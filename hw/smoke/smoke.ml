(* Smoke tests for the block 2 RTL. Every expected value below was worked out by hand from
   docs/engine.md and the RP2040 datasheet, cycle by cycle. The reasoning is in each
   test's comment. Only the decoder check uses the Isa library.

   Cycle convention (engine.md section 5): the outputs read in a cycle are the state after
   the previous cycle's edge, with that cycle's inputs applied. A host pulse set in a cycle
   takes effect at its end. *)

open Hardcaml

let failures = ref 0
let checks = ref 0

let expect what ~cyc got want =
  incr checks;
  if got <> want
  then (
    incr failures;
    Printf.printf
      "FAIL %s at cycle %d: got %d (0x%x), expected %d (0x%x)\n%!"
      what
      cyc
      got
      got
      want
      want)
;;

(* ---------- Harness ---------- *)

type tb =
  { sim : Cyclesim.t_port_list
  ; mutable now : int
  }

let pulse_names =
  [ "sm_restart"
  ; "clkdiv_restart"
  ; "fifo_flush"
  ; "irq_clear"
  ; "irq_force"
  ; "fdebug_clear"
  ; "txf_push"
  ; "rxf_pop"
  ; "instr_write"
  ; "imem_write"
  ]
;;

let set tb name v =
  let r = Cyclesim.in_port tb.sim name in
  r := Bits.of_int ~width:(Bits.width !r) v
;;

let get tb name = Bits.to_int !(Cyclesim.out_port ~clock_edge:Before tb.sim name)

(* One clock cycle. [f] sets this cycle's inputs; [check] reads this cycle's outputs. *)
let cyc tb ?(f = fun () -> ()) ?(check = fun () -> ()) () =
  List.iter (fun n -> set tb n 0) pulse_names;
  f ();
  Cyclesim.cycle_check tb.sim;
  Cyclesim.cycle_before_clock_edge tb.sim;
  check ();
  Cyclesim.cycle_at_clock_edge tb.sim;
  Cyclesim.cycle_after_clock_edge tb.sim;
  tb.now <- tb.now + 1
;;

(* Build a block with [num_sms] engines, reset it, and leave every input at 0 except
   rst_n, which is high from the first cycle after reset (engine.md section 5, cycle 0). *)
let make ~num_sms =
  let circuit = Polyglot_hw.Pio_block.circuit ~num_sms in
  let sim = Cyclesim.create circuit in
  let tb = { sim; now = 0 } in
  List.iter (fun (_, r) -> r := Bits.zero (Bits.width !r)) (Cyclesim.in_ports sim);
  (* Cyclesim applies the reset values only through Cyclesim.reset (a clocked cycle with
     rst_n low does not reset registers in this simulator), so call it while rst_n is low,
     then release. *)
  set tb "rst_n" 0;
  cyc tb ();
  Cyclesim.reset sim;
  cyc tb ();
  set tb "rst_n" 1;
  tb
;;

(* Configuration words, RP2040 layouts (datasheet 3.7). *)
let clkdiv_1 = 0x0001_0000 (* INT 1, FRAC 0: a tick every cycle *)
let execctrl_default = 0x0001_F000 (* WRAP_TOP 31, WRAP_BOTTOM 0 *)
let shiftctrl_default = 0x000C_0000 (* IN and OUT shift right, thresholds 32 *)

(* PINCTRL with SET_COUNT, OUT_COUNT and SIDESET_COUNT, all bases at 0 unless given. *)
let pinctrl ?(set_count = 1) ?(out_count = 0) ?(sideset_count = 0) ?(sideset_base = 0)
    ?(set_base = 0) ()
  =
  (sideset_count lsl 29)
  lor (set_count lsl 26)
  lor (out_count lsl 20)
  lor (sideset_base lsl 10)
  lor (set_base lsl 5)
;;

let configure tb ~sm ~clkdiv ~execctrl ~shiftctrl ~pinctrl_v =
  set tb (Printf.sprintf "clkdiv%d" sm) clkdiv;
  set tb (Printf.sprintf "execctrl%d" sm) execctrl;
  set tb (Printf.sprintf "shiftctrl%d" sm) shiftctrl;
  set tb (Printf.sprintf "pinctrl%d" sm) pinctrl_v
;;

(* Write an instruction word to IMEM, with the SM disabled, in one cycle. *)
let load_imem tb addr word =
  cyc tb
    ~f:(fun () ->
      set tb "imem_write" 1;
      set tb "imem_addr" addr;
      set tb "imem_data" word)
    ()
;;

(* Run [n] cycles, reading [check] in each. Outputs are read with clock_edge Before. *)
let run tb n ?(f = fun _ () -> ()) ?(check = fun _ _ -> ()) () =
  for c = 0 to n - 1 do
    cyc tb ~f:(f c) ~check:(check c) ()
  done
;;

(* ---------- 1. Decoder, exhaustive against the ISA library (engine.md section 4) ---------- *)

let decoder_exhaustive () =
  let sim = Cyclesim.create (Polyglot_hw.Decode.circuit ()) in
  let set_in name v =
    let r = Cyclesim.in_port sim name in
    r := Bits.of_int ~width:(Bits.width !r) v
  in
  let get_out name = Bits.to_int !(Cyclesim.out_port ~clock_edge:Before sim name) in
  let configs =
    List.init 6 (fun c -> c, false) @ List.init 5 (fun c -> c + 1, true)
  in
  let before = !failures in
  let n_checked = ref 0 in
  for w = 0 to 0xFFFF do
    let d = Polyglot_isa.Isa.decode w in
    let legal = Polyglot_isa.Isa.is_legal d in
    let is_c p = legal && p in
    let want_jmp = is_c (match d with Polyglot_isa.Isa.Jmp _ -> true | _ -> false) in
    let want_wait = is_c (match d with Polyglot_isa.Isa.Wait _ -> true | _ -> false) in
    let want_in = is_c (match d with Polyglot_isa.Isa.In _ -> true | _ -> false) in
    let want_out = is_c (match d with Polyglot_isa.Isa.Out _ -> true | _ -> false) in
    let want_push = is_c (match d with Polyglot_isa.Isa.Push _ -> true | _ -> false) in
    let want_pull = is_c (match d with Polyglot_isa.Isa.Pull _ -> true | _ -> false) in
    let want_mov = is_c (match d with Polyglot_isa.Isa.Mov _ -> true | _ -> false) in
    let want_irq = is_c (match d with Polyglot_isa.Isa.Irq _ -> true | _ -> false) in
    let want_set = is_c (match d with Polyglot_isa.Isa.Set _ -> true | _ -> false) in
    let want_lcu =
      match d with
      | Polyglot_isa.Isa.In { source = In_lcu; _ }
      | Polyglot_isa.Isa.Mov { source = Ms_crc; _ }
      | Polyglot_isa.Isa.Set { dest = Set_lcu; _ } -> 1
      | _ -> 0
    in
    let want_bc =
      match d with
      | Polyglot_isa.Isa.In { bit_count; _ } | Polyglot_isa.Isa.Out { bit_count; _ } when legal ->
        bit_count
      | _ -> 0
    in
    List.iter
      (fun (count, enable) ->
        set_in "instr" w;
        set_in "sideset_count" count;
        set_in "side_en" (if enable then 1 else 0);
        Cyclesim.cycle_check sim;
        Cyclesim.cycle_before_clock_edge sim;
        incr n_checked;
        let b x = if x then 1 else 0 in
        let split =
          Polyglot_isa.Isa.Side.split
            { Polyglot_isa.Isa.Side.count; enable }
            ((w lsr 8) land 31)
        in
        let want_sv = Option.value split.side ~default:0 in
        let want_sval = if Option.is_some split.side then 1 else 0 in
        let got name v = if get_out name <> v then (incr failures; Printf.printf "FAIL decode %s w=0x%04x count=%d en=%b: got %d want %d\n%!" name w count enable (get_out name) v) in
        got "legal" (b legal);
        got "is_jmp" (b want_jmp);
        got "is_wait" (b want_wait);
        got "is_in" (b want_in);
        got "is_out" (b want_out);
        got "is_push" (b want_push);
        got "is_pull" (b want_pull);
        got "is_mov" (b want_mov);
        got "is_irq" (b want_irq);
        got "is_set" (b want_set);
        got "uses_lcu" want_lcu;
        got "side_valid" want_sval;
        got "side_value" want_sv;
        got "delay" split.delay;
        got "bit_count" want_bc;
        Cyclesim.cycle_at_clock_edge sim;
        Cyclesim.cycle_after_clock_edge sim)
      configs
  done;
  expect "decoder mismatches" ~cyc:0 (!failures - before) 0;
  Printf.printf "decoder: %d words x %d side-set configs = %d evaluations checked\n%!"
    0x10000 (List.length configs) !n_checked
