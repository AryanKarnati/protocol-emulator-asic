(* pgsim: run a PIO program in the golden model with pin and TX stimulus.

   pgsim --program prog.json [--config cfg.json] [--sm N] [--cycles N]
         [--tx WORD]... [--pins CYCLE:VALUE]... [--init-instr HEX]...
         [--vcd FILE] [--trace] [--show-pins MASK]

   --program   pioasm -o json output (first program, or --name NAME).
   --config    JSON with the RP2040 register values, as hex strings or ints:
               {"clkdiv": "0x00010000", "execctrl": "0x0001f000",
                "shiftctrl": "0x000c0000", "pinctrl": "0x14000000",
                "sync_bypass": "0x0"}
               Missing keys keep the reset value, adjusted from the program's
               wrap and side-set fields.
   --tx        32-bit word pushed to the TX FIFO of --sm before cycle 0 (repeatable).
   --pins      external pad levels from CYCLE on (repeatable). VALUE is 32 bits.
   --init-instr an instruction written to SMx_INSTR before cycle 0 (repeatable),
               e.g. "e081" for set pindirs, 1. Each takes one cycle, not counted.
   --trace     print "cycle pad" for every cycle, pads in hex.
   --vcd       write a VCD of the pads and each SM's state. *)

let program_path = ref ""
let program_name = ref None
let config_path = ref None
let sm_index = ref 0
let cycles = ref 32
let tx_words = ref []
let pin_events = ref []
let init_instrs = ref []
let vcd_path = ref None
let trace = ref false

let usage = "pgsim --program FILE [options]"

let parse_int s = int_of_string s

let parse_pins s =
  match String.index_opt s ':' with
  | Some i ->
    (int_of_string (String.sub s 0 i), int_of_string (String.sub s (i + 1) (String.length s - i - 1)))
  | None -> failwith "--pins expects CYCLE:VALUE"
;;

let () =
  Arg.parse
    [ "--program", Arg.String (fun s -> program_path := s), "FILE pioasm JSON"
    ; "--name", Arg.String (fun s -> program_name := Some s), "NAME program in the file"
    ; "--config", Arg.String (fun s -> config_path := Some s), "FILE register JSON"
    ; "--sm", Arg.Set_int sm_index, "N state machine to run (default 0)"
    ; "--cycles", Arg.Set_int cycles, "N cycles to run (default 32)"
    ; "--tx", Arg.String (fun s -> tx_words := parse_int s :: !tx_words), "WORD TX word"
    ; "--pins", Arg.String (fun s -> pin_events := parse_pins s :: !pin_events), "C:V pads from cycle C"
    ; ( "--init-instr"
      , Arg.String (fun s -> init_instrs := parse_int ("0x" ^ s) :: !init_instrs)
      , "HEX instruction written to SMx_INSTR" )
    ; "--vcd", Arg.String (fun s -> vcd_path := Some s), "FILE write VCD"
    ; "--trace", Arg.Set trace, " print pads per cycle"
    ]
    (fun _ -> failwith "unexpected argument")
    usage
;;

let () =
  if !program_path = "" then (prerr_endline usage; exit 2)
;;

let read_config path =
  let j = Yojson.Safe.from_file path in
  let open Yojson.Safe.Util in
  let get k =
    match j |> member k with
    | `Null -> None
    | `Int n -> Some n
    | `String s -> Some (int_of_string s)
    | _ -> failwith ("bad value for " ^ k)
  in
  get "clkdiv", get "execctrl", get "shiftctrl", get "pinctrl", get "sync_bypass"
;;

let () =
  let prog = Pioasm_json.load ?which:!program_name !program_path in
  let t = Pgsim.create () in
  Pgsim.load_program t prog.Pioasm_json.words;
  (* Start from reset, then apply what the program's JSON says (wrap, side-set). *)
  let c = Pgsim.Config.reset in
  let c =
    { c with
      Pgsim.Config.wrap_top = prog.Pioasm_json.wrap
    ; wrap_bottom = prog.Pioasm_json.wrap_target
    }
  in
  let c =
    match prog.Pioasm_json.sideset with
    | None -> c
    | Some (size, optional, pindirs) ->
      { c with
        Pgsim.Config.sideset_count = size + Bool.to_int optional
      ; side_en = optional
      ; side_pindir = pindirs
      }
  in
  let c =
    match !config_path with
    | None -> c
    | Some path ->
      let clkdiv, execctrl, shiftctrl, pinctrl, sync_bypass = read_config path in
      let reg o default = Option.value o ~default in
      let base =
        Pgsim.Config.of_registers
          ~clkdiv:(reg clkdiv (Pgsim.Config.clkdiv_register c))
          ~execctrl:(reg execctrl (Pgsim.Config.execctrl_register c))
          ~shiftctrl:(reg shiftctrl (Pgsim.Config.shiftctrl_register c))
          ~pinctrl:(reg pinctrl (Pgsim.Config.pinctrl_register c))
      in
      (match sync_bypass with
       | Some b -> t.Pgsim.sync_bypass <- b
       | None -> ());
      base
  in
  Pgsim.set_config t !sm_index c;
  (* Host setup before cycle 0: TX words, then forced instructions. *)
  List.iter (fun w -> Pgsim.write_tx t !sm_index w) (List.rev !tx_words);
  List.iter
    (fun w ->
      Pgsim.write_instr t !sm_index w;
      ignore (Pgsim.step t))
    (List.rev !init_instrs);
  Pgsim.set_enabled t !sm_index true;
  let events = List.sort compare !pin_events in
  let pending = ref events in
  let step_cycle cyc =
    (* Apply pad events due at this cycle. *)
    let rec apply () =
      match !pending with
      | (c, v) :: rest when c <= cyc ->
        t.Pgsim.ext <- v;
        pending := rest;
        apply ()
      | _ -> ()
    in
    apply ();
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
    Printf.eprintf "sm%d pc=%d x=%08x y=%08x isr=%08x/%d osr=%08x/%d tx=%d rx=%d stall=%s illegal=%b\n"
      !sm_index d.Pgsim.pc d.Pgsim.x d.Pgsim.y d.Pgsim.isr d.Pgsim.isr_count d.Pgsim.osr
      d.Pgsim.osr_count d.Pgsim.tx_level d.Pgsim.rx_level (Pgsim.stall_name d.Pgsim.stall)
      d.Pgsim.illegal)
;;
