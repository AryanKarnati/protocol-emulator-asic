(* The whole chip as a golden model: docs/chip.md sections 5 to 9. Section numbers are cited
   where a rule is not obvious. The four engines are {!Pgsim}; the host link, the register
   block and the pin block are here. *)

let m32 = 0xFFFF_FFFF
let bit v i = (v lsr i) land 1

(* Register reset values and write masks (chip.md 8.1). *)
let clkdiv_reset = 0x0001_0000
let execctrl_reset = 0x0001_F000
let shiftctrl_reset = 0x000C_0000
let pinctrl_reset = 0x1400_0000
let clkdiv_mask = 0xFFFF_FF00
let execctrl_mask = 0x7FFF_FF9F
let shiftctrl_mask = 0xFFFF_0000
let hostirq_mask = 0x0FFF
let sync_mask = 0x00FF_FFFF
let id_value = 0x504C_4754
let imem_depth = 64

(* The FDEBUG flags that exist: RP2040 3.7 layout with ILLEGAL at [31:28]. *)
let fdebug_layout = 0xFF0F_0F0F

(* Bits of FSTAT, FDEBUG and FLEVEL that belong to SM [n] (engine.md 3). *)
let fstat_bits n = (1 lsl n) lor (1 lsl (8 + n)) lor (1 lsl (16 + n)) lor (1 lsl (24 + n))
let fdebug_bits n = fstat_bits n lor (1 lsl (28 + n))
let flevel_bits n = 0xFF lsl (8 * n)

let sm_mask ~num_sms f =
  let m = ref 0 in
  for n = 0 to num_sms - 1 do
    m := !m lor f n
  done;
  !m
;;

type sm_regs =
  { mutable clkdiv : int
  ; mutable execctrl : int (** bit 31 is not stored: it reads dbg_exec_stalled *)
  ; mutable shiftctrl : int
  ; mutable pinctrl : int
  ; mutable ext : int (** bit 0 is PAGE *)
  }

(* An RX read, from its read to its commit (chip.md 8.3). [rempty] is RXEMPTY at the read. *)
type rx_read =
  { rsm : int
  ; rempty : bool
  }

type bus =
  { write : bool
  ; read : bool
  ; commit : bool
  ; addr : int
  ; wdata : int
  ; rdata : int
  }

type outputs =
  { uo_out : int
  ; uio_out : int
  ; uio_oe : int
  ; miso : int
  ; bus : bus
  }

let no_bus = { write = false; read = false; commit = false; addr = 0; wdata = 0; rdata = 0 }

type t =
  { num_sms : int
  ; pio : Pgsim.t
  ; regs : sm_regs array
  ; mutable ctrl_en : int
  ; mutable hostirq_en : int
  ; mutable pad_od : int
  ; mutable sync_bypass : int
  ; mutable scratch : int
  ; sck : int array (** s1, s2, s3 (6.1) *)
  ; mosi : int array
  ; csn : int array
  ; mutable in_frame : bool
  ; mutable rises : int (** RISEs so far in this frame: the number of the next bit *)
  ; mutable cmd_r : int
  ; mutable cmd_f : int
  ; mutable addr_reg : int (** ADDR as received, bits 8 to 23 *)
  ; mutable wacc : int (** the last 32 MOSI bits *)
  ; mutable rx_pend : rx_read option
  ; mutable miso_sr : int (** the 32-bit MISO shift register (6.5) *)
  ; mutable ncycle : int
  }

let create ?(num_sms = 4) () =
  if num_sms < 1 || num_sms > 4 then invalid_arg "chip: num_sms must be 1 to 4";
  { num_sms
  ; pio = Pgsim.create ()
  ; regs =
      Array.init 4 (fun _ ->
        { clkdiv = clkdiv_reset
        ; execctrl = execctrl_reset
        ; shiftctrl = shiftctrl_reset
        ; pinctrl = pinctrl_reset
        ; ext = 0
        })
  ; ctrl_en = 0
  ; hostirq_en = 0
  ; pad_od = 0
  ; sync_bypass = 0
  ; scratch = 0
  ; sck = [| 0; 0; 0 |]
  ; mosi = [| 0; 0; 0 |]
  ; csn = [| 1; 1; 1 |]
  ; in_frame = false
  ; rises = 0
  ; cmd_r = 0
  ; cmd_f = 0
  ; addr_reg = 0
  ; wacc = 0
  ; rx_pend = None
  ; miso_sr = 0
  ; ncycle = 0
  }
