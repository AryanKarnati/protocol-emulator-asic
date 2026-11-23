(* Cyclesim checks for the block 3 RTL: the host link (docs/chip.md section 6), the register
   block (section 8) and the pin block (section 9). The expected cycles and values are
   worked out by hand from the contract. A pin waveform is written as a list of cycles,
   and the expected event of a SCK rise at relative cycle r is at r + 2 (section 6.2: the
   RISE is two cycles after the pin, because of the two synchroniser flops). *)

open Hardcaml

let failures = ref 0
let checks = ref 0

let fail what fmt =
  incr failures;
  Printf.printf ("FAIL %s: " ^^ fmt ^^ "\n%!") what
;;

let expect_int what got want =
  incr checks;
  if got <> want then fail what "got %d (0x%x), want %d (0x%x)" got got want want
;;

let expect_bool what got want = expect_int what (Bool.to_int got) (Bool.to_int want)

let expect_ints what got want =
  incr checks;
  if got <> want
  then
    fail
      what
      "got [%s], want [%s]"
      (String.concat "; " (List.map string_of_int got))
      (String.concat "; " (List.map string_of_int want))
;;

(* ---------- Cyclesim harness ---------- *)

let to_int b = Bits.to_int !b

(* Every output of one cycle, read before the clock edge. *)
let read_outs sim =
  List.map (fun (name, r) -> name, Bits.to_int !r) (Cyclesim.out_ports ~clock_edge:Before sim)
;;

let out_of outs name = List.assoc name outs

(* ---------- Host link ---------- *)

type pin =
  { sck : int
  ; mosi : int
  ; cs : int
  }

let idle = { sck = 0; mosi = 0; cs = 1 }
let gap n = List.init n (fun _ -> idle)

(* One frame, from CS falling. [setup] cycles with SCK low come first. Each bit has [lo]
   cycles of SCK low (MOSI already holds the bit, so it changes only while SCK is low) and
   [hi] cycles of SCK high. The frame ends with [lo] cycles of SCK low and CS still low;
   the caller raises CS. Returns the pins and the index of each bit's first SCK-high cycle
   (its RISE is two cycles later). *)
let frame ?(setup = 4) ?(lo = 3) ?(hi = 3) bits =
  let pins = ref [] in
  let pos = ref 0 in
  let push p =
    pins := p :: !pins;
    incr pos
  in
  let rises = Array.make (List.length bits) 0 in
  for _ = 1 to setup do
    push { sck = 0; mosi = 0; cs = 0 }
  done;
  List.iteri
    (fun j b ->
       for _ = 1 to lo do
         push { sck = 0; mosi = b; cs = 0 }
       done;
       rises.(j) <- !pos;
       for _ = 1 to hi do
         push { sck = 1; mosi = b; cs = 0 }
       done)
    bits;
  for _ = 1 to lo do
    push { sck = 0; mosi = 0; cs = 0 }
  done;
  List.rev !pins, rises
;;

(* MSB-first bits of [v], [n] wide. *)
let bits_of v n = List.init n (fun k -> (v lsr (n - 1 - k)) land 1)

(* The 24-bit header of section 6.3. *)
let header ~r ~f ~addr = [ r; f; 0; 0; 0; 0; 0; 0 ] @ bits_of addr 16

let write_frame ?(f = 0) ~addr words =
  header ~r:0 ~f ~addr @ List.concat_map (fun w -> bits_of w 32) words
;;

(* A read frame clocks [n] data words of 32 dummy-free bits after its dummy byte. MOSI is
   ignored from bit 24, so the bits are 0. *)
let read_frame ?(f = 0) ~addr n = header ~r:1 ~f ~addr @ List.init (8 + (32 * n)) (fun _ -> 0)

type obs =
  { miso : int
  ; wr : int
  ; rd : int
  ; cm : int
  ; baddr : int
  ; wdata : int
  ; rdata : int
  }

type link =
  { sim : Cyclesim.t_port_list
  ; mutable now : int
  }

let link_make () =
  let sim = Cyclesim.create (Polyglot_hw.Hostlink.circuit ()) in
  List.iter (fun (_, r) -> r := Bits.zero (Bits.width !r)) (Cyclesim.in_ports sim);
  let t = { sim; now = 0 } in
  let set n v =
    let r = Cyclesim.in_port sim n in
    r := Bits.of_int ~width:(Bits.width !r) v
  in
  set "rst_n" 0;
  Cyclesim.reset sim;
  set "rst_n" 1;
  set "cs_n" 1;
  t
;;

let set_in t n v =
  let r = Cyclesim.in_port t.sim n in
  r := Bits.of_int ~width:(Bits.width !r) v
;;

