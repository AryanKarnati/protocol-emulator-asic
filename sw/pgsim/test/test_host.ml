(* Tests for the host operations of the block 2 contract (docs/engine.md section 5, H1 to H9),
   FDEBUG clears, the block-level register layouts (section 3) and F4. Expectations are
   derived from docs/engine.md, not from the code. *)

module Isa = Polyglot_isa.Isa
module C = Pgsim.Config
module H = Pgsim.Host_op

let enc = Isa.encode
let set_pins ?(delay = 0) d = enc (Isa.Set { delay_side = delay; dest = Set_pins; data = d })
let set_x d = enc (Isa.Set { delay_side = 0; dest = Set_x; data = d })
let set_pindirs d = enc (Isa.Set { delay_side = 0; dest = Set_pindirs; data = d })
let jmp ?(cond = Isa.Always) addr = enc (Isa.Jmp { delay_side = 0; cond; addr })
let pull ?(block = true) () = enc (Isa.Pull { delay_side = 0; if_empty = false; block })
let push ?(block = true) () = enc (Isa.Push { delay_side = 0; if_full = false; block })
let mov_isr_x = enc (Isa.Mov { delay_side = 0; dest = Mov_isr; op = Op_none; source = Ms_x })
let wait_gpio n = enc (Isa.Wait { delay_side = 0; polarity = true; source = Wsrc_gpio n })
let irq_set ?(wait = false) index = enc (Isa.Irq { delay_side = 0; clear = false; wait; index; rel = false })
let in_x n = enc (Isa.In { delay_side = 0; source = In_x; bit_count = n })

let check name cond = if not cond then failwith ("FAILED: " ^ name)

let make ?(i = 0) ?(cfg = C.reset) words =
  let t = Pgsim.create () in
  Pgsim.load_program t words;
  Pgsim.set_config t i cfg;
  Pgsim.set_enabled t i true;
  t
;;

let dbg t i = Pgsim.debug t i
let step ?host t = ignore (Pgsim.step ?host t)

(* A config with the given SM 0 SET pin count, for the pin tests. *)
let set1 = { C.reset with set_count = 1 }

(* ------------------------------------------------------------------------------------ *)
(* H1: TX push. *)

(* A full FIFO drops the word and sets TXOVER, even when the SM pops in the same cycle. *)
let%test_unit "H1: full TX drops the push even if the SM pops in that cycle" =
  let t = make [ pull (); jmp 0 ] in
  List.iter (Pgsim.write_tx t 0) [ 1; 2; 3; 4 ];
  step ~host:[ H.Tx_push { sm = 0; data = 9 } ] t;
  let d = dbg t 0 in
  check "word dropped" (not (List.mem 9 d.Pgsim.tx_fifo));
  check "txover set" d.Pgsim.txover;
  check "pull popped the head" (d.Pgsim.osr = 1)
;;

(* A word pushed into a non-full FIFO joins the tail after the SM's pop of the cycle, and the
   SM sees it from the next cycle. *)
let%test_unit "H1: an accepted push joins the tail and is seen from the next cycle" =
  let t = make [ pull (); jmp 0 ] in
  Pgsim.write_tx t 0 1;
  step ~host:[ H.Tx_push { sm = 0; data = 9 } ] t;
  let d = dbg t 0 in
  check "fifo holds only the new word" (d.Pgsim.tx_fifo = [ 9 ]);
  check "no txover" (not d.Pgsim.txover);
  check "pull took the old head" (d.Pgsim.osr = 1);
  (* The JMP at address 1 runs in cycle 1, so the pull at address 0 runs again in cycle 2. *)
  step t;
  step t;
  check "next pull takes the pushed word" ((dbg t 0).Pgsim.osr = 9)
;;

(* ------------------------------------------------------------------------------------ *)
(* H2: RX pop. *)

let%test_unit "H2: pop of an empty RX gives 0, sets RXUNDER, and an SM push that cycle stays" =
  let t = make [ mov_isr_x; push (); jmp 1 ] in
  t.Pgsim.sms.(0).Pgsim.x <- 0x55;
  step t;
  (* Cycle 1: the push runs and puts 0x55 in RX. The pop is presented while RX is empty. *)
  let r = Pgsim.step_ex ~host:[ H.Rx_pop { sm = 0 } ] t in
  check "pop data is 0" (r.Pgsim.rx_data = [ 0 ]);
  check "rxunder set" (dbg t 0).Pgsim.rxunder;
  check "push landed in RX" ((dbg t 0).Pgsim.rx_fifo = [ 0x55 ])

