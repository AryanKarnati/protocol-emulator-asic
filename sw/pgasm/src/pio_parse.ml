(* Parser for one pioasm source line, following the grammar in pioasm 2.3.1 parser.yy.

   pioasm allows one statement per line: a directive, an instruction, a label, a label
   followed by an instruction, or nothing. Code blocks are handled by [Pio_source]. *)

open Core
open Pio_lex

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | And
  | Or
  | Xor
  | Shl
  | Shr

type expr =
  | Lit of int
  | Name of loc * string
  | Bin of binop * expr * expr
  | Neg of expr
  | Rev of expr

type symdef =
  { sname : string
  ; sloc : loc
  ; spublic : bool
  }

type jcond =
  | Always
  | Not_x
  | X_dec
  | Not_y
  | Y_dec
  | X_ne_y
  | Pin_cond
  | Not_osre

type wsrc =
  | W_gpio of expr
  | W_pin of expr
  | W_irq of expr * int (** irq_type: 0 plain, 1 prev, 2 rel, 3 next *)
  | W_jmppin of expr

type in_src =
  | I_pins
  | I_x
  | I_y
  | I_null
  | I_isr
  | I_osr
  | I_status

type out_dst =
  | O_pins
  | O_x
  | O_y
  | O_null
  | O_pindirs
  | O_isr
  | O_pc
  | O_exec

type mov_dst =
  | M_pins
  | M_x
  | M_y
  | M_exec
  | M_pc
  | M_isr
  | M_osr
  | M_pindirs (** v1 *)
  | M_rxfifo of expr option (** v1; None means rxfifo[y] *)

type mov_src =
  | S_pins
  | S_x
  | S_y
  | S_null
  | S_status
  | S_isr
  | S_osr
  | S_rxfifo of expr option (** v1 *)

type mov_op_p =
  | Op_none
  | Op_invert
  | Op_reverse

type irq_mod =
  | Irq_set
  | Irq_set_wait
  | Irq_clear

type set_dst =
  | T_pins
  | T_x
  | T_y
  | T_pindirs

type kind =
  | K_nop
  | K_jmp of jcond * expr
  | K_wait of expr * wsrc
  | K_in of in_src * expr
  | K_out of out_dst * expr
  | K_push of bool * bool (** if_full, block *)
  | K_pull of bool * bool (** if_empty, block *)
  | K_mov of mov_dst * mov_op_p * mov_src
  | K_irq of irq_mod * expr * int (** irq_type as for W_irq *)
  | K_set of set_dst * expr
  | K_word of expr

type inst =
  { iloc : loc
  ; kind : kind
  ; sideset : expr option
  ; delay : expr option
  ; prefix_loc : loc (** location of the mnemonic, used for the v1 checks *)
  }

type dir =
  | D_program of loc * string
  | D_define of loc * symdef * expr
  | D_origin of loc * expr
  | D_pio_version of loc * int
  | D_side_set of loc * expr * bool * bool (** value, optional, pindirs *)
  | D_in of loc * expr * bool * bool * expr (** count, right, autop, threshold *)
  | D_out of loc * expr * bool * bool * expr
  | D_set of loc * expr
  | D_wrap_target of loc
  | D_wrap of loc
  | D_lang_opt of loc * string * string * string
  | D_clock_div of loc * float
  | D_fifo of loc * string (** "txrx" | "tx" | "rx" | "txput" | "txget" | "putget" *)
  | D_mov_status of loc

type body =
  | B_none
  | B_dir of dir
  | B_inst of inst

type line =
  { label : symdef option
  ; body : body
  }

(* ---------- Cursor ---------- *)

type cur =
  { toks : token array
  ; file : string
  ; lineno : int
  ; eol_col : int
  ; mutable pos : int
  }

let here c =
  if c.pos < Array.length c.toks
  then { file = c.file; line = c.lineno; col = c.toks.(c.pos).col }
  else { file = c.file; line = c.lineno; col = c.eol_col }
;;

let peek c = if c.pos < Array.length c.toks then Some c.toks.(c.pos).tok else None
let peek2 c = if c.pos + 1 < Array.length c.toks then Some c.toks.(c.pos + 1).tok else None
let advance c = c.pos <- c.pos + 1

