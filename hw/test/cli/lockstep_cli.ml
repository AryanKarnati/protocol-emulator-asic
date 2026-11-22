(* lockstep_cli: run the lockstep harness.

   lockstep_cli gen [--count N] [--seed S] [--sms K] [--dut NAME] [--save DIR --save-n K]
       Generate N random cases, run each against the reference, stop at the first mismatch,
       shrink it, and write the shrunk case to DIR/failure.json (--out DIR, default .).
   lockstep_cli triage [--count N] [--seed S] [--sms K] [--dut NAME] [--out-dir DIR]
       Run N cases without stopping, group the mismatches into classes (first failing port,
       and whether a mid-run reset precedes it), shrink one case per class into DIR.
   lockstep_cli replay FILE [--dut NAME]
       Run one case file against the reference (the JSON that gen, triage and write-cases make).
   lockstep_cli corpus [--dir DIR] [--cycles N] [--dut NAME] [--write-dir DIR]
       Run every program of the pioasm corpus in lockstep.
   lockstep_cli mutants [--count N] [--seed S]
       Run gen against each faulty pgsim variant and report where it is caught.
   lockstep_cli write-cases DIR [--count N] [--seed S]
       Write the corpus cases and N generated cases as self-contained JSON files.
   lockstep_cli rtl-probe [--sms N]
       Print the RTL outputs after reset and across a mid-run reset.

   DUT names: pgsim (the port-level pgsim DUT), rtl (the Cyclesim adapter of
   hw/test/rtl, built into this executable), and the faulty variants named by mutants. The
   reference is always pgsim, with pads from the stimulus. Example, the RTL at one SM:
     _build/default/hw/test/cli/lockstep_cli.exe triage --count 10000 --seed 1 --sms 1 --dut rtl *)

open Polyglot_lockstep

let mutant_names = Polyglot_mutant_duts.Mutant_duts.names

let dut_of_name name ~num_sms : Dut.port_dut =
  match name with
  | "pgsim" ->
    Dut.pgsim (module Pgsim : Dut.PGSIM) ~name ~pads_from_pins_in:true ~num_sms
  | "rtl" -> Polyglot_rtl_dut.Rtl_dut.create ~num_sms
  | _ ->
    (match Polyglot_mutant_duts.Mutant_duts.make name ~num_sms with
     | Some d -> d
     | None -> failwith ("unknown DUT " ^ name))
;;

let dut_name_of n =
  if n = "pgsim" || n = "rtl" || List.mem n mutant_names then n else failwith ("unknown DUT " ^ n)
;;

(* Run [case] (normalised) on the reference and on the named DUT. *)
let waive = ref false
let waive_fifo = ref false

let check ~dut case =
  let num_sms = case.Case.num_sms in
  let reference = Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"pgsim-ref" ~pads_from_pins_in:false ~num_sms in
  let dut = dut_of_name dut ~num_sms in
  Lockstep.run ~waive_cycle0_fstat:!waive ~waive_after_reset_fifo:!waive_fifo ~reference ~dut case
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
  waive := List.mem "--waive-cycle0-fstat" args;
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
  let sms = match flag args "--sms" "" with "" -> None | n -> Some (int_of_string n) in
  match Gen.search ~seed ?sms ~check ~count () with
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
  waive_fifo := List.mem "--waive-after-reset-fifo" args;
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
  waive := List.mem "--waive-cycle0-fstat" args;
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

(* Port base name: dbg_pc0 -> dbg_pc, irq -> irq. *)
let port_base name =
  let n = String.length name in
  let rec cut i = if i > 0 && name.[i - 1] >= '0' && name.[i - 1] <= '9' then cut (i - 1) else i in
  let i = cut n in
  if i < n && i > 0 && name.[i - 1] = '_' then name else String.sub name 0 i

(* Class key helper: whether a mid-run reset (rst_n low) is at or before the failing run cycle.
   Only the failing window is used otherwise, so one bug does not split into many classes. *)
let window_kinds (case : Case.t) (run_cycle : int) =
  let reset_before = List.exists (fun (cy, ev) -> ev = Case.Reset_low && cy <= run_cycle) case.Case.events in
  if reset_before
  then "after-reset"
  else
    case.Case.events
    |> List.filter (fun (cy, _) -> cy >= run_cycle - 3 && cy <= run_cycle)
    |> List.map (fun (_, ev) -> Case.kind_name ev)
    |> List.sort_uniq compare
    |> String.concat "+"
