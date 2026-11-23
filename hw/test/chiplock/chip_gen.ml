(* Random host operations as pin traces (docs/chip.md 6, 11). A case is a sequence of frames,
   idle gaps, external-pad changes and resets. Every frame is clocked as a host would clock it,
   with random SCK periods (4 cycles and up, and a few breaches of 6.6), random CS setup and gap,
   random MOSI in the cycles where it may change, cut frames and resets inside frames. *)

open Chip_case

let st_of seed = Random.State.make [| seed; 0x9E37 |]

(* Register addresses the host touches (chip.md 8.1). *)
let reg_addrs =
  [ 0x000; 0x004; 0x008; 0x00C; 0x010; 0x014; 0x018; 0x01C; 0x020; 0x024; 0x028; 0x02C; 0x030
  ; 0x034; 0x038 ]
;;

let sm_offsets = [ 0x00; 0x04; 0x08; 0x0C; 0x10; 0x14; 0x18; 0x2C; 0x30; 0x34; 0x38; 0x3C ]

let generate ?(target = 4000) ~seed ~num_sms () : Chip_case.t =
  let st = st_of seed in
  let rint n = Random.State.int st n in
  (* A uniform 32-bit value (Random.State.int takes bounds below 2^30). *)
  let r32 () = (rint 0x10000 lsl 16) lor rint 0x10000 in
  let chance p = Random.State.float st 1.0 < p in
  let buf = ref [] in
  let len () = List.length !buf in
  let ext_ui = ref 0 and ext_uio = ref 0 in
  let emit ~csn ~mosi ~sck ~rst =
    let ui = (csn lsl 7) lor (mosi lsl 6) lor (sck lsl 5) lor (!ext_ui land 0x1F) in
    buf := { ui; uio = !ext_uio; rst } :: !buf
  in
  let rst_cycles n =
    for _ = 1 to n do
      emit ~csn:1 ~mosi:0 ~sck:0 ~rst:true
    done
  in
  (* One frame: [bits] (MSB first), SCK high and low phases of [h] cycles. *)
  let frame bits =
    let h = if chance 0.85 then 2 + rint 3 else 1 in
    let setup = 1 + rint 5 and gap = if chance 0.8 then 2 + rint 4 else 1 in
    let n = Array.length bits in
    let first = if n > 0 then bits.(0) else 0 in
    for _ = 1 to setup do
      emit ~csn:0 ~mosi:first ~sck:0 ~rst:false
    done;
    Array.iteri
      (fun j b ->
        (* A reset in the middle of a frame, now and then. *)
        if chance 0.0003 then rst_cycles (1 + rint 2);
        for _ = 1 to h do
          emit ~csn:0 ~mosi:b ~sck:1 ~rst:false
        done;
        let next = if j + 1 < n then bits.(j + 1) else rint 2 in
        for _ = 1 to h do
          emit ~csn:0 ~mosi:next ~sck:0 ~rst:false
        done)
      bits;
    for _ = 1 to gap do
      emit ~csn:1 ~mosi:(rint 2) ~sck:0 ~rst:false
    done
  in
  let word_bits w = Array.init 32 (fun k -> (w lsr (31 - k)) land 1) in
  let addr_bits a = Array.init 16 (fun k -> (a lsr (15 - k)) land 1) in
  let cmd_bits ~read ~fixed =
    [| (if read then 1 else 0); (if fixed then 1 else 0); 0; 0; 0; 0; 0; 0 |]
  in
  (* Keep SM register data inside the contract (engine.md 3, chip.md 8.2): SIDESET_COUNT 0 to 5
     (PINCTRL), no side-set enable without a count (EXECCTRL), INT 0 only with FRAC 0 (CLKDIV) and
     never both FJOIN bits (SHIFTCTRL). Random writes to any register go through this too. *)
  let legal addr data =
    let sm_reg = addr >= 0x200 && addr < 0x300 in
    match addr land 0x3F with
    | 0x14 when sm_reg ->
      let sc = min 5 ((data lsr 29) land 7) in
      (data land 0x1FFF_FFFF) lor (sc lsl 29)
    | 0x04 when sm_reg -> data land lnot (1 lsl 30)
    | 0x00 when sm_reg ->
      if (data lsr 16) land 0xFFFF = 0 then data land 0xFFFF_0000 else data land 0xFFFF_FFFF
    | 0x08 when sm_reg -> if (data lsr 30) land 3 = 3 then data land lnot (1 lsl 30) else data
    | _ -> data
  in
  let write_op addr data =
    let data = legal addr data in
    frame (Array.concat [ cmd_bits ~read:false ~fixed:(chance 0.3); addr_bits addr; word_bits data ])
  in
  let read_op addr n =
    let dummy = Array.make 8 0 in
    let body = Array.init (32 * n) (fun _ -> rint 2) in
    frame (Array.concat [ cmd_bits ~read:true ~fixed:(chance 0.5); addr_bits addr; dummy; body ])
  in
  let rx_addr () = 0x050 + (4 * rint 4) in
  let any_addr () =
    let r = rint 100 in
    if r < 10 then 0x02C
    else if r < 40 then List.nth reg_addrs (rint (List.length reg_addrs))
    else if r < 55 then 0x040 + (4 * rint 4)
    else if r < 70 then rx_addr ()
    else if r < 80 then 0x100 + (4 * rint 64)
    else if r < 97 then 0x200 + (0x40 * rint num_sms) + List.nth sm_offsets (rint (List.length sm_offsets))
    else rint 0x10000 land lnot 3
  in
  (* An IMEM word: mostly random, and often an instruction that reads the pads (in pins, wait
     pin, jmp pin), so the pad vector reaches the engines' state (chip.md 9.1). *)
  let instr_word () =
    match rint 10 with
    | 0 -> 0x4000 lor rint 2
    | 1 -> 0x20A0 lor rint 32
    | 2 -> 0x00C0 lor rint 32
    | _ -> rint 0x10000
  in
  let sm_config sm =
    (* CLKDIV: INT >= 1 (INT 0 with FRAC 0 is the only other legal form, chip.md 8.2). *)
    let int = 1 + rint 8 in
    let frac = if chance 0.5 then 0 else rint 256 in
    write_op (0x200 + (0x40 * sm)) ((int lsl 16) lor (frac lsl 8));
    (* EXECCTRL, SHIFTCTRL (FJOIN is 00, 01 or 10), PINCTRL. *)
    (* SIDE_EN off: a side-set enable needs a count of at least 1 (engine.md 4), kept simple here. *)
    write_op (0x204 + (0x40 * sm)) (r32 () land 0x7FFF_FF9F land lnot (1 lsl 30));
    let fj = rint 3 in
    write_op (0x208 + (0x40 * sm)) ((fj lsl 30) lor (rint 0x4000 lsl 16));
    (* SIDESET_COUNT 0 to 5 (engine.md 4): the model and the RTL take no other value. *)
    write_op (0x214 + (0x40 * sm)) ((r32 () land 0x1FFF_FFFF) lor (rint 6 lsl 29))
  in
  (* A pad test (chip.md 9.1): SM0 forces a SET of a pin and sets its direction, then the pad
     controls and the external levels change. The pins it drives reach the engines and PAD_IN. *)
  let pad_test () =
    let base = if chance 0.5 then rint 8 else rint 32 in
    write_op 0x214 ((1 lsl 26) lor (base lsl 5));
    (* SET pins (dest 0) and SET pindirs (dest 4), data 0 or 1 *)
    write_op 0x210 (0xE000 lor (0 lsl 5) lor rint 2);
    write_op 0x210 (0xE000 lor (4 lsl 5) lor rint 2);
    write_op 0x024 (rint 256);
    write_op 0x020 (rint 0x1000);
    ext_ui := rint 32;
    ext_uio := rint 256;
    (* read the pads back: PAD_IN is uio_in, what the pads show (chip.md 8.1) *)
    read_op 0x02C 1
  in
  (* Prefix: an IMEM image, configurations and enables, as a host sets up a run. *)
  let image () =
    for k = 0 to rint 8 do
      write_op (0x100 + (4 * k)) (instr_word ())
    done
  in
  image ();
  for sm = 0 to num_sms - 1 do
    if chance 0.7 then sm_config sm
  done;
  write_op 0x008 (if chance 0.7 then 1 + rint 15 else 0xF);
  (* Half the cases load a push loop, so RX FIFO 0 fills with pin levels (RX reads and commits). *)
  if chance 0.5
  then (
    write_op 0x100 0x4000;
    write_op 0x104 0x8020;
    write_op 0x108 0x0000;
    write_op 0x008 (1 + rint 15));
  if chance 0.8 then pad_test ();
  (* Random operations, until the target length. *)
  (* The random operations run for [target] cycles after the prefix. *)
  let loop_start = len () in
  while len () - loop_start < target do
    let r = rint 100 in
    if r < 25
    then write_op (any_addr ()) (r32 ())
    else if r < 45
    then read_op (if chance 0.25 then 0x02C else if chance 0.4 then rx_addr () else any_addr ()) (1 + rint 3)
    else if r < 50
    then pad_test ()
    else if r < 55
    then frame (Array.init (1 + rint 120) (fun _ -> rint 2))
    else if r < 65
    then for _ = 1 to 1 + rint 20 do emit ~csn:1 ~mosi:(rint 2) ~sck:0 ~rst:false done
    else if r < 72
    then (
      ext_ui := rint 32;
      ext_uio := rint 256)
    else if r < 74 && chance 0.2
    then rst_cycles (1 + rint 2)
    else if r < 80
    then (
      (* A FIFO change of FJOIN with data in the FIFOs: the chip flushes both (chip.md 8.2). *)
      (* SMs disabled, so nothing pops the words; then FJOIN changes; then the enables return *)
      let sm = rint num_sms in
      write_op 0x008 0;
      for _ = 1 to 1 + rint 3 do
        write_op (0x040 + (4 * sm)) (r32 ())
      done;
      write_op (0x208 + (0x40 * sm)) ((rint 3 lsl 30) lor (r32 () land 0x3FFF_0000));
      write_op 0x008 (rint 16))
    else (
      (* A 1-byte STATUS poll: the command byte alone. *)
      frame (Array.init 8 (fun _ -> rint 2)))
  done;
  let cycles = Array.of_list (List.rev !buf) in
  { num_sms; cycles }
;;

(* The corpus through the host link (chip.md 11): each program is loaded as a host loads it,
   with IMEM writes, the SM configuration and the enable, and then runs for [cycles] cycles with
   CS_N high. Pad stimulus of the program is not driven: the chip has 16 external pads and the
   corpus pin events address 32 pins. *)
let corpus ?(cycles = 3000) ~num_sms (c : Polyglot_lockstep.Case.t) : Chip_case.t =
  let buf = ref [] in
  let emit ~csn ~mosi ~sck =
    buf := { ui = (csn lsl 7) lor (mosi lsl 6) lor (sck lsl 5); uio = 0; rst = false } :: !buf
  in
  let frame bits =
    let h = 3 and setup = 4 and gap = 4 in
    let n = Array.length bits in
    for _ = 1 to setup do emit ~csn:0 ~mosi:(if n > 0 then bits.(0) else 0) ~sck:0 done;
    Array.iteri
      (fun j b ->
        for _ = 1 to h do emit ~csn:0 ~mosi:b ~sck:1 done;
        let next = if j + 1 < n then bits.(j + 1) else 0 in
        for _ = 1 to h do emit ~csn:0 ~mosi:next ~sck:0 done)
      bits;
    for _ = 1 to gap do emit ~csn:1 ~mosi:0 ~sck:0 done
  in
  let word_bits w = Array.init 32 (fun k -> (w lsr (31 - k)) land 1) in
  let addr_bits a = Array.init 16 (fun k -> (a lsr (15 - k)) land 1) in
  let write addr data =
    frame (Array.concat [ Array.make 8 0; addr_bits addr; word_bits data ])
  in
  for k = 0 to Array.length c.Polyglot_lockstep.Case.imem - 1 do
    write (0x100 + (4 * k)) c.Polyglot_lockstep.Case.imem.(k)
  done;
  for sm = 0 to num_sms - 1 do
    let s = c.Polyglot_lockstep.Case.initial.(sm) in
    let base = 0x200 + (0x40 * sm) in
    write base s.Polyglot_lockstep.Case.clkdiv;
    write (base + 4) s.execctrl;
    write (base + 8) s.shiftctrl;
    write (base + 0x14) s.pinctrl
  done;
  let enable =
    List.fold_left
      (fun acc (_, ev) -> match ev with Polyglot_lockstep.Case.Sm_enable v -> v | _ -> acc)
      1 c.events
  in
  write 0x008 (enable land 0xF);
  for _ = 1 to cycles do emit ~csn:1 ~mosi:0 ~sck:0 done;
  { num_sms; cycles = Array.of_list (List.rev !buf) }
;;

(* Coverage of a chip case (chip.md 11): the scenarios it reaches, from a replay on the model
   (bus pulses, pads, FIFO levels) and from the pin trace (frame gaps, SCK periods). Each is a
   boolean per case. *)
let chip_scenario_names =
  [ "bus write to IMEM"
  ; "bus write to an SM register"
  ; "bus write to TXFn"
  ; "bus read of RXFn with a word present"
  ; "bus read of RXFn while empty (RXUNDER)"
  ; "RXFn commit that pops"
  ; "burst read: two read pulses in one frame"
  ; "PAD_IN read while a pad is driven"
  ; "pad driven (uio_oe nonzero)"
  ; "HOST_IRQ asserted with HOSTIRQ_EN set"
  ; "reset cycle"
  ; "back-to-back frames at the minimum gap (2 cycles)"
  ; "frame gap of 3 or more cycles"
  ; "SCK period of exactly 4 cycles"
  ; "SCK breach: a high or low phase of 1 cycle"
  ; "external ui_in[4:0] nonzero"
  ]
;;

let chip_scenarios (c : Chip_case.t) : (string * bool) list =
  let flag = Array.make (List.length chip_scenario_names) false in
  let set i = flag.(i) <- true in
  let m = Chip.create ~num_sms:c.Chip_case.num_sms () in
  let cyc = c.Chip_case.cycles in
  let reads_in_frame = ref 0 in
  Array.iteri
    (fun k (y : Chip_case.cyc) ->
      if y.Chip_case.rst
      then (
        set 10;
        Chip.reset m)
      else (
        let obs = Chip.observe m in
        let o = Chip.step m ~ui_in:y.Chip_case.ui ~uio_ext:y.Chip_case.uio in
        let b = o.Chip.bus in
        let rx_level n = (List.assoc "dbg_flevel" obs lsr ((8 * n) + 4)) land 0xF in
        if y.Chip_case.ui land 0x1F <> 0 then set 15;
        if o.Chip.uio_oe <> 0 then set 8;
        if b.Chip.write
        then (
          let a = b.Chip.addr in
          if a >= 0x100 && a < 0x200 then set 0;
          if a >= 0x200 && a < 0x300 then set 1;
          if a >= 0x040 && a < 0x050 then set 2);
        if b.Chip.read
        then (
          incr reads_in_frame;
          if !reads_in_frame >= 2 then set 6;
          if b.Chip.addr >= 0x050 && b.Chip.addr < 0x060
          then (
            let n = (b.Chip.addr - 0x50) / 4 in
            if n < c.Chip_case.num_sms && rx_level n > 0 then set 3 else set 4);
          if b.Chip.addr = 0x02C && o.Chip.uio_oe <> 0 then set 7);
        if b.Chip.commit
        then (
          let n = (b.Chip.addr - 0x50) / 4 in
          if n >= 0 && n < c.Chip_case.num_sms && rx_level n > 0 then set 5);
        (* HOST_IRQ: uo_out[6] high while pins_out[14] is low, so the pad is the flag (9.2). *)
        if (List.assoc "uo_out" obs lsr 6) land 1 = 1 && (List.assoc "dbg_pins_out" obs lsr 14) land 1 = 0
        then set 9;
        ignore k))
    cyc;
  (* Frames and SCK phases from the pin trace. *)
  let n = Array.length cyc in
  let csn k = if k < n then cyc.(k).Chip_case.ui lsr 7 land 1 else 1 in
  let sck k = if k < n then cyc.(k).Chip_case.ui lsr 5 land 1 else 0 in
  (* Runs of equal CS_N and SCK. *)
  let runs f =
    let acc = ref [] and i = ref 0 in
    while !i < n do
      let v = f !i in
      let j = ref !i in
      while !j < n && f !j = v do
        incr j
      done;
      acc := (v, !j - !i, !i) :: !acc;
      i := !j
    done;
    List.rev !acc
  in
  let cs_runs = runs csn in
  let rec gaps = function
    | (1, len, _) :: rest when len >= 1 -> (
        (match rest with
         | (0, _, _) :: _ -> if len = 2 then set 11 else if len >= 3 then set 12
         | _ -> ());
        gaps rest)
    | _ :: rest -> gaps rest
    | [] -> ()
  in
  gaps cs_runs;
  let sck_runs = runs (fun k -> if csn k = 0 then sck k else 2) in
  List.iter
    (fun (v, len, _) ->
      if v = 1 && len = 2 then set 13;
      if v = 1 && len = 1 then set 14;
      if v = 0 && len = 1 then set 14)
    sck_runs;
  List.mapi (fun k name -> name, flag.(k)) chip_scenario_names
;;
