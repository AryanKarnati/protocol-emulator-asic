(* Byte-identity test: every .pio in the golden corpus is assembled by pgasm and compared with
   the outputs that the official pioasm 2.3.1 wrote (see sw/pgasm/oracle/make_corpus.sh):
   - <file>.pio.json      whole-file JSON, byte for byte
   - <file>.pio.<prog>.hex one hex file per program, byte for byte

   Run with: opam exec --switch=polyglot -- dune test --root .  *)

open Core
open Pgasm_lib

let corpus = "corpus/pico-examples"

let rec walk dir =
  Stdlib.Sys.readdir dir
  |> Array.to_list
  |> List.sort ~compare:String.compare
  |> List.concat_map ~f:(fun name ->
    let path = Filename.concat dir name in
    if Stdlib.Sys.is_directory path
    then walk path
    else if String.is_suffix path ~suffix:".pio"
    then [ path ]
    else [])
;;

let read path = In_channel.read_all path

let () =
  let files = walk corpus in
  let failures = ref 0 in
  let fail fmt = Printf.ksprintf (fun s -> incr failures; Stdlib.print_endline s) fmt in
  let json_ok = ref 0 in
  let prog_ok = ref 0 in
  let prog_total = ref 0 in
  List.iter files ~f:(fun file ->
    let text = read file in
    match Pio_asm.assemble ~file text with
    | exception Pio_lex.Error (loc, msg) ->
      fail "FAIL: %s: %s: %s" file (Pio_lex.loc_to_string loc) msg
    | progs, global_syms ->
      let json = Pio_out.to_json progs global_syms in
      let expected_json = read (file ^ ".json") in
      if String.equal json expected_json
      then Int.incr json_ok
      else fail "FAIL: %s: JSON differs from pioasm output" file;
      List.iter progs ~f:(fun (p : Pio_asm.out_prog) ->
        Int.incr prog_total;
        let hex_file = sprintf "%s.%s.hex" file p.name in
        let expected_hex = read hex_file in
        if String.equal (Pio_out.to_hex p) expected_hex
        then Int.incr prog_ok
        else fail "FAIL: %s [%s]: hex differs from pioasm output" file p.name));
  printf
    "corpus: %d/%d programs byte-identical (hex); %d/%d files byte-identical (JSON); %d files\n"
    !prog_ok
    !prog_total
    !json_ok
    (List.length files)
    (List.length files);
  (* Edge cases, with the oracle's output stored next to each snippet. A case with a .json file
     was accepted by pioasm; a case with a .oracle-error file was rejected by it. *)
  let known_gaps =
    (* accepted by pioasm, rejected by pgasm on purpose:
       - .mov_status: a v0 directive pgasm does not implement yet
       - .pio_version 1: PIO version 1 is block 5 *)
    [ "mov_status.pio"; "pio_version1_pindirs.pio" ]
  in
  let edge = walk "edge" in
  let edge_ok = ref 0 in
  List.iter edge ~f:(fun file ->
    let name = Filename.basename file in
    let text = read file in
    let is_known_gap = List.mem known_gaps name ~equal:String.equal in
    match Pio_asm.assemble ~file text with
    | exception Pio_lex.Error (loc, msg) ->
      if Stdlib.Sys.file_exists (file ^ ".oracle-error") || is_known_gap
      then Int.incr edge_ok
      else fail "FAIL: edge %s: pgasm rejects, pioasm accepts: %s: %s" name (Pio_lex.loc_to_string loc) msg
    | progs, global_syms ->
      if Stdlib.Sys.file_exists (file ^ ".oracle-error")
      then fail "FAIL: edge %s: pgasm accepts, pioasm rejects" name
      else if is_known_gap
      then fail "FAIL: edge %s: listed as a known gap but pgasm accepts it now" name
      else if String.equal (Pio_out.to_json progs global_syms) (read (file ^ ".json"))
      then Int.incr edge_ok
      else fail "FAIL: edge %s: JSON differs from pioasm" name);
  printf "edge: %d/%d cases agree with pioasm (%d known gaps)\n" !edge_ok (List.length edge) (List.length known_gaps);
  if !failures > 0 || !prog_ok <> !prog_total || !json_ok <> List.length files
  then (
    printf "%d failure(s)\n" !failures;
    Stdlib.exit 1)
;;
