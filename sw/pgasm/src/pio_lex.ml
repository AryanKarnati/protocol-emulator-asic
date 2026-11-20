(* Lexer for pioasm syntax, following pioasm 2.3.1 lexer.ll.

   Keywords are case-insensitive, as in pioasm (%option case-insensitive). The lexer works
   one source line at a time. Code blocks (% lang { ... %}) span lines and are handled by
   [Pio_source], not here. *)

open Core

type loc =
  { file : string
  ; line : int
  ; col : int
  }
[@@deriving sexp_of]

let loc_to_string { file; line; col } = sprintf "%s:%d.%d" file line col

exception Error of loc * string

type tok =
  | Kw of string (** keyword, canonical lowercase *)
  | Dir of string (** known directive, lowercase, without the dot *)
  | Id of string (** identifier, original spelling *)
  | Int of int
  | Float of float
  | Op of string (** punctuation and operators *)
  | Str of string (** .lang_opt string, raw including quotes *)
  | Raw of string (** .lang_opt word that is not an integer *)

type token =
  { tok : tok
  ; col : int
  }

let keywords =
  String.Set.of_list
    [ "jmp"; "wait"; "in"; "out"; "push"; "pull"; "mov"; "irq"; "set"; "nop"
    ; "public"; "opt"; "side"; "pin"; "gpio"; "osre"; "jmppin"; "prev"; "next"
    ; "pins"; "null"; "pindirs"; "block"; "noblock"; "ifempty"; "iffull"
    ; "nowait"; "clear"; "rel"; "x"; "y"; "pc"; "exec"; "isr"; "osr"; "status"
    ; "txrx"; "tx"; "rx"; "txput"; "txget"; "putget"; "left"; "right"; "auto"
    ; "manual"; "rxfifo"; "txfifo"; "rp2040"; "rp2350"
    ]
;;

(* Spelling variants that pioasm maps to the same token. *)
let canonical_kw = function
  | "optional" -> "opt"
  | "sideset" | "side_set" -> "side"
  | s -> s
;;

let directives =
  String.Set.of_list
    [ "program"; "wrap_target"; "wrap"; "word"; "define"; "side_set"; "origin"
    ; "lang_opt"; "pio_version"; "clock_div"; "fifo"; "mov_status"; "set"; "out"; "in"
    ]
;;

let is_blank c = Char.equal c ' ' || Char.equal c '\t' || Char.equal c '\r'
let is_digit c = Char.is_digit c
let is_hex c = Char.is_digit c || Char.between (Char.lowercase c) ~low:'a' ~high:'f'
let is_bin c = Char.equal c '0' || Char.equal c '1'
let is_id_start c = Char.is_alpha c || Char.equal c '_'
let is_id_char c = Char.is_alphanum c || Char.equal c '_'

