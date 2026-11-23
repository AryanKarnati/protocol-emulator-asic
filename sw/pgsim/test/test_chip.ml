(* Directed checks of the whole-chip model (docs/chip.md). The expectations are derived from the
   contract, by hand, and the tests drive the pins as a host would. *)

let check name cond = if not cond then failwith ("FAILED: " ^ name)
let enc = Polyglot_isa.Isa.encode

(* Bits of a frame, MSB first, from bytes. *)
let bits_of_bytes bytes =
  List.concat_map (fun b -> List.init 8 (fun k -> (b lsr (7 - k)) land 1)) bytes |> Array.of_list
;;

let word_bytes w = [ (w lsr 24) land 0xFF; (w lsr 16) land 0xFF; (w lsr 8) land 0xFF; w land 0xFF ]

(* Command byte, address and data of one access (chip.md 6.3). F = 0 unless [fixed]. *)
let cmd ~read ~fixed = (if read then 0x80 else 0) lor (if fixed then 0x40 else 0)
let addr_bytes a = [ (a lsr 8) land 0xFF; a land 0xFF ]

let write_frame s ?(cut = max_int) addr data =
  let bits = bits_of_bytes ([ cmd ~read:false ~fixed:false ] @ addr_bytes addr @ word_bytes data) in
  let bits = Array.sub bits 0 (min cut (Array.length bits)) in
  ignore (Chip_serve.frame_bits s bits)
;;

let read_word s addr =
  let bytes = [ cmd ~read:true ~fixed:false ] @ addr_bytes addr @ [ 0 ] @ [ 0; 0; 0; 0 ] in
  let out = Chip_serve.frame s bytes in
  List.fold_left (fun acc b -> (acc lsl 8) lor b) 0 (List.filteri (fun i _ -> i >= 4) out)
;;

let server ?(num_sms = 4) () = Chip_serve.create ~num_sms ~sck_half:3 ~cs_setup:4 ~cs_gap:4

(* 6.3, 8.1: ID, HWCFG and a SCRATCH round trip. *)
let registers () =
  let s = server () in
  check "ID" (read_word s 0x000 = 0x504C_4754);
  check "HWCFG with 4 SMs and IMEM 64" (read_word s 0x004 = 0x1040_0404);
  check "HWCFG with 1 SM" (read_word (server ~num_sms:1 ()) 0x004 = 0x1040_0104);
  write_frame s 0x038 0xDEAD_BEEF;
  check "SCRATCH round trip" (read_word s 0x038 = 0xDEAD_BEEF);
  (* Reset values of the SM block (8.1). *)
  check "SM0 CLKDIV reset" (read_word s 0x200 = 0x0001_0000);
  check "SM0 EXECCTRL reset" (read_word s 0x204 = 0x0001_F000);
  check "SM3 PINCTRL reset" (read_word s (0x200 + (3 * 0x40) + 0x14) = 0x1400_0000);
  (* CTRL SM_RESTART and CLKDIV_RESTART read 0 (8.1). *)
  write_frame s 0x008 0x0000_0F0F;
  check "CTRL reads SM_ENABLE only" (read_word s 0x008 = 0x0F)
;;

(* Absent SMs read 0 and ignore writes (8.1). *)
let absent () =
  let s = server ~num_sms:1 () in
  write_frame s (0x200 + 0x40) 0x1234;
  check "absent SM1 CLKDIV reads 0" (read_word s (0x200 + 0x40) = 0);
  write_frame s 0x008 0xF;
  check "CTRL keeps only SM0 enable" (read_word s 0x008 = 1)
;;

(* 6.5, 6.6: the MISO cycles of a frame, from the pin cycles. For a rise of SCK in pin cycle c,
   the RISE is in cycle c + 2, and MISO shows the next bit from cycle c + 3. START at cycle 2 (CS_N
   fell at 0) loads STATUS 0xF0, visible from cycle 3. Rises at pin cycles 4, 8, ..., 24 each
   shift one bit out, so MISO(t) is STATUS[7 - k] where k counts the rises with c + 3 <= t. *)
let miso_cycles () =
  let chip = Chip.create () in
  let rises = [ 4; 8; 12; 16; 20; 24 ] in
  let sck_at c = if List.exists (fun r -> c >= r && c < r + 2) rises then 1 else 0 in
  let csn_at c = if c >= 0 && c < 30 then 0 else 1 in
  let miso =
    Array.init 30 (fun c ->
      let ui_in = (csn_at c lsl 7) lor (sck_at c lsl 5) in
      (Chip.step chip ~ui_in ~uio_ext:0).Chip.miso)
  in
  let expected t =
    if t < 3
    then 0
    else (
      let k = List.length (List.filter (fun r -> r + 3 <= t) rises) in
      if k < 8 then (0xF0 lsr (7 - k)) land 1 else 0)
  in
  Array.iteri
    (fun t m -> check (Printf.sprintf "MISO at cycle %d" t) (m = expected t))
    miso;
  check "MISO carries STATUS 1,1,1,1 then 0,0 at the sampling rises"
    (List.map (fun r -> miso.(r)) rises = [ 1; 1; 1; 1; 0; 0 ])
