(* One PIO state machine (engine.md sections 3 and 5, 6). Block 2.

   Each cycle the engine does one of:
   - an attempt of the latched instruction, if one is latched and it is forced (F1: every
     cycle, whatever the divider, enable or delay), or EXEC-latched on an enabled tick with
     delay 0 (F2);
   - an attempt of the instruction at PC, on an enabled tick with delay 0, when nothing is
     latched;
   - a delay countdown, on an enabled tick with delay > 0 and no forced instruction.

   An attempt either completes or stalls. A stalled attempt changes nothing except the
   stall reason, the side-set-done flag, the IRQ wait state and the EXEC_STALLED flag.

   The state is named after the registers it becomes in the Verilog (pc_q, x_q, ...).
   Host operations (H1 to H9) are handled outside this module, in fifo_join.ml and
   pio_block.ml. Only SM_RESTART and CLKDIV_RESTART reach this module. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; sm_num : 'a [@bits 2]
    ; enable : 'a
    ; restart : 'a
    ; clkdiv_restart : 'a
    ; clkdiv_int : 'a [@bits 16]
    ; clkdiv_frac : 'a [@bits 8]
    ; execctrl : 'a [@bits 32]
    ; shiftctrl : 'a [@bits 32]
    ; pinctrl : 'a [@bits 32]
    ; instr_write : 'a
    ; instr_data : 'a [@bits 16]
    ; imem_word : 'a [@bits 16]
    ; in_sel : 'a [@bits 32]
    ; tx_head : 'a [@bits 32]
    ; tx_empty : 'a
    ; tx_level : 'a [@bits 4]
    ; rx_full : 'a
    ; rx_level : 'a [@bits 4]
    ; irq_q : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { pc : 'a [@bits 5]
    ; lvl_mask : 'a [@bits 32]
    ; lvl_val : 'a [@bits 32]
    ; dir_mask : 'a [@bits 32]
    ; dir_val : 'a [@bits 32]
    ; irq_set : 'a [@bits 8]
    ; irq_clr : 'a [@bits 8]
    ; tx_pop : 'a
    ; rx_push : 'a
    ; rx_push_data : 'a [@bits 32]
    ; txstall : 'a
    ; rxstall : 'a
    ; illegal : 'a
    ; x : 'a [@bits 32]
    ; y : 'a [@bits 32]
    ; isr : 'a [@bits 32]
    ; osr : 'a [@bits 32]
    ; dbg_cnt : 'a [@bits 32]
    ; exec_stalled : 'a
    ; phase : 'a [@bits 25]
    }
  [@@deriving hardcaml]
end

let c2 k = of_int ~width:2 k
let c3 k = of_int ~width:3 k
let c4 k = of_int ~width:4 k
let c6 k = of_int ~width:6 k
let zero32 = zero 32
let bitof x n = select x n n

(* Pull threshold or push threshold: a field of 0 means 32 (engine.md R3). *)
let thr_of f5 = mux2 (f5 ==: zero 5) (c6 32) (uresize f5 6)

(* 32-bit mask with bit j set iff j < n6 (n6 in 0..32). *)
let thermo32 n6 = concat_msb (List.rev (List.init 32 (fun j -> c6 j <: n6)))

(* Rotate left and right by a 5-bit variable amount, as a log shifter. *)
let rotl_var x amt =
  let rec go x k = if k = 5 then x else go (mux2 (bitof amt k) (rotl x (1 lsl k)) x) (k + 1) in
  go x 0
;;

let rotr_var x amt =
  let rec go x k = if k = 5 then x else go (mux2 (bitof amt k) (rotr x (1 lsl k)) x) (k + 1) in
  go x 0
;;

(* Shifts by a 6-bit amount in 0..32. A shift by 32 gives 0. *)
let shl_var x n6 =
  mux2 (n6 ==: c6 32) zero32 (log_shift sll x (select n6 4 0))
;;

let shr_var x n6 =
  mux2 (n6 ==: c6 32) zero32 (log_shift srl x (select n6 4 0))
;;

(* Saturating add of a shift count, at 32 (datasheet 3.4.4.2). *)
let sat_add cnt n6 =
  let s = uresize cnt 7 +: uresize n6 7 in
  mux2 (s >=: of_int ~width:7 32) (c6 32) (select s 5 0)
;;

(* IRQ flag index (engine.md R14): with REL, the low two bits are added to the SM number. *)
let irq_flag_index sm_num rel idx =
  mux2 rel (concat_msb [ bitof idx 2; select idx 1 0 +: sm_num ]) idx
;;

let onehot8 idx en =
  concat_msb (List.rev (List.init 8 (fun k -> en &: (idx ==: c3 k))))
;;

let create (scope : Scope.t) (i : _ I.t) =
  let mkr ~width ~reset_to =
    ignore width;
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to
  in
  let ex = i.execctrl in
  let sh = i.shiftctrl in
  let pcfg = i.pinctrl in
  (* EXECCTRL (datasheet 3.7, SM0_EXECCTRL). *)
  let side_en = bitof ex 30 in
  let side_pindir = bitof ex 29 in
  let jmp_pin = select ex 28 24 in
  let out_sticky = bitof ex 17 in
  let wrap_top = select ex 16 12 in
  let wrap_bottom = select ex 11 7 in
  let status_sel = bitof ex 4 in
  let status_n = select ex 3 0 in
  (* SHIFTCTRL. *)
  let pull_thr = thr_of (select sh 29 25) in
  let push_thr = thr_of (select sh 24 20) in
  let out_right = bitof sh 19 in
  let in_right = bitof sh 18 in
  let autopull = bitof sh 17 in
  let autopush = bitof sh 16 in
  (* PINCTRL. *)
  let sideset_count = select pcfg 31 29 in
  let set_count6 = uresize (select pcfg 28 26) 6 in
  let out_count6 = select pcfg 25 20 in
  let in_base = select pcfg 19 15 in
  let sideset_base = select pcfg 14 10 in
  let set_base = select pcfg 9 5 in
  let out_base = select pcfg 4 0 in
  (* State. Every register is a wire first, so that the next-state logic can refer to
     any of them. *)
  let pc = wire 5 in
  let x = wire 32 in
  let y = wire 32 in
  let isr = wire 32 in
  let osr = wire 32 in
  let isr_cnt = wire 6 in
  let osr_cnt = wire 6 in
  let delay = wire 5 in
  let latch_valid = wire 1 in
  let latch_forced = wire 1 in
  let latch_instr = wire 16 in
  let imem_stall = wire 4 in
  let latch_stall = wire 4 in
  let imem_ss = wire 1 in
  let latch_ss = wire 1 in
  let imem_irqw = wire 1 in
  let latch_irqw = wire 1 in
  let exec_stalled = wire 1 in
  (* OUT_STICKY record: the most recent OUT/SET/MOV pin write, level or direction. *)
  let sticky_mask = wire 32 in
  let sticky_val = wire 32 in
  let sticky_isdir = wire 1 in
  (* Divider (engine.md R10, H4). *)
  let clk_out =
    Clkdiv.hierarchical_dbg
      scope
      { Clkdiv.I.clk = i.clk
      ; rst_n = i.rst_n
      ; int_ = i.clkdiv_int
      ; frac = i.clkdiv_frac
      ; restart = i.clkdiv_restart
      }
  in
  let tick = clk_out.tick in
  (* Which attempt, if any, this cycle. *)
  let forced_act = (latch_valid &: latch_forced) -- "forced_act" in
  let tick_en = (i.enable &: tick) -- "tick_en" in
  let delay_zero = (delay ==: zero 5) -- "delay_zero" in
  let attempt_latch =
    (forced_act |: (latch_valid &: ~:latch_forced &: tick_en &: delay_zero))
    -- "attempt_latch"
  in
  let attempt_imem = (~:latch_valid &: tick_en &: delay_zero) -- "attempt_imem" in
  let attempt = (attempt_latch |: attempt_imem) -- "attempt" in
  (* Delay countdown: an enabled tick with delay > 0, and no forced instruction (F1). *)
  let dec_now = (tick_en &: ~:forced_act &: ~:delay_zero) -- "dec_now" in
  (* The instruction being attempted. latch_valid is 0 for an IMEM attempt. *)
  let word = mux2 latch_valid latch_instr i.imem_word -- "word" in
  let dec =
    Decode.hierarchical
      scope
      { Decode.I.instr = word; sideset_count; side_en }
  in
  let { Decode.O.legal = _
      ; is_jmp
      ; is_wait
      ; is_in
      ; is_out
      ; is_push
      ; is_pull
      ; is_mov
      ; is_irq
      ; is_set
      ; uses_lcu
      ; side_valid
      ; side_value
      ; delay = delay_field
      ; bit_count
      ; _
      }
    =
    dec
  in
  (* engine.md R12: the LCU encodings are reserved in block 2. Reserved words run as a
     NOP and set ILLEGAL. *)
  let ok = (dec.Decode.O.legal &: ~:uses_lcu) -- "ok" in
  let now c = (attempt &: ok &: c) in
  (* Fields of the word. *)
  let w_low5 = select word 4 0 in
  let jmp_cond = select word 7 5 in
  let wait_pol = bitof word 7 in
  let wait_src = select word 6 5 in
  let in_src = select word 7 5 in
  let out_dst = select word 7 5 in
  let push_iffull = bitof word 6 in
  let push_block = bitof word 5 in
  let pull_ifempty = bitof word 6 in
  let pull_block = bitof word 5 in
  let mov_dst = select word 7 5 in
  let mov_op = select word 4 3 in
  let mov_src = select word 2 0 in
  let irq_clr_bit = bitof word 6 in
  let irq_wait_bit = bitof word 5 in
  let irq_rel = bitof word 4 in
  let irq_idx = select word 2 0 in
  let set_dst = select word 7 5 in
  let set_data = select word 4 0 in
  (* The pin bus of IN and MOV PINS: bit j is pin IN_BASE + j (datasheet 3.5.6.2). *)
  let in_sel = i.in_sel in
  let in_sel_bit k = bitof in_sel k in
  let bus = rotr_var in_sel in_base in
  let bus_bit k = bitof bus k in
  (* The IRQ flag this instruction uses (WAIT IRQ and IRQ, engine.md R14). *)
  let flag_idx = irq_flag_index i.sm_num irq_rel irq_idx -- "flag_idx" in
  let flag_val = mux flag_idx (List.init 8 (fun k -> bitof i.irq_q k)) -- "flag_val" in
  (* ---- JMP (datasheet 3.4.2.2) ---- *)
  let jmp_now = now is_jmp in
  let jmp_pin_val = mux jmp_pin (List.init 32 in_sel_bit) in
  let x_zero = (x ==: zero 32) in
  let y_zero = (y ==: zero 32) in
  let jmp_cond_val =
    mux
      jmp_cond
      [ vdd
      ; x_zero
      ; ~:x_zero
      ; y_zero
      ; ~:y_zero
      ; x <>: y
      ; jmp_pin_val
      ; osr_cnt <: pull_thr
      ]
    -- "jmp_cond_val"
  in
  let jmp_taken = (jmp_now &: jmp_cond_val) -- "jmp_taken" in
  let x_dec = (jmp_now &: (jmp_cond ==: c3 2)) -- "x_dec" in
  let y_dec = (jmp_now &: (jmp_cond ==: c3 4)) -- "y_dec" in
  (* ---- WAIT (datasheet 3.4.3.2) ---- *)
  let wait_now = now is_wait in
  let wait_bit =
    mux
      wait_src
      [ mux w_low5 (List.init 32 in_sel_bit)
      ; mux w_low5 (List.init 32 bus_bit)
      ; flag_val
      ; vdd
      ]
    -- "wait_bit"
  in
  let wait_cond = (wait_bit ==: wait_pol) -- "wait_cond" in
  let wait_done = (wait_now &: wait_cond) -- "wait_done" in
  let wait_stall = (wait_now &: ~:wait_cond) -- "wait_stall" in
  let wait_code = mux wait_src [ c4 4; c4 5; c4 6; c4 6 ] in
  let wait_irq_clr = (wait_done &: (wait_src ==: c2 2) &: wait_pol) -- "wait_irq_clr" in
  (* ---- IN (datasheet 3.4.4.2, 3.5.4.1) ---- *)
  let in_now = now is_in in
  let in_src_val = mux in_src [ bus; x; y; zero32; zero32; zero32; isr; osr ] in
  let in_n = bit_count in
  let in_data = (in_src_val &: thermo32 in_n) -- "in_data" in
  let isr_right = (shr_var isr in_n |: shl_var in_data (c6 32 -: in_n)) in
  let isr_left = (shl_var isr in_n |: in_data) in
  let isr_new_in = mux2 in_right isr_right isr_left -- "isr_new_in" in
  let isr_cnt_new = sat_add isr_cnt in_n -- "isr_cnt_new" in
  let in_thr_hit = (autopush &: (isr_cnt_new >=: push_thr)) -- "in_thr_hit" in
  let in_stall = (in_now &: in_thr_hit &: i.I.rx_full) -- "in_stall" in
  let in_push = (in_now &: in_thr_hit &: ~:(i.I.rx_full)) -- "in_push" in
  let in_shift = (in_now &: ~:in_thr_hit) -- "in_shift" in
  (* ---- PUSH (datasheet 3.4.6.2, engine.md R7) ---- *)
  let push_now = now is_push in
  let push_noop = (push_now &: push_iffull &: (isr_cnt <: push_thr)) -- "push_noop" in
  let push_try = (push_now &: ~:push_noop) -- "push_try" in
  let push_stall = (push_try &: push_block &: i.I.rx_full) -- "push_stall" in
  let push_drop = (push_try &: ~:push_block &: i.I.rx_full) -- "push_drop" in
  let push_fire = (push_try &: ~:(i.I.rx_full)) -- "push_fire" in
  let push_clr = (push_drop |: push_fire) -- "push_clr" in
  (* ---- PULL (datasheet 3.4.7.2, engine.md R4) ---- *)
  let pull_now = now is_pull in
  (* R4: with autopull, a PULL is a no-op only when the OSR is full (count 0). IfEmpty
     keeps its own rule: no-op unless the count has reached the threshold. *)
  let pull_noop =
    (pull_now
     &: ((autopull &: (osr_cnt ==: zero 6)) |: (pull_ifempty &: (osr_cnt <: pull_thr))))
    -- "pull_noop"
  in
  let pull_try = (pull_now &: ~:pull_noop) -- "pull_try" in
  let pull_stall = (pull_try &: i.I.tx_empty &: pull_block) -- "pull_stall" in
  let pull_nb_empty = (pull_try &: i.I.tx_empty &: ~:pull_block) -- "pull_nb_empty" in
  let pull_data = (pull_try &: ~:(i.I.tx_empty)) -- "pull_data" in
  let pull_clr = (pull_data |: pull_nb_empty) -- "pull_clr" in
  (* ---- OUT (datasheet 3.4.5.2, 3.5.4.2, engine.md R5) ---- *)
  let out_now = now is_out in
  let out_n = bit_count in
  let autopull_hit = (autopull &: (osr_cnt >=: pull_thr)) -- "autopull_hit" in
  let out_hit = (out_now &: autopull_hit) -- "out_hit" in
  let out_refill_stall = (out_hit &: ~:(i.I.tx_empty)) -- "out_refill_stall" in
  let out_empty_stall = (out_hit &: i.I.tx_empty) -- "out_empty_stall" in
  let out_run = (out_now &: ~:autopull_hit) -- "out_run" in
  let out_data =
    mux2
      out_right
      (osr &: thermo32 out_n)
      (shr_var osr (c6 32 -: out_n))
    -- "out_data"
  in
  let osr_shifted =
    mux2 out_right (shr_var osr out_n) (shl_var osr out_n) -- "osr_shifted"
  in
  let osr_cnt_after = sat_add osr_cnt out_n -- "osr_cnt_after" in
  let out_refill_after =
    (out_run &: autopull &: (osr_cnt_after >=: pull_thr) &: ~:(i.I.tx_empty))
    -- "out_refill_after"
  in
  let out_pins = (out_run &: (out_dst ==: c3 0)) -- "out_pins" in
  let out_x = (out_run &: (out_dst ==: c3 1)) -- "out_x" in
  let out_y = (out_run &: (out_dst ==: c3 2)) -- "out_y" in
  let out_dirs = (out_run &: (out_dst ==: c3 4)) -- "out_dirs" in
  let out_pc = (out_run &: (out_dst ==: c3 5)) -- "out_pc" in
  let out_isr = (out_run &: (out_dst ==: c3 6)) -- "out_isr" in
  let out_exec = (out_run &: (out_dst ==: c3 7)) -- "out_exec" in
  (* ---- MOV (datasheet 3.4.8.2) ---- *)
  let mov_now = now is_mov in
  let status_bit =
    (* STATUS_SEL 0 is TXLEVEL and 1 is RXLEVEL (datasheet 3.7). mux2 returns its first
       argument when the select is 1, so RX comes first. *)
    mux2 status_sel (i.I.rx_level <: status_n) (i.I.tx_level <: status_n) -- "status_bit"
  in
  let mov_src_val =
    mux
      mov_src
      [ bus; x; y; zero32; zero32; repeat status_bit 32; isr; osr ]
    -- "mov_src_val"
  in
  let mov_data =
    mux mov_op [ mov_src_val; ~:mov_src_val; reverse mov_src_val; mov_src_val ]
    -- "mov_data"
  in
  let mov_pins = (mov_now &: (mov_dst ==: c3 0)) -- "mov_pins" in
  let mov_x = (mov_now &: (mov_dst ==: c3 1)) -- "mov_x" in
  let mov_y = (mov_now &: (mov_dst ==: c3 2)) -- "mov_y" in
  let mov_exec = (mov_now &: (mov_dst ==: c3 4)) -- "mov_exec" in
  let mov_pc = (mov_now &: (mov_dst ==: c3 5)) -- "mov_pc" in
  let mov_isr = (mov_now &: (mov_dst ==: c3 6)) -- "mov_isr" in
  let mov_osr = (mov_now &: (mov_dst ==: c3 7)) -- "mov_osr" in
  (* ---- IRQ (datasheet 3.4.9.2, engine.md R9, R13, R15, F5) ---- *)
  let irq_now = now is_irq in
  let irq_clr_now = (irq_now &: irq_clr_bit) -- "irq_clr_now" in
  let irq_set_form = (irq_now &: ~:irq_clr_bit) -- "irq_set_form" in
  let irq_state = mux2 latch_valid latch_irqw imem_irqw -- "irq_state" in
  let irqw_form = (irq_set_form &: irq_wait_bit) -- "irqw_form" in
  let irqw_next = irqw_form &: (~:irq_state |: flag_val) in
  let irq_stall = irqw_next -- "irq_stall" in
  let irq_set_now = (irq_set_form &: ~:irq_state) -- "irq_set_now" in
  (* ---- SET (datasheet 3.4.10.2) ---- *)
  let set_now = now is_set in
  let set_pins = (set_now &: (set_dst ==: c3 0)) -- "set_pins" in
  let set_x = (set_now &: (set_dst ==: c3 1)) -- "set_x" in
  let set_y = (set_now &: (set_dst ==: c3 2)) -- "set_y" in
  let set_dirs = (set_now &: (set_dst ==: c3 4)) -- "set_dirs" in
  let set_d32 = uresize set_data 32 in
  (* ---- Pin writes (datasheet 3.5.6, engine.md R2) ---- *)
  (* One mask rotator and one value rotator serve OUT, MOV PINS and SET. The source, the
     count and the base are selected first, then rotated once. At most one of these
     instructions writes in a cycle, so the selection is exact. The OUT and MOV mapping uses
     OUT_BASE and OUT_COUNT, and SET uses SET_BASE and SET_COUNT (datasheet 3.5.6). *)
  let set_write = (set_pins |: set_dirs) -- "set_write" in
  let pin_base = mux2 set_write set_base out_base in
  let pin_count = mux2 set_write set_count6 out_count6 in
  let pin_data = mux2 mov_pins mov_data (mux2 set_write set_d32 out_data) in
  let pin_mask = rotl_var (thermo32 pin_count) pin_base -- "pin_mask" in
  let pin_val = (rotl_var pin_data pin_base &: pin_mask) -- "pin_val" in
  let m_of f m = repeat f 32 &: m in
  let lvl_write_now = (out_pins |: mov_pins |: set_pins) -- "lvl_write_now" in
  let lvl_new_mask = m_of lvl_write_now pin_mask -- "lvl_new_mask" in
  let lvl_new_val = m_of lvl_write_now pin_val -- "lvl_new_val" in
  let dir_write_now = (out_dirs |: set_dirs) -- "dir_write_now" in
  let dir_new_mask = m_of dir_write_now pin_mask -- "dir_new_mask" in
  let dir_new_val = m_of dir_write_now pin_val -- "dir_new_val" in
  (* OUT_STICKY (engine.md OUT_STICKY): with the SM enabled and no new write this cycle,
     the last write of each kind is asserted again. *)
  let sticky_on = (out_sticky &: i.enable) in
  let write_any = (lvl_write_now |: dir_write_now) -- "write_any" in
  (* The record re-asserts on its own kind only. A new write (of either kind) takes the
     cycle itself; the other kind's new mask is zero, so it does not disturb it. *)
  let rec_lvl = (repeat (sticky_on &: ~:sticky_isdir) 32 &: sticky_mask) in
  let rec_dir = (repeat (sticky_on &: sticky_isdir) 32 &: sticky_mask) in
  let lvl_eff_mask = mux2 write_any lvl_new_mask rec_lvl -- "lvl_eff_mask" in
  let lvl_eff_val =
    mux2 write_any lvl_new_val (repeat (sticky_on &: ~:sticky_isdir) 32 &: sticky_val)
    -- "lvl_eff_val"
  in
  let dir_eff_mask = mux2 write_any dir_new_mask rec_dir -- "dir_eff_mask" in
  let dir_eff_val =
    mux2 write_any dir_new_val (repeat (sticky_on &: sticky_isdir) 32 &: sticky_val)
    -- "dir_eff_val"
  in
  (* Side-set (datasheet 3.5.1, engine.md R11). It applies on the first attempt only, and
     beats OUT, SET and MOV on the same pin. *)
  let ss_flag = mux2 latch_valid latch_ss imem_ss -- "ss_flag" in
  let ss_apply = (attempt &: ~:ss_flag &: side_valid) -- "ss_apply" in
  let ss_nbits = (uresize sideset_count 6 -: uresize side_en 6) -- "ss_nbits" in
  let ss_mask =
    (rotl_var (thermo32 ss_nbits) sideset_base &: repeat ss_apply 32) -- "ss_mask"
  in
  let ss_val =
    (rotl_var (uresize side_value 32) sideset_base &: ss_mask) -- "ss_val"
  in
  let ss_is_dir = repeat side_pindir 32 in
  let ss_lvl_mask = (ss_mask &: ~:ss_is_dir) -- "ss_lvl_mask" in
  let ss_lvl_val = (ss_val &: ~:ss_is_dir) -- "ss_lvl_val" in
  let ss_dir_mask = (ss_mask &: ss_is_dir) -- "ss_dir_mask" in
  let ss_dir_val = (ss_val &: ss_is_dir) -- "ss_dir_val" in
  let lvl_mask_out = (ss_lvl_mask |: lvl_eff_mask) -- "lvl_mask_out" in
  let lvl_val_out = (ss_lvl_val |: (lvl_eff_val &: ~:ss_lvl_mask)) -- "lvl_val_out" in
  let dir_mask_out = (ss_dir_mask |: dir_eff_mask) -- "dir_mask_out" in
  let dir_val_out = (ss_dir_val |: (dir_eff_val &: ~:ss_dir_mask)) -- "dir_val_out" in
  (* ---- Stalls and completion ---- *)
  let stall =
    (push_stall |: pull_stall |: in_stall |: out_hit |: wait_stall |: irq_stall) -- "stall"
  in
  let stall_code =
    mux2
      (push_stall |: in_stall)
      (c4 2)
      (mux2
         pull_stall
         (c4 1)
         (mux2
            out_hit
            (c4 3)
            (mux2 wait_stall wait_code (mux2 irq_stall (c4 7) (zero 4)))))
    -- "stall_code"
  in
  let complete = (attempt &: ~:stall) -- "complete" in
  let imem_done = (attempt_imem &: ~:stall) -- "imem_done" in
  let latch_done = (attempt_latch &: ~:stall) -- "latch_done" in
  (* ---- Program counter (datasheet 3.5.2, engine.md R8) ---- *)
  let pc_write_now =
    (jmp_taken |: out_pc |: mov_pc) -- "pc_write_now"
  in
  let pc_write_latch = (latch_done &: pc_write_now) -- "pc_write_latch" in
  let pc_target =
    mux2
      jmp_taken
      (select word 4 0)
      (mux2 out_pc (select out_data 4 0) (select mov_data 4 0))
    -- "pc_target"
  in
  let pc_adv = mux2 (pc ==: wrap_top) wrap_bottom (pc +: one 5) -- "pc_adv" in
  let pc_next =
    mux2 pc_write_now pc_target (mux2 imem_done pc_adv pc) -- "pc_next"
  in
  (* ---- Delay (engine.md "Delay counter", F1) ---- *)
  let exec_form = (out_exec |: mov_exec) -- "exec_form" in
  let delay_next =
    mux2
      dec_now
      (delay -: one 5)
      (mux2
         (complete &: ~:forced_act)
         (mux2 exec_form (zero 5) delay_field)
         delay)
    -- "delay_next"
  in
  (* ---- ISR and OSR (datasheet 3.4.4, 3.4.5, 3.4.6, 3.4.7, 3.4.8, 3.5.4) ---- *)
  let tx_pop_refill =
    (* engine.md R5, "on any enabled tick that is not an OUT": refill when the threshold is
       reached and TX has data. A PULL or MOV OSR that just cleared the count is excluded. *)
    (autopull &: tick_en &: ~:forced_act &: ~:out_now &: (osr_cnt >=: pull_thr)
     &: ~:(i.I.tx_empty) &: ~:pull_clr &: ~:mov_osr)
    -- "tx_pop_refill"
  in
  let tx_pop =
    (pull_data |: out_refill_stall |: out_refill_after |: tx_pop_refill) -- "tx_pop"
  in
  let isr_next =
    mux2
      mov_isr
      mov_data
      (mux2
         out_isr
         out_data
         (mux2
            (in_push |: push_clr)
            zero32
            (mux2 in_shift isr_new_in isr)))
    -- "isr_next"
  in
  let isr_cnt_next =
    mux2
      mov_isr
      (c6 0)
      (mux2
         out_isr
         out_n
         (mux2
            (in_push |: push_clr)
            (c6 0)
            (mux2 in_shift isr_cnt_new isr_cnt)))
    -- "isr_cnt_next"
  in
  let osr_refill_val =
    out_refill_after |: out_refill_stall |: pull_data |: tx_pop_refill
  in
  let osr_next =
    mux2
      osr_refill_val
      (i.I.tx_head)
      (mux2
         out_run
         osr_shifted
         (mux2 pull_nb_empty x (mux2 mov_osr mov_data osr)))
    -- "osr_next"
  in
  let osr_cnt_next =
    mux2
      out_run
      (mux2 out_refill_after (c6 0) osr_cnt_after)
      (mux2
         (out_refill_stall |: pull_clr |: mov_osr |: tx_pop_refill)
         (c6 0)
         osr_cnt)
    -- "osr_cnt_next"
  in
  let x_next =
    mux2
      x_dec
      (x -: one 32)
      (mux2
         mov_x
         mov_data
         (mux2 out_x out_data (mux2 set_x set_d32 x)))
    -- "x_next"
  in
  let y_next =
    mux2
      y_dec
      (y -: one 32)
      (mux2
         mov_y
         mov_data
         (mux2 out_y out_data (mux2 set_y set_d32 y)))
    -- "y_next"
  in
  (* ---- Instruction latch (F1, F2, H7, H3) ---- *)
  let exec_set = (out_exec |: mov_exec) -- "exec_set" in
  let exec_lo16 = mux2 mov_exec (select mov_data 15 0) (select out_data 15 0) -- "exec_lo16" in
  let latch_valid_next =
    mux2
      i.instr_write
      vdd
      (mux2
         i.restart
         gnd
         (mux2 exec_set vdd (mux2 latch_done gnd latch_valid)))
    -- "latch_valid_next"
  in
  let latch_forced_next =
    mux2 i.instr_write vdd (mux2 exec_set gnd latch_forced) -- "latch_forced_next"
  in
  let latch_instr_next =
    mux2 i.instr_write i.instr_data (mux2 exec_set exec_lo16 latch_instr)
    -- "latch_instr_next"
  in
  (* Flags of the latched instruction are cleared by a new INSTR write, by restart and on
     completion. *)
  let clr_latch_scope = (i.restart |: i.instr_write |: exec_set) -- "clr_latch_scope" in
  let latch_ss_next =
    mux2 clr_latch_scope gnd (mux2 attempt_latch stall latch_ss) -- "latch_ss_next"
  in
  let latch_irqw_next =
    mux2 clr_latch_scope gnd (mux2 attempt_latch irqw_next latch_irqw) -- "latch_irqw_next"
  in
  (* IMEM flags are cleared on restart, on a PC write by a latched instruction (the
     instruction they belong to is abandoned), and on completion. *)
  let imem_ss_next =
    mux2 i.restart gnd (mux2 pc_write_latch gnd (mux2 attempt_imem stall imem_ss))
    -- "imem_ss_next"
  in
  let imem_irqw_next =
    mux2
      i.restart
      gnd
      (mux2 pc_write_latch gnd (mux2 attempt_imem irqw_next imem_irqw))
    -- "imem_irqw_next"
  in
  let stall_reason_now = mux2 stall stall_code (zero 4) -- "stall_reason_now" in
  (* F6: a latched instruction that writes the PC abandons the IMEM instruction, and its
     stall reason goes with it. *)
  let imem_stall_next =
    mux2
      i.restart
      (zero 4)
      (mux2 pc_write_latch (zero 4) (mux2 attempt_imem stall_reason_now imem_stall))
    -- "imem_stall_next"
  in
  let latch_stall_next =
    mux2
      clr_latch_scope
      (zero 4)
      (mux2 attempt_latch stall_reason_now latch_stall)
    -- "latch_stall_next"
  in
  let exec_stalled_next =
    mux2
      i.restart
      gnd
      (mux2 i.instr_write gnd (mux2 forced_act stall exec_stalled))
    -- "exec_stalled_next"
  in
  (* ---- Registers ---- *)
  let reg_pc = reg (mkr ~width:5 ~reset_to:(zero 5)) pc_next -- "pc_q" in
  pc <== reg_pc;
  let reg_x = reg (mkr ~width:32 ~reset_to:zero32) x_next -- "x_q" in
  x <== reg_x;
  let reg_y = reg (mkr ~width:32 ~reset_to:zero32) y_next -- "y_q" in
  y <== reg_y;
  let isr_reset = mux2 i.restart (zero 32) isr_next in
  let reg_isr = reg (mkr ~width:32 ~reset_to:zero32) isr_reset -- "isr_q" in
  isr <== reg_isr;
  let isr_cnt_reset = mux2 i.restart (c6 0) isr_cnt_next in
  let reg_isr_cnt = reg (mkr ~width:6 ~reset_to:(c6 0)) isr_cnt_reset -- "isr_cnt_q" in
  isr_cnt <== reg_isr_cnt;
  let reg_osr = reg (mkr ~width:32 ~reset_to:zero32) osr_next -- "osr_q" in
  osr <== reg_osr;
  let osr_cnt_reset = mux2 i.restart (c6 32) osr_cnt_next in
  let reg_osr_cnt = reg (mkr ~width:6 ~reset_to:(c6 32)) osr_cnt_reset -- "osr_cnt_q" in
  osr_cnt <== reg_osr_cnt;
  let delay_reset = mux2 i.restart (zero 5) delay_next in
  let reg_delay = reg (mkr ~width:5 ~reset_to:(zero 5)) delay_reset -- "delay_q" in
  delay <== reg_delay;
  let reg_latch_valid =
    reg (mkr ~width:1 ~reset_to:gnd) latch_valid_next -- "latch_valid_q"
  in
  latch_valid <== reg_latch_valid;
  let reg_latch_forced =
    reg (mkr ~width:1 ~reset_to:gnd) latch_forced_next -- "latch_forced_q"
  in
  latch_forced <== reg_latch_forced;
  let reg_latch_instr =
    reg (mkr ~width:16 ~reset_to:(zero 16)) latch_instr_next -- "latch_instr_q"
  in
  latch_instr <== reg_latch_instr;
  let reg_imem_stall =
    reg (mkr ~width:4 ~reset_to:(zero 4)) imem_stall_next -- "imem_stall_q"
  in
  imem_stall <== reg_imem_stall;
  let reg_latch_stall =
    reg (mkr ~width:4 ~reset_to:(zero 4)) latch_stall_next -- "latch_stall_q"
  in
  latch_stall <== reg_latch_stall;
  let reg_imem_ss = reg (mkr ~width:1 ~reset_to:gnd) imem_ss_next -- "imem_ss_q" in
  imem_ss <== reg_imem_ss;
  let reg_latch_ss = reg (mkr ~width:1 ~reset_to:gnd) latch_ss_next -- "latch_ss_q" in
  latch_ss <== reg_latch_ss;
  let reg_imem_irqw =
    reg (mkr ~width:1 ~reset_to:gnd) imem_irqw_next -- "imem_irqw_q"
  in
  imem_irqw <== reg_imem_irqw;
  let reg_latch_irqw =
    reg (mkr ~width:1 ~reset_to:gnd) latch_irqw_next -- "latch_irqw_q"
  in
  latch_irqw <== reg_latch_irqw;
  let reg_exec_stalled =
    reg (mkr ~width:1 ~reset_to:gnd) exec_stalled_next -- "exec_stalled_q"
  in
  exec_stalled <== reg_exec_stalled;
  (* The OUT_STICKY record: a new write replaces all of it, and restart clears it (H3).
     It is recorded whether or not the SM is enabled (a forced write counts). *)
  let new_mask = mux2 dir_write_now dir_new_mask lvl_new_mask in
  let new_val = mux2 dir_write_now dir_new_val lvl_new_val in
  let sticky_mask_next =
    mux2 i.restart zero32 (mux2 write_any new_mask sticky_mask)
  in
  let sticky_val_next =
    mux2 i.restart zero32 (mux2 write_any new_val sticky_val)
  in
  let sticky_isdir_next = mux2 i.restart gnd (mux2 write_any dir_write_now sticky_isdir) in
  let reg_sticky_mask =
    reg (mkr ~width:32 ~reset_to:zero32) sticky_mask_next -- "sticky_mask_q"
  in
  sticky_mask <== reg_sticky_mask;
  let reg_sticky_val =
    reg (mkr ~width:32 ~reset_to:zero32) sticky_val_next -- "sticky_val_q"
  in
  sticky_val <== reg_sticky_val;
  let reg_sticky_isdir =
    reg (mkr ~width:1 ~reset_to:gnd) sticky_isdir_next -- "sticky_isdir_q"
  in
  sticky_isdir <== reg_sticky_isdir;
  (* ---- Outputs ---- *)
  let irq_set_out = onehot8 flag_idx irq_set_now -- "irq_set_out" in
  let irq_clr_out = onehot8 flag_idx (irq_clr_now |: wait_irq_clr) -- "irq_clr_out" in
  let stall_reason =
    mux2 (latch_stall <>: zero 4) latch_stall imem_stall -- "stall_reason"
  in
  let dbg_cnt =
    concat_msb
      [ zero 4
      ; stall_reason
      ; zero 3
      ; delay
      ; zero 2
      ; osr_cnt
      ; zero 2
      ; isr_cnt
      ]
    -- "dbg_cnt"
  in
  { O.pc = reg_pc
  ; lvl_mask = lvl_mask_out
  ; lvl_val = lvl_val_out
  ; dir_mask = dir_mask_out
  ; dir_val = dir_val_out
  ; irq_set = irq_set_out
  ; irq_clr = irq_clr_out
  ; tx_pop
  ; rx_push = (push_fire |: in_push) -- "rx_push"
  ; rx_push_data = mux2 in_push isr_new_in isr -- "rx_push_data"
  ; txstall = (pull_stall |: out_empty_stall) -- "txstall"
  ; rxstall = (push_stall |: push_drop |: in_stall) -- "rxstall"
  ; illegal = (attempt &: ~:ok) -- "illegal"
  ; x = reg_x
  ; y = reg_y
  ; isr = reg_isr
  ; osr = reg_osr
  ; dbg_cnt
  ; exec_stalled = reg_exec_stalled
  ; phase = clk_out.phase
  }
;;

module Hier = Hierarchy.In_scope (I) (O)

let hierarchical scope i = Hier.hierarchical ~scope ~name:"sm" create i
