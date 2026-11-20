(* Walks a source file line by line, handling multi-line code blocks as pioasm's lexer does
   (lexer.ll, code_block state):

   - A line whose first non-blank character is '%' starts a code block:
       % <lang> {
     The language is the text between '%' and '{', trimmed. Empty means "c-sdk".
   - Contents run until a line that starts with "%}" in column 1. Text after "%}" is ignored.
   - Blank lines and leading/trailing blanks of blank lines are dropped. Other lines are
     kept whole, with a trailing newline. *)

open Core
open Pio_lex

type event =
  | Line of int * Pio_parse.line
  | Code of loc * string * string (** location, language, contents *)

let is_blank_line s = String.for_all s ~f:is_blank

let default_lang = "c-sdk"

(* Calls [f] for each event in source order. Parse errors propagate as [Pio_lex.Error]. *)
let iter_events ~file (text : string) ~(f : event -> unit) =
  let lines = Array.of_list (String.split text ~on:'\n') in
  let n = Array.length lines in
  let idx = ref 0 in
  (* state of a /* ... */ comment that is still open at the start of the current line *)
  let in_comment = ref false in
  (* A /* comment still open at the end of a line does not end the statement: pioasm's
     lexer emits no newline token inside a comment, so the next line continues it. *)
  let pending : string option ref = ref None in
  let pending_line = ref 0 in
  let flush () =
    match !pending with
    | None -> ()
    | Some text ->
      pending := None;
      f (Line (!pending_line, Pio_parse.parse_line ~file ~lineno:!pending_line text))
  in
  while !idx < n do
    let lineno = !idx + 1 in
    let raw = lines.(!idx) in
    let first =
      let k = ref 0 in
      while !k < String.length raw && is_blank raw.[!k] do
        incr k
      done;
      !k
    in
    if (not !in_comment) && first < String.length raw && Char.equal raw.[first] '%'
    then (
      let loc = { file; line = lineno; col = first + 1 } in
      let brace =
        match String.index_from raw first '{' with
        | Some b -> b
        | None -> raise (Error (loc, "invalid code block start: expected '{' after '%'"))
      in
      let lang_raw = String.sub raw ~pos:(first + 1) ~len:(brace - first - 1) in
      let lang = String.strip lang_raw in
      let lang = if String.is_empty lang then default_lang else lang in
      let buf = Buffer.create 256 in
      let add_line s =
        if not (is_blank_line s)
        then (
          Buffer.add_string buf s;
          Buffer.add_char buf '\n')
      in
      (* text after '{' on the start line *)
      let rest = String.drop_prefix raw (brace + 1) in
      let ends = ref false in
      if String.is_prefix rest ~prefix:"%}"
      then ends := true
      else add_line rest;
      incr idx;
      while (not !ends) && !idx < n do
        let s = lines.(!idx) in
        if String.is_prefix s ~prefix:"%}"
        then ends := true
        else add_line s;
        incr idx
      done;
      if not !ends
      then raise (Error (loc, "code block is not terminated by '%}'"));
      f (Code (loc, lang, Buffer.contents buf)))
    else (
      (* .lang_opt lines are lexed in their own mode, where /* is not a comment *)
      let in_lang_opt =
        String.is_prefix (String.lowercase (String.lstrip raw)) ~prefix:".lang_opt"
      in
      let cleaned =
        if in_lang_opt then raw else Pio_lex.blank_block_comments ~in_comment raw
      in
      if !in_comment && not in_lang_opt
      then (
        (match !pending with
         | None ->
           pending := Some (cleaned ^ " ");
           pending_line := lineno
         | Some p -> pending := Some (p ^ cleaned ^ " "))
      )
      else (
        (match !pending with
         | None -> pending_line := lineno; pending := Some cleaned
         | Some p -> pending := Some (p ^ cleaned));
        flush ());
      incr idx)
  done;
  flush ()
;;
