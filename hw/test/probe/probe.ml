(* Debug probe: run a directed case on the pgsim port-level DUT and print the SM state and the
   IRQ flags per run cycle. *)
open Polyglot_lockstep

let () =
  let c = Directed.restart_clears_latch_irq () in
  let inputs = Case.dense c in
  let d = Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"p" ~pads_from_pins_in:true ~num_sms:1 in
  ignore (d.Dut.cycle (Ports.idle ~rst_n:false));
  Array.iteri
    (fun n inp ->
      let o = d.Dut.regs () in
      if n >= Case.load_cycles then
        Printf.printf "cyc %2d pc=%d irq=%02x stall=%d exec_stalled=%d osr=%08x\n" (n - 32)
          o.Ports.pc.(0) o.Ports.irq (o.Ports.cnt.(0) lsr 24 land 15) o.Ports.exec_stalled.(0) o.Ports.osr.(0);
      let inp = { inp with Ports.pins_in = Ports.pins_in_of ~pins_out:o.Ports.pins_out ~pins_oe:o.Ports.pins_oe ~ext:inp.Ports.pins_ext } in
      ignore (d.Dut.cycle inp))
    inputs
