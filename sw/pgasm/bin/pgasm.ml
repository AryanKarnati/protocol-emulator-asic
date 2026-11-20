(* pgasm: assembles pioasm syntax (PIO version 0) to hex or JSON. The output is byte-identical
   to pioasm 2.3.1 for the programs in the golden corpus.

   Usage: pgasm [-o json|hex] [--program NAME] INPUT [OUTPUT]
   OUTPUT defaults to stdout. -o hex needs a single program, or --program NAME. *)

open Core
open Pgasm_lib

let usage () =
  Stdlib.prerr_endline "usage: pgasm [-o json|hex] [--program NAME] INPUT [OUTPUT]";
  Stdlib.exit 2
;;

let () =
  let args = List.tl_exn (Array.to_list (Sys.get_argv ())) in
  let fmt = ref "json" in
  let prog = ref None in
  let rec parse acc = function
    | "-o" :: f :: rest ->
      fmt := f;
      parse acc rest
    | "--program" :: n :: rest ->
      prog := Some n;
      parse acc rest
    | x :: rest -> parse (x :: acc) rest
    | [] -> List.rev acc
  in
  let positional = parse [] args in
  let input, output =
    match positional with
    | [ i ] -> i, None
    | [ i; o ] -> i, Some o
    | _ -> usage ()
  in
  let text = In_channel.read_all input in
  let emit s =
    match output with
    | None -> Out_channel.output_string Out_channel.stdout s
    | Some o -> Out_channel.write_all o ~data:s
  in
  match Pio_asm.assemble ~file:input text with
  | exception Pio_lex.Error (loc, msg) ->
    Stdlib.prerr_endline (Pio_lex.loc_to_string loc ^ ": " ^ msg);
    Stdlib.exit 1
  | progs, global_syms ->
    (match !fmt with
     | "json" -> emit (Pio_out.to_json progs global_syms)
     | "hex" ->
       let chosen =
         match !prog, progs with
         | Some n, _ ->
           (match List.find progs ~f:(fun (p : Pio_asm.out_prog) -> String.equal p.name n) with
            | Some p -> p
            | None ->
              Stdlib.prerr_endline ("no program " ^ n);
              Stdlib.exit 1)
         | None, [ p ] -> p
         | None, _ ->
           Stdlib.prerr_endline "hex output needs a single program, or --program NAME";
           Stdlib.exit 1
       in
       emit (Pio_out.to_hex chosen)
     | f ->
       Stdlib.prerr_endline ("unsupported output format: " ^ f ^ " (pgasm supports json and hex)");
       Stdlib.exit 1)
;;