(* One clock cycle. The read data is the test's register block: it depends on bus_addr,
   which is combinational from the link's state, so it is set in two passes. *)
let link_step t ~status ~rdata_of (p : pin) =
  set_in t "sck" p.sck;
  set_in t "mosi" p.mosi;
  set_in t "cs_n" p.cs;
  set_in t "status" status;
  set_in t "rdata" 0;
  Cyclesim.cycle_before_clock_edge t.sim;
  let addr = to_int (Cyclesim.out_port ~clock_edge:Before t.sim "bus_addr") in
  set_in t "rdata" (rdata_of addr);
  Cyclesim.cycle_before_clock_edge t.sim;
  let outs = read_outs t.sim in
  Cyclesim.cycle_at_clock_edge t.sim;
  Cyclesim.cycle_after_clock_edge t.sim;
  t.now <- t.now + 1;
  { miso = out_of outs "miso"
  ; wr = out_of outs "bus_write"
  ; rd = out_of outs "bus_read"
  ; cm = out_of outs "bus_commit"
  ; baddr = out_of outs "bus_addr"
  ; wdata = out_of outs "bus_wdata"
  ; rdata = to_int (Cyclesim.in_port t.sim "rdata")
  }
;;

(* Run a list of pins. [status] and [rdata_of] are functions of the index in the list. *)
let run_with_rdata ?(status = fun _ -> 0xA5) t ~rdata_of pins =
  Array.of_list
    (List.mapi
       (fun k p -> link_step t ~status:(status k) ~rdata_of (p : pin))
       pins)
;;

let indices obs f =
  List.filter (fun i -> f obs.(i)) (List.init (Array.length obs) Fun.id)
;;

let test_host_link () =
  Printf.printf "host link\n%!";
  (* H1: one write word. The write is at the RISE of bit 55. *)
  let t = link_make () in
  let pins, rises = frame (write_frame ~addr:0x0038 [ 0xDEADBEEF ]) in
  let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 4) in
  let base = 3 in
  let w = base + rises.(55) + 2 in
  expect_ints "H1 write pulses" (indices obs (fun o -> o.wr = 1)) [ w ];
  expect_int "H1 write address" obs.(w).baddr 0x0038;
  expect_int "H1 write data" obs.(w).wdata 0xDEADBEEF;
  expect_ints "H1 read pulses" (indices obs (fun o -> o.rd = 1)) [];
  expect_ints "H1 commit pulses" (indices obs (fun o -> o.cm = 1)) [];
  (* H2: two words at 0xFFFC. With F = 0 the second word wraps to 0x0000. With F = 1 both
     are at 0xFFFC. *)
  let check_two ~f label expect_addr2 =
    let t = link_make () in
    let pins, rises = frame (write_frame ~f ~addr:0xFFFC [ 0x11111111; 0x22222222 ]) in
    let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 4) in
    let w1 = 3 + rises.(55) + 2 in
    let w2 = 3 + rises.(87) + 2 in
    expect_ints (label ^ " writes") (indices obs (fun o -> o.wr = 1)) [ w1; w2 ];
    expect_int (label ^ " word 0 address") obs.(w1).baddr 0xFFFC;
    expect_int (label ^ " word 0 data") obs.(w1).wdata 0x11111111;
    expect_int (label ^ " word 1 address") obs.(w2).baddr expect_addr2;
    expect_int (label ^ " word 1 data") obs.(w2).wdata 0x22222222
  in
  check_two ~f:0 "H2 F=0" 0x0000;
  check_two ~f:1 "H2 F=1" 0xFFFC;
  (* H3: a write frame cut after 50 bits writes nothing. *)
  let t = link_make () in
  let bits = write_frame ~addr:0x0038 [ 0x12345678 ] in
  let cut = List.filteri (fun k _ -> k < 50) bits in
  let pins, _ = frame cut in
  let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 8) in
  expect_ints "H3 cut mid-word writes" (indices obs (fun o -> o.wr = 1)) [];
  (* H4: one read word. The read access is at the RISE of bit 31 and the commit at bit 32.
     MISO carries STATUS (0xA5) in bits 0 to 7, zeros in bits 8 to 31, and the word from
     bit 32, MSB first. *)
  let t = link_make () in
  let rdata_of a = if a = 0x0040 then 0xCAFEF00D else 0 in
  let pins, rises = frame (read_frame ~addr:0x0040 1) in
  let obs = run_with_rdata t ~rdata_of (gap 3 @ pins @ gap 4) in
  let r31 = 3 + rises.(31) + 2 in
  let r32 = 3 + rises.(32) + 2 in
  (* The 64-bit frame clocks bit 63 too: that RISE is word 1's read access (31 + 32m), with
     no commit after it. *)
  expect_ints "H4 read pulses" (indices obs (fun o -> o.rd = 1)) [ r31; 3 + rises.(63) + 2 ];
  expect_ints "H4 commit pulses" (indices obs (fun o -> o.cm = 1)) [ r32 ];
  expect_int "H4 read address" obs.(r31).baddr 0x0040;
  expect_int "H4 commit address" obs.(r32).baddr 0x0040;
  expect_int "H4 read value" obs.(r31).rdata 0xCAFEF00D;
  let sample j = obs.(3 + rises.(j)).miso in
  let status = bits_of 0xA5 8 in
  expect_ints
    "H4 MISO command byte"
    (List.init 8 sample)
    status;
  expect_ints "H4 MISO dummy byte" (List.init 24 (fun k -> sample (8 + k))) (List.init 24 (fun _ -> 0));
  expect_ints
    "H4 MISO data word"
    (List.init 32 (fun k -> sample (32 + k)))
    (bits_of 0xCAFEF00D 32);
  (* Section 6.5: MISO never changes in cycles c to c + 2 after a rise in cycle c. *)
  let stable = ref true in
  for j = 0 to 63 do
    let c = 3 + rises.(j) in
    if not (obs.(c).miso = obs.(c + 1).miso && obs.(c + 1).miso = obs.(c + 2).miso)
    then stable := false
  done;
  expect_bool "H4 MISO stable from rise to rise+2" !stable true;
  (* H5: two read words at 0x0040 and 0x0044 (F = 0). Word 1 is read at bit 63 and
     committed at bit 64. Its MSB is on MISO from bit 64. The first bit of word 1 is
     clocked before the word is popped (6.4). *)
  let t = link_make () in
  let rdata_of a = 0x10000000 lor a in
  let pins, rises = frame (read_frame ~addr:0x0040 2) in
  let obs = run_with_rdata t ~rdata_of (gap 3 @ pins @ gap 4) in
  (* The 96-bit frame also clocks bit 95, the read access of word 2, which has no commit. *)
  expect_ints
    "H5 read pulses"
    (indices obs (fun o -> o.rd = 1))
    [ 3 + rises.(31) + 2; 3 + rises.(63) + 2; 3 + rises.(95) + 2 ];
  expect_ints
    "H5 commit pulses"
    (indices obs (fun o -> o.cm = 1))
    [ 3 + rises.(32) + 2; 3 + rises.(64) + 2 ];
  expect_int "H5 word 1 address" obs.(3 + rises.(63) + 2).baddr 0x0044;
  expect_int "H5 word 1 commit address" obs.(3 + rises.(64) + 2).baddr 0x0044;
  let sample j = obs.(3 + rises.(j)).miso in
  expect_ints
    "H5 MISO word 1"
    (List.init 32 (fun k -> sample (64 + k)))
    (bits_of (0x10000000 lor 0x44) 32);
  (* H6: a read cut after its read (bit 31) and before its commit (bit 32). No commit. *)
  let t = link_make () in
  let pins, rises = frame (List.filteri (fun k _ -> k < 32) (read_frame ~addr:0x0040 1)) in
  let obs = run_with_rdata t ~rdata_of:(fun _ -> 0xFFFFFFFF) (gap 3 @ pins @ gap 4) in
  expect_ints "H6 read pulses" (indices obs (fun o -> o.rd = 1)) [ 3 + rises.(31) + 2 ];
  expect_ints "H6 no commit" (indices obs (fun o -> o.cm = 1)) [];
  (* H7: a 1-byte STATUS poll. STATUS is taken in the START cycle, so a change after it
     does not reach MISO. The status is 0xA5 up to the START cycle and 0x3C after it. *)
  let t = link_make () in
  let pins, rises = frame (bits_of 0x80 8) in
  (* CS falls at index 3, so START is at index 5. *)
  let status k = if k <= 5 then 0xA5 else 0x3C in
  let obs = run_with_rdata t ~status ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 4) in
  let sample j = obs.(3 + rises.(j)).miso in
  expect_ints "H7 STATUS poll bits" (List.init 8 sample) (bits_of 0xA5 8);
  expect_ints "H7 no bus pulses" (indices obs (fun o -> o.wr = 1 || o.rd = 1)) [];
  (* H8: back-to-back write frames with the minimum gap of two cycles of CS high. *)
  let t = link_make () in
  let pa, ra = frame (write_frame ~addr:0x0010 [ 0x01020304 ]) in
  let pb, rb = frame (write_frame ~addr:0x0020 [ 0x0A0B0C0D ]) in
  let start_b = List.length pa + 2 in
  let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ pa @ gap 2 @ pb @ gap 4) in
  let wa = 3 + ra.(55) + 2 in
  let wb = 3 + start_b + rb.(55) + 2 in
  expect_ints "H8 writes" (indices obs (fun o -> o.wr = 1)) [ wa; wb ];
  expect_int "H8 frame A data" obs.(wa).wdata 0x01020304;
  expect_int "H8 frame B address" obs.(wb).baddr 0x0020;
  expect_int "H8 frame B data" obs.(wb).wdata 0x0A0B0C0D;
  (* H9: a rise in the START cycle is ignored. CS falls at cycle 0 and SCK rises in the
     same cycle, so that rise would be at cycle 2, the START cycle. The frame after it
     must count from its own first rise. *)
  let t = link_make () in
  let stray = [ { sck = 1; mosi = 1; cs = 0 }; { sck = 1; mosi = 1; cs = 0 }; { sck = 1; mosi = 1; cs = 0 } ]
              @ [ { sck = 0; mosi = 0; cs = 0 }; { sck = 0; mosi = 0; cs = 0 }; { sck = 0; mosi = 0; cs = 0 } ] in
  let pb, rb = frame ~setup:0 (write_frame ~addr:0x0030 [ 0x55AA55AA ]) in
  let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ stray @ pb @ gap 4) in
  let base = 3 + 6 in
  let wb = base + rb.(55) + 2 in
  expect_ints "H9 writes" (indices obs (fun o -> o.wr = 1)) [ wb ];
  expect_int "H9 data" obs.(wb).wdata 0x55AA55AA;
  expect_int "H9 address" obs.(wb).baddr 0x0030;
  (* H10: uneven and minimal SCK phases. The period is at least 4 cycles (6.6). *)
  List.iter
    (fun (lo, hi) ->
       let t = link_make () in
       let pins, rises = frame ~setup:4 ~lo ~hi (write_frame ~addr:0x0100 [ 0x0F0E0D0C; 0x0B0A0908 ]) in
       let obs = run_with_rdata t ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 4) in
       let label = Printf.sprintf "H10 lo=%d hi=%d" lo hi in
       expect_ints
         (label ^ " writes")
         (indices obs (fun o -> o.wr = 1))
         [ 3 + rises.(55) + 2; 3 + rises.(87) + 2 ])
    [ 2, 2; 2, 5; 5, 2; 3, 3 ];
  (* H11: the first SCK rise is 3 cycles after CS falls. STATUS bit 7 is then on MISO at
     the first sample (6.6, H-CS). *)
  let t = link_make () in
  let pins, rises = frame ~setup:0 ~lo:3 ~hi:3 (bits_of 0x80 8) in
  let obs = run_with_rdata t ~status:(fun _ -> 0x80) ~rdata_of:(fun _ -> 0) (gap 3 @ pins @ gap 2) in
  expect_int "H11 first rise is 3 cycles after CS" (rises.(0)) 3;
  expect_int "H11 STATUS bit 7 at the first sample" obs.(3 + rises.(0)).miso 1;
  (* H12: the MISO stability claim over a long read frame with SCK at 4 cycles. *)
  let t = link_make () in
  let rdata_of a = 0x5A5A5A5A lxor a in
  let pins, rises = frame ~lo:2 ~hi:2 (read_frame ~addr:0x0200 3) in
  let obs = run_with_rdata t ~rdata_of (gap 3 @ pins @ gap 4) in
  let stable = ref true in
  Array.iter
    (fun r ->
       let c = 3 + r in
       if not (obs.(c).miso = obs.(c + 1).miso && obs.(c + 1).miso = obs.(c + 2).miso)
       then stable := false)
    rises;
  expect_bool "H12 MISO stable in c to c+2" !stable true
