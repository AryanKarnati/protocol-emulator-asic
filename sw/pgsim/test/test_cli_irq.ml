(* Tests for the divider phase after the entry jump, forced and EXEC IRQ instructions during
   an IRQ wait, and the pgsim command (Runner.main): events, multi-SM config, --pins, --tx
   ordering and errors. Expectations are derived by hand from the datasheet and from
   capture.py's order of host operations, not from the model's own output. *)

module Isa = Polyglot_isa.Isa
module C = Pgsim.Config

let enc = Isa.encode
let check name cond = if not cond then failwith ("FAILED: " ^ name)
let dbg t i = Pgsim.debug t i

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

let set_pins d = enc (Isa.Set { delay_side = 0; dest = Set_pins; data = d })
let jmp addr = enc (Isa.Jmp { delay_side = 0; cond = Always; addr })
let out_exec n = enc (Isa.Out { delay_side = 0; dest = Out_exec; bit_count = n })
let irq ?(wait = false) ?(clear = false) ?(index = 0) () =
  enc (Isa.Irq { delay_side = 0; clear; wait; index; rel = false })
;;

let write_file path text =
  let oc = open_out path in
  output_string oc text;
  close_out oc;
  path
;;

(* ------------------------------------------------------------------------------------ *)
(* Divider phase after the entry jump *)

(* A silicon trace header with the given registers and program, for the loader. The
   samples are the given list, four per word. *)
