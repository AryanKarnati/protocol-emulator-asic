(* Trace tool: run a case file on the reference (pgsim) and on a DUT, and print both
   sides per cycle for one SM: pc, fifo flags, irq and stall code. Usage:
     probe.exe CASE.json SM [rtl|pgsim|mut-NAME] *)
open Polyglot_lockstep

let () =
  let file = Sys.argv.(1) in
  let sm = int_of_string Sys.argv.(2) in
  let dut_name = if Array.length Sys.argv > 3 then Sys.argv.(3) else "rtl" in
  let c = Case.normalise (Case.read_file file) in
  let num_sms = c.Case.num_sms in
  let inputs = Case.dense c in
  let reference = Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"ref" ~pads_from_pins_in:false ~num_sms in
  let dut =
    if dut_name = "rtl" then Polyglot_rtl_dut.Rtl_dut.create ~num_sms
    else if dut_name = "pgsim" then Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"p" ~pads_from_pins_in:true ~num_sms
    else Option.get (Polyglot_mutant_duts.Mutant_duts.make (String.sub dut_name 4 (String.length dut_name - 4)) ~num_sms)
  in
  ignore (reference.Dut.cycle (Ports.idle ~rst_n:false));
  ignore (dut.Dut.cycle (Ports.idle ~rst_n:false));
  Array.iteri
    (fun n inp ->
      let r = reference.Dut.regs () in
      let d = dut.Dut.regs () in
      if n >= Case.load_cycles then (
        let cy = n - Case.load_cycles in
        let show (o : Ports.outputs) =
          Printf.sprintf "pc=%2d fstat=%08x irq=%02x cnt=%08x pins=%08x oe=%08x" o.Ports.pc.(sm) o.Ports.fstat o.Ports.irq o.Ports.cnt.(sm) o.Ports.pins_out o.Ports.pins_oe
        in
        Printf.printf "cyc %3d  ref: %s
        dut: %s%s
" cy (show r) (show d)
          (if r.Ports.pc.(sm) <> d.Ports.pc.(sm) || r.Ports.irq <> d.Ports.irq || r.Ports.pins_out <> d.Ports.pins_out || r.Ports.pins_oe <> d.Ports.pins_oe then "   <== differ" else ""));
      let inp = { inp with Ports.pins_in = Ports.pins_in_of ~pins_out:d.Ports.pins_out ~pins_oe:d.Ports.pins_oe ~ext:inp.Ports.pins_ext } in
      ignore (reference.Dut.cycle inp);
      ignore (dut.Dut.cycle inp))
    inputs