;;

(* ---------- Register block ---------- *)

(* The block's inputs. Bus pulses are zeroed every cycle. Levels keep their value until
   the test changes them: they stand for the state of pio_block and of the pads. *)
type regs =
  { rsim : Cyclesim.t_port_list
  ; levels : (string, int) Hashtbl.t
  }

let regs_make ~num_sms ~imem_depth =
  let rsim = Cyclesim.create (Polyglot_hw.Regs.circuit ~num_sms ~imem_depth) in
  List.iter (fun (_, r) -> r := Bits.zero (Bits.width !r)) (Cyclesim.in_ports rsim);
  let rg = { rsim; levels = Hashtbl.create 64 } in
  (Cyclesim.in_port rsim "rst_n") := Bits.of_int ~width:1 0;
  Cyclesim.reset rsim;
  (Cyclesim.in_port rsim "rst_n") := Bits.of_int ~width:1 1;
  rg
;;

let level rg name v = Hashtbl.replace rg.levels name v

(* One cycle. [pulses] are (input, value) for this cycle only: the bus strobes default to
   0, and the other inputs default to their level. The result is every output, read
   before the clock edge. *)
let rcycle rg ?(pulses = []) () =
  List.iter
    (fun (name, r) ->
       if name <> "clock" && name <> "rst_n"
       then (
         let v =
           match List.assoc_opt name pulses with
           | Some v -> v
           | None ->
             if List.mem name [ "bus_write"; "bus_read"; "bus_commit" ]
             then 0
             else (try Hashtbl.find rg.levels name with Not_found -> 0)
         in
         r := Bits.of_int ~width:(Bits.width !r) v))
    (Cyclesim.in_ports rg.rsim);
  Cyclesim.cycle_before_clock_edge rg.rsim;
  let outs = read_outs rg.rsim in
  Cyclesim.cycle_at_clock_edge rg.rsim;
  Cyclesim.cycle_after_clock_edge rg.rsim;
  outs
;;

(* The read value in a cycle with [bus_addr] set: rdata is combinational from it. *)
let rd rg addr = out_of (rcycle rg ~pulses:[ "bus_addr", addr ] ()) "rdata"