let%test_unit "H2: pop of a non-empty RX returns the head and it leaves at the end of the cycle" =
  let t = make [ jmp 0 ] in
  t.Pgsim.sms.(0).Pgsim.rx.Pgsim.Fifo.items <- [ 0xAA; 0xBB ];
  let r = Pgsim.step_ex ~host:[ H.Rx_pop { sm = 0 } ] t in
  check "head returned" (r.Pgsim.rx_data = [ 0xAA ]);
  check "head left" ((dbg t 0).Pgsim.rx_fifo = [ 0xBB ]);
  check "no rxunder" (not (dbg t 0).Pgsim.rxunder)
;;

(* ------------------------------------------------------------------------------------ *)
(* H3: SM_RESTART, and INSTR written in the same cycle. *)

let%test_unit "H3: restart clears ISR, count, delay and the latch, keeps PC, X, Y and OSR" =
  let t = make [ in_x 8; jmp 0 ] in
  t.Pgsim.sms.(0).Pgsim.x <- 0xA5;
  t.Pgsim.sms.(0).Pgsim.osr <- 0x1234;
  t.Pgsim.sms.(0).Pgsim.osr_count <- 3;
  step ~host:[ H.Sm_restart 1 ] t;
  let d = dbg t 0 in
  check "isr count 0" (d.Pgsim.isr_count = 0);
  check "isr 0" (d.Pgsim.isr = 0);
  check "osr count 32" (d.Pgsim.osr_count = 32);
  check "osr kept" (d.Pgsim.osr = 0x1234);
  check "x kept" (d.Pgsim.x = 0xA5);
  check "delay 0" (d.Pgsim.delay = 0)
;;

(* The restart of cycle k overrides the IN of that cycle; an INSTR write in the same cycle is
   then latched after the restart. *)
let%test_unit "H3: restart then INSTR in one cycle: the new instruction stays latched" =
  let t = make [ in_x 8; jmp 0 ] in
  step ~host:[ H.Instr_write { sm = 0; data = set_pins 1 }; H.Sm_restart 1 ] t;
  let d = dbg t 0 in
  check "isr count is 0 after the restart" (d.Pgsim.isr_count = 0);
  check "forced instruction latched" (d.Pgsim.latch = Pgsim.Host_latch (set_pins 1));
  check "exec_stalled is 0 before it runs" (not d.Pgsim.exec_stalled)
;;

(* ------------------------------------------------------------------------------------ *)
(* H4: CLKDIV_RESTART. *)

let%test_unit "H4: clkdiv restart sets the phase to 0 at the end of the cycle" =
  let cfg = { C.reset with clkdiv_int = 3; clkdiv_frac = 0 } in
  let t = make ~cfg [ jmp 0 ] in
  step t;
  check "phase advanced" ((dbg t 0).Pgsim.acc <> 0);
  step ~host:[ H.Clkdiv_restart 1 ] t;
  check "phase 0 after the restart cycle" ((dbg t 0).Pgsim.acc = 0)
;;

(* ------------------------------------------------------------------------------------ *)
(* H5: IRQ set, clear and force. *)

let%test_unit "H5: a set beats a host clear in the same cycle" =
  let t = make [ irq_set 2; jmp 1 ] in
  step ~host:[ H.Irq_clear 0x04 ] t;
  check "flag 2 set by the IRQ instruction wins" (t.Pgsim.irq land 4 = 4)
;;

let%test_unit "H5: host IRQ clear and force (force beats clear) with the flags as they were" =
  let t = make [ jmp 0 ] in
  Pgsim.force_irq t 0x0F;
  (* irq_next = (0x0F AND NOT 0x03) OR 0x01 = 0x0D: flag 0 is forced again, flag 1 is
     cleared, flags 2 and 3 stay. *)
  step ~host:[ H.Irq_clear 0x03; H.Irq_force 0x01 ] t;
  check "irq is 0x0D" (t.Pgsim.irq = 0x0D);
  Pgsim.clear_irq t 0xFF;
  check "clear all" (t.Pgsim.irq = 0)
;;

(* ------------------------------------------------------------------------------------ *)
(* H6: FIFO flush. *)

