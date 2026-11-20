(* RP2040 PIO version 0 instruction set, with the Polyglot LCU extensions.

   Encoding reference: RP2040 datasheet section 3.4, as summarised in DESIGN.md section 9.1.
   The datasheet PDF was not available to check against. Cross-checked against pioasm 2.3.1 and its
   disassembler, pico-sdk/tools/pioasm/pio_disassembler.cpp.

   Every 16-bit word decodes to a value of [t]. Words that are reserved in version 0 decode
   to [Illegal w] and encode back to [w], so encode (decode w) = w for all w. *)

open Core

(* ---------- Field types ---------- *)

type jmp_cond =
  | Always
  | Not_x
  | X_dec
  | Not_y
  | Y_dec
  | X_ne_y
  | Jmp_pin
  | Not_osre
[@@deriving sexp, equal, compare, enumerate]

type wait_source =
  | Wsrc_gpio of int (** absolute GPIO, 0..31 *)
  | Wsrc_pin of int (** relative to IN_BASE, 0..31 *)
  | Wsrc_irq of
      { index : int
      ; rel : bool
      } (** index 0..7; [rel] adds the state machine number *)
[@@deriving sexp, equal, compare]

type in_source =
  | In_pins
  | In_x
  | In_y
  | In_null
  | In_lcu (** Polyglot extension, source 100 *)
  | In_status
  (** source 101. pioasm 2.3.1 assembles [in status] to this encoding; DESIGN.md 9.1 lists 101 as reserved. *)
  | In_isr
  | In_osr
[@@deriving sexp, equal, compare, enumerate]

type out_dest =
  | Out_pins
  | Out_x
  | Out_y
  | Out_null
  | Out_pindirs
  | Out_pc
  | Out_isr
  | Out_exec
[@@deriving sexp, equal, compare, enumerate]

(* MOV destination 011 is PINDIRS in RP2350 version 1 only, so it is not here. *)
type mov_dest =
  | Mov_pins
  | Mov_x
  | Mov_y
  | Mov_exec
  | Mov_pc
  | Mov_isr
  | Mov_osr
[@@deriving sexp, equal, compare, enumerate]

type mov_op =
  | Op_none
  | Op_invert
  | Op_reverse
[@@deriving sexp, equal, compare, enumerate]

type mov_source =
  | Ms_pins
  | Ms_x
  | Ms_y
  | Ms_null
  | Ms_crc (** Polyglot extension, source 100 *)
  | Ms_status
  | Ms_isr
  | Ms_osr
[@@deriving sexp, equal, compare, enumerate]

type set_dest =
  | Set_pins
  | Set_x
  | Set_y
  | Set_lcu (** Polyglot extension, destination 011 *)
  | Set_pindirs
[@@deriving sexp, equal, compare, enumerate]

(* ---------- Instructions ----------

   [delay_side] is the raw 5-bit delay/side-set field (instruction bits 12:8). How it splits
   into side-set and delay depends on the program's SIDESET_COUNT and SIDE_EN; see [Side].
   [bit_count] is 1..32 (the encoding 0 means 32). *)

type t =
  | Jmp of
      { delay_side : int
      ; cond : jmp_cond
      ; addr : int
      }
  | Wait of
      { delay_side : int
      ; polarity : bool
      ; source : wait_source
      }
  | In of
      { delay_side : int
      ; source : in_source
      ; bit_count : int
      }
  | Out of
      { delay_side : int
      ; dest : out_dest
      ; bit_count : int
      }
  | Push of
      { delay_side : int
      ; if_full : bool
      ; block : bool
      }
  | Pull of
      { delay_side : int
      ; if_empty : bool
      ; block : bool
      }
  | Mov of
      { delay_side : int
      ; dest : mov_dest
      ; op : mov_op
      ; source : mov_source
      }
  | Irq of
      (** [clear] and [wait] both set: the hardware clear wins, [to_string] prints only
          "clear", so that text does not round-trip. The word itself still round-trips. *)
      { delay_side : int
      ; clear : bool
      ; wait : bool
      ; index : int
      ; rel : bool
      }
  | Set of
      { delay_side : int
      ; dest : set_dest
      ; data : int
      }
  | Illegal of int