let wr rg addr data =
  rcycle rg ~pulses:[ "bus_write", 1; "bus_addr", addr; "bus_wdata", data ] ()
;;

(* FSTAT with the RX FIFOs empty where [mask] has a bit set, and TX empty. *)
let fstat_rx mask = 0x0F000000 lor (mask lsl 8)

let test_regs () =
  Printf.printf "register block\n%!";
  let rg = regs_make ~num_sms:4 ~imem_depth:64 in
  level rg "fstat" (fstat_rx 0);
  (* R1: reset values (chip.md 8.1). *)
  expect_int "R1 ID" (rd rg 0x000) 0x504C4754;
  expect_int "R1 HWCFG (4 SMs, IMEM 64, version 1)" (rd rg 0x004) 0x10400404;
  expect_int "R1 CTRL" (rd rg 0x008) 0;
  expect_int "R1 FSTAT is the pio level" (rd rg 0x00C) (fstat_rx 0);
  expect_int "R1 IRQ" (rd rg 0x018) 0;
  expect_int "R1 HOSTIRQ_EN" (rd rg 0x020) 0;
  expect_int "R1 PAD_OD" (rd rg 0x024) 0;
  expect_int "R1 INPUT_SYNC_BYPASS" (rd rg 0x028) 0;
  expect_int "R1 SCRATCH" (rd rg 0x038) 0;
  expect_int "R1 DBG_CTRL reads 0" (rd rg 0x060) 0;
  expect_int "R1 IMEM reads 0" (rd rg 0x100) 0;
  expect_int "R1 SM0 CLKDIV" (rd rg 0x200) 0x00010000;
  expect_int "R1 SM0 EXECCTRL" (rd rg 0x204) 0x0001F000;
  expect_int "R1 SM0 SHIFTCTRL" (rd rg 0x208) 0x000C0000;
  expect_int "R1 SM0 PINCTRL" (rd rg 0x214) 0x14000000;
  expect_int "R1 SM0 EXT" (rd rg 0x218) 0;
  expect_int "R1 SM3 CLKDIV" (rd rg 0x2C0) 0x00010000;
  expect_int "R1 SM3 PINCTRL" (rd rg 0x2D4) 0x14000000;
  (* R2: write masks. Write all ones, then read back. *)
  let masked label addr mask =
    ignore (wr rg addr 0xFFFFFFFF);
    expect_int label (rd rg addr) mask
  in
  let o = wr rg 0x008 0xFFF in
  expect_int "R2 CTRL SM_ENABLE mask (4 SMs)" (rd rg 0x008) 0xF;
  expect_int "R2 CTRL restart pulses" (out_of o "sm_restart") 0xF;
  expect_int "R2 CTRL clkdiv restart pulses" (out_of o "clkdiv_restart") 0xF;
  masked "R2 SM0 CLKDIV mask" 0x200 0xFFFFFF00;
  masked "R2 SM0 EXECCTRL mask" 0x204 0x7FFFFF9F;
  masked "R2 SM0 SHIFTCTRL mask" 0x208 0xFFFF0000;
  masked "R2 SM0 PINCTRL mask" 0x214 0xFFFFFFFF;
  masked "R2 SM0 EXT mask (IMEM 64)" 0x218 1;
  masked "R2 SM3 CLKDIV mask" 0x2C0 0xFFFFFF00;
  masked "R2 HOSTIRQ_EN mask" 0x020 0xFFF;
  masked "R2 PAD_OD mask" 0x024 0xFF;
  masked "R2 INPUT_SYNC_BYPASS mask" 0x028 0xFFFFFF;
  masked "R2 SCRATCH mask" 0x038 0xFFFFFFFF;
  (* Write-only, reserved and read-only addresses. *)
  expect_int "R2 IRQ_FORCE reads 0" (rd rg 0x01C) 0;
  expect_int "R2 TXF0 reads 0" (rd rg 0x040) 0;
  ignore (wr rg 0x060 0xFF);
  expect_int "R2 DBG_CTRL ignores writes" (rd rg 0x060) 0;
  ignore (wr rg 0x21C 0xFFFF);
  expect_int "R2 LCU_CFG reads 0" (rd rg 0x21C) 0;
  ignore (wr rg 0x228 0xFFFF);
  expect_int "R2 LCU_CRC reads 0" (rd rg 0x228) 0;
  ignore (wr rg 0x104 0xFFFF);
  expect_int "R2 IMEM is write-only" (rd rg 0x104) 0;
  ignore (wr rg 0x000 0);
  expect_int "R2 ID is read-only" (rd rg 0x000) 0x504C4754;
  ignore (wr rg 0x20C 0xFF);
  expect_int "R2 ADDR is read-only" (rd rg 0x20C) 0;
  (* R3: pulses are presented in the write cycle only. *)
  let o = wr rg 0x040 0x1234 in
  expect_int "R3 TXF0 push" (out_of o "txf_push") 1;
  expect_int "R3 TXF0 sm" (out_of o "txf_sm") 0;
  expect_int "R3 TXF0 data" (out_of o "txf_data") 0x1234;
  let o = wr rg 0x04C 0xBEEF in
  expect_int "R3 TXF3 push" (out_of o "txf_push") 1;
  expect_int "R3 TXF3 sm" (out_of o "txf_sm") 3;
  expect_int "R3 push gone next cycle" (out_of (rcycle rg ()) "txf_push") 0;
  let o = wr rg 0x290 0x12ABCD in
  expect_int "R3 SM2 INSTR write" (out_of o "instr_write") 1;
  expect_int "R3 SM2 INSTR sm" (out_of o "instr_sm") 2;
  expect_int "R3 SM2 INSTR data is w[15:0]" (out_of o "instr_data") 0xABCD;
  let o = wr rg 0x114 0x00059876 in
  expect_int "R3 IMEM[5] write" (out_of o "imem_write") 1;
  expect_int "R3 IMEM[5] address" (out_of o "imem_addr") 5;
  expect_int "R3 IMEM[5] data" (out_of o "imem_data") 0x9876;
  let o = wr rg 0x018 0x5A in
  expect_int "R3 IRQ clear" (out_of o "irq_clear") 0x5A;
  let o = wr rg 0x01C 0x1FF in
  expect_int "R3 IRQ_FORCE" (out_of o "irq_force") 0xFF;
  let o = wr rg 0x010 0xFFFFFFFF in
  expect_int "R3 FDEBUG clear" (out_of o "fdebug_clear") 0xFFFFFFFF;
  (* R3: a register write lands at the end of its cycle, so the next cycle reads it. *)
  let o = wr rg 0x008 0x3 in
  expect_int "R3 CTRL enable is the old level in the write cycle" (out_of o "sm_enable") 0xF;
  expect_int "R3 CTRL enable seen next cycle" (out_of (rcycle rg ()) "sm_enable") 0x3;
  let o = wr rg 0x200 0x00020000 in
  expect_int "R3 CLKDIV old level in the write cycle" (out_of o "clkdiv0") 0xFFFFFF00;
  expect_int
    "R3 CLKDIV new level next cycle"
    (out_of (rcycle rg ()) "clkdiv0")
    0x00020000;
  (* R3: SHIFTCTRL FJOIN. Reset FJOIN is 00. A change of FJOIN flushes, and a write that
     keeps FJOIN does not, even when other bits change. *)
  let o = wr rg 0x248 0x80000000 in
  expect_int "R3 FJOIN_RX 0 to 1 flushes SM1" (out_of o "fifo_flush") 0b0010;
  let o = wr rg 0x248 0x80000000 in
  expect_int "R3 FJOIN kept: no flush" (out_of o "fifo_flush") 0;
  let o = wr rg 0x248 0x40000000 in
  expect_int "R3 FJOIN 10 to 01 flushes SM1" (out_of o "fifo_flush") 0b0010;
  let o = wr rg 0x248 0x40FFFFFF in
  expect_int "R3 FJOIN kept, other bits change: no flush" (out_of o "fifo_flush") 0;
  expect_int "R3 SHIFTCTRL keeps the masked bits" (rd rg 0x248) 0x40FF0000;
  (* R4: RX FIFO peek and commit (8.3). The RXEMPTY bits are the levels of FSTAT. *)
  level rg "rxf_data" 0x1234;
  level rg "fstat" (fstat_rx 0b0000);
  let o = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x050 ] () in
  expect_int "R4 RXF0 read value" (out_of o "rdata") 0x1234;
  expect_int "R4 read cycle pops nothing" (out_of o "rxf_pop") 0;
  expect_int "R4 read cycle sets nothing" (out_of o "fdebug_set") 0;
  expect_int "R4 rxf_sm during the read" (out_of o "rxf_sm") 0;
  let o = rcycle rg ~pulses:[ "bus_commit", 1; "bus_addr", 0x050 ] () in
  expect_int "R4 commit pops RX0" (out_of o "rxf_pop") 1;
  expect_int "R4 commit rxf_sm" (out_of o "rxf_sm") 0;
  expect_int "R4 commit sets nothing" (out_of o "fdebug_set") 0;
  (* R4: an empty FIFO. The read returns the (zero) head, and the commit sets RXUNDER
     and pops nothing. *)
  level rg "rxf_data" 0;
  level rg "fstat" (fstat_rx 0b0010);
  let o = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x054 ] () in
  expect_int "R4 RXF1 empty read value" (out_of o "rdata") 0;
  let o = rcycle rg ~pulses:[ "bus_commit", 1; "bus_addr", 0x054 ] () in
  expect_int "R4 empty commit pops nothing" (out_of o "rxf_pop") 0;
  expect_int "R4 empty commit sets RXUNDER[1]" (out_of o "fdebug_set") 0x200;
  (* R4: empty at the read and not empty at the commit: the record is taken at the read,
     so RXUNDER is still set and nothing is popped. *)
  level rg "fstat" (fstat_rx 0b0100);
  let _ = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x058 ] () in
  level rg "fstat" (fstat_rx 0b0000);
  let o = rcycle rg ~pulses:[ "bus_commit", 1; "bus_addr", 0x058 ] () in
  expect_int "R4 empty at read, not at commit: no pop" (out_of o "rxf_pop") 0;
  expect_int "R4 empty at read, not at commit: RXUNDER[2]" (out_of o "fdebug_set") 0x400;
  (* R4: not empty at the read and empty at the commit still pops: the head is the word
     being received. *)
  level rg "fstat" (fstat_rx 0b0000);
  let _ = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x05C ] () in
  level rg "fstat" (fstat_rx 0b1000);
  let o = rcycle rg ~pulses:[ "bus_commit", 1; "bus_addr", 0x05C ] () in
  expect_int "R4 non-empty at read, empty at commit: pops" (out_of o "rxf_pop") 1;
  expect_int "R4 rxf_sm 3" (out_of o "rxf_sm") 3;
  expect_int "R4 and sets nothing" (out_of o "fdebug_set") 0;
  level rg "fstat" (fstat_rx 0b0000);
  (* R4: an aborted read (no commit) pops nothing. A commit of another register does not
     pop either. *)
  let o = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x050 ] () in
  expect_int "R4 aborted read: the read pops nothing" (out_of o "rxf_pop") 0;
  let _ = rcycle rg ~pulses:[ "bus_read", 1; "bus_addr", 0x014 ] () in
  let o = rcycle rg ~pulses:[ "bus_commit", 1; "bus_addr", 0x014 ] () in
  expect_int "R4 commit of FLEVEL pops nothing" (out_of o "rxf_pop") 0;
  expect_int "R4 commit of FLEVEL sets nothing" (out_of o "fdebug_set") 0;
  (* R5: SM blocks. SM3 CLKDIV was masked to 0xFFFFFF00 above, so that is the old level. *)
  let o = wr rg 0x2C0 0x00030000 in
  expect_int "R5 SM3 CLKDIV old level" (out_of o "clkdiv3") 0xFFFFFF00;
  expect_int "R5 SM3 CLKDIV write" (rd rg 0x2C0) 0x00030000;
  expect_int "R5 SM3 clkdiv3 output next cycle" (out_of (rcycle rg ()) "clkdiv3") 0x00030000;
  (* R6: IMEM with depth 64 takes word 40. A write to LCU_CFG sends no pulse. *)
  let o = wr rg 0x1A0 0x1234 in
  expect_int "R6 IMEM[40] write with depth 64" (out_of o "imem_write") 1;
  expect_int "R6 IMEM[40] address" (out_of o "imem_addr") 40;
  let o = wr rg 0x21C 0x0 in
  expect_int "R6 LCU write sends no pulse" (out_of o "instr_write") 0;
  (* R7: DBG reads. EXECCTRL was masked to 0x7FFFFF9F above. *)
  level rg "dbg_x0" 0xDEAD;
  level rg "dbg_pc0" 0x1F;
  level rg "dbg_instr0" 0xE0A1;
  level rg "dbg_exec_stalled0" 1;
  level rg "dbg_cnt0" 0x01020304;
  level rg "dbg_isr1" 0x77;
  expect_int "R7 DBG_X" (rd rg 0x22C) 0xDEAD;
  expect_int "R7 ADDR is the PC" (rd rg 0x20C) 0x1F;
  expect_int "R7 INSTR reads the fetch word" (rd rg 0x210) 0xE0A1;
  expect_int "R7 EXECCTRL bit 31 reads EXEC_STALLED" (rd rg 0x204) 0xFFFFFF9F;
  expect_int "R7 DBG_CNT" (rd rg 0x23C) 0x01020304;
  expect_int "R7 SM1 DBG_ISR" (rd rg 0x274) 0x77;
  level rg "dbg_exec_stalled0" 0;
  expect_int "R7 EXECCTRL bit 31 follows the stall" (rd rg 0x204) 0x7FFFFF9F;
  (* R8: absent SMs, with 2 SMs. *)
  let rg2 = regs_make ~num_sms:2 ~imem_depth:64 in
  level rg2 "fstat" (fstat_rx 0);
  expect_int "R8 HWCFG has 2 SMs" (rd rg2 0x004) 0x10400204;
  let o = wr rg2 0x008 0xFFF in
  expect_int "R8 CTRL keeps 2 enable bits" (rd rg2 0x008) 0x3;
  expect_int "R8 CTRL restart pulses only for SMs 0 and 1" (out_of o "sm_restart") 0x3;
  expect_int
    "R8 CTRL clkdiv restart pulses only for SMs 0 and 1"
    (out_of o "clkdiv_restart")
    0x3;
  let o = wr rg2 0x290 0x12345 in
  expect_int "R8 SM2 INSTR gives no pulse" (out_of o "instr_write") 0;
  ignore (wr rg2 0x2C0 0x00070000);
  expect_int "R8 SM2 CLKDIV gives no output" (out_of (rcycle rg2 ()) "clkdiv2") 0;
  expect_int "R8 SM2 CLKDIV reads 0" (rd rg2 0x2C0) 0;
  let o = wr rg2 0x2C8 0x80000000 in
  expect_int "R8 SM2 SHIFTCTRL gives no flush" (out_of o "fifo_flush") 0;
  let o = wr rg2 0x248 0x80000000 in
  expect_int "R8 SM1 flushes on FJOIN change" (out_of o "fifo_flush") 0b0010;
  let o = wr rg2 0x048 0x1 in
  expect_int "R8 TXF2 write gives no push" (out_of o "txf_push") 0;
  let o = wr rg2 0x044 0x1 in
  expect_int "R8 TXF1 write pushes" (out_of o "txf_push") 1;
  let o = rcycle rg2 ~pulses:[ "bus_read", 1; "bus_addr", 0x058 ] () in
  expect_int "R8 RXF2 reads 0" (out_of o "rdata") 0;
  let o = rcycle rg2 ~pulses:[ "bus_commit", 1; "bus_addr", 0x058 ] () in
  expect_int "R8 RXF2 commit pops nothing" (out_of o "rxf_pop") 0;
  expect_int "R8 RXF2 commit sets nothing" (out_of o "fdebug_set") 0;
  expect_int "R8 SM2 DBG reads 0" (rd rg2 0x22C) 0;
  (* R9: IMEM with depth 32 takes words 0 to 31 only, and EXT is not stored. *)
  let rg3 = regs_make ~num_sms:4 ~imem_depth:32 in
  let o = wr rg3 0x1A0 0x1 in
  expect_int "R9 IMEM[40] gives no write with depth 32" (out_of o "imem_write") 0;
  let o = wr rg3 0x150 0x1 in
  expect_int "R9 IMEM[20] writes with depth 32" (out_of o "imem_write") 1;
  expect_int "R9 HWCFG IMEM depth 32" (rd rg3 0x004) 0x10200404;
  ignore (wr rg3 0x218 0x1);
  expect_int "R9 EXT mask is 0 with depth 32" (rd rg3 0x218) 0;
  expect_int "R9 ext0 stays 0" (out_of (rcycle rg3 ()) "ext0") 0
