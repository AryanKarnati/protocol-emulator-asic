(* Replays a lockstep case file (format polyglot-lockstep-case, version 1) against
   Pio_block in Cyclesim, following docs/engine.md section 5, and prints the ports of each
   run cycle. Usage: replay.exe CASE.json

   Load phase: 32 cycles, one IMEM write per cycle from "imem", after reset. Then the
   per-SM "initial" configs and "initial_sync_bypass" are applied. Run cycle c applies the
   events with "cycle" = c. Levels (sm_enable, ext_pins) persist. Pulses (imem_write,
   tx_push, instr_write) last one cycle. pins_in = (pins_out & pins_oe) | (ext & ~pins_oe),
   from the pin registers at the start of the cycle. *)

open Hardcaml

let set sim name v =
  let r = Cyclesim.in_port sim name in
  r := Bits.of_int ~width:(Bits.width !r) v

let get sim name = Bits.to_int !(Cyclesim.out_port ~clock_edge:Before sim name)
let get_after sim name = Bits.to_int !(Cyclesim.out_port ~clock_edge:After sim name)

let pulses =
  [ "sm_restart"; "clkdiv_restart"; "fifo_flush"; "irq_clear"; "irq_force"; "fdebug_clear"
  ; "txf_push"; "rxf_pop"; "instr_write"; "imem_write" ]

let () =
  let file = Sys.argv.(1) in
  let open Yojson.Basic.Util in
  let j = Yojson.Basic.from_file file in
  let num_sms = j |> member "num_sms" |> to_int in
  let cycles = j |> member "cycles" |> to_int in
  let imem = j |> member "imem" |> to_list |> List.map to_int |> Array.of_list in
  let initial = j |> member "initial" |> to_list in
  let init_sync = j |> member "initial_sync_bypass" |> to_int in
  let events = j |> member "events" |> to_list in
  let sim = Cyclesim.create (Polyglot_hw.Pio_block.circuit ~num_sms) in
  List.iter (fun (_, r) -> r := Bits.zero (Bits.width !r)) (Cyclesim.in_ports sim);
  let cyc ?(pre = fun () -> ()) ?(check = fun () -> ()) () =
    List.iter (fun n -> set sim n 0) pulses;
    pre ();
    Cyclesim.cycle_check sim;
    Cyclesim.cycle_before_clock_edge sim;
    check ();
    Cyclesim.cycle_at_clock_edge sim;
    Cyclesim.cycle_after_clock_edge sim
  in
  (* Reset (cycle-based reset is not applied by Cyclesim; see smoke.ml). *)
  set sim "rst_n" 1;
  cyc ();
  set sim "rst_n" 0;
  cyc ();
  Cyclesim.reset sim;
  cyc ();
  set sim "rst_n" 1;
  (* Load phase. *)
  for k = 0 to 31 do
    let w = if k < Array.length imem then imem.(k) else 0 in
    cyc
      ~pre:(fun () ->
        set sim "imem_write" 1;
        set sim "imem_addr" k;
        set sim "imem_data" w)
      ()
  done;
  List.iteri
    (fun i cfg ->
      if i < num_sms
      then (
        set sim (Printf.sprintf "clkdiv%d" i) (cfg |> member "clkdiv" |> to_int);
        set sim (Printf.sprintf "execctrl%d" i) (cfg |> member "execctrl" |> to_int);
        set sim (Printf.sprintf "shiftctrl%d" i) (cfg |> member "shiftctrl" |> to_int);
        set sim (Printf.sprintf "pinctrl%d" i) (cfg |> member "pinctrl" |> to_int)))
    initial;
  set sim "sync_bypass" init_sync;
  (* Run phase. *)
  let ext = ref 0 in
  let po = ref 0 in
  let poe = ref 0 in
  let ev_at c =
    List.filter (fun e -> e |> member "cycle" |> to_int = c) events
  in
  (* Cycle [cycles] has no events: it is the state after the last cycle, which the case
     files compare against (manifest "run cycle" = cycles). *)
  for c = 0 to cycles do
    let evs = ev_at c in
    let pulse_set = ref [] in
    let reset = ref false in
    List.iter
      (fun e ->
        match e |> member "op" |> to_string with
        | "sm_enable" -> set sim "sm_enable" (e |> member "mask" |> to_int)
        | "ext_pins" -> ext := e |> member "pins" |> to_int
        | "imem_write" ->
          pulse_set :=
            (fun () ->
              set sim "imem_write" 1;
              set sim "imem_addr" (e |> member "addr" |> to_int);
              set sim "imem_data" (e |> member "data" |> to_int))
            :: !pulse_set
        | "tx_push" ->
          pulse_set :=
            (fun () ->
              set sim "txf_push" 1;
              set sim "txf_sm" (e |> member "sm" |> to_int);
              set sim "txf_data" (e |> member "data" |> to_int))
            :: !pulse_set
        | "instr_write" ->
          pulse_set :=
            (fun () ->
              set sim "instr_write" 1;
              set sim "instr_sm" (e |> member "sm" |> to_int);
              set sim "instr_data" (e |> member "data" |> to_int))
            :: !pulse_set
        | "reset_low" -> reset := true
        | op -> Printf.printf "# cycle %d: event %s not replayed\n" c op)
      evs;
    set sim "pins_in" ((!po land !poe) lor (!ext land lnot !poe land 0xFFFF_FFFF));
    if !reset
    then (
      (* rst_n low for this cycle: registers reset through Cyclesim.reset, and the outputs
         of this cycle are not compared. *)
      set sim "rst_n" 0;
      Cyclesim.reset sim;
      cyc ();
      set sim "rst_n" 1)
    else
    cyc
      ~pre:(fun () -> List.iter (fun f -> f ()) (List.rev !pulse_set))
      ~check:(fun () ->
        let pc = List.init num_sms (fun k -> Printf.sprintf "pc%d=%d" k (get sim (Printf.sprintf "dbg_pc%d" k))) in
        Printf.printf "c=%d pins_out=0x%08x pins_oe=0x%08x irq=0x%02x %s\n%!" c
          (get sim "pins_out") (get sim "pins_oe") (get sim "irq") (String.concat " " pc))
      ();
    po := get_after sim "pins_out";
    poe := get_after sim "pins_oe"
  done