[@@deriving sexp, equal, compare]

(* ---------- Side-set and delay ---------- *)

module Side = struct
  (* [count] is SIDESET_COUNT: the number of MSBs of the delay/side-set field used for
     side-set, including the enable bit when [enable] is set (pio.h PINCTRL). *)
  type config =
    { count : int
    ; enable : bool
    }
  [@@deriving sexp, equal, compare]

  type split =
    { side : int option
    ; delay : int
    }
  [@@deriving sexp, equal, compare]

  let none = { count = 0; enable = false }

  let check_config { count; enable } =
    if count < 0 || count > 5 then invalid_arg "Side: count must be 0..5";
    if enable && count < 1 then invalid_arg "Side: enable needs count >= 1"
  ;;

  let delay_bits { count; _ } = 5 - count

  let split cfg ds =
    check_config cfg;
    if ds < 0 || ds > 31 then invalid_arg "Side.split: field must be 0..31";
    let db = delay_bits cfg in
    if cfg.count = 0
    then { side = None; delay = ds }
    else (
      let delay = ds land ((1 lsl db) - 1) in
      if cfg.enable
      then (
        let present = ds land 0x10 <> 0 in
        let data = (ds lsr db) land ((1 lsl (cfg.count - 1)) - 1) in
        { side = (if present then Some data else None); delay })
      else { side = Some ((ds lsr db) land ((1 lsl cfg.count) - 1)); delay })
  ;;

  let join cfg { side; delay } =
    check_config cfg;
    let db = delay_bits cfg in
    if delay < 0 || delay >= 1 lsl db
    then invalid_arg (sprintf "Side.join: delay %d does not fit in %d bits" delay db);
    if cfg.count = 0
    then (
      match side with
      | None -> delay
      | Some _ -> invalid_arg "Side.join: no side-set configured")
    else if cfg.enable
    then (
      match side with
      | None -> delay
      | Some v ->
        if v < 0 || v >= 1 lsl (cfg.count - 1)
        then invalid_arg "Side.join: side-set value out of range";
        (1 lsl 4) lor (v lsl db) lor delay)
    else (
      match side with
      | None -> invalid_arg "Side.join: side-set value required"
      | Some v ->
        if v < 0 || v >= 1 lsl cfg.count
        then invalid_arg "Side.join: side-set value out of range";
        (v lsl db) lor delay)
  ;;
end

(* ---------- Encoding ---------- *)

let check_range name v lo hi =
  if v < lo || v > hi
  then invalid_arg (sprintf "Isa.encode: %s = %d not in %d..%d" name v lo hi)
;;

let check_ds ds = check_range "delay_side" ds 0 31

let jmp_cond_code = function
  | Always -> 0
  | Not_x -> 1
  | X_dec -> 2
  | Not_y -> 3
  | Y_dec -> 4
  | X_ne_y -> 5
  | Jmp_pin -> 6
  | Not_osre -> 7
;;

let jmp_cond_of_code = function
  | 0 -> Always
  | 1 -> Not_x
  | 2 -> X_dec
  | 3 -> Not_y
  | 4 -> Y_dec
  | 5 -> X_ne_y
  | 6 -> Jmp_pin
  | _ -> Not_osre
;;

let in_source_code = function
  | In_pins -> 0
  | In_x -> 1
  | In_y -> 2
  | In_null -> 3
  | In_lcu -> 4
  | In_status -> 5
  | In_isr -> 6
  | In_osr -> 7
;;

let in_source_of_code = function
  | 0 -> In_pins
  | 1 -> In_x
  | 2 -> In_y
  | 3 -> In_null
  | 4 -> In_lcu
  | 5 -> In_status
  | 6 -> In_isr
  | _ -> In_osr
;;

let out_dest_code = function
  | Out_pins -> 0
  | Out_x -> 1
  | Out_y -> 2
  | Out_null -> 3
  | Out_pindirs -> 4
  | Out_pc -> 5
  | Out_isr -> 6
  | Out_exec -> 7
;;