;;

(* ---------- Pin block ---------- *)

module Pins_circuit = Circuit.With_interface (Polyglot_hw.Pins.I) (Polyglot_hw.Pins.O)

(* The pin block is combinational, so each case evaluates once. Unset inputs are 0. *)
let pins_eval ?(num_sms = 4) inputs =
  let sim =
    Cyclesim.create
      (Pins_circuit.create_exn ~name:"pins" (Polyglot_hw.Pins.create ~num_sms))
  in
  List.iter (fun (name, v) -> (Cyclesim.in_port sim name) := Bits.of_int ~width:(Bits.width !(Cyclesim.in_port sim name)) v) inputs;
  Cyclesim.cycle_before_clock_edge sim;
  read_outs sim
;;

let test_pins () =
  Printf.printf "pin block\n%!";
  (* P1: the input vector and uo_out (9.1, 9.2). *)
  let o = pins_eval [ "ui_in", 0xA5; "uio_in", 0x3C; "pins_out", 0x2A00 ] in
  expect_int "P1 uo_out[5:0] is pins_out[13:8]" (out_of o "uo_out") 0x2A;
  expect_int "P1 pins_in is {0, ui_in, uo_out, uio_in}" (out_of o "pins_in") 0x00A52A3C;
  expect_int "P1 sync bypass vector" (out_of (pins_eval [ "sync_bypass", 0xABCDEF ]) "sync_bypass32") 0x00ABCDEF;
  (* P2: MISO is uo_out[7], and pins_in[15] reads it back. *)
  let o = pins_eval [ "miso", 1 ] in
  expect_int "P2 uo_out[7] is MISO" (out_of o "uo_out") 0x80;
  expect_int "P2 pins_in[15] reads uo_out[7]" (out_of o "pins_in") 0x00008000;
  (* P3: uo_out[6] is pins_out[14] while HOSTIRQ_EN is 0. *)
  let o = pins_eval [ "pins_out", 0x4000 ] in
  expect_int "P3 uo_out[6] is pins_out[14] with HOSTIRQ_EN 0" (out_of o "uo_out") 0x40;
  (* P4: HOST_IRQ. Source i of HOSTIRQ_EN is irq[i] for i < 4, RXNEMPTY for 4 to 7 and
     TXNFULL for 8 to 11. While HOSTIRQ_EN is set, uo_out[6] is HOST_IRQ and not pins_out[14]. *)
  let o = pins_eval [ "hostirq_en", 0x001; "irq", 0x01 ] in
  expect_int "P4 irq0 claims uo_out[6]" (out_of o "uo_out") 0x40;
  expect_int "P4 HOST_IRQ" (out_of o "host_irq") 1;
  let o = pins_eval [ "hostirq_en", 0x002; "irq", 0x01; "pins_out", 0x4000 ] in
  expect_int "P4 irq1 not set: uo_out[6] 0 even with pins_out[14] 1" (out_of o "uo_out") 0x00;
  expect_int "P4 HOST_IRQ 0" (out_of o "host_irq") 0;
  (* FSTAT with TXFULL[3] = 1 (bit 19) and RXEMPTY[1] = 1 (bit 9). *)
  let fstat = 0x00080200 in
  let o = pins_eval [ "hostirq_en", 0x010; "fstat", fstat ] in
  expect_int "P4 RXNEMPTY0 source (bit 4) fires" (out_of o "host_irq") 1;
  let o = pins_eval [ "hostirq_en", 0x200; "fstat", fstat ] in
  expect_int "P4 TXNFULL1 source (bit 9) fires: TXFULL1 is 0" (out_of o "host_irq") 1;
  let o = pins_eval [ "hostirq_en", 0x800; "fstat", fstat ] in
  expect_int "P4 TXNFULL3 source (bit 11) is 0 while TXFULL3 is 1" (out_of o "host_irq") 0;
  let o = pins_eval [ "hostirq_en", 0x020; "fstat", fstat ] in
  expect_int "P4 RXNEMPTY1 source (bit 5) is 0 while RXEMPTY1 is 1" (out_of o "host_irq") 0;
  (* P5: STATUS = {TXNFULL[3:0], RXNEMPTY[3:0]} (9.3). Bit 7 is TXNFULL[3]. *)
  let o = pins_eval [ "fstat", fstat ] in
  expect_int "P5 STATUS with 4 SMs" (out_of o "status") 0x7D;
  (* P5: with 2 SMs the absent SMs read as neither non-empty nor not-full. *)
  let o = pins_eval ~num_sms:2 [ "fstat", fstat ] in
  expect_int "P5 STATUS with 2 SMs: absent SMs contribute 0" (out_of o "status") 0x31;
  let o = pins_eval ~num_sms:2 [ "hostirq_en", 0xC00; "fstat", 0 ] in
  expect_int "P5 HOST_IRQ: absent SM2 and SM3 TXNFULL sources are 0" (out_of o "host_irq") 0;
  let o = pins_eval ~num_sms:2 [ "hostirq_en", 0x80; "fstat", 0 ] in
  expect_int "P5 HOST_IRQ: absent SM3 RXNEMPTY is 0" (out_of o "host_irq") 0;
  (* P6: open-drain on uio (9.2). uio_out is 0 for an open-drain pad, and uio_oe drops
     when the program writes 1 (released). *)
  let o = pins_eval [ "pad_od", 0x01; "pins_out", 0x01; "pins_oe", 0x01 ] in
  expect_int "P6 open-drain released: uio_oe 0" (out_of o "uio_oe") 0;
  expect_int "P6 open-drain released: uio_out 0" (out_of o "uio_out") 0;
  let o = pins_eval [ "pad_od", 0x01; "pins_out", 0x00; "pins_oe", 0x01 ] in
  expect_int "P6 open-drain pulled low: uio_oe 1" (out_of o "uio_oe") 1;
  expect_int "P6 open-drain pulled low: uio_out 0" (out_of o "uio_out") 0;
  let o = pins_eval [ "pad_od", 0x00; "pins_out", 0x01; "pins_oe", 0x01 ] in
  expect_int "P6 push-pull high: uio_oe 1" (out_of o "uio_oe") 1;
  expect_int "P6 push-pull high: uio_out 1" (out_of o "uio_out") 1;
  let o = pins_eval [ "pad_od", 0x80; "pins_out", 0x80; "pins_oe", 0x00 ] in
  expect_int "P6 input pad stays an input" (out_of o "uio_oe") 0
