(** pgsim: cycle-accurate golden model of one RP2040-style PIO block (4 state machines),
    base ISA, block 1 scope.

    One call to {!step} is one system clock cycle. Sources are RP2040 datasheet section 3
    (cited in pgsim.ml and README.md). Block 2 compares {!debug} and {!pads} against the RTL
    every cycle, so the signatures here are the contract. *)

module Isa = Polyglot_isa.Isa

(** Configuration in the RP2040 register layout (datasheet 3.7). *)
module Config : sig
  type t =
    { clkdiv_int : int (** 0 means 65536 *)
    ; clkdiv_frac : int
    ; side_en : bool (** EXECCTRL.SIDE_EN *)
    ; side_pindir : bool
    ; jmp_pin : int
    ; out_sticky : bool
    ; wrap_top : int
    ; wrap_bottom : int
    ; status_rx : bool (** STATUS_SEL: true = RXLEVEL, false = TXLEVEL (RP2040 bit 4) *)
    ; status_n : int (** 0..15 in the RP2040 layout *)
    ; fjoin_rx : bool
    ; fjoin_tx : bool
    ; pull_thresh : int (** 1..32; register value 0 means 32 *)
    ; push_thresh : int
    ; out_right : bool
    ; in_right : bool
    ; autopull : bool
    ; autopush : bool
    ; sideset_count : int (** PINCTRL.SIDESET_COUNT, includes the enable bit *)
    ; set_count : int
    ; out_count : int
    ; in_base : int
    ; sideset_base : int
    ; set_base : int
    ; out_base : int
    }

  (** RP2040 reset values. *)
  val reset : t

  (** Build from the four register values, RP2040 layout. OUT_EN_SEL and INLINE_OUT_EN
      are not modelled and are dropped (see README). *)
  val of_registers : clkdiv:int -> execctrl:int -> shiftctrl:int -> pinctrl:int -> t

  val clkdiv_register : t -> int
  val execctrl_register : t -> int
  val shiftctrl_register : t -> int
  val pinctrl_register : t -> int
end

(** A 4-deep FIFO, or 8 deep when joined (datasheet 3.5.3). *)
module Fifo : sig
  type t =
    { mutable items : int list (** head first *)
    ; mutable depth : int
    }

  val create : int -> t
  val level : t -> int
  val full : t -> bool
  val empty : t -> bool
  val push : t -> int -> unit
  val pop : t -> int option
  val flush : t -> unit
end

(** Per-cycle pin write accumulator (internal to a step). *)
type pinw =
  { mutable lm : int
  ; mutable lv : int
  ; mutable dm : int
  ; mutable dv : int
  }

(** Why an SM is not executing, with the DESIGN.md 7 code in {!stall_code}. *)
type stall =
  | No_stall
  | Stall_tx_empty (** blocking PULL, TX FIFO empty *)
  | Stall_rx_full (** blocking PUSH, or autopush, RX FIFO full *)
  | Stall_autopull (** OUT with the OSR at its threshold *)
  | Stall_wait_gpio (** WAIT GPIO *)
  | Stall_wait_pin (** WAIT PIN *)
  | Stall_wait_irq (** WAIT IRQ *)
  | Stall_irq_wait (** IRQ instruction waiting for the host to clear its flag *)

(** The pending instruction slot. *)
type latch =
  | No_latch
  | Exec_latch of int (** from OUT EXEC or MOV EXEC *)
  | Host_latch of int (** written to SMx_INSTR *)

type sm =
  { index : int
  ; mutable cfg : Config.t
  ; mutable enabled : bool
  ; mutable pc : int
  ; mutable x : int
  ; mutable y : int
  ; mutable isr : int
  ; mutable isr_count : int
  ; mutable osr : int
  ; mutable osr_count : int
  ; mutable delay : int
  ; mutable side_done : bool
  ; mutable host_side_done : bool
  ; mutable latch : latch
  ; mutable irq_wait : int option
  ; mutable latch_irq_wait : int option
  ; mutable acc : int
  ; mutable tx : Fifo.t
  ; mutable rx : Fifo.t
  ; mutable txstall : bool
  ; mutable txover : bool
  ; mutable rxunder : bool
  ; mutable rxstall : bool
  ; mutable illegal : bool
  ; mutable stall : stall
  ; mutable sticky : pinw
  }

type t =
  { sms : sm array
  ; imem : int array
  ; mutable cycle : int
  ; mutable irq : int
  ; mutable pin_level : int
  ; mutable pin_dir : int
  ; mutable ext : int
  ; mutable sync_bypass : int
  ; hist : int array
  }

(** A fresh block: reset state, empty IMEM, all SMs disabled. *)
val create : unit -> t

(** Write words to IMEM from address 0. Words are masked to 16 bits. *)
val load_program : t -> int list -> unit

(** Set SM [i]'s configuration. Changing FJOIN discards the FIFO contents. *)
val set_config : t -> int -> Config.t -> unit

(** Advance one system clock cycle. Returns the pad levels at the start of the cycle. *)
val step : t -> int

(** Pads at the start of the cycle, before the next {!step}: [(level, oe)]. *)
val pads : t -> int * int

(** Host write to the TX FIFO. Full: sets TXOVER and drops the word. *)
val write_tx : t -> int -> int -> unit

(** Host read of the RX FIFO. Empty: sets RXUNDER and returns [None]. *)
val read_rx : t -> int -> int option

(** Host write to SMx_INSTR. Runs at once, ignoring the divider and enable. *)
val write_instr : t -> int -> int -> unit

val set_enabled : t -> int -> bool -> unit

(** CTRL.SM_RESTART for SMs in the mask. *)
val sm_restart : t -> int -> unit

(** CTRL.CLKDIV_RESTART for SMs in the mask. *)
val clkdiv_restart : t -> int -> unit

(** Host write-1-to-clear of IRQ flags in the mask. *)
val clear_irq : t -> int -> unit

(** Debug view of one SM, for the block 2 lockstep harness. *)
type debug =
  { pc : int
  ; x : int
  ; y : int
  ; isr : int
  ; isr_count : int
  ; osr : int
  ; osr_count : int
  ; tx_fifo : int list
  ; rx_fifo : int list
  ; tx_level : int
  ; rx_level : int
  ; delay : int
  ; acc : int
  ; stall : stall
  ; stall_code : int
  ; enabled : bool
  ; illegal : bool
  ; latch : latch
  ; irq_wait : int option
  ; latch_irq_wait : int option
  ; side_done : bool
  ; host_side_done : bool
  ; sticky : int * int * int * int
  ; txstall : bool
  ; txover : bool
  ; rxunder : bool
  ; rxstall : bool
  }

val debug : t -> int -> debug

(** DESIGN.md 7 DBG_CNT.stall_reason code: 0 none, 1 tx_empty, 2 rx_full, 3 autopull,
    4 wait_gpio, 5 wait_pin, 6 wait_irq, 7 irq_wait. AMBIGUITY, see README. *)
val stall_code : stall -> int

val stall_name : stall -> string
