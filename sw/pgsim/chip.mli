(** The whole chip as a golden model (docs/chip.md, sections 5 to 9): the host link at pin
    level, the register block, the pin block, and {!Pgsim} for the four engines.

    One call to {!step} is one system clock cycle, with the pad levels of that cycle. Reset
    is {!create}, which is the state after reset (chip.md 10). The pin rules are chip.md 6.1
    to 6.5, and the register rules chip.md 8. The lockstep compares {!step}'s outputs and
    {!pio} against the RTL every cycle (chip.md 11). *)

(** Bus pulses of one cycle (chip.md 6.4), for the lockstep. [addr] is meaningful when one of
    the three pulses is set, [wdata] in a write, [rdata] in a read. *)
type bus =
  { write : bool
  ; read : bool
  ; commit : bool
  ; addr : int (** byte address, bits 1:0 cleared *)
  ; wdata : int
  ; rdata : int
  }

type outputs =
  { uo_out : int (** 8 bits, chip.md 9.2 *)
  ; uio_out : int
  ; uio_oe : int
  ; miso : int (** uo_out[7], the MISO shift register's MSB (chip.md 6.5) *)
  ; bus : bus
  }

type t

(** [create ~num_sms ()] is the chip after reset with [num_sms] engines (1 to 4) and the
    64-word IMEM. [sram] is not modelled and must be false. *)
val create : ?num_sms:int -> unit -> t

(** [step t ~ui_in ~uio_ext] runs one cycle. [ui_in] is the 8 dedicated inputs, and [uio_ext]
    the external level of each bidirectional pad. The pad input that the chip sees is
    [uio_oe ? uio_out : uio_ext] (chip.md 9.2). Returns this cycle's outputs. *)
val step : t -> ui_in:int -> uio_ext:int -> outputs

(** The outputs of the cycle that the next {!step} would produce, with the same
    [ui_in] and [uio_ext] as that step. Does not change the state. *)
val peek : t -> ui_in:int -> uio_ext:int -> outputs

(** The engines, for debug views. Their configuration and enables are the chip's registers,
    as of the start of the last cycle. *)
val pio : t -> Pgsim.t

(** Reset (chip.md 10): every state element except IMEM returns to its reset value. The cycle
    count keeps counting. *)
val reset : t -> unit

(** Cycles stepped since reset. *)
val cycle : t -> int

(** The register value at a byte address, as a bus read would return it at the start of the
    next cycle, with the given pad levels. Reads 0 for unmapped addresses. Used by tests. *)
val read_reg : t -> ui_in:int -> uio_ext:int -> int -> int

(** Address decode, for tests: is [addr] a mapped register? *)
val mapped : t -> int -> bool

(** The compared ports of the cycle, before its {!step}, named as the RTL ports (chip.md 11):
    the pads and the present SMs' pio_block debug ports. *)
val observe : t -> (string * int) list

(** The bus ports of a step's outputs, named as the RTL ports (chip.md 11). The address is
    compared only when a pulse is set, the write data in a write and the read data in a read. *)
val bus_ports : outputs -> (string * int) list
