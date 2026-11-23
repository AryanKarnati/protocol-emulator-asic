(* Cyclesim adapter: the RTL DUT for the lockstep harness. It drives the port names of
   docs/engine.md section 3 on a Hardcaml Cyclesim of [Polyglot_hw.Pio_block.circuit].

   Reset model. The RTL's registers are asynchronous-reset (rst_n low holds them at R0).
   Cyclesim does not model that: a reset given as a data signal does not take effect at
   clock edges (checked with hw/test/rtl/reset_probe, round 2). So the adapter takes reset
   from [Cyclesim.reset] instead. While rst_n is low it calls [Cyclesim.reset] and does not
   clock, so the registers hold R0 as the async reset would. IMEM is not reset by
   [Cyclesim.reset], as engine.md R0 requires, and the case's load phase rewrites it
   regardless. Reset that a Verilog simulator would catch (async, glitch, reset-edge
   sensitivity) cannot be checked here: it is for block 3's cocotb and gate-level runs.

   Port presence. Engine.md 3 says the ports exist for 4 SMs whatever num_sms is. A port
   the circuit lacks is recorded in [missing] and treated as 0 (outputs) or ignored
   (inputs). The missing list is reported by the CLI as triage class 1. *)

open Polyglot_lockstep
module Sim = Hardcaml.Cyclesim

let bits width v = Hardcaml.Bits.of_int ~width v
let to_int b = Hardcaml.Bits.to_int b

(* Ports the circuit lacked, from any adapter instance. *)
let missing : (string, unit) Hashtbl.t = Hashtbl.create 8

let note name = if not (Hashtbl.mem missing name) then Hashtbl.add missing name ()

(* Ports the circuit lacked, sorted. *)
let missing_ports () = Hashtbl.fold (fun k () acc -> k :: acc) missing [] |> List.sort compare

let create ~num_sms : Dut.port_dut =
  let circuit = Polyglot_hw.Pio_block.circuit ~num_sms in
  let sim = Sim.create circuit in
  let reset () =
    Sim.reset sim;
    (* Settle the combinational outputs of the reset state, so reads see R0. *)
    Sim.cycle_check sim
  in
  reset ();
  let set name width v =
    match Sim.in_port sim name with
    | r -> r := bits width v
    | exception _ -> note name
  in
  let get name =
    match Sim.out_port ~clock_edge:Hardcaml.Side.Before sim name with
    | r -> to_int !r
    | exception _ ->
      note name;
      0
  in
  let per name = Array.init 4 (fun i -> get (Printf.sprintf "%s%d" name i)) in
  (* Drive the input ports for one cycle (rst_n high). *)
  let drive (i : Ports.inputs) =
    set "rst_n" 1 1;
    set "sm_enable" 4 i.Ports.sm_enable;
    for k = 0 to 3 do
      set (Printf.sprintf "clkdiv%d" k) 32 i.Ports.clkdiv.(k);
      set (Printf.sprintf "execctrl%d" k) 32 i.Ports.execctrl.(k);
      set (Printf.sprintf "shiftctrl%d" k) 32 i.Ports.shiftctrl.(k);
      set (Printf.sprintf "pinctrl%d" k) 32 i.Ports.pinctrl.(k)
    done;
    set "sync_bypass" 32 i.Ports.sync_bypass;
    set "pins_in" 32 i.Ports.pins_in;
    set "sm_restart" 4 i.Ports.sm_restart;
    set "clkdiv_restart" 4 i.Ports.clkdiv_restart;
    set "fifo_flush" 4 i.Ports.fifo_flush;
    set "irq_clear" 8 i.Ports.irq_clear;
    set "irq_force" 8 i.Ports.irq_force;
    set "fdebug_clear" 32 i.Ports.fdebug_clear;
    set "fdebug_set" 32 i.Ports.fdebug_set;
    for k = 0 to 3 do
      set (Printf.sprintf "ext%d" k) 32 i.Ports.sm_ext.(k)
    done;
    set "rxf_sm" 2 i.Ports.rxf_sm;
    (match i.Ports.txf_push with
     | Some (sm, d) ->
       set "txf_push" 1 1;
       set "txf_sm" 2 sm;
       set "txf_data" 32 d
     | None -> set "txf_push" 1 0);
    (match i.Ports.rxf_pop with
     | Some _ -> set "rxf_pop" 1 1
     | None -> set "rxf_pop" 1 0);
    (match i.Ports.instr_write with
     | Some (sm, d) ->
       set "instr_write" 1 1;
       set "instr_sm" 2 sm;
       set "instr_data" 16 d
     | None -> set "instr_write" 1 0);
    (match i.Ports.imem_write with
     | Some (a, d) ->
       set "imem_write" 1 1;
       set "imem_addr" 6 a;
       set "imem_data" 16 d
     | None -> set "imem_write" 1 0);
    Sim.cycle_check sim
  in
  (* Outputs of the cycle: the inputs are driven first, since FIFO capacity follows FJOIN
     (engine.md 3). Register outputs do not depend on the rest. *)
  let regs (i : Ports.inputs) : Ports.outputs =
    if i.Ports.rst_n then drive i;
    Sim.cycle_before_clock_edge sim;
    { Ports.pins_out = get "pins_out"
    ; pins_oe = get "pins_oe"
    ; irq = get "irq"
    ; fstat = get "fstat"
    ; flevel = get "flevel"
    ; fdebug = get "fdebug"
    ; pc = per "dbg_pc"
    ; x = per "dbg_x"
    ; y = per "dbg_y"
    ; isr = per "dbg_isr"
    ; osr = per "dbg_osr"
    ; cnt = per "dbg_cnt"
    ; exec_stalled = per "dbg_exec_stalled"
    ; phase = per "dbg_phase"
    ; instr = per "dbg_instr"
    ; rxf_data = get "rxf_data"
    }
  in
  let cycle (i : Ports.inputs) : int =
    if not i.Ports.rst_n
    then (
      reset ();
      0)
    else (
      drive i;
      Sim.cycle_before_clock_edge sim;
      let rx = get "rxf_data" in
      Sim.cycle_at_clock_edge sim;
      Sim.cycle_after_clock_edge sim;
      Sim.cycle_check sim;
      rx)
  in
  { Dut.name = "rtl"; regs; cycle }
;;