;;

(* ---------- 2. SET PINS / JMP loop, with the pin timing of R1 ---------- *)

(* IMEM: 0 SET PINDIRS,1; 1 SET PINS,1; 2 SET PINS,0; 3 JMP 1. SET_COUNT 1 at pin 0.
   Enabled in cycle 0. Program counter, one instruction per cycle:
     c0 pc0 (dir write) -> c1 pc1 (set 1) -> c2 pc2 (set 0) -> c3 pc3 (JMP 1) -> c4 pc1
     -> c5 pc2 -> c6 pc3 (JMP) -> c7 pc1 ...
   A write in cycle k is on pins_out in cycle k+1 (R1). pins_oe becomes 1 in cycle 1.
   Level writes happen in c1, c2, c4, c5, c7, ...:
     pins_out: c0 0, c1 0, c2 1, c3 0, c4 0, c5 1, c6 0, c7 0, c8 1
     pins_oe:  c0 0, c1 1, and 1 from then on. *)
let set_pins_loop () =
  let tb = make ~num_sms:1 in
  List.iteri
    (fun addr w -> load_imem tb addr w)
    [ 0xE081 (* SET PINDIRS,1 *); 0xE001 (* SET PINS,1 *); 0xE000 (* SET PINS,0 *); 0x0001 (* JMP 1 *) ];
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  let want_out = [| 0; 0; 1; 0; 0; 1; 0; 0; 1 |] in
  let want_pc = [| 0; 1; 2; 3; 1; 2; 3; 1; 2 |] in
  let want_oe = [| 0; 1; 1; 1; 1; 1; 1; 1; 1 |] in
  run
    tb
    9
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 1)
    ~check:(fun c () ->
      expect "set_pins pins_out" ~cyc:c (get tb "pins_out") want_out.(c);
      expect "set_pins pins_oe" ~cyc:c (get tb "pins_oe") want_oe.(c);
      expect "set_pins dbg_pc0" ~cyc:c (get tb "dbg_pc0") want_pc.(c))
    ()
;;

(* ---------- 3. Side-set on a stalled instruction (R11) ---------- *)

(* SIDESET_COUNT 1 (no enable), SIDESET_BASE 5. IMEM: 0 PULL block side 1 (0x90A0);
   1 SET PINS,1 side 0 (0xE001). Enabled in cycle 0, TX empty.
     c0: PULL stalls (TX empty). Side-set applies on this first attempt: pin 5 -> 1, on
         pins_out from c1. TXSTALL is set, visible from c1.
     c1, c2: still stalled. No second side-set (R11).
     c2: host pushes a word (H1). The SM sees it from c3.
     c3: PULL completes. Its side-set was already done, so pin 5 keeps 1.
     c4: SET PINS,1 side 0 runs: pin 5 -> 0 and pin 0 -> 1, on pins_out from c5. *)
let side_set_stall () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x90A0;
  load_imem tb 1 0xE001;
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ~sideset_count:1 ~sideset_base:5 ());
  let want_out_bit5 = [| 0; 1; 1; 1; 1; 0 |] in
  let want_out_bit0 = [| 0; 0; 0; 0; 0; 1 |] in
  (* c3: PULL completes, pc 1 from c4. c4: SET completes, pc 2 from c5. *)
  let want_pc = [| 0; 0; 0; 0; 1; 2 |] in
  run
    tb
    6
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 2 then (
        set tb "txf_push" 1;
        set tb "txf_data" 0x1234_5678))
    ~check:(fun c () ->
      let po = get tb "pins_out" in
      expect "side_set pin5" ~cyc:c ((po lsr 5) land 1) want_out_bit5.(c);
      expect "side_set pin0" ~cyc:c (po land 1) want_out_bit0.(c);
      expect "side_set dbg_pc0" ~cyc:c (get tb "dbg_pc0") want_pc.(c);
      (* TXSTALL is bit 24 of FDEBUG, set by the empty-TX stall of c0 and visible from c1. *)
      if c = 1 then expect "side_set TXSTALL" ~cyc:c ((get tb "fdebug" lsr 24) land 1) 1;
      if c = 1 then expect "side_set stall reason" ~cyc:c ((get tb "dbg_cnt0" lsr 24) land 15) 1)
    ()
;;

(* ---------- 4. WAIT on a pin, synchroniser on and bypassed (R1) ---------- *)

(* IMEM: 0 WAIT 1 PIN 0; 1 SET PINS,1. Enabled in cycle 0. External pin 0 is 0 until cycle
   10, then 1. Bypassed: the WAIT sees r1, which is pins_in one cycle earlier, so it
   completes in cycle 11 and pc is 1 from cycle 12. Synchronised: it sees r3, which is
   pins_in three cycles earlier, so it completes in cycle 13 and pc is 1 from cycle 14. *)
let wait_pin ~bypass =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x20A0;
  load_imem tb 1 0xE001;
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  set tb "sync_bypass" (if bypass then 1 else 0);
  let rise = 10 in
  let n = 16 in
  let want_pc_change = if bypass then 12 else 14 in
  let label = if bypass then "wait_pin bypassed" else "wait_pin synchronised" in
  run
    tb
    n
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      set tb "pins_in" (if c >= rise then 1 else 0))
    ~check:(fun c () ->
      (* pc is 0 until the WAIT completes, then 1 for one cycle. The SET after it moves
         the pc on to 2, and the JMP after that returns it to 0. Only the change is
         checked here. *)
      let pc = get tb "dbg_pc0" in
      if c < want_pc_change then expect (label ^ " pc before") ~cyc:c pc 0;
      if c = want_pc_change then expect (label ^ " pc change") ~cyc:c pc 1)
    ()
;;

(* ---------- 5. IRQ set by one engine, WAIT by another (num_sms = 2) ---------- *)

(* The engines share IMEM, so the second engine starts at address 8 (a forced JMP 8 while
   it is disabled, F1). IMEM: 0 IRQ set 3; 1 JMP 0; 8 WAIT 1 IRQ 3; 9 JMP 9.
   Both enabled in cycle 0, clock divider 1.
     SM0 sets flag 3 in c0, c2, c4 ... (IRQ instruction at pc0 on even cycles).
     SM1 at c0 waits for flag 3, which reads 0 (stall). At c1 the flag reads 1 (R9: a set
     is seen one cycle later), so SM1 completes and clears it. Its pc is 9 from c2.
   irq: c0 0, c1 1, c2 0 (SM1 cleared it in c1), c3 1 (SM0 set it in c2), then 1 (no more
   clears). *)
