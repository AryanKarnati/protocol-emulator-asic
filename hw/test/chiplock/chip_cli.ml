(* chip_cli: the top-level lockstep from the command line (docs/chip.md 11).
   triage  --count N --seed S --sms K [--cycles C] [--out-dir D]   random chip cases
   replay  FILE [--dut rtl]                                        one case file
   shrink  FILE --out PATH                                         shrink a failing case file
   corpus  [--sms K] [--cycles C] [--dir D]                        the pico-examples corpus
   gen     --seed S --sms K --out PATH                             write one generated case *)

open Polyglot_chiplock

let flag args name default =
  let rec go = function
    | k :: v :: _ when k = name -> v
    | _ :: rest -> go rest
    | [] -> default
  in
  go args
;;

let int_flag args name default = int_of_string (flag args name (string_of_int default))

let report label = function
  | Chip_lockstep.Pass { cycles } -> Printf.printf "%s: pass, %d cycles\n" label cycles
  | Chip_lockstep.Fail f -> Printf.printf "%s: %s\n" label (Chip_lockstep.describe f)
;;

let cmd_triage args =
  let count = int_flag args "--count" 100 in
  let seed = int_flag args "--seed" 1 in
  let sms = int_flag args "--sms" 4 in
  let cycles = int_flag args "--cycles" 4000 in
  let out_dir = flag args "--out-dir" "." in
  let t0 = Sys.time () in
  let passed = ref 0 and failed = ref 0 and total = ref 0 in
  for i = 0 to count - 1 do
    let c = Chip_gen.generate ~target:cycles ~seed:((seed * 1_000_003) + i) ~num_sms:sms () in
    total := !total + Array.length c.Chip_case.cycles;
    match Chip_lockstep.run c with
    | Chip_lockstep.Pass _ -> incr passed
    | Chip_lockstep.Fail f ->
      incr failed;
      let shrunk, sf, steps = Chip_lockstep.shrink c f in
      let path = Filename.concat out_dir (Printf.sprintf "chip_fail_%d_%d.json" seed i) in
      Chip_case.write_file path shrunk;
      Printf.printf "case %d: %s\n  shrunk in %d runs to %d cycles: %s\n  -> %s\n" i
        (Chip_lockstep.describe f) steps (Array.length shrunk.Chip_case.cycles)
        (Chip_lockstep.describe sf) path
  done;
  let secs = Sys.time () -. t0 in
  Printf.printf
    "chip triage: %d cases at %d SMs (seed %d): %d passed, %d failed, %d cycles, %.1f s (%.2f cases/s, %.0f cycles/s)\n"
    count sms seed !passed !failed !total secs
    (float_of_int count /. secs)
    (float_of_int !total /. secs);
  if !failed = 0 then 0 else 1
;;

let cmd_replay args file =
  let c = Chip_case.normalise (Chip_case.read_file file) in
  ignore args;
  match Chip_lockstep.run c with
  | Chip_lockstep.Pass _ as o ->
    report ("replay " ^ file) o;
    0
  | Chip_lockstep.Fail _ as o ->
    report ("replay " ^ file) o;
    1
;;

let cmd_shrink args file =
  let out = flag args "--out" "shrunk_chip.json" in
  let c = Chip_case.normalise (Chip_case.read_file file) in
  match Chip_lockstep.run c with
  | Chip_lockstep.Pass _ ->
    Printf.printf "shrink %s: passes, nothing to shrink\n" file;
    0
  | Chip_lockstep.Fail f ->
    let shrunk, sf, steps = Chip_lockstep.shrink c f in
    Chip_case.write_file out shrunk;
    Printf.printf "shrunk %s in %d runs to %d cycles: %s -> %s\n" file steps
      (Array.length shrunk.Chip_case.cycles) (Chip_lockstep.describe sf) out;
    1
;;

let cmd_corpus args =
  let sms = int_flag args "--sms" 4 in
  let cycles = int_flag args "--cycles" 3000 in
  let dir = flag args "--dir" "sw/pgasm/test/corpus" in
  let cases = Polyglot_lockstep.Corpus.cases ~cycles ~dir () in
  let fails = ref 0 in
  List.iter
    (fun (name, lc) ->
      let c = Chip_gen.corpus ~cycles ~num_sms:sms lc in
      match Chip_lockstep.run c with
      | Chip_lockstep.Pass _ -> ()
      | Chip_lockstep.Fail f ->
        incr fails;
        Printf.printf "corpus %s: %s\n" name (Chip_lockstep.describe f))
    cases;
  Printf.printf "chip corpus: %d programs at %d SMs through the host link, %d failed\n"
    (List.length cases) sms !fails;
  if !fails = 0 then 0 else 1