(* Integer literal as make_INT / make_HEX / make_BINARY: must fit in a C int. *)
let int_of_literal ~loc s =
  let fail what = raise (Error (loc, sprintf "%s is out of range: %s" what s)) in
  let check n = if n >= 0 && n <= 0x7FFF_FFFF then n else fail "integer" in
  (* pioasm's lexer is case-insensitive, so 0X1F and 0B101 are valid *)
  let lw = String.lowercase s in
  if String.is_prefix lw ~prefix:"0x"
  then (
    match Int.of_string_opt ("0x" ^ String.drop_prefix lw 2) with
    | Some n when n >= 0 && n <= 0x7FFF_FFFF -> n
    | _ -> fail "hex")
  else if String.is_prefix lw ~prefix:"0b"
  then (
    match Int.of_string_opt ("0b" ^ String.drop_prefix lw 2) with
    | Some n when n >= 0 && n <= 0x7FFF_FFFF -> n
    | _ -> fail "binary")
  else (
    match Int.of_string_opt s with
    | Some n -> check n
    | None -> fail "integer")
;;

(* Replace block comments with spaces, so that the rest of the line keeps its columns.
   [in_comment] carries "inside a /* ... */" across lines, as pioasm's c_comment state does.
   A ';' or "//" ends the scan of the line, as in pioasm. *)
let blank_block_comments ~(in_comment : bool ref) (text : string) : string =
  let n = String.length text in
  let b = Bytes.of_string text in
  let i = ref 0 in
  let stop = ref false in
  while (not !stop) && !i < n do
    if !in_comment
    then (
      if !i + 1 < n && Char.equal text.[!i] '*' && Char.equal text.[!i + 1] '/'
      then (
        Bytes.set b !i ' ';
        Bytes.set b (!i + 1) ' ';
        in_comment := false;
        i := !i + 2)
      else (
        if not (Char.equal text.[!i] '\r') then Bytes.set b !i ' ';
        incr i))
    else if Char.equal text.[!i] ';'
            || (Char.equal text.[!i] '/' && !i + 1 < n && Char.equal text.[!i + 1] '/')
    then stop := true
    else if Char.equal text.[!i] '/' && !i + 1 < n && Char.equal text.[!i + 1] '*'
    then (
      Bytes.set b !i ' ';
      Bytes.set b (!i + 1) ' ';
      in_comment := true;
      i := !i + 2)
    else incr i
  done;
  Bytes.to_string b
;;

(* Lex one source line (no newline) that is not inside a code block. *)
let lex_line ~file ~lineno (text : string) : token array =
  let n = String.length text in
  let toks = ref [] in
  let push tok col = toks := { tok; col } :: !toks in
  let loc col = { file; line = lineno; col } in
  (* After .lang_opt, pioasm lexes in its own mode where ';' is part of a word. *)
  let lang_mode = ref false in
  let i = ref 0 in
  let stop = ref false in
  while (not !stop) && !i < n do
    let c = text.[!i] in
    let col = !i + 1 in
    if is_blank c
    then incr i
    else if !lang_mode
    then (
      if Char.equal c '"'
      then (
        match String.rindex text '"' with
        | Some j when j > !i ->
          push (Str (String.sub text ~pos:!i ~len:(j - !i + 1))) col;
          i := j + 1
        | _ -> raise (Error (loc col, "unterminated string")))
      else if Char.equal c '='
      then (
        push (Op "=") col;
        incr i)
      else (
        let j = ref !i in
        while
          !j < n
          && (not (is_blank text.[!j]))
          && (not (Char.equal text.[!j] '"'))
          && not (Char.equal text.[!j] '=')
        do
          incr j
        done;
        let w = String.sub text ~pos:!i ~len:(!j - !i) in
        let is_dec = String.for_all w ~f:is_digit in
        let is_hex_lit =
          String.is_prefix (String.lowercase w) ~prefix:"0x"
          && String.length w > 2
          && String.for_all (String.drop_prefix w 2) ~f:is_hex
        in
        let is_bin_lit =
          String.is_prefix (String.lowercase w) ~prefix:"0b"
          && String.length w > 2
          && String.for_all (String.drop_prefix w 2) ~f:is_bin
        in
        if is_dec || is_hex_lit || is_bin_lit
        then push (Int (int_of_literal ~loc:(loc col) w)) col
        else push (Raw w) col;
        i := !j))
    else if Char.equal c ';' || (Char.equal c '/' && !i + 1 < n && Char.equal text.[!i + 1] '/')
    then stop := true
    else if is_id_start c
    then (
      let j = ref !i in
      while !j < n && is_id_char text.[!j] do
        incr j
      done;
      let w = String.sub text ~pos:!i ~len:(!j - !i) in
      let lw = String.lowercase w in
      if Set.mem keywords lw
      then push (Kw (canonical_kw lw)) col
      else if String.equal lw "one"
      then push (Int 1) col
      else if String.equal lw "zero"
      then push (Int 0) col
      else push (Id w) col;
      i := !j)
    else if Char.equal c '.' && !i + 1 < n && is_digit text.[!i + 1]
    then (
      (* float such as ".5" *)
      let j = ref (!i + 1) in
      while !j < n && is_digit text.[!j] do
        incr j
      done;
      push (Float (Float.of_string (String.sub text ~pos:!i ~len:(!j - !i)))) col;
      i := !j)
    else if Char.equal c '.'
    then (
      let j = ref (!i + 1) in
      while !j < n && is_id_char text.[!j] do
        incr j
      done;
      let w = String.lowercase (String.sub text ~pos:(!i + 1) ~len:(!j - !i - 1)) in
      if String.is_empty w then raise (Error (loc col, "invalid character: ."));
      if not (Set.mem directives w)
      then raise (Error (loc col, "unknown directive ." ^ w));
      push (Dir w) col;
      if String.equal w "lang_opt" then lang_mode := true;
      i := !j)
    else if is_digit c
    then (
      let start = !i in
      let j = ref !i in
      if Char.equal c '0' && !i + 1 < n && String.contains "xX" text.[!i + 1]
      then (
        j := !i + 2;
        while !j < n && is_hex text.[!j] do
          incr j
        done;
        push (Int (int_of_literal ~loc:(loc col) (String.sub text ~pos:start ~len:(!j - start)))) col)
      else if Char.equal c '0' && !i + 1 < n && String.contains "bB" text.[!i + 1]
      then (
        j := !i + 2;
        while !j < n && is_bin text.[!j] do
          incr j
        done;
        push (Int (int_of_literal ~loc:(loc col) (String.sub text ~pos:start ~len:(!j - start)))) col)
      else (
        while !j < n && is_digit text.[!j] do
          incr j
        done;
        if !j + 1 < n && Char.equal text.[!j] '.' && is_digit text.[!j + 1]
        then (
          incr j;
          while !j < n && is_digit text.[!j] do
            incr j
          done;
          push (Float (Float.of_string (String.sub text ~pos:start ~len:(!j - start)))) col)
        else push (Int (int_of_literal ~loc:(loc col) (String.sub text ~pos:start ~len:(!j - start)))) col);
      i := !j)
    else if !i + 6 <= n && String.equal (String.sub text ~pos:!i ~len:6) "\xE2\x88\x92\xE2\x88\x92"
    then (
      (* U+2212 U+2212, the Unicode spelling of "--" *)
      push (Op "--") col;
      i := !i + 6)
    else (
      let two = if !i + 1 < n then String.sub text ~pos:!i ~len:2 else "" in
      if List.mem [ "::"; "--"; "!="; "<<"; ">>" ] two ~equal:String.equal
      then (
        push (Op two) col;
        i := !i + 2)
      else (
        match c with
        | ',' | ':' | '(' | ')' | '[' | ']' | '+' | '-' | '*' | '/' | '|' | '&' | '^' | '!' | '~' | '<' ->
          push (Op (String.make 1 c)) col;
          incr i
        | _ -> raise (Error (loc col, "invalid character: " ^ String.make 1 c))))
  done;
  Array.of_list (List.rev !toks)
;;
