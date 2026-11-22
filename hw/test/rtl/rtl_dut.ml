(* Cyclesim adapter: the RTL DUT for the lockstep harness. It drives the port names of
   docs/engine.md section 3 on a Hardcaml Cyclesim of [Polyglot_hw.Pio_block.circuit]. *)

open Polyglot_lockstep
module Sim = Hardcaml.Cyclesim

let bits width v = Hardcaml.Bits.of_int ~width v
let to_int b = Hardcaml.Bits.to_int b

let missing : (string, unit) Hashtbl.t = Hashtbl.create 8

let note name = if not (Hashtbl.mem missing name) then Hashtbl.add missing name ()

(* Ports the circuit lacked, sorted. *)
let missing_ports () = Hashtbl.fold (fun k () acc -> k :: acc) missing [] |> List.sort compare

let create ~num_sms : Dut.port_dut =
  let circuit = Polyglot_hw.Pio_block.circuit ~num_sms in
  let sim = Sim.create circuit in
  (* Cyclesim applies register reset values only through [Sim.reset]: call it before cycle
     0. The lockstep runner then drives rst_n low for two cycles (Lockstep.run). *)
  Sim.reset sim;
  (* Settle the combinational outputs of the reset state (the registered view of cycle 0). *)
  Sim.cycle_check sim;
  (* engine.md 3: ports exist for 4 SMs whatever num_sms is. A port that the circuit does not
     have is recorded in [missing] (reported by the probe), and reads as 0 / ignores writes,
     which is what engine.md 3 says for an SM with no logic. *)
  let set name width v =
    match Sim.in_port sim name with
    | r -> r := bits width v
    | exception _ -> note name
  in
  let get ?(before = true) name =
    match
      if before
      then Sim.out_port ~clock_edge:Hardcaml.Side.Before sim name
      else Sim.out_port sim name
    with
    | r -> to_int !r
    | exception _ ->
      note name;
      0
  in
  let per name f = Array.init 4 (fun i -> f (Printf.sprintf "%s%d" name i)) in
  let regs () : Ports.outputs =
    Sim.cycle_before_clock_edge sim;
    let g = get in
    { Ports.pins_out = g "pins_out"
    ; pins_oe = g "pins_oe"
    ; irq = g "irq"
    ; fstat = g "fstat"
    ; flevel = g "flevel"
    ; fdebug = g "fdebug"
    ; pc = per "dbg_pc" (fun n -> g n)
    ; x = per "dbg_x" (fun n -> g n)
    ; y = per "dbg_y" (fun n -> g n)
    ; isr = per "dbg_isr" (fun n -> g n)
    ; osr = per "dbg_osr" (fun n -> g n)
    ; cnt = per "dbg_cnt" (fun n -> g n)
    ; exec_stalled = per "dbg_exec_stalled" (fun n -> g n)
    ; phase = per "dbg_phase" (fun n -> g n)
    ; rxf_data = 0
    }
  in
  let cycle (i : Ports.inputs) : int =
    (* Reset cycles do not clock: Sim.reset above has put every register at its R0 value,
       and clocking with rst_n low would advance the divider (engine.md R0, section 5). *)
    if not i.Ports.rst_n
    then 0
    else (
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
    (match i.Ports.txf_push with
     | Some (sm, d) ->
       set "txf_push" 1 1;
       set "txf_sm" 2 sm;
       set "txf_data" 32 d
     | None -> set "txf_push" 1 0);
    (match i.Ports.rxf_pop with
     | Some sm ->
       set "rxf_pop" 1 1;
       set "rxf_sm" 2 sm
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
       set "imem_addr" 5 a;
       set "imem_data" 16 d
     | None -> set "imem_write" 1 0);
    Sim.cycle_before_clock_edge sim;
    let rx = match i.Ports.rxf_pop with Some _ -> get ~before:true "rxf_data" | None -> 0 in
    Sim.cycle_at_clock_edge sim;
    Sim.cycle_after_clock_edge sim;
    rx)
  in
  { Dut.name = "rtl"; regs; cycle }
;;