;;

(* ---------- Whole chip ---------- *)

(* The chip with its pads. [ui_ext] holds ui_in[4:0] and [uio_ext] the external level of
   each uio pad. SPI pins are set per cycle. *)
type chip =
  { csim : Cyclesim.t_port_list
  ; ui_ext : int
  ; uio_ext : int
  }

let chip_make ?(num_sms = 4) ?(imem_depth = 64) () =
  let sim = Cyclesim.create (Polyglot_hw.Chip.circuit ~num_sms ~imem_depth) in
  List.iter (fun (_, r) -> r := Bits.zero (Bits.width !r)) (Cyclesim.in_ports sim);
  (Cyclesim.in_port sim "rst_n") := Bits.of_int ~width:1 0;
  Cyclesim.reset sim;
  (Cyclesim.in_port sim "rst_n") := Bits.of_int ~width:1 1;
  { csim = sim; ui_ext = 0; uio_ext = 0 }
;;

let set_port c n v =
  let r = Cyclesim.in_port c.csim n in
  r := Bits.of_int ~width:(Bits.width !r) v
;;

(* One cycle. The uio pads follow the testbench rule of engine.md R1: uio_in[i] is
   uio_out[i] where uio_oe[i] is set, and the external level otherwise. uio_in does not
   reach an output in the same cycle, so one extra evaluation is enough. *)
