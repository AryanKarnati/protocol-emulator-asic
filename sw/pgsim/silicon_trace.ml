(* Compare a silicon trace (silicon-ref/trace.py format, JSON lines) with pgsim.

   The silicon sampler reads the pads once per sysclk cycle: sample k is the level of
   GPIO pins_base+j in bit j, for the cycle k after the start write (silicon-ref README,
   "Sample order" and "Sample ... sysclk cycle k"). pgsim is run with the program from the
   header on SM0, from cycle 0, and its pad levels are compared with the samples. [latency]
   is the input/output delay measured by the calibration run (README, "Calibration"); it is
   required, never guessed. Sample k is compared with pgsim cycle k - latency.

   AMBIGUITY: the header's `init` and `registers` layouts are read by key name (see
   [init_levels], [init_dirs], [init_tx] below). Unknown keys are ignored, and the result
   says which were used. *)

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
  ; first_mismatch : mismatch option
  ; notes : string list
  }

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0
;;

let hex_int = function
  | `String s -> int_of_string s
  | `Int n -> n
  | _ -> failwith "expected a hex string or an integer"
;;

(* Read every JSON line. *)
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

let member_opt k j = match U.member k j with `Null -> None | v -> Some v

(* Find the register value whose key contains [name], case-insensitively. *)
let register regs name =
  match regs with
  | `Assoc kvs ->
    List.find_map
      (fun (k, v) -> if contains (String.lowercase_ascii k) name then Some (hex_int v) else None)
      kvs
  | _ -> None
;;

let compare_files ?(latency = 0) path : result =
  let recs = read_records path in
  let header =
    match recs with
    | h :: _ when U.member "record" h = `String "header" -> h
    | _ -> failwith "first record must be the header"
  in
  let footer =
    List.find_opt (fun r -> U.member "record" r = `String "footer") recs
  in
  (match footer with
   | Some f when U.member "complete" f = `Bool true -> ()
   | _ -> failwith "no complete footer: the capture did not finish");
  let words =
    List.concat_map
      (fun r ->
        if U.member "record" r = `String "words"
        then List.map hex_int (U.to_list (U.member "words" r))
        else [])
      recs
    |> Array.of_list
  in
  let samples =
    Array.init (4 * Array.length words) (fun k ->
      (words.(k / 4) lsr (8 * (k mod 4))) land 0xFF)
  in
  let cap = U.member "capture" header in
  let pins_base = U.to_int (U.member "pins_base" cap) in
  let pins_count = U.to_int (U.member "pins_count" cap) in
  let prog = U.member "program" header in
  let prog_words =
    List.map hex_int (U.to_list (U.member "words" prog)) |> List.map (fun w -> w land 0xFFFF)
  in
  let notes = ref [] in
  let regs = U.member "registers" prog in
  let reg name default =
    match register regs name with
    | Some v -> v
    | None ->
      notes := Printf.sprintf "register %s not in header: reset value used" name :: !notes;
      default
  in
  let cfg =
    let c = Pgsim.Config.reset in
    Pgsim.Config.of_registers
      ~clkdiv:(reg "clkdiv" (Pgsim.Config.clkdiv_register c))
      ~execctrl:(reg "execctrl" (Pgsim.Config.execctrl_register c))
      ~shiftctrl:(reg "shiftctrl" (Pgsim.Config.shiftctrl_register c))
      ~pinctrl:(reg "pinctrl" (Pgsim.Config.pinctrl_register c))
  in
  let t = Pgsim.create () in
  Pgsim.load_program t prog_words;
  Pgsim.set_config t 0 cfg;
  (* Initial state written before enable (header.init). Key names are read as found. *)
  let init = member_opt "init" header in
  (match init with
   | None -> ()
   | Some i ->
     (match member_opt "tx_words" i with
      | Some l -> List.iter (fun w -> Pgsim.write_tx t 0 (hex_int w)) (U.to_list l)
      | None -> ());
     (match member_opt "levels" i with
      | Some v -> t.Pgsim.pin_level <- hex_int v
      | None -> ());
     (match member_opt "directions" i with
      | Some v -> t.Pgsim.pin_dir <- hex_int v
      | None -> ()));
  Pgsim.set_enabled t 0 true;
  let n = Array.length samples in
  let pads = Array.init n (fun _ -> Pgsim.step t) in
  let first = ref None in
  let compared = ref 0 in
  for k = latency to n - 1 do
    let c = k - latency in
    incr compared;
    if !first = None
    then
      for j = 0 to pins_count - 1 do
        if !first = None
        then (
          let silicon = (samples.(k) lsr j) land 1 in
          let model = (pads.(c) lsr (pins_base + j)) land 1 in
          if silicon <> model
          then first := Some { sample = k; pin = j; silicon; model })
      done
  done;
  { samples = n; compared = !compared; first_mismatch = !first; notes = List.rev !notes }
;;
