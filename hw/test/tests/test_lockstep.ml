(* The comparator must pass the pgsim DUT and must catch every faulty variant. *)
open Polyglot_lockstep

let run ~dut_of (case : Case.t) =
  let num_sms = case.Case.num_sms in
  let reference =
    Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim-ref" ~pads_from_pins_in:false ~num_sms
  in
  Lockstep.run ~reference ~dut:(dut_of ~num_sms) case
;;

let pgsim_dut ~num_sms =
  Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim" ~pads_from_pins_in:true ~num_sms
;;

let check name = function
  | Lockstep.Pass _ -> ()
  | Lockstep.Fail f -> failwith (name ^ ": unexpected mismatch\n" ^ Lockstep.report f)
;;

let mutants : (string * (num_sms:int -> Dut.port_dut)) list =
  [ ( "delay_off_by_one"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_delay_off_by_one.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ; ( "sideset_loses_to_out"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_sideset_loses_to_out.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ; ( "autopull_no_refill_non_out"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_autopull_no_refill_non_out.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ; ( "irq_clear_beats_set"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_irq_clear_beats_set.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ; ( "input_latency_2"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_input_latency_2.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ; ( "host_push_same_cycle"
    , fun ~num_sms ->
        Dut.pgsim
          (module Pgsim_mut_host_push_same_cycle.Pgsim : Dut.PGSIM)
          ~name:"m" ~pads_from_pins_in:true ~num_sms )
  ]
;;

let () =
  let c = Gen.generate_one ~seed:3 5 in
  assert (Case.of_text (Case.to_text c) = c);
  for i = 0 to 299 do
    check "gen" (run ~dut_of:pgsim_dut (Gen.generate_one ~seed:11 i))
  done;
  List.iter
    (fun (_, c) -> check "corpus" (run ~dut_of:pgsim_dut c))
    (Corpus.cases ~cycles:1000 ~dir:"../../../sw/pgasm/test/corpus" ());
  List.iter
    (fun (name, dut_of) ->
      let caught = ref false in
      let i = ref 0 in
      while (not !caught) && !i < 1500 do
        (match run ~dut_of (Gen.generate_one ~seed:1 !i) with
         | Lockstep.Fail _ -> caught := true
         | Lockstep.Pass _ -> ());
        incr i
      done;
      if not !caught then failwith ("mutant not caught: " ^ name))
    mutants;
  print_endline "lockstep: pgsim passes, all 6 mutants caught"
;;
