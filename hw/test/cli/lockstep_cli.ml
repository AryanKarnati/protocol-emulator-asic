(* lockstep_cli: run the lockstep harness.

   lockstep_cli gen [--count N] [--seed S] [--dut NAME] [--save DIR --save-n K]
       Generate N random cases (Base_quickcheck, seed S), run each against the reference.
       Stops at the first mismatch, shrinks it, prints the report and writes the shrunk case
       to DIR/failure.json (default: the current directory).
   lockstep_cli replay FILE [--dut NAME]
       Run one case file (the JSON that gen and write-cases produce) against the reference.
   lockstep_cli corpus [--dir DIR] [--cycles N] [--dut NAME] [--write-dir DIR]
       Run every program of the pioasm corpus in lockstep.
   lockstep_cli mutants [--count N] [--seed S]
       Run gen against each faulty pgsim variant and report where it is caught.
   lockstep_cli write-cases DIR [--count N] [--seed S]
       Write the corpus cases and N generated cases as self-contained JSON files.

   DUT names: pgsim (the port-level pgsim DUT, pads from pins_in), and mut-NAME for the
   faulty variants listed by mutants. The reference is always pgsim, pads from the stimulus.
   The RTL DUT is in hw/test/rtl and is built separately (see its README comment). *)

open Polyglot_lockstep

let mutant_names =
  [ "delay_off_by_one"
  ; "sideset_loses_to_out"
  ; "autopull_no_refill_non_out"
  ; "irq_clear_beats_set"
  ; "input_latency_2"
  ; "host_push_same_cycle"
  ]
;;

