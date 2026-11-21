(* The pgsim command, as a function so that tests can call it. [main argv] returns the exit
   status: 0 on success, 2 on a usage or input error. Trace lines and the summary go to
   [out], errors go to [err].

   pgsim --program prog.json [--config cfg.json] [--sm N] [--cycles N]
         [--tx WORD]... [--init-instr HEX]...
         [--pins CYCLE:VALUE]... [--at EVENT]...
         [--vcd FILE] [--trace]

   --program     pioasm -o json output (first program, or --name NAME).
   --config      JSON. Top-level keys set one SM, or "sms" is a list of such objects, each
                 with an "sm" index. Keys (hex strings or ints):
                   clkdiv, execctrl, shiftctrl, pinctrl   (RP2040 layout)
                   enable (bool, default true)
                   entry  (instruction the SM starts at, default 0)
                   sync_bypass (INPUT_SYNC_BYPASS, global)
                 A register given here replaces the whole register, so an explicit pinctrl
                 replaces the side-set count that the program JSON gives. Missing registers
                 keep the reset value, adjusted from the program JSON (wrap and side-set; see
                 Pioasm_json.apply_to_config).
   --sm N        the SM that --tx, --init-instr and the summary refer to (default 0). The
                 order of the options does not matter: --sm applies to all of them.
   --tx WORD     word pushed to the TX FIFO of SM --sm before cycle 0 (repeatable).
   --init-instr  HEX instruction written to SMx_INSTR for SM --sm before cycle 0, one
                 step each (repeatable), e.g. e081 for set pindirs, 1.
   --pins C:V    external 32-bit pad levels from cycle C (repeatable).
   --at EVENT    an event at a cycle, applied before that cycle runs (repeatable):
                   CYCLE:tx:SM:WORD     TX push
                   CYCLE:irqclear:MASK  host write-1-to-clear of IRQ flags
                   CYCLE:pin:N:V        external level of pad N from CYCLE on
                   CYCLE:instr:SM:HEX   forced instruction (SMx_INSTR)
   --trace       print "cycle pad" for every cycle, pads in hex, and a summary of --sm.
   --vcd FILE    write a VCD of the pads and each SM's state.

   Before cycle 0 the host does, in capture.py's order: TX words, init instructions, the
   entry jump for each SM, a CLKDIV_RESTART for all SMs (so the dividers start at phase 0),
   then the enables from the config. *)

type event =
  | Tx of int * int (* SM, word *)
  | Irq_clear of int (* mask *)
  | Pad of int * int (* pad, level *)
  | Instr of int * int (* SM, word *)

exception Usage of string

let usage = "pgsim --program FILE [options]"

let parse_at s =
  let bad () = raise (Usage ("bad --at event: " ^ s)) in
  let i x = match int_of_string_opt x with Some n -> n | None -> bad () in
  match String.split_on_char ':' s with
  | c :: rest ->
    let c = i c in
    (match rest with
     | [ "tx"; sm; w ] -> c, Tx (i sm, i w)
     | [ "irqclear"; m ] -> c, Irq_clear (i m)
     | [ "pin"; n; v ] -> c, Pad (i n, i v)
     | [ "instr"; sm; h ] -> c, Instr (i sm, i ("0x" ^ h))
     | _ -> bad ())
  | [] -> bad ()
;;

let parse_pins s =
  match String.split_on_char ':' s with
  | [ c; v ] ->
    (match int_of_string_opt c, int_of_string_opt v with
     | Some c, Some v -> c, v
     | _ -> raise (Usage ("bad --pins value: " ^ s)))
  | _ -> raise (Usage "--pins expects CYCLE:VALUE")
;;

type sm_setup =
  { index : int
  ; clkdiv : int option
  ; execctrl : int option
  ; shiftctrl : int option
  ; pinctrl : int option
  ; enable : bool
  ; entry : int
  }