;;

(* trace FILE --from A --to B: the pins and the model's pads of each cycle in the range. *)
let cmd_trace args file =
  let c = Chip_case.normalise (Chip_case.read_file file) in
  let from = int_flag args "--from" 0 and upto = int_flag args "--to" 40 in
  let m = Chip.create ~num_sms:c.Chip_case.num_sms () in
  Array.iteri
    (fun k (y : Chip_case.cyc) ->
      if y.rst then Chip.reset m
      else (
        (match (Pgsim.debug (Chip.pio m) 0).Pgsim.latch with
         | Pgsim.Host_latch w -> Printf.printf "LATCH at %d word %04x\n" k w
         | _ -> ());
        let o = Chip.step m ~ui_in:y.ui ~uio_ext:y.uio in
        if o.Chip.bus.Chip.write then Printf.printf "WRITE at %d addr %04x data %08x\n" k o.Chip.bus.Chip.addr o.Chip.bus.Chip.wdata;
        if k >= from && k <= upto then (let (f, r) = Chip.frame_state m in Printf.printf "FS %d ui=%02x open=%b rises=%d\n" k y.ui f r);
        if (o.Chip.bus.Chip.read || o.Chip.bus.Chip.commit) && k >= from && k <= upto then Printf.printf "BUS at %d read=%b commit=%b addr %04x\n" k o.Chip.bus.Chip.read o.Chip.bus.Chip.commit o.Chip.bus.Chip.addr;
        if k >= from && k <= upto then
          Printf.printf "%5d ui=%02x uio=%02x uo=%02x uio_out=%02x uio_oe=%02x\n" k y.ui y.uio o.Chip.uo_out
            o.Chip.uio_out o.Chip.uio_oe))
    c.Chip_case.cycles;
  0
;;

(* coverage --count N --seed S --sms K [--cycles C]: the scenarios of N generated cases. *)
let cmd_coverage args =
  let count = int_flag args "--count" 2000 in
  let seed = int_flag args "--seed" 1 in
  let sms = int_flag args "--sms" 4 in
  let cycles = int_flag args "--cycles" 3000 in
  let hits = Hashtbl.create 16 in
  let total = ref 0 in
  for i = 0 to count - 1 do
    let c = Chip_gen.generate ~target:cycles ~seed:((seed * 1_000_003) + i) ~num_sms:sms () in
    total := !total + Array.length c.Chip_case.cycles;
    List.iter
      (fun (name, hit) -> if hit then Hashtbl.replace hits name (1 + Option.value ~default:0 (Hashtbl.find_opt hits name)))
      (Chip_gen.chip_scenarios c)
  done;
  Printf.printf "chip coverage over %d cases at %d SMs (seed %d, %d cycles):\n" count sms seed !total;
  List.iter
    (fun name -> Printf.printf "  %-55s %5d\n" name (Option.value ~default:0 (Hashtbl.find_opt hits name)))
    Chip_gen.chip_scenario_names;
  0
;;

let cmd_gen args =
  let seed = int_flag args "--seed" 1 in
  let sms = int_flag args "--sms" 4 in
  let out = flag args "--out" "chip_case.json" in
  Chip_case.write_file out (Chip_gen.generate ~seed ~num_sms:sms ());
  Printf.printf "wrote %s\n" out;
  0
;;

let () =
  let argv = Array.to_list Sys.argv in
  let code =
    match argv with
    | _ :: "triage" :: args -> cmd_triage args
    | _ :: "replay" :: file :: args -> cmd_replay args file
    | _ :: "shrink" :: file :: args -> cmd_shrink args file
    | _ :: "corpus" :: args -> cmd_corpus args
    | _ :: "gen" :: args -> cmd_gen args
    | _ :: "coverage" :: args -> cmd_coverage args
    | _ :: "trace" :: file :: args -> cmd_trace args file
    | _ ->
      prerr_endline "usage: chip_cli (triage|replay FILE|shrink FILE|corpus|gen) [options]";
      2
  in
  exit code
;;
