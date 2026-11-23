(* Closed-loop co-simulation plant for the host library's PIO SPI master.

   pgsim runs the master program at the RP2350 system clock (120 MHz). The whole-chip model
   runs at 60 MHz (one chip cycle every two system cycles, with a clock phase). The pads are
   wired: SCK, MOSI and CS_N from the PIO's pads 6, 7 and 8 (GPIO 22 to 24) into the chip's
   ui_in, and the chip's MISO into the PIO's pad 24 (GPIO 40). Board delays are sysclk cycles,
   and the input path is pgsim's (2-flop synchroniser, or bypass).

   The Python side (sw/host/cosim/plant.py) drives the RP2350 FIFOs through this plant and
   advances time by a host API cost per call. Commands, one per line on stdin:
     adv N    advance N system cycles, reply "ok"
     tx W     push W to TX FIFO 0 if it has room, reply "ok 1" or "ok 0"
     rx       pop RX FIFO 0, reply "ok V" (V = -1 if empty)
     lvl      reply "ok TX RX" (FIFO levels)
     cyc      reply "ok N" (system cycles so far)
     log      the chip's samples, one line each, then "ok"
     quit *)

let args = Array.to_list Sys.argv |> List.tl

let opt name default =
  let rec go = function
    | k :: v :: _ when k = name -> v
    | _ :: r -> go r
    | [] -> default
  in
  go args

let iopt name d = int_of_string (opt name (string_of_int d))
let words = opt "--words" "" |> String.split_on_char ',' |> List.filter (( <> ) "") |> List.map int_of_string
let clkdiv = iopt "--clkdiv" 0x20000
let execctrl = iopt "--execctrl" 0x1F000
let shiftctrl = iopt "--shiftctrl" 0x10830000
let pinctrl = iopt "--pinctrl" 0
let phase = iopt "--phase" 0 (* the system cycle parity on which the chip steps *)
let dsck = iopt "--dsck" 0 (* board delay, pins to chip, in system cycles *)
let dmiso = iopt "--dmiso" 0 (* board delay, chip to pins, in system cycles *)
let bypass = iopt "--bypass" 0 (* INPUT_SYNC_BYPASS for the pads *)
let trace = opt "--trace" "" <> ""
let sck_pad = 6
let mosi_pad = 7
let cs_pad = 8
let miso_pad = 24

let pg = Pgsim.create ()
let chip = Chip.create ~num_sms:4 ()

let () =
  Pgsim.load_program pg words;
  Pgsim.set_config pg 0 (Pgsim.Config.of_registers ~clkdiv ~execctrl ~shiftctrl ~pinctrl);
  pg.Pgsim.sync_bypass <- bypass;
  pg.Pgsim.ext <- 0;
  (* The library's init: pindirs for SCK, MOSI and CS_N, then CS_N high. *)
  Pgsim.write_instr pg 0 0xE087;
  ignore (Pgsim.step pg);
  Pgsim.write_instr pg 0 0xE004;
  ignore (Pgsim.step pg);
  Pgsim.clkdiv_restart pg 0xF;
  Pgsim.set_enabled pg 0 true

let cyc = ref 0
let hist_h = Array.make 64 (0, 1, 0) (* (sck, csn, mosi) of each system cycle, for dsck *)
let miso_hist = Array.make 64 0
let chip_miso = ref 0
let log = Buffer.create 4096

(* One system cycle: the PIO runs, then the chip steps on its phase, then MISO reaches the pad. *)
let step () =
  let pad = Pgsim.step pg in
  let b n = (pad lsr n) land 1 in
  hist_h.(!cyc land 63) <- (b sck_pad, b cs_pad, b mosi_pad);
  let sck, csn, mosi = hist_h.((!cyc - dsck) land 63) in
  if (!cyc - phase) land 1 = 0 then begin
    let ui_in = (csn lsl 7) lor (mosi lsl 6) lor (sck lsl 5) in
    let o = Chip.step chip ~ui_in ~uio_ext:0 in
    chip_miso := o.Chip.miso;
    if trace then
      Buffer.add_string log (Printf.sprintf "%d %d %d %d %d\n" !cyc sck csn mosi o.Chip.miso)
  end;
  miso_hist.(!cyc land 63) <- !chip_miso;
  let m = miso_hist.((!cyc - dmiso) land 63) in
  pg.Pgsim.ext <- (if m = 1 then 1 lsl miso_pad else 0);
  incr cyc

let advance k =
  for _ = 1 to k do
    step ()
  done

let level () =
  let d = Pgsim.debug pg 0 in
  (d.Pgsim.tx_level, d.Pgsim.rx_level)

let () =
  try
    while true do
      (* The last reply must leave before the next command is read. *)
      flush stdout;
      let line = input_line stdin in
      match String.split_on_char ' ' (String.trim line) with
      | [ "adv"; n ] ->
        advance (int_of_string n);
        print_string "ok\n"
      | [ "tx"; w ] ->
        let tx, _ = level () in
        if tx < 4 then begin
          Pgsim.write_tx pg 0 (int_of_string w);
          print_string "ok 1\n"
        end
        else print_string "ok 0\n"
      | [ "rx" ] ->
        let v = match Pgsim.read_rx pg 0 with Some v -> v | None -> -1 in
        Printf.printf "ok %d\n" v
      | [ "lvl" ] ->
        let tx, rx = level () in
        Printf.printf "ok %d %d\n" tx rx
      | [ "cyc" ] -> Printf.printf "ok %d\n" !cyc
      | [ "log" ] ->
        print_string (Buffer.contents log);
        print_string "ok\n"
      | [ "quit" ] -> raise End_of_file
      | _ -> print_string "err\n"
    done
  with End_of_file -> ()
