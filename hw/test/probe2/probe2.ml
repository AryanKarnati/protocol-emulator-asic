(* pgsim state probe: drive pgsim directly from a case file (through Case.dense, as the lockstep
   does) and print SM [sm]'s model state per run cycle. Usage: probe2.exe CASE.json SM [FROM TO] *)
open Polyglot_lockstep
module P = Pgsim

let () =
  let file = Sys.argv.(1) in
  let sm = int_of_string Sys.argv.(2) in
  let from_c = if Array.length Sys.argv > 4 then int_of_string Sys.argv.(3) else 0 in
  let to_c = if Array.length Sys.argv > 4 then int_of_string Sys.argv.(4) else max_int in
  let c = Case.normalise (Case.read_file file) in
  let inputs = Case.dense c in
  let t = P.create () in
  P.load_program t (Array.to_list c.Case.imem);
  let applied = Array.make 4 None in
  Array.iteri
    (fun n (inp : Ports.inputs) ->
      if n >= Case.load_cycles then (
        let cy = n - Case.load_cycles in
        for i = 0 to c.Case.num_sms - 1 do
          let cfg =
            P.Config.of_registers ~clkdiv:inp.Ports.clkdiv.(i) ~execctrl:inp.execctrl.(i)
              ~shiftctrl:inp.shiftctrl.(i) ~pinctrl:inp.pinctrl.(i)
          in
          (match applied.(i) with
           | Some x when x = cfg -> ()
           | _ ->
             P.set_config t i cfg;
             applied.(i) <- Some cfg);
          P.set_enabled t i (inp.sm_enable lsr i land 1 = 1)
        done;
        t.P.sync_bypass <- inp.sync_bypass;
        t.P.ext <- inp.pins_ext;
        let d = P.debug t sm in
        if cy >= from_c && cy <= to_c then
          Printf.printf
            "cyc %2d en=%b pc=%d delay=%d acc=%d stall=%d pins=%08x\n"
            cy d.P.enabled d.P.pc d.P.delay d.P.acc d.P.stall_code t.P.pin_level);
      ignore (P.step t))
    inputs