let drive c ?(sck = 0) ?(mosi = 0) ?(cs = 1) () =
  set_port c "ui_in" (c.ui_ext lor (sck lsl 5) lor (mosi lsl 6) lor (cs lsl 7));
  set_port c "uio_in" c.uio_ext;
  Cyclesim.cycle_before_clock_edge c.csim;
  let oe = to_int (Cyclesim.out_port ~clock_edge:Before c.csim "uio_oe") in
  let out = to_int (Cyclesim.out_port ~clock_edge:Before c.csim "uio_out") in
  set_port c "uio_in" ((out land oe) lor (c.uio_ext land lnot oe land 0xFF));
  Cyclesim.cycle_before_clock_edge c.csim;
  let outs = read_outs c.csim in
  Cyclesim.cycle_at_clock_edge c.csim;
  Cyclesim.cycle_after_clock_edge c.csim;
  outs
;;

(* Run pins over SPI, and return the outputs of every cycle. *)
let spi c (pins : pin list) =
  Array.of_list (List.map (fun (p : pin) -> drive c ~sck:p.sck ~mosi:p.mosi ~cs:p.cs ()) pins)
;;

let idle_cycles c n = spi c (gap n)
let last a = a.(Array.length a - 1)
let miso_of o = (out_of o "uo_out" lsr 7) land 1

(* The MSB-first 32-bit word whose bits start at frame bit [j0]. *)
let sample_word outs rises j0 =
  List.fold_left
    (fun acc k -> (acc lsl 1) lor miso_of outs.(3 + rises.(j0 + k)))
    0
    (List.init 32 Fun.id)