let dut_of_name name ~num_sms : Dut.port_dut =
  let port (module P : Dut.PGSIM) ~pads_from_pins_in =
    Dut.pgsim (module P) ~name ~pads_from_pins_in ~num_sms
  in
  match name with
  | "pgsim" -> port (module Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "delay_off_by_one" ->
    port (module Pgsim_mut_delay_off_by_one.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "sideset_loses_to_out" ->
    port (module Pgsim_mut_sideset_loses_to_out.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "autopull_no_refill_non_out" ->
    port (module Pgsim_mut_autopull_no_refill_non_out.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "irq_clear_beats_set" ->
    port (module Pgsim_mut_irq_clear_beats_set.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "input_latency_2" ->
    port (module Pgsim_mut_input_latency_2.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | "host_push_same_cycle" ->
    port (module Pgsim_mut_host_push_same_cycle.Pgsim : Dut.PGSIM) ~pads_from_pins_in:true
  | _ -> failwith ("unknown DUT " ^ name)
;;

let dut_name_of n =
  if n = "pgsim" || List.mem n mutant_names then n else failwith ("unknown DUT " ^ n)
;;

(* Run [case] (normalised) on the reference and on the named DUT. *)
let check ~dut case =
  let num_sms = case.Case.num_sms in
  let reference = Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim-ref" ~pads_from_pins_in:false ~num_sms in
  let dut = dut_of_name dut ~num_sms in
  Lockstep.run ~reference ~dut case
;;

let print_failure ~label (case : Case.t) (f : Lockstep.failure) =
  Printf.printf "%s\n%s" label (Lockstep.report f);
  Printf.printf "case (%d SMs, %d run cycles, %d events):\n%s\n" case.Case.num_sms case.Case.cycles
    (List.length case.Case.events)
    (Case.to_text case)
;;

let flag args name default =
  let rec go = function
    | k :: v :: _ when k = name -> v
    | _ :: rest -> go rest
    | [] -> default
  in
  go args
;;

let int_flag args name default = int_of_string (flag args name (string_of_int default))

let cmd_gen args =
  let count = int_flag args "--count" 1000 in
  let seed = int_flag args "--seed" 1 in
  let dut = dut_name_of (flag args "--dut" "pgsim") in
  let save_dir = flag args "--save" "" in
  let save_n = int_flag args "--save-n" 0 in
  let saved = ref 0 in
  let check c =
    if save_dir <> "" && !saved < save_n
    then (
      incr saved;
      Case.write_file (Filename.concat save_dir (Printf.sprintf "gen_%04d.json" !saved)) c);
    check ~dut c
  in
  match Gen.search ~seed ~check ~count () with
  | Gen.Passed { count; total_cycles; seconds } ->
    Printf.printf
      "gen: %d cases passed on %s (seed %d): %d compared cycles, %.2f s, %.3f ms per case\n" count dut
      seed total_cycles seconds
      (1000. *. seconds /. float_of_int (max 1 count));
    0
  | Gen.Failed { index; case; failure; shrink_steps } ->
    Printf.printf "gen: case %d failed on %s after %d shrink steps\n" index dut shrink_steps;
    print_failure ~label:"shrunk failure:" case failure;
    let path = Filename.concat (flag args "--out" ".") "failure.json" in
    Case.write_file path case;
    Printf.printf "shrunk case written to %s\n" path;
    1
;;

let cmd_replay args file =
  let dut = dut_name_of (flag args "--dut" "pgsim") in
  let case = Case.normalise (Case.read_file file) in
  match check ~dut case with
  | Lockstep.Pass { cycles } ->
    Printf.printf "replay %s: pass on %s, %d cycles\n" file dut cycles;
    0
  | Lockstep.Fail f ->
    print_failure ~label:("replay " ^ file ^ ": mismatch") case f;
    1
;;

let write_cases dir cases =
  List.iter
    (fun (name, c) ->
      let safe = String.map (fun ch -> if ch = '/' || ch = ' ' then '_' else ch) name in
      Case.write_file (Filename.concat dir (safe ^ ".json")) c)
    cases
;;

let cmd_corpus args =
  let dir = flag args "--dir" "sw/pgasm/test/corpus" in
  let cycles = int_flag args "--cycles" 3000 in
  let dut = dut_name_of (flag args "--dut" "pgsim") in
  let cases = Corpus.cases ~cycles ~dir () in
  (match flag args "--write-dir" "" with
   | "" -> ()
   | d -> write_cases d cases);
  let t0 = Sys.time () in
  let failed = ref 0 in
  let total = ref 0 in
  List.iter
    (fun (name, c) ->
      match check ~dut c with
      | Lockstep.Pass { cycles } -> total := !total + cycles
      | Lockstep.Fail f ->
        incr failed;
        print_failure ~label:("corpus " ^ name ^ ": mismatch") c f)
    cases;
  let dt = Sys.time () -. t0 in
  Printf.printf "corpus: %d programs on %s, %d cycles each, %d failed, %.2f s\n" (List.length cases) dut
    cycles !failed dt;
  if !failed = 0 then 0 else 1
;;

let cmd_mutants args =
  let count = int_flag args "--count" 2000 in
  let seed = int_flag args "--seed" 1 in
  let rows =
    List.map
      (fun m ->
        let name = "mut-" ^ m in
        match Gen.search ~seed ~check:(check ~dut:m) ~count () with
        | Gen.Passed { count; _ } ->
          Printf.printf "%-30s NOT CAUGHT in %d cases\n%!" name count;
          name, false
        | Gen.Failed { index; case; failure; shrink_steps } ->
          Printf.printf
            "%-30s caught at case %d: %s at %s (%d SMs, %d events after %d shrink steps)\n%!" name
            index failure.Lockstep.port
            (Printf.sprintf "run cycle %d" (failure.Lockstep.cycle - Case.load_cycles))
            case.Case.num_sms (List.length case.Case.events) shrink_steps;
          name, true)
      mutant_names
  in
  let missed = List.filter (fun (_, c) -> not c) rows in
  Printf.printf "mutants: %d of %d caught\n" (List.length rows - List.length missed) (List.length rows);
  if missed = [] then 0 else 1
;;

let cmd_write_cases args dir =
  let count = int_flag args "--count" 20 in
  let seed = int_flag args "--seed" 1 in
  write_cases dir (Corpus.cases ~dir:"sw/pgasm/test/corpus" ());
  for i = 1 to count do
    Case.write_file (Filename.concat dir (Printf.sprintf "gen_%03d.json" i)) (Gen.generate_one ~seed i)
  done;
  0
;;

let () =
  let argv = Array.to_list Sys.argv in
  let code =
    match argv with
    | _ :: "gen" :: args -> cmd_gen args
    | _ :: "replay" :: file :: args -> cmd_replay args file
    | _ :: "corpus" :: args -> cmd_corpus args
    | _ :: "mutants" :: args -> cmd_mutants args
    | _ :: "write-cases" :: dir :: args -> cmd_write_cases args dir
    | _ ->
      prerr_endline
        "usage: lockstep_cli (gen|replay FILE|corpus|mutants|write-cases DIR) [options]";
      2
  in
  exit code
;;