let out_dest_of_code = function
  | 0 -> Out_pins
  | 1 -> Out_x
  | 2 -> Out_y
  | 3 -> Out_null
  | 4 -> Out_pindirs
  | 5 -> Out_pc
  | 6 -> Out_isr
  | _ -> Out_exec
;;

let mov_dest_code = function
  | Mov_pins -> 0
  | Mov_x -> 1
  | Mov_y -> 2
  | Mov_exec -> 4
  | Mov_pc -> 5
  | Mov_isr -> 6
  | Mov_osr -> 7
;;

let mov_dest_of_code = function
  | 0 -> Some Mov_pins
  | 1 -> Some Mov_x
  | 2 -> Some Mov_y
  | 4 -> Some Mov_exec
  | 5 -> Some Mov_pc
  | 6 -> Some Mov_isr
  | 7 -> Some Mov_osr
  | _ -> None (* 3 = PINDIRS, RP2350 version 1 only *)
;;

let mov_op_code = function
  | Op_none -> 0
  | Op_invert -> 1
  | Op_reverse -> 2
;;

let mov_op_of_code = function
  | 0 -> Some Op_none
  | 1 -> Some Op_invert
  | 2 -> Some Op_reverse
  | _ -> None
;;

let mov_source_code = function
  | Ms_pins -> 0
  | Ms_x -> 1
  | Ms_y -> 2
  | Ms_null -> 3
  | Ms_crc -> 4
  | Ms_status -> 5
  | Ms_isr -> 6
  | Ms_osr -> 7
;;

let mov_source_of_code = function
  | 0 -> Ms_pins
  | 1 -> Ms_x
  | 2 -> Ms_y
  | 3 -> Ms_null
  | 4 -> Ms_crc
  | 5 -> Ms_status
  | 6 -> Ms_isr
  | _ -> Ms_osr
;;

let set_dest_code = function
  | Set_pins -> 0
  | Set_x -> 1
  | Set_y -> 2
  | Set_lcu -> 3
  | Set_pindirs -> 4
;;

let set_dest_of_code = function
  | 0 -> Some Set_pins
  | 1 -> Some Set_x
  | 2 -> Some Set_y
  | 3 -> Some Set_lcu
  | 4 -> Some Set_pindirs
  | _ -> None
;;

let encode_bit_count n =
  check_range "bit_count" n 1 32;
  n land 31
;;

(* ---------- Decoding ---------- *)

(* Decode a 16-bit word. Total on 0..0xFFFF: every word gives a value of [t]. Raises
   [Invalid_argument] outside that range.

   Reserved encodings decode to [Illegal w]. The complete set, version 0:
   - WAIT source 11: JMPPIN, RP2350 version 1 only.
   - WAIT source IRQ with index bit 3: PREV/NEXT, RP2350 version 1 only. Beyond DESIGN.md
     9.1; orchestrator ruling, pending V1.
   - IN source 101: not reserved in pioasm (it assembles [in status]). Decodes to
     [In_status], which [is_legal] reports as not legal. DESIGN.md 9.1 lists it as
     reserved. Decision recorded in the commit that added [is_legal].
   - PUSH/PULL with bits 4:0 non-zero: DESIGN.md 9.1 requires 00000. These words are
     MOV RXFIFO in RP2350 version 1.
   - MOV destination 011: PINDIRS, RP2350 version 1 only.
   - MOV operation 11: reserved in DESIGN.md 9.1.
   - IRQ bit 7: reserved in pioasm and the disassembler. Beyond DESIGN.md 9.1; orchestrator
     ruling, pending V1.
   - IRQ index bit 3: PREV/NEXT, RP2350 version 1 only. Beyond DESIGN.md 9.1; orchestrator
     ruling, pending V1.
   - SET destination 101, 110, 111: reserved in DESIGN.md 9.1.

   A reserved word executes as a NOP and sets FDEBUG.ILLEGAL (DESIGN.md 9.1). [encode]
   gives back the same word for it. *)
