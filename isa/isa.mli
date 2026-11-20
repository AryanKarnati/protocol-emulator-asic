(* Interface of polyglot_isa. See isa.ml for the encoding table and the reasons behind it.

   Consumers (the RTL decoder, pgsim, pgasm) should use [decode], [is_legal], [encode] and the
   accessors. Do not write your own match over [t]. *)

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
  (** [clear] and [wait] both set: the hardware clear wins, [to_string] prints only
      "clear", so that text does not round-trip. The word itself still round-trips. *)
  | Irq of
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


(** Side-set and delay. [count] is SIDESET_COUNT: the number of MSBs of the delay/side-set
    field used for side-set, including the enable bit when [enable] is set. *)
module Side : sig
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

  (** No side-set: the whole delay/side-set field is delay. *)
  val none : config

  (** Split a raw 5-bit field. Raises if the field is out of 0..31. *)
  val split : config -> int -> split

  (** Join a split back into the raw 5-bit field. Raises if the value does not fit. *)
  val join : config -> split -> int
end

(** Raw field codes, for consumers that need the encoding tables (for example the RTL
    decoder). Only [mov_dest_of_code], [mov_op_of_code] and [set_dest_of_code] return [None]
    for a reserved code. The other [*_of_code] functions are total. *)
val jmp_cond_code : jmp_cond -> int
val jmp_cond_of_code : int -> jmp_cond
val in_source_code : in_source -> int
val in_source_of_code : int -> in_source
val out_dest_code : out_dest -> int
val out_dest_of_code : int -> out_dest
val mov_dest_code : mov_dest -> int
val mov_dest_of_code : int -> mov_dest option
val mov_op_code : mov_op -> int
val mov_op_of_code : int -> mov_op option
val mov_source_code : mov_source -> int
val mov_source_of_code : int -> mov_source
val set_dest_code : set_dest -> int
val set_dest_of_code : int -> set_dest option

(** [decode] is total on 0..0xFFFF and raises [Invalid_argument] outside that range. Every
    reserved word decodes to [Illegal w]. *)
val decode : int -> t

(** [encode] is the inverse of [decode] for every 16-bit word:
    [encode (decode w) = w]. It raises [Invalid_argument] for an [Illegal w] that is not a
    reserved encoding, and for any field out of range. *)
val encode : t -> int

(** [false] means the instruction executes as a NOP and sets FDEBUG.ILLEGAL (DESIGN.md 9.1).
    Returns [false] for every [Illegal _] and for [In { source = In_status; _ }]. *)
val is_legal : t -> bool

(** Raw delay/side-set field, instruction bits 12:8. For [Illegal w] it is read from [w]. *)
val delay_side : t -> int

(** Replace the raw delay/side-set field. Reserved-ness does not depend on that field, so a
    reserved word stays reserved. *)
val with_delay_side : t -> int -> t

(** pioasm-style disassembly. [side] says how the delay/side-set field splits. [Irq] with
    both [clear] and [wait] prints only "clear", so that text does not round-trip. [Illegal w]
    prints [.word 0x....]. *)
val to_string : ?side:Side.config -> t -> string