;;

let pio t = t.pio
let cycle t = t.ncycle
let present t n = n < t.num_sms

(* The engines' view of the registers. A register write is visible from the next cycle, so
   the view is taken at the start of each cycle (chip.md 8.2). *)
let configure t =
  let pio = t.pio in
  for n = 0 to 3 do
    if present t n
    then (
      let r = t.regs.(n) in
      Pgsim.set_config
        pio
        n
        (Pgsim.Config.of_registers
           ~clkdiv:r.clkdiv
           ~execctrl:r.execctrl
           ~shiftctrl:r.shiftctrl
           ~pinctrl:r.pinctrl);
      Pgsim.set_page pio n r.ext);
    Pgsim.set_enabled pio n (present t n && bit t.ctrl_en n = 1)
  done;
  pio.Pgsim.sync_bypass <- t.sync_bypass
;;

(* STATUS and the HOST_IRQ sources (chip.md 9.3). An absent SM, or a FIFO of capacity 0 (both
   full and empty in FSTAT), gives 0. *)
let nonempty_bits t fst =
  let v = ref 0 in
  for n = 0 to 3 do
    if present t n && bit fst (8 + n) = 0 then v := !v lor (1 lsl n)
  done;
  !v
;;

let notfull_bits t fst =
  let v = ref 0 in
  for n = 0 to 3 do
    if present t n && bit fst (16 + n) = 0 then v := !v lor (1 lsl n)
  done;
  !v
;;

let status t fst = (notfull_bits t fst lsl 4) lor nonempty_bits t fst

(* The start-of-cycle state that the outputs and the register reads of a cycle use. *)
type view =
  { fst : int
  ; fdb : int
  ; flv : int
  ; irq : int
  ; pins_out : int
  ; pins_oe : int
  ; miso : int
  ; uo_out : int
  ; uio_out : int
  ; uio_oe : int
  }

let view t =
  let pio = t.pio in
  let fst = Pgsim.fstat pio land sm_mask ~num_sms:t.num_sms fstat_bits in
  let fdb = Pgsim.fdebug pio land sm_mask ~num_sms:t.num_sms fdebug_bits in
  let flv = Pgsim.flevel pio land sm_mask ~num_sms:t.num_sms flevel_bits in
  let irq = pio.Pgsim.irq in
  let pins_out = Pgsim.pins_out pio in
  let pins_oe = Pgsim.pins_oe pio in
  let miso = (t.miso_sr lsr 31) land 1 in
  (* Pads (9.2): uio_out is 0 where PAD_OD is set; the enable drops on an open-drain 0. *)
  let uio_out = ref 0 in
  let uio_oe = ref 0 in
  for i = 0 to 7 do
    let od = bit t.pad_od i in
    let po = bit pins_out i in
    if od = 0 then uio_out := !uio_out lor (po lsl i);
    if bit pins_oe i = 1 && not (od = 1 && po = 1) then uio_oe := !uio_oe lor (1 lsl i)
  done;
  (* HOST_IRQ (9.3): sources irq[3:0], RXNEMPTY at 7:4 and TXNFULL at 11:8. *)
  let src = irq land 0xF lor (nonempty_bits t fst lsl 4) lor (notfull_bits t fst lsl 8) in
  let host_irq = t.hostirq_en land src <> 0 in
  let uo6 = if t.hostirq_en <> 0 then Bool.to_int host_irq else bit pins_out 14 in
  let uo_out = (pins_out lsr 8) land 0x3F lor (uo6 lsl 6) lor (miso lsl 7) in
  { fst
  ; fdb
  ; flv
  ; irq
  ; pins_out
  ; pins_oe
  ; miso
  ; uo_out
  ; uio_out = !uio_out
  ; uio_oe = !uio_oe
  }
;;

(* The pad input path (9.2): an output pad reads what it drives, the others the level. *)
let uio_in v ~uio_ext = (v.uio_oe land v.uio_out) lor (uio_ext land lnot v.uio_oe) land 0xFF

