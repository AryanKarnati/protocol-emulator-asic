(* Tests for pgsim. Expectations are hand-derived from the RP2040 datasheet section 3
   (cited in each test), not from the model's own output.
   Run with: opam exec --switch=polyglot -- dune test --root . *)

module Isa = Polyglot_isa.Isa
module C = Pgsim.Config

let enc = Isa.encode

let set_pins ?(delay = 0) ?(side = None) d =
  let ds = match side with None -> delay | Some s -> (s lsl 4) lor delay in
  enc (Isa.Set { delay_side = ds; dest = Set_pins; data = d })
;;

let set_pindirs d = enc (Isa.Set { delay_side = 0; dest = Set_pindirs; data = d })
let set_x d = enc (Isa.Set { delay_side = 0; dest = Set_x; data = d })
let jmp ?(cond = Isa.Always) addr = enc (Isa.Jmp { delay_side = 0; cond; addr })
let out ?(delay_side = 0) dest n = enc (Isa.Out { delay_side; dest; bit_count = n })
let in_ ?(delay_side = 0) src n = enc (Isa.In { delay_side; source = src; bit_count = n })

let pull ?(delay_side = 0) ?(if_empty = false) ?(block = true) () =
  enc (Isa.Pull { delay_side; if_empty; block })
;;

let push ?(delay_side = 0) ?(if_full = false) ?(block = true) () =
  enc (Isa.Push { delay_side; if_full; block })
;;

let mov ?(delay_side = 0) ?(op = Isa.Op_none) dest source =
  enc (Isa.Mov { delay_side; dest; op; source })
;;

let irq ?(delay_side = 0) ?(clear = false) ?(wait = false) ?(rel = false) index =
  enc (Isa.Irq { delay_side; clear; wait; index; rel })
;;

let check name cond = if not cond then failwith ("FAILED: " ^ name)

(* A machine with [words] in instruction memory, SM [i] configured by [cfg], enabled. *)
let make ?(i = 0) ?(cfg = C.reset) words =
  let t = Pgsim.create () in
  Pgsim.load_program t words;
  Pgsim.set_config t i cfg;
  Pgsim.set_enabled t i true;
  t
;;

let run t n =
  for _ = 1 to n do
    ignore (Pgsim.step t)
  done
;;

(* Pad level of pin 0 for [n] cycles (each cycle is one step). *)
let pin0 t n = List.init n (fun _ -> Pgsim.step t land 1)

let dbg t i = Pgsim.debug t i

(* ------------------------------------------------------------------------------------ *)
(* Registers: datasheet 3.7 reset values and round trip *)

let%expect_test "reset register values (datasheet 3.7)" =
  check "clkdiv reset" (C.clkdiv_register C.reset = 0x0001_0000);
  check "execctrl reset" (C.execctrl_register C.reset = 0x0001_F000);
  check "shiftctrl reset" (C.shiftctrl_register C.reset = 0x000C_0000);
  check "pinctrl reset" (C.pinctrl_register C.reset = 0x1400_0000)
;;

let%expect_test "register round trip for a non-trivial configuration" =
  let c =
    C.of_registers
      ~clkdiv:0x0002_8000
      ~execctrl:0x4000_3000
      ~shiftctrl:0x400C_0000
      ~pinctrl:0x5410_0000
  in
  check "clkdiv int" (c.C.clkdiv_int = 2);
  check "clkdiv frac" (c.C.clkdiv_frac = 0x80);
  check "side_en" c.C.side_en;
  check "wrap top" (c.C.wrap_top = 3);
  check "fjoin_tx" c.C.fjoin_tx;
  check "sideset count" (c.C.sideset_count = 2);
  check "out count" (c.C.out_count = 1);
  check "clkdiv re-encode" (C.clkdiv_register c = 0x0002_8000);
  check "pinctrl re-encode" (C.pinctrl_register c = 0x5410_0000)
;;

(* ------------------------------------------------------------------------------------ *)
(* Waveforms derived from the datasheet *)

(* 3.2.2: squarewave. set pindirs,1; again: set pins,1 [1]; set pins,0; jmp again.
   Four cycles per period, 50% duty. A write made in cycle c is on the pad in cycle c+1,
   so the pad is 0 0 1 1 0 0 1 1 ... from cycle 0. *)
let%expect_test "squarewave: period 4, 50% duty (datasheet 3.2.2)" =
  let cfg = { C.reset with set_count = 1 } in
  let t = make ~cfg [ set_pindirs 1; set_pins ~delay:1 1; set_pins 0; jmp 1 ] in
  let w = pin0 t 12 in
  check "squarewave" (w = [ 0; 0; 1; 1; 0; 0; 1; 1; 0; 0; 1; 1 ])
