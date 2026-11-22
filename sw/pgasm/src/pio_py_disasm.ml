(* Disassembler for the instruction comments of pioasm's python output. A port of the static
   disassemble in pioasm 2.3.1's python_output.cpp. It is not the disassembler of the JSON and
   c-sdk outputs (Pio_disasm, a port of pio_disassembler.cpp). The differences:

   - the mnemonic is followed by its arguments in parentheses, padded to 24 columns:
     in_(...), out(...), wait(...), set(...), jmp(...), irq(...), push(...), pull(...), mov(...),
     nop();
   - operands are separated by ", " (push/pull use "iffull, "/"ifempty, "), jump conditions are
     named (not_x, x_dec, ...) and jumps name their target as a numeric label;
   - wait jmppin, irq prev/next, pindirs-less mov rxfifo[] and the other words the python
     writer does not decode are printed as word(0x....);
   - the line is not trimmed: the side-set and delay columns are padded as well.

   Layout: "side" is ".side(N)" padded to 9 columns, the delay "[d]" to 4 columns. *)

open Core

let pad s n = if String.length s >= n then s else s ^ String.make (n - String.length s) ' '

let jmp_conditions = [| ""; "not_x"; "x_dec"; "not_y"; "y_dec"; "x_not_y"; "pin"; "not_osre" |]
let in_sources = [| "pins"; "x"; "y"; "null"; ""; "status"; "isr"; "osr" |]
let out_dests = [| "pins"; "x"; "y"; "null"; "pindirs"; "pc"; "isr"; "exec" |]
let mov_dests = [| "pins"; "x"; "y"; ""; "exec"; "pc"; "isr"; "osr" |]
let mov_sources = [| "pins"; "x"; "y"; "null"; ""; "status"; "isr"; "osr" |]
let set_dests = [| "pins"; "x"; "y"; ""; "pindirs"; ""; ""; "" |]

exception Invalid

let irq_text n =
  let i = Int.to_string (n land 7) in
  if n land 0x10 <> 0 then "rel(" ^ i ^ ")" else i
;;

(* (mnemonic, text inside the parentheses) of a word the python writer decodes. [labels] are
   the jump targets of the program. Raises [Invalid] otherwise. *)
let decode ~(labels : int list) (inst : int) : string * string =
  let major = (inst lsr 13) land 7 in
  let arg1 = (inst lsr 5) land 7 in
  let arg2 = (inst land 0x1f) lor ((inst land 0x10000) lsr 11) in
  match major with
  | 0 ->
    let label =
      if List.mem labels arg2 ~equal:Int.equal then Int.to_string arg2 else "?"
    in
    ( "jmp"
    , if arg1 <> 0
      then jmp_conditions.(arg1) ^ ", \"" ^ label ^ "\""
      else "\"" ^ label ^ "\"" )
  | 1 ->
    let guts =
      match arg1 land 3 with
      | 0 -> "gpio, " ^ Int.to_string arg2
      | 1 -> "pin, " ^ Int.to_string arg2
      | 2 -> if arg2 land 8 <> 0 then raise Invalid else "irq, " ^ irq_text arg2
      | _ -> raise Invalid
    in
    "wait", (if arg1 land 4 <> 0 then "1, " else "0, ") ^ guts
  | 2 ->
    let src = in_sources.(arg1) in
    if String.is_empty src then raise Invalid;
    "in_", src ^ ", " ^ Int.to_string (if arg2 <> 0 then arg2 else 32)
  | 3 ->
    "out", out_dests.(arg1) ^ ", " ^ Int.to_string (if arg2 <> 0 then arg2 else 32)
  | 4 ->
    if arg2 <> 0 then raise Invalid;
    let mn, pre =
      if arg1 land 4 <> 0
      then "pull", if arg1 land 2 <> 0 then "ifempty, " else ""
      else "push", if arg1 land 2 <> 0 then "iffull, " else ""
    in
    mn, pre ^ if arg1 land 1 <> 0 then "block" else "noblock"
  | 5 ->
    let dest = mov_dests.(arg1) in
    let src = mov_sources.(arg2 land 7) in
    let op = arg2 lsr 3 in
    if String.is_empty dest || String.is_empty src || op = 3 then raise Invalid;
    if String.equal dest src && (arg1 = 1 || arg2 = 2) && op = 0
    then "nop", ""
    else (
      let operand =
        match op with
        | 1 -> "invert(" ^ src ^ ")"
        | 2 -> "reverse(" ^ src ^ ")"
        | _ -> src
      in
      "mov", dest ^ ", " ^ operand)
  | 6 ->
    if arg1 land 4 <> 0 || arg2 land 8 <> 0 then raise Invalid;
    let pre =
      if arg1 land 2 <> 0 then "clear, " else if arg1 land 1 <> 0 then "block, " else ""
    in
    "irq", pre ^ irq_text arg2
  | _ ->
    let dest = set_dests.(arg1) in
    if String.is_empty dest then raise Invalid;
    "set", dest ^ ", " ^ Int.to_string arg2
;;

(* One instruction line body, without the " # <index>" suffix. [sideset_bits] is 0 when the
   program has no .side_set. *)
let disassemble ~(labels : int list) ~(sideset_bits : int) ~(sideset_opt : bool) (inst : int)
  : string
  =
  let body =
    match decode ~labels inst with
    | mn, guts -> pad (mn ^ "(" ^ guts ^ ")") 24
    | exception Invalid -> pad (sprintf "word(0x%04x)" inst) 24
  in
  let delay = (inst lsr 8) land 0x1f in
  let side =
    if sideset_bits <> 0 && ((not sideset_opt) || delay land 0x10 <> 0)
    then (
      let v = (delay land if sideset_opt then 0xf else 0x1f) lsr (5 - sideset_bits) in
      pad (sprintf ".side(%d)" v) 9)
    else pad "" 9
  in
  let d = delay land ((1 lsl (5 - sideset_bits)) - 1) in
  body ^ side ^ pad (if d <> 0 then sprintf "[%d]" d else "") 4
;;