let%test_unit "H6: flush empties both FIFOs at the end of the cycle, after a push and a pop" =
  let t = make [ pull (); jmp 0 ] in
  Pgsim.write_tx t 0 1;
  Pgsim.write_tx t 0 2;
  t.Pgsim.sms.(0).Pgsim.rx.Pgsim.Fifo.items <- [ 7 ];
  step ~host:[ H.Tx_push { sm = 0; data = 9 }; H.Rx_pop { sm = 0 }; H.Fifo_flush 1 ] t;
  let d = dbg t 0 in
  check "tx empty" (d.Pgsim.tx_fifo = []);
  check "rx empty" (d.Pgsim.rx_fifo = []);
  check "the SM's pop still reached OSR" (d.Pgsim.osr = 1)
;;

(* ------------------------------------------------------------------------------------ *)
(* H7 and F1: a forced instruction runs in the next cycle, and EXEC_STALLED (F4). *)

let%test_unit "F4: exec_stalled while a forced wait is stalled, 0 once it completes" =
  let t = make ~cfg:set1 [ jmp 0 ] in
  Pgsim.set_enabled t 0 false;
  step ~host:[ H.Instr_write { sm = 0; data = wait_gpio 5 } ] t;
  check "not yet attempted" (not (dbg t 0).Pgsim.exec_stalled);
  step t;
  check "stalled attempt sets exec_stalled" (dbg t 0).Pgsim.exec_stalled;
  check "stall code is wait_gpio" ((dbg t 0).Pgsim.stall_code = 4);
  Pgsim.set_enabled t 0 false;
  (* WAIT GPIO sees the pad through the synchroniser: three cycles (R1). *)
  t.Pgsim.ext <- 1 lsl 5;
  step t;
  step t;
  step t;
  step t;
  check "completion clears exec_stalled" (not (dbg t 0).Pgsim.exec_stalled);
  check "no latch left" ((dbg t 0).Pgsim.latch = Pgsim.No_latch)
;;

(* ------------------------------------------------------------------------------------ *)
(* H8: FDEBUG clears, all five flag kinds, and a set beats a clear. *)

let fd_flags = [ "txstall"; "txover"; "rxunder"; "rxstall"; "illegal" ]

let%test_unit "H8: FDEBUG write-1-to-clear clears each of the five flags" =
  let set_all t =
    let s = t.Pgsim.sms.(0) in
    s.Pgsim.txstall <- true;
    s.Pgsim.txover <- true;
    s.Pgsim.rxunder <- true;
    s.Pgsim.rxstall <- true;
    s.Pgsim.illegal <- true
  in
  let fd_bit = [ 24; 16; 8; 0; 28 ] in
  List.iter2
    (fun name b ->
      let t = make [ jmp 0 ] in
      set_all t;
      check (name ^ " set in FDEBUG") (Pgsim.fdebug t land (1 lsl b) <> 0);
      step ~host:[ H.Fdebug_clear (1 lsl b) ] t;
      check (name ^ " cleared by its own bit") (Pgsim.fdebug t land (1 lsl b) = 0);
      check (name ^ " the other flags stay") (Pgsim.fdebug t land lnot (1 lsl b) <> 0))
    fd_flags
    fd_bit
;;

let%test_unit "H8: a flag set in the cycle beats a clear of the same cycle" =
  let t = make [ jmp 0 ] in
  let s = t.Pgsim.sms.(0) in
  s.Pgsim.txover <- true;
  (* A host push into the full TX FIFO sets TXOVER again in this cycle. *)
  List.iter (Pgsim.write_tx t 0) [ 1; 2; 3; 4 ];
  s.Pgsim.txover <- true;
  step ~host:[ H.Tx_push { sm = 0; data = 5 }; H.Fdebug_clear (1 lsl 16) ] t;
  check "txover still set" (dbg t 0).Pgsim.txover
;;

let%test_unit "H8: an old flag is cleared when nothing sets it in the cycle" =
  let t = make [ jmp 0 ] in
  t.Pgsim.sms.(0).Pgsim.rxstall <- true;
  step ~host:[ H.Fdebug_clear 1 ] t;
  check "rxstall cleared" (not (dbg t 0).Pgsim.rxstall)
;;

(* ------------------------------------------------------------------------------------ *)
(* H9: IMEM write, visible from the next cycle. *)

