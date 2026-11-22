(* DUTs at the port level. A [port_dut] is what the lockstep runner drives: [regs] reads the
   register outputs of the current cycle, and [cycle] presents one cycle's inputs, returns
   the combinational rxf_data, and clocks. [pgsim] builds one from a pgsim module, so the
   same port mapping serves the reference and the faulty variants (which are pgsim with one
   source edit each, see hw/test/mutants). *)

type port_dut =
  { name : string
  ; regs : unit -> Ports.outputs
  ; cycle : Ports.inputs -> int
  }

module type PGSIM = module type of Pgsim

(* [pads_from_pins_in]: drive pgsim's pad level from the [pins_in] port (what an RTL
   testbench does), instead of the external stimulus. The two agree when the testbench
   computes pins_in as engine.md R1 says, which the lockstep checks cycle by cycle. *)
let pgsim (module P : PGSIM) ~name ~pads_from_pins_in ~num_sms : port_dut =
  let t = P.create () in
  let applied : P.Config.t option array = Array.make 4 None in
  let regs () : Ports.outputs =
    let per f = Array.init 4 (fun i -> if i < num_sms then f i else 0) in
    let dbg i = P.debug t i in
    let smask f = Ports.sm_mask ~num_sms f in
    { Ports.pins_out = P.pins_out t
    ; pins_oe = P.pins_oe t
    ; irq = t.P.irq
    ; fstat = P.fstat t land smask Ports.fstat_bits
    ; flevel = P.flevel t land smask Ports.flevel_bits
    ; fdebug = P.fdebug t land smask Ports.fdebug_bits
    ; pc = per (fun i -> (dbg i).P.pc)
    ; x = per (fun i -> (dbg i).P.x)
    ; y = per (fun i -> (dbg i).P.y)
    ; isr = per (fun i -> (dbg i).P.isr)
    ; osr = per (fun i -> (dbg i).P.osr)
    ; cnt = per (fun i -> P.dbg_cnt t i)
    ; exec_stalled = per (fun i -> if (dbg i).P.exec_stalled then 1 else 0)
    ; phase = per (fun i -> (dbg i).P.acc)
    ; rxf_data = 0
    }
  in
  let host_ops (i : Ports.inputs) =
    let ops = ref [] in
    let add o = ops := o :: !ops in
    (* Inputs aimed at an SM with no logic are ignored (engine.md 3). *)
    let here sm = sm < num_sms in
    (match i.txf_push with
     | Some (sm, data) when here sm -> add (P.Host_op.Tx_push { sm; data })
     | _ -> ());
    (match i.rxf_pop with
     | Some sm when here sm -> add (P.Host_op.Rx_pop { sm })
     | _ -> ());
    (match i.instr_write with
     | Some (sm, data) when here sm -> add (P.Host_op.Instr_write { sm; data })
     | _ -> ());
    (match i.imem_write with
     | Some (addr, data) -> add (P.Host_op.Imem_write { addr; data })
     | None -> ());
    let smask = (1 lsl num_sms) - 1 in
    if i.sm_restart land smask <> 0 then add (P.Host_op.Sm_restart (i.sm_restart land smask));
    if i.clkdiv_restart land smask <> 0
    then add (P.Host_op.Clkdiv_restart (i.clkdiv_restart land smask));
    if i.fifo_flush land smask <> 0 then add (P.Host_op.Fifo_flush (i.fifo_flush land smask));
    if i.irq_clear land 0xFF <> 0 then add (P.Host_op.Irq_clear (i.irq_clear land 0xFF));
    if i.irq_force land 0xFF <> 0 then add (P.Host_op.Irq_force (i.irq_force land 0xFF));
    let fd = i.fdebug_clear land Ports.sm_mask ~num_sms Ports.fdebug_bits in
    if fd <> 0 then add (P.Host_op.Fdebug_clear fd);
    List.rev !ops
  in
  let cycle (i : Ports.inputs) : int =
    if not i.rst_n
    then 0 (* reset: the model is in its reset state and does not count cycles *)
    else (
      let rx =
        match i.rxf_pop with
        | Some sm when sm < num_sms -> P.rx_head t sm
        | Some _ | None -> 0
      in
      for sm = 0 to num_sms - 1 do
        let cfg =
          P.Config.of_registers
            ~clkdiv:i.clkdiv.(sm)
            ~execctrl:i.execctrl.(sm)
            ~shiftctrl:i.shiftctrl.(sm)
            ~pinctrl:i.pinctrl.(sm)
        in
        (match applied.(sm) with
         | Some c when c = cfg -> ()
         | _ ->
           P.set_config t sm cfg;
           applied.(sm) <- Some cfg);
        P.set_enabled t sm (i.sm_enable lsr sm land 1 = 1)
      done;
      t.P.sync_bypass <- i.sync_bypass;
      t.P.ext <- (if pads_from_pins_in then i.pins_in else i.pins_ext);
      ignore (P.step_ex ~host:(host_ops i) t);
      rx)
  in
  { name; regs; cycle }
;;
