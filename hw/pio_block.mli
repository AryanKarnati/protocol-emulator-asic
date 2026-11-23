(** The PIO block: instruction memory, IRQ flags, pin registers, input synchronisers, and
    [num_sms] engines with their FIFOs (docs/engine.md sections 3, 5, 6 and 9).

    Ports exist for 4 engines whatever [num_sms] is. Engine [i >= num_sms] has no logic:
    its outputs are 0 and inputs aimed at it are ignored.

    The instruction memory has depth 32 or 64. With depth 64, engine [n] fetches
    [IMEM[{PAGE, PC}]], where PAGE is bit 0 of [ext n]. With depth 32 it fetches [IMEM[PC]]
    and ignores [ext] and [imem_addr[5]]. *)

open Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sm_enable : 'a
    ; clkdiv0 : 'a
    ; clkdiv1 : 'a
    ; clkdiv2 : 'a
    ; clkdiv3 : 'a
    ; execctrl0 : 'a
    ; execctrl1 : 'a
    ; execctrl2 : 'a
    ; execctrl3 : 'a
    ; shiftctrl0 : 'a
    ; shiftctrl1 : 'a
    ; shiftctrl2 : 'a
    ; shiftctrl3 : 'a
    ; pinctrl0 : 'a
    ; pinctrl1 : 'a
    ; pinctrl2 : 'a
    ; pinctrl3 : 'a
    ; sync_bypass : 'a
    ; pins_in : 'a
    ; sm_restart : 'a
    ; clkdiv_restart : 'a
    ; fifo_flush : 'a
    ; irq_clear : 'a
    ; irq_force : 'a
    ; fdebug_clear : 'a
    ; txf_push : 'a
    ; txf_sm : 'a
    ; txf_data : 'a
    ; rxf_pop : 'a
    ; rxf_sm : 'a
    ; instr_write : 'a
    ; instr_sm : 'a
    ; instr_data : 'a
    ; imem_write : 'a
    ; imem_addr : 'a
    ; imem_data : 'a
    ; ext0 : 'a
    ; ext1 : 'a
    ; ext2 : 'a
    ; ext3 : 'a
    ; fdebug_set : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { pins_out : 'a
    ; pins_oe : 'a
    ; irq : 'a
    ; rxf_data : 'a
    ; fstat : 'a
    ; flevel : 'a
    ; fdebug : 'a
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
    }
  [@@deriving hardcaml]
end

(** Flat instantiation: the logic is inlined into the parent. [imem_depth] is 32 or 64.
    Raises [Invalid_argument] for any other [num_sms] (1 to 4) or [imem_depth]. *)
val create : num_sms:int -> imem_depth:int -> Scope.t -> Signal.t I.t -> Signal.t O.t

(** Hierarchical instantiation inside a larger design: the block appears as module
    [pio_block], and its own submodules (sm, decode, fifo_join, clkdiv_dbg) below it. *)
val hierarchical
  :  num_sms:int
  -> imem_depth:int
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t

(** The block as a stand-alone circuit named [pio_block], with the database of its
    submodules, for the Verilog printer (gen_verilog). *)
val circuit_with_database : num_sms:int -> imem_depth:int -> Circuit.t * Circuit_database.t

(** The block as a stand-alone circuit with its submodules inlined, for Cyclesim. Same
    logic as [circuit_with_database]. *)
val circuit_with : num_sms:int -> imem_depth:int -> Circuit.t

(** [circuit_with ~num_sms ~imem_depth:64]. *)
val circuit : num_sms:int -> Circuit.t
