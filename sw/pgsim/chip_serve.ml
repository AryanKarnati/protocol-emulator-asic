(* pgsim chip-serve: the whole-chip model behind a line protocol (docs/chip.md section 12).
   The host library drives it with frames and pad levels, and reads the pins back. Each
   command is one line on stdin and gets one reply line on stdout. *)

type server =
  { chip : Chip.t
  ; sck_half : int
  ; cs_setup : int
  ; cs_gap : int
  ; mutable ext_ui : int (** ui_in[4:0], the external level *)
  ; mutable ext_uio : int (** the external level of each uio pad *)
  }

let usage =
  "pgsim chip-serve [--num-sms N] [--sck-half H] [--cs-setup S] [--cs-gap G]\n\
   commands: xfer HEX | run N | ext UI UIO | pads | cycle | quit"

let create ~num_sms ~sck_half ~cs_setup ~cs_gap =
  { chip = Chip.create ~num_sms ()
  ; sck_half
  ; cs_setup
  ; cs_gap
  ; ext_ui = 0
  ; ext_uio = 0
  }
;;

(* One cycle with the given SCK, MOSI and CS_N pins. Returns the chip's outputs of the cycle. *)
let drive s ~sck ~mosi ~csn =
  let ui_in = (csn lsl 7) lor (mosi lsl 6) lor (sck lsl 5) lor (s.ext_ui land 0x1F) in
  Chip.step s.chip ~ui_in ~uio_ext:s.ext_uio
;;

let idle_cycles s n =
  for _ = 1 to n do
    ignore (drive s ~sck:0 ~mosi:0 ~csn:1)
  done
;;

(* Clock the bits of a frame, CS_N low, with SCK high and low phases of [sck_half] cycles and
   MOSI changed in the low phase (chip.md 6.6). Returns the MISO value sampled in the first
   cycle of each SCK high phase. [cs_setup] cycles with SCK low come before the first bit, and
   [cs_gap] cycles with CS_N high after the last. *)
let frame_bits s (bits : int array) : int array =
  let h = s.sck_half in
  let n = Array.length bits in
  let samples = Array.make n 0 in
  let first = if n > 0 then bits.(0) else 0 in
  for _ = 1 to s.cs_setup do
    ignore (drive s ~sck:0 ~mosi:first ~csn:0)
  done;
  for j = 0 to n - 1 do
    for c = 0 to h - 1 do
      let o = drive s ~sck:1 ~mosi:bits.(j) ~csn:0 in
      if c = 0 then samples.(j) <- o.Chip.miso
    done;
    let next = if j + 1 < n then bits.(j + 1) else 0 in
    for _ = 1 to h do
      ignore (drive s ~sck:0 ~mosi:next ~csn:0)
    done
  done;
  idle_cycles s s.cs_gap;
  samples
;;

(* One frame of whole bytes (chip.md 6.3 layout is the caller's). Returns the MISO byte of each
   byte sent, MSB first. *)
let frame s (bytes : int list) : int list =
  let bits =
    List.concat_map (fun b -> List.init 8 (fun k -> (b lsr (7 - k)) land 1)) bytes |> Array.of_list
  in
  let samples = frame_bits s bits in
  List.init (List.length bytes) (fun i ->
    let v = ref 0 in
    for k = 0 to 7 do
      v := (!v lsl 1) lor samples.((8 * i) + k)
    done;
    !v)
;;

let hex_of_bytes bs = String.concat "" (List.map (Printf.sprintf "%02x") bs)

let bytes_of_hex s : int list option =
  let n = String.length s in
  if n mod 2 <> 0
  then None
  else (
    try
      Some (List.init (n / 2) (fun i -> int_of_string ("0x" ^ String.sub s (2 * i) 2)))
    with
    | Failure _ -> None)
;;

let parse_hex s = try Some (int_of_string ("0x" ^ s)) with Failure _ -> None

(* One command, as one reply line, and whether the server goes on. *)
let command s (line : string) : string * bool =
  let words = String.split_on_char ' ' (String.trim line) |> List.filter (fun w -> w <> "") in
  match words with
  | [ "quit" ] -> "ok", false
  | [ "reset" ] ->
    Chip.reset s.chip;
    "ok", true
  | "run" :: [ _ ] | "run" :: _ when List.length words <> 2 -> "err run takes one count argument", true
  | "ext" :: _ when List.length words <> 3 -> "err ext takes two hex arguments", true
  | [ "cycle" ] -> Printf.sprintf "ok %d" (Chip.cycle s.chip), true
  | "xfer" :: [ hex ] ->
    (match bytes_of_hex hex with
     | None -> "err xfer needs an even number of hex digits", true
     | Some bytes -> "ok " ^ hex_of_bytes (frame s bytes), true)
  | "xfer" :: _ -> "err xfer takes one hex argument", true
  | [ "run"; n ] ->
    (match int_of_string_opt n with
     | Some n when n >= 0 ->
       idle_cycles s n;
       "ok", true
     | _ -> "err run needs a count of cycles", true)
  | [ "ext"; ui; uio ] ->
    (match parse_hex ui, parse_hex uio with
     | Some ui, Some uio when ui >= 0 && ui <= 0xFF && uio >= 0 && uio <= 0xFF ->
       s.ext_ui <- ui land 0x1F;
       s.ext_uio <- uio;
       "ok", true
     | _ -> "err ext needs two hex bytes", true)
  | [ "pads" ] ->
    let o = Chip.peek s.chip ~ui_in:((1 lsl 7) lor (s.ext_ui land 0x1F)) ~uio_ext:s.ext_uio in
    Printf.sprintf "ok %02x %02x %02x" o.Chip.uo_out o.Chip.uio_out o.Chip.uio_oe, true
  | [] -> "err empty command", true
  | w :: _ -> Printf.sprintf "err unknown command %s" w, true
;;

(* Parse the options and serve stdin. *)
let main ?(input = stdin) ?(output = stdout) (argv : string array) : int =
  let num_sms = ref 4 and sck_half = ref 3 and cs_setup = ref 4 and cs_gap = ref 4 in
  let rec opts = function
    | [] -> Ok ()
    | "--num-sms" :: v :: rest ->
      (match int_of_string_opt v with
       | Some n when n >= 1 && n <= 4 ->
         num_sms := n;
         opts rest
       | _ -> Error "--num-sms takes 1 to 4")
    | "--sck-half" :: v :: rest ->
      (match int_of_string_opt v with
       | Some n when n >= 1 ->
         sck_half := n;
         opts rest
       | _ -> Error "--sck-half takes 1 or more")
    | "--cs-setup" :: v :: rest ->
      (match int_of_string_opt v with
       | Some n when n >= 1 ->
         cs_setup := n;
         opts rest
       | _ -> Error "--cs-setup takes 1 or more")
    | "--cs-gap" :: v :: rest ->
      (match int_of_string_opt v with
       | Some n when n >= 1 ->
         cs_gap := n;
         opts rest
       | _ -> Error "--cs-gap takes 1 or more")
    | x :: _ -> Error ("unknown option " ^ x)
  in
  match opts (List.tl (Array.to_list argv)) with
  | Error reason ->
    Printf.eprintf "%s\n%s\n" reason usage;
    flush stderr;
    2
  | Ok () ->
    let s = create ~num_sms:!num_sms ~sck_half:!sck_half ~cs_setup:!cs_setup ~cs_gap:!cs_gap in
    let rec loop () =
      match In_channel.input_line input with
      | None -> 0
      | Some line ->
        let reply, go_on = command s line in
        Printf.fprintf output "%s\n" reply;
        flush output;
        if go_on then loop () else 0
    in
    loop ()
;;
