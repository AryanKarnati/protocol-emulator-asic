(* Compare a silicon trace (silicon-ref/capture.py and trace.py format, JSON lines) with
   pgsim.

   The silicon sampler reads the pads once per sysclk cycle. Sample k is the level of GPIO
   pins_base+j in bit j, for the sysclk cycle k after the start write (silicon-ref README,
   "Sample order"). pgsim is set up from the header and run from its enable (cycle 0), and
   its pad levels are compared with the samples. [latency] is the input and output delay
   measured by the calibration run (README, "Calibration"). It is required and never
   guessed. Sample k is compared with pgsim cycle k - latency. The first [latency] samples
   have no pgsim counterpart. They are reported, not skipped silently.

   Header fields read (capture.py writes them; checked against silicon-ref/capture.py on
   main):
     program.words        "0x%04x" strings, the instructions at offset 0
     program.entry        the first instruction to run, forced by a jmp before enable
     program.pio_version  must be 0
     program.registers    CLKDIV, EXECCTRL, SHIFTCTRL, PINCTRL, RP2350 layout (see below)
     program.init.levels  {"<gpio>": 0|1}, applied as the pin output level
     program.init.dirs    {"<gpio>": 0|1}, applied as the pin direction
     program.init.tx_words  "0x%08x" strings, written to the TX FIFO before enable
     capture.pins_base, capture.pins_count, capture.sm

   The traces come from a Pico 2, which is an RP2350. Its registers differ from the RP2040
   layout only in EXECCTRL STATUS_SEL and STATUS_N, which is converted here. Every other
   field the loader reads has the same bit positions in both (checked against the RP2350
   pio.h in the pico-sdk cache). *)

module Y = Yojson.Safe
module U = Yojson.Safe.Util

type mismatch =
  { sample : int
  ; pin : int (* capture pin index j; GPIO = pins_base + j *)
  ; silicon : int
  ; model : int
  }

type result =
  { samples : int
  ; compared : int
  ; skipped_head : int list (* the first [latency] sample values, not compared *)
  ; first_mismatch : mismatch option
  }

exception Bad_trace of string

let bad fmt = Printf.ksprintf (fun s -> raise (Bad_trace s)) fmt

let hex_int = function
  | `String s ->
    (match int_of_string_opt s with
     | Some n -> n
     | None -> bad "not a number: %S" s)
  | `Int n -> n
  | j -> bad "expected a hex string or an integer, got %s" (Y.to_string j)
;;

let member k j =
  match U.member k j with
  | `Null -> bad "missing key %S" k
  | v -> v
;;

(* ------------------------------------------------------------------------------------ *)
(* RP2350 EXECCTRL to the model's (RP2040-layout) configuration.

   RP2350 (pio.h): STATUS_SEL bits 6:5 (0 TXLEVEL, 1 RXLEVEL, 2 IRQ), STATUS_N bits 4:0.
   RP2040: STATUS_SEL bit 4 (1 = RX), STATUS_N bits 3:0. The IRQ status source and levels
   above 15 are not representable in the model, so they fail. *)
let rp2350_execctrl_to_rp2040 execctrl =
  let sel = (execctrl lsr 5) land 3 in
  let n = execctrl land 31 in
  if sel = 2 then bad "EXECCTRL.STATUS_SEL = IRQ (2): not modelled";
  if sel = 3 then bad "EXECCTRL.STATUS_SEL = 3: reserved";
  if n > 15 then bad "EXECCTRL.STATUS_N = %d: the model holds 0..15" n;
  (* Clear the RP2350-only status bits, then write the RP2040 positions. *)
  let kept = execctrl land lnot 0x7F land 0xFFFF_FFFF in
  kept lor (if sel = 1 then 0x10 else 0) lor n
;;

(* SHIFTCTRL bits 15:14 are RP2350 FJOIN_RX_PUT/GET (for DMA-style joined access). The
   model does not have them, so they must be zero. *)
let rp2350_shiftctrl_check shiftctrl =
  if (shiftctrl lsr 14) land 3 <> 0
  then bad "SHIFTCTRL.FJOIN_RX_PUT/GET set: not modelled"
;;

let config_of_registers regs =
  let get name =
    match U.member name regs with
    | `Null -> bad "program.registers.%s missing" name
    | v -> hex_int v
  in
  let clkdiv = get "clkdiv" in
  let execctrl = get "execctrl" in
  let shiftctrl = get "shiftctrl" in
  let pinctrl = get "pinctrl" in
  rp2350_shiftctrl_check shiftctrl;
  Pgsim.Config.of_registers
    ~clkdiv
    ~execctrl:(rp2350_execctrl_to_rp2040 execctrl)
    ~shiftctrl
    ~pinctrl
;;

(* ------------------------------------------------------------------------------------ *)
(* Initial state: levels and dirs are dicts of GPIO number (a string) to 0 or 1. *)

