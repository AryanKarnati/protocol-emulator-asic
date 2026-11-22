(* pgasm: assembles pioasm syntax (PIO version 0) to hex, JSON, python or c-sdk. The output is
   byte-identical to pioasm 2.3.1 for the programs in the golden corpus.

   Usage: pgasm [-o json|hex|python|c-sdk] [--program NAME] INPUT [OUTPUT]
   INPUT and OUTPUT may be "-" for stdin and stdout. OUTPUT defaults to stdout.
   -o hex needs a single program, or --program NAME. *)

open Core
open Pgasm_lib

let fail msg =
  Stdlib.prerr_endline ("pgasm: " ^ msg);
  Stdlib.prerr_endline "usage: pgasm [-o json|hex|python|c-sdk] [--program NAME] INPUT [OUTPUT]";
  Stdlib.exit 2
;;

type args =
  { fmt : string
  ; prog : string option
  ; input : string
  ; output : string option
  }

let parse_args (argv : string list) : args =
  let rec go fmt prog positional = function
    | [] -> fmt, prog, List.rev positional
    | "-o" :: [] | "--program" :: [] -> fail "option needs a value"
    | "-o" :: f :: rest -> go f prog positional rest
    | "--program" :: n :: rest -> go fmt (Some n) positional rest
    | "-" :: rest -> go fmt prog ("-" :: positional) rest
    | x :: _ when String.is_prefix x ~prefix:"-" -> fail ("unknown option: " ^ x)
    | x :: rest -> go fmt prog (x :: positional) rest
  in
  let fmt, prog, positional = go "json" None [] argv in
  match positional with
  | [ input ] -> { fmt; prog; input; output = None }
  | [ input; output ] -> { fmt; prog; input; output = Some output }
  | [] -> fail "missing INPUT"
  | _ -> fail "too many arguments"
;;

let () =
  let a = parse_args (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let text =
    if String.equal a.input "-"
    then In_channel.input_all In_channel.stdin
    else (
      try In_channel.read_all a.input with
      | Stdlib.Sys_error _ ->
        Stdlib.prerr_endline ("pgasm: can't open input file '" ^ a.input ^ "'");
        Stdlib.exit 1)
  in
  let emit s =
    match a.output with
    | None | Some "-" -> Out_channel.output_string Out_channel.stdout s
    | Some o ->
      (try Out_channel.write_all o ~data:s with
       | Stdlib.Sys_error _ ->
         Stdlib.prerr_endline ("pgasm: can't open output file '" ^ o ^ "'");
         Stdlib.exit 1)
  in
  let warn_c_sdk_lang_opts progs =
    (* pioasm's c-sdk writer ignores .lang_opt for its own language, and says so *)
    List.iter progs ~f:(fun (p : Pio_asm.out_prog) ->
      List.iter p.lang_opts ~f:(fun (lang, _) ->
        if String.is_prefix lang ~prefix:"c-sdk"
        then
          Stdlib.prerr_endline
            ("warning: c-sdk does not support output options; " ^ lang ^ " lang_opt ignored.")))
  in
  let file = if String.equal a.input "-" then "<stdin>" else a.input in
  match Pio_asm.assemble ~file text with
  | exception Pio_lex.Error (loc, msg) ->
    Stdlib.prerr_endline (Pio_lex.loc_to_string loc ^ ": " ^ msg);
    Stdlib.exit 1
  | progs, global_syms ->
    (match a.fmt with
     | "json" -> emit (Pio_out.to_json progs global_syms)
     | "hex" ->
       let chosen =
         match a.prog, progs with
         | Some n, _ ->
           (match List.find progs ~f:(fun (p : Pio_asm.out_prog) -> String.equal p.name n) with
            | Some p -> p
            | None ->
              Stdlib.prerr_endline ("pgasm: no program " ^ n);
              Stdlib.exit 1)
         | None, [ p ] -> p
         | None, _ ->
           Stdlib.prerr_endline "pgasm: hex output needs a single program, or --program NAME";
           Stdlib.exit 1
       in
       emit (Pio_out.to_hex chosen)
     | "python" -> emit (Pio_out.to_python progs global_syms)
     | "c-sdk" ->
       warn_c_sdk_lang_opts progs;
       emit (Pio_out.to_c_sdk progs global_syms)
     | f ->
       Stdlib.prerr_endline
         ("pgasm: unsupported output format: " ^ f ^ " (supported: json, hex, python, c-sdk)");
       Stdlib.exit 1)
;;
