(* Tests for (1) a forced instruction's completion never leaving the interrupted
   instruction's stall reason stale (README, "Stall reason of a latched instruction"), and
   (2) three CLI paths that were not covered: --at CYCLE:pin:N:V, the sync_bypass config key,
   and the divider restart before enable. Expectations are derived from the datasheet and
   from capture.py's order of host operations. *)

module Isa = Polyglot_isa.Isa
module C = Pgsim.Config

let enc = Isa.encode
let check name cond = if not cond then failwith ("FAILED: " ^ name)
let dbg t i = Pgsim.debug t i

let make ?(cfg = C.reset) words =
  let t = Pgsim.create () in
  Pgsim.load_program t words;
  Pgsim.set_config t 0 cfg;
  Pgsim.set_enabled t 0 true;
  t
;;

let run t n =
  for _ = 1 to n do
    ignore (Pgsim.step t)
  done
;;

let set_pins d = enc (Isa.Set { delay_side = 0; dest = Set_pins; data = d })

let write_file path text =
  let oc = open_out path in
  output_string oc text;
  close_out oc;
  path
;;

let cli args =
  let out = Buffer.create 256 in
  let err = Buffer.create 64 in
  let status =
    Runner.main ~out:(Buffer.add_string out) ~err:(Buffer.add_string err)
      (Array.of_list ("pgsim" :: args))
  in
  status, Buffer.contents out, Buffer.contents err
;;

let trace_pads out =
  String.split_on_char '\n' out
  |> List.filter_map (fun line ->
    if line <> "" && line.[0] >= '0' && line.[0] <= '9'
    then Scanf.sscanf line "%d %x" (fun c p -> Some (c, p))
    else None)
;;

let pad_at out c = List.assoc c (trace_pads out) land 1

(* ------------------------------------------------------------------------------------ *)
(* Forced instruction completion and the stall reason *)

let wait_pin5 = enc (Isa.Wait { delay_side = 0; polarity = true; source = Wsrc_pin 5 })
let wait_gpio4 = enc (Isa.Wait { delay_side = 0; polarity = true; source = Wsrc_gpio 4 })

(* Stalled in wait 1 pin 5 at divisor 4. Force wait 1 gpio 4 and release pin 4. On the cycle
   the forced instruction completes, the reported reason is the IMEM one, with no tick. *)
let forced_wait_check ~disable =
  let cfg = { C.reset with clkdiv_int = 4 } in
  let t = make ~cfg [ wait_pin5; set_pins 1 ] in
  run t 8;
  check "imem stalled on pin 5" ((dbg t 0).Pgsim.stall = Pgsim.Stall_wait_pin);
  if disable then Pgsim.set_enabled t 0 false;
  Pgsim.write_instr t 0 wait_gpio4;
  ignore (Pgsim.step t);
  check "latched wait reports its own reason" ((dbg t 0).Pgsim.stall = Pgsim.Stall_wait_gpio);
  check "latched wait stall_code is 4" ((dbg t 0).Pgsim.stall_code = 4);
  t.Pgsim.ext <- 1 lsl 4;
  let steps = ref 0 in
  while (dbg t 0).Pgsim.latch <> Pgsim.No_latch && !steps < 20 do
    ignore (Pgsim.step t);
    incr steps
  done;
  check "forced wait completed" ((dbg t 0).Pgsim.latch = Pgsim.No_latch);
  let d = dbg t 0 in
  check
    (Printf.sprintf "at completion the IMEM reason is reported, stall_code %d" d.Pgsim.stall_code)
    (d.Pgsim.stall = Pgsim.Stall_wait_pin
     && d.Pgsim.stall_code = 5
     && d.Pgsim.latch_stall = Pgsim.No_stall);
  (* With the SM disabled the IMEM never re-evaluates, so the reason must hold. *)
  run t 12;
  check "reason still correct later" ((dbg t 0).Pgsim.stall = Pgsim.Stall_wait_pin)
;;

let%expect_test "forced wait completion restores the IMEM reason at once, clkdiv 4, enabled" =
  forced_wait_check ~disable:false
;;

let%expect_test "forced wait completion restores the IMEM reason at once, clkdiv 4, disabled" =
  forced_wait_check ~disable:true
;;

(* ------------------------------------------------------------------------------------ *)
(* CLI paths *)

(* pull; set pins,1; jmp 0, as in test_cli_irq. *)
let pull_program =
  write_file "cli_paths_pull.json"
    {|{"programs":[{"name":"pull","pioVersion":0,"wrapTarget":0,"wrap":2,"instructions":[{"hex":"80a0","instruction":"pull"},{"hex":"e001","instruction":"set pins, 1"},{"hex":"0000","instruction":"jmp 0"}]}]}|}
;;

(* --at CYCLE:pin:N:V: pads 0 is driven from its external level (no PIO writes, since
   PINCTRL is zero), set at cycle 3 to 1 and at cycle 6 to 0. *)
let%expect_test "--at CYCLE:pin:N:V sets a known pad level from that cycle" =
  let cfg = write_file "cli_paths_pad_cfg.json" {|{"pinctrl":"0x00000000"}|} in
  let status, out, _ =
    cli
      [ "--program"; pull_program; "--config"; cfg; "--at"; "3:pin:0:1"; "--at"; "6:pin:0:0"
      ; "--cycles"; "9"; "--trace" ]
  in
  check "status 0" (status = 0);
  check "pad 0 low at 2" (pad_at out 2 = 0);
  check "pad 0 high from 3" (pad_at out 3 = 1);
  check "pad 0 high at 5" (pad_at out 5 = 1);
  check "pad 0 low from 6" (pad_at out 6 = 0)
;;

(* wait 1 pin 5; set pins,1; jmp 0. Pin 5 is not driven by the program (set pins drives
   pins 0..4), so the external level from --at reaches the wait. *)
let wait_program =
  write_file "cli_paths_wait_pin5.json"
    {|{"programs":[{"name":"w","pioVersion":0,"wrapTarget":0,"wrap":2,"instructions":[{"hex":"20a5","instruction":"wait 1 pin 5"},{"hex":"e001","instruction":"set pins, 1"},{"hex":"0000","instruction":"jmp 0"}]}]}|}
;;

(* The first cycle where pad 0 is high. Pin 5 is driven to 1 at cycle 2. The wait completes
   on the step that sees it: 3 cycles later through the synchroniser, 1 cycle later when
   pin 5 is bypassed. set pins then drives pad 0 two cycles after the wait completes. *)
let first_high_pad cfg_text =
  let cfg = write_file "cli_paths_sync_cfg.json" cfg_text in
  let _, out, _ =
    cli
      [ "--program"; wait_program; "--config"; cfg; "--init-instr"; "e081"; "--at"; "2:pin:5:1"
      ; "--cycles"; "12"; "--trace" ]
  in
  let rec first c = if c > 11 then -1 else if pad_at out c = 1 then c else first (c + 1) in
  first 0
;;

let%expect_test "sync_bypass: bypassing pin 5 completes the wait 2 cycles earlier" =
  let synced = first_high_pad {|{"sync_bypass":"0x0"}|} in
  let bypassed = first_high_pad {|{"sync_bypass":"0x20"}|} in
  check (Printf.sprintf "synchronised: pad high at %d" synced) (synced = 7);
  check (Printf.sprintf "bypassed: pad high at %d" bypassed) (bypassed = 5);
  check "difference is 2" (synced - bypassed = 2)
;;

(* clkdiv 2.5, restarted by the CLI before enable. The program toggles pad 0 on every tick:
   set pins,1 then set pins,0. Ticks fall on 2, 4, 7, 9 (gaps 2, 3, 2), and the pad follows
   one cycle later: high on 3-4, low 5-7, high 8-9, low 10. The init-instr step before enable
   would otherwise leave the accumulator at 256 and move every tick. *)
let%expect_test "CLI divider restart before enable: clkdiv 2.5 ticks on 2, 4, 7, 9" =
  let prog =
    write_file "cli_paths_toggle.json"
      {|{"programs":[{"name":"tog","pioVersion":0,"wrapTarget":0,"wrap":1,"instructions":[{"hex":"e001","instruction":"set pins, 1"},{"hex":"e000","instruction":"set pins, 0"}]}]}|}
  in
  let cfg = write_file "cli_paths_clk25.json" {|{"clkdiv":"0x00028000"}|} in
  let status, out, _ =
    cli [ "--program"; prog; "--config"; cfg; "--init-instr"; "e081"; "--cycles"; "12"; "--trace" ]
  in
  check "status 0" (status = 0);
  let got = List.init 12 (pad_at out) in
  let want = [ 0; 0; 0; 1; 1; 0; 0; 0; 1; 1; 0; 0 ] in
  check
    (Printf.sprintf "pad 0 over 12 cycles: %s" (String.concat "" (List.map string_of_int got)))
    (got = want)
;;