let pin_dict name j =
  match j with
  | `Assoc kvs ->
    List.map
      (fun (k, v) ->
        let pin =
          match int_of_string_opt k with
          | Some p when p >= 0 && p <= 31 -> p
          | _ -> bad "%s: key %S is not a GPIO number 0..31" name k
        in
        let b =
          match v with
          | `Int 0 -> 0
          | `Int 1 -> 1
          | _ -> bad "%s: pin %d value must be 0 or 1, got %s" name pin (Y.to_string v)
        in
        pin, b)
      kvs
  | _ -> bad "%s must be an object, got %s" name (Y.to_string j)
;;

let apply_init (t : Pgsim.t) (init : Y.t) =
  let levels = pin_dict "init.levels" (member "levels" init) in
  let dirs = pin_dict "init.dirs" (member "dirs" init) in
  List.iter
    (fun (pin, b) ->
      let m = 1 lsl pin in
      t.Pgsim.pin_level <- (if b = 1 then t.Pgsim.pin_level lor m else t.Pgsim.pin_level land lnot m))
    levels;
  List.iter
    (fun (pin, b) ->
      let m = 1 lsl pin in
      t.Pgsim.pin_dir <- (if b = 1 then t.Pgsim.pin_dir lor m else t.Pgsim.pin_dir land lnot m))
    dirs;
  let tx =
    match member "tx_words" init with
    | `List l -> List.map hex_int l
    | j -> bad "init.tx_words must be a list, got %s" (Y.to_string j)
  in
  let depth = t.Pgsim.sms.(0).Pgsim.tx.Pgsim.Fifo.depth in
  if List.length tx > depth
  then bad "init.tx_words has %d words, the TX FIFO holds %d" (List.length tx) depth;
  List.iter
    (fun w ->
      if w < 0 || w > 0xFFFF_FFFF then bad "init.tx_words: %#x is not 32 bits" w;
      Pgsim.write_tx t 0 w)
    tx
;;

(* ------------------------------------------------------------------------------------ *)
(* Reading the file. *)

let read_records path =
  let ic = open_in path in
  let rec loop acc =
    match input_line ic with
    | exception End_of_file ->
      close_in ic;
      List.rev acc
    | line -> if String.trim line = "" then loop acc else loop (Y.from_string line :: acc)
  in
  loop []
;;

(* A trace read and set up for pgsim: the model is configured, init applied, the entry
   jump executed, and the SM enabled (cycle 0 is the first step after enable). *)
type loaded =
  { model : Pgsim.t
  ; samples : int array
  ; pins_base : int
  ; pins_count : int
  ; entry : int
  ; name : string
  }

let load path : loaded =
  let recs = read_records path in
  let header =
    match recs with
    | h :: _ when U.member "record" h = `String "header" -> h
    | _ -> bad "first record must be the header"
  in
  (match U.member "format" header with
   | `String "polyglot-pio-silicon-trace" -> ()
   | j -> bad "unknown format %s" (Y.to_string j));
  (match U.member "version" header with
   | `Int 1 -> ()
   | j -> bad "unsupported version %s" (Y.to_string j));
  let footer = List.find_opt (fun r -> U.member "record" r = `String "footer") recs in
  (match footer with
   | Some f when U.member "complete" f = `Bool true -> ()
   | _ -> bad "no complete footer: the capture did not finish");
  let words =
    List.concat_map
      (fun r ->
        if U.member "record" r = `String "words"
        then List.map hex_int (U.to_list (member "words" r))
        else [])
      recs
    |> Array.of_list
  in
  (match footer with
   | Some f ->
     if U.to_int (member "words_total" f) <> Array.length words
     then bad "footer words_total does not match the word blocks";
     if U.to_int (member "samples_total" f) <> 4 * Array.length words
     then bad "footer samples_total does not match the word blocks"
   | None -> ());
  let samples =
    Array.init (4 * Array.length words) (fun k -> (words.(k / 4) lsr (8 * (k mod 4))) land 0xFF)
  in
  let cap = member "capture" header in
  let pins_base = U.to_int (member "pins_base" cap) in
  let pins_count = U.to_int (member "pins_count" cap) in
  if U.to_int (member "bits_per_sample" cap) <> 8 then bad "only 8-bit samples are handled";
  let prog = member "program" header in
  if U.to_int (member "pio_version" prog) <> 0 then bad "program.pio_version must be 0";
  let prog_words =
    U.to_list (member "words" prog) |> List.map hex_int |> List.map (fun w -> w land 0xFFFF)
  in
  if prog_words = [] then bad "program.words is empty";
  let entry = U.to_int (member "entry" prog) in
  if entry < 0 || entry >= List.length prog_words then
    bad "program.entry %d is outside the %d-word program" entry (List.length prog_words);
  let cfg = config_of_registers (member "registers" prog) in
  let t = Pgsim.create () in
  Pgsim.load_program t prog_words;
  Pgsim.set_config t 0 cfg;
  apply_init t (member "init" prog);
  (* jmp entry, written to SM0_INSTR before enable (capture.py step 9). Its cycle is not a
     sample cycle, so it is one step before the enable. *)
  Pgsim.write_instr t 0 (0x0000 lor entry);
  ignore (Pgsim.step t);
  Pgsim.set_enabled t 0 true;
  { model = t
  ; samples
  ; pins_base
  ; pins_count
  ; entry
  ; name = U.to_string (member "name" prog)
  }
;;

(* Compare the loaded samples with pgsim's pads. [latency] must be given. *)
let compare ?(latency = 0) (l : loaded) : result =
  if latency < 0 then bad "latency must be >= 0";
  let n = Array.length l.samples in
  let pads = Array.init n (fun _ -> Pgsim.step l.model) in
  let skipped = List.init (min latency n) (fun k -> l.samples.(k)) in
  let first = ref None in
  let compared = ref 0 in
  for k = latency to n - 1 do
    let c = k - latency in
    incr compared;
    for j = 0 to l.pins_count - 1 do
      if !first = None
      then (
        let silicon = (l.samples.(k) lsr j) land 1 in
        let model = (pads.(c) lsr (l.pins_base + j)) land 1 in
        if silicon <> model then first := Some { sample = k; pin = j; silicon; model })
    done
  done;
  { samples = n; compared = !compared; skipped_head = skipped; first_mismatch = !first }
;;

let compare_files ?(latency = 0) path = compare ~latency (load path)