let decode w =
  check_range "word" w 0 0xFFFF;
  let ds = (w lsr 8) land 31 in
  let bit n = w land (1 lsl n) <> 0 in
  let illegal = Illegal w in
  match w lsr 13 with
  | 0 -> Jmp { delay_side = ds; cond = jmp_cond_of_code ((w lsr 5) land 7); addr = w land 31 }
  | 1 ->
    let low = w land 31 in
    (match (w lsr 5) land 3 with
     | 0 -> Wait { delay_side = ds; polarity = bit 7; source = Wsrc_gpio low }
     | 1 -> Wait { delay_side = ds; polarity = bit 7; source = Wsrc_pin low }
     | 2 ->
       (* bit 3 selects PREV/NEXT in RP2350 version 1, reserved here *)
       if low land 8 <> 0
       then illegal
       else
         Wait
           { delay_side = ds
           ; polarity = bit 7
           ; source = Wsrc_irq { index = low land 7; rel = low land 0x10 <> 0 }
           }
     | _ (* JMPPIN is RP2350 version 1 only *) -> illegal)
  | 2 ->
    let count = w land 31 in
    In
      { delay_side = ds
      ; source = in_source_of_code ((w lsr 5) land 7)
      ; bit_count = (if count = 0 then 32 else count)
      }
  | 3 ->
    let count = w land 31 in
    Out
      { delay_side = ds
      ; dest = out_dest_of_code ((w lsr 5) land 7)
      ; bit_count = (if count = 0 then 32 else count)
      }
  | 4 ->
    (* PUSH/PULL with bits 4:0 set is MOV RXFIFO (RP2350 version 1), reserved here *)
    if w land 31 <> 0
    then illegal
    else if bit 7
    then Pull { delay_side = ds; if_empty = bit 6; block = bit 5 }
    else Push { delay_side = ds; if_full = bit 6; block = bit 5 }
  | 5 ->
    (match
       ( mov_dest_of_code ((w lsr 5) land 7)
       , mov_op_of_code ((w lsr 3) land 3) )
     with
     | Some dest, Some op ->
       Mov { delay_side = ds; dest; op; source = mov_source_of_code (w land 7) }
     | _ -> illegal)
  | 6 ->
    (* bit 7 is reserved; bit 3 selects PREV/NEXT in RP2350 version 1, reserved here *)
    if bit 7 || bit 3
    then illegal
    else
      Irq
        { delay_side = ds
        ; clear = bit 6
        ; wait = bit 5
        ; index = w land 7
        ; rel = bit 4
        }
  | _ ->
    (match set_dest_of_code ((w lsr 5) land 7) with
     | Some dest -> Set { delay_side = ds; dest; data = w land 31 }
     | None -> illegal)
;;

(* The single legality predicate for version 0, as DESIGN.md section 9.1 defines it. The
   RTL decoder and pgsim must both use this, not their own tables.

   [Illegal] is reserved and executes as a NOP that sets the ILLEGAL flag.

   IN source 101 is special. pioasm 2.3.1 assembles [in status] to this encoding, and the
   decoder keeps it as [In { source = In_status; _ }] so the disassembler can print it.
   DESIGN.md section 9.1 lists 101 as reserved, and the RP2040 datasheet is not checked for
   it, so for the chip and the model it is reserved: not legal. Whether silicon agrees is
   what V1 on a Pico 2 will show. pgasm still accepts [in status] and emits 101, so its
   output stays byte-identical to pioasm. *)
let is_legal = function
  | Illegal _ -> false
  | In { source = In_status; _ } -> false
  | _ -> true
;;

(* Raw delay/side-set field, instruction bits 12:8. For [Illegal w] it is read from w. *)
let delay_side = function
  | Jmp { delay_side; _ }
  | Wait { delay_side; _ }
  | In { delay_side; _ }
  | Out { delay_side; _ }
  | Push { delay_side; _ }
  | Pull { delay_side; _ }
  | Mov { delay_side; _ }
  | Irq { delay_side; _ }
  | Set { delay_side; _ } -> delay_side
  | Illegal w -> (w lsr 8) land 31
;;

