(* The block 2 PIO block: IMEM, IRQ flags, pin registers, input synchronisers, and
   num_sms engines with their FIFOs (docs/engine.md sections 3, 5 and 6, rules R1, R2,
   H5, H8, H9). Ports exist for 4 engines whatever num_sms is. Engine i >= num_sms has
   no logic, and its outputs are 0. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sm_enable : 'a [@bits 4]
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
    ; sync_bypass : 'a [@bits 32]
    ; pins_in : 'a [@bits 32]
    ; sm_restart : 'a [@bits 4]
    ; clkdiv_restart : 'a [@bits 4]
    ; fifo_flush : 'a [@bits 4]
    ; irq_clear : 'a [@bits 8]
    ; irq_force : 'a [@bits 8]
    ; fdebug_clear : 'a [@bits 32]
    ; txf_push : 'a
    ; txf_sm : 'a [@bits 2]
    ; txf_data : 'a [@bits 32]
    ; rxf_pop : 'a
    ; rxf_sm : 'a [@bits 2]
    ; instr_write : 'a
    ; instr_sm : 'a [@bits 2]
    ; instr_data : 'a [@bits 16]
    ; imem_write : 'a
    ; imem_addr : 'a [@bits 5]
    ; imem_data : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { pins_out : 'a [@bits 32]
    ; pins_oe : 'a [@bits 32]
    ; irq : 'a [@bits 8]
    ; rxf_data : 'a [@bits 32]
    ; fstat : 'a [@bits 32]
    ; flevel : 'a [@bits 32]
    ; fdebug : 'a [@bits 32]
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
    }
  [@@deriving hardcaml]
end

let bitof x n = select x n n

(* Engine i of the block, as far as the block needs it. *)
type engine =
  { sm : Signal.t Sm.O.t
  ; fifo : Signal.t Fifo_join.O.t
  }

let create ~num_sms (scope : Scope.t) (i : _ I.t) =
  if num_sms < 1 || num_sms > 4
  then invalid_arg (Printf.sprintf "pio_block: num_sms must be 1 to 4, got %d" num_sms);
  let n = num_sms in
  let mkr w = Reg_spec.override (Reg_spec.create () ~clock:i.clock) ~reset:i.rst_n ~reset_edge:Edge.Falling ~reset_to:(zero w) in
  let clkdivs = [| i.clkdiv0; i.clkdiv1; i.clkdiv2; i.clkdiv3 |] in
  let execctrls = [| i.execctrl0; i.execctrl1; i.execctrl2; i.execctrl3 |] in
  let shiftctrls = [| i.shiftctrl0; i.shiftctrl1; i.shiftctrl2; i.shiftctrl3 |] in
  let pinctrls = [| i.pinctrl0; i.pinctrl1; i.pinctrl2; i.pinctrl3 |] in
  (* Input registers (engine.md R1): every pin passes through r1, and synchronised pins
     through r2 and r3. The engines see r1 for bypassed pins and r3 otherwise. *)
  let in_r1 = reg (mkr 32) i.pins_in -- "in_r1" in
  let in_r2 = reg (mkr 32) in_r1 -- "in_r2" in
  let in_r3 = reg (mkr 32) in_r2 -- "in_r3" in
  let in_sel =
    concat_msb
      (List.rev
         (List.init 32 (fun p ->
            mux2 (bitof i.sync_bypass p) (bitof in_r1 p) (bitof in_r3 p))))
    -- "in_sel"
  in
  (* Instruction memory: one write port, read through each engine's PC. *)
  let imem_words =
    List.init 32 (fun k ->
      reg
        (Reg_spec.create () ~clock:i.clock)
        ~enable:(i.imem_write &: (i.imem_addr ==: of_int ~width:5 k))
        i.imem_data
      -- Printf.sprintf "imem_%d" k)
  in
  let irq_w = wire 8 in
  let engines = Array.make 4 None in
  for k = 0 to n - 1 do
    let imem_word_w = wire 16 in
    let tx_head_w = wire 32 in
    let tx_empty_w = wire 1 in
    let tx_level_w = wire 4 in
    let rx_full_w = wire 1 in
    let rx_level_w = wire 4 in
    let sh = shiftctrls.(k) in
    let sm =
      Sm.hierarchical
        scope
        { Sm.I.clk = i.clock
        ; rst_n = i.rst_n
        ; sm_num = of_int ~width:2 k
        ; enable = bitof i.sm_enable k
        ; restart = bitof i.sm_restart k
        ; clkdiv_restart = bitof i.clkdiv_restart k
        ; clkdiv_int = select clkdivs.(k) 31 16
        ; clkdiv_frac = select clkdivs.(k) 15 8
        ; execctrl = execctrls.(k)
        ; shiftctrl = sh
        ; pinctrl = pinctrls.(k)
        ; instr_write = i.instr_write &: (i.instr_sm ==: of_int ~width:2 k)
        ; instr_data = i.instr_data
        ; imem_word = imem_word_w
        ; in_sel
        ; tx_head = tx_head_w
        ; tx_empty = tx_empty_w
        ; tx_level = tx_level_w
        ; rx_full = rx_full_w
        ; rx_level = rx_level_w
        ; irq_q = irq_w
        }
    in
    let fifo =
      Fifo_join.hierarchical
        scope
        { Fifo_join.I.clk = i.clock
        ; rst_n = i.rst_n
        ; join_tx = bitof sh 30
        ; join_rx = bitof sh 31
        ; flush = bitof i.fifo_flush k
        ; host_tx_push = i.txf_push &: (i.txf_sm ==: of_int ~width:2 k)
        ; host_tx_data = i.txf_data
        ; sm_tx_pop = sm.tx_pop
        ; sm_rx_push = sm.rx_push
        ; sm_rx_data = sm.rx_push_data
        ; host_rx_pop = i.rxf_pop &: (i.rxf_sm ==: of_int ~width:2 k)
        }
    in
    tx_head_w <== fifo.tx_head;
    tx_empty_w <== fifo.tx_empty;
    tx_level_w <== fifo.tx_level;
    rx_full_w <== fifo.rx_full;
    rx_level_w <== fifo.rx_level;
    imem_word_w <== mux sm.pc imem_words;
    engines.(k) <- Some { sm; fifo }
  done;
  let eng k = Option.get engines.(k) in
  (* Pin registers (engine.md R2): per pin, the highest-numbered engine that writes wins,
     separately for level and direction. A pin nobody writes keeps its value. *)
  let pins_out_w = wire 32 in
  let pins_oe_w = wire 32 in
  let lvl_next = ref pins_out_w in
  let dir_next = ref pins_oe_w in
  for k = 0 to n - 1 do
    let s = (eng k).sm in
    lvl_next := (s.Sm.O.lvl_mask &: s.lvl_val) |: (~:(s.lvl_mask) &: !lvl_next);
    dir_next := (s.dir_mask &: s.dir_val) |: (~:(s.dir_mask) &: !dir_next)
  done;
  let pins_out_q = reg (mkr 32) !lvl_next -- "pins_out_q" in
  pins_out_w <== pins_out_q;
  let pins_oe_q = reg (mkr 32) !dir_next -- "pins_oe_q" in
  pins_oe_w <== pins_oe_q;
  (* IRQ flags (engine.md H5): a set always beats a clear in the same cycle. *)
  let or_all f = List.fold_left (fun acc k -> acc |: f (eng k)) (zero 8) (List.init n Fun.id) in
  let sm_sets = or_all (fun e -> e.sm.Sm.O.irq_set) in
  let sm_clrs = or_all (fun e -> e.sm.irq_clr) in
  let irq_next = (irq_w &: ~:(sm_clrs |: i.irq_clear)) |: sm_sets |: i.irq_force in
  let irq_q = reg (mkr 8) irq_next -- "irq_q" in
  irq_w <== irq_q;
  (* FDEBUG (engine.md H8): sticky flags, a set wins over a clear. *)
  let fdebug_w = wire 32 in
  let set_arr = Array.make 32 gnd in
  for k = 0 to n - 1 do
    let e = eng k in
    set_arr.(28 + k) <- e.sm.illegal;
    set_arr.(24 + k) <- e.sm.txstall;
    set_arr.(16 + k) <- e.fifo.tx_dropped;
    set_arr.(8 + k) <- e.fifo.rx_underflow;
    set_arr.(k) <- e.sm.rxstall
  done;
  let set_vec = concat_msb (List.rev (Array.to_list set_arr)) in
  let fdebug_next = (fdebug_w &: ~:(i.fdebug_clear)) |: set_vec in
  let fdebug_q = reg (mkr 32) fdebug_next -- "fdebug_q" in
  fdebug_w <== fdebug_q;
  (* FSTAT and FLEVEL, RP2040 layout (datasheet 3.7). *)
  let fstat_arr = Array.make 32 gnd in
  let flevel_arr = Array.make 32 gnd in
  for k = 0 to n - 1 do
    let f = (eng k).fifo in
    fstat_arr.(24 + k) <- f.tx_empty;
    fstat_arr.(16 + k) <- f.tx_full;
    fstat_arr.(8 + k) <- f.rx_empty;
    fstat_arr.(k) <- f.rx_full;
    for b = 0 to 3 do
      flevel_arr.((8 * k) + b) <- bitof f.tx_level b;
      flevel_arr.((8 * k) + 4 + b) <- bitof f.rx_level b
    done
  done;
  let fstat = concat_msb (List.rev (Array.to_list fstat_arr)) in
  let flevel = concat_msb (List.rev (Array.to_list flevel_arr)) in
  let rxf_data =
    mux
      i.rxf_sm
      (List.init 4 (fun k ->
         if k < n
         then (
           let f = (eng k).fifo in
           mux2 f.rx_empty (zero 32) f.rx_head)
         else zero 32))
    -- "rxf_data"
  in
  let pick k w f = if k < n then f (eng k).sm else zero w in
  { O.pins_out = pins_out_q
  ; pins_oe = pins_oe_q
  ; irq = irq_q
  ; rxf_data
  ; fstat
  ; flevel
  ; fdebug = fdebug_q
  ; dbg_pc0 = pick 0 5 (fun s -> s.Sm.O.pc)
  ; dbg_pc1 = pick 1 5 (fun s -> s.pc)
  ; dbg_pc2 = pick 2 5 (fun s -> s.pc)
  ; dbg_pc3 = pick 3 5 (fun s -> s.pc)
  ; dbg_x0 = pick 0 32 (fun s -> s.x)
  ; dbg_x1 = pick 1 32 (fun s -> s.x)
  ; dbg_x2 = pick 2 32 (fun s -> s.x)
  ; dbg_x3 = pick 3 32 (fun s -> s.x)
  ; dbg_y0 = pick 0 32 (fun s -> s.y)
  ; dbg_y1 = pick 1 32 (fun s -> s.y)
  ; dbg_y2 = pick 2 32 (fun s -> s.y)
  ; dbg_y3 = pick 3 32 (fun s -> s.y)
  ; dbg_isr0 = pick 0 32 (fun s -> s.isr)
  ; dbg_isr1 = pick 1 32 (fun s -> s.isr)
  ; dbg_isr2 = pick 2 32 (fun s -> s.isr)
  ; dbg_isr3 = pick 3 32 (fun s -> s.isr)
  ; dbg_osr0 = pick 0 32 (fun s -> s.osr)
  ; dbg_osr1 = pick 1 32 (fun s -> s.osr)
  ; dbg_osr2 = pick 2 32 (fun s -> s.osr)
  ; dbg_osr3 = pick 3 32 (fun s -> s.osr)
  ; dbg_cnt0 = pick 0 32 (fun s -> s.dbg_cnt)
  ; dbg_cnt1 = pick 1 32 (fun s -> s.dbg_cnt)
  ; dbg_cnt2 = pick 2 32 (fun s -> s.dbg_cnt)
  ; dbg_cnt3 = pick 3 32 (fun s -> s.dbg_cnt)
  ; dbg_exec_stalled0 = pick 0 1 (fun s -> s.exec_stalled)
  ; dbg_exec_stalled1 = pick 1 1 (fun s -> s.exec_stalled)
  ; dbg_exec_stalled2 = pick 2 1 (fun s -> s.exec_stalled)
  ; dbg_exec_stalled3 = pick 3 1 (fun s -> s.exec_stalled)
  ; dbg_phase0 = pick 0 25 (fun s -> s.phase)
  ; dbg_phase1 = pick 1 25 (fun s -> s.phase)
  ; dbg_phase2 = pick 2 25 (fun s -> s.phase)
  ; dbg_phase3 = pick 3 25 (fun s -> s.phase)
  }
;;

module Circuit_io = Circuit.With_interface (I) (O)

(* The block, and the database of its submodules (sm, decode, fifo_join, clkdiv_dbg).
   The database is what the Verilog printer needs to emit the whole hierarchy. *)
let circuit_with_database ~num_sms =
  let scope = Scope.create () in
  let circuit = Circuit_io.create_exn ~name:"pio_block" (create ~num_sms scope) in
  circuit, Scope.circuit_database scope
;;

(* The block for simulation. Its submodules are inlined (flatten_design), because Cyclesim
   treats a hierarchical instance as combinational from every input to every output, which
   makes the engine's PC look like a loop through the IMEM read. The logic is the same
   code as [circuit_with_database]. *)
let circuit ~num_sms =
  let scope = Scope.create ~flatten_design:true () in
  Circuit_io.create_exn ~name:"pio_block" (create ~num_sms scope)
;;
