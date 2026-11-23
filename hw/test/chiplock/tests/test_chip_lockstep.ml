(* The chip lockstep in CI (docs/chip.md 11, 13): clean random cases pass against the RTL chip,
   and every chip mutant is caught within a few cases. The large runs (2,000 cases and up, and the
   corpus) are chip_cli triage and chip_cli corpus, run by hand. *)

open Polyglot_chiplock

let clean_cases = 4
let cycles = 1500
let cases_per_mutant = 6

let () =
  for i = 0 to clean_cases - 1 do
    let c = Chip_gen.generate ~target:cycles ~seed:(7000 + i) ~num_sms:(1 + i) () in
    match Chip_lockstep.run c with
    | Chip_lockstep.Pass _ -> ()
    | Chip_lockstep.Fail f -> failwith ("clean chip case " ^ string_of_int i ^ ": " ^ Chip_lockstep.describe f)
  done;
  List.iter
    (fun (name, model) ->
      let caught = ref false in
      let i = ref 0 in
      while (not !caught) && !i < cases_per_mutant do
        let c = Chip_gen.generate ~target:cycles ~seed:(9000 + !i) ~num_sms:4 () in
        (match Chip_lockstep.run ~model c with
         | Chip_lockstep.Fail _ -> caught := true
         | Chip_lockstep.Pass _ -> ());
        incr i
      done;
      if not !caught then failwith ("chip mutant not caught: " ^ name))
    Polyglot_chip_mutants.Chip_mutants.models;
  print_endline "chip lockstep: clean cases pass, all chip mutants caught"
;;
