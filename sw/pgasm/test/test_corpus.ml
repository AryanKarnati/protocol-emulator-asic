(* pgasm regression tests. Run with: opam exec --switch=polyglot -- dune test --root .

   1. Corpus: every .pio in corpus/pico-examples is assembled, and the output is compared with
      what the official pioasm 2.3.1 wrote (sw/pgasm/oracle/make_corpus.sh), byte for byte:
      <file>.pio.json, <file>.pio.<prog>.hex, <file>.pio.c-sdk.h and <file>.pio.python.py.
   2. Edge cases in edge/: each snippet has pioasm's JSON (<name>.pio.json, accepted) or a
      marker (<name>.pio.oracle-error, rejected). pgasm must agree.
   3. Isa consistency: every word that pgasm assembles from a non-.word source satisfies
      Isa.encode (Isa.decode w) = w, and Isa.is_legal, except IN source 101 (in status), which
      pioasm accepts and the chip treats as reserved.
   4. Word sweep: all 65536 words, 32 per program (2048 programs). The per-chunk MD5 of pgasm's
      JSON is compared with the MD5 of pioasm -v 0's JSON stored in word_sweep.md5, one line
      per chunk of 8 programs (256 words). Produced by oracle/word_sweep.py. *)

open Core
open Pgasm_lib

let corpus = "corpus/pico-examples"
let edge_dir = "edge"

(* Exact counts. A corpus or edge directory that is missing or empty fails here. *)
let expected_corpus_files = 26
let expected_corpus_programs = 36
let expected_edge_cases = 71
let expected_sweep_chunks = 256

let rec walk dir ~suffix =
  Stdlib.Sys.readdir dir
  |> Array.to_list
  |> List.sort ~compare:String.compare
  |> List.concat_map ~f:(fun name ->
    let path = Filename.concat dir name in
    if Stdlib.Sys.is_directory path
    then walk path ~suffix
    else if String.is_suffix path ~suffix
    then [ path ]
    else [])
;;

let read path = In_channel.read_all path

(* An expected output from pioasm. An empty one is a broken corpus, not a pass. *)
let read_expected path =
  let s = read path in
  if String.is_empty s then failwith ("empty expected output: " ^ path);
  s
;;
let failures = ref 0

let fail fmt =
  Printf.ksprintf
    (fun s ->
      incr failures;
      Stdlib.print_endline s)
    fmt
;;

(* 3. Isa consistency for the words of one assembled program. *)
let check_isa ~name (p : Pio_asm.out_prog) =
  List.iter p.words ~f:(fun w ->
    match Polyglot_isa.Isa.decode w with
    | Polyglot_isa.Isa.In { source = Polyglot_isa.Isa.In_status; _ } -> ()
    | t ->
      if Polyglot_isa.Isa.encode t <> w
      then fail "FAIL: isa %s: encode (decode 0x%04x) differs" name w;
      if not (Polyglot_isa.Isa.is_legal t)
      then fail "FAIL: isa %s: 0x%04x is not legal" name w)
;;

(* 4. The sweep program for index k: words 32k .. 32k+31, as .word lines. *)
let sweep_source k =
  let b = Buffer.create 1024 in
  Buffer.add_string b (sprintf ".program w%04d\n" k);
  for j = 0 to 31 do
    Buffer.add_string b (sprintf "    .word 0x%04x\n" ((32 * k) + j))
  done;
  Buffer.contents b
;;

let sweep_chunk_digest c =
  let b = Buffer.create 8192 in
  for k = 8 * c to (8 * c) + 7 do
    match Pio_asm.assemble ~file:"<word sweep>" (sweep_source k) with
    | exception Pio_lex.Error (loc, msg) ->
      fail "FAIL: sweep program %d: %s: %s" k (Pio_lex.loc_to_string loc) msg
    | progs, global_syms -> Buffer.add_string b (Pio_out.to_json progs global_syms)
  done;
  Stdlib.Digest.to_hex (Stdlib.Digest.string (Buffer.contents b))
;;