;;

(* 6.4: a write frame cut before bit 55 writes nothing; the full 56 bits write the word. *)
let frame_cut () =
  let s = server () in
  write_frame s ~cut:55 0x038 0xCAFE_BABE;
  check "cut mid-word does not write SCRATCH" (read_word s 0x038 = 0);
  write_frame s 0x038 0xCAFE_BABE;
  check "full word writes SCRATCH" (read_word s 0x038 = 0xCAFE_BABE)
;;

(* 6.2: a SCK rise in the cycle of START is not a rise. The frame after it is counted from its
   first real rise. *)
let rise_with_start () =
  let s = server () in
  ignore (Chip_serve.drive s ~sck:1 ~mosi:0 ~csn:0);
  write_frame s 0x038 0x1357_9BDF;
  check "a rise in the cycle of START is not counted" (read_word s 0x038 = 0x1357_9BDF)
;;

(* Pads (9.1, 9.2): PAD_IN reads the external level of an undriven uio pad. *)
let pad_readback () =
  let s = server () in
  ignore (Chip_serve.command s "ext 15 5a");
  let v = read_word s 0x02C in
  check "PAD_IN shows the uio level" (v land 0xFF = 0x5A);
  check "PAD_IN shows ui_in[4:0]" ((v lsr 16) land 0x1F = 0x15)
;;

(* Back-to-back frames with the minimum gap of 2 cycles of CS_N high (6.6, H-CS). *)
let back_to_back () =
  let s = Chip_serve.create ~num_sms:4 ~sck_half:3 ~cs_setup:4 ~cs_gap:2 in
  for _ = 1 to 5 do
    check "ID with gap 2" (read_word s 0x000 = 0x504C_4754)
  done
;;

(* RX: a program that pushes zeros fills RX FIFO 0. Then a read and its commit (6.4, 8.3). *)
let rx_setup () =
  let s = server () in
  (* SM0: push noblock; jmp 0. *)
  let push_nb = enc (Polyglot_isa.Isa.Push { delay_side = 0; if_full = false; block = false }) in
  let jmp0 = enc (Polyglot_isa.Isa.Jmp { delay_side = 0; cond = Polyglot_isa.Isa.Always; addr = 0 }) in
  write_frame s 0x100 push_nb;
  write_frame s 0x104 jmp0;
  write_frame s 0x008 1;
  (* Run enough cycles for four pushes to fill the RX FIFO, then stop the SM so the level holds. *)
  ignore (Chip_serve.command s "run 40");
  write_frame s 0x008 0;
  s
;;

let rx_level s = (read_word s 0x014 lsr 4) land 0xF

(* 6.4, 8.3: a read cut before its commit leaves the RX FIFO as it was. *)
let rx_read_cut () =
  let s = rx_setup () in
  let before = rx_level s in
  check "RX FIFO 0 is full before the read" (before = 4);
  (* 32 bits: the command, address and dummy byte. The read is at bit 31, and the frame stops there. *)
  let bits = bits_of_bytes ([ cmd ~read:true ~fixed:false ] @ addr_bytes 0x050 @ [ 0 ]) in
  ignore (Chip_serve.frame_bits s bits);
  check "read cut before commit: RX level unchanged" (rx_level s = before);
  (* One more bit: the commit at bit 32 pops the word. *)
  let bits = Array.append bits [| 0 |] in
  ignore (Chip_serve.frame_bits s bits);
  check "commit pops one word" (rx_level s = before - 1)
;;

(* 8.3: a burst of two reads of RX FIFO 0 (fixed address), stopped after the second read and
   before its commit. The second word is not popped, so it is not lost. *)
let rx_burst_stop () =
  let s = rx_setup () in
  let before = rx_level s in
  let fixed_read = bits_of_bytes ([ cmd ~read:true ~fixed:true ] @ addr_bytes 0x050 @ [ 0 ]) in
  (* 64 bits: the first read at bit 31 and its commit at bit 32; the second read at bit 63, with no
     commit. One word is popped and the second word is still in the FIFO. *)
  ignore (Chip_serve.frame_bits s (Array.append fixed_read (Array.make 32 0)));
  check "burst stopped at the second read: one word popped" (rx_level s = before - 1);
  (* 65 bits: pops the word the stop left (commit at bit 32), then the second word (commit at 64). *)
  ignore (Chip_serve.frame_bits s (Array.append fixed_read (Array.make 33 0)));
  check "the next burst pops the word the stop left, and one more" (rx_level s = before - 3)
;;

let () =
  registers ();
  absent ();
  miso_cycles ();
  frame_cut ();
  rise_with_start ();
  pad_readback ();
  back_to_back ();
  rx_read_cut ();
  rx_burst_stop ();
  print_endline "chip directed checks: passed"
;;
