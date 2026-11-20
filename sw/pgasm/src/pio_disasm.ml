(* Disassembler for the "instruction" text in pgasm's JSON. A port of pioasm 2.3.1's
   tools/pioasm/pio_disassembler.cpp, which pioasm uses for its own JSON. It does not check
   the PIO version: it prints the RP2350 forms (prev/next, jmppin, pindirs, mov rxfifo) for
   the words that have them, and "reserved" for words pioasm does not decode. That is why
   the JSON text of a .word can differ from Polyglot_isa.Isa.to_string, which follows
   DESIGN.md. Polyglot's extension words are reserved here, as pioasm sees them.

   Layout: the mnemonic is padded to 7 columns and the operands to 16, then "side N" is
   padded to 7 and "[d]" to 4. Trailing spaces are removed. *)

open Core

let pad s n = if String.length s >= n then s else s ^ String.make (n - String.length s) ' '

let jmp_conditions = [| ""; "!x, "; "x--, "; "!y, "; "y--, "; "x != y, "; "pin, "; "!osre, " |]
let in_sources = [| "pins"; "x"; "y"; "null"; ""; "status"; "isr"; "osr" |]
let out_dests = [| "pins"; "x"; "y"; "null"; "pindirs"; "pc"; "isr"; "exec" |]
let mov_dests = [| "pins"; "x"; "y"; "pindirs"; "exec"; "pc"; "isr"; "osr" |]
let mov_sources = [| "pins"; "x"; "y"; "null"; ""; "status"; "isr"; "osr" |]
let set_dests = [| "pins"; "x"; "y"; ""; "pindirs"; ""; ""; "" |]

exception Invalid

(* (mnemonic, operands) of a valid instruction word, or raises [Invalid]. *)
let parts (inst : int) : string * string =
  let major = (inst lsr 13) land 7 in
  let arg1 = (inst lsr 5) land 7 in
  let arg2 = inst land 0x1F in
  match major with
  | 0 -> "jmp", jmp_conditions.(arg1) ^ Int.to_string arg2
  | 1 ->
    let body =
      match arg1 land 3 with
      | 0 -> "gpio, " ^ Int.to_string arg2
      | 1 -> "pin, " ^ Int.to_string arg2
      | 2 ->
        "irq"
        ^ (if arg2 land 0x08 <> 0 then if arg2 land 0x10 <> 0 then " next" else " prev" else "")
        ^ ", "
        ^ Int.to_string (arg2 land 7)
        ^ (if arg2 land 0x18 = 0x10 then " rel" else "")
      | _ ->
        if arg2 land 0x1C <> 0
        then raise Invalid
        else if arg2 <> 0
        then "jmppin + " ^ Int.to_string (arg2 land 3)
        else "jmppin"
    in
    "wait", (if arg1 land 4 <> 0 then "1 " else "0 ") ^ body
  | 2 ->
    let src = in_sources.(arg1) in
    if String.is_empty src then raise Invalid;
    "in", src ^ ", " ^ Int.to_string (if arg2 <> 0 then arg2 else 32)
  | 3 ->
    "out", out_dests.(arg1) ^ ", " ^ Int.to_string (if arg2 <> 0 then arg2 else 32)
  | 4 ->
    if arg2 <> 0
    then (
      if arg1 land 3 <> 0 || arg2 land 0x10 = 0 then raise Invalid;
      let index = if arg2 land 8 <> 0 then Int.to_string (arg2 land 3) else "y" in
      let operands =
        if arg1 land 4 <> 0 then "osr, rxfifo[" ^ index ^ "]" else "rxfifo[" ^ index ^ "], isr"
      in
      "mov", operands)
    else (
      let mnem = if arg1 land 4 <> 0 then "pull" else "push" in
      let pre =
        if arg1 land 4 <> 0
        then if arg1 land 2 <> 0 then "ifempty " else ""
        else if arg1 land 2 <> 0
        then "iffull "
        else ""
      in
      let block = if arg1 land 1 <> 0 then "block" else "noblock" in
      mnem, pre ^ block)
  | 5 ->
    let dest = mov_dests.(arg1) in
    let source = mov_sources.(arg2 land 7) in
    let operation = arg2 lsr 3 in
    if String.is_empty source || String.is_empty dest || operation = 3 then raise Invalid;
    if String.equal dest source && operation = 0 && (arg1 = 1 || arg2 = 2)
    then "nop", ""
    else
      "mov",
      dest
      ^ ", "
      ^ (if operation = 1 then "~" else if operation = 2 then "::" else "")
      ^ source
  | 6 ->
    if arg1 land 4 <> 0 then raise Invalid;
    let g =
      (if arg1 land 2 <> 0 then "clear " else if arg1 land 1 <> 0 then "wait " else "nowait ")
      ^ Int.to_string (arg2 land 7)
    in
    let g =
      match arg2 land 0x18 with
      | 0x10 -> g ^ " rel"
      | 0x08 -> "prev " ^ g
      | 0x18 -> "next " ^ g
      | _ -> g
    in
    "irq", g
  | _ ->
    let dest = set_dests.(arg1) in
    if String.is_empty dest then raise Invalid;
    "set", dest ^ ", " ^ Int.to_string arg2
;;

(* [sideset_bits] is the specified side-set bit count plus one when optional (0 when there is
   no side-set); [sideset_opt] is the optional flag. Same arguments as pioasm's disassemble. *)
let disassemble (inst : int) ~(sideset_bits : int) ~(sideset_opt : bool) : string =
  match parts inst with
  | exception Invalid -> "reserved"
  | mnem, operands ->
    let delay = (inst lsr 8) land 0x1F in
    let side =
      if sideset_bits <> 0 && ((not sideset_opt) || delay land 0x10 <> 0)
      then
        "side "
        ^ Int.to_string
            ((delay land if sideset_opt then 0xF else 0x1F) lsr (5 - sideset_bits))
      else ""
    in
    let delay = delay land ((1 lsl (5 - sideset_bits)) - 1) in
    let delay_s = if delay <> 0 then "[" ^ Int.to_string delay ^ "]" else "" in
    let line = pad mnem 7 ^ pad operands 16 ^ pad side 7 ^ pad delay_s 4 in
    String.rstrip line
;;
