(* The whole chip (docs/chip.md): the host link, the register block, the pin block and
   pio_block. It has the Tiny Tapeout pads and the dbg_* ports of section 4. The reset
   synchroniser is in top.ml.

   Loops. Each combinational path runs from a register to a register or a pad, but the
   modules refer to each other: the register block reads pio_block's outputs, and
   pio_block takes its configuration from the register block. The pio_block outputs are
   therefore wires, driven once pio_block exists. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    ; dbg_pins_out : 'a [@bits 32]
    ; dbg_pins_oe : 'a [@bits 32]
    ; dbg_irq : 'a [@bits 8]
    ; dbg_fstat : 'a [@bits 32]
    ; dbg_flevel : 'a [@bits 32]
    ; dbg_fdebug : 'a [@bits 32]
    ; dbg_pc0 : 'a [@bits 5]
    ; dbg_pc1 : 'a [@bits 5]
    ; dbg_pc2 : 'a [@bits 5]
    ; dbg_pc3 : 'a [@bits 5]
    ; dbg_x0 : 'a [@bits 32]
    ; dbg_x1 : 'a [@bits 32]
    ; dbg_x2 : 'a [@bits 32]
    ; dbg_x3 : 'a [@bits 32]
    ; dbg_y0 : 'a [@bits 32]
    ; dbg_y1 : 'a [@bits 32]
    ; dbg_y2 : 'a [@bits 32]
    ; dbg_y3 : 'a [@bits 32]
    ; dbg_isr0 : 'a [@bits 32]
    ; dbg_isr1 : 'a [@bits 32]
    ; dbg_isr2 : 'a [@bits 32]
    ; dbg_isr3 : 'a [@bits 32]
    ; dbg_osr0 : 'a [@bits 32]
    ; dbg_osr1 : 'a [@bits 32]
    ; dbg_osr2 : 'a [@bits 32]
    ; dbg_osr3 : 'a [@bits 32]
    ; dbg_cnt0 : 'a [@bits 32]
    ; dbg_cnt1 : 'a [@bits 32]
    ; dbg_cnt2 : 'a [@bits 32]
    ; dbg_cnt3 : 'a [@bits 32]
    ; dbg_exec_stalled0 : 'a
    ; dbg_exec_stalled1 : 'a
    ; dbg_exec_stalled2 : 'a
    ; dbg_exec_stalled3 : 'a
    ; dbg_phase0 : 'a [@bits 25]
    ; dbg_phase1 : 'a [@bits 25]
    ; dbg_phase2 : 'a [@bits 25]
    ; dbg_phase3 : 'a [@bits 25]
    ; dbg_instr0 : 'a [@bits 16]
    ; dbg_instr1 : 'a [@bits 16]
    ; dbg_instr2 : 'a [@bits 16]
    ; dbg_instr3 : 'a [@bits 16]
    ; dbg_bus_write : 'a
    ; dbg_bus_read : 'a
    ; dbg_bus_commit : 'a
    ; dbg_bus_addr : 'a [@bits 16]
    ; dbg_bus_wdata : 'a [@bits 32]
    ; dbg_bus_rdata : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

let bitof x k = select x k k

(* The chip, with pio_block instantiated in [scope]. The sub-blocks of the link, the
   register block and the pins are flat. *)
let create ~num_sms ~imem_depth (scope : Scope.t) (i : _ I.t) =
  (* Forward references. *)
  let pio_o = Pio_block.O.Of_signal.wires () in
  let pins_in_w = wire 32 in
  let status_w = wire 8 in
  let rdata_w = wire 32 in
  let link =
    Hostlink.create
      { Hostlink.I.clock = i.clock
      ; rst_n = i.rst_n
      ; sck = bitof i.ui_in 5
      ; mosi = bitof i.ui_in 6
      ; cs_n = bitof i.ui_in 7
      ; status = status_w
      ; rdata = rdata_w
      }
  in
  let regs =
    Regs.create
      ~num_sms
      ~imem_depth
      { Regs.I.clock = i.clock
      ; rst_n = i.rst_n
      ; bus_write = link.bus_write
      ; bus_read = link.bus_read
      ; bus_commit = link.bus_commit
      ; bus_addr = link.bus_addr
      ; bus_wdata = link.bus_wdata
      ; pins_in = pins_in_w
      ; pins_out = pio_o.pins_out
      ; pins_oe = pio_o.pins_oe
      ; irq = pio_o.irq
      ; fstat = pio_o.fstat
      ; flevel = pio_o.flevel
      ; fdebug = pio_o.fdebug
      ; rxf_data = pio_o.rxf_data
      ; dbg_pc0 = pio_o.dbg_pc0
      ; dbg_pc1 = pio_o.dbg_pc1
      ; dbg_pc2 = pio_o.dbg_pc2
      ; dbg_pc3 = pio_o.dbg_pc3
      ; dbg_x0 = pio_o.dbg_x0
      ; dbg_x1 = pio_o.dbg_x1
      ; dbg_x2 = pio_o.dbg_x2
      ; dbg_x3 = pio_o.dbg_x3
      ; dbg_y0 = pio_o.dbg_y0
      ; dbg_y1 = pio_o.dbg_y1
      ; dbg_y2 = pio_o.dbg_y2
      ; dbg_y3 = pio_o.dbg_y3
      ; dbg_isr0 = pio_o.dbg_isr0
      ; dbg_isr1 = pio_o.dbg_isr1
      ; dbg_isr2 = pio_o.dbg_isr2
      ; dbg_isr3 = pio_o.dbg_isr3
      ; dbg_osr0 = pio_o.dbg_osr0
      ; dbg_osr1 = pio_o.dbg_osr1
      ; dbg_osr2 = pio_o.dbg_osr2
      ; dbg_osr3 = pio_o.dbg_osr3
      ; dbg_cnt0 = pio_o.dbg_cnt0
      ; dbg_cnt1 = pio_o.dbg_cnt1
      ; dbg_cnt2 = pio_o.dbg_cnt2
      ; dbg_cnt3 = pio_o.dbg_cnt3
      ; dbg_exec_stalled0 = pio_o.dbg_exec_stalled0
      ; dbg_exec_stalled1 = pio_o.dbg_exec_stalled1
      ; dbg_exec_stalled2 = pio_o.dbg_exec_stalled2
      ; dbg_exec_stalled3 = pio_o.dbg_exec_stalled3
      ; dbg_instr0 = pio_o.dbg_instr0
      ; dbg_instr1 = pio_o.dbg_instr1
      ; dbg_instr2 = pio_o.dbg_instr2
      ; dbg_instr3 = pio_o.dbg_instr3
      }
  in
  let pins =
    Pins.create
      ~num_sms
      { Pins.I.ui_in = i.ui_in
      ; uio_in = i.uio_in
      ; pins_out = pio_o.pins_out
      ; pins_oe = pio_o.pins_oe
      ; pad_od = regs.pad_od
      ; sync_bypass = regs.sync_bypass
      ; hostirq_en = regs.hostirq_en
      ; irq = pio_o.irq
      ; fstat = pio_o.fstat
      ; miso = link.miso
      }
  in
  pins_in_w <== pins.pins_in;
  status_w <== pins.status;
  rdata_w <== regs.rdata;
  (* pio_block. Its ext inputs are 32 bits, and only bit 0 (PAGE) is ever set. *)
  let pio =
    Pio_block.hierarchical
      ~num_sms
      ~imem_depth
      scope
      { Pio_block.I.clock = i.clock
      ; rst_n = i.rst_n
      ; sm_enable = regs.sm_enable
      ; clkdiv0 = regs.clkdiv0
      ; clkdiv1 = regs.clkdiv1
      ; clkdiv2 = regs.clkdiv2
      ; clkdiv3 = regs.clkdiv3
      ; execctrl0 = regs.execctrl0
      ; execctrl1 = regs.execctrl1
      ; execctrl2 = regs.execctrl2
      ; execctrl3 = regs.execctrl3
      ; shiftctrl0 = regs.shiftctrl0
      ; shiftctrl1 = regs.shiftctrl1
      ; shiftctrl2 = regs.shiftctrl2
      ; shiftctrl3 = regs.shiftctrl3
      ; pinctrl0 = regs.pinctrl0
      ; pinctrl1 = regs.pinctrl1
      ; pinctrl2 = regs.pinctrl2
      ; pinctrl3 = regs.pinctrl3
      ; sync_bypass = pins.sync_bypass32
      ; pins_in = pins.pins_in
      ; sm_restart = regs.sm_restart
      ; clkdiv_restart = regs.clkdiv_restart
      ; fifo_flush = regs.fifo_flush
      ; irq_clear = regs.irq_clear
      ; irq_force = regs.irq_force
      ; fdebug_clear = regs.fdebug_clear
      ; txf_push = regs.txf_push
      ; txf_sm = regs.txf_sm
      ; txf_data = regs.txf_data
      ; rxf_pop = regs.rxf_pop
      ; rxf_sm = regs.rxf_sm
      ; instr_write = regs.instr_write
      ; instr_sm = regs.instr_sm
      ; instr_data = regs.instr_data
      ; imem_write = regs.imem_write
      ; imem_addr = regs.imem_addr
      ; imem_data = regs.imem_data
      ; ext0 = uresize regs.ext0 32
      ; ext1 = uresize regs.ext1 32
      ; ext2 = uresize regs.ext2 32
      ; ext3 = uresize regs.ext3 32
      ; fdebug_set = regs.fdebug_set
      }
  in
  ignore (Pio_block.O.map2 pio_o pio ~f:(fun w s -> w <== s));
  { O.uo_out = pins.uo_out
  ; uio_out = pins.uio_out
  ; uio_oe = pins.uio_oe
  ; dbg_pins_out = pio.pins_out
  ; dbg_pins_oe = pio.pins_oe
  ; dbg_irq = pio.irq
  ; dbg_fstat = pio.fstat
  ; dbg_flevel = pio.flevel
  ; dbg_fdebug = pio.fdebug
  ; dbg_pc0 = pio.dbg_pc0
  ; dbg_pc1 = pio.dbg_pc1
  ; dbg_pc2 = pio.dbg_pc2
  ; dbg_pc3 = pio.dbg_pc3
  ; dbg_x0 = pio.dbg_x0
  ; dbg_x1 = pio.dbg_x1
  ; dbg_x2 = pio.dbg_x2
  ; dbg_x3 = pio.dbg_x3
  ; dbg_y0 = pio.dbg_y0
  ; dbg_y1 = pio.dbg_y1
  ; dbg_y2 = pio.dbg_y2
  ; dbg_y3 = pio.dbg_y3
  ; dbg_isr0 = pio.dbg_isr0
  ; dbg_isr1 = pio.dbg_isr1
  ; dbg_isr2 = pio.dbg_isr2
  ; dbg_isr3 = pio.dbg_isr3
  ; dbg_osr0 = pio.dbg_osr0
  ; dbg_osr1 = pio.dbg_osr1
  ; dbg_osr2 = pio.dbg_osr2
  ; dbg_osr3 = pio.dbg_osr3
  ; dbg_cnt0 = pio.dbg_cnt0
  ; dbg_cnt1 = pio.dbg_cnt1
  ; dbg_cnt2 = pio.dbg_cnt2
  ; dbg_cnt3 = pio.dbg_cnt3
  ; dbg_exec_stalled0 = pio.dbg_exec_stalled0
  ; dbg_exec_stalled1 = pio.dbg_exec_stalled1
  ; dbg_exec_stalled2 = pio.dbg_exec_stalled2
  ; dbg_exec_stalled3 = pio.dbg_exec_stalled3
  ; dbg_phase0 = pio.dbg_phase0
  ; dbg_phase1 = pio.dbg_phase1
  ; dbg_phase2 = pio.dbg_phase2
  ; dbg_phase3 = pio.dbg_phase3
  ; dbg_instr0 = pio.dbg_instr0
  ; dbg_instr1 = pio.dbg_instr1
  ; dbg_instr2 = pio.dbg_instr2
  ; dbg_instr3 = pio.dbg_instr3
  ; dbg_bus_write = link.bus_write
  ; dbg_bus_read = link.bus_read
  ; dbg_bus_commit = link.bus_commit
  ; dbg_bus_addr = link.bus_addr
  ; dbg_bus_wdata = link.bus_wdata
  ; dbg_bus_rdata = regs.rdata
  }
;;

module Circuit_io = Circuit.With_interface (I) (O)

(* The chip for the Verilog printer: pio_block stays a module of its own. *)
let circuit_with_database ~num_sms ~imem_depth =
  let scope = Scope.create () in
  let circuit = Circuit_io.create_exn ~name:"chip" (create ~num_sms ~imem_depth scope) in
  circuit, Scope.circuit_database scope
;;

(* The chip for Cyclesim: every submodule is inlined. *)
let circuit ~num_sms ~imem_depth =
  let scope = Scope.create ~flatten_design:true () in
  Circuit_io.create_exn ~name:"chip" (create ~num_sms ~imem_depth scope)
;;
