(* The register block (docs/chip.md section 8): the bus side of the chip. It stores the
   configuration, turns bus writes into pulses for pio_block in the same cycle (8.2), and
   answers bus reads combinationally from bus_addr (8.3).

   Decode. A bus address falls in one of three regions: the low registers (addr < 0x100),
   IMEM (0x100 to 0x1FF), or an SM block (0x200 to 0x2FF, n = addr[7:6], offset =
   addr[5:2]). Within the low region the word index w = addr[7:2] selects the register
   with a single 6-bit mux. Absent SMs (n >= num_sms) have no registers, and their
   addresses read 0 and do nothing. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; bus_write : 'a
    ; bus_read : 'a
    ; bus_commit : 'a
    ; bus_addr : 'a [@bits 16]
    ; bus_wdata : 'a [@bits 32]
    ; pins_in : 'a [@bits 32]
    ; pins_out : 'a [@bits 32]
    ; pins_oe : 'a [@bits 32]
    ; irq : 'a [@bits 8]
    ; fstat : 'a [@bits 32]
    ; flevel : 'a [@bits 32]
    ; fdebug : 'a [@bits 32]
    ; rxf_data : 'a [@bits 32]
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
    ; dbg_instr0 : 'a [@bits 16]
    ; dbg_instr1 : 'a [@bits 16]
    ; dbg_instr2 : 'a [@bits 16]
    ; dbg_instr3 : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { rdata : 'a [@bits 32]
    ; sm_enable : 'a [@bits 4]
    ; sync_bypass : 'a [@bits 24]
    ; pad_od : 'a [@bits 8]
    ; hostirq_en : 'a [@bits 12]
    ; clkdiv0 : 'a [@bits 32]
    ; clkdiv1 : 'a [@bits 32]
    ; clkdiv2 : 'a [@bits 32]
    ; clkdiv3 : 'a [@bits 32]
    ; execctrl0 : 'a [@bits 32]
    ; execctrl1 : 'a [@bits 32]
    ; execctrl2 : 'a [@bits 32]
    ; execctrl3 : 'a [@bits 32]
    ; shiftctrl0 : 'a [@bits 32]
    ; shiftctrl1 : 'a [@bits 32]
    ; shiftctrl2 : 'a [@bits 32]
    ; shiftctrl3 : 'a [@bits 32]
    ; pinctrl0 : 'a [@bits 32]
    ; pinctrl1 : 'a [@bits 32]
    ; pinctrl2 : 'a [@bits 32]
    ; pinctrl3 : 'a [@bits 32]
    ; ext0 : 'a
    ; ext1 : 'a
    ; ext2 : 'a
    ; ext3 : 'a
    ; sm_restart : 'a [@bits 4]
    ; clkdiv_restart : 'a [@bits 4]
    ; fifo_flush : 'a [@bits 4]
    ; irq_clear : 'a [@bits 8]
    ; irq_force : 'a [@bits 8]
    ; fdebug_clear : 'a [@bits 32]
    ; fdebug_set : 'a [@bits 32]
    ; txf_push : 'a
    ; txf_sm : 'a [@bits 2]
    ; txf_data : 'a [@bits 32]
    ; rxf_pop : 'a
    ; rxf_sm : 'a [@bits 2]
    ; instr_write : 'a
    ; instr_sm : 'a [@bits 2]
    ; instr_data : 'a [@bits 16]
    ; imem_write : 'a
    ; imem_addr : 'a [@bits 6]
    ; imem_data : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

(* Reset values and write masks (chip.md section 8.1; datasheet 3.7 layouts). *)
let id_value = 0x504C4754
let clkdiv_mask = 0xFFFFFF00
let clkdiv_reset = 0x00010000
let execctrl_mask = 0x7FFFFF9F
let execctrl_reset = 0x0001F000
let shiftctrl_mask = 0xFFFF0000
let shiftctrl_reset = 0x000C0000
let pinctrl_reset = 0x14000000

(* HWCFG: [5:0] FIFO depth 4, [11:8] SMs, [22:16] IMEM depth, [24] LCU (0),
   [25] SRAM (0), [31:28] version 1. *)
let hwcfg_value ~num_sms ~imem_depth =
  4 lor (num_sms lsl 8) lor (imem_depth lsl 16) lor (1 lsl 28)
;;

let bitof x k = select x k k
let is v s = s ==: of_int ~width:(width s) v

(* A bit vector from a list of 1-bit signals, least significant first. *)
let vec_lsb bits = concat_msb (List.rev bits)

let create ~num_sms ~imem_depth (i : _ I.t) =
  if num_sms < 1 || num_sms > 4
  then invalid_arg (Printf.sprintf "regs: num_sms must be 1 to 4, got %d" num_sms);
  if imem_depth <> 32 && imem_depth <> 64
  then invalid_arg (Printf.sprintf "regs: imem_depth must be 32 or 64, got %d" imem_depth);
  let n = num_sms in
  let rspec reset_to =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clock)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to
  in
  let rreg ~width ~reset ~enable d = reg (rspec (of_int ~width reset)) ~enable d in
  let wr = i.bus_write in
  let a = i.bus_addr in
  let wd = i.bus_wdata in
  (* Regions. The address is word-aligned, so bits 1:0 are not decoded. *)
  let hi_zero = is 0 (select a 15 10) in
  let low = hi_zero &: ~:(bitof a 9) &: ~:(bitof a 8) in
  let imem_r = hi_zero &: ~:(bitof a 9) &: bitof a 8 in
  let sm_r = hi_zero &: bitof a 9 &: ~:(bitof a 8) in
  let w = select a 7 2 in
  let smn = select a 7 6 in
  let off = select a 5 2 in
  let rxf_idx = select w 1 0 in
  (* A write to the low register with word index [k]. *)
  let wr_low k = wr &: low &: is k w in
  (* A write to register [off] of SM [k]. *)
  let wr_sm k off_v = wr &: sm_r &: (smn ==:. k) &: (off ==:. off_v) in
  (* An index [idx] is a present SM when it is below num_sms. *)
  let present idx = if n = 4 then vdd else idx <: of_int ~width:2 n in
  (* Configuration. *)
  let en_q =
    rreg
      ~width:4
      ~reset:0
      ~enable:(wr_low 2)
      (select wd 3 0 &: of_int ~width:4 ((1 lsl n) - 1))
  in
  let hostirq_q = rreg ~width:12 ~reset:0 ~enable:(wr_low 8) (select wd 11 0) in
  let pad_od_q = rreg ~width:8 ~reset:0 ~enable:(wr_low 9) (select wd 7 0) in
  let sync_q = rreg ~width:24 ~reset:0 ~enable:(wr_low 10) (select wd 23 0) in
  let scratch_q = rreg ~width:32 ~reset:0 ~enable:(wr_low 14) wd in
  (* Per-SM configuration. Absent SMs get constant zero. *)
  let zero32 = zero 32 in
  let per_sm k =
    if k >= n
    then zero32, zero32, zero32, zero32, gnd
    else (
      let clkdiv =
        rreg
          ~width:32
          ~reset:clkdiv_reset
          ~enable:(wr_sm k 0)
          (wd &: of_int ~width:32 clkdiv_mask)
      in
      let execctrl =
        rreg
          ~width:32
          ~reset:execctrl_reset
          ~enable:(wr_sm k 1)
          (wd &: of_int ~width:32 execctrl_mask)
      in
      let shiftctrl =
        rreg
          ~width:32
          ~reset:shiftctrl_reset
          ~enable:(wr_sm k 2)
          (wd &: of_int ~width:32 shiftctrl_mask)
      in
      let pinctrl =
        rreg ~width:32 ~reset:pinctrl_reset ~enable:(wr_sm k 5) wd
      in
      let ext =
        rreg
          ~width:1
          ~reset:0
          ~enable:(wr_sm k 6)
          (if imem_depth = 64 then bitof wd 0 else gnd)
      in
      clkdiv, execctrl, shiftctrl, pinctrl, ext)
  in
  let sms = Array.init 4 per_sm in
  let clkdiv_q k = let c, _, _, _, _ = sms.(k) in c in
  let execctrl_q k = let _, e, _, _, _ = sms.(k) in e in
  let shiftctrl_q k = let _, _, s, _, _ = sms.(k) in s in
  let pinctrl_q k = let _, _, _, p, _ = sms.(k) in p in
  let ext_q k = let _, _, _, _, x = sms.(k) in x in
  (* Pulses (chip.md 8.2). Each is presented in the cycle of the write. *)
  let ctrl_wr = wr_low 2 in
  let ctrl_bit k b = if k < n then ctrl_wr &: bitof wd b else gnd in
  let sm_restart = vec_lsb (List.init 4 (fun k -> ctrl_bit k (4 + k))) in
  let clkdiv_restart = vec_lsb (List.init 4 (fun k -> ctrl_bit k (8 + k))) in
  let fifo_flush =
    vec_lsb
      (List.init 4 (fun k ->
         if k >= n
         then gnd
         else
           wr_sm k 2 &: (select wd 31 30 <>: select (shiftctrl_q k) 31 30)))
  in
  let irq_clear = mux2 (wr_low 6) (select wd 7 0) (zero 8) in
  let irq_force = mux2 (wr_low 7) (select wd 7 0) (zero 8) in
  let fdebug_clear = mux2 (wr_low 4) wd zero32 in
  (* TX push (0x040 + 4n): w = 16 + n. RX pop (0x050 + 4n): w = 20 + n. *)
  let tx_wr = wr &: low &: is 4 (select w 5 2) &: present rxf_idx in
  let rx_region = low &: is 5 (select w 5 2) &: present rxf_idx in
  (* RX (8.3). The read in cycle t records whether the FIFO was empty; the commit acts on
     that record. The commit is always the cycle after the bit before it, so the record
     is always of the same word. *)
  let rxe_q =
    reg
      (Reg_spec.create () ~clock:i.clock)
      ~enable:i.bus_read
      (mux rxf_idx [ bitof i.fstat 8; bitof i.fstat 9; bitof i.fstat 10; bitof i.fstat 11 ])
  in
  let rxf_pop = i.bus_commit &: rx_region &: ~:rxe_q in
  let fdebug_set =
    vec_lsb
      (List.init 32 (fun b ->
         if b >= 8 && b < 12
         then i.bus_commit &: rx_region &: rxe_q &: is (b - 8) rxf_idx
         else gnd))
  in
  (* IMEM (0x100 + 4k): k = w, written only when k < depth. *)
  let imem_w =
    imem_r &: wr &: (if imem_depth = 64 then vdd else ~:(bitof w 5))
  in
  (* SM instruction and FIFO-join pulses, gated by present SMs. *)
  let instr_write = wr &: sm_r &: (off ==:. 4) &: present smn in
  (* Read mux (8.3). Each entry is the value of the register in the cycle of the read. *)
  let low_entries = Array.make 64 zero32 in
  let set idx v = low_entries.(idx) <- v in
  set 0 (of_int ~width:32 id_value);
  set 1 (of_int ~width:32 (hwcfg_value ~num_sms ~imem_depth));
  set 2 (uresize en_q 32);
  set 3 i.fstat;
  set 4 i.fdebug;
  set 5 i.flevel;
  set 6 (uresize i.irq 32);
  set 8 (uresize hostirq_q 32);
  set 9 (uresize pad_od_q 32);
  set 10 (uresize sync_q 32);
  set 11 i.pins_in;
  set 12 i.pins_out;
  set 13 i.pins_oe;
  set 14 scratch_q;
  for k = 0 to n - 1 do
    set (20 + k) i.rxf_data
  done;
  let low_val = mux w (Array.to_list low_entries) in
  let dbg_pc = [| i.dbg_pc0; i.dbg_pc1; i.dbg_pc2; i.dbg_pc3 |] in
  let dbg_x = [| i.dbg_x0; i.dbg_x1; i.dbg_x2; i.dbg_x3 |] in
  let dbg_y = [| i.dbg_y0; i.dbg_y1; i.dbg_y2; i.dbg_y3 |] in
  let dbg_isr = [| i.dbg_isr0; i.dbg_isr1; i.dbg_isr2; i.dbg_isr3 |] in
  let dbg_osr = [| i.dbg_osr0; i.dbg_osr1; i.dbg_osr2; i.dbg_osr3 |] in
  let dbg_cnt = [| i.dbg_cnt0; i.dbg_cnt1; i.dbg_cnt2; i.dbg_cnt3 |] in
  let dbg_stall = [| i.dbg_exec_stalled0; i.dbg_exec_stalled1; i.dbg_exec_stalled2; i.dbg_exec_stalled3 |] in
  let dbg_instr = [| i.dbg_instr0; i.dbg_instr1; i.dbg_instr2; i.dbg_instr3 |] in
  let sm_block k =
    if k >= n
    then zero32
    else (
      let e = Array.make 16 zero32 in
      e.(0) <- uresize (clkdiv_q k) 32;
      e.(1) <- concat_msb [ dbg_stall.(k); select (execctrl_q k) 30 0 ];
      e.(2) <- uresize (shiftctrl_q k) 32;
      e.(3) <- uresize dbg_pc.(k) 32;
      e.(4) <- uresize dbg_instr.(k) 32;
      e.(5) <- uresize (pinctrl_q k) 32;
      e.(6) <- uresize (ext_q k) 32;
      e.(11) <- dbg_x.(k);
      e.(12) <- dbg_y.(k);
      e.(13) <- dbg_isr.(k);
      e.(14) <- dbg_osr.(k);
      e.(15) <- dbg_cnt.(k);
      mux off (Array.to_list e))
  in
  let sm_val = mux smn (List.init 4 sm_block) in
  (* Regions are disjoint. IMEM reads 0. *)
  let rdata = mux2 low low_val (mux2 sm_r sm_val zero32) in
  { O.rdata
  ; sm_enable = en_q
  ; sync_bypass = sync_q
  ; pad_od = pad_od_q
  ; hostirq_en = hostirq_q
  ; clkdiv0 = clkdiv_q 0
  ; clkdiv1 = clkdiv_q 1
  ; clkdiv2 = clkdiv_q 2
  ; clkdiv3 = clkdiv_q 3
  ; execctrl0 = execctrl_q 0
  ; execctrl1 = execctrl_q 1
  ; execctrl2 = execctrl_q 2
  ; execctrl3 = execctrl_q 3
  ; shiftctrl0 = shiftctrl_q 0
  ; shiftctrl1 = shiftctrl_q 1
  ; shiftctrl2 = shiftctrl_q 2
  ; shiftctrl3 = shiftctrl_q 3
  ; pinctrl0 = pinctrl_q 0
  ; pinctrl1 = pinctrl_q 1
  ; pinctrl2 = pinctrl_q 2
  ; pinctrl3 = pinctrl_q 3
  ; ext0 = ext_q 0
  ; ext1 = ext_q 1
  ; ext2 = ext_q 2
  ; ext3 = ext_q 3
  ; sm_restart
  ; clkdiv_restart
  ; fifo_flush
  ; irq_clear
  ; irq_force
  ; fdebug_clear
  ; fdebug_set
  ; txf_push = tx_wr
  ; txf_sm = rxf_idx
  ; txf_data = wd
  ; rxf_pop
  ; rxf_sm = rxf_idx
  ; instr_write
  ; instr_sm = smn
  ; instr_data = select wd 15 0
  ; imem_write = imem_w
  ; imem_addr = w
  ; imem_data = select wd 15 0
  }
;;

module Circuit_io = Circuit.With_interface (I) (O)

(* The register block alone, flat, for the tests. *)
let circuit ~num_sms ~imem_depth =
  Circuit_io.create_exn ~name:"regs" (create ~num_sms ~imem_depth)
;;