let with_delay_side t ds =
  check_ds ds;
  match t with
  | Jmp r -> Jmp { r with delay_side = ds }
  | Wait r -> Wait { r with delay_side = ds }
  | In r -> In { r with delay_side = ds }
  | Out r -> Out { r with delay_side = ds }
  | Push r -> Push { r with delay_side = ds }
  | Pull r -> Pull { r with delay_side = ds }
  | Mov r -> Mov { r with delay_side = ds }
  | Irq r -> Irq { r with delay_side = ds }
  | Set r -> Set { r with delay_side = ds }
  | Illegal w -> Illegal ((w land lnot (31 lsl 8)) lor (ds lsl 8))
;;

let encode = function
  | Illegal w ->
    check_range "illegal word" w 0 0xFFFF;
    if not (equal (decode w) (Illegal w))
    then invalid_arg (sprintf "Isa.encode: Illegal 0x%04x is not a reserved encoding" w);
    w
  | Jmp { delay_side; cond; addr } ->
    check_ds delay_side;
    check_range "addr" addr 0 31;
    (delay_side lsl 8) lor (jmp_cond_code cond lsl 5) lor addr
  | Wait { delay_side; polarity; source } ->
    check_ds delay_side;
    let pol = if polarity then 0x80 else 0 in
    let src, low =
      match source with
      | Wsrc_gpio n ->
        check_range "gpio" n 0 31;
        0, n
      | Wsrc_pin n ->
        check_range "pin" n 0 31;
        1, n
      | Wsrc_irq { index; rel } ->
        check_range "irq index" index 0 7;
        2, index lor (if rel then 0x10 else 0)
    in
    0x2000 lor (delay_side lsl 8) lor pol lor (src lsl 5) lor low
  | In { delay_side; source; bit_count } ->
    check_ds delay_side;
    0x4000 lor (delay_side lsl 8) lor (in_source_code source lsl 5) lor encode_bit_count bit_count
  | Out { delay_side; dest; bit_count } ->
    check_ds delay_side;
    0x6000
    lor (delay_side lsl 8)
    lor (out_dest_code dest lsl 5)
    lor encode_bit_count bit_count
  | Push { delay_side; if_full; block } ->
    check_ds delay_side;
    0x8000
    lor (delay_side lsl 8)
    lor (if if_full then 0x40 else 0)
    lor (if block then 0x20 else 0)
  | Pull { delay_side; if_empty; block } ->
    check_ds delay_side;
    0x8080
    lor (delay_side lsl 8)
    lor (if if_empty then 0x40 else 0)
    lor (if block then 0x20 else 0)
  | Mov { delay_side; dest; op; source } ->
    check_ds delay_side;
    0xA000
    lor (delay_side lsl 8)
    lor (mov_dest_code dest lsl 5)
    lor (mov_op_code op lsl 3)
    lor mov_source_code source
  | Irq { delay_side; clear; wait; index; rel } ->
    check_ds delay_side;
    check_range "irq index" index 0 7;
    0xC000
    lor (delay_side lsl 8)
    lor (if clear then 0x40 else 0)
    lor (if wait then 0x20 else 0)
    lor (if rel then 0x10 else 0)
    lor index
  | Set { delay_side; dest; data } ->
    check_ds delay_side;
    check_range "set data" data 0 31;
    0xE000 lor (delay_side lsl 8) lor (set_dest_code dest lsl 5) lor data
;;

(* ---------- Disassembly ----------

   Output follows pioasm's disassembler: mnemonic padded to 7 columns, operands to 16, then
   "side N" padded to 7, then "[d]" padded to 4, with trailing spaces removed. *)

let pad_right s n =
  let len = String.length s in
  if len >= n then s else s ^ String.make (n - len) ' '
;;

let jmp_cond_text = function
  | Always -> ""
  | Not_x -> "!x, "
  | X_dec -> "x--, "
  | Not_y -> "!y, "
  | Y_dec -> "y--, "
  | X_ne_y -> "x != y, "
  | Jmp_pin -> "pin, "
  | Not_osre -> "!osre, "
;;

let in_source_text = function
  | In_pins -> "pins"
  | In_x -> "x"
  | In_y -> "y"
  | In_null -> "null"
  | In_lcu -> "lcu"
  | In_status -> "status"
  | In_isr -> "isr"
  | In_osr -> "osr"
;;

