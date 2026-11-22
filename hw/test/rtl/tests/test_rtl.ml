(* The RTL against the pgsim reference: the corpus at 4 SMs, and a small generated batch at
   1 and 4 SMs. Any mismatch fails this test, and its report is printed. The full runs
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
      for i = 0 to 199 do
        let c = Gen.generate_one ~seed:(100 + sms) i in
        report (Printf.sprintf "gen %d (sms %d)" i sms) (run { c with Case.num_sms = sms })
      done)
    [ 1; 4 ];
  Printf.printf "rtl lockstep: %d mismatching cases\n" !failures;
  if !failures > 0 then exit 1
;;