let irq_between_engines () =
  let tb = make ~num_sms:2 in
  load_imem tb 0 0xC003 (* IRQ set 3 *);
  load_imem tb 1 0x0000 (* JMP 0 *);
  load_imem tb 8 0x20C3 (* WAIT 1 IRQ 3 *);
  load_imem tb 9 0x0009 (* JMP 9 *);
  List.iter
    (fun sm ->
      configure
        tb
        ~sm
        ~clkdiv:clkdiv_1
        ~execctrl:execctrl_default
        ~shiftctrl:shiftctrl_default
        ~pinctrl_v:(pinctrl ()))
    [ 0; 1 ];
  (* Engine 1 starts at address 8: forced JMP 8 while disabled (F1). The write is in the
     cycle before, and the JMP runs in the next, so pc is 8 from the first run cycle. *)
  cyc tb
    ~f:(fun () ->
      set tb "instr_write" 1;
      set tb "instr_sm" 1;
      set tb "instr_data" 0x0008)
    ();
  cyc tb ();
  (* Flag 3 is bit 3, so its value is 8. *)
  let want_irq = [| 0; 8; 0; 8; 8 |] in
  let want_pc1 = [| 8; 8; 9; 9; 9 |] in
  run
    tb
    5
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 3)
    ~check:(fun c () ->
      expect "irq irq" ~cyc:c (get tb "irq") want_irq.(c);
      expect "irq dbg_pc1" ~cyc:c (get tb "dbg_pc1") want_pc1.(c))
    ()
;;

(* ---------- 6. Forced instructions while disabled, F1, F3, F4 ---------- *)

(* SM disabled throughout. Host writes INSTR in cycle w; the instruction runs in w+1.
   1. SET PINDIRS,1 (0xE081) in cycle 0: pins_oe 1 from cycle 2.
   2. SET PINS,1 [7] (0xE701) in cycle 2: pins_out 1 from cycle 4, and the delay field
      is ignored: DBG_CNT delay stays 0.
   3. JMP 5 (0x0005) in cycle 4: pc 5 from cycle 6.
   4. PULL block (0x80A0) in cycle 6 with TX empty: it stalls. EXEC_STALLED is 1 and the
      latch stall reason is 1 from cycle 8. pc stays 5.
   5. Host pushes a word in cycle 8. The SM sees it in cycle 9, the PULL completes, and
      EXEC_STALLED and the stall reason clear from cycle 10. pc stays 5. *)
let forced_while_disabled () =
  let tb = make ~num_sms:1 in
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  (* (cycle of the INSTR write, word). Each runs in the following cycle. *)
  let forced = [ 0, 0xE081; 2, 0xE701; 4, 0x0005; 6, 0x80A0 ] in
  let push_at = 8 in
  run
    tb
    11
    ~f:(fun c () ->
      List.iter
        (fun (k, w) ->
          if k = c
          then (
            set tb "instr_write" 1;
            set tb "instr_data" w))
        forced;
      if c = push_at
      then (
        set tb "txf_push" 1;
        set tb "txf_data" 0xABCD))
    ~check:(fun c () ->
      let oe = get tb "pins_oe" in
      let po = get tb "pins_out" in
      expect "forced pins_oe" ~cyc:c (oe land 1) (if c >= 2 then 1 else 0);
      expect "forced pins_out" ~cyc:c (po land 1) (if c >= 4 then 1 else 0);
      expect "forced delay" ~cyc:c ((get tb "dbg_cnt0" lsr 16) land 31) 0;
      expect "forced pc" ~cyc:c (get tb "dbg_pc0") (if c >= 6 then 5 else 0);
      if c >= 8
      then (
        let stalled = if c < 10 then 1 else 0 in
        expect "forced exec_stalled" ~cyc:c (get tb "dbg_exec_stalled0") stalled;
        expect "forced latch stall reason" ~cyc:c ((get tb "dbg_cnt0" lsr 24) land 15) stalled))
    ()
;;

(* ---------- 7. OUT EXEC (F2) ---------- *)

(* IMEM: 0 PULL block; 1 OUT EXEC,32; 2 JMP 1. SET_COUNT 1. Enabled in cycle 0, and the
   host pushes 0x0000E001 (SET PINS,1) in cycle 0, so the TX FIFO has it from cycle 1.
     c0: PULL stalls (TX empty at the start of c0). Stall reason 1 is visible from c1.
     c1: PULL pops the word; pc 1 from c2.
     c2: OUT EXEC runs, latches the low 16 bits (0xE001), and pc 2 from c3.
     c3: the latched SET PINS,1 runs. It does not advance pc, so pc stays 2 in c4.
         pins_out 1 from c4.
     c4: JMP 1 runs, so pc is 1 from c5. *)
let out_exec () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x80A0;
  load_imem tb 1 0x60E0;
  load_imem tb 2 0x0001;
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  let want_pc = [| 0; 0; 1; 2; 2; 1 |] in
  let want_out = [| 0; 0; 0; 0; 1; 1 |] in
  run
    tb
    6
    ~f:(fun c () ->
      if c = 0 then (
        set tb "sm_enable" 1;
        set tb "txf_push" 1;
        set tb "txf_data" 0x0000_E001))
    ~check:(fun c () ->
      expect "out_exec dbg_pc0" ~cyc:c (get tb "dbg_pc0") want_pc.(c);
      expect "out_exec pins_out" ~cyc:c (get tb "pins_out" land 1) want_out.(c);
      if c = 1 then expect "out_exec stall reason" ~cyc:c ((get tb "dbg_cnt0" lsr 24) land 15) 1;
      if c = 2 then expect "out_exec stall cleared" ~cyc:c ((get tb "dbg_cnt0" lsr 24) land 15) 0)
    ()
;;

(* ---------- 8. Clock divider, INT 2 FRAC 128 (R10) ---------- *)

(* D = 2.5. The phase P is the value in units of 1/256 cycle, and each cycle adds 256.
   A tick comes when P + 256 >= 640. From c0, P is 0, 256, 512, 128, 384, 0, 256, ...,
   so ticks fall in c2, c4, c7, c9, c12, c14 (gaps 2, 3, 2, 3 ...).
   IMEM: 0 SET PINS,1; 1 SET PINS,0; 2 JMP 0. Ticks execute pc0 at c2, pc1 at c4, pc2 at
   c7, pc0 at c9, pc1 at c12, pc2 at c14. *)
let clock_divider () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0xE001;
  load_imem tb 1 0xE000;
  load_imem tb 2 0x0000;
  configure
    tb
    ~sm:0
    ~clkdiv:0x0002_8000
    ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  (* The divider runs while the SM is disabled, so restart it in the cycle before enabling.
     Its phase is then 0 in cycle 0. *)
  cyc tb ~f:(fun () -> set tb "clkdiv_restart" 1) ();
  let want_phase = [| 0; 256; 512; 128; 384; 0; 256; 512; 128; 384; 0; 256; 512; 128; 384; 0 |] in
  let want_pc = [| 0; 0; 0; 1; 1; 2; 2; 2; 0; 0; 1; 1; 1; 2; 2; 0 |] in
  let want_out = [| 0; 0; 0; 1; 1; 0; 0; 0; 0; 0; 1; 1; 1; 0; 0; 0 |] in
  run
    tb
    16
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 1)
    ~check:(fun c () ->
      expect "clkdiv phase" ~cyc:c (get tb "dbg_phase0") want_phase.(c);
      expect "clkdiv pc" ~cyc:c (get tb "dbg_pc0") want_pc.(c);
      expect "clkdiv pins_out" ~cyc:c (get tb "pins_out" land 1) want_out.(c))
    ()
;;

(* ---------- 9. FIFO join and FIFO status (engine.md 2, 3, H1, H2, H6) ---------- *)

