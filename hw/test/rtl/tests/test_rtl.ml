(* The RTL against the pgsim reference: the corpus at 4 SMs, and 500 generated cases at 1 and 4
   SMs (about 2 minutes in total, for CI). Any mismatch fails this test, and its report is printed. The full runs
   (10,000 cases, triage into classes, case files) are lockstep_cli triage; see the
   README in hw/test/cases/rtl. *)
open Polyglot_lockstep

let rtl ~num_sms = Polyglot_rtl_dut.Rtl_dut.create ~num_sms

let run (case : Case.t) =
  let num_sms = case.Case.num_sms in
  let reference =
    Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim-ref" ~pads_from_pins_in:false ~num_sms
  in
  Lockstep.run ~reference ~dut:(rtl ~num_sms) case
;;

let failures = ref 0

let report label = function
  | Lockstep.Pass _ -> ()
  | Lockstep.Fail f ->
    incr failures;
    Printf.printf "%s\n%s" label (Lockstep.report f)
;;

let () =
  List.iter
    (fun (name, c) -> report ("corpus " ^ name) (run c))
    (Corpus.cases ~cycles:3000 ~dir:"../../../../sw/pgasm/test/corpus" ());
  List.iter
    (fun sms ->
      for i = 0 to 499 do
        let c = Gen.generate_one ~seed:(100 + sms) i in
        report (Printf.sprintf "gen %d (sms %d)" i sms) (run { c with Case.num_sms = sms })
      done)
    [ 1; 4 ];
  (* Checked after the runs: the adapter records a port only when it is accessed. A port
     missing from the circuit reads as 0, which would hide a deleted port whenever its reference
     value is 0. Every port must be present. *)
  let missing = Polyglot_rtl_dut.Rtl_dut.missing_ports () in
  if missing <> [] then failwith ("RTL ports missing from the circuit: " ^ String.concat " " missing);
  Printf.printf "rtl lockstep: %d mismatching cases\n" !failures;
  if !failures > 0 then exit 1
;;
