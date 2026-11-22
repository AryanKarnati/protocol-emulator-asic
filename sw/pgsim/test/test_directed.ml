(* Directed scenarios for pgsim against docs/engine.md (block 2 contract), written from the
   contract and the datasheet only, by the checker of round 1. Each failing check prints FAIL
   with its scenario. Runs as part of dune test. *)
module Isa = Polyglot_isa.Isa
module C = Pgsim.Config
module H = Pgsim.Host_op

let enc = Isa.encode
let fails = ref 0
let total = ref 0
let scen = ref ""
let messages = ref []
let note m = messages := m :: !messages
let chk what cond =
  incr total;
  if not cond then (incr fails; note (Printf.sprintf "[%s] %s" !scen what))
let chki what got exp =
  incr total;
  if got <> exp then (incr fails; note (Printf.sprintf "[%s] %s: got %d (0x%x) expected %d (0x%x)" !scen what got got exp exp))
let sc name = scen := name

let set_pins ?(ds = 0) d = enc (Isa.Set { delay_side = ds; dest = Set_pins; data = d })
let set_x ?(ds = 0) d = enc (Isa.Set { delay_side = ds; dest = Set_x; data = d })
let set_y ?(ds = 0) d = enc (Isa.Set { delay_side = ds; dest = Set_y; data = d })
let set_pd ?(ds = 0) d = enc (Isa.Set { delay_side = ds; dest = Set_pindirs; data = d })
let jmp ?(ds = 0) ?(cond = Isa.Always) a = enc (Isa.Jmp { delay_side = ds; cond; addr = a })
let pull ?(ds = 0) ?(ie = false) ?(block = true) () = enc (Isa.Pull { delay_side = ds; if_empty = ie; block })
let push ?(ds = 0) ?(iff = false) ?(block = true) () = enc (Isa.Push { delay_side = ds; if_full = iff; block })
let in_ ?(ds = 0) src n = enc (Isa.In { delay_side = ds; source = src; bit_count = n })
let out ?(ds = 0) dst n = enc (Isa.Out { delay_side = ds; dest = dst; bit_count = n })
let mov ?(ds = 0) ?(op = Isa.Op_none) dst src = enc (Isa.Mov { delay_side = ds; dest = dst; op; source = src })
let wait ?(ds = 0) pol src = enc (Isa.Wait { delay_side = ds; polarity = pol; source = src })
let irq ?(ds = 0) ?(clear = false) ?(wt = false) ?(rel = false) i = enc (Isa.Irq { delay_side = ds; clear; wait = wt; index = i; rel })
let nop = mov Isa.Mov_y Isa.Ms_y

let mk ?(cfgs = []) ?(en = [ 0 ]) words =
  let t = Pgsim.create () in
  Pgsim.load_program t words;
  List.iter (fun (i, c) -> Pgsim.set_config t i c) cfgs;
  List.iter (fun i -> Pgsim.set_enabled t i true) en;
  t

let st ?host t = Pgsim.step_ex ?host t
let s ?host t = ignore (st ?host t)
let d t i = Pgsim.debug t i
let cnt t i = Pgsim.dbg_cnt t i
let reason t i = (cnt t i lsr 24) land 15
let one_wrap = { C.reset with wrap_top = 0; wrap_bottom = 0 }