let fifo_status () =
  (* Not joined: 4 words accepted, the 5th dropped with TXOVER. *)
  let tb = make ~num_sms:1 in
  for k = 1 to 5 do
    cyc tb ~f:(fun () -> set tb "txf_push" 1; set tb "txf_data" k) ()
  done;
  cyc tb
    ~check:(fun () ->
      (* FSTAT: TXFULL bit 16, RXEMPTY bit 8. FLEVEL: TX level 4. FDEBUG: TXOVER bit 16. *)
      expect "fifo fstat (4 deep)" ~cyc:0 (get tb "fstat") 0x0001_0100;
      expect "fifo flevel (4 deep)" ~cyc:0 (get tb "flevel") 0x4;
      expect "fifo fdebug (4 deep)" ~cyc:0 (get tb "fdebug") 0x0001_0000)
    ();
  (* Joined to TX: 8 words accepted, RX has no capacity. *)
  let tb = make ~num_sms:1 in
  set tb "shiftctrl0" (shiftctrl_default lor (1 lsl 30));
  for k = 1 to 9 do
    cyc tb ~f:(fun () -> set tb "txf_push" 1; set tb "txf_data" k) ()
  done;
  cyc tb
    ~check:(fun () ->
      (* TXFULL bit 16, RXEMPTY bit 8 and RXFULL bit 0 both set. TX level 8. TXOVER from the
         9th push. *)
      expect "fifo fstat (joined TX)" ~cyc:0 (get tb "fstat") 0x0001_0101;
      expect "fifo flevel (joined TX)" ~cyc:0 (get tb "flevel") 0x8;
      expect "fifo fdebug (joined TX)" ~cyc:0 (get tb "fdebug") 0x0001_0000)
    ();
  (* Flush empties both FIFOs (H6). *)
  cyc tb ~f:(fun () -> set tb "fifo_flush" 1) ();
  cyc tb
    ~check:(fun () ->
      expect "fifo flush level" ~cyc:0 (get tb "flevel") 0;
      (* TXEMPTY bit 24 (level 0), RXEMPTY bit 8, RXFULL bit 0 (RX has no capacity). *)
      expect "fifo flush fstat" ~cyc:0 (get tb "fstat") 0x0100_0101)
    ();
  (* Joined to RX: a host pop from an empty RX FIFO sets RXUNDER (bit 8). *)
  let tb = make ~num_sms:1 in
  set tb "shiftctrl0" (shiftctrl_default lor (1 lsl 31));
  cyc tb ~f:(fun () -> set tb "rxf_pop" 1; set tb "rxf_sm" 0) ();
  cyc tb
    ~check:(fun () ->
      expect "fifo rxunder" ~cyc:0 (get tb "fdebug") 0x100;
      expect "fifo rxf_data empty" ~cyc:0 (get tb "rxf_data") 0)
    ()
;;

(* ---------- 10. OUT with autopull from host-pushed TX words (R5) ---------- *)

(* IMEM 0: OUT PINS,8. WRAP_TOP = WRAP_BOTTOM = 0, so pc stays 0. OUT_COUNT 8 at pin 0.
   Autopull on, thresholds 32. Words W1 = 0xC3 (pushed in c0) and W2 = 0xA5 (pushed in c1).
     c0: OSR count 32 >= threshold, TX empty: stall, TXSTALL set (visible c1).
     c1: TX has W1: refill (count 0, pop W1), stall with reason 3. W2 is pushed at its end.
     c2: shifts out 0xC3 to pins 0 to 7; count 8. pins_out 0xC3 from c3.
     c3, c4: shift out 0; count 16, 24.
     c5: shifts out 0 and reaches count 32, so it refills from W2 (not empty). count 0 from c6.
     c6: shifts out 0xA5 (low 8 bits of W2); pins_out 0xA5 from c7. count 8.
     c7, c8: count 16, 24. c9: count 32, TX empty, no refill.
     c10: stall (reason 3) with TXSTALL. *)
let autopull_out () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x6008 (* OUT PINS,8 *);
  configure
    tb
    ~sm:0
    ~clkdiv:clkdiv_1
    ~execctrl:0
    ~shiftctrl:(shiftctrl_default lor (1 lsl 17))
    ~pinctrl_v:(pinctrl ~out_count:8 ~set_count:0 ());
  (* Indexed by cycle. The stall of c10 shows from c11 (the stall is decided in c10). *)
  let want_pins = [| 0; 0; 0; 0xC3; 0; 0; 0; 0xA5; 0; 0; 0; 0 |] in
  let want_count = [| 32; 32; 0; 8; 16; 24; 0; 8; 16; 24; 32; 32 |] in
  let want_stall = [| 0; 3; 3; 0; 0; 0; 0; 0; 0; 0; 0; 3 |] in
  run
    tb
    12
    ~f:(fun c () ->
      if c = 0
      then (
        set tb "sm_enable" 1;
        set tb "txf_push" 1;
        set tb "txf_data" 0xC3);
      if c = 1
      then (
        set tb "txf_push" 1;
        set tb "txf_data" 0xA5))
    ~check:(fun c () ->
      expect "autopull pins" ~cyc:c (get tb "pins_out" land 0xFF) want_pins.(c);
      expect "autopull osr count" ~cyc:c ((get tb "dbg_cnt0" lsr 8) land 63) want_count.(c);
      expect "autopull stall reason" ~cyc:c ((get tb "dbg_cnt0" lsr 24) land 15) want_stall.(c);
      if c = 1 then expect "autopull TXSTALL" ~cyc:c ((get tb "fdebug" lsr 24) land 1) 1)
    ()
;;

(* ---------- 11. Further cases (engine.md R2, R4, R6, F6, H3, OUT_STICKY, MOV, FIFO) ---------- *)

(* Forced JMP to [addr] on a disabled SM, then one idle cycle, so that pc is [addr] from the
   next cycle (F1). *)
(* Two idle cycles, so that the input synchronisers hold the pin levels set so far. *)
let preload tb =
  cyc tb ();
  cyc tb ()
;;

let force_jmp tb ~sm ~addr =
  cyc tb
    ~f:(fun () ->
      set tb "instr_write" 1;
      set tb "instr_sm" sm;
      set tb "instr_data" addr)
    ();
  cyc tb ()
;;

let cfg_all tb ~sms ~execctrl ~shiftctrl ~pinctrl_v =
  List.iter
    (fun sm ->
      configure tb ~sm ~clkdiv:clkdiv_1 ~execctrl ~shiftctrl ~pinctrl_v)
    sms
;;

let check_arr what tb ~name ~mask arr c =
  if c < Array.length arr then expect what ~cyc:c (get tb name land mask) arr.(c)
;;

(* IRQ with REL (R14): flag = (index & 4) | ((index + sm) & 3). IRQ set 4 REL (0xC014).
   SM0 sets flag 4 (bit 4, 0x10); SM1 sets flag 5 (bit 5, 0x20). Both at pc 0 in c0. *)
let irq_rel () =
  let tb = make ~num_sms:2 in
  load_imem tb 0 0xC014;
  load_imem tb 1 0x0001;
  cfg_all tb ~sms:[ 0; 1 ] ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  let want = [| 0; 0x30; 0x30; 0x30 |] in
  run tb 4
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 3)
    ~check:(fun c () -> check_arr "irq_rel irq" tb ~name:"irq" ~mask:0xFF want c)
    ()
;;

(* OUT_STICKY, one record (datasheet 3.7 "the most recent OUT/SET"). SM1 (higher) sets
   pin 0 direction to 1 in c0 and then loops, so its record is a direction write and
   re-asserts pin 0 direction = 1 each cycle. SM0 loops on SET PINDIRS,0 (writes at even
   cycles), but SM1 wins. In c5 the host forces SET PINS,1 on SM1, which is a new level
   write: it replaces the record, so direction is no longer sticky. SM0's next direction
   write (c6) then takes effect, and pin 0 is driven high by the sticky level.
   pins_oe: c0 0, c1..c6 1, c7 on 0. pins_out: 0 until c6, 1 from c7. *)