;;

(* 3.6.3: UART TX from the corpus program uart_tx.pio (8n1, LSB first, clkdiv 1). Timing
   from the instruction delays: the pull idles high at cycles 1..8, start bit low at 9..16,
   data bit k at 17+8k..24+8k, and the stop bit is high from 81 while the TX FIFO is
   empty. Byte 0xA5 = 1010_0101, sent LSB first: 1,0,1,0,0,1,0,1. *)
let%expect_test "uart_tx sends 0xA5 with the hand-derived pin timing (datasheet 3.6.3)" =
  let prog =
    Pioasm_json.load "../../pgasm/test/corpus/pico-examples/pio/uart_tx/uart_tx.pio.json"
  in
  let cfg =
    C.of_registers
      ~clkdiv:0x0001_0000
      ~execctrl:0x4000_3000
      ~shiftctrl:0x400C_0000
      ~pinctrl:0x5410_0000
  in
  let t = Pgsim.create () in
  Pgsim.load_program t prog.Pioasm_json.words;
  Pgsim.set_config t 0 cfg;
  Pgsim.write_tx t 0 0xA5;
  (* The host makes pin 0 an output (SDK pio_sm_set_pindirs): set pindirs, 1. *)
  Pgsim.write_instr t 0 (set_pindirs 1);
  ignore (Pgsim.step t);
  Pgsim.set_enabled t 0 true;
  (* Cycle 0 of the frame is the first step after enable. *)
  let w = Array.of_list (pin0 t 100) in
  for c = 1 to 8 do
    check (Printf.sprintf "idle high at %d" c) (w.(c) = 1)
  done;
  for c = 9 to 16 do
    check (Printf.sprintf "start bit at %d" c) (w.(c) = 0)
  done;
  List.iteri
    (fun k b ->
      for c = 17 + (8 * k) to 24 + (8 * k) do
        check (Printf.sprintf "data bit %d at %d" k c) (w.(c) = b)
      done)
    [ 1; 0; 1; 0; 0; 1; 0; 1 ];
  for c = 81 to 99 do
    check (Printf.sprintf "stop bit at %d" c) (w.(c) = 1)
  done
;;

(* ------------------------------------------------------------------------------------ *)
(* Delay and stalls (3.2.2, 3.2.4) *)

(* 3.2.2: a delay of d adds d idle cycles after the instruction, so [set pins,1 [3]]
   followed by [set pins,0] keeps the pin high for 4 cycles. *)
let%expect_test "delay counts only after completion (datasheet 3.2.2)" =
  let t = make [ set_pindirs 1; set_pins ~delay:3 1; set_pins 0 ] in
  let w = pin0 t 7 in
  check "delay holds high" (w = [ 0; 0; 1; 1; 1; 1; 0 ])
;;

(* 3.2.4: a blocking PULL with an empty TX FIFO stalls, PC holds, and the delay does not
   start until the instruction completes. *)
let%expect_test "blocking PULL stalls on empty TX; delay starts after completion (3.2.4)" =
  let t = make [ pull (); set_pins ~delay:2 1; set_pins 0 ] in
  run t 5;
  let d = dbg t 0 in
  check "stalled on tx" (d.Pgsim.stall = Pgsim.Stall_tx_empty);
  check "pc held at pull" (d.Pgsim.pc = 0);
  check "tx stall flag set" t.Pgsim.sms.(0).Pgsim.txstall;
  check "no delay while stalled" (d.Pgsim.delay = 0);
  Pgsim.write_tx t 0 0x1;
  run t 1;
  check "pull completed" ((dbg t 0).Pgsim.pc = 1);
  (* The pull has no delay of its own. The delay of set pins,1 [2] starts after it runs. *)
  check "no delay after pull" ((dbg t 0).Pgsim.delay = 0);
  run t 1;
  check "set pins ran" ((dbg t 0).Pgsim.pc = 2 && t.Pgsim.pin_level land 1 = 1);
  check "its delay 2 now runs" ((dbg t 0).Pgsim.delay = 2)
;;

(* 3.2.4 and 3.5.1: side-set takes effect on the first tick of the instruction, even when
   the instruction stalls. Here side-set is one bit with no enable, so bit 4 of the
   delay/side-set field is the side value. *)
let%expect_test "side-set applies on the first tick even if the instruction stalls" =
  let cfg = { C.reset with sideset_count = 1; side_en = false; sideset_base = 0 } in
  let t = make ~cfg [ pull ~delay_side:0x10 () ] in
  run t 1;
  check "level written while stalled" (t.Pgsim.pin_level land 1 = 1);
  check "still stalled" ((dbg t 0).Pgsim.stall = Pgsim.Stall_tx_empty)
;;