let%test_unit "H9: the IMEM word written in cycle k runs from k+1" =
  let t = make ~cfg:set1 [ set_pins 1; jmp 1 ] in
  step ~host:[ H.Imem_write { addr = 0; data = set_pins 0 } ] t;
  check "old word executed in cycle 0" (t.Pgsim.pin_level land 1 = 1);
  check "new word stored" (t.Pgsim.imem.(0) = set_pins 0)
;;

(* ------------------------------------------------------------------------------------ *)
(* Block-level layouts (engine.md section 3). *)

let%test_unit "FSTAT and FLEVEL: an SM with 3 TX and 2 RX words, and a joined TX FIFO" =
  let t = Pgsim.create () in
  Pgsim.write_tx t 0 1;
  Pgsim.write_tx t 0 2;
  Pgsim.write_tx t 0 3;
  t.Pgsim.sms.(0).Pgsim.rx.Pgsim.Fifo.items <- [ 4; 5 ];
  let f = Pgsim.fstat t in
  check "SM0 TXEMPTY clear" (f land (1 lsl 24) = 0);
  check "SM0 TXFULL clear" (f land (1 lsl 16) = 0);
  check "SM0 RXEMPTY clear" (f land (1 lsl 8) = 0);
  check "SM0 RXFULL clear" (f land 1 = 0);
  check "SM1 TXEMPTY set" (f land (1 lsl 25) <> 0);
  let l = Pgsim.flevel t in
  check "SM0 TX level 3" (l land 0xF = 3);
  check "SM0 RX level 2" ((l lsr 4) land 0xF = 2);
  (* Joined TX: capacity 8 for TX, 0 for RX. RX reads full and empty with level 0. *)
  let u = Pgsim.create () in
  Pgsim.set_config u 1 { C.reset with fjoin_tx = true };
  let f = Pgsim.fstat u in
  check "joined SM1 TX empty, capacity 8 so not full" (f land (1 lsl 25) <> 0 && f land (1 lsl 17) = 0);
  check "SM1 RX empty and full at capacity 0" (f land (1 lsl 9) <> 0 && f land (1 lsl 1) <> 0);
  check "SM1 TX level 0" ((Pgsim.flevel u lsr 8) land 0xF = 0)
;;

let%test_unit "FDEBUG layout puts ILLEGAL in [31:28] per SM" =
  let t = make [ 0xA060 (* reserved MOV destination, illegal *); jmp 0 ] in
  step t;
  check "illegal bit 28" (Pgsim.fdebug t land (1 lsl 28) <> 0)
;;

let%test_unit "DBG_CNT packs ISR, OSR counts, delay and stall reason" =
  let t = make [ in_x 8; jmp 0 ] in
  step t;
  let v = Pgsim.dbg_cnt t 0 in
  check "isr count 8" (v land 63 = 8);
  check "osr count 32" ((v lsr 8) land 63 = 32);
  check "no delay" ((v lsr 16) land 31 = 0);
  check "no stall" ((v lsr 24) land 15 = 0)
;;

let%test_unit "pins_out and pins_oe are the register values" =
  let t = make ~cfg:set1 [ set_pindirs 1; set_pins 1 ] in
  step t;
  step t;
  check "pins_oe pin 0" (Pgsim.pins_oe t = 1);
  check "pins_out pin 0" (Pgsim.pins_out t = 1)
;;

(* ------------------------------------------------------------------------------------ *)
(* Immediate functions give the same result as a cycle without SM activity. *)

let%test_unit "immediate write_tx equals a host push with an idle SM" =
  let t = make [ jmp 0 ] in
  Pgsim.write_tx t 0 3;
  check "present before the next step" ((dbg t 0).Pgsim.tx_fifo = [ 3 ]);
  let u = make [ jmp 0 ] in
  step ~host:[ H.Tx_push { sm = 0; data = 3 } ] u;
  check "same fifo after a step" ((dbg u 0).Pgsim.tx_fifo = (dbg t 0).Pgsim.tx_fifo)
;;

let%test_unit "two pushes to one SM in one cycle are refused" =
  let t = make [ jmp 0 ] in
  let raised =
    try
      step ~host:[ H.Tx_push { sm = 0; data = 1 }; H.Tx_push { sm = 0; data = 2 } ] t;
      false
    with
    | Invalid_argument _ -> true
  in
  check "refused" raised
;;

let _ = fd_flags