;;

let cmd_triage args =
  waive_fifo := List.mem "--waive-after-reset-fifo" args;
  let count = int_flag args "--count" 1000 in
  let seed = int_flag args "--seed" 1 in
  let dut = dut_name_of (flag args "--dut" "rtl") in
  let sms = match flag args "--sms" "" with "" -> None | n -> Some (int_of_string n) in
  let out_dir = flag args "--out-dir" "." in
  let passed, fails, cycles, secs =
    Gen.search_all ~seed ?sms ~check:(check ~dut) ~count ()
  in
  let miss = Polyglot_rtl_dut.Rtl_dut.missing_ports () in
  if miss <> [] then Printf.printf "RTL ports missing from the circuit: %s\n" (String.concat " " miss);
  Printf.printf "triage on %s: %d cases, %d passed, %d failed, %d compared cycles, %.1f s\n" dut
    count passed (List.length fails) cycles secs;
  let classes = Hashtbl.create 16 in
  List.iter
    (fun (i, c, (f : Lockstep.failure)) ->
      let run_cycle = f.Lockstep.cycle - Case.load_cycles in
      let key =
        Printf.sprintf "%s [%s]" (port_base f.Lockstep.port) (window_kinds c run_cycle)
      in
      let prev = Option.value (Hashtbl.find_opt classes key) ~default:[] in
      Hashtbl.replace classes key ((i, c, f) :: prev))
    fails;
  let rows =
    Hashtbl.fold (fun k v acc -> (k, List.rev v) :: acc) classes []
    |> List.sort (fun (_, a) (_, b) -> compare (List.length b) (List.length a))
  in
  List.iter
    (fun (key, members) ->
      let i, _, (f : Lockstep.failure) = List.hd members in
      Printf.printf "class %-45s count %4d  first: case %d, %s, port %s, ref=0x%x dut=0x%x\n" key
        (List.length members) i (Lockstep.describe_cycle f.Lockstep.cycle) f.Lockstep.port f.Lockstep.reference
        f.Lockstep.dut)
    rows;
  List.iteri
    (fun k (key, members) ->
      let _, c, f = List.hd members in
      let shrunk, sf, steps = Gen.shrink_failing ~check:(check ~dut) ~limit:400 c f in
      let file =
        Filename.concat out_dir
          (Printf.sprintf "class_%02d_%s.json" (k + 1)
             (String.map (fun ch -> if ch = ' ' || ch = '[' || ch = ']' || ch = '+' then '_' else ch) key))
      in
      Case.write_file file shrunk;
      Printf.printf "shrunk class %d (%s): %s, port %s, ref=0x%x dut=0x%x, %d shrink steps -> %s\n"
        (k + 1) key (Lockstep.describe_cycle sf.Lockstep.cycle) sf.Lockstep.port sf.Lockstep.reference
        sf.Lockstep.dut steps file)
    rows;
  if fails = [] then 0 else 1
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

(* Probe the RTL: print the register outputs after reset and over the first idle cycles. *)
let cmd_rtl_probe args =
  let num_sms = int_flag args "--sms" 4 in
  let d = Polyglot_rtl_dut.Rtl_dut.create ~num_sms in
  let show tag =
    let o = d.Dut.regs (Ports.idle ~rst_n:true) in
    Printf.printf "%-12s fstat=%x flevel=%x fdebug=%x pins_oe=%x irq=%x phase0=%x\n" tag
      o.Ports.fstat o.Ports.flevel o.Ports.fdebug o.Ports.pins_oe o.Ports.irq o.Ports.phase.(0)
  in
  show "after reset";
  for c = 0 to 2 do
    ignore (d.Dut.cycle (Ports.idle ~rst_n:true));
    show (Printf.sprintf "idle %d" c)
  done;
  (* Mid-run reset: rst_n low for two cycles, then high. *)
  for c = 0 to 1 do
    ignore (d.Dut.cycle (Ports.idle ~rst_n:false));
    show (Printf.sprintf "rst_n low %d" c)
  done;
  ignore (d.Dut.cycle (Ports.idle ~rst_n:true));
  show "after reset";
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
    | _ :: "rtl-probe" :: args -> cmd_rtl_probe args
    | _ :: "triage" :: args -> cmd_triage args
    | _ ->
      prerr_endline
        "usage: lockstep_cli (gen|replay FILE|corpus|mutants|write-cases DIR) [options]";
      2
  in
  exit code
;;