let read_config ~default_sm path =
  let j = Yojson.Safe.from_file path in
  let open Yojson.Safe.Util in
  let num k o =
    match member k o with
    | `Null -> None
    | `Int n -> Some n
    | `String s ->
      (match int_of_string_opt s with
       | Some n -> Some n
       | None -> raise (Usage (Printf.sprintf "config: %s is not a number: %S" k s)))
    | _ -> raise (Usage ("config: bad value for " ^ k))
  in
  let one o def =
    { index = (match member "sm" o with `Int n -> n | _ -> def)
    ; clkdiv = num "clkdiv" o
    ; execctrl = num "execctrl" o
    ; shiftctrl = num "shiftctrl" o
    ; pinctrl = num "pinctrl" o
    ; enable = (match member "enable" o with `Bool b -> b | _ -> true)
    ; entry = Option.value (num "entry" o) ~default:0
    }
  in
  let sync = num "sync_bypass" j in
  let setups =
    match member "sms" j with
    | `List l -> List.mapi (fun i o -> one o i) l
    | _ -> [ one j default_sm ]
  in
  setups, sync
;;

let main ?(out = print_string) ?(err = prerr_string) (argv : string array) : int =
  let program_path = ref "" in
  let program_name = ref None in
  let config_path = ref None in
  let sm_index = ref 0 in
  let cycles = ref 32 in
  (* TX words and init instructions name no SM until the end, so --sm may come later. *)
  let tx_words = ref [] in
  let init_instrs = ref [] in
  let pin_events = ref [] in
  let events = ref [] in
  let vcd_path = ref None in
  let trace = ref false in
  let spec =
    [ "--program", Arg.String (fun s -> program_path := s), "FILE pioasm JSON"
    ; "--name", Arg.String (fun s -> program_name := Some s), "NAME program in the file"
    ; "--config", Arg.String (fun s -> config_path := Some s), "FILE register JSON"
    ; "--sm", Arg.Set_int sm_index, "N SM for --tx, --init-instr and the summary"
    ; "--cycles", Arg.Set_int cycles, "N cycles to run (default 32)"
    ; "--tx", Arg.String (fun s -> tx_words := s :: !tx_words), "WORD TX word for --sm"
    ; ( "--pins"
      , Arg.String (fun s -> pin_events := parse_pins s :: !pin_events)
      , "C:V pads from cycle C" )
    ; ( "--init-instr"
      , Arg.String (fun s -> init_instrs := s :: !init_instrs)
      , "HEX instruction for --sm" )
    ; ( "--at"
      , Arg.String (fun s -> events := parse_at s :: !events)
      , "EVENT per-cycle event" )
    ; "--vcd", Arg.String (fun s -> vcd_path := Some s), "FILE write VCD"
    ; "--trace", Arg.Set trace, " print pads per cycle and a summary"
    ]
  in
  try
    Arg.parse_argv ~current:(ref 0) argv spec
      (fun _ -> raise (Usage "unexpected argument"))
      usage;
    if !program_path = ""
    then raise (Usage "--program is required");
    let prog = Pioasm_json.load ?which:!program_name !program_path in
    let t = Pgsim.create () in
    Pgsim.load_program t prog.Pioasm_json.words;
    let base = Pioasm_json.apply_to_config prog Pgsim.Config.reset in
    let setups, sync =
      match !config_path with
      | None ->
        ( [ { index = !sm_index; clkdiv = None; execctrl = None; shiftctrl = None
            ; pinctrl = None; enable = true; entry = 0 } ]
        , None )
      | Some p -> read_config ~default_sm:!sm_index p
    in
    (match sync with
     | Some b -> t.Pgsim.sync_bypass <- b
     | None -> ());
    List.iter
      (fun s ->
        let reg o default = Option.value o ~default in
        let cfg =
          Pgsim.Config.of_registers
            ~clkdiv:(reg s.clkdiv (Pgsim.Config.clkdiv_register base))
            ~execctrl:(reg s.execctrl (Pgsim.Config.execctrl_register base))
            ~shiftctrl:(reg s.shiftctrl (Pgsim.Config.shiftctrl_register base))
            ~pinctrl:(reg s.pinctrl (Pgsim.Config.pinctrl_register base))
        in
        Pgsim.set_config t s.index cfg)
      setups;
    (* Host setup before cycle 0, in capture.py's order. *)
    List.iter
      (fun w ->
        match int_of_string_opt w with
        | Some w -> Pgsim.write_tx t !sm_index w
        | None -> raise (Usage ("--tx: not a number: " ^ w)))
      (List.rev !tx_words);
    List.iter
      (fun h ->
        match int_of_string_opt ("0x" ^ h) with
        | Some w ->
          Pgsim.write_instr t !sm_index w;
          ignore (Pgsim.step t)
        | None -> raise (Usage ("--init-instr: not hex: " ^ h)))
      (List.rev !init_instrs);
    List.iter
      (fun s ->
        if s.entry <> 0
        then (
          Pgsim.write_instr t s.index s.entry;
          ignore (Pgsim.step t)))
      setups;
    (* CLKDIV_RESTART for every SM, then the enables (capture.py step 11). *)
    Pgsim.clkdiv_restart t 0xF;
    List.iter (fun s -> Pgsim.set_enabled t s.index s.enable) setups;
    let pending_pins = ref (List.sort compare !pin_events) in
    let pending_events =
      ref (List.stable_sort (fun (a, _) (b, _) -> compare a b) (List.rev !events))
    in
    let set_pad n v =
      let m = 1 lsl n in
      t.Pgsim.ext <- (if v = 1 then t.Pgsim.ext lor m else t.Pgsim.ext land lnot m)
    in
    let step_cycle cyc =
      let rec apply_pins () =
        match !pending_pins with
        | (c, v) :: rest when c <= cyc ->
          t.Pgsim.ext <- v;
          pending_pins := rest;
          apply_pins ()
        | _ -> ()
      in
      apply_pins ();
      let rec apply_events () =
        match !pending_events with
        | (c, ev) :: rest when c <= cyc ->
          (match ev with
           | Tx (sm, w) -> Pgsim.write_tx t sm w
           | Irq_clear m -> Pgsim.clear_irq t m
           | Pad (n, v) -> set_pad n v
           | Instr (sm, w) -> Pgsim.write_instr t sm w);
          pending_events := rest;
          apply_events ()
        | _ -> ()
      in
      apply_events ();
      Pgsim.step t
    in
    (match !vcd_path with
     | Some path -> Vcd.run ~path ~cycles:!cycles t step_cycle
     | None ->
       for cyc = 0 to !cycles - 1 do
         let pad = step_cycle cyc in
         if !trace then out (Printf.sprintf "%d %08x\n" cyc pad)
       done);
    if !trace
    then (
      let d = Pgsim.debug t !sm_index in
      out
        (Printf.sprintf
           "sm%d pc=%d x=%08x y=%08x isr=%08x/%d osr=%08x/%d tx=%d rx=%d stall=%s illegal=%b\n"
           !sm_index d.Pgsim.pc d.Pgsim.x d.Pgsim.y d.Pgsim.isr d.Pgsim.isr_count d.Pgsim.osr
           d.Pgsim.osr_count d.Pgsim.tx_level d.Pgsim.rx_level (Pgsim.stall_name d.Pgsim.stall)
           d.Pgsim.illegal));
    0
  with
  | Arg.Bad msg ->
    err msg;
    2
  | Arg.Help msg ->
    out msg;
    0
  | Usage msg | Failure msg | Sys_error msg | Yojson.Json_error msg ->
    err ("pgsim: error: " ^ msg ^ "\n");
    2
;;