(* ------------------------------------------------------------------------------------ *)
(* Shifting, thresholds, autopush and autopull (3.4.4, 3.4.5, 3.5.4) *)

(* 3.4.4.2: IN shifts right with autopush at 8 bits. One [in x, 8] with X=0xA5 pushes
   0xA5000000 (the data enters at the top of the ISR). *)
let%expect_test "IN with autopush at 8 bits pushes 0xA5000000 (datasheet 3.4.4.2)" =
  let cfg = { C.reset with autopush = true; push_thresh = 8; in_right = true } in
  let t = make ~cfg [ in_ In_x 8 ] in
  t.Pgsim.sms.(0).Pgsim.x <- 0xA5;
  run t 1;
  check "rx has one word" ((dbg t 0).Pgsim.rx_level = 1);
  match Pgsim.read_rx t 0 with
  | Some w -> check (Printf.sprintf "rx word %08x" w) (w = 0xA5000000)
  | None -> failwith "no word in RX"
;;

(* 3.5.4.2: with autopull at threshold 8, an OUT with the OSR already at threshold pulls
   from TX and stalls for that cycle. The next OUT then shifts 8 bits, and when the OSR
   reaches the threshold again with TX empty, the next OUT stalls. *)
let%expect_test "autopull: refill stalls once, then OUT stalls when TX runs dry (3.5.4.2)" =
  let cfg =
    { C.reset with autopull = true; pull_thresh = 8; out_right = true }
  in
  let t = make ~cfg [ out Out_null 8; out Out_null 8 ] in
  Pgsim.write_tx t 0 0x1234;
  (* OSR counter starts at 32 (datasheet 3.2.3.3), i.e. at threshold: pull, then stall. *)
  run t 1;
  let d = dbg t 0 in
  check "refill stall" (d.Pgsim.stall = Pgsim.Stall_autopull);
  check "osr loaded" (d.Pgsim.osr = 0x1234);
  check "osr count reset" (d.Pgsim.osr_count = 0);
  (* First OUT shifts 8 bits; count reaches the threshold with TX empty: no refill. *)
  run t 1;
  let d = dbg t 0 in
  check "after first out" (d.Pgsim.pc = 1 && d.Pgsim.osr_count = 8);
  run t 1;
  check "second OUT stalls" ((dbg t 0).Pgsim.stall = Pgsim.Stall_autopull)
;;

(* ------------------------------------------------------------------------------------ *)
(* Wrap (3.5.2) *)

(* 3.5.2: with WRAP_TOP=2 and WRAP_BOTTOM=1, the PC wraps from 2 to 1 with no jump. Start
   at 0 (set pindirs), then 1 (set pins,1) and 2 (set pins,0) repeat. *)
let%expect_test "wrap: the PC returns to WRAP_BOTTOM from WRAP_TOP (datasheet 3.5.2)" =
  let cfg = { C.reset with wrap_top = 2; wrap_bottom = 1; set_count = 1 } in
  let t = make ~cfg [ set_pindirs 1; set_pins 1; set_pins 0 ] in
  let w = pin0 t 9 in
  check "toggles every cycle after the first" (w = [ 0; 0; 1; 0; 1; 0; 1; 0; 1 ]);
  check "pc in wrap range" (let p = (dbg t 0).Pgsim.pc in p = 1 || p = 2)
;;

(* ------------------------------------------------------------------------------------ *)
(* FIFO join (3.5.3) *)

let%expect_test "FJOIN_TX gives an 8-deep TX FIFO and no RX FIFO (datasheet 3.5.3)" =
  let cfg = { C.reset with fjoin_tx = true } in
  let t = make ~cfg [ jmp 0 ] in
  Pgsim.set_enabled t 0 false;
  for i = 1 to 8 do
    Pgsim.write_tx t 0 i
  done;
  check "tx holds 8" ((dbg t 0).Pgsim.tx_level = 8);
  Pgsim.write_tx t 0 9;
  check "9th write overflows" t.Pgsim.sms.(0).Pgsim.txover;
  check "tx still 8" ((dbg t 0).Pgsim.tx_level = 8);
  check "rx depth 0" (Pgsim.Fifo.full t.Pgsim.sms.(0).Pgsim.rx && (dbg t 0).Pgsim.rx_level = 0)
;;

(* ------------------------------------------------------------------------------------ *)
(* Clock divider (3.5.5; same 16.8 rule as docs/gate.md) *)

(* 3.5.5: a divisor of 2.5 gives an average of 2.5 cycles per instruction. A two-instruction
   loop toggles the pin on every tick, so 2560 cycles contain 1024 ticks. *)