(* The pins_in vector of the engines (9.1): {8'b0, ui_in, uo_out, uio_in}. *)
let pins_in v ~ui_in ~uio_ext =
  ((ui_in land 0xFF) lsl 16) lor (v.uo_out lsl 8) lor uio_in v ~uio_ext
;;

(* The value a bus read returns at the start of the cycle (8.1 and 8.3), and for RXFn the
   record its commit needs. An absent SM's RXFn reads 0 and records nothing. *)
let read_value t v ~ui_in ~uio_ext ~addr =
  let pio = t.pio in
  let a = addr land 0xFFFC in
  let sm_block = a >= 0x200 && a < 0x200 + (4 * 0x40) in
  let sm_n = (a - 0x200) / 0x40 in
  let off = (a - 0x200) mod 0x40 in
  let dbg f = if sm_block && present t sm_n then f (Pgsim.debug pio sm_n) else 0 in
  let plain x = x, None in
  if a = 0x000 then plain id_value
  else if a = 0x004 then plain (4 lor (t.num_sms lsl 8) lor (imem_depth lsl 16) lor (1 lsl 28))
  else if a = 0x008 then plain t.ctrl_en
  else if a = 0x00C then plain v.fst
  else if a = 0x010 then plain v.fdb
  else if a = 0x014 then plain v.flv
  else if a = 0x018 then plain v.irq
  else if a = 0x020 then plain t.hostirq_en
  else if a = 0x024 then plain t.pad_od
  else if a = 0x028 then plain t.sync_bypass
  else if a = 0x02C
  then plain ((ui_in land 0xFF) lsl 16 lor (v.uo_out lsl 8) lor uio_in v ~uio_ext)
  else if a = 0x030 then plain v.pins_out
  else if a = 0x034 then plain v.pins_oe
  else if a = 0x038 then plain t.scratch
  else if a >= 0x050 && a < 0x060
  then (
    let n = (a - 0x50) / 4 in
    if present t n
    then (
      let rempty = (Pgsim.debug pio n).Pgsim.rx_fifo = [] in
      Pgsim.rx_head pio n, Some { rsm = n; rempty })
    else plain 0)
  else if sm_block
  then (
    let r = t.regs.(sm_n) in
    match off with
    | _ when not (present t sm_n) -> plain 0
    | 0x00 -> plain r.clkdiv
    | 0x04 ->
      plain
        ((r.execctrl land execctrl_mask)
         lor dbg (fun d -> if d.Pgsim.exec_stalled then 1 lsl 31 else 0))
    | 0x08 -> plain r.shiftctrl
    | 0x0C -> plain (dbg (fun d -> d.Pgsim.pc land 0x1F))
    | 0x10 -> plain (dbg (fun d -> d.Pgsim.instr))
    | 0x14 -> plain r.pinctrl
    | 0x18 -> plain (r.ext land 1)
    | 0x2C -> plain (dbg (fun d -> d.Pgsim.x))
    | 0x30 -> plain (dbg (fun d -> d.Pgsim.y))
    | 0x34 -> plain (dbg (fun d -> d.Pgsim.isr))
    | 0x38 -> plain (dbg (fun d -> d.Pgsim.osr))
    | 0x3C -> plain (if present t sm_n then Pgsim.dbg_cnt pio sm_n else 0)
    | _ -> plain 0)
  else plain 0
;;

(* Is [addr] a mapped register (8.1)? SRAM is absent here. *)
let mapped _t addr =
  let a = addr land 0xFFFC in
  List.mem a [ 0x000; 0x004; 0x008; 0x00C; 0x010; 0x014; 0x018; 0x01C; 0x020; 0x024; 0x028; 0x02C; 0x030; 0x034; 0x038; 0x060 ]
  || (a >= 0x040 && a < 0x060)
  || (a >= 0x100 && a < 0x100 + (4 * imem_depth))
  || (a >= 0x200 && a < 0x300)
;;

let read_reg t ~ui_in ~uio_ext addr =
  configure t;
  let v = view t in
  Stdlib.fst (read_value t v ~ui_in ~uio_ext ~addr)
;;

(* A bus write (8.2). The engine pulses go into [pulses]; the register updates go into
   [updates], and are applied at the end of the cycle. *)
let bus_write t ~addr ~data ~pulses ~updates =
  let a = addr land 0xFFFC in
  let pulse p = pulses := p :: !pulses in
  let later f = updates := f :: !updates in
  let sm_block = a >= 0x200 && a < 0x200 + (4 * 0x40) in
  let sm_n = (a - 0x200) / 0x40 in
  let off = (a - 0x200) mod 0x40 in
  let live n = present t n in
  if a = 0x008
  then (
    let en = data land 0xF land sm_mask ~num_sms:t.num_sms (fun n -> 1 lsl n) in
    let sr = (data lsr 4) land 0xF land sm_mask ~num_sms:t.num_sms (fun n -> 1 lsl n) in
    let cr = (data lsr 8) land 0xF land sm_mask ~num_sms:t.num_sms (fun n -> 1 lsl n) in
    later (fun () -> t.ctrl_en <- en);
    if sr <> 0 then pulse (Pgsim.Host_op.Sm_restart sr);
    if cr <> 0 then pulse (Pgsim.Host_op.Clkdiv_restart cr))
  else if a = 0x010
  then (
    let m = data land fdebug_layout in
    if m <> 0 then pulse (Pgsim.Host_op.Fdebug_clear m))
  else if a = 0x018
  then (
    let m = data land 0xFF in
    if m <> 0 then pulse (Pgsim.Host_op.Irq_clear m))
  else if a = 0x01C
  then (
    let m = data land 0xFF in
    if m <> 0 then pulse (Pgsim.Host_op.Irq_force m))
  else if a = 0x020
  then later (fun () -> t.hostirq_en <- data land hostirq_mask)
  else if a = 0x024
  then later (fun () -> t.pad_od <- data land 0xFF)
  else if a = 0x028
  then later (fun () -> t.sync_bypass <- data land sync_mask)
  else if a = 0x038
  then later (fun () -> t.scratch <- data land m32)
  else if a >= 0x040 && a < 0x050
  then (
    let n = (a - 0x40) / 4 in
    if live n then pulse (Pgsim.Host_op.Tx_push { sm = n; data = data land m32 }))
  else if a >= 0x100 && a < 0x100 + (4 * imem_depth)
  then pulse (Pgsim.Host_op.Imem_write { addr = (a - 0x100) / 4; data = data land 0xFFFF })
  else if sm_block && live sm_n
  then (
    let r = t.regs.(sm_n) in
    match off with
    | 0x00 -> later (fun () -> r.clkdiv <- data land clkdiv_mask)
    | 0x04 -> later (fun () -> r.execctrl <- data land execctrl_mask)
    | 0x08 ->
      (* An FJOIN change flushes both FIFOs at the end of this cycle (8.2). *)
      let old = (r.shiftctrl lsr 30) land 3 in
      if (data lsr 30) land 3 <> old then pulse (Pgsim.Host_op.Fifo_flush (1 lsl sm_n));
      later (fun () -> r.shiftctrl <- data land shiftctrl_mask)
    | 0x10 -> pulse (Pgsim.Host_op.Instr_write { sm = sm_n; data = data land 0xFFFF })
    | 0x14 -> later (fun () -> r.pinctrl <- data land m32)
    | 0x18 -> later (fun () -> r.ext <- data land 1)
    | _ -> ())
  else ()
;;

(* One cycle with the pad levels [ui_in] and [uio_ext] (the external level of each pad). The
   outputs are those of the start of the cycle. *)
let step t ~ui_in ~uio_ext =
  let ui_in = ui_in land 0xFF and uio_ext = uio_ext land 0xFF in
  configure t;
  let v = view t in
  let sck_pin = bit ui_in 5 and mosi_pin = bit ui_in 6 and csn_pin = bit ui_in 7 in
  (* The synchronised SCK, MOSI and CS_N of this cycle (6.1). *)
  let sck2 = t.sck.(1) and sck3 = t.sck.(2) in
  let mosi2 = t.mosi.(1) in
  let csn2 = t.csn.(1) and csn3 = t.csn.(2) in
  let start = csn2 = 0 && csn3 = 1 in
  let end_ = csn2 = 1 && csn3 = 0 in
  let rise = sck2 = 1 && sck3 = 0 && csn2 = 0 && csn3 = 0 in
  let pulses = ref [] in
  let updates = ref [] in
  let bus = ref no_bus in
  (* MISO shift register (6.5): the next value. *)
  let miso_next = ref (t.miso_sr) in
  let rx_next = ref t.rx_pend in
  let later f = updates := f :: !updates in
  if start
  then (
    later (fun () ->
      t.in_frame <- true;
      t.rises <- 0;
      t.cmd_r <- 0;
      t.cmd_f <- 0;
      t.addr_reg <- 0;
      t.wacc <- 0);
    miso_next := status t v.fst lsl 24;
    rx_next := None)
  else if end_
  then (
    later (fun () -> t.in_frame <- false);
    miso_next := 0;
    rx_next := None)
  else if rise && t.in_frame
  then (
    let j = t.rises in
    let b = mosi2 in
    later (fun () -> t.rises <- j + 1);
    (* Frame fields (6.3). *)
    if j = 0 then later (fun () -> t.cmd_r <- b);
    if j = 1 then later (fun () -> t.cmd_f <- b);
    if j >= 8 && j < 24
    then later (fun () -> t.addr_reg <- ((t.addr_reg lsl 1) lor b) land 0xFFFF);
    if j >= 24 then later (fun () -> t.wacc <- ((t.wacc lsl 1) lor b) land m32);
    let rd = t.cmd_r = 1 in
    let word_addr m =
      let base = if t.cmd_f = 1 then t.addr_reg else t.addr_reg + (4 * m) in
      base land 0xFFFC land 0xFFFF
    in
    (* Bus accesses (6.4). *)
    let shifted = ref true in
    if (not rd) && j >= 24 && (j - 24) mod 32 = 31
    then (
      let m = (j - 24) / 32 in
      let wdata = ((t.wacc lsl 1) lor b) land m32 in
      let addr = word_addr m in
      bus := { no_bus with write = true; addr; wdata };
      bus_write t ~addr ~data:wdata ~pulses ~updates)
    else if rd && j >= 31 && (j - 31) mod 32 = 0
    then (
      let m = (j - 31) / 32 in
      let addr = word_addr m in
      let value, pend = read_value t v ~ui_in ~uio_ext ~addr in
      bus := { no_bus with read = true; addr; rdata = value };
      rx_next := pend;
      miso_next := value;
      shifted := false)
    else if rd && j >= 32 && (j - 32) mod 32 = 0
    then (
      let m = (j - 32) / 32 in
      bus := { no_bus with commit = true; addr = word_addr m };
      (* The commit of an RXFn read pops it, or sets RXUNDER if it was empty (8.3). *)
      match t.rx_pend with
      | Some { rsm; rempty } ->
        if rempty
        then pulses := Pgsim.Host_op.Fdebug_set (1 lsl (8 + rsm)) :: !pulses
        else pulses := Pgsim.Host_op.Rx_pop { sm = rsm } :: !pulses;
        rx_next := None
      | None -> ());
    if !shifted then miso_next := (t.miso_sr lsl 1) land m32);
  (* The engines, with this cycle's pins and pulses. The engine reads its input pins from
     [pins_in], which is set before the step (9.1). *)
  let pins_in = pins_in v ~ui_in ~uio_ext in
  t.pio.Pgsim.ext <- pins_in;
  ignore (Pgsim.step_ex ~host:(List.rev !pulses) t.pio);
  (* End of cycle: the synchronisers shift, and the registers take their new values. *)
  t.csn.(2) <- t.csn.(1);
  t.csn.(1) <- t.csn.(0);
  t.csn.(0) <- csn_pin;
  t.sck.(2) <- t.sck.(1);
  t.sck.(1) <- t.sck.(0);
  t.sck.(0) <- sck_pin;
  t.mosi.(2) <- t.mosi.(1);
  t.mosi.(1) <- t.mosi.(0);
  t.mosi.(0) <- mosi_pin;
  List.iter (fun f -> f ()) (List.rev !updates);
  t.miso_sr <- !miso_next;
  t.rx_pend <- !rx_next;
  t.ncycle <- t.ncycle + 1;
  { uo_out = v.uo_out; uio_out = v.uio_out; uio_oe = v.uio_oe; miso = v.miso; bus = !bus }
;;

(* The outputs of the next cycle, for the given pads, without changing the state. *)
let peek t ~ui_in ~uio_ext =
  configure t;
  let v = view t in
  ignore (ui_in, uio_ext);
  { uo_out = v.uo_out; uio_out = v.uio_out; uio_oe = v.uio_oe; miso = v.miso; bus = no_bus }
;;
