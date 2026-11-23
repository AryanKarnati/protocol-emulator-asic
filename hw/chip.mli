(** The whole chip (docs/chip.md sections 3, 4 and 11): the host link, the register block,
    the pin block and pio_block, with 4 SMs and a 64-word IMEM at the top level.
    The ports are the Verilog names of section 4. *)

open Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; ui_in : 'a
    ; uio_in : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { uo_out : 'a
    ; uio_out : 'a
    ; uio_oe : 'a
    ; dbg_pins_out : 'a
    ; dbg_pins_oe : 'a
    ; dbg_irq : 'a
    ; dbg_fstat : 'a
    ; dbg_flevel : 'a
    ; dbg_fdebug : 'a
    ; dbg_pc0 : 'a
    ; dbg_pc1 : 'a
    ; dbg_pc2 : 'a
    ; dbg_pc3 : 'a
    ; dbg_x0 : 'a
    ; dbg_x1 : 'a
    ; dbg_x2 : 'a
    ; dbg_x3 : 'a
    ; dbg_y0 : 'a
    ; dbg_y1 : 'a
    ; dbg_y2 : 'a
    ; dbg_y3 : 'a
    ; dbg_isr0 : 'a
    ; dbg_isr1 : 'a
    ; dbg_isr2 : 'a
    ; dbg_isr3 : 'a
    ; dbg_osr0 : 'a
    ; dbg_osr1 : 'a
    ; dbg_osr2 : 'a
    ; dbg_osr3 : 'a
    ; dbg_cnt0 : 'a
    ; dbg_cnt1 : 'a
    ; dbg_cnt2 : 'a
    ; dbg_cnt3 : 'a
    ; dbg_exec_stalled0 : 'a
    ; dbg_exec_stalled1 : 'a
    ; dbg_exec_stalled2 : 'a
    ; dbg_exec_stalled3 : 'a
    ; dbg_phase0 : 'a
    ; dbg_phase1 : 'a
    ; dbg_phase2 : 'a
    ; dbg_phase3 : 'a
    ; dbg_instr0 : 'a
    ; dbg_instr1 : 'a
    ; dbg_instr2 : 'a
    ; dbg_instr3 : 'a
    ; dbg_bus_write : 'a
    ; dbg_bus_read : 'a
    ; dbg_bus_commit : 'a
    ; dbg_bus_addr : 'a
    ; dbg_bus_wdata : 'a
    ; dbg_bus_rdata : 'a
    }
  [@@deriving hardcaml]
end

(** The chip, with pio_block instantiated in the scope. [num_sms] is 1 to 4 and
    [imem_depth] 32 or 64. Used by the top. *)
val create : num_sms:int -> imem_depth:int -> Scope.t -> Signal.t I.t -> Signal.t O.t

(** The chip for the Verilog printer, with pio_block as a module of its own. *)
val circuit_with_database : num_sms:int -> imem_depth:int -> Circuit.t * Circuit_database.t

(** The chip for Cyclesim, with every submodule inlined (section 3). *)
val circuit : num_sms:int -> imem_depth:int -> Circuit.t
