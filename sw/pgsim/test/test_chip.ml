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

(* chip.md 9.1: the engines see the pad vector, not their own output registers. Each case drives one
   pin from SM0 with a forced SET (SET_COUNT 1 at SET_BASE [pin]), then reads the pad value the
   engines saw in the cycle (Pgsim.pads after a step). *)
let set_insn d dest = enc (Polyglot_isa.Isa.Set { delay_side = 0; dest; data = d })

let force_set s ~base ~level ~dir =
  write_frame s 0x214 ((1 lsl 26) lor (base lsl 5));
  write_frame s 0x210 (set_insn level Polyglot_isa.Isa.Set_pins);
  write_frame s 0x210 (set_insn dir Polyglot_isa.Isa.Set_pindirs)
;;

let pad_level_after_step s =
  ignore (Chip_serve.drive s ~sck:0 ~mosi:0 ~csn:1);
  fst (Pgsim.pads (Chip.pio s.Chip_serve.chip))
;;

(* (a) a released open-drain pin (PAD_OD set, output 0) reads the external level *)
let pad_released_od () =
  let s = server () in
  (* Level 1 with PAD_OD set releases the pad (9.2): the output enable drops. *)
  force_set s ~base:3 ~level:1 ~dir:1;
  write_frame s 0x024 0x08;
  ignore (Chip_serve.command s "ext 00 08");
  let v = pad_level_after_step s in
  check "released open-drain pin 3 reads the external level" ((v lsr 3) land 1 = 1);
  let o = Chip.peek s.Chip_serve.chip ~ui_in:0 ~uio_ext:0x08 in
  check "released pad drives nothing" (o.Chip.uio_oe land 0x08 = 0)
;;

(* (b) pin 14 reads uo_out[6] = HOST_IRQ while HOSTIRQ_EN is set, not the pin's own level *)
let pad_pin14_hostirq () =
  let s = server () in
  write_frame s 0x01C 0x01;
  write_frame s 0x020 0x001;
  let v = pad_level_after_step s in
  check "pin 14 reads HOST_IRQ, which is 1 here" ((v lsr 14) land 1 = 1);
  check "pin 14 level from pins_out is 0" ((Pgsim.pins_out (Chip.pio s.Chip_serve.chip) lsr 14) land 1 = 0)
;;

(* (c) pin 15 reads uo_out[7] = MISO, cycle by cycle through a frame (pins 8..15 = uo_out). *)
let pad_pin15_miso () =
  let s = server () in
  let seen_one = ref false in
  for c = 0 to 40 do
    let sck = if c >= 4 && (c - 4) mod 6 < 3 then 1 else 0 in
    let o = Chip_serve.drive s ~sck ~mosi:0 ~csn:(if c >= 2 then 0 else 1) in
    let lv, _ = Pgsim.pads (Chip.pio s.Chip_serve.chip) in
    let uo = o.Chip.uo_out in
    if (uo lsr 7) land 1 = 1 then seen_one := true;
    check (Printf.sprintf "pin 15 = MISO at cycle %d" c) ((lv lsr 15) land 1 = (uo lsr 7) land 1);
    check (Printf.sprintf "pins 8..13 = uo_out[5:0] at cycle %d" c) ((lv lsr 8) land 0x3F = uo land 0x3F);
    check (Printf.sprintf "pin 14 = uo_out[6] at cycle %d" c) ((lv lsr 14) land 1 = (uo lsr 6) land 1)
  done;
  check "MISO was 1 at some cycle of the frame" !seen_one
;;

(* (d) input-only pin 16 with its direction bit set reads ui_in[0], not the output level *)
let pad_input_only_dir () =
  let s = server () in
  force_set s ~base:16 ~level:0 ~dir:1;
  ignore (Chip_serve.command s "ext 01 00");
  let v = pad_level_after_step s in
  check "pin 16 with direction set reads ui_in[0]" ((v lsr 16) land 1 = 1);
  check "pin 16 output level is 0" ((Pgsim.pins_out (Chip.pio s.Chip_serve.chip) lsr 16) land 1 = 0)
;;

(* (e) virtual pin 24 with its direction bit set reads 0, whatever its output level *)
let pad_virtual_dir () =
  let s = server () in
  force_set s ~base:24 ~level:1 ~dir:1;
  let v = pad_level_after_step s in
  check "virtual pin 24 reads 0 with direction set" ((v lsr 24) land 1 = 0);
  check "virtual pin 24 output level is 1" ((Pgsim.pins_out (Chip.pio s.Chip_serve.chip) lsr 24) land 1 = 1)
;;

(* A read frame of [n] words from [addr] (8.3, 6.3): the words MISO sends, in order. *)
let read_words s ~fixed addr n =
  let bytes = [ cmd ~read:true ~fixed ] @ addr_bytes addr @ [ 0 ] @ List.init (4 * n) (fun _ -> 0) in
  let out = Chip_serve.frame s bytes in
  List.init n (fun m ->
    List.fold_left (fun acc b -> (acc lsl 8) lor b) 0 (List.filteri (fun i _ -> i >= 4 + (4 * m) && i < 8 + (4 * m)) out))
;;

(* RXF word values (8.3): an echo, pull; in osr,32; push; jmp 0, moves TXF0 words to RX FIFO 0. A
   fixed-address (F = 1) burst returns the words in order, then 0 when the FIFO is empty, and each
   word is popped by its commit. *)
let rxf_values () =
  let s = server () in
  let pull_block = enc (Polyglot_isa.Isa.Pull { delay_side = 0; if_empty = false; block = true }) in
  let push_block = enc (Polyglot_isa.Isa.Push { delay_side = 0; if_full = false; block = true }) in
  let in_osr = enc (Polyglot_isa.Isa.In { delay_side = 0; source = Polyglot_isa.Isa.In_osr; bit_count = 32 }) in
  write_frame s 0x100 pull_block;
  write_frame s 0x104 in_osr;
  write_frame s 0x108 push_block;
  write_frame s 0x10C 0;
  write_frame s 0x008 1;
  let words = [ 0x1111_1111; 0x2222_2222; 0xDEAD_BEEF ] in
  List.iter (fun w -> write_frame s 0x040 w) words;
  ignore (Chip_serve.command s "run 120");
  check "RX FIFO 0 holds the three echoed words" ((read_word s 0x014 lsr 4) land 0xF = 3);
  check "F = 1 burst returns the words in order, then 0"
    (read_words s ~fixed:true 0x050 4 = words @ [ 0 ]);
  check "the burst popped all three and the fourth read set RXUNDER"
    ((read_word s 0x014 lsr 4) land 0xF = 0 && (read_word s 0x010 lsr 8) land 0xF = 1)
;;

let () =
  registers ();
  rxf_values ();
  pad_released_od ();
  pad_pin14_hostirq ();
  pad_pin15_miso ();
  pad_input_only_dir ();
  pad_virtual_dir ();
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