let describe = function
  | None -> "end of line"
  | Some (Kw s) -> "'" ^ s ^ "'"
  | Some (Dir s) -> "'." ^ s ^ "'"
  | Some (Id s) -> "identifier '" ^ s ^ "'"
  | Some (Int n) -> "integer " ^ Int.to_string n
  | Some (Float f) -> "float " ^ Float.to_string f
  | Some (Op s) -> "'" ^ s ^ "'"
  | Some (Str s) -> "string " ^ s
  | Some (Raw s) -> "text '" ^ s ^ "'"
;;

let syntax_error c =
  raise (Error (here c, "syntax error, unexpected " ^ describe (peek c)))
;;

let expect_op c op =
  match peek c with
  | Some (Op o) when String.equal o op -> advance c
  | _ -> syntax_error c
;;

let expect_end c =
  match peek c with
  | None -> ()
  | _ -> syntax_error c
;;

let accept_op c op =
  match peek c with
  | Some (Op o) when String.equal o op ->
    advance c;
    true
  | _ -> false
;;

let accept_kw c kw =
  match peek c with
  | Some (Kw k) when String.equal k kw ->
    advance c;
    true
  | _ -> false
;;

(* Optional comma, as in the grammar's "comma" rule. *)
let comma c = ignore (accept_op c "," : bool)

(* ---------- Expressions ---------- *)

let binop_of = function
  | Op "+" -> Some (3, Add)
  | Op "-" -> Some (3, Sub)
  | Op "*" -> Some (4, Mul)
  | Op "/" -> Some (4, Div)
  | Op "&" -> Some (5, And)
  | Op "|" -> Some (5, Or)
  | Op "^" -> Some (5, Xor)
  | Op "<<" -> Some (2, Shl)
  | Op ">>" -> Some (2, Shr)
  | _ -> None
;;

(* A "value" is a literal, a name or a parenthesised expression. *)
let rec parse_value c =
  match peek c with
  | Some (Int n) ->
    advance c;
    Lit n
  | Some (Id s) ->
    let l = here c in
    advance c;
    Name (l, s)
  | Some (Op "(") ->
    advance c;
    let e = parse_expr c 0 in
    expect_op c ")";
    e
  | _ -> syntax_error c

(* Precedence climbing. Levels follow parser.yy: REVERSE (lowest), shifts, + and -,
   * and /, then & | ^ (highest). The prefix rules take the precedence of their token. *)
and parse_expr c min_prec =
  let left = ref (parse_prefix c) in
  let continue = ref true in
  while !continue do
    match peek c with
    | Some tok ->
      (match binop_of tok with
       | Some (p, op) when p >= min_prec ->
         advance c;
         let right = parse_expr c (p + 1) in
         left := Bin (op, !left, right)
       | _ -> continue := false)
    | None -> continue := false
  done;
  !left

and parse_prefix c =
  match peek c with
  | Some (Op "-") ->
    advance c;
    Neg (parse_expr c 4)
  | Some (Op "::") ->
    advance c;
    Rev (parse_expr c 2)
  | _ -> parse_value c
;;

let parse_full_expr c = parse_expr c 0

(* ---------- Instructions ---------- *)

let parse_jcond c =
  match peek c, peek2 c with
  | Some (Op ("!" | "~")), Some (Kw "x") ->
    advance c;
    advance c;
    Not_x
  | Some (Op ("!" | "~")), Some (Kw "y") ->
    advance c;
    advance c;
    Not_y
  | Some (Op ("!" | "~")), Some (Kw "osre") ->
    advance c;
    advance c;
    Not_osre
  | Some (Kw "x"), Some (Op "--") ->
    advance c;
    advance c;
    X_dec
  | Some (Kw "y"), Some (Op "--") ->
    advance c;
    advance c;
    Y_dec
  | Some (Kw "x"), Some (Op "!=") ->
    advance c;
    advance c;
    (match peek c with
     | Some (Kw "y") -> advance c
     | _ -> syntax_error c);
    X_ne_y
  | Some (Kw "pin"), _ ->
    advance c;
    Pin_cond
  | _ -> Always
;;

let parse_wait_source c =
  match peek c with
  | Some (Kw "irq") ->
    advance c;
    let itype =
      if accept_kw c "prev"
      then 1
      else if accept_kw c "next"
      then 3
      else 0
    in
    let prev_next_loc = here c in
    comma c;
    let v = parse_value c in
    if itype = 0 && accept_kw c "rel"
    then W_irq (v, 2)
    else if itype = 0
    then W_irq (v, 0)
    else (
      match peek c with
      | Some (Kw "rel") ->
        raise (Error (here c, "'rel' is not supported for 'irq prev' or 'irq next'"))
      | _ ->
        ignore prev_next_loc;
        W_irq (v, itype))
  | Some (Kw "gpio") ->
    advance c;
    comma c;
    W_gpio (parse_value c)
  | Some (Kw "pin") ->
    advance c;
    comma c;
    W_pin (parse_value c)
  | Some (Kw "jmppin") ->
    advance c;
    if accept_op c "+"
    then W_jmppin (parse_value c)
    else W_jmppin (Lit 0)
  | _ -> raise (Error (here c, "expected irq, gpio, pin or jmp_pin"))
;;

let parse_irq_mod c =
  if accept_kw c "clear"
  then Irq_clear
  else if accept_kw c "wait"
  then Irq_set_wait
  else if accept_kw c "nowait" || accept_kw c "set"
  then Irq_set
  else Irq_set
;;

let parse_mov_target c =
  match peek c with
  | Some (Kw "pins") -> advance c; M_pins
  | Some (Kw "x") -> advance c; M_x
  | Some (Kw "y") -> advance c; M_y
  | Some (Kw "exec") -> advance c; M_exec
  | Some (Kw "pc") -> advance c; M_pc
  | Some (Kw "isr") -> advance c; M_isr
  | Some (Kw "osr") -> advance c; M_osr
  | Some (Kw "pindirs") -> advance c; M_pindirs
  | Some (Kw "rxfifo") ->
    advance c;
    expect_op c "[";
    let idx =
      match peek c with
      | Some (Kw "y") ->
        advance c;
        None
      | _ -> Some (parse_value c)
    in
    expect_op c "]";
    M_rxfifo idx
  | _ -> syntax_error c
;;

let parse_mov_source c =
  match peek c with
  | Some (Kw "pins") -> advance c; S_pins
  | Some (Kw "x") -> advance c; S_x
  | Some (Kw "y") -> advance c; S_y
  | Some (Kw "null") -> advance c; S_null
  | Some (Kw "status") -> advance c; S_status
  | Some (Kw "isr") -> advance c; S_isr
  | Some (Kw "osr") -> advance c; S_osr
  | Some (Kw "rxfifo") ->
    advance c;
    expect_op c "[";
    let idx =
      match peek c with
      | Some (Kw "y") ->
        advance c;
        None
      | _ -> Some (parse_value c)
    in
    expect_op c "]";
    S_rxfifo idx
  | _ -> syntax_error c
;;

let parse_mov_op c =
  match peek c with
  | Some (Op ("!" | "~")) ->
    advance c;
    Op_invert
  | Some (Op "::") ->
    advance c;
    Op_reverse
  | _ -> Op_none
;;

(* Base instruction, without the trailing side-set and delay. Returns the kind and the
   location of the mnemonic. *)
let parse_base c =
  let mloc = here c in
  match peek c with
  | Some (Kw "nop") ->
    advance c;
    mloc, K_nop
  | Some (Kw "jmp") ->
    advance c;
    let cond = parse_jcond c in
    comma c;
    let target = parse_full_expr c in
    mloc, K_jmp (cond, target)
  | Some (Kw "wait") ->
    advance c;
    let pol =
      match peek c with
      | Some (Int _ | Id _ | Op "(") -> parse_value c
      | _ -> Lit 1
    in
    let src = parse_wait_source c in
    mloc, K_wait (pol, src)
  | Some (Kw "in") ->
    advance c;
    let src =
      match peek c with
      | Some (Kw "pins") -> advance c; I_pins
      | Some (Kw "x") -> advance c; I_x
      | Some (Kw "y") -> advance c; I_y
      | Some (Kw "null") -> advance c; I_null
      | Some (Kw "isr") -> advance c; I_isr
      | Some (Kw "osr") -> advance c; I_osr
      | Some (Kw "status") -> advance c; I_status
      | _ -> syntax_error c
    in
    comma c;
    mloc, K_in (src, parse_value c)
  | Some (Kw "out") ->
    advance c;
    let dst =
      match peek c with
      | Some (Kw "pins") -> advance c; O_pins
      | Some (Kw "x") -> advance c; O_x
      | Some (Kw "y") -> advance c; O_y
      | Some (Kw "null") -> advance c; O_null
      | Some (Kw "pindirs") -> advance c; O_pindirs
      | Some (Kw "isr") -> advance c; O_isr
      | Some (Kw "pc") -> advance c; O_pc
      | Some (Kw "exec") -> advance c; O_exec
      | _ -> syntax_error c
    in
    comma c;
    mloc, K_out (dst, parse_value c)
  | Some (Kw "push") ->
    advance c;
    let iffull = accept_kw c "iffull" in
    let block = if accept_kw c "noblock" then false else (ignore (accept_kw c "block" : bool); true) in
    mloc, K_push (iffull, block)
  | Some (Kw "pull") ->
    advance c;
    let ifempty = accept_kw c "ifempty" in
    let block = if accept_kw c "noblock" then false else (ignore (accept_kw c "block" : bool); true) in
    mloc, K_pull (ifempty, block)
  | Some (Kw "mov") ->
    advance c;
    let dst = parse_mov_target c in
    comma c;
    let op = parse_mov_op c in
    let src = parse_mov_source c in
    mloc, K_mov (dst, op, src)
  | Some (Kw "irq") ->
    advance c;
    (match peek c with
     | Some (Kw ("prev" | "next")) ->
       let itype = if accept_kw c "prev" then 1 else (advance c; 3) in
       let m = parse_irq_mod c in
       let v = parse_value c in
       (match peek c with
        | Some (Kw "rel") ->
          raise (Error (here c, "'rel' is not supported for 'irq prev' or 'irq next'"))
        | _ -> mloc, K_irq (m, v, itype))
     | _ ->
       let m = parse_irq_mod c in
       let v = parse_value c in
       if accept_kw c "rel" then mloc, K_irq (m, v, 2) else mloc, K_irq (m, v, 0))
  | Some (Kw "set") ->
    advance c;
    let dst =
      match peek c with
      | Some (Kw "pins") -> advance c; T_pins
      | Some (Kw "x") -> advance c; T_x
      | Some (Kw "y") -> advance c; T_y
      | Some (Kw "pindirs") -> advance c; T_pindirs
      | _ -> syntax_error c
    in
    comma c;
    mloc, K_set (dst, parse_value c)
  | _ -> syntax_error c
;;

(* Trailing "side N" and "[d]" in either order, each at most once. *)
let parse_tail c =
  let sideset = ref None in
  let delay = ref None in
  let continue = ref true in
  while !continue do
    match peek c with
    | Some (Kw "side") when Option.is_none !sideset ->
      advance c;
      sideset := Some (parse_value c)
    | Some (Op "[") when Option.is_none !delay ->
      advance c;
      let e = parse_full_expr c in
      expect_op c "]";
      delay := Some e
    | _ -> continue := false
  done;
  !sideset, !delay
;;

let parse_instruction c =
  match peek c with
  | Some (Kw _) ->
    let mloc, kind = parse_base c in
    let sideset, delay = parse_tail c in
    expect_end c;
    { iloc = mloc; kind; sideset; delay; prefix_loc = mloc }
  | _ -> syntax_error c
;;

(* ---------- Directives and labels ---------- *)

let parse_symdef c =
  match peek c with
  | Some (Id s) ->
    let l = here c in
    advance c;
    { sname = s; sloc = l; spublic = false }
  | Some (Kw "public") ->
    advance c;
    (match peek c with
     | Some (Id s) ->
       let l = here c in
       advance c;
       { sname = s; sloc = l; spublic = true }
     | _ -> syntax_error c)
  | Some (Op "*") ->
    advance c;
    (match peek c with
     | Some (Id s) ->
       let l = here c in
       advance c;
       { sname = s; sloc = l; spublic = true }
     | _ -> syntax_error c)
  | _ -> syntax_error c
;;

let parse_direction c =
  if accept_kw c "left"
  then false
  else if accept_kw c "right"
  then true
  else true
;;

let parse_autop c =
  if accept_kw c "auto"
  then true
  else (
    ignore (accept_kw c "manual" : bool);
    false)
;;

let parse_threshold c =
  match peek c with
  | Some (Int _ | Id _ | Op "(") -> parse_value c
  | _ -> Lit 32
;;

let parse_dir c (name : string) : dir =
  let l = here c in
  match name with
  | "program" ->
    (match peek c with
     | Some (Id s) ->
       advance c;
       expect_end c;
       D_program (l, s)
     | _ -> syntax_error c)
  | "define" ->
    let sd = parse_symdef c in
    let e = parse_full_expr c in
    expect_end c;
    D_define (l, sd, e)
  | "origin" ->
    let v = parse_value c in
    expect_end c;
    D_origin (l, v)
  | "pio_version" ->
    let v =
      match peek c with
      | Some (Int n) -> advance c; n
      | Some (Kw "rp2040") -> advance c; 0
      | Some (Kw "rp2350") -> advance c; 1
      | _ -> syntax_error c
    in
    expect_end c;
    D_pio_version (l, v)
  | "side_set" ->
    let v = parse_value c in
    let opt = accept_kw c "opt" in
    let pindirs = accept_kw c "pindirs" in
    expect_end c;
    D_side_set (l, v, opt, pindirs)
  | "in" | "out" ->
    let count = parse_value c in
    let right = parse_direction c in
    let autop = parse_autop c in
    let thr = parse_threshold c in
    expect_end c;
    if String.equal name "in" then D_in (l, count, right, autop, thr) else D_out (l, count, right, autop, thr)
  | "set" ->
    let v = parse_value c in
    expect_end c;
    D_set (l, v)
  | "wrap_target" ->
    expect_end c;
    D_wrap_target l
  | "wrap" ->
    expect_end c;
    D_wrap l
  | "lang_opt" ->
    (* lang_mode tokens: Raw lang, Raw name, '=', Int | Str | Raw *)
    (match peek c with
     | Some (Raw lang) ->
       advance c;
       (match peek c with
        | Some (Raw name) ->
          advance c;
          expect_op c "=";
          let value =
            match peek c with
            | Some (Int n) -> advance c; Int.to_string n
            | Some (Str s) -> advance c; s
            | Some (Raw s) -> advance c; s
            | _ -> syntax_error c
          in
          expect_end c;
          D_lang_opt (l, lang, name, value)
        | _ -> syntax_error c)
     | _ -> raise (Error (l, "expected format is .lang_opt language option_name = option_value")))
  | "clock_div" ->
    let f =
      match peek c with
      | Some (Int n) -> advance c; Float.of_int n
      | Some (Float f) -> advance c; f
      | _ -> syntax_error c
    in
    expect_end c;
    D_clock_div (l, f)
  | "fifo" ->
    let v =
      match peek c with
      | Some (Kw ("txrx" | "tx" | "rx" | "txput" | "txget" | "putget" as k)) -> advance c; k
      | _ -> syntax_error c
    in
    expect_end c;
    D_fifo (l, v)
  | "mov_status" -> D_mov_status l
  | _ -> raise (Error (l, "unknown directive ." ^ name))
;;

(* Parse one line of source (not a code block). *)
let parse_line ~file ~lineno (text : string) : line =
  let toks = lex_line ~file ~lineno text in
  let c = { toks; file; lineno; eol_col = String.length text + 1; pos = 0 } in
  if Array.length toks = 0
  then { label = None; body = B_none }
  else (
    (* label: symdef COLON, where symdef is ID, public ID or * ID *)
    let is_label_start =
      match peek c with
      | Some (Id _) -> true
      | Some (Kw "public") -> true
      | Some (Op "*") -> true
      | _ -> false
    in
    let label =
      if is_label_start
      then (
        let save = c.pos in
        match parse_symdef c with
        | sd when accept_op c ":" -> Some sd
        | _ ->
          c.pos <- save;
          None
        | exception Error _ ->
          c.pos <- save;
          None)
      else None
    in
    match peek c with
    | None -> { label; body = B_none }
    | Some (Dir "word") ->
      (* .word is an instruction in pioasm (WORD value), so it can carry a label *)
      let iloc = here c in
      advance c;
      let v = parse_value c in
      expect_end c;
      { label; body = B_inst { iloc; kind = K_word v; sideset = None; delay = None; prefix_loc = iloc } }
    | Some (Dir name) ->
      if Option.is_some label then syntax_error c;
      advance c;
      { label = None; body = B_dir (parse_dir c name) }
    | Some (Kw _) ->
      { label; body = B_inst (parse_instruction c) }
    | _ ->
      (* a bare identifier that is not followed by a colon *)
      syntax_error c)
;;