let () =
  (* ---------------- R0 reset ---------------- *)
  sc "R0 reset";
  let t = Pgsim.create () in
  for i = 0 to 3 do
    let x = d t i in
    chki "pc" x.pc 0; chki "x" x.x 0; chki "isr" x.isr 0; chki "osr" x.osr 0;
    chki "dbg_cnt (osr count 32)" (cnt t i) (32 lsl 8);
    chki "phase" x.acc 0; chk "exec_stalled" (not x.exec_stalled)
  done;
  chki "fstat" (Pgsim.fstat t) 0x0F000F00; chki "flevel" (Pgsim.flevel t) 0;
  chki "fdebug" (Pgsim.fdebug t) 0; chki "irq" t.irq 0;
  chki "pins_out" (Pgsim.pins_out t) 0; chki "pins_oe" (Pgsim.pins_oe t) 0;

  (* ---------------- H1 ---------------- *)
  sc "H1 push at full with SM pop";
  let t = mk [ pull (); jmp 0 ] in
  List.iter (Pgsim.write_tx t 0) [ 1; 2; 3; 4 ];
  s ~host:[ H.Tx_push { sm = 0; data = 9 } ] t;
  chki "level after" (Pgsim.Fifo.level (Pgsim.(t.sms.(0))).tx) 3;
  chk "txover" ((d t 0).txover); chki "osr" (d t 0).osr 1;
  chki "fdebug txover bit" (Pgsim.fdebug t land 0x00FF0000) 0x10000;
  sc "H1 push at 3 with SM pop: joins tail after pop";
  let t = mk [ pull (); jmp 0 ] in
  List.iter (Pgsim.write_tx t 0) [ 1; 2; 3 ];
  s ~host:[ H.Tx_push { sm = 0; data = 9 } ] t;
  chk "tx = [2;3;9]" ((d t 0).tx_fifo = [ 2; 3; 9 ]); chk "no txover" (not (d t 0).txover);
  sc "H1 push at empty with blocking pull same cycle: SM stalls";
  let t = mk [ pull (); jmp 0 ] in
  s ~host:[ H.Tx_push { sm = 0; data = 7 } ] t;
  chki "pc stays" (d t 0).pc 0; chk "txstall" (d t 0).txstall; chki "reason tx_empty" (reason t 0) 1;
  chk "word in fifo" ((d t 0).tx_fifo = [ 7 ]);
  s t; chki "osr gets it next cycle" (d t 0).osr 7; chki "reason 0" (reason t 0) 0;

  (* ---------------- H2 ---------------- *)
  sc "H2 pop at empty with SM push same cycle";
  let t = mk [ push (); jmp 0 ] in
  t.sms.(0).isr <- 0x55;
  let r = st ~host:[ H.Rx_pop { sm = 0 } ] t in
  chk "rx_data = [0]" (r.rx_data = [ 0 ]); chk "rxunder" (d t 0).rxunder;
  chk "push landed" ((d t 0).rx_fifo = [ 0x55 ]); chki "rx_head" (Pgsim.rx_head t 0) 0x55;
  sc "H2 pop at full with SM blocking push";
  let t = mk [ push (); jmp 0 ] in
  List.iter (Pgsim.Fifo.push t.sms.(0).rx) [ 1; 2; 3; 4 ];
  t.sms.(0).isr <- 0x66;
  let r = st ~host:[ H.Rx_pop { sm = 0 } ] t in
  chk "rx_data = head" (r.rx_data = [ 1 ]); chk "fifo [2;3;4]" ((d t 0).rx_fifo = [ 2; 3; 4 ]);
  chki "push stalled this cycle (pc 0)" (d t 0).pc 0; chk "rxstall" (d t 0).rxstall; chki "reason 2" (reason t 0) 2;
  s t; chk "push lands next cycle" ((d t 0).rx_fifo = [ 2; 3; 4; 0x66 ]);

  (* ---------------- H3 ---------------- *)
  sc "H3 restart + instr_write";
  let t = mk [ in_ ~ds:5 Isa.In_x 8; jmp 0 ] in
  t.sms.(0).x <- 0xAB;
  s t; chki "isr count 8" (d t 0).isr_count 8; chki "delay 5" (d t 0).delay 5;
  s ~host:[ H.Sm_restart 1; H.Instr_write { sm = 0; data = set_y 3 } ] t;
  let x = d t 0 in
  chki "isr_count 0" x.isr_count 0; chki "delay 0" x.delay 0; chki "isr 0" x.isr 0; chki "osr_count 32" x.osr_count 32;
  chk "latched set y" (x.latch = Pgsim.Host_latch (set_y 3));
  chki "x kept" x.x 0xAB; chki "pc kept (restart doesn't reset pc)" x.pc 1;
  s t; chki "forced ran" (d t 0).y 3; chk "latch gone" ((d t 0).latch = Pgsim.No_latch); chki "pc not advanced" (d t 0).pc 1;
  sc "H3 restart keeps OSR contents, pin writes still happen";
  let t = mk ~cfgs:[ 0, { C.reset with set_count = 1 } ] [ pull (); set_pins 1; jmp 2 ] in
  Pgsim.write_tx t 0 0xCAFE;
  s ~host:[ H.Sm_restart 1 ] t;
  chki "osr kept" (d t 0).osr 0xCAFE; chki "osr_count restored 32" (d t 0).osr_count 32;
  s ~host:[ H.Sm_restart 1 ] t;
  chki "pin write in restart cycle happens" (Pgsim.pins_out t land 1) 1;
  chki "pc advanced" (d t 0).pc 2;
  sc "H3 restart clears irq wait, stall reason, side_done";
  let c = { C.reset with side_en = false; sideset_count = 1; sideset_base = 0; set_count = 1; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ irq ~wt:true 0 ~ds:0x10 ] in
  s t;
  chk "irq flag set" (t.irq land 1 = 1); chki "reason 7" (reason t 0) 7; chk "irq_wait Some" ((d t 0).irq_wait <> None);
  chki "pin0 side=1 visible" (Pgsim.pins_out t land 1) 1;
  s ~host:[ H.Sm_restart 1 ] t;
  chk "irq_wait None" ((d t 0).irq_wait = None); chki "reason 0" (reason t 0) 0; chk "side_done false" (not (d t 0).side_done);
  (* IRQ flag still 1 so after restart the IRQ instr re-attempts: sets again, stalls *)
  s t; chki "re-attempt stalls again reason 7" (reason t 0) 7;

  (* ---------------- H4 ---------------- *)
  sc "H4 clkdiv_restart";
  let c = { C.reset with clkdiv_int = 3; clkdiv_frac = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ nop ] in
  s t; chki "P=256" (d t 0).acc 256; s t; chki "P=512" (d t 0).acc 512;
  s ~host:[ H.Clkdiv_restart 1 ] t; chki "tick cycle still happened but P=0" (d t 0).acc 0; chki "pc advanced (tick ran)" (d t 0).pc 1;
  s t; chki "P=256 next" (d t 0).acc 256;
  sc "H4 restart while SM disabled/tick not due";
  let t = mk ~cfgs:[ 0, c ] ~en:[] [ nop ] in
  s t; s ~host:[ H.Clkdiv_restart 1 ] t; chki "P=0" (d t 0).acc 0;

  (* ---------------- H5 ---------------- *)
  sc "H5 set beats clear";
  let t = mk [ irq 0; jmp 1 ] in
  t.irq <- 1;
  s ~host:[ H.Irq_clear 1 ] t; chki "irq stays 1 (SM set beats host clear)" t.irq 1;
  let t = mk [ jmp 0 ] in
  t.irq <- 1; s ~host:[ H.Irq_clear 1; H.Irq_force 1 ] t; chki "force beats clear" t.irq 1;
  sc "H5 wait 1 irq clear vs force same cycle";
  let t = mk [ wait true (Isa.Wsrc_irq { index = 0; rel = false }); jmp 1 ] in
  t.irq <- 1; s ~host:[ H.Irq_force 1 ] t; chki "force wins over wait clear" t.irq 1; chki "wait done" (d t 0).pc 1;
  sc "H5 wait 1 irq clear vs SM1 irq set";
  let t = mk ~en:[ 0; 1 ] [ wait true (Isa.Wsrc_irq { index = 0; rel = false }); jmp 1 ] in
  t.irq <- 1;
  (* both SMs run the same program; sm1 rel? use sm1 with different pc *)
  t.sms.(1).pc <- 2; Pgsim.load_program t [ wait true (Isa.Wsrc_irq { index = 0; rel = false }); jmp 1; irq 0; jmp 3 ];
  s t; chki "set (sm1) beats clear (sm0 wait)" t.irq 1; chki "sm0 done" (d t 0).pc 1;
  sc "H5 IRQ clear instr vs set instr";
  let t = mk ~en:[ 0; 1 ] [ irq ~clear:true 0; jmp 1; irq 0; jmp 3 ] in
  t.sms.(1).pc <- 2; t.irq <- 1; s t; chki "irq 1" t.irq 1;
  sc "R14 rel index";
  let t = mk ~en:[ 2 ] [ irq ~rel:true 1; jmp 1 ] in
  s t; chki "sm2 rel 1 -> flag 3" t.irq 0x8;
  let t = mk ~en:[ 3 ] [ irq ~rel:true 6; jmp 1 ] in
  s t; chki "sm3 rel 6 -> (6&4)|((6+3)&3)=5" t.irq 0x20;

  (* ---------------- H6 ---------------- *)
  sc "H6 flush";
  let t = mk [ pull (); push (); jmp 0 ] in
  List.iter (Pgsim.write_tx t 0) [ 1; 2 ];
  Pgsim.Fifo.push t.sms.(0).rx 5;
  s ~host:[ H.Fifo_flush 1; H.Tx_push { sm = 0; data = 3 } ] t;
  chk "tx empty" ((d t 0).tx_fifo = []); chk "rx empty" ((d t 0).rx_fifo = []); chki "osr got popped word" (d t 0).osr 1;
  chki "flevel 0" (Pgsim.flevel t) 0;

  (* ---------------- H7 ---------------- *)
  sc "H7 instr_write replaces stalled forced instr, retry still runs";
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = pull () } ] t;
  s t; chk "forced stalled, exec_stalled" (d t 0).exec_stalled; chki "reason 1" (reason t 0) 1; chk "txstall" (d t 0).txstall;
  s ~host:[ H.Instr_write { sm = 0; data = set_x 7 }; H.Tx_push { sm = 0; data = 0xAA } ] t;
  chk "retry ran, still stalled in cycle (tx empty at start)" ((d t 0).latch = Pgsim.Host_latch (set_x 7));
  chk "exec_stalled cleared by new write" (not (d t 0).exec_stalled); chki "reason 0 after new write" (reason t 0) 0;
  s t; chki "x=7" (d t 0).x 7; chk "tx kept word" ((d t 0).tx_fifo = [ 0xAA ]); chki "osr untouched" (d t 0).osr 0;

  (* ---------------- H8 ---------------- *)
  sc "H8 fdebug";
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Rx_pop { sm = 0 } ] t; chki "rxunder" (Pgsim.fdebug t) 0x100;
  s ~host:[ H.Fdebug_clear 0x100; H.Rx_pop { sm = 0 } ] t; chki "set beats clear" (Pgsim.fdebug t) 0x100;
  s ~host:[ H.Fdebug_clear 0x100 ] t; chki "cleared" (Pgsim.fdebug t) 0;
  s ~host:[ H.Fdebug_clear 0xFFFFFFFF ] t; chki "clear all of nothing" (Pgsim.fdebug t) 0;
  (* illegal bit 28+i *)
  let t = mk ~en:[ 2 ] [ 0x40A0 ] in
  s t; chki "ILLEGAL sm2 at bit 30" (Pgsim.fdebug t) (1 lsl 30);
  s ~host:[ H.Fdebug_clear (1 lsl 30) ] t; chki "illegal set again by the retry? (it is NOP, pc moved to 1: imem[1]=0=JMP0 legal)" (Pgsim.fdebug t) 0;

  (* ---------------- H9 ---------------- *)
  sc "H9 imem write";
  let t = mk [ jmp 0 ] in
  s ~host:[ H.Imem_write { addr = 0; data = set_x 9 } ] t;
  chki "old word ran in cycle k" (d t 0).x 0; s t; chki "new word from k+1" (d t 0).x 9;

  (* ---------------- R1 ---------------- *)
  sc "R1 output k+1, input k+1/k+3";
  let c = { one_wrap with set_count = 5 } in
  let t = mk ~cfgs:[ 0, c ] [ set_pins 3 ] in
  chki "before" (Pgsim.pins_out t) 0; s t; chki "pins_out after cycle 0" (Pgsim.pins_out t) 3; chki "oe still 0" (Pgsim.pins_oe t) 0;
  let t = mk ~cfgs:[ 0, one_wrap ] [ mov Isa.Mov_x Isa.Ms_pins ] in
  t.sync_bypass <- 0xFFFFFFFF;
  for k = 0 to 5 do
    if k = 3 then t.ext <- 1; s t;
    chki (Printf.sprintf "bypass x after cycle %d" k) (d t 0).x (if k >= 4 then 1 else 0)
  done;
  let t = mk ~cfgs:[ 0, one_wrap ] [ mov Isa.Mov_x Isa.Ms_pins ] in
  t.sync_bypass <- 0;
  for k = 0 to 7 do
    if k = 3 then t.ext <- 1; s t;
    chki (Printf.sprintf "sync x after cycle %d" k) (d t 0).x (if k >= 6 then 1 else 0)
  done;
  sc "R1 pad rule";
  (* set pindirs 1 drives pin0; level 1 drives; ext 0; instruction reading sees own output after the 1 reg stage *)
  let t = mk ~cfgs:[ 0, { one_wrap with set_count = 1 } ] [ set_pd 1 ] in
  s t; chki "oe=1 after cycle 0" (Pgsim.pins_oe t) 1;
  let (lvl, oe) = Pgsim.pads t in chki "pad lvl" lvl 0; chki "pad oe" oe 1;
  t.ext <- 1; let (lvl, _) = Pgsim.pads t in chki "driven pin ignores ext (out=0)" (lvl land 1) 0;

  (* ---------------- R2 ---------------- *)
  sc "R2 side-set beats set; highest SM wins; separate level/dir";
  let c0 = { C.reset with set_count = 2; set_base = 0; sideset_count = 1; sideset_base = 0; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c0 ] [ set_pins ~ds:0x10 0 ] in   (* set pins=0 (2 pins), side=1 on pin0 *)
  s t; chki "pin0 side beats set" (Pgsim.pins_out t) 0b01;
  let c1 = { c0 with sideset_count = 0; set_count = 2 } in
  let t = mk ~cfgs:[ 0, c1; 1, c1 ] ~en:[ 0; 1 ] [ set_pins 1 ] in
  t.sms.(0).cfg <- c1;
  Pgsim.load_program t [ set_pins 1; set_pins 0; ];
  t.sms.(1).pc <- 1; t.sms.(0).cfg <- { c1 with wrap_top = 0 }; t.sms.(1).cfg <- { c1 with wrap_top = 1; wrap_bottom = 1 };
  s t; chki "sm1 (set 0) wins over sm0 (set 1) on both pins" (Pgsim.pins_out t) 0;
  let t = mk ~cfgs:[ 0, { c1 with set_count = 1 } ] [ set_pins 1; set_pd 1; nop ] in
  s t; chki "level only (dir 0)" (Pgsim.pins_out t) 1; chki "dir untouched" (Pgsim.pins_oe t) 0;
  sc "OUT_STICKY forced write while disabled recorded; not asserted while disabled";
  let cs = { C.reset with out_sticky = true; set_count = 3; wrap_top = 0; wrap_bottom = 0 } in
  let c1 = { C.reset with set_count = 3; wrap_top = 1; wrap_bottom = 1 } in
  let t = mk ~cfgs:[ 0, cs; 1, c1 ] ~en:[ 1 ] [ nop; set_pins 0 ] in
  t.sms.(1).pc <- 1;
  s ~host:[ H.Instr_write { sm = 0; data = set_pins 5 } ] t; (* cycle 0: sm1 writes 0 *)
  chki "pins 0" (Pgsim.pins_out t) 0;
  s t; chki "forced ran: pins 5, sm1 sets 0 too, sm1 higher wins -> 0" (Pgsim.pins_out t) 0;
  (* sm1 keeps writing 0 each cycle: it overrides. disable sm1; sm0 still disabled *)
  Pgsim.set_enabled t 1 false; s t; chki "after disable, pins hold 0" (Pgsim.pins_out t) 0;
  Pgsim.set_enabled t 0 true; s t; (* sm0 enabled, nop, sticky re-asserts 5 *)
  chki "sticky re-asserts forced write once enabled" (Pgsim.pins_out t) 5;
  sc "OUT_STICKY not asserted while disabled";
  let t = mk ~cfgs:[ 0, cs; 1, c1 ] ~en:[ 0 ] [ set_pins 5; set_pins 0 ] in
  t.sms.(1).pc <- 1; s t; chki "pins 5" (Pgsim.pins_out t) 5;
  Pgsim.set_enabled t 0 false;
  Pgsim.set_enabled t 1 true; s t; chki "sm1 writes 0" (Pgsim.pins_out t) 0;
  Pgsim.set_enabled t 1 false; s t; s t; chki "disabled sticky sm0 does not re-assert" (Pgsim.pins_out t) 0;

  (* ---------------- R3/R4 ---------------- *)
  sc "R3 !OSRE with thresh";
  let c = { C.reset with pull_thresh = 8; wrap_top = 3; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ jmp ~cond:Isa.Not_osre 2; set_x 1; set_x 2; jmp 3 ] in
  (* osr_count = 32 >= 8: !osre false -> not taken -> pc 1 *)
  s t; chki "count32 -> OSRE: not taken" (d t 0).pc 1;
  let t = mk ~cfgs:[ 0, c ] [ jmp ~cond:Isa.Not_osre 2; set_x 1; set_x 2; jmp 3 ] in
  t.sms.(0).osr_count <- 7; s t; chki "count 7 <8 -> taken" (d t 0).pc 2;
  let t = mk ~cfgs:[ 0, c ] [ jmp ~cond:Isa.Not_osre 2; set_x 1; set_x 2; jmp 3 ] in
  t.sms.(0).osr_count <- 8; s t; chki "count 8 -> not taken" (d t 0).pc 1;
  sc "R3 thresh reg 0 means 32 (both)";
  let c0 = C.of_registers ~clkdiv:0x10000 ~execctrl:0x1F000 ~shiftctrl:0x000C0000 ~pinctrl:0x14000000 in
  chki "pull_thresh 32" c0.pull_thresh 32; chki "push_thresh 32" c0.push_thresh 32;
  (* R4 (revised, engine.md): the PULL is a no-op only when the OSR is full (count 0). A
     partly shifted OSR (count 3 here) is not full, so the PULL loads the TX word. The
     block 1 reading (no-op below the threshold) is withdrawn; its expectations changed. *)
  sc "R4 pull with autopull on a partly shifted OSR loads a fresh word";
  let c = { C.reset with autopull = true; pull_thresh = 8; wrap_top = 1; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ pull (); nop ] in
  t.sms.(0).osr_count <- 3; t.sms.(0).osr <- 0x77; Pgsim.write_tx t 0 0x99;
  s t; chki "osr loaded from TX" (d t 0).osr 0x99; chki "count cleared" (d t 0).osr_count 0; chk "tx popped" ((d t 0).tx_fifo = []); chki "pc 1" (d t 0).pc 1;
  sc "R4 pull with autopull on a full OSR is a no-op";
  let t = mk ~cfgs:[ 0, c ] [ pull (); nop ] in
  t.sms.(0).osr_count <- 0; t.sms.(0).osr <- 0x77; Pgsim.write_tx t 0 0x99;
  s t; chki "osr kept" (d t 0).osr 0x77; chk "tx not popped" ((d t 0).tx_fifo = [ 0x99 ]); chki "pc 1" (d t 0).pc 1;

  (* ---------------- R5 ---------------- *)
  sc "R5 OUT at threshold, TX non-empty: refill + stall, then run";
  let c = { C.reset with autopull = true; pull_thresh = 8; out_right = true; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ out Isa.Out_x 8 ] in
  Pgsim.write_tx t 0 0x11223344; Pgsim.write_tx t 0 0x55667788;
  s t; chki "osr refilled" (d t 0).osr 0x11223344; chki "count 0" (d t 0).osr_count 0; chki "reason 3" (reason t 0) 3; chki "no txstall" (Pgsim.fdebug t land 0x0F000000) 0;
  chki "x untouched" (d t 0).x 0;
  s t; chki "x = low 8 bits" (d t 0).x 0x44; chki "count hit thresh -> refilled, osr = 2nd word" (d t 0).osr 0x55667788; chki "count 0" (d t 0).osr_count 0; chki "reason 0" (reason t 0) 0;
  sc "R5 OUT at threshold, TX empty: stall, TXSTALL";
  let t = mk ~cfgs:[ 0, c ] [ out Isa.Out_x 8 ] in
  s t; chk "txstall" (d t 0).txstall; chki "reason 3" (reason t 0) 3; chki "osr_count still 32" (d t 0).osr_count 32;
  sc "R5 non-OUT refill incl. delay tick";
  let t = mk ~cfgs:[ 0, c ] [ set_x ~ds:3 1; nop ] in
  s t; chki "c0 tx empty no refill" (d t 0).osr_count 32;
  s ~host:[ H.Tx_push { sm = 0; data = 0xABCD } ] t; chki "c1 (delay tick) push seen only from c2" (d t 0).osr_count 32;
  s t; chki "c2 delay tick refills" (d t 0).osr_count 0; chki "osr" (d t 0).osr 0xABCD; chki "delay was 2 after c2" (d t 0).delay 1;
  sc "R5 non-OUT refill on stalled non-OUT (wait)";
  let t = mk ~cfgs:[ 0, c ] [ wait true (Isa.Wsrc_gpio 5) ] in
  Pgsim.write_tx t 0 0x4242; s t; chki "refill on stalled WAIT tick" (d t 0).osr_count 0; chki "reason 4" (reason t 0) 4;
  sc "R5 no refill on forced cycles; tick consumed";
  let cdiv = { c with clkdiv_int = 2; wrap_top = 31; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, cdiv ] [ nop; nop; nop; nop; nop; nop; nop; nop ] in
  s t; chki "c0 no tick" (d t 0).pc 0; s t; chki "c1 tick" (d t 0).pc 1;
  s ~host:[ H.Tx_push { sm = 0; data = 0x55 }; H.Instr_write { sm = 0; data = set_x 9 } ] t; (* c2 *)
  chki "c2 no tick: no refill" (d t 0).osr_count 32;
  s t; (* c3: tick but forced *) chki "forced ran" (d t 0).x 9; chki "no refill on forced cycle" (d t 0).osr_count 32; chki "pc did not advance (no IMEM exec)" (d t 0).pc 1;
  s t; s t; chki "c5 tick refill" (d t 0).osr_count 0;
  sc "F1 forced during delay uses up a tick";
  let cdiv = { C.reset with clkdiv_int = 2; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, cdiv ] [ set_x ~ds:3 1 ] in
  let dl = Array.make 12 0 in
  for k = 0 to 11 do
    let host = if k = 4 then [ H.Instr_write { sm = 0; data = set_y 4 } ] else [] in
    s ~host t; dl.(k) <- (d t 0).delay
  done;
  (* c1 exec delay 3; c3 ->2; c5 forced (stays 2); c7 ->1; c9 ->0; c11 exec *)
  chk ("delay trace " ^ String.concat "," (Array.to_list (Array.map string_of_int dl))) (Array.to_list dl = [ 0; 3; 3; 2; 2; 2; 2; 1; 1; 0; 0; 3 ]);
  chki "forced y" (d t 0).y 4;
  sc "F1 forced instruction with own delay ignored, pc unchanged unless writes it";
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = set_x ~ds:7 3 } ] t; s t;
  chki "x" (d t 0).x 3; chki "delay 0" (d t 0).delay 0; chki "pc 0" (d t 0).pc 0;
  s ~host:[ H.Instr_write { sm = 0; data = jmp 9 } ] t; s t; chki "jmp sets pc" (d t 0).pc 9;
  sc "F1 forced instruction runs while disabled/divider off-tick";
  let t = mk ~cfgs:[ 0, { C.reset with clkdiv_int = 100 } ] ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = set_x 1 } ] t; s t; chki "x" (d t 0).x 1;

  (* ---------------- R6 ---------------- *)
  sc "R6 autopush stall no state change";
  let c = { C.reset with autopush = true; push_thresh = 16; in_right = false; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ in_ Isa.In_x 8 ] in
  t.sms.(0).x <- 0xA5;
  for _ = 1 to 8 do s t done;
  chki "rx full" (Pgsim.fstat t land 0xF) 1; chki "level 4" (Pgsim.flevel t lsr 4 land 15) 4;
  s t; chki "9th in shifts" (d t 0).isr_count 8; s t;
  chki "10th stalls: count unchanged" (d t 0).isr_count 8; chki "isr unchanged" (d t 0).isr 0xA5; chk "rxstall" (d t 0).rxstall; chki "reason 2" (reason t 0) 2;
  let pc = (d t 0).pc in s ~host:[ H.Rx_pop { sm = 0 } ] t; chki "pop cycle still stalled" (d t 0).pc pc;
  s t; chki "next cycle push lands, isr cleared" (d t 0).isr_count 0; chki "reason 0" (reason t 0) 0;
  sc "R6 IN not reaching thresh doesn't stall even when RX full";
  let t = mk ~cfgs:[ 0, c ] [ in_ Isa.In_x 8 ] in
  List.iter (Pgsim.Fifo.push t.sms.(0).rx) [ 1; 2; 3; 4 ];
  s t; chki "shifts" (d t 0).isr_count 8; chki "no rxstall" (Pgsim.fdebug t land 0xF) 0;
  sc "R7 nonblocking push to full";
  let t = mk [ push ~block:false () ] in
  List.iter (Pgsim.Fifo.push t.sms.(0).rx) [ 1; 2; 3; 4 ]; t.sms.(0).isr <- 5; t.sms.(0).isr_count <- 7;
  s t; chki "isr 0" (d t 0).isr 0; chki "count 0" (d t 0).isr_count 0; chk "rxstall" (d t 0).rxstall; chki "pc moved" (d t 0).pc 1; chki "reason 0" (reason t 0) 0;
  sc "R7 blocking pull empty";
  let t = mk [ pull () ] in s t; chk "txstall" (d t 0).txstall; chki "reason 1" (reason t 0) 1;
  sc "R7 non-blocking pull empty copies x";
  let t = mk [ pull ~block:false () ] in t.sms.(0).x <- 77; s t; chki "osr = x" (d t 0).osr 77; chk "no txstall" (not (d t 0).txstall);

  (* ---------------- R8 ---------------- *)
  sc "R8 mov pc / out pc ignore wrap";
  let c = { C.reset with wrap_top = 1; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ mov Isa.Mov_pc Isa.Ms_x ] in
  t.sms.(0).x <- 7; s t; chki "pc 7 (no wrap)" (d t 0).pc 7;
  let t = mk ~cfgs:[ 0, c ] [ out Isa.Out_pc 5 ] in
  t.sms.(0).osr_count <- 0; t.sms.(0).osr <- 0b10110; s t; chki "out pc" (d t 0).pc 0b10110;  (* out_right default true: low 5 bits *)
  sc "wrap: jmp not wrapped, normal wraps";
  let t = mk ~cfgs:[ 0, { C.reset with wrap_top = 2; wrap_bottom = 1 } ] [ nop; nop; nop; nop ] in
  t.sms.(0).pc <- 2; s t; chki "wrap top->bottom" (d t 0).pc 1;
  t.sms.(0).pc <- 3; s t; chki "pc past wrap_top increments" (d t 0).pc 4;

  (* ---------------- R9 IRQ timing ---------------- *)
  sc "R9 IRQ set seen one cycle later";
  let t = mk ~en:[ 0; 1 ] [ wait true (Isa.Wsrc_irq { index = 0; rel = false }); jmp 1; irq 0; jmp 3 ] in
  t.sms.(1).pc <- 2;
  s t; chki "c0: sm0 saw 0, still stalled" (d t 0).pc 0; chki "irq set" t.irq 1; chki "reason 6" (reason t 0) 6;
  s t; chki "c1 sm0 done" (d t 0).pc 1; 

  (* ---------------- R10 divider ---------------- *)
  sc "R10 divider 1.5 and 1.0 and disabled";
  let t = mk ~cfgs:[ 0, { C.reset with clkdiv_int = 1; clkdiv_frac = 128 } ] [ nop ] in
  let tr = List.init 6 (fun _ -> let p0 = (d t 0).pc in s t; ((d t 0).pc <> p0, (d t 0).acc)) in
  chk "ticks 1.5" (tr = [ false, 256; true, 128; true, 0; false, 256; true, 128; true, 0 ]);
  let t = mk ~cfgs:[ 0, { C.reset with clkdiv_int = 0; clkdiv_frac = 0 } ] ~en:[] [ nop ] in
  s t; chki "int=0 means 65536, P runs while disabled" (d t 0).acc 256;
  let t = mk ~en:[] [ nop ] in s t; chki "1.0 P=0 after tick" (d t 0).acc 0;

  (* ---------------- R11 side-set once ---------------- *)
  sc "R11 side-set once on stall; forced flag separate";
  let c = { C.reset with sideset_count = 1; sideset_base = 0; set_count = 1; set_base = 0; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ wait ~ds:0x10 true (Isa.Wsrc_gpio 9) ] in
  s t; chki "c0 side=1 -> pin0 =1 visible after c0" (Pgsim.pins_out t land 1) 1;
  s ~host:[ H.Instr_write { sm = 0; data = set_pins 0 } ] t; (* c1: stalled retry, no side re-apply *)
  chki "c1 pin0 still 1" (Pgsim.pins_out t land 1) 1;
  s t; (* c2 forced: set pins 0 *)
  chki "forced ran: pin0=0" (Pgsim.pins_out t land 1) 0;
  s t; (* c3 imem wait retry: must NOT re-apply side-set *)
  chki "c3 pin0 still 0 (side-set not repeated after forced interrupt)" (Pgsim.pins_out t land 1) 0;
  s ~host:[ H.Sm_restart 1 ] t; s t;
  chki "after restart side-set applies again" (Pgsim.pins_out t land 1) 1;
  sc "R11 forced instr with side-set uses its own flag, applied on first attempt only";
  let t = mk ~cfgs:[ 0, c ] ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = wait ~ds:0x10 true (Isa.Wsrc_gpio 9) } ] t;
  s t; chki "forced first attempt side=1" (Pgsim.pins_out t land 1) 1;
  t.pin_level <- 0; (* poke pin to see re-application *)
  s t; chki "retry doesn't reapply" (Pgsim.pins_out t land 1) 0;

  (* ---------------- R12 ---------------- *)
  sc "R12 reserved words";
  let words = [ 0x40A0 lor 0x300; 0xA060; 0xA018 ; 0x8001; 0xC008; 0xC080; 0xE0A0; 0x20E0; 0x2048; 0x4080; ] in
  List.iter (fun w ->
    let t = mk ~cfgs:[ 0, { C.reset with sideset_count = 0 } ] [ w; nop ] in
    t.sms.(0).x <- 5; s t;
    let x = d t 0 in
    chk (Printf.sprintf "word 0x%04x illegal flag" w) x.illegal;
    chki (Printf.sprintf "word 0x%04x pc" w) x.pc 1;
    chki (Printf.sprintf "word 0x%04x delay field kept" w) x.delay ((w lsr 8) land 31)) words;
  let t = mk ~cfgs:[ 0, { C.reset with sideset_count = 2; set_count = 2 } ] [ 0x40A0 lor (0b11000 lsl 8) ] in
  s t; chki "side-set bits on NOP: pins = 3" (Pgsim.pins_out t) 3;

  (* ---------------- R13 / R15 ---------------- *)
  sc "R13 WAIT 0 irq does not clear; WAIT 1 clears";
  let t = mk [ wait false (Isa.Wsrc_irq { index = 2; rel = false }); jmp 1 ] in
  t.irq <- 0; s t; chki "wait 0 passes, flag stays 0" t.irq 0;
  sc "R15 irq wait";
  let t = mk [ irq ~wt:true 1; jmp 1 ] in
  s t; chki "flag set" t.irq 2; chki "pc stay" (d t 0).pc 0; chki "reason 7" (reason t 0) 7;
  s t; chki "still waiting" (d t 0).pc 0;
  s ~host:[ H.Irq_clear 2 ] t; chki "clear cycle still stalls (flag seen at start=1)" (d t 0).pc 0; chki "flag 0" t.irq 0;
  s t; chki "released" (d t 0).pc 1; chki "reason 0" (reason t 0) 0;
  sc "R15 clear beats wait when both set";
  let t = mk [ irq ~clear:true ~wt:true 1; jmp 1 ] in
  t.irq <- 2; s t; chki "cleared, no wait" t.irq 0; chki "pc 1" (d t 0).pc 1;

  (* ---------------- F2 ---------------- *)
  sc "F2 OUT EXEC / MOV EXEC";
  let c = { C.reset with wrap_top = 3; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ mov ~ds:5 Isa.Mov_exec Isa.Ms_x; set_x 0; jmp 3; jmp 3 ] in
  t.sms.(0).x <- set_y ~ds:2 9;
  s t; chki "pc advanced by exec instr" (d t 0).pc 1; chki "delay ignored on MOV EXEC" (d t 0).delay 0;
  chk "latched exec" ((d t 0).latch = Pgsim.Exec_latch (set_y ~ds:2 9)); chk "exec_stalled 0 for exec latch" (not (d t 0).exec_stalled);
  s t; chki "y=9" (d t 0).y 9; chki "its own delay 2" (d t 0).delay 2; chki "pc not advanced" (d t 0).pc 1;
  sc "F2 exec while delay pending waits for delay";
  let t = mk ~cfgs:[ 0, c ] [ nop ] in
  t.sms.(0).delay <- 2; t.sms.(0).latch <- Pgsim.Exec_latch (set_x 4);
  s t; s t; chki "still not run after 2 delay ticks (cycle2)" (d t 0).x 0; s t; chki "run on tick with delay 0" (d t 0).x 4;
  sc "F2 exec stalled retried";
  let t = mk ~cfgs:[ 0, c ] [ mov Isa.Mov_exec Isa.Ms_x; nop ] in
  t.sms.(0).x <- pull ();
  s t; s t; chki "pull stalled latch reason" (reason t 0) 1; chk "latch still" ((d t 0).latch <> Pgsim.No_latch); chk "exec_stalled false for exec" (not (d t 0).exec_stalled);

  (* ---------------- F3 two stall reasons ---------------- *)
  sc "F3 two reasons";
  let t = mk [ wait true (Isa.Wsrc_gpio 3); jmp 0 ] in
  s t; chki "imem reason 4" (reason t 0) 4;
  s ~host:[ H.Instr_write { sm = 0; data = pull () } ] t; chki "write: reason still imem 4" (reason t 0) 4;
  s t; chki "forced stalled shows latch reason 1" (reason t 0) 1;
  s ~host:[ H.Instr_write { sm = 0; data = set_x 1 } ] t; chki "new write clears latch reason -> imem 4" (reason t 0) 4;
  s t; chki "forced completes, imem reason shows same cycle" (reason t 0) 4;
  sc "F3 imem reason on completion 0";
  let t = mk [ wait true (Isa.Wsrc_gpio 3); jmp 0 ] in
  s t; t.ext <- 8; for _ = 1 to 4 do s t done; chki "wait done reason 0" (reason t 0) 0;

  (* ---------------- F4 ---------------- *)
  sc "F4";
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = wait true (Isa.Wsrc_gpio 3) } ] t; chk "latched not attempted: exec_stalled 0" (not (d t 0).exec_stalled);
  s t; chk "stalled -> 1" (d t 0).exec_stalled; t.ext <- 8; for _ = 1 to 4 do s t done; chk "completed -> 0" (not (d t 0).exec_stalled);
  (* H3 restart clears it *)
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = wait true (Isa.Wsrc_gpio 3) } ] t; s t; s ~host:[ H.Sm_restart 1 ] t; chk "restart clears" (not (d t 0).exec_stalled);
  let t = mk ~en:[] [ nop ] in
  s ~host:[ H.Instr_write { sm = 0; data = wait true (Isa.Wsrc_gpio 3) } ] t; s t;
  s ~host:[ H.Instr_write { sm = 0; data = set_x 1 } ] t; chk "new write: exec_stalled 0 right away" (not (d t 0).exec_stalled);

  (* ---------------- F5 ---------------- *)
  sc "F5 irq waits separate";
  let t = mk [ irq ~wt:true 0; jmp 1 ] in
  s t; chki "imem irq wait" (reason t 0) 7;
  s ~host:[ H.Instr_write { sm = 0; data = irq ~wt:true 1 } ] t;
  s t; chk "forced irq wait has own slot, imem keeps" ((d t 0).irq_wait = Some 0 && (d t 0).latch_irq_wait = Some 1);
  s ~host:[ H.Irq_clear 2 ] t; s t; chk "forced completes" ((d t 0).latch = Pgsim.No_latch);
  chk "imem wait unaffected" ((d t 0).irq_wait = Some 0);

  (* ---------------- fjoin ---------------- *)
  sc "FJOIN levels";
  let t = mk ~cfgs:[ 0, { C.reset with fjoin_tx = true } ] ~en:[] [ nop ] in
  List.iter (Pgsim.write_tx t 0) [ 1; 2; 3; 4; 5; 6; 7; 8; 9 ];
  chki "tx level 8" (Pgsim.flevel t land 15) 8; chk "txover on 9th" (d t 0).txover;
  chki "fstat rx both full and empty" (Pgsim.fstat t land 0x0F01) 0x0F01;
  chki "txfull" (Pgsim.fstat t land 0x10000) 0x10000;
  let t = mk ~cfgs:[ 0, { C.reset with fjoin_rx = true } ] ~en:[] [ nop ] in
  chki "tx cap0 reads full and empty" (Pgsim.fstat t land 0x01010000) 0x01010000; chki "txempty" (Pgsim.fstat t land 0x01000000) 0x01000000;
  s ~host:[ H.Tx_push { sm = 0; data = 1 } ] t; chk "txover on cap 0" (d t 0).txover; chki "level 0" (Pgsim.flevel t) 0;

  (* ---------------- misc: delay semantic ---------------- *)
  sc "delay counter";
  let t = mk [ set_x ~ds:2 1; set_y 2; jmp 1 ] in
  s t; chki "delay 2" (d t 0).delay 2; s t; chki "1" (d t 0).delay 1; chki "pc 1 (not executed)" (d t 0).pc 1; s t; chki "0" (d t 0).delay 0; chki "y not yet" (d t 0).y 0; s t; chki "y" (d t 0).y 2;
  sc "dbg_cnt packing";
  let t = mk [ in_ ~ds:3 Isa.In_null 5 ] in s t; chki "cnt" (cnt t 0) (5 lor (32 lsl 8) lor (3 lsl 16));
  sc "side-set with side_en + stall";
  let c = { C.reset with side_en = true; sideset_count = 2; sideset_base = 3; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ wait ~ds:0b11000 true (Isa.Wsrc_gpio 2) ] in
  s t; chki "side_en: bit4 enable, bit3 value, delay bits 2:0 =0 -> pin3 =1" (Pgsim.pins_out t) 0b1000;
  sc "side-set pindirs";
  let c = { C.reset with side_pindir = true; sideset_count = 2; sideset_base = 3; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ nop ] in
  t.sms.(0).cfg <- c; Pgsim.load_program t [ mov ~ds:0b11000 Isa.Mov_y Isa.Ms_y ]; s t; chki "oe bits 3,4" (Pgsim.pins_oe t) 0b11000; chki "level untouched" (Pgsim.pins_out t) 0;

  (* ---------------- Illegal numbers: instr_write to idx>=? ---------------- *)
  sc "restart during forced stall + H3 override of SM's irq set";
  let t = mk [ irq ~wt:true 0 ] in
  s ~host:[ H.Sm_restart 1 ] t; chki "irq set in restart cycle still happens" t.irq 1; chk "irq_wait cleared by restart" ((d t 0).irq_wait = None);

  (* ---------------- EXEC vs side-set-done (contract gap) ---------------- *)
  sc "R11/F2 EXEC-latched instruction interrupting a stalled IMEM instruction";
  let c = { C.reset with sideset_count = 1; sideset_base = 0; set_count = 1; set_base = 0; wrap_top = 0; wrap_bottom = 0 } in
  let t = mk ~cfgs:[ 0, c ] [ wait ~ds:0x10 true (Isa.Wsrc_gpio 9) ] in
  s t; chki "imem wait applied side=1" (Pgsim.pins_out t land 1) 1;
  (* forced MOV EXEC x, x = set pins 0 [side=1 would make pin0=1] with ds=0x10 -> side 1 value 1?; use side 0: ds=0 *)
  t.sms.(0).x <- set_pins ~ds:0 0;
  s ~host:[ H.Instr_write { sm = 0; data = mov Isa.Mov_exec Isa.Ms_x } ] t;
  s t; (* forced mov exec runs, latches exec *)
  s t; (* exec instr set pins 0 with side=0 on first attempt: contract-wise first attempt of that instruction => side-set value 0 applied *)
  chki "R11: exec side-set 0 drives pin0 low" (Pgsim.pins_out t land 1) 0;
  s t; chki "R11: the IMEM side-set is not re-applied after the EXEC" (Pgsim.pins_out t land 1) 0;
  Printf.printf "directed: %d checks, %d failed\n" !total !fails;
  if !fails > 0
  then failwith (String.concat "\n" (Printf.sprintf "directed: %d checks failed" !fails :: List.rev !messages))