let () =
  (* 1. corpus *)
  let files = walk corpus ~suffix:".pio" in
  let json_ok = ref 0 in
  let prog_ok = ref 0 in
  let prog_total = ref 0 in
  let c_sdk_ok = ref 0 in
  let python_ok = ref 0 in
  List.iter files ~f:(fun file ->
    let text = read file in
    match Pio_asm.assemble ~file text with
    | exception Pio_lex.Error (loc, msg) ->
      fail "FAIL: %s: %s: %s" file (Pio_lex.loc_to_string loc) msg
    | progs, global_syms ->
      let json = Pio_out.to_json progs global_syms in
      if String.equal json (read_expected (file ^ ".json"))
      then Int.incr json_ok
      else fail "FAIL: %s: JSON differs from pioasm output" file;
      if String.equal (Pio_out.to_c_sdk progs global_syms) (read_expected (file ^ ".c-sdk.h"))
      then Int.incr c_sdk_ok
      else fail "FAIL: %s: c-sdk output differs from pioasm output" file;
      if String.equal (Pio_out.to_python progs global_syms) (read_expected (file ^ ".python.py"))
      then Int.incr python_ok
      else fail "FAIL: %s: python output differs from pioasm output" file;
      List.iter progs ~f:(fun (p : Pio_asm.out_prog) ->
        Int.incr prog_total;
        if String.equal (Pio_out.to_hex p) (read_expected (sprintf "%s.%s.hex" file p.name))
        then Int.incr prog_ok
        else fail "FAIL: %s [%s]: hex differs from pioasm output" file p.name;
        check_isa ~name:file p));
  if List.length files <> expected_corpus_files
  then fail "FAIL: corpus has %d files, expected %d" (List.length files) expected_corpus_files;
  if !prog_total <> expected_corpus_programs
  then fail "FAIL: corpus has %d programs, expected %d" !prog_total expected_corpus_programs;
  printf
    "corpus: %d/%d programs byte-identical (hex); %d/%d files (JSON), %d/%d (c-sdk), %d/%d (python)\n"
    !prog_ok
    !prog_total
    !json_ok
    (List.length files)
    !c_sdk_ok
    (List.length files)
    !python_ok
    (List.length files);
  (* 2. edge cases. The only known gap is .pio_version 1, which is a documented non-goal
     (see sw/pgasm/README.md). *)
  let known_gaps = [ "pio_version1_pindirs.pio" ] in
  let edge = walk edge_dir ~suffix:".pio" in
  let edge_ok = ref 0 in
  List.iter edge ~f:(fun file ->
    let name = Filename.basename file in
    let text = read file in
    let oracle_rejects = Stdlib.Sys.file_exists (file ^ ".oracle-error") in
    let is_known_gap = List.mem known_gaps name ~equal:String.equal in
    match Pio_asm.assemble ~file text with
    | exception Pio_lex.Error (loc, msg) ->
      if oracle_rejects || is_known_gap
      then Int.incr edge_ok
      else fail "FAIL: edge %s: pgasm rejects, pioasm accepts: %s: %s" name (Pio_lex.loc_to_string loc) msg
    | progs, global_syms ->
      if oracle_rejects
      then fail "FAIL: edge %s: pgasm accepts, pioasm rejects" name
      else if is_known_gap
      then fail "FAIL: edge %s: listed as a known gap but pgasm accepts it now" name
      else if String.equal (Pio_out.to_json progs global_syms) (read (file ^ ".json"))
      then (
        Int.incr edge_ok;
        if not (String.is_substring text ~substring:".word")
        then List.iter progs ~f:(check_isa ~name:file))
      else fail "FAIL: edge %s: JSON differs from pioasm" name);
  if List.length edge <> expected_edge_cases
  then fail "FAIL: %d edge cases, expected %d" (List.length edge) expected_edge_cases;
  printf "edge: %d/%d cases agree with pioasm (%d known gap)\n" !edge_ok (List.length edge) (List.length known_gaps);
  (* 4. word sweep *)
  let stored =
    In_channel.read_lines "word_sweep.md5"
    |> List.filter_map ~f:(fun l ->
      match String.split l ~on:' ' with
      | [ idx; md5 ] -> Some (Int.of_string idx, md5)
      | _ -> None)
  in
  if List.length stored <> expected_sweep_chunks
  then fail "FAIL: word_sweep.md5 has %d chunks, expected %d" (List.length stored) expected_sweep_chunks;
  let sweep_ok = ref 0 in
  List.iter stored ~f:(fun (c, md5) ->
    if String.equal (sweep_chunk_digest c) md5 then Int.incr sweep_ok
    else fail "FAIL: word sweep chunk %d differs from pioasm" c);
  printf "word sweep: %d/%d chunks of 256 words agree with pioasm (65536 words)\n" !sweep_ok (List.length stored);
  if !failures > 0
  then (
    printf "%d failure(s)\n" !failures;
    Stdlib.exit 1)
;;