let write_trace ~path ~clkdiv ~execctrl ~words ~init_dirs ~tx_words samples =
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
  let hexs l = `List (List.map (fun w -> `String (Printf.sprintf "0x%04x" w)) l) in
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
            [ "name", `String "p"
            ; "pio_version", `Int 0
            ; "entry", `Int 0
            ; ( "init"
              , `Assoc
                  [ "levels", `Assoc []
                  ; "dirs", `Assoc (List.map (fun p -> string_of_int p, `Int 1) init_dirs)
                  ; "tx_words", `List (List.map (fun w -> `String (Printf.sprintf "0x%08x" w)) tx_words)
                  ] )
            ; "words", hexs words
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
  output_string
    oc
    (Yojson.Safe.to_string
       (`Assoc
           [ "record", `String "words"
           ; "first_word", `Int 0
           ; "words", `List (List.init nwords (fun w -> `String (word w)))
           ])
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
  close_out oc;
  path
;;

(* Cycles on which the PC changes, from the first step after enable. *)
let tick_cycles m n =
  let ticks = ref [] in
  let prev = ref (dbg m 0).Pgsim.pc in
  for c = 0 to n - 1 do
    ignore (Pgsim.step m);
    let pc = (dbg m 0).Pgsim.pc in
    if pc <> !prev then ticks := c :: !ticks;
    prev := pc
  done;
  List.rev !ticks
;;

(* Divisor 2.5 from phase 0 must tick on cycles 2, 4, 7, 9 (gaps 2, 3, 2, ...). The program
   is set pindirs; set pins,1; set pins,0 over 1..2, so every tick moves the PC. *)
let%expect_test "divider 2.5 after the entry jump: first ticks on 2, 4, 7, 9" =
  let path =
    write_trace ~path:"silicon_clk25.jsonl" ~clkdiv:0x0002_8000 ~execctrl:0x0000_2080
      ~words:[ 0xE081; 0xE001; 0xE000 ] ~init_dirs:[ 0 ] ~tx_words:[] (Array.make 16 0)
  in
  let m = (Silicon_trace.load path).Silicon_trace.model in
  let ticks = tick_cycles m 40 in
  check
    (Printf.sprintf "ticks %s" (String.concat "," (List.map string_of_int ticks)))
    (match ticks with 2 :: 4 :: 7 :: 9 :: _ -> true | _ -> false)
;;

(* The fixture with its CLKDIV changed to 2.5 (0x00028000). The first tick runs the pull
   (its PC change is on cycle 2). The pull has delay 7, so set x runs 8 ticks later, the
   ninth tick. Ticks fall on 2, 4, 7, 9, 12, 14, 17, 19, 22 (ceil(2.5k) - 1). *)
let%expect_test "fixture with CLKDIV 2.5: PC changes on cycles 2 and 4" =
  let text =
    let ic = open_in "../../../silicon-ref/testdata/uart_tx_example.jsonl" in
    let s = really_input_string ic (in_channel_length ic) in
    close_in ic;
    s
  in
  let needle = "\"clkdiv\": \"0x00010000\"" in
  let len = String.length needle in
  let i =
    let rec find k = if String.sub text k len = needle then k else find (k + 1) in
    find 0
  in
  let changed =
    String.sub text 0 i ^ "\"clkdiv\": \"0x00028000\""
    ^ String.sub text (i + len) (String.length text - i - len)
  in
  let path = write_file "fixture_clk25.jsonl" changed in
  let m = (Silicon_trace.load path).Silicon_trace.model in
  let ticks = tick_cycles m 23 in
  check
    (Printf.sprintf "fixture ticks %s" (String.concat "," (List.map string_of_int ticks)))
    (ticks = [ 2; 22 ])
;;

(* ------------------------------------------------------------------------------------ *)
(* Forced and EXEC IRQ instructions during an IRQ wait *)

let%expect_test "forced irq clear during an irq wait clears the flag; the wait resumes" =
  let t = make [ irq ~wait:true (); set_pins 1 ] in
  run t 2;
  check "stalled in irq wait" ((dbg t 0).Pgsim.irq_wait = Some 0);
  Pgsim.write_instr t 0 (irq ~clear:true ());
  ignore (Pgsim.step t);
  check "forced clear cleared flag 0" (t.Pgsim.irq land 1 = 0);
  check "imem wait kept" ((dbg t 0).Pgsim.irq_wait = Some 0);
  run t 2;
  check "wait resumed and set pins ran" (t.Pgsim.pin_level land 1 = 1)
;;

let%expect_test "forced irq nowait during an irq wait sets its flag and keeps the wait" =
  let t = make [ irq ~wait:true (); set_pins 1 ] in
  run t 2;
  Pgsim.write_instr t 0 (irq ~index:1 ());
  ignore (Pgsim.step t);
  check "forced nowait set flag 1" (t.Pgsim.irq land 2 = 2);
  check "imem still waiting on flag 0" ((dbg t 0).Pgsim.irq_wait = Some 0);
  check "still stalled in irq wait" ((dbg t 0).Pgsim.stall = Pgsim.Stall_irq_wait);
  run t 2;
  check "not released while flag 0 is up" (t.Pgsim.pin_level land 1 = 0);
  (* Flag 1 is bit 1, mask 2. Clearing it must not release the wait on flag 0. *)
  Pgsim.clear_irq t 2;
  run t 2;
  check "not released by flag 1" (t.Pgsim.pin_level land 1 = 0);
  check "flag 0 still up" (t.Pgsim.irq land 1 = 1);
  Pgsim.clear_irq t 1;
  run t 2;
  check "released once flag 0 is cleared" (t.Pgsim.pin_level land 1 = 1)
;;

(* OUT EXEC of an IRQ wait: the executee waits in its own slot. The IMEM wait slot is not
   touched, and the IMEM instruction after the OUT runs once the executee completes. *)
let%expect_test "out exec of an irq wait stalls in the latch slot, not the IMEM slot" =
  let t = make [ out_exec 16; set_pins 1 ] in
  t.Pgsim.sms.(0).Pgsim.osr <- irq ~wait:true ~index:2 ();
  t.Pgsim.sms.(0).Pgsim.osr_count <- 0;
  run t 2;
  let d = dbg t 0 in
  check "executee stalled on irq" (d.Pgsim.stall = Pgsim.Stall_irq_wait);
  check "latch wait slot used" (d.Pgsim.latch_irq_wait = Some 2);
  check "imem wait slot untouched" (d.Pgsim.irq_wait = None);
  Pgsim.clear_irq t 4;
  run t 2;
  check "executee done" ((dbg t 0).Pgsim.latch = Pgsim.No_latch);
  check "imem continued" (t.Pgsim.pin_level land 1 = 1)
;;

(* ------------------------------------------------------------------------------------ *)
(* The pgsim command (Runner.main) *)

let cli args =
  let out = Buffer.create 256 in
  let err = Buffer.create 64 in
  let status =
    Runner.main ~out:(Buffer.add_string out) ~err:(Buffer.add_string err)
      (Array.of_list ("pgsim" :: args))
  in
  status, Buffer.contents out, Buffer.contents err
;;

(* "cycle pad" lines of --trace output, as (cycle, pad) pairs. *)
let trace_pads out =
  String.split_on_char '\n' out
  |> List.filter_map (fun line ->
    if line <> "" && line.[0] >= '0' && line.[0] <= '9'
    then Scanf.sscanf line "%d %x" (fun c p -> Some (c, p))
    else None)
;;

let pad_at out c = List.assoc c (trace_pads out) land 1

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0
;;

(* pull; set pins,1; jmp 0. *)
let pull_program =
  write_file "cli_pull.json"
    {|{"programs":[{"name":"pull","pioVersion":0,"wrapTarget":0,"wrap":2,"instructions":[{"hex":"80a0","instruction":"pull"},{"hex":"e001","instruction":"set pins, 1"},{"hex":"0000","instruction":"jmp 0"}]}]}|}
;;

let%expect_test "--at tx: a TX push at cycle 5 lets the pull run; the pin follows" =
  let status, out, _ =
    cli [ "--program"; pull_program; "--init-instr"; "e081"; "--at"; "5:tx:0:1"; "--cycles"; "10"; "--trace" ]
  in
  check "status 0" (status = 0);
  check "low before set pins runs" (pad_at out 6 = 0);
  check "high after set pins" (pad_at out 7 = 1)
;;

let%expect_test "--at irqclear: clearing the flag releases an irq wait" =
  let prog =
    write_file "cli_irq.json"
      {|{"programs":[{"name":"irq","pioVersion":0,"wrapTarget":0,"wrap":2,"instructions":[{"hex":"c020","instruction":"irq wait 0"},{"hex":"e001","instruction":"set pins, 1"},{"hex":"0000","instruction":"jmp 0"}]}]}|}
  in
  let status, out, _ =
    cli [ "--program"; prog; "--init-instr"; "e081"; "--at"; "6:irqclear:1"; "--cycles"; "10"; "--trace" ]
  in
  check "status 0" (status = 0);
  check "still waiting at 7" (pad_at out 7 = 0);
  check "released by 8" (pad_at out 8 = 1)
;;

let%expect_test "--at instr: a forced set pins runs at its cycle" =
  let prog =
    write_file "cli_jmp.json"
      {|{"programs":[{"name":"loop","pioVersion":0,"wrapTarget":0,"wrap":0,"instructions":[{"hex":"0000","instruction":"jmp 0"}]}]}|}
  in
  let status, out, _ =
    cli [ "--program"; prog; "--init-instr"; "e081"; "--at"; "3:instr:0:e001"; "--cycles"; "6"; "--trace" ]
  in
  check "status 0" (status = 0);
  check "low before the forced instruction" (pad_at out 3 = 0);
  check "high after it" (pad_at out 4 = 1)
;;

let%expect_test "--pins: external pad levels from a cycle, with no PIO driving the pin" =
  let cfg = write_file "cli_pins_cfg.json" {|{"pinctrl":"0x00000000"}|} in
  let status, out, _ =
    cli [ "--program"; pull_program; "--config"; cfg; "--pins"; "3:1"; "--cycles"; "6"; "--trace" ]
  in
  check "status 0" (status = 0);
  check "low before 3" (pad_at out 2 = 0);
  check "high from 3" (pad_at out 3 = 1)
;;

let%expect_test "multi-SM config: two SMs drive one pin, the higher-numbered wins" =
  (* imem: 0 set pins,1; 1 jmp 1; 2 set pins,0; 3 jmp 3. SM0 starts at 0, SM1 at 2. *)
  let prog =
    write_file "cli_multi.json"
      {|{"programs":[{"name":"two","pioVersion":0,"wrapTarget":0,"wrap":3,"instructions":[{"hex":"e001","instruction":"set pins, 1"},{"hex":"0001","instruction":"jmp 1"},{"hex":"e000","instruction":"set pins, 0"},{"hex":"0003","instruction":"jmp 3"}]}]}|}
  in
  let both =
    write_file "cli_multi_both.json" {|{"sms":[{"sm":0,"enable":true},{"sm":1,"entry":2,"enable":true}]}|}
  in
  let only0 =
    write_file "cli_multi_only0.json" {|{"sms":[{"sm":0,"enable":true},{"sm":1,"entry":2,"enable":false}]}|}
  in
  let _, out_both, _ =
    cli [ "--program"; prog; "--config"; both; "--init-instr"; "e081"; "--cycles"; "6"; "--trace" ]
  in
  let _, out0, _ =
    cli [ "--program"; prog; "--config"; only0; "--init-instr"; "e081"; "--cycles"; "6"; "--trace" ]
  in
  check "both SMs: pin low" (pad_at out_both 4 = 0);
  check "SM0 alone: pin high" (pad_at out0 4 = 1)
;;

let%expect_test "--tx before --sm binds to the named SM (order-independent)" =
  let cfg = write_file "cli_sm1.json" {|{"sms":[{"sm":1}]}|} in
  let _, out, _ =
    cli [ "--program"; pull_program; "--config"; cfg; "--tx"; "5"; "--sm"; "1"; "--cycles"; "2"; "--trace" ]
  in
  check (Printf.sprintf "SM1 pulled 5 into its OSR; out=%S" out) (contains out "osr=00000005")
;;

let%expect_test "a bad --at gives a clean error and status 2" =
  let status, _, err = cli [ "--program"; pull_program; "--at"; "5:bogus" ] in
  check "status 2" (status = 2);
  check (Printf.sprintf "error text %S" err) (contains err "pgsim: error: bad --at event")
;;
