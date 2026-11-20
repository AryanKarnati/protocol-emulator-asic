(* pgsim: run a PIO program in the golden model with pin, TX and IRQ stimulus.

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
                 Missing registers keep the reset value, adjusted from the program JSON
                 (wrap and side-set; see Pioasm_json.apply_to_config).
   --sm N        the SM whose state --trace and the summary report (default 0).
   --tx WORD     word pushed to SM --sm's TX FIFO before cycle 0 (repeatable).
   --init-instr  HEX instruction written to SMx_INSTR for SM --sm before cycle 0, one
                 step each (repeatable), e.g. e081 for set pindirs, 1.
   --pins C:V    external 32-bit pad levels from cycle C (repeatable).
   --at EVENT    an event at a cycle, applied before that cycle runs (repeatable):
                   CYCLE:tx:SM:WORD     TX push
                   CYCLE:irqclear:MASK  host write-1-to-clear of IRQ flags
                   CYCLE:pin:N:V        external level of pad N from CYCLE on
                   CYCLE:instr:SM:HEX   forced instruction (SMx_INSTR)
   --trace       print "cycle pad" for every cycle, pads in hex.
   --vcd FILE    write a VCD of the pads and each SM's state.

   The program is loaded into the shared IMEM. Before cycle 0 the host does, in order:
   TX words, init instructions, the entry jump for each SM (as capture.py does), then the
   enables from the config. *)

type event =
  | Tx of int * int (* SM, word *)
  | Irq_clear of int (* mask *)
  | Pad of int * int (* pad, level *)
  | Instr of int * int (* SM, word *)

let program_path = ref ""
let program_name = ref None
let config_path = ref None
let sm_index = ref 0
let cycles = ref 32
let tx_words : (int * int) list ref = ref []
let pin_events : (int * int) list ref = ref []
let init_instrs : int list ref = ref []
let events : (int * event) list ref = ref []
let vcd_path = ref None
let trace = ref false
let usage = "pgsim --program FILE [options]"

let parse_at s =
  let i x = int_of_string x in
  match String.split_on_char ':' s with
  | c :: rest ->
    let c = i c in
    (match rest with
     | [ "tx"; sm; w ] -> c, Tx (i sm, i w)
     | [ "irqclear"; m ] -> c, Irq_clear (i m)
     | [ "pin"; n; v ] -> c, Pad (i n, i v)
     | [ "instr"; sm; h ] -> c, Instr (i sm, i ("0x" ^ h))
     | _ -> failwith ("bad --at event: " ^ s))
  | [] -> failwith ("bad --at event: " ^ s)
;;

let parse_pins s =
  match String.split_on_char ':' s with
  | [ c; v ] -> int_of_string c, int_of_string v
  | _ -> failwith "--pins expects CYCLE:VALUE"
;;

let () =
  Arg.parse
    [ "--program", Arg.String (fun s -> program_path := s), "FILE pioasm JSON"
    ; "--name", Arg.String (fun s -> program_name := Some s), "NAME program in the file"
    ; "--config", Arg.String (fun s -> config_path := Some s), "FILE register JSON"
    ; "--sm", Arg.Set_int sm_index, "N SM to report (default 0)"
    ; "--cycles", Arg.Set_int cycles, "N cycles to run (default 32)"
    ; ( "--tx"
      , Arg.String (fun s -> tx_words := (!sm_index, int_of_string s) :: !tx_words)
      , "WORD TX word for --sm" )
    ; "--pins", Arg.String (fun s -> pin_events := parse_pins s :: !pin_events), "C:V pads"
    ; ( "--init-instr"
      , Arg.String (fun s -> init_instrs := int_of_string ("0x" ^ s) :: !init_instrs)
      , "HEX instruction for --sm" )
    ; "--at", Arg.String (fun s -> events := parse_at s :: !events), "EVENT per-cycle event"
    ; "--vcd", Arg.String (fun s -> vcd_path := Some s), "FILE write VCD"
    ; "--trace", Arg.Set trace, " print pads per cycle"
    ]
    (fun _ -> failwith "unexpected argument")
    usage
;;

(* The config file: one object, or {"sms": [...]}. Each SM entry may name "sm". *)
type sm_setup =
  { index : int
  ; clkdiv : int option
  ; execctrl : int option
  ; shiftctrl : int option
  ; pinctrl : int option
  ; enable : bool
  ; entry : int
  }

let read_config path =
  let j = Yojson.Safe.from_file path in
  let open Yojson.Safe.Util in
  let num k o =
    match member k o with
    | `Null -> None
    | `Int n -> Some n
    | `String s -> Some (int_of_string s)
    | _ -> failwith ("bad value for " ^ k)
  in
  let one o default_index =
    { index = (match member "sm" o with `Int n -> n | _ -> default_index)
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
    | _ -> [ one j !sm_index ]
  in
  setups, sync
;;

let () =
  let prog = Pioasm_json.load ?which:!program_name !program_path in
  let t = Pgsim.create () in
  Pgsim.load_program t prog.Pioasm_json.words;
  let base = Pioasm_json.apply_to_config prog Pgsim.Config.reset in
  let setups, sync =
    match !config_path with
    | None -> [ { index = !sm_index; clkdiv = None; execctrl = None; shiftctrl = None;
                  pinctrl = None; enable = true; entry = 0 } ], None
    | Some p -> read_config p
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
  (* Host setup before cycle 0, in capture.py's order: TX words, init instructions,
     entry jumps, then the enables. *)
  List.iter (fun (sm, w) -> Pgsim.write_tx t sm w) (List.rev !tx_words);
  List.iter
    (fun w ->
      Pgsim.write_instr t !sm_index w;
      ignore (Pgsim.step t))
    (List.rev !init_instrs);
  List.iter
    (fun s ->
      if s.entry <> 0
      then (
        Pgsim.write_instr t s.index s.entry;
        ignore (Pgsim.step t)))
    setups;
  List.iter (fun s -> Pgsim.set_enabled t s.index s.enable) setups;
  let pending_pins = ref (List.sort compare !pin_events) in
  let pending_events = ref (List.stable_sort (fun (a, _) (b, _) -> compare a b) (List.rev !events)) in
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
         | Pad (n, v) ->
           let m = 1 lsl n in
           t.Pgsim.ext <- (if v = 1 then t.Pgsim.ext lor m else t.Pgsim.ext land lnot m)
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
       if !trace then Printf.printf "%d %08x\n" cyc pad
     done);
  if !trace || !vcd_path <> None
  then (
    let d = Pgsim.debug t !sm_index in
    Printf.eprintf
      "sm%d pc=%d x=%08x y=%08x isr=%08x/%d osr=%08x/%d tx=%d rx=%d stall=%s illegal=%b\n"
      !sm_index d.Pgsim.pc d.Pgsim.x d.Pgsim.y d.Pgsim.isr d.Pgsim.isr_count d.Pgsim.osr
      d.Pgsim.osr_count d.Pgsim.tx_level d.Pgsim.rx_level (Pgsim.stall_name d.Pgsim.stall)
      d.Pgsim.illegal)
;;
