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
  ; mutable latch_stall : stall
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
  ; mutable page : int (** SMn_EXT.PAGE, bit 0 (engine.md 9) *)
  }

type t =
  { sms : sm array
  ; imem : int array (** 64 words: two pages of 32 (engine.md 9) *)
  ; mutable cycle : int
  ; mutable irq : int
  ; mutable pin_level : int
  ; mutable pin_dir : int
  ; mutable ext : int
  ; mutable sync_bypass : int
  ; mutable pads_given : bool
    (** true: [ext] is the pad value the engines see, with no override by the pin's own output
        (chip.md 9.1). false: the block 2 pad rule. *)
  ; hist : int array
  }

(** A fresh block: reset state, empty IMEM, all SMs disabled. *)
val create : unit -> t

(** Write words to IMEM from address 0. Words are masked to 16 bits. *)
val load_program : t -> int list -> unit

(** Set SM [i]'s configuration. Changing FJOIN discards the FIFO contents. *)
val set_config : t -> int -> Config.t -> unit

(** Host operations of the block 2 contract (engine.md section 5, H1 to H9). An operation
    presented in a cycle is judged against the state at the start of that cycle, and takes
    effect at its end, together with the SMs' own updates. *)
module Host_op : sig
  type t =
    | Tx_push of
        { sm : int
        ; data : int
        } (** H1: dropped and TXOVER set if the TX FIFO is full at the start of the cycle *)
    | Rx_pop of { sm : int } (** H2: [rx_data] is the head, or 0 and RXUNDER if empty *)
    | Instr_write of
        { sm : int
        ; data : int
        } (** H3, H7: after any restart of the same cycle, latched for the next cycle *)
    | Sm_restart of int (** H3, SM mask *)
    | Clkdiv_restart of int (** H4, SM mask *)
    | Irq_clear of int (** H5, IRQ mask, write 1 to clear *)
    | Irq_force of int (** H5, IRQ mask *)
    | Fdebug_clear of int (** H8, FDEBUG layout mask, write 1 to clear *)
    | Fdebug_set of int
      (** H8, FDEBUG layout mask: sets the flags. A set wins over a clear in the same cycle. *)
    | Fifo_flush of int (** H6, SM mask: both FIFOs empty at the end of the cycle *)
    | Imem_write of
        { addr : int
        ; data : int
        } (** H9, usable from the next cycle. The address is 6 bits (engine.md 9). *)
end

type step_result =
  { pads : int (** pads at the start of the cycle *)
  ; rx_data : int list
    (** one per [Rx_pop], in order: the RX head (or 0) judged at the start of the cycle *)
  }

(** Advance one system clock cycle with the host operations of that cycle. Returns the pad
    levels at the start of the cycle. Two pushes to one SM, or two pops from one SM, in one
    cycle raise [Invalid_argument], as does an SM index outside 0..3. *)
val step : ?host:Host_op.t list -> t -> int

(** As {!step}, and also returns the RX data of each pop. *)
val step_ex : ?host:Host_op.t list -> t -> step_result

(** Head of the RX FIFO of SM [i], or 0 if it is empty: the combinational [rxf_data]. *)
val rx_head : t -> int -> int

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

(** Host IRQ_FORCE: set the IRQ flags in the mask. *)
val force_irq : t -> int -> unit

(** Host write-1-to-clear of FDEBUG, in the RP2040 layout with ILLEGAL at [31:28]. *)
val clear_fdebug : t -> int -> unit

(** Empty both FIFOs of the SMs in the mask. *)
val flush_fifos : t -> int -> unit

(** Write one IMEM word, at address 0 to 63. *)
val write_imem : t -> int -> int -> unit

(** SMn_EXT.PAGE of SM [i] (bit 0 of the level). It applies from the next {!step} and
    {!debug}, because the fetch address is {PAGE, PC} (engine.md 9). *)
val set_page : t -> int -> int -> unit

(** Block-level views, for the lockstep harness. Register layouts are in engine.md section 3.
    [fstat] and [flevel] are RP2040 FSTAT and FLEVEL. [fdebug] is RP2040 FDEBUG with the
    ILLEGAL flag of each SM in [31:28]. A FIFO of capacity 0 reads as both full and empty.
    [pins_out] and [pins_oe] are the output level and direction registers. *)
val fstat : t -> int

val flevel : t -> int
val fdebug : t -> int
val pins_out : t -> int
val pins_oe : t -> int

(** DBG_CNT of SM [i] (DESIGN.md 7): ISR count [5:0], OSR count [13:8], delay [20:16],
    stall reason [27:24]. *)
val dbg_cnt : t -> int -> int

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
  ; latch_stall : stall
  ; exec_stalled : bool
    (** EXECCTRL.EXEC_STALLED (engine.md F4): a host instruction is latched and its latest
        attempt stalled *)
  ; side_done : bool
  ; host_side_done : bool
  ; sticky : int * int * int * int
  ; txstall : bool
  ; txover : bool
  ; rxunder : bool
  ; rxstall : bool
  ; instr : int (** IMEM word at the fetch address {PAGE, PC}, dbg_instr (engine.md 3) *)
  }

val debug : t -> int -> debug

(** DESIGN.md 7 DBG_CNT.stall_reason code: 0 none, 1 tx_empty, 2 rx_full, 3 autopull,
    4 wait_gpio, 5 wait_pin, 6 wait_irq, 7 irq_wait. The encoding is the one DESIGN §7 now
    defines. *)
val stall_code : stall -> int

val stall_name : stall -> string