let sticky_one_record () =
  let tb = make ~num_sms:2 in
  load_imem tb 0 0xE080 (* SET PINDIRS,0 *);
  load_imem tb 1 0x0000 (* JMP 0 *);
  load_imem tb 8 0xE081 (* SET PINDIRS,1 *);
  load_imem tb 9 0x0009 (* JMP 9 *);
  let execctrl = execctrl_default lor (1 lsl 17) in
  cfg_all tb ~sms:[ 0; 1 ] ~execctrl ~shiftctrl:shiftctrl_default ~pinctrl_v:(pinctrl ());
  force_jmp tb ~sm:1 ~addr:8;
  let want_oe = [| 0; 1; 1; 1; 1; 1; 1; 0; 0; 0 |] in
  let want_out = [| 0; 0; 0; 0; 0; 0; 0; 1; 1; 1 |] in
  run tb 10
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 3;
      if c = 5
      then (
        set tb "instr_write" 1;
        set tb "instr_sm" 1;
        set tb "instr_data" 0xE001))
    ~check:(fun c () ->
      check_arr "sticky pins_oe" tb ~name:"pins_oe" ~mask:1 want_oe c;
      check_arr "sticky pins_out" tb ~name:"pins_out" ~mask:1 want_out c)
    ()
;;

(* MOV (datasheet 3.4.8.2), one SM, enabled in c0. STATUS_N 1 with TXLEVEL.
     0 SET X,5           1 MOV Y,~X         2 MOV ISR,::X     3 MOV OSR,Y
     4 MOV X,STATUS      5 PULL block      6 MOV EXEC,OSR    7 JMP 7
   The host pushes 0xE001 in c4, so TX is empty in c4 (STATUS is all ones) and the PULL
   in c5 gets it. MOV EXEC in c6 latches SET PINS,1, which runs in c7 and drives pin 0 from
   c8. Writes made in cycle k show from k+1. *)
let mov_ops () =
  let tb = make ~num_sms:1 in
  List.iteri
    (fun a w -> load_imem tb a w)
    [ 0xE025; 0xA049; 0xA0D1; 0xA0E2; 0xA025; 0x80A0; 0xA087; 0x0007 ];
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:(execctrl_default lor 1)
    ~shiftctrl:shiftctrl_default ~pinctrl_v:(pinctrl ());
  let want_pc = [| 0; 1; 2; 3; 4; 5; 6; 7; 7; 7 |] in
  let want_x = [| 0; 5; 5; 5; 5; 0xFFFFFFFF; 0xFFFFFFFF; 0xFFFFFFFF; 0xFFFFFFFF; 0xFFFFFFFF |] in
  let want_y = Array.init 10 (fun c -> if c >= 2 then 0xFFFFFFFA else 0) in
  let want_isr = Array.init 10 (fun c -> if c >= 3 then 0xA0000000 else 0) in
  let want_osr = [| 0; 0; 0; 0; 0xFFFFFFFA; 0xFFFFFFFA; 0xE001; 0xE001; 0xE001; 0xE001 |] in
  let want_out = [| 0; 0; 0; 0; 0; 0; 0; 0; 1; 1 |] in
  run tb 10
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 4
      then (
        set tb "txf_push" 1;
        set tb "txf_data" 0xE001))
    ~check:(fun c () ->
      check_arr "mov pc" tb ~name:"dbg_pc0" ~mask:31 want_pc c;
      check_arr "mov X" tb ~name:"dbg_x0" ~mask:0xFFFFFFFF want_x c;
      check_arr "mov Y" tb ~name:"dbg_y0" ~mask:0xFFFFFFFF want_y c;
      check_arr "mov ISR" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF want_isr c;
      check_arr "mov OSR" tb ~name:"dbg_osr0" ~mask:0xFFFFFFFF want_osr c;
      check_arr "mov pins_out" tb ~name:"pins_out" ~mask:1 want_out c)
    ()
;;

(* IN with autopush on a full RX FIFO (R6). Threshold 8, pins 0x5A, all synchronisers
   bypassed. IN PINS,8 pushes its word at c0 to c3, which fills the RX FIFO. In c4 the
   next IN would reach the threshold with RX full: it stalls with reason 2, RXSTALL, and no
   shift (ISR stays 0). The host pops in c7. The stalled IN completes in c8 (RX has space
   from c8), so pc is 1 from c9. *)
let in_autopush_stall () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x4008 (* IN PINS,8 *);
  set tb "pins_in" 0x5A;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  (* execctrl 0: wrap top and bottom both 0, so pc stays 0 and the IN repeats. *)
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:0
    ~shiftctrl:(shiftctrl_default lor (1 lsl 16) lor (8 lsl 20)) ~pinctrl_v:(pinctrl ());
  let want_stall = [| 0; 0; 0; 0; 0; 2; 2; 2; 2 |] in
  let want_rxstall = Array.init 9 (fun c -> if c >= 5 then 1 else 0) in
  let want_rxlevel = [| 0; 1; 2; 3; 4; 4; 4; 4; 3 |] in
  run tb 9
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 7
      then (
        set tb "rxf_pop" 1;
        set tb "rxf_sm" 0))
    ~check:(fun c () ->
      check_arr "autopush pc" tb ~name:"dbg_pc0" ~mask:31 (Array.make 9 0) c;
      check_arr "autopush stall reason" tb ~name:"dbg_cnt0" ~mask:0x0F00_0000
        (Array.map (fun r -> r lsl 24) want_stall) c;
      check_arr "autopush RXSTALL" tb ~name:"fdebug" ~mask:1 want_rxstall c;
      check_arr "autopush rx level" tb ~name:"flevel" ~mask:0xF0
        (Array.map (fun l -> l lsl 4) want_rxlevel) c;
      check_arr "autopush isr" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF (Array.make 9 0) c;
      if c = 7 then expect "autopush popped word" ~cyc:c (get tb "rxf_data") 0x5A00_0000)
    ()
;;

(* PUSH IFFULL (datasheet 3.4.6.2): a no-op below the threshold, a push at it. Threshold 8,
   pins 0xF. c0 IN PINS,4: ISR 0xF0000000, count 4. c1 PUSH IFFULL is a no-op (count 4 < 8).
   c2 IN PINS,4: ISR 0xFF000000, count 8. c3 PUSH IFFULL pushes it and clears ISR. *)
let push_iffull () =
  let tb = make ~num_sms:1 in
  List.iteri (fun a w -> load_imem tb a w)
    [ 0x4004 (* IN PINS,4 *); 0x8060 (* PUSH IFFULL block *); 0x4004; 0x8060; 0x0004 (* JMP 4 *) ];
  set tb "pins_in" 0xF;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default
    ~shiftctrl:(shiftctrl_default lor (8 lsl 20)) ~pinctrl_v:(pinctrl ());
  let want_pc = [| 0; 1; 2; 3; 4 |] in
  let want_isr = [| 0; 0xF000_0000; 0xF000_0000; 0xFF00_0000; 0 |] in
  let want_cnt = [| 0; 4; 4; 8; 0 |] in
  let want_empty = [| 1; 1; 1; 1; 0 |] in
  run tb 5
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 4
      then (
        set tb "rxf_pop" 1;
        set tb "rxf_sm" 0))
    ~check:(fun c () ->
      check_arr "iffull pc" tb ~name:"dbg_pc0" ~mask:31 want_pc c;
      check_arr "iffull isr" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF want_isr c;
      check_arr "iffull isr count" tb ~name:"dbg_cnt0" ~mask:63 want_cnt c;
      check_arr "iffull RXEMPTY" tb ~name:"fstat" ~mask:0x100 (Array.map (fun e -> e * 0x100) want_empty) c;
      if c = 4 then expect "iffull popped word" ~cyc:c (get tb "rxf_data") 0xFF00_0000)
    ()
;;

(* PUSH noblock into a full RX FIFO (datasheet 3.4.6.2, R7). IN PINS,1 with pin 0 high
   gives ISR 0x80000000 in one bit, and PUSH noblock pushes it each time. Pushes at c1, c3,
   c5, c7 fill RX. The push at c9 is into a full FIFO: the data is dropped, RXSTALL is set,
   and ISR is cleared. The program wraps between 0 and 1. *)