let out_dest_text = function
  | Out_pins -> "pins"
  | Out_x -> "x"
  | Out_y -> "y"
  | Out_null -> "null"
  | Out_pindirs -> "pindirs"
  | Out_pc -> "pc"
  | Out_isr -> "isr"
  | Out_exec -> "exec"
;;

let mov_dest_text = function
  | Mov_pins -> "pins"
  | Mov_x -> "x"
  | Mov_y -> "y"
  | Mov_exec -> "exec"
  | Mov_pc -> "pc"
  | Mov_isr -> "isr"
  | Mov_osr -> "osr"
;;

let mov_source_text = function
  | Ms_pins -> "pins"
  | Ms_x -> "x"
  | Ms_y -> "y"
  | Ms_null -> "null"
  | Ms_crc -> "crc"
  | Ms_status -> "status"
  | Ms_isr -> "isr"
  | Ms_osr -> "osr"
;;

let set_dest_text = function
  | Set_pins -> "pins"
  | Set_x -> "x"
  | Set_y -> "y"
  | Set_lcu -> "lcu"
  | Set_pindirs -> "pindirs"
;;

let bit_count_text n = Int.to_string n

(* (mnemonic, operands, delay_side) for a non-illegal instruction. *)
let parts = function
  | Illegal _ -> assert false
  | Jmp { delay_side; cond; addr } ->
    "jmp", jmp_cond_text cond ^ Int.to_string addr, delay_side
  | Wait { delay_side; polarity; source } ->
    let pol = if polarity then "1 " else "0 " in
    let src =
      match source with
      | Wsrc_gpio n -> "gpio, " ^ Int.to_string n
      | Wsrc_pin n -> "pin, " ^ Int.to_string n
      | Wsrc_irq { index; rel } ->
        "irq, " ^ Int.to_string index ^ (if rel then " rel" else "")
    in
    "wait", pol ^ src, delay_side
  | In { delay_side; source; bit_count } ->
    "in", in_source_text source ^ ", " ^ bit_count_text bit_count, delay_side
  | Out { delay_side; dest; bit_count } ->
    "out", out_dest_text dest ^ ", " ^ bit_count_text bit_count, delay_side
  | Push { delay_side; if_full; block } ->
    ( "push"
    , (if if_full then "iffull " else "") ^ (if block then "block" else "noblock")
    , delay_side )
  | Pull { delay_side; if_empty; block } ->
    ( "pull"
    , (if if_empty then "ifempty " else "") ^ (if block then "block" else "noblock")
    , delay_side )
  | Mov { delay_side; dest; op; source } ->
    let dtxt = mov_dest_text dest in
    let stxt = mov_source_text source in
    let dcode = mov_dest_code dest in
    let low5 = (mov_op_code op lsl 3) lor mov_source_code source in
    (* pioasm prints these forms as nop: "mov y, y" and "mov x, x" *)
    if String.equal dtxt stxt && equal_mov_op op Op_none && (dcode = 1 || low5 = 2)
    then "nop", "", delay_side
    else (
      let prefix =
        match op with
        | Op_none -> ""
        | Op_invert -> "~"
        | Op_reverse -> "::"
      in
      "mov", dtxt ^ ", " ^ prefix ^ stxt, delay_side)
  | Irq { delay_side; clear; wait; index; rel } ->
    let prefix = if clear then "clear " else if wait then "wait " else "nowait " in
    "irq", prefix ^ Int.to_string index ^ (if rel then " rel" else ""), delay_side
  | Set { delay_side; dest; data } ->
    "set", set_dest_text dest ^ ", " ^ Int.to_string data, delay_side
;;

let to_string ?(side = Side.none) t =
  match t with
  | Illegal w -> sprintf ".word 0x%04x" w
  | _ ->
    let mnemonic, operands, ds = parts t in
    let { Side.side = side_value; delay } = Side.split side ds in
    let side_txt =
      match side_value with
      | Some v -> "side " ^ Int.to_string v
      | None -> ""
    in
    let delay_txt = if delay = 0 then "" else "[" ^ Int.to_string delay ^ "]" in
    let line =
      pad_right mnemonic 7
      ^ pad_right operands 16
      ^ pad_right side_txt 7
      ^ pad_right delay_txt 4
    in
    String.rstrip line
;;