;;

(* Read [n] words with a read frame. Returns the words. *)
let chip_read ?(f = 0) c ~addr n =
  let pins, rises = frame (read_frame ~f ~addr n) in
  let outs = spi c (gap 3 @ pins @ gap 4) in
  List.init n (fun m -> sample_word outs rises (32 + (32 * m)))
;;

let chip_write ?(f = 0) c ~addr words =
  let pins, _ = frame (write_frame ~f ~addr words) in
  ignore (spi c (gap 3 @ pins @ gap 4))
;;

let test_chip () =
  Printf.printf "chip\n%!";
  (* C1: ID and SCRATCH over SPI. *)
  let c = chip_make () in
  expect_int "C1 ID over SPI" (List.hd (chip_read c ~addr:0x000 1)) 0x504C4754;
  chip_write c ~addr:0x038 [ 0xCAFE1234 ];
  expect_int "C1 SCRATCH read back" (List.hd (chip_read c ~addr:0x038 1)) 0xCAFE1234;
  (* C2: IMEM in both pages. Page 0: set pindirs 31, set pins 21, jmp 2. Page 1: set pins
     10, jmp 1. The SM runs page 0 first, then page 1 after EXT.PAGE is set. *)
  let c = chip_make () in
  chip_write c ~addr:0x100 [ 0xE09F; 0xE015; 0x0002 ];
  chip_write c ~addr:0x180 [ 0xE00A; 0x0001 ];
  chip_write c ~addr:0x008 [ 0x1 ];
  let o = last (idle_cycles c 30) in
  expect_int "C2 page 0 uio_out[4:0]" (out_of o "uio_out" land 0x1F) 0x15;
  expect_int "C2 page 0 uio_oe[4:0]" (out_of o "uio_oe" land 0x1F) 0x1F;
  (* C2: open-drain (PAD_OD) on pins 0 and 1. Pin 0 holds 1 and is released; pin 1 holds
     0 and is pulled low. *)
  chip_write c ~addr:0x024 [ 0x3 ];
  let o = last (idle_cycles c 2) in
  expect_int "C2 open-drain uio_out[4:0]" (out_of o "uio_out" land 0x1F) 0x14;
  expect_int "C2 open-drain uio_oe[4:0]" (out_of o "uio_oe" land 0x1F) 0x1E;
  chip_write c ~addr:0x024 [ 0x0 ];
  (* C2: page switch. Disable, set EXT.PAGE of SM0, then restart and enable. *)
  chip_write c ~addr:0x008 [ 0x0 ];
  chip_write c ~addr:0x218 [ 0x1 ];
  chip_write c ~addr:0x008 [ 0x11 ];
  let o = last (idle_cycles c 30) in
  expect_int "C2 page 1 uio_out[4:0]" (out_of o "uio_out" land 0x1F) 0x0A;
  (* C3: HOST_IRQ on uo_out[6] (9.3). *)
  let c = chip_make () in
  chip_write c ~addr:0x020 [ 0x001 ];
  chip_write c ~addr:0x01C [ 0x01 ];
  expect_int "C3 IRQ0 forced: HOST_IRQ on uo_out[6]" ((out_of (last (idle_cycles c 2)) "uo_out" lsr 6) land 1) 1;
  chip_write c ~addr:0x018 [ 0x01 ];
  expect_int "C3 IRQ0 cleared: uo_out[6] low" ((out_of (last (idle_cycles c 2)) "uo_out" lsr 6) land 1) 0;
  (* C4: a TX word is pulled by a program and shows on uio. Program: set pindirs 31,
     pull block, out pins 5, jmp 1. OUT_COUNT is 5 in PINCTRL. *)
  let c = chip_make () in
  chip_write c ~addr:0x100 [ 0xE09F; 0x80A0; 0x6005; 0x0001 ];
  chip_write c ~addr:0x214 [ 0x14500000 ];
  chip_write c ~addr:0x008 [ 0x1 ];
  let o = last (idle_cycles c 30) in
  expect_int "C4 stalled on an empty TX FIFO" (out_of o "uio_out" land 0x1F) 0;
  chip_write c ~addr:0x040 [ 0x1B ];
  let o = last (idle_cycles c 30) in
  expect_int "C4 pulled TX word reaches uio" (out_of o "uio_out" land 0x1F) 0x1B;
  (* C5: RX burst. Program: set x 21, in x 32, push block, set x 9, in x 32, push block,
     jmp 0. The RX FIFO receives 21, 9, 21, 9 and then the program stalls. *)
  let c = chip_make () in
  chip_write c ~addr:0x100 [ 0xE035; 0x4020; 0x8020; 0xE029; 0x4020; 0x8020; 0x0000 ];
  chip_write c ~addr:0x008 [ 0x1 ];
  ignore (idle_cycles c 200);
  expect_ints
    "C5 RX burst read, fixed address"
    (chip_read ~f:1 c ~addr:0x050 4)
    [ 21; 9; 21; 9 ];
  (* C6: a chip with 1 SM and a 32-word IMEM. The host sees 1 SM and 32 words in HWCFG,
     the absent SMs read 0, and the SM that exists runs its program. *)
  let c = chip_make ~num_sms:1 ~imem_depth:32 () in
  expect_int "C6 HWCFG with 1 SM and IMEM 32" (List.hd (chip_read c ~addr:0x004 1)) 0x10200104;
  expect_int "C6 absent SM1 CLKDIV reads 0" (List.hd (chip_read c ~addr:0x240 1)) 0;
  chip_write c ~addr:0x100 [ 0xE09F; 0xE015; 0x0002 ];
  chip_write c ~addr:0x008 [ 0x1 ];
  let o = last (idle_cycles c 30) in
  expect_int "C6 1-SM chip runs: uio_out[4:0]" (out_of o "uio_out" land 0x1F) 0x15;
  (* A 1-byte STATUS poll: TXNFULL0 is bit 4 (the TX FIFO is not full), RXNEMPTY0 is bit 0
     (the RX FIFO is empty), and every absent SM bit is 0. *)
  let pins, rises = frame (bits_of 0x80 8) in
  let outs = spi c (gap 3 @ pins @ gap 4) in
  expect_int "C6 1-SM STATUS poll" (List.fold_left (fun acc j -> (acc lsl 1) lor miso_of outs.(3 + rises.(j))) 0 (List.init 8 Fun.id)) 0x10;
;;

let () =
  test_host_link ();
  test_regs ();
  test_pins ();
  test_chip ();
  Printf.printf "checks: %d, failures: %d\n" !checks !failures;
  if !failures > 0 then exit 1
;;