let push_noblock () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x4001 (* IN PINS,1 *);
  load_imem tb 1 0x8000 (* PUSH noblock *);
  set tb "pins_in" 1;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:0x0000_1000 (* wrap top 1, bottom 0 *)
    ~shiftctrl:shiftctrl_default ~pinctrl_v:(pinctrl ());
  let want_pc = Array.init 11 (fun c -> c land 1) in
  let want_rx = [| 0; 0; 1; 1; 2; 2; 3; 3; 4; 4; 4 |] in
  let want_rxstall = Array.init 11 (fun c -> if c >= 10 then 1 else 0) in
  let want_isr = Array.init 11 (fun c -> if c land 1 = 1 && c <= 9 then 0x8000_0000 else 0) in
  run tb 11
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 1)
    ~check:(fun c () ->
      check_arr "noblock pc" tb ~name:"dbg_pc0" ~mask:31 want_pc c;
      check_arr "noblock rx level" tb ~name:"flevel" ~mask:0xF0 (Array.map (fun l -> l lsl 4) want_rx) c;
      check_arr "noblock RXSTALL" tb ~name:"fdebug" ~mask:1 want_rxstall c;
      check_arr "noblock isr" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF want_isr c)
    ()
;;

(* SM_RESTART (H3). IMEM: SET X,7; IN PINS,4 (pins 0xF); JMP 2. Restart in c5 clears ISR
   and its count; PC and X keep their values, and the OSR count is back at 32. *)
let sm_restart () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0xE027 (* SET X,7 *);
  load_imem tb 1 0x4004 (* IN PINS,4 *);
  load_imem tb 2 0x0002 (* JMP 2 *);
  set tb "pins_in" 0xF;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default
    ~shiftctrl:shiftctrl_default ~pinctrl_v:(pinctrl ());
  let want_pc = [| 0; 1; 2; 2; 2; 2; 2 |] in
  let want_isr = [| 0; 0; 0xF000_0000; 0xF000_0000; 0xF000_0000; 0xF000_0000; 0 |] in
  let want_cnt = [| 0; 0; 4; 4; 4; 4; 0 |] in
  let want_x = [| 0; 7; 7; 7; 7; 7; 7 |] in
  run tb 7
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 5 then set tb "sm_restart" 1)
    ~check:(fun c () ->
      check_arr "restart pc" tb ~name:"dbg_pc0" ~mask:31 want_pc c;
      check_arr "restart isr" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF want_isr c;
      check_arr "restart isr count" tb ~name:"dbg_cnt0" ~mask:63 want_cnt c;
      check_arr "restart X" tb ~name:"dbg_x0" ~mask:0xFFFFFFFF want_x c;
      check_arr "restart osr count" tb ~name:"dbg_cnt0" ~mask:0x3F00 (Array.make 7 0x2000) c)
    ()
;;

(* Shifting left (IN_SHIFTDIR and OUT_SHIFTDIR 0). IN part: pins 0x5, IN PINS,4 twice:
   ISR 0x5 then 0x55. OUT part: PULL 0x12345678, OUT X,8 twice. The OUT takes the top 8
   bits, so X becomes 0x12 then 0x34, and OSR shifts left, count 8 then 16. *)
let shift_left () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x4004;
  load_imem tb 1 0x4004;
  load_imem tb 2 0x0002;
  set tb "pins_in" 0x5;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:0
    ~pinctrl_v:(pinctrl ());
  run tb 4
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 1)
    ~check:(fun c () ->
      check_arr "shl isr" tb ~name:"dbg_isr0" ~mask:0xFFFFFFFF [| 0; 5; 0x55; 0x55 |] c;
      check_arr "shl isr count" tb ~name:"dbg_cnt0" ~mask:63 [| 0; 4; 8; 8 |] c)
    ()
;;

let out_shift_left () =
  let tb = make ~num_sms:1 in
  List.iteri (fun a w -> load_imem tb a w)
    [ 0x80A0 (* PULL block *); 0x6028 (* OUT X,8 *); 0x6028; 0x0003 (* JMP 3 *) ];
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:0
    ~pinctrl_v:(pinctrl ());
  run tb 5
    ~f:(fun c () ->
      if c = 0
      then (
        set tb "sm_enable" 1;
        set tb "txf_push" 1;
        set tb "txf_data" 0x1234_5678))
    ~check:(fun c () ->
      check_arr "oshl pc" tb ~name:"dbg_pc0" ~mask:31 [| 0; 0; 1; 2; 3 |] c;
      check_arr "oshl X" tb ~name:"dbg_x0" ~mask:0xFFFFFFFF [| 0; 0; 0; 0x12; 0x34 |] c;
      check_arr "oshl OSR" tb ~name:"dbg_osr0" ~mask:0xFFFFFFFF
        [| 0; 0; 0x1234_5678; 0x3456_7800; 0x5678_0000 |] c;
      check_arr "oshl OSR count" tb ~name:"dbg_cnt0" ~mask:0x3F00
        (Array.map (fun n -> n lsl 8) [| 32; 32; 0; 8; 16 |]) c)
    ()
;;

(* Pin priority (R2): both engines write pin 0 level in c0. SM0 sets 1, SM1 (higher) sets
   0. The pin reads 0 from c1 on and stays there. *)
let pin_priority () =
  let tb = make ~num_sms:2 in
  load_imem tb 0 0xE001 (* SET PINS,1 *);
  load_imem tb 1 0x0001;
  load_imem tb 8 0xE000 (* SET PINS,0 *);
  load_imem tb 9 0x0009;
  cfg_all tb ~sms:[ 0; 1 ] ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  force_jmp tb ~sm:1 ~addr:8;
  run tb 4
    ~f:(fun c () -> if c = 0 then set tb "sm_enable" 3)
    ~check:(fun c () -> check_arr "priority pins_out" tb ~name:"pins_out" ~mask:1 [| 0; 0; 0; 0 |] c)
    ()
;;

(* F6 (engine.md). Side-set on pin 5 (SIDESET_COUNT 1 at base 5). IMEM 0: PULL block side 1
   (stalls, TX empty). IMEM 5: SET PINS,1 side 0. In c2 the host forces JMP 5 with side 1
   (0x1005). The forced JMP runs in c3 and abandons the PULL: its stall reason and side-set
   flag are cleared at the end of c3. So IMEM 5 side-sets pin 5 to 0 in c4, which
   it would not do if the old flag were still set. *)
let f6_abandon () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x90A0 (* PULL block side 1 *);
  load_imem tb 5 0xE001 (* SET PINS,1 side 0 *);
  load_imem tb 6 0x0006 (* JMP 6 *);
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ~sideset_count:1 ~sideset_base:5 ());
  let want_pc = [| 0; 0; 0; 0; 5; 6; 6 |] in
  let want_stall = [| 0; 1; 1; 1; 0; 0; 0 |] in
  let want_p5 = [| 0; 1; 1; 1; 1; 0; 0 |] in
  let want_p0 = [| 0; 0; 0; 0; 0; 1; 1 |] in
  run tb 7
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 2
      then (
        set tb "instr_write" 1;
        set tb "instr_sm" 0;
        set tb "instr_data" 0x1005))
    ~check:(fun c () ->
      check_arr "f6 pc" tb ~name:"dbg_pc0" ~mask:31 want_pc c;
      check_arr "f6 stall reason" tb ~name:"dbg_cnt0" ~mask:0x0F00_0000
        (Array.map (fun r -> r lsl 24) want_stall) c;
      check_arr "f6 pin5" tb ~name:"pins_out" ~mask:0x20 (Array.map (fun b -> b * 0x20) want_p5) c;
      check_arr "f6 pin0" tb ~name:"pins_out" ~mask:1 want_p0 c)
    ()
;;

(* PULL under autopull (R4, changed). OSR count 32 at reset. PULL loads W1 (count 0). OUT
   X,8 shifts it to count 8. The next PULL: count is not 0, so it is not a no-op: it loads
   W2 at once. Under the old rule it would have been a no-op and OUT would have read W1. *)