let%expect_test "clock divider 2.5: 1024 ticks in 2560 cycles (datasheet 3.5.5)" =
  let cfg =
    { C.reset with
      clkdiv_int = 2
    ; clkdiv_frac = 0x80
    ; set_count = 1
    ; wrap_top = 2
    ; wrap_bottom = 1
    }
  in
  let t = make ~cfg [ set_pindirs 1; set_pins 1; set_pins 0 ] in
  let w = pin0 t 2560 in
  let transitions = ref 0 in
  let prev = ref 0 in
  List.iter
    (fun b ->
      if b <> !prev then incr transitions;
      prev := b)
    w;
  (* 1024 ticks in total. One tick is the set pindirs (no transition), and the last
     tick's level is still in the pipeline at cycle 2559, so 1022..1024 transitions. *)
  check (Printf.sprintf "ticks %d" !transitions) (!transitions >= 1022 && !transitions <= 1024)
;;

(* ------------------------------------------------------------------------------------ *)
(* IRQ (3.4.9, 3.2.6) *)

(* 3.4.9.2: the rel bit adds the state machine number to the low two bits of the index.
   SM2 with index 1 and rel raises flag 3. *)
let%expect_test "IRQ rel index: SM2 with index 1 raises flag 3 (datasheet 3.4.9.2)" =
  let t = make ~i:2 [ irq ~rel:true 1; jmp 0 ] in
  run t 1;
  check (Printf.sprintf "irq flags %02x" t.Pgsim.irq) (t.Pgsim.irq = 0x08)
;;

(* 3.4.9.2: IRQ wait raises the flag and stalls until it is cleared. *)
let%expect_test "IRQ wait: stall until the host clears the flag, then continue (3.4.9.2)" =
  let t = make [ irq ~wait:true 2; set_pindirs 1; set_pins 1 ] in
  run t 4;
  check "flag raised" (t.Pgsim.irq land 4 = 4);
  check "stalled on irq" ((dbg t 0).Pgsim.stall = Pgsim.Stall_irq_wait);
  check "not past the wait" (t.Pgsim.pin_level land 1 = 0);
  Pgsim.clear_irq t 4;
  run t 3;
  check "continued after clear" (t.Pgsim.pin_level land 1 = 1)
;;

(* ------------------------------------------------------------------------------------ *)
(* Pin priority and side-set override (3.2.5, 3.5.6) *)

(* 3.2.5: when two SMs write the same pin in one cycle, the higher-numbered SM wins. *)
let%expect_test "highest-numbered SM wins a shared pin (datasheet 3.2.5)" =
  let t = Pgsim.create () in
  Pgsim.load_program t [ set_pins 1 ];
  Pgsim.set_config t 0 { C.reset with set_count = 1 };
  Pgsim.set_config t 1 { C.reset with set_count = 1 };
  Pgsim.load_program t [ set_pins 0 ];
  Pgsim.set_enabled t 0 true;
  Pgsim.set_enabled t 1 true;
  ignore (Pgsim.step t);
  check "SM1 wins" (t.Pgsim.pin_level land 1 = 0)
;;

(* 3.5.6: side-set overrides an OUT/SET on the same pin from the same SM. *)
let%expect_test "side-set overrides SET on the same pin in one SM (datasheet 3.5.6)" =
  let cfg = { C.reset with set_count = 1; sideset_count = 1; side_en = false; sideset_base = 0 } in
  let t = make ~cfg [ set_pins ~side:(Some 1) 0 ] in
  ignore (Pgsim.step t);
  check "side-set value wins" (t.Pgsim.pin_level land 1 = 1)
;;

(* ------------------------------------------------------------------------------------ *)
(* Reserved words, forced instructions, EXEC (3.4, 3.5.7, DESIGN.md 9.1) *)

(* mov dest 011 is reserved in version 0 (datasheet 3.4.8.2). *)
let%expect_test "reserved word runs as a NOP and sets ILLEGAL" =
  let t = make [ 0xA060; set_x 1 ] in
  run t 2;
  check "illegal flag" (dbg t 0).Pgsim.illegal;
  check "continued past the reserved word" ((dbg t 0).Pgsim.pc = 2)
;;

(* 3.5.7: an instruction written to SMx_INSTR runs at once, even when the SM is disabled
   and regardless of the clock divider. *)
let%expect_test "forced instruction runs at once, ignoring enable and divider (3.5.7)" =
  let t = make [ jmp 0 ] in
  Pgsim.set_enabled t 0 false;
  Pgsim.write_instr t 0 (set_pins 1);
  ignore (Pgsim.step t);
  check "forced set pins ran" (t.Pgsim.pin_level land 1 = 1)
;;

(* 3.5.7: OUT EXEC runs the low 16 bits of the shifted-out data on the next cycle, and the
   OUT's own delay is ignored. *)
let%expect_test "OUT EXEC runs the next cycle; OUT delay ignored (datasheet 3.5.7)" =
  let cfg = { C.reset with set_count = 1 } in
  let t = make ~cfg [ out ~delay_side:5 Out_exec 16; set_x 9 ] in
  t.Pgsim.sms.(0).Pgsim.osr <- set_pins 1;
  t.Pgsim.sms.(0).Pgsim.osr_count <- 0;
  ignore (Pgsim.step t);
  check "executee pending" (match t.Pgsim.sms.(0).Pgsim.latch with Pgsim.Exec_latch _ -> true | _ -> false);
  ignore (Pgsim.step t);
  check "executee ran on the next cycle" (t.Pgsim.pin_level land 1 = 1)
;;

(* 3.4.10: SET PINDIRS drives pin directions, separately from levels. *)
let%expect_test "set pindirs changes the direction but not the level (datasheet 3.4.10)" =
  let cfg = { C.reset with set_count = 1 } in
  let t = make ~cfg [ set_pindirs 1 ] in
  ignore (Pgsim.step t);
  check "direction set" (t.Pgsim.pin_dir land 1 = 1);
  check "level untouched" (t.Pgsim.pin_level land 1 = 0)
;;

(* ------------------------------------------------------------------------------------ *)
(* Not in block 1 *)

let%expect_test "LCU instructions are stubs that raise" =
  let t = make [ enc (Isa.Set { delay_side = 0; dest = Set_lcu; data = 0 }) ] in
  let raised =
    try
      ignore (Pgsim.step t);
      false
    with
    | Failure _ -> true
  in
  check "set lcu raises" raised
;;

let%expect_test "mov x, osr copies OSR and resets its counter (datasheet 3.4.8.2)" =
  let t = make [ mov Mov_x Ms_osr ] in
  t.Pgsim.sms.(0).Pgsim.osr <- 0xDEAD;
  t.Pgsim.sms.(0).Pgsim.osr_count <- 9;
  ignore (Pgsim.step t);
  check "x copied" (t.Pgsim.sms.(0).Pgsim.x = 0xDEAD)
;;

(* Keep the helpers used by every test. *)
let _ = (mov, in_, run)

(* ------------------------------------------------------------------------------------ *)
(* Silicon trace comparison (silicon-ref/README.md format) *)

(* Write a trace file in the documented format, with samples [samples] (one per cycle). *)
let write_silicon_trace ?(clkdiv = 0x0001_0000) ?(execctrl = 0x0001_F000)
    ?(words = [ 0xE081; 0xE101; 0xE000; 0x0001 ]) ?(init_dirs = []) path samples =
  let n = Array.length samples in
  let nwords = (n + 3) / 4 in
  let word w =
    let v = ref 0 in
    for k = 0 to 3 do
      let i = (4 * w) + k in
      let s = if i < n then samples.(i) else 0 in
      v := !v lor (s lsl (8 * k))
    done;
    Printf.sprintf "0x%08x" !v
  in
  let header =
    `Assoc
      [ "record", `String "header"
      ; "format", `String "polyglot-pio-silicon-trace"
      ; "version", `Int 1
      ; "sysclk_hz", `Int 150_000_000
      ; ( "capture"
        , `Assoc
            [ "sm", `Int 1
            ; "pins_base", `Int 0
            ; "pins_count", `Int 8
            ; "bits_per_sample", `Int 8
            ; "samples_per_word", `Int 4
            ] )
      ; ( "program"
        , `Assoc
            [ "name", `String "squarewave"
            ; "pio_version", `Int 0
            ; "entry", `Int 0
            ; ( "init"
              , `Assoc
                  [ "levels", `Assoc []
                  ; "dirs", `Assoc (List.map (fun p -> string_of_int p, `Int 1) init_dirs)
                  ; "tx_words", `List []
                  ] )
            ; "words", `List (List.map (fun w -> `String (Printf.sprintf "0x%04x" w)) words)
            ; ( "registers"
              , `Assoc
                  [ "clkdiv", `String (Printf.sprintf "0x%08x" clkdiv)
                  ; "execctrl", `String (Printf.sprintf "0x%08x" execctrl)
                  ; "shiftctrl", `String "0x000c0000"
                  ; "pinctrl", `String "0x04000000"
                  ] )
            ] )
      ]
  in
  let oc = open_out path in
  output_string oc (Yojson.Safe.to_string header ^ "\n");
  let words = List.init nwords (fun w -> `String (word w)) in
  output_string
    oc
    (Yojson.Safe.to_string (`Assoc [ "record", `String "words"; "first_word", `Int 0; "words", `List words ])
     ^ "\n");
  output_string
    oc
    (Yojson.Safe.to_string
       (`Assoc
           [ "record", `String "footer"
           ; "words_total", `Int nwords
           ; "samples_total", `Int (4 * nwords)
           ; "fdebug", `String "0x00000000"
           ; "rxstall_capture", `Bool false
           ; "complete", `Bool true
           ])
     ^ "\n");
  close_out oc
;;

(* Pad bit 0 of the squarewave model for [n] cycles: the "silicon" in these tests. *)
let squarewave_pads n =
  let cfg = { C.reset with set_count = 1 } in
  let t = make ~cfg [ set_pindirs 1; set_pins ~delay:1 1; set_pins 0; jmp 1 ] in
  Array.init n (fun _ -> Pgsim.step t)
;;

let%expect_test "trace_cmp: a trace equal to pgsim matches; latency aligns samples" =
  let n = 16 in
  let pads = squarewave_pads n in
  let s0 = Array.map (fun p -> p land 1) pads in
  write_silicon_trace "silicon_match.jsonl" s0;
  let r = Silicon_trace.compare_files ~latency:0 "silicon_match.jsonl" in
  check "no mismatch at latency 0" (r.Silicon_trace.first_mismatch = None);
  check "all samples compared" (r.Silicon_trace.compared = 16);
  (* The same pads delayed by 2 cycles match with latency 2 and not with 0. *)
  let delayed = Array.init n (fun k -> if k < 2 then 0 else s0.(k - 2)) in
  write_silicon_trace "silicon_delayed.jsonl" delayed;
  let r2 = Silicon_trace.compare_files ~latency:2 "silicon_delayed.jsonl" in
  check "latency 2 matches" (r2.Silicon_trace.first_mismatch = None);
  let r0 = Silicon_trace.compare_files ~latency:0 "silicon_delayed.jsonl" in
  check "latency 0 mismatches" (r0.Silicon_trace.first_mismatch <> None)
;;

let%expect_test "trace_cmp: first mismatch names the sample and pin" =
  let n = 16 in
  let s0 = Array.map (fun p -> p land 1) (squarewave_pads n) in
  let bad = Array.copy s0 in
  bad.(5) <- 1 - bad.(5);
  write_silicon_trace "silicon_bad.jsonl" bad;
  match (Silicon_trace.compare_files ~latency:0 "silicon_bad.jsonl").Silicon_trace.first_mismatch with
  | Some m ->
    check "sample index" (m.Silicon_trace.sample = 5);
    check "pin index" (m.Silicon_trace.pin = 0)
  | None -> failwith "expected a mismatch"
;;

(* 3.2.2 again, with the corpus program squarewave.pio.json, so the words are the pioasm
   output and not typed by hand. Same expected pad sequence as above. *)
let%expect_test "corpus squarewave.pio.json: period 4, 50% duty (datasheet 3.2.2)" =
  let prog =
    Pioasm_json.load "../../pgasm/test/corpus/pico-examples/pio/squarewave/squarewave.pio.json"
  in
  let t = Pgsim.create () in
  Pgsim.load_program t prog.Pioasm_json.words;
  Pgsim.set_config t 0 { C.reset with set_count = 1 };
  Pgsim.set_enabled t 0 true;
  let w = pin0 t 12 in
  check "squarewave from pioasm words" (w = [ 0; 0; 1; 1; 0; 0; 1; 1; 0; 0; 1; 1 ])
;;

(* ------------------------------------------------------------------------------------ *)
(* Silicon trace loader against the capture.py fixture (silicon-ref/testdata). The samples
   in the fixture are synthetic, so only the header, the init and the sample decoding are
   checked here, not a waveform match. *)

let fixture = "../../../silicon-ref/testdata/uart_tx_example.jsonl"

let%expect_test "loader: header fields, init applied, entry, sample count and values" =
  let l = Silicon_trace.load fixture in
  check "program name" (l.Silicon_trace.name = "uart_tx");
  check "entry is 0" (l.Silicon_trace.entry = 0);
  check "capture pins" (l.Silicon_trace.pins_base = 0 && l.Silicon_trace.pins_count = 8);
  check "sample count" (Array.length l.Silicon_trace.samples = 1280);
  (* First word 0xd08fd1a1 gives bytes a1 d1 8f d0, LSB first (silicon-ref README). *)
  check "sample 0..3" (Array.sub l.Silicon_trace.samples 0 4 = [| 0xa1; 0xd1; 0x8f; 0xd0 |]);
  let m = l.Silicon_trace.model in
  (* init.levels and init.dirs: GPIO 0 and 1 driven high. *)
  check "init levels" (m.Pgsim.pin_level land 3 = 3);
  check "init dirs" (m.Pgsim.pin_dir land 3 = 3);
  (* init.tx_words: 0xa5 then 0x5a, in order. *)
  check "tx words" ((Pgsim.debug m 0).Pgsim.tx_fifo = [ 0xa5; 0x5a ]);
  (* RP2350 EXECCTRL 0x40003000: SIDE_EN set, wrap 3..0, STATUS fields zero. *)
  let d = Pgsim.debug m 0 in
  check "pc at entry before enable" (d.Pgsim.pc = 0);
  check "sm enabled" d.Pgsim.enabled
;;

let%expect_test "loader: fixture config reaches the model as RP2040-layout registers" =
  let l = Silicon_trace.load fixture in
  let m = l.Silicon_trace.model in
  (* The side-set count is the JSON size, 2 with the enable bit (pinctrl 0x40100400). *)
  check "sideset count" (m.Pgsim.sms.(0).Pgsim.cfg.Pgsim.Config.sideset_count = 2);
  check "side_en" m.Pgsim.sms.(0).Pgsim.cfg.Pgsim.Config.side_en;
  check "out count" (m.Pgsim.sms.(0).Pgsim.cfg.Pgsim.Config.out_count = 1)
;;

(* RP2350 STATUS_SEL and STATUS_N differ from RP2040 (pio.h: [6:5] and [4:0]). *)
let%expect_test "RP2350 STATUS fields convert to the RP2040 layout" =
  let conv e = Silicon_trace.rp2350_execctrl_to_rp2040 e in
  (* STATUS_SEL = 1 (RXLEVEL), STATUS_N = 5: RP2040 bit 4 set, N = 5. *)
  check "rx sel" (conv (0x20 lor 5) = 0x10 lor 5);
  (* STATUS_SEL = 0 (TXLEVEL), STATUS_N = 3. *)
  check "tx sel" (conv 3 = 3);
  (* RP2350-only bits must not leak into the RP2040 layout. *)
  check "side en kept" (conv (0x4000_0000 lor 0x20) = 0x4000_0010);
  let raised f = try ignore (f ()); false with Silicon_trace.Bad_trace _ -> true in
  check "IRQ status rejected" (raised (fun () -> conv 0x40));
  check "N above 15 rejected" (raised (fun () -> conv 16))
;;

(* ------------------------------------------------------------------------------------ *)
(* Program JSON to configuration, no --config (the side-set size bug) *)

(* corpus uart_tx with no register config: wrap and side-set come from the JSON only. The
   JSON size is 2 with the enable bit, so SIDESET_COUNT is 2. With SIDESET_COUNT counted
   wrong, the side-set delay split is wrong and the timing below moves. OUT has no pins
   here (the JSON carries none), so the data bits do not show. The side-set alone gives:
   high at 1..8 (pull), low at 9..80 (start bit, then no pin driven), high from 81. *)
let%expect_test "corpus uart_tx with no config: side-set timing (datasheet 3.5.1, 3.6.3)" =
  let prog =
    Pioasm_json.load "../../pgasm/test/corpus/pico-examples/pio/uart_tx/uart_tx.pio.json"
  in
  let cfg = Pioasm_json.apply_to_config prog Pgsim.Config.reset in
  check "sideset count from JSON size" (cfg.Pgsim.Config.sideset_count = 2);
  check "side enable from JSON" cfg.Pgsim.Config.side_en;
  let t = Pgsim.create () in
  Pgsim.load_program t prog.Pioasm_json.words;
  Pgsim.set_config t 0 cfg;
  Pgsim.write_tx t 0 0xA5;
  Pgsim.write_instr t 0 (set_pindirs 1);
  ignore (Pgsim.step t);
  Pgsim.set_enabled t 0 true;
  let w = Array.of_list (pin0 t 90) in
  for c = 1 to 8 do
    check (Printf.sprintf "high at %d" c) (w.(c) = 1)
  done;
  for c = 9 to 80 do
    check (Printf.sprintf "low at %d" c) (w.(c) = 0)
  done;
  for c = 81 to 89 do
    check (Printf.sprintf "stop high at %d" c) (w.(c) = 1)
  done
;;

(* 3.5.7: a forced instruction ignores its delay field and does not zero a pending delay
   of the instruction it interrupts. *)
let%expect_test "forced instruction: delay ignored, pending delay kept (datasheet 3.5.7)" =
  let t = make [ set_pins ~delay:5 1; jmp 1 ] in
  run t 1;
  check "interrupted delay is 5" ((dbg t 0).Pgsim.delay = 5);
  Pgsim.write_instr t 0 (set_pins ~delay:3 0);
  ignore (Pgsim.step t);
  check "forced instruction ran" (t.Pgsim.pin_level land 1 = 0);
  check "pending delay untouched" ((dbg t 0).Pgsim.delay = 5)
;;

(* 3.5.4.2, "On non-OUT cycles": with autopull, a non-OUT cycle refills an empty OSR from a
   waiting TX word, so the OUT that follows a delay does not stall. *)
let%expect_test "autopull refills on non-OUT cycles, including delay cycles (datasheet 3.5.4.2)" =
  let cfg = { C.reset with autopull = true; pull_thresh = 32; out_count = 5 } in
  let t = make ~cfg [ set_x 0; out ~delay_side:0 Out_pins 5 ] in
  (* Reset OSR count is 32, so the OSR is at threshold. The word waits in TX. *)
  Pgsim.write_tx t 0 0xFFFF_FFFF;
  (* Make the SET a delayed one: [3] on set x, 0. *)
  t.Pgsim.imem.(0) <- enc (Isa.Set { delay_side = 3; dest = Set_x; data = 0 });
  run t 1;
  check "refilled on the set cycle" (t.Pgsim.sms.(0).Pgsim.osr_count = 0);
  check "tx word moved to OSR" (t.Pgsim.sms.(0).Pgsim.osr = 0xFFFF_FFFF);
  run t 4;
  check "OUT ran without stalling" ((dbg t 0).Pgsim.stall = Pgsim.No_stall && (dbg t 0).Pgsim.pc = 2)
;;

(* 3.4.6.2: a blocking PUSH into a full RX FIFO sets RXSTALL and stalls. *)
let%expect_test "blocking PUSH into a full RX FIFO sets RXSTALL (datasheet 3.4.6.2)" =
  let t = make [ push () ] in
  for i = 1 to 4 do
    Pgsim.Fifo.push t.Pgsim.sms.(0).Pgsim.rx i
  done;
  run t 1;
  let d = dbg t 0 in
  check "stalled on rx full" (d.Pgsim.stall = Pgsim.Stall_rx_full);
  check "rxstall set" d.Pgsim.rxstall
;;

(* 3.5.4.1 and 3.4.6.2: an autopush into a full RX FIFO stalls, and sets RXSTALL. *)
let%expect_test "autopush into a full RX FIFO stalls and sets RXSTALL (datasheet 3.5.4.1)" =
  let cfg = { C.reset with autopush = true; push_thresh = 8 } in
  let t = make ~cfg [ in_ In_x 8 ] in
  for i = 1 to 4 do
    Pgsim.Fifo.push t.Pgsim.sms.(0).Pgsim.rx i
  done;
  run t 1;
  let d = dbg t 0 in
  check "stalled on rx full" (d.Pgsim.stall = Pgsim.Stall_rx_full);
  check "rxstall set" d.Pgsim.rxstall;
  check "isr not shifted while stalled" (d.Pgsim.isr_count = 0)
;;

(* Debug view: the lockstep harness needs the latch, IRQ wait, accumulator, side-set state,
   sticky state and FIFO contents, and the pads at the start of the cycle. *)
let%expect_test "debug view exposes latch, irq wait, FIFOs, flags and pads" =
  let t = make [ irq ~wait:true 3; set_pindirs 1 ] in
  Pgsim.write_tx t 0 0x11;
  Pgsim.write_tx t 0 0x22;
  run t 2;
  let d = dbg t 0 in
  check "irq wait flag" (d.Pgsim.irq_wait = Some 3);
  check "fifo contents" (d.Pgsim.tx_fifo = [ 0x11; 0x22 ]);
  check "stall code for irq wait" (d.Pgsim.stall_code = 7);
  check "accumulator in range" (d.Pgsim.acc >= 0 && d.Pgsim.acc < 256);
  Pgsim.write_instr t 0 (set_pins 1);
  check "host latch visible" ((dbg t 0).Pgsim.latch = Pgsim.Host_latch (set_pins 1));
  let level, oe = Pgsim.pads t in
  check "pads show start-of-cycle state" (level land 1 = 0 && oe = 0)
;;

(* 3.4.9.2: a forced instruction during an IRQ wait does not clear the wait. The IRQ wait
   keeps its flag and resumes after the host clears it. AMBIGUITY, see README. *)
let%expect_test "forced instruction during IRQ wait keeps the wait (ambiguity, V1)" =
  let t = make [ irq ~wait:true 2; set_pins 1 ] in
  run t 3;
  check "waiting" ((dbg t 0).Pgsim.irq_wait = Some 2);
  Pgsim.write_instr t 0 (set_pins 0);
  ignore (Pgsim.step t);
  check "wait kept after forced instruction" ((dbg t 0).Pgsim.irq_wait = Some 2);
  Pgsim.clear_irq t 4;
  run t 2;
  check "resumed after clear" (t.Pgsim.pin_level land 1 = 1)
;;