let pull_r4 () =
  let tb = make ~num_sms:1 in
  List.iteri (fun a w -> load_imem tb a w)
    [ 0x80A0 (* PULL block *); 0x6028 (* OUT X,8 *); 0x80A0; 0x6028; 0x0004 (* JMP 4 *) ];
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default
    ~shiftctrl:(shiftctrl_default lor (1 lsl 17)) ~pinctrl_v:(pinctrl ());
  run tb 6
    ~f:(fun c () ->
      if c = 0
      then (
        set tb "sm_enable" 1;
        set tb "txf_push" 1;
        set tb "txf_data" 0x1111_1111)
      else if c = 1
      then (
        set tb "txf_push" 1;
        set tb "txf_data" 0x2222_2222))
    ~check:(fun c () ->
      check_arr "r4 pc" tb ~name:"dbg_pc0" ~mask:31 [| 0; 0; 1; 2; 3; 4 |] c;
      check_arr "r4 X" tb ~name:"dbg_x0" ~mask:0xFFFFFFFF [| 0; 0; 0; 0x11; 0x11; 0x22 |] c;
      check_arr "r4 OSR" tb ~name:"dbg_osr0" ~mask:0xFFFFFFFF
        [| 0; 0; 0x1111_1111; 0x0011_1111; 0x2222_2222; 0x0022_2222 |] c;
      check_arr "r4 OSR count" tb ~name:"dbg_cnt0" ~mask:0x3F00
        (Array.map (fun n -> n lsl 8) [| 32; 32; 0; 8; 0; 8 |]) c)
    ()
;;

(* Absent engines (num_sms 1): host operations aimed at engines 1 to 3 do nothing, and
   every bit that belongs to them reads 0 (engine.md section 3, clarification). *)
let absent_engines () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x0000;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  let dbg =
    List.concat_map
      (fun k ->
        List.map
          (fun p -> Printf.sprintf "%s%d" p k)
          [ "dbg_pc"; "dbg_x"; "dbg_y"; "dbg_isr"; "dbg_osr"; "dbg_cnt"; "dbg_exec_stalled"; "dbg_phase" ])
      [ 1; 2; 3 ]
  in
  run tb 4
    ~f:(fun c () ->
      set tb "sm_enable" 1;
      if c = 0
      then (
        set tb "txf_push" 1;
        set tb "txf_sm" 1;
        set tb "txf_data" 0x1234);
      if c = 1
      then (
        set tb "instr_write" 1;
        set tb "instr_sm" 2;
        set tb "instr_data" 0xE001);
      if c = 2
      then (
        set tb "rxf_pop" 1;
        set tb "rxf_sm" 3))
    ~check:(fun c () ->
      expect "absent fstat" ~cyc:c (get tb "fstat" land 0x0E0E_0E0E) 0;
      expect "absent flevel" ~cyc:c (get tb "flevel" land 0xFFFF_FF00) 0;
      expect "absent fdebug" ~cyc:c (get tb "fdebug" land 0xEE0E_0E0E) 0;
      if c = 2 then expect "absent rxf_data" ~cyc:c (get tb "rxf_data") 0;
      List.iter (fun n -> expect ("absent " ^ n) ~cyc:c (get tb n) 0) dbg)
    ()
;;

(* ---------- 12. Round 3: ports for every num_sms, R11, restart, flush, H7, two engines ---------- *)

(* engine.md section 3: every port exists for num_sms 1 to 4. Expected names and widths. *)
let section3_inputs =
  [ "clock", 1; "rst_n", 1; "sm_enable", 4 ]
  @ List.concat_map (fun p -> List.init 4 (fun k -> Printf.sprintf "%s%d" p k, 32))
      [ "clkdiv"; "execctrl"; "shiftctrl"; "pinctrl" ]
  @ [ "sync_bypass", 32; "pins_in", 32; "sm_restart", 4; "clkdiv_restart", 4; "fifo_flush", 4
    ; "irq_clear", 8; "irq_force", 8; "fdebug_clear", 32; "txf_push", 1; "txf_sm", 2
    ; "txf_data", 32; "rxf_pop", 1; "rxf_sm", 2; "instr_write", 1; "instr_sm", 2
    ; "instr_data", 16; "imem_write", 1; "imem_addr", 5; "imem_data", 16 ]
;;

let section3_outputs =
  [ "pins_out", 32; "pins_oe", 32; "irq", 8; "rxf_data", 32; "fstat", 32; "flevel", 32
  ; "fdebug", 32 ]
  @ List.init 4 (fun k -> Printf.sprintf "dbg_pc%d" k, 5)
  @ List.concat_map (fun p -> List.init 4 (fun k -> Printf.sprintf "%s%d" p k, 32))
      [ "dbg_x"; "dbg_y"; "dbg_isr"; "dbg_osr"; "dbg_cnt" ]
  @ List.init 4 (fun k -> Printf.sprintf "dbg_exec_stalled%d" k, 1)
  @ List.init 4 (fun k -> Printf.sprintf "dbg_phase%d" k, 25)
;;

let port_check () =
  for n = 1 to 4 do
    let sim = Cyclesim.create (Polyglot_hw.Pio_block.circuit ~num_sms:n) in
    let widths ports = List.map (fun (name, r) -> name, Bits.width !r) ports in
    let ins = widths (Cyclesim.in_ports sim) in
    let outs = widths (Cyclesim.out_ports sim) in
    let check what want got =
      let missing = List.filter (fun p -> not (List.mem p got)) want in
      let extra = List.filter (fun p -> not (List.mem p want)) got in
      List.iter (fun (name, w) -> Printf.printf "  num_sms=%d %s missing %s[%d]\n%!" n what name w) missing;
      List.iter (fun (name, w) -> Printf.printf "  num_sms=%d %s extra %s[%d]\n%!" n what name w) extra;
      expect (Printf.sprintf "num_sms=%d %s port list" n what) ~cyc:0
        (List.length missing + List.length extra) 0
    in
    check "input" section3_inputs ins;
    check "output" section3_outputs outs
  done
;;

(* R11 (round 3): the IMEM WAIT and the latched instruction each keep their own side-set
   flag. Side-set on pin 5. Pin 1 low, so the WAIT GPIO 1 stalls. pins_in is 0xE001.
     c0 IMEM WAIT 1 GPIO 1, side 1: side-set applies once (pin 5 = 1 from c1); stalls.
     c2 host forces MOV EXEC,PINS with side 1 (0xB080). It runs in c3, side 1 (pin 5 stays 1),
        and latches the low 16 bits of PINS (0xE001) as an EXEC instruction.
     c4 EXEC SET PINS,1 side 0 runs: its own side-set applies on its first attempt, so pin 5
        goes to 0 (from c5), and pin 0 goes to 1.
     c5 the IMEM WAIT retries: its flag is still set, so no side-set. Pin 5 stays 0. *)
let r11_latch_flag () =
  let tb = make ~num_sms:1 in
  load_imem tb 0 0x3081 (* WAIT 1 GPIO 1, side 1 *);
  set tb "pins_in" 0xE001;
  set tb "sync_bypass" 0xFFFF_FFFF;
  preload tb;
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ~sideset_count:1 ~sideset_base:5 ());
  run tb 7
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 2
      then (
        set tb "instr_write" 1;
        set tb "instr_sm" 0;
        set tb "instr_data" 0xB080))
    ~check:(fun c () ->
      check_arr "r11 pin5" tb ~name:"pins_out" ~mask:0x20
        (Array.map (fun b -> b * 0x20) [| 0; 1; 1; 1; 1; 0; 0 |]) c;
      check_arr "r11 pin0" tb ~name:"pins_out" ~mask:1 [| 0; 0; 0; 0; 0; 1; 1 |] c;
      check_arr "r11 pc" tb ~name:"dbg_pc0" ~mask:31 (Array.make 7 0) c)
    ()
;;

(* Restart (H3) clears the OUT_STICKY record and both stall reasons. SM1 (higher) runs
   SET PINS,1 then WAIT 1 GPIO 1 (stalls), with sticky on. SM0 runs SET PINS,0 and is
   enabled only in c6. Restart of SM1 in c4 clears its record, so SM0's write in c6 wins
   (c7 pin 0 = 0). Without the restart SM1 would re-assert pin 0 = 1 and win.
   SM1 stall reason 4 is visible c2..c4 and c6 onward, and 0 in c5 (the restart cleared
   it, and the retry in c5 shows from c6). *)
let restart_clears_sticky () =
  let tb = make ~num_sms:2 in
  load_imem tb 0 0xE000 (* SET PINS,0 *);
  load_imem tb 1 0x0001 (* JMP 1 *);
  load_imem tb 8 0xE001 (* SET PINS,1 *);
  load_imem tb 9 0x2081 (* WAIT 1 GPIO 1 *);
  cfg_all tb ~sms:[ 0 ] ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  configure tb ~sm:1 ~clkdiv:clkdiv_1 ~execctrl:(execctrl_default lor (1 lsl 17))
    ~shiftctrl:shiftctrl_default ~pinctrl_v:(pinctrl ());
  force_jmp tb ~sm:1 ~addr:8;
  run tb 9
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 2;
      if c = 4 then set tb "sm_restart" 2;
      if c = 6 then set tb "sm_enable" 3)
    ~check:(fun c () ->
      check_arr "restart pin0" tb ~name:"pins_out" ~mask:1 [| 0; 1; 1; 1; 1; 1; 1; 0; 0 |] c;
      check_arr "restart pc1" tb ~name:"dbg_pc1" ~mask:31 [| 8; 9; 9; 9; 9; 9; 9; 9; 9 |] c;
      check_arr "restart stall reason" tb ~name:"dbg_cnt1" ~mask:0x0F00_0000
        (Array.map (fun r -> r lsl 24) [| 0; 0; 4; 4; 4; 0; 4; 4; 4 |]) c)
    ()
;;

(* Flush in the same cycle as a push (H6, H1). Non-joined TX, 4 words. Case A: the FIFO is
   full, and in c4 the host pushes and flushes together. The push is dropped (TXOVER, from
   H1), and the flush empties the FIFO. Case B: 2 words, and the push-with-flush in c2 is
   dropped by the flush, with no TXOVER. *)
let flush_with_push () =
  let tb = make ~num_sms:1 in
  run tb 6
    ~f:(fun c () ->
      if c < 4 || c = 4
      then (
        set tb "txf_push" 1;
        set tb "txf_data" (c + 1));
      if c = 4 then set tb "fifo_flush" 1)
    ~check:(fun c () ->
      if c = 5
      then (
        expect "flush A level" ~cyc:c (get tb "flevel" land 0xF) 0;
        expect "flush A fstat" ~cyc:c (get tb "fstat") 0x0100_0100;
        expect "flush A TXOVER" ~cyc:c (get tb "fdebug") 0x0001_0000))
    ();
  let tb = make ~num_sms:1 in
  run tb 4
    ~f:(fun c () ->
      if c < 2 || c = 2
      then (
        set tb "txf_push" 1;
        set tb "txf_data" (c + 1));
      if c = 2 then set tb "fifo_flush" 1)
    ~check:(fun c () ->
      if c = 3
      then (
        expect "flush B level" ~cyc:c (get tb "flevel" land 0xF) 0;
        expect "flush B fstat" ~cyc:c (get tb "fstat") 0x0100_0100;
        expect "flush B TXOVER" ~cyc:c (get tb "fdebug") 0))
    ()
;;

(* H7: a forced PULL stalls on empty TX and retries. In c4 a new INSTR write arrives. The
   retry in c4 still runs (it stalls again), and the new SET PINS,1 replaces the latch at the
   end of c4, so it runs in c5 and pin 0 is 1 from c6. exec_stalled and the latch stall reason
   are 1 from c2 to c4, and 0 from c5 (the new write clears them). *)
let h7_replace_latch () =
  let tb = make ~num_sms:1 in
  configure tb ~sm:0 ~clkdiv:clkdiv_1 ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  run tb 8
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 1;
      if c = 0 then (set tb "instr_write" 1; set tb "instr_data" 0x80A0);
      if c = 4 then (set tb "instr_write" 1; set tb "instr_data" 0xE001))
    ~check:(fun c () ->
      check_arr "h7 exec_stalled" tb ~name:"dbg_exec_stalled0" ~mask:1 [| 0; 0; 1; 1; 1; 0; 0; 0 |] c;
      check_arr "h7 latch stall" tb ~name:"dbg_cnt0" ~mask:0x0F00_0000
        (Array.map (fun r -> r lsl 24) [| 0; 0; 1; 1; 1; 0; 0; 0 |]) c;
      check_arr "h7 pin0" tb ~name:"pins_out" ~mask:1 [| 0; 0; 0; 0; 0; 0; 1; 1 |] c;
      check_arr "h7 pc" tb ~name:"dbg_pc0" ~mask:31 (Array.make 8 0) c)
    ()
;;

(* num_sms 2 with SM1 enabled. SM1 runs IRQ set 2 (0xC002) and loops. Two words are pushed
   to its TX. Its IRQ flag 2 (0x4) shows from c1. Its FIFO bits: TX level 1 then 2 (FLEVEL
   bits 11:8), TXEMPTY clear (bit 25), RXEMPTY set (bit 9). SM0's bits stay empty. *)
let two_engines_sm1 () =
  let tb = make ~num_sms:2 in
  load_imem tb 8 0xC002 (* IRQ set 2 *);
  load_imem tb 9 0x0009 (* JMP 9 *);
  cfg_all tb ~sms:[ 0; 1 ] ~execctrl:execctrl_default ~shiftctrl:shiftctrl_default
    ~pinctrl_v:(pinctrl ());
  force_jmp tb ~sm:1 ~addr:8;
  run tb 3
    ~f:(fun c () ->
      if c = 0 then set tb "sm_enable" 2;
      if c < 2
      then (
        set tb "txf_push" 1;
        set tb "txf_sm" 1;
        set tb "txf_data" (0x11 * (c + 1))))
    ~check:(fun c () ->
      check_arr "two irq" tb ~name:"irq" ~mask:0xFF [| 0; 4; 4 |] c;
      check_arr "two pc1" tb ~name:"dbg_pc1" ~mask:31 [| 8; 9; 9 |] c;
      check_arr "two fstat" tb ~name:"fstat" ~mask:0xFFFF_FFFF [| 0x0300_0300; 0x0100_0300; 0x0100_0300 |] c;
      check_arr "two flevel" tb ~name:"flevel" ~mask:0xFFFF_FFFF [| 0; 0x100; 0x200 |] c)
    ()
;;

let () =
  port_check ();
  r11_latch_flag ();
  restart_clears_sticky ();
  flush_with_push ();
  h7_replace_latch ();
  two_engines_sm1 ();
  decoder_exhaustive ();
  set_pins_loop ();
  side_set_stall ();
  wait_pin ~bypass:true;
  wait_pin ~bypass:false;
  irq_between_engines ();
  forced_while_disabled ();
  out_exec ();
  clock_divider ();
  fifo_status ();
  autopull_out ();
  irq_rel ();
  sticky_one_record ();
  mov_ops ();
  in_autopush_stall ();
  push_iffull ();
  push_noblock ();
  sm_restart ();
  shift_left ();
  out_shift_left ();
  pin_priority ();
  f6_abandon ();
  pull_r4 ();
  absent_engines ();
  Printf.printf "smoke: %d checks, %d failures\n%!" !checks !failures;
  if !failures > 0 then exit 1
;;
