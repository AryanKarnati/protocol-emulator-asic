(* pgsim: cycle-accurate golden model of one RP2040-style PIO block (4 state machines),
   base ISA only (block 1 scope). One call to [step] is one system clock cycle.

   Sources: RP2040 datasheet section 3 ("PIO", rev as downloaded to ~/.cache/polyglot).
   Section numbers are cited next to every rule that is not obvious. Where the datasheet
   is silent or ambiguous, the choice is marked AMBIGUITY and listed in sw/pgsim/README.md.

   Not modelled in this block: LCU (in lcu, mov ..., crc, set lcu raise), the host link,
   IO direction and output-only pad rules (DESIGN.md 5), INLINE_OUT_EN / OUT_EN_SEL, EXT
   and PAGE, the pad-level FSTAT/FDEBUG pin-direction details. *)

module Isa = Polyglot_isa.Isa

let m32 = 0xFFFF_FFFF
let mask n = (1 lsl n) - 1
let bit v i = (v lsr i) land 1

let rotl32 x r =
  let r = r land 31 in
  ((x lsl r) lor (x lsr (32 - r))) land m32
;;

let rotr32 x r = rotl32 x ((32 - r) land 31)

let reverse32 x =
  let r = ref 0 in
  for i = 0 to 31 do
    if bit x i = 1 then r := !r lor (1 lsl (31 - i))
  done;
  !r
;;

(* Pins [base .. base+count-1] (mod 32), as a 32-bit mask. *)
let group_mask base count = rotl32 (mask count) base

(* Value bit i goes to pin base+i (mod 32). Only the low [count] bits of [v] are used. *)
let place base count v = rotl32 (v land mask count) base

(* ------------------------------------------------------------------------------------ *)
(* Configuration, in the RP2040 register layout (datasheet 3.7; SMx_CLKDIV, EXECCTRL,
   SHIFTCTRL, PINCTRL). The values here are the numbers a capture script writes. *)

module Config = struct
  type t =
    { clkdiv_int : int (* 0 means 65536 (datasheet 3.7, SMx_CLKDIV) *)
    ; clkdiv_frac : int
    ; side_en : bool (* EXECCTRL.SIDE_EN, datasheet 3.5.1 *)
    ; side_pindir : bool (* EXECCTRL.SIDE_PINDIR *)
    ; jmp_pin : int (* EXECCTRL.JMP_PIN *)
    ; out_sticky : bool (* EXECCTRL.OUT_STICKY *)
    ; wrap_top : int
    ; wrap_bottom : int
    ; status_rx : bool (* EXECCTRL.STATUS_SEL: true = RXLEVEL, false = TXLEVEL *)
    ; status_n : int
    ; fjoin_rx : bool (* SHIFTCTRL.FJOIN_RX, datasheet 3.5.3 *)
    ; fjoin_tx : bool
    ; pull_thresh : int (* 1..32; register value 0 means 32 *)
    ; push_thresh : int
    ; out_right : bool (* SHIFTCTRL.OUT_SHIFTDIR, 1 = right *)
    ; in_right : bool
    ; autopull : bool
    ; autopush : bool
    ; sideset_count : int (* PINCTRL.SIDESET_COUNT, includes the enable bit *)
    ; set_count : int
    ; out_count : int
    ; in_base : int
    ; sideset_base : int
    ; set_base : int
    ; out_base : int
    }

  let field v hi lo = (v lsr lo) land mask (hi - lo + 1)

  let of_registers ~clkdiv ~execctrl ~shiftctrl ~pinctrl =
    let thresh v = match v with 0 -> 32 | n -> n in
    { clkdiv_int = field clkdiv 31 16
    ; clkdiv_frac = field clkdiv 15 8
    ; side_en = field execctrl 30 30 = 1
    ; side_pindir = field execctrl 29 29 = 1
    ; jmp_pin = field execctrl 28 24
    ; out_sticky = field execctrl 17 17 = 1
    ; wrap_top = field execctrl 16 12
    ; wrap_bottom = field execctrl 11 7
    ; status_rx = field execctrl 4 4 = 1
    ; status_n = field execctrl 3 0
    ; fjoin_rx = field shiftctrl 31 31 = 1
    ; fjoin_tx = field shiftctrl 30 30 = 1
    ; pull_thresh = thresh (field shiftctrl 29 25)
    ; push_thresh = thresh (field shiftctrl 24 20)
    ; out_right = field shiftctrl 19 19 = 1
    ; in_right = field shiftctrl 18 18 = 1
    ; autopull = field shiftctrl 17 17 = 1
    ; autopush = field shiftctrl 16 16 = 1
    ; sideset_count = field pinctrl 31 29
    ; set_count = field pinctrl 28 26
    ; out_count = field pinctrl 25 20
    ; in_base = field pinctrl 19 15
    ; sideset_base = field pinctrl 14 10
    ; set_base = field pinctrl 9 5
    ; out_base = field pinctrl 4 0
    }
  ;;

  let put v hi lo x = v lor ((x land mask (hi - lo + 1)) lsl lo)

  let clkdiv_register c = put (put 0 31 16 c.clkdiv_int) 15 8 c.clkdiv_frac

  let execctrl_register c =
    let v = 0 in
    let v = put v 30 30 (Bool.to_int c.side_en) in
    let v = put v 29 29 (Bool.to_int c.side_pindir) in
    let v = put v 28 24 c.jmp_pin in
    let v = put v 17 17 (Bool.to_int c.out_sticky) in
    let v = put v 16 12 c.wrap_top in
    let v = put v 11 7 c.wrap_bottom in
    let v = put v 4 4 (Bool.to_int c.status_rx) in
    put v 3 0 c.status_n
  ;;

  let shiftctrl_register c =
    let t n = if n = 32 then 0 else n in
    let v = 0 in
    let v = put v 31 31 (Bool.to_int c.fjoin_rx) in
    let v = put v 30 30 (Bool.to_int c.fjoin_tx) in
    let v = put v 29 25 (t c.pull_thresh) in
    let v = put v 24 20 (t c.push_thresh) in
    let v = put v 19 19 (Bool.to_int c.out_right) in
    let v = put v 18 18 (Bool.to_int c.in_right) in
    let v = put v 17 17 (Bool.to_int c.autopull) in
    put v 16 16 (Bool.to_int c.autopush)
  ;;

  let pinctrl_register c =
    let v = 0 in
    let v = put v 31 29 c.sideset_count in
    let v = put v 28 26 c.set_count in
    let v = put v 25 20 c.out_count in
    let v = put v 19 15 c.in_base in
    let v = put v 14 10 c.sideset_base in
    let v = put v 9 5 c.set_base in
    put v 4 0 c.out_base
  ;;

  (* RP2040 reset values (datasheet 3.7): CLKDIV 0x00010000, EXECCTRL 0x0001F000,
     SHIFTCTRL 0x000C0000, PINCTRL 0x14000000. *)
  let reset =
    of_registers
      ~clkdiv:0x0001_0000
      ~execctrl:0x0001_F000
      ~shiftctrl:0x000C_0000
      ~pinctrl:0x1400_0000
  ;;
end

(* ------------------------------------------------------------------------------------ *)
(* FIFOs. 4 deep each; joining gives one FIFO 8 deep and the other 0 (datasheet 3.5.3). *)

module Fifo = struct
  type t =
    { mutable items : int list (* head first *)
    ; mutable depth : int
    }

  let create depth = { items = []; depth }
  let level f = List.length f.items
  let full f = level f >= f.depth
  let empty f = match f.items with [] -> true | _ -> false
  let push f w = f.items <- f.items @ [ w ]

  let pop f =
    match f.items with
    | [] -> None
    | h :: tl ->
      f.items <- tl;
      Some h
  ;;

  let flush f = f.items <- []
end

(* ------------------------------------------------------------------------------------ *)
(* Per-cycle pin write accumulators. Level and direction are separate (datasheet 3.5.6). *)

type pinw =
  { mutable lm : int
  ; mutable lv : int
  ; mutable dm : int
  ; mutable dv : int
  }

let pinw_create () = { lm = 0; lv = 0; dm = 0; dv = 0 }

let pinw_copy w = { lm = w.lm; lv = w.lv; dm = w.dm; dv = w.dv }

let pinw_to_tuple w = w.lm, w.lv, w.dm, w.dv

let pinw_empty w = w.lm = 0 && w.dm = 0

let add_lvl w m v =
  w.lm <- w.lm lor m;
  w.lv <- w.lv land lnot m lor (v land m)
;;

let add_dir w m v =
  w.dm <- w.dm lor m;
  w.dv <- w.dv land lnot m lor (v land m)
;;

(* ------------------------------------------------------------------------------------ *)
(* State *)

type stall =
  | No_stall
  | Stall_tx_empty (* blocking PULL, TX FIFO empty *)
  | Stall_rx_full (* blocking PUSH, or autopush, RX FIFO full *)
  | Stall_autopull (* OUT with OSR at its threshold (datasheet 3.5.4.2) *)
  | Stall_wait_gpio (* WAIT GPIO, datasheet 3.4.3 *)
  | Stall_wait_pin (* WAIT PIN *)
  | Stall_wait_irq (* WAIT IRQ, datasheet 3.4.3.2 *)
  | Stall_irq_wait (* IRQ wait: flag raised, waiting for the host to clear it, 3.4.9.2 *)

type latch =
  | No_latch
  | Exec_latch of int (* from OUT EXEC / MOV EXEC (datasheet 3.5.7) *)
  | Host_latch of int (* written to SMx_INSTR *)

type sm =
  { index : int
  ; mutable cfg : Config.t
  ; mutable enabled : bool
  ; mutable pc : int
  ; mutable x : int
  ; mutable y : int
  ; mutable isr : int
  ; mutable isr_count : int
  ; mutable osr : int
  ; mutable osr_count : int
  ; mutable delay : int
  ; mutable side_done : bool (* side-set already applied to the instruction in progress *)
  ; mutable host_side_done : bool (* same, for the forced instruction in the host latch *)
  ; mutable latch : latch
  ; mutable irq_wait : int option (* flag an IMEM IRQ instruction raised and waits on *)
  ; mutable latch_irq_wait : int option (* same, for a latched EXEC or host IRQ instruction *)
  ; mutable latch_stall : stall (* stall reason of the latched EXEC or host instruction *)
  ; mutable acc : int (* clock divider accumulator, 1/256 units *)
  ; mutable tx : Fifo.t
  ; mutable rx : Fifo.t
  ; mutable txstall : bool (* FDEBUG.TXSTALL *)
  ; mutable txover : bool (* FDEBUG.TXOVER *)
  ; mutable rxunder : bool (* FDEBUG.RXUNDER *)
  ; mutable rxstall : bool (* FDEBUG.RXSTALL *)
  ; mutable illegal : bool (* FDEBUG.ILLEGAL-like sticky flag, see DESIGN.md 9.1 *)
  ; mutable stall : stall
  ; mutable sticky : pinw (* OUT_STICKY: last OUT/SET/MOV pin write *)
  ; mutable page : int (* SMn_EXT.PAGE, bit 0 (engine.md 9) *)
  }

type t =
  { sms : sm array
  ; imem : int array (* 64 words, two pages of 32 (engine.md 9) *)
  ; mutable cycle : int
  ; mutable irq : int (* 8 flags, datasheet 3.2.6 *)
  ; mutable pin_level : int (* output level register, 32 bits *)
  ; mutable pin_dir : int (* output enable register, 1 = driven by PIO *)
  ; mutable ext : int (* external pad levels, set by the caller *)
  ; mutable sync_bypass : int (* INPUT_SYNC_BYPASS (datasheet 3.5.6.3) *)
  ; hist : int array (* hist.(k) = pad level k cycles ago *)
  }

(* (tx depth, rx depth). Joining one direction gives it 8 entries and the other 0
   (datasheet 3.5.3). *)
let fifo_depths (c : Config.t) =
  if c.fjoin_tx then 8, 0 else if c.fjoin_rx then 0, 8 else 4, 4
;;

let create () =
  let cfg = Config.reset in
  let tx_d, rx_d = fifo_depths cfg in
  let sms =
    Array.init 4 (fun index ->
      { index
      ; cfg
      ; enabled = false
      ; pc = 0
      ; x = 0
      ; y = 0
      ; isr = 0
      ; isr_count = 0
      ; osr = 0
      ; osr_count = 32 (* datasheet 3.2.3.3: OSR counter resets to 32 *)
      ; delay = 0
      ; side_done = false
      ; host_side_done = false
      ; latch = No_latch
      ; irq_wait = None
      ; latch_irq_wait = None
      ; latch_stall = No_stall
      ; acc = 0
      ; tx = Fifo.create tx_d
      ; rx = Fifo.create rx_d
      ; txstall = false
      ; txover = false
      ; rxunder = false
      ; rxstall = false
      ; illegal = false
      ; stall = No_stall
      ; sticky = pinw_create ()
      ; page = 0
      })
  in
  { sms
  ; imem = Array.make 64 0
  ; cycle = 0
  ; irq = 0
  ; pin_level = 0
  ; pin_dir = 0
  ; ext = 0
  ; sync_bypass = 0
  ; hist = Array.make 4 0
  }
;;

(* Pad level for this cycle: a PIO-driven pin shows its level, others show the external
   level. Writes made in cycle c show on the pad in cycle c+1 (one register stage). *)
let pad_now t =
  ((t.pin_level land t.pin_dir) lor (t.ext land lnot t.pin_dir)) land m32
;;

(* The value IN, JMP PIN, WAIT GPIO and WAIT PIN see. The pad from 1 cycle ago is bypassed
   for pins in [sync_bypass]; the others go through the 2-FF synchroniser, which adds two
   cycles (datasheet 3.5.6.1 and 3.5.6.3). *)
let synced t =
  ((t.hist.(1) land t.sync_bypass) lor (t.hist.(3) land lnot t.sync_bypass)) land m32
;;

let set_config t i cfg =
  let sm = t.sms.(i) in
  let old = sm.cfg in
  sm.cfg <- cfg;
  if old.fjoin_rx <> cfg.fjoin_rx || old.fjoin_tx <> cfg.fjoin_tx
  then (
    (* Changing FJOIN discards FIFO contents (datasheet 3.5.3). *)
    let tx_d, rx_d = fifo_depths cfg in
    sm.tx <- Fifo.create tx_d;
    sm.rx <- Fifo.create rx_d)
;;

let load_program t words =
  Array.fill t.imem 0 (Array.length t.imem) 0;
  List.iteri (fun i w -> if i < Array.length t.imem then t.imem.(i) <- w land 0xFFFF) words
;;

(* ------------------------------------------------------------------------------------ *)
(* Decoding helpers. Everything the model needs from an instruction goes through here. *)

let delay_side_of (ins : Isa.t) = Isa.delay_side ins

let side_cfg (c : Config.t) : Isa.Side.config option =
  if c.sideset_count = 0
  then None
  else Some { Isa.Side.count = c.sideset_count; enable = c.side_en }
;;

(* Side-set on the first attempt, from the delay/side-set field (datasheet 3.5.1). *)
let split_side (c : Config.t) ds : int option * int =
  match side_cfg c with
  | None -> None, ds
  | Some sc ->
    let s = Isa.Side.split sc ds in
    s.side, s.delay
;;

let irq_index sm_index index rel =
  if rel then index land 4 lor ((index + sm_index) land 3) else index
;;

(* Next PC after a non-jump instruction (datasheet 3.5.2 rule 2 and 3). *)
let wrap_next (c : Config.t) pc = if pc = c.wrap_top then c.wrap_bottom else (pc + 1) land 31

(* ------------------------------------------------------------------------------------ *)
(* Instruction bodies *)

(* Where an instruction came from. Decides PC, delay, latch and IRQ-wait handling
   (datasheet 3.2.2, 3.5.7). *)
type src =
  | Imem
  | Exec
  | Host

type outcome =
  | Stalled of stall
  | Done of
      { jump : int option
      ; delay_applies : bool
      ; exec : int option
      }

let done_ ?jump ?(delay_applies = true) ?exec () = Done { jump; delay_applies; exec }

(* Writes made by one instruction: body (OUT/SET/MOV) and side-set are kept apart because
   side-set wins on the same pin (datasheet 3.5.6). *)
let body sm ins ~src ~synced ~irq_snap ~(bodyw : pinw) ~(setw : int ref) ~(clrw : int ref) =
  let c = sm.cfg in
  let thr_pull = c.pull_thresh in
  let thr_push = c.push_thresh in
  match ins with
  | Isa.Illegal _ -> done_ ()
  | Isa.Jmp { cond; addr; _ } ->
    let taken =
      match (cond : Isa.jmp_cond) with
      | Always -> true
      | Not_x -> sm.x = 0
      | X_dec ->
        let r = sm.x <> 0 in
        sm.x <- (sm.x - 1) land m32;
        r
      | Not_y -> sm.y = 0
      | Y_dec ->
        let r = sm.y <> 0 in
        sm.y <- (sm.y - 1) land m32;
        r
      | X_ne_y -> sm.x <> sm.y
      | Jmp_pin -> bit synced c.jmp_pin = 1
      (* !OSRE: OSR not empty, i.e. fewer bits shifted out than the pull threshold
         (datasheet 3.4.2.2). AMBIGUITY: "empty" read as count >= threshold. *)
      | Not_osre -> sm.osr_count < thr_pull
    in
    done_ ?jump:(if taken then Some addr else None) ()
  | Isa.Wait { polarity; source; _ } ->
    let pol = Bool.to_int polarity in
    (match (source : Isa.wait_source) with
     | Wsrc_gpio n ->
       if bit synced n = pol then done_ () else Stalled Stall_wait_gpio
     | Wsrc_pin n ->
       if bit synced ((c.in_base + n) land 31) = pol then done_ () else Stalled Stall_wait_pin
     | Wsrc_irq { index; rel } ->
       let i = irq_index sm.index index rel in
       if bit irq_snap i = pol
       then (
         (* WAIT 1 IRQ clears the flag when the condition is met (datasheet 3.4.3.2). *)
         if pol = 1 then clrw := !clrw lor (1 lsl i);
         done_ ())
       else Stalled Stall_wait_irq)
  | Isa.In { source; bit_count = n; _ } ->
    (match (source : Isa.in_source) with
     | In_lcu -> done_ () (* unreachable: [attempt] runs LCU words as Illegal (R12) *)
     | In_status -> done_ () (* not reached: is_legal is false, handled by the caller *)
     | _ ->
       let v =
         match source with
         | In_pins -> rotr32 synced c.in_base
         | In_x -> sm.x
         | In_y -> sm.y
         | In_null -> 0
         | In_isr -> sm.isr
         | In_osr -> sm.osr
         | In_lcu | In_status -> assert false
       in
       let new_count = min 32 (sm.isr_count + n) in
       (* An autopush that would hit a full RX FIFO stalls before anything changes
          (datasheet 3.5.4.1). *)
       if c.autopush && new_count >= thr_push && Fifo.full sm.rx
       then (
        (* Blocking PUSH or autopush into a full RX FIFO sets RXSTALL (datasheet 3.4.6.2). *)
        sm.rxstall <- true;
        Stalled Stall_rx_full)
       else (
         let data = v land mask n in
         let isr' =
           if c.in_right
           then (sm.isr lsr n) lor (data lsl (32 - n)) land m32
           else ((sm.isr lsl n) lor data) land m32
         in
         if c.autopush && new_count >= thr_push
         then (
           Fifo.push sm.rx isr';
           sm.isr <- 0;
           sm.isr_count <- 0)
         else (
           sm.isr <- isr';
           sm.isr_count <- new_count);
         done_ ()))
  | Isa.Out { dest; bit_count = n; _ } ->
    if c.autopull && sm.osr_count >= thr_pull
    then (
      (* Datasheet 3.5.4.2: OUT with the OSR at threshold pulls if it can, then stalls. *)
      if Fifo.empty sm.tx
      then (
        sm.txstall <- true;
        Stalled Stall_autopull)
      else (
        (match Fifo.pop sm.tx with
         | Some w ->
           sm.osr <- w;
           sm.osr_count <- 0
         | None -> ());
        Stalled Stall_autopull))
    else (
      let value =
        if c.out_right
        then sm.osr land mask n
        else (sm.osr lsr (32 - n)) land mask n
      in
      let osr' = if c.out_right then sm.osr lsr n else (sm.osr lsl n) land m32 in
      let count' = min 32 (sm.osr_count + n) in
      (* Commit the destination write. *)
      let exec = ref None in
      let jump = ref None in
      let delay_applies = ref true in
      (match (dest : Isa.out_dest) with
       | Out_pins -> add_lvl bodyw (group_mask c.out_base c.out_count) (place c.out_base c.out_count value)
       | Out_pindirs -> add_dir bodyw (group_mask c.out_base c.out_count) (place c.out_base c.out_count value)
       | Out_x -> sm.x <- value
       | Out_y -> sm.y <- value
       | Out_null -> ()
       | Out_pc -> jump := Some (value land 31)
       | Out_isr ->
         sm.isr <- value;
         sm.isr_count <- min 32 n
       | Out_exec ->
         exec := Some (value land 0xFFFF);
         (* Delay on the OUT itself is ignored (datasheet 3.4.5.2). *)
         delay_applies := false);
      (* Autopull refill on the same cycle as the last shift (datasheet 3.5.4.2). *)
      if c.autopull && count' >= thr_pull && not (Fifo.empty sm.tx)
      then (
        (match Fifo.pop sm.tx with
         | Some w ->
           sm.osr <- w;
           sm.osr_count <- 0
         | None -> ()))
      else (
        sm.osr <- osr';
        sm.osr_count <- count');
      Done { jump = !jump; delay_applies = !delay_applies; exec = !exec })
  | Isa.Push { if_full; block; _ } ->
    if if_full && sm.isr_count < thr_push
    then done_ ()
    else if Fifo.full sm.rx
    then
      if block
      then (
        (* Blocking PUSH or autopush into a full RX FIFO sets RXSTALL (datasheet 3.4.6.2). *)
        sm.rxstall <- true;
        Stalled Stall_rx_full)
      else (
        (* Non-blocking push onto a full RX FIFO: data lost, RXSTALL set, ISR cleared
           (datasheet 3.4.6.2). AMBIGUITY: the ISR count is cleared too. *)
        sm.rxstall <- true;
        sm.isr <- 0;
        sm.isr_count <- 0;
        done_ ())
    else (
      Fifo.push sm.rx sm.isr;
      sm.isr <- 0;
      sm.isr_count <- 0;
      done_ ())
  | Isa.Pull { if_empty; block; _ } ->
    (* OSR still holds unshifted data (count below threshold). *)
    let osr_has_data = sm.osr_count < thr_pull in
    if c.autopull && sm.osr_count = 0
    then done_ () (* R4: under autopull a PULL is a no-op only when the OSR is full (count 0) *)
    else if if_empty && osr_has_data
    then done_ ()
    else if not (Fifo.empty sm.tx)
    then (
      (match Fifo.pop sm.tx with
       | Some w -> sm.osr <- w
       | None -> ());
      sm.osr_count <- 0;
      done_ ())
    else if block
    then (
      sm.txstall <- true;
      Stalled Stall_tx_empty)
    else (
      (* Non-blocking pull from an empty FIFO copies X to OSR (datasheet 3.4.7.2). *)
      sm.osr <- sm.x;
      sm.osr_count <- 0;
      done_ ())
  | Isa.Mov { dest; op; source; _ } ->
    let status_word =
      let level = if c.status_rx then Fifo.level sm.rx else Fifo.level sm.tx in
      if level < c.status_n then m32 else 0
    in
    let v0 =
      match (source : Isa.mov_source) with
      | Ms_pins -> rotr32 synced c.in_base
      | Ms_x -> sm.x
      | Ms_y -> sm.y
      | Ms_null -> 0
      | Ms_crc -> 0 (* unreachable: [attempt] runs LCU words as Illegal (R12) *)
      | Ms_status -> status_word
      | Ms_isr -> sm.isr
      | Ms_osr -> sm.osr
    in
    let v =
      match (op : Isa.mov_op) with
      | Op_none -> v0
      | Op_invert -> v0 lxor m32
      | Op_reverse -> reverse32 v0
    in
    (match (dest : Isa.mov_dest) with
     | Mov_pins -> add_lvl bodyw (group_mask c.out_base c.out_count) (place c.out_base c.out_count v); done_ ()
     | Mov_x ->
       sm.x <- v;
       done_ ()
     | Mov_y ->
       sm.y <- v;
       done_ ()
     | Mov_exec -> done_ ~delay_applies:false ~exec:(v land 0xFFFF) ()
     | Mov_pc -> done_ ~jump:(v land 31) ()
     | Mov_isr ->
       sm.isr <- v;
       sm.isr_count <- 0;
       done_ ()
     | Mov_osr ->
       sm.osr <- v;
       sm.osr_count <- 0;
       done_ ())
  | Isa.Irq { clear; wait; index; rel; _ } ->
    let i = irq_index sm.index index rel in
    (* An IMEM IRQ instruction and a latched (EXEC or host) one each have their own wait
       slot, so a forced IRQ cannot take over the wait of the stalled instruction
       (datasheet 3.2.2, 3.5.7). *)
    let slot_get () =
      match src with
      | Imem -> sm.irq_wait
      | Exec | Host -> sm.latch_irq_wait
    in
    let slot_set v =
      match src with
      | Imem -> sm.irq_wait <- v
      | Exec | Host -> sm.latch_irq_wait <- v
    in
    (match slot_get () with
     | Some w ->
       (* Already raised; stall until the flag is lowered (datasheet 3.4.9.2). *)
       if bit irq_snap w = 1
       then Stalled Stall_irq_wait
       else (
         slot_set None;
         done_ ())
     | None ->
       if clear
       then (
         clrw := !clrw lor (1 lsl i);
         done_ ())
       else (
         setw := !setw lor (1 lsl i);
         if wait
         then (
           slot_set (Some i);
           Stalled Stall_irq_wait)
         else done_ ()))
  | Isa.Set { dest; data; _ } ->
    (match (dest : Isa.set_dest) with
     | Set_pins ->
       add_lvl bodyw (group_mask c.set_base c.set_count) (place c.set_base c.set_count data);
       done_ ()
     | Set_pindirs ->
       add_dir bodyw (group_mask c.set_base c.set_count) (place c.set_base c.set_count data);
       done_ ()
     | Set_x ->
       sm.x <- data;
       done_ ()
     | Set_y ->
       sm.y <- data;
       done_ ()
     | Set_lcu -> done_ () (* unreachable: [attempt] runs LCU words as Illegal (R12) *))
;;

(* Execute [word] for one attempt. [src] says where it came from, which decides the PC and
   latch update. [sidew] receives the side-set writes of the first attempt. *)
(* Where an instruction came from. Decides PC and latch handling (datasheet 3.2.2, 3.5.7). *)
(* What one SM tick did, for the non-OUT autopull rule (datasheet 3.5.4.2). *)
type tick_kind =
  | Idle (* no enable tick, or a forced instruction: AMBIGUITY, see README *)
  | Out_tick (* an OUT, executed or stalled *)
  | Other_tick (* any other instruction, a delay cycle, or a stall *)

(* The three LCU extension encodings (DESIGN.md 9.2). *)
let lcu_word = function
  | Isa.In { source = In_lcu; _ } | Isa.Mov { source = Ms_crc; _ } | Isa.Set { dest = Set_lcu; _ } -> true
  | _ -> false
;;

(* Execute [word] once. [src] decides PC, delay and latch handling. Returns true if the
   instruction is an OUT. *)
let attempt sm ~src ~word ~synced ~irq_snap ~bodyw ~sidew ~setw ~clrw =
  let c = sm.cfg in
  let ins = Isa.decode word in
  (* The LCU extension words (in lcu, mov ..., crc, set lcu) are not modelled until block 5.
     They run as a NOP and set ILLEGAL, as reserved words do (R12). *)
  let legal = Isa.is_legal ins && not (lcu_word ins) in
  if not legal then sm.illegal <- true;
  let ds = delay_side_of ins in
  let host = src = Host in
  (* R11: the IMEM instruction and the latched one (forced or EXEC) each keep their own
     side-set-done flag. [host_side_done] is the latched flag, so an EXEC completing does not
     change the flag of the IMEM instruction it came from. *)
  let latched = src <> Imem in
  let first = not (if latched then sm.host_side_done else sm.side_done) in
  let side, delay = split_side c ds in
  let ins_body = if legal then ins else Isa.Illegal word in
  let is_out = match ins with Isa.Out _ -> true | _ -> false in
  let outcome = body sm ins_body ~src ~synced ~irq_snap ~bodyw ~setw ~clrw in
  (* Side-set is applied on the first attempt, even if the instruction stalls
     (datasheet 3.2.4 note, 3.5.1). It is written after the body, so it wins on a pin. *)
  (match side with
   | Some v when first ->
     let sbits = c.sideset_count - Bool.to_int c.side_en in
     if c.side_pindir
     then add_dir sidew (group_mask c.sideset_base sbits) (place c.sideset_base sbits v)
     else add_lvl sidew (group_mask c.sideset_base sbits) (place c.sideset_base sbits v)
   | _ -> ());
  let set_flag b = if latched then sm.host_side_done <- b else sm.side_done <- b in
  (match outcome with
   | Stalled r ->
     (match src with
      | Imem -> sm.stall <- r
      | Exec | Host -> sm.latch_stall <- r);
     set_flag true
   | Done { jump; delay_applies; exec } ->
     (* A latched instruction (EXEC or host) completes by clearing only [latch_stall]. The
        IMEM reason in [stall] is never touched, so the reported reason is correct on the
        same cycle (README, "Stall reason of a latched instruction"). *)
     (match src with
      | Imem -> sm.stall <- No_stall
      | Exec | Host -> sm.latch_stall <- No_stall);
     set_flag false;
     (* OUT_STICKY (ruling, engine.md): a completed OUT, SET or MOV pin write replaces the
        sticky record even when its pin mask is empty (SET_COUNT 0, OUT_COUNT 0). The record
        is then empty, so nothing is re-asserted. Side-set writes never touch the record. The
        record is kept whether or not OUT_STICKY is set; it is only asserted while set. This is
        the one site where the record is written. *)
     (match ins_body with
      | Isa.Out { dest = Out_pins | Out_pindirs; _ }
      | Isa.Set { dest = Set_pins | Set_pindirs; _ }
      | Isa.Mov { dest = Mov_pins; _ } ->
        sm.sticky <- pinw_copy bodyw
      | _ -> ());
     (match src, jump with
      | Imem, Some a -> sm.pc <- a
      | Imem, None -> sm.pc <- wrap_next c sm.pc
      | (Exec | Host), Some a ->
        (* F6: a latched instruction that writes the PC abandons the IMEM instruction in
           progress: its side-set flag, IRQ wait and IMEM stall reason are cleared. *)
        sm.pc <- a;
        sm.side_done <- false;
        sm.irq_wait <- None;
        sm.stall <- No_stall
      | (Exec | Host), None -> ());
     (* A forced instruction's delay is ignored, and it leaves a pending delay alone
        (datasheet 3.5.7: "Delay cycles are ignored on instructions written to the INSTR
        register"). OUT EXEC's own delay is ignored too (3.4.5.2). *)
     if not host then sm.delay <- (if delay_applies then delay else 0);
     if src <> Imem then sm.latch_irq_wait <- None;
     (* R11: a new EXEC latch starts with its own side-set flag clear. *)
     (match exec with Some _ -> sm.host_side_done <- false | None -> ());
     sm.latch
     <- (match exec with
         | Some w -> Exec_latch w
         | None -> No_latch));
  is_out
;;

(* The IMEM address an SM fetches in the current cycle: {PAGE, PC} (engine.md 9). *)
let fetch_addr sm = (sm.page lsl 5) lor sm.pc

(* One SM for one system cycle. [tick] is its clock-divider enable. *)
let run_sm t sm ~tick ~synced ~irq_snap ~bodyw ~sidew ~setw ~clrw : tick_kind =
  let attempt = attempt sm ~synced ~irq_snap ~bodyw ~sidew ~setw ~clrw in
  match sm.latch with
  | Host_latch w ->
    (* Forced instructions run at once, ignoring the divider and the enable
       (datasheet 3.5.7). *)
    ignore (attempt ~src:Host ~word:w);
    Idle
  | _ when not (sm.enabled && tick) -> Idle
  | _ when sm.delay > 0 ->
    sm.delay <- sm.delay - 1;
    Other_tick
  | Exec_latch w -> if attempt ~src:Exec ~word:w then Out_tick else Other_tick
  | No_latch -> if attempt ~src:Imem ~word:t.imem.(fetch_addr sm) then Out_tick else Other_tick
;;

(* Datasheet 3.5.4.2, "On non-OUT cycles": after a non-OUT tick, an osr count at or above
   the threshold refills the OSR from a non-empty TX FIFO (the MOV and PULL count clears
   have already been applied by their own bodies, so the order matches the pseudocode). *)
let autopull_after_non_out sm kind =
  match kind with
  | Other_tick when sm.cfg.autopull ->
    if sm.osr_count >= sm.cfg.pull_thresh && not (Fifo.empty sm.tx)
    then (
      match Fifo.pop sm.tx with
      | Some w ->
        sm.osr <- w;
        sm.osr_count <- 0
      | None -> ())
  | _ -> ()
;;

(* Clock divider: 16.8 fixed point. One tick every divisor/256 cycles, with the fractional
   part spread by a first-order accumulator (datasheet 3.5.5; same rule as docs/gate.md). *)
let divisor (c : Config.t) =
  ((if c.clkdiv_int = 0 then 65536 else c.clkdiv_int) * 256) + c.clkdiv_frac
;;

let divider_tick sm =
  let d = divisor sm.cfg in
  let t' = sm.acc + 256 in
  if t' >= d
  then (
    sm.acc <- t' - d;
    true)
  else (
    sm.acc <- t';
    false)
;;

(* ------------------------------------------------------------------------------------ *)
(* Host operations (block 2 contract, section 5, H1 to H9). An operation presented in cycle
   k is judged against the state at the start of that cycle, and takes effect at its end,
   together with the SMs' own updates. The immediate functions further down (used between
   cycles) apply the same effects at once. *)

module Host_op = struct
  type t =
    | Tx_push of
        { sm : int
        ; data : int
        }
    | Rx_pop of { sm : int }
    | Instr_write of
        { sm : int
        ; data : int
        }
    | Sm_restart of int (* SM mask *)
    | Clkdiv_restart of int (* SM mask *)
    | Irq_clear of int (* IRQ mask, write 1 to clear *)
    | Irq_force of int (* IRQ mask *)
    | Fdebug_clear of int (* FDEBUG layout mask, write 1 to clear *)
    | Fdebug_set of int (* FDEBUG layout mask, sets flags; a set wins over a clear (H8) *)
    | Fifo_flush of int (* SM mask *)
    | Imem_write of
        { addr : int
        ; data : int
        }
end

type step_result =
  { pads : int (* pads at the start of the cycle *)
  ; rx_data : int list (* one per [Rx_pop] in the list, in order (combinational, H2) *)
  }

let host_sm t i =
  if i < 0 || i > 3 then invalid_arg (Printf.sprintf "pgsim: SM %d out of range" i);
  t.sms.(i)
;;

(* CTRL.SM_RESTART (datasheet 3.7; contract H3). PC, OSR contents, X and Y keep their
   values. *)
let restart_sm sm =
  sm.isr <- 0;
  sm.isr_count <- 0;
  sm.osr_count <- 32;
  sm.delay <- 0;
  sm.latch <- No_latch;
  sm.side_done <- false;
  sm.host_side_done <- false;
  sm.irq_wait <- None;
  sm.latch_irq_wait <- None;
  sm.latch_stall <- No_stall;
  sm.stall <- No_stall;
  sm.sticky <- pinw_create ()
;;

let restart_sms t mask = Array.iteri (fun i sm -> if bit mask i = 1 then restart_sm sm) t.sms

(* SMx_INSTR (datasheet 3.2.2, 3.5.7; contract H7 and F1, F3, F5). The word is latched and
   runs on the next cycle. Its delay is ignored, and it does not touch the side-set state or
   the pending delay of the instruction it interrupts. *)
let latch_instr sm w =
  sm.latch <- Host_latch (w land 0xFFFF);
  sm.latch_irq_wait <- None;
  sm.latch_stall <- No_stall;
  sm.host_side_done <- false
;;

(* FDEBUG flags of one SM. *)
type fdbg =
  { f_txstall : bool
  ; f_txover : bool
  ; f_rxunder : bool
  ; f_rxstall : bool
  ; f_illegal : bool
  }

let fdbg_none =
  { f_txstall = false; f_txover = false; f_rxunder = false; f_rxstall = false; f_illegal = false }
;;

let fdbg_of_sm sm =
  { f_txstall = sm.txstall
  ; f_txover = sm.txover
  ; f_rxunder = sm.rxunder
  ; f_rxstall = sm.rxstall
  ; f_illegal = sm.illegal
  }
;;

let fdbg_store sm f =
  sm.txstall <- f.f_txstall;
  sm.txover <- f.f_txover;
  sm.rxunder <- f.f_rxunder;
  sm.rxstall <- f.f_rxstall;
  sm.illegal <- f.f_illegal
;;

(* The clear mask for SM [i] in the FDEBUG layout (RP2040 3.7, with ILLEGAL at [31:28]). *)
let fdbg_clear_of_mask mask i =
  { f_txstall = bit mask (24 + i) = 1
  ; f_txover = bit mask (16 + i) = 1
  ; f_rxunder = bit mask (8 + i) = 1
  ; f_rxstall = bit mask i = 1
  ; f_illegal = bit mask (28 + i) = 1
  }
;;

(* H8: flag_next = (flag AND NOT clear) OR set. [set] holds the flags set in this cycle. *)
let fdbg_merge ~pre ~clear ~set =
  let f p c s = (p && not c) || s in
  { f_txstall = f pre.f_txstall clear.f_txstall set.f_txstall
  ; f_txover = f pre.f_txover clear.f_txover set.f_txover
  ; f_rxunder = f pre.f_rxunder clear.f_rxunder set.f_rxunder
  ; f_rxstall = f pre.f_rxstall clear.f_rxstall set.f_rxstall
  ; f_illegal = f pre.f_illegal clear.f_illegal set.f_illegal
  }
;;

(* One system clock cycle, with the host operations of this cycle. *)
let step_ex ?(host = []) t =
  let pad = pad_now t in
  t.hist.(3) <- t.hist.(2);
  t.hist.(2) <- t.hist.(1);
  t.hist.(1) <- t.hist.(0);
  t.hist.(0) <- pad;
  let synced = synced t in
  let irq_snap = t.irq in
  (* F7 compares the IMEM write address with the fetch address at the start of the cycle. *)
  let fetch0 = Array.map fetch_addr t.sms in
  (* FDEBUG flags: the start-of-cycle values are kept aside, and the flags are rebuilt from
     the sets of this cycle (H8). *)
  let pre_flags = Array.map fdbg_of_sm t.sms in
  Array.iter (fun sm -> fdbg_store sm fdbg_none) t.sms;
  (* Host operations, judged against the start-of-cycle state (H1, H2). Their effects are
     collected here and applied at the end of the cycle. *)
  let restart = ref 0 in
  let clk_restart = ref 0 in
  let flush = ref 0 in
  let irq_clr = ref 0 in
  let irq_frc = ref 0 in
  let fd_mask = ref 0 in
  let fd_set = ref 0 in
  let tx_in = ref [] in
  let rx_out = ref [] in
  let rx_data = ref [] in
  let instrs = ref [] in
  let imem = ref [] in
  let pushed = Array.make 4 false in
  let popped = Array.make 4 false in
  List.iter
    (fun (op : Host_op.t) ->
      match op with
      | Tx_push { sm; data } ->
        let s = host_sm t sm in
        if pushed.(sm) then invalid_arg "pgsim: two TX pushes to one SM in a cycle";
        pushed.(sm) <- true;
        (* H1: a full FIFO drops the word, even if the SM pops in this cycle. *)
        if Fifo.full s.tx then s.txover <- true else tx_in := (sm, data land m32) :: !tx_in
      | Rx_pop { sm } ->
        let s = host_sm t sm in
        if popped.(sm) then invalid_arg "pgsim: two RX pops from one SM in a cycle";
        popped.(sm) <- true;
        (* H2: an empty FIFO gives 0 and sets RXUNDER. *)
        (match s.rx.Fifo.items with
         | [] ->
           s.rxunder <- true;
           rx_data := 0 :: !rx_data
         | w :: _ ->
           rx_data := w :: !rx_data;
           rx_out := sm :: !rx_out)
      | Instr_write { sm; data } ->
        ignore (host_sm t sm);
        instrs := (sm, data land 0xFFFF) :: !instrs
      | Sm_restart m -> restart := !restart lor (m land 0xF)
      | Clkdiv_restart m -> clk_restart := !clk_restart lor (m land 0xF)
      | Irq_clear m -> irq_clr := !irq_clr lor (m land 0xFF)
      | Irq_force m -> irq_frc := !irq_frc lor (m land 0xFF)
      | Fdebug_clear m -> fd_mask := !fd_mask lor m
      | Fdebug_set m -> fd_set := !fd_set lor m
      | Fifo_flush m -> flush := !flush lor (m land 0xF)
      | Imem_write { addr; data } -> imem := (addr land 63, data land 0xFFFF) :: !imem)
    host;
  let setw = ref 0 in
  let clrw = ref 0 in
  let pin_writes = Array.init 4 (fun _ -> pinw_create ()) in
  Array.iteri
    (fun i sm ->
      let tick = divider_tick sm in
      let bodyw = pinw_create () in
      let sidew = pinw_create () in
      let kind = run_sm t sm ~tick ~synced ~irq_snap ~bodyw ~sidew ~setw ~clrw in
      autopull_after_non_out sm kind;
      (* OUT_STICKY (datasheet 3.7): the last OUT, SET or MOV pin write is kept, forced
         writes included. It is asserted only while the SM is enabled, in the cycles that
         make no new write. *)
      let eff =
        if sm.cfg.out_sticky && sm.enabled && pinw_empty bodyw
        then pinw_copy sm.sticky
        else bodyw
      in
      let combine (dst : pinw) (src : pinw) =
        dst.lm <- dst.lm lor src.lm;
        dst.lv <- dst.lv land lnot src.lm lor (src.lv land src.lm);
        dst.dm <- dst.dm lor src.dm;
        dst.dv <- dst.dv land lnot src.dm lor (src.dv land src.dm)
      in
      let total = pinw_create () in
      combine total eff;
      combine total sidew;
      pin_writes.(i) <- total)
    t.sms;
  (* Output priority: for each pin the highest-numbered SM that writes it wins
     (datasheet 3.2.5, 3.5.6.1). Applying in ascending order gives that. *)
  Array.iter
    (fun (w : pinw) ->
      t.pin_level <- t.pin_level land lnot w.lm lor (w.lv land w.lm);
      t.pin_dir <- t.pin_dir land lnot w.dm lor (w.dv land w.dm))
    pin_writes;
  (* IRQ flags (H5): irq_next = (irq AND NOT (SM clears or host clears)) OR SM sets OR
     forced. A set always beats a clear in the same cycle (datasheet 3.2.7). WAIT and IRQ
     read the flags as they were at the start of the cycle. *)
  t.irq <- (irq_snap land lnot (!clrw lor !irq_clr)) lor !setw lor !irq_frc land 0xFF;
  (* FIFOs (H1, H2, H6): an SM pop happens before the host push joins the tail. *)
  List.iter (fun sm -> ignore (Fifo.pop t.sms.(sm).rx)) !rx_out;
  List.iter (fun (sm, w) -> Fifo.push t.sms.(sm).tx w) (List.rev !tx_in);
  for i = 0 to 3 do
    if bit !flush i = 1
    then (
      Fifo.flush t.sms.(i).tx;
      Fifo.flush t.sms.(i).rx)
  done;
  (* SM_RESTART (H3) overrides what the SM did in this cycle, then an INSTR write is latched
     (H7). CLKDIV_RESTART (H4) sets the phase to 0 after this cycle's tick. *)
  restart_sms t !restart;
  for i = 0 to 3 do
    if bit !clk_restart i = 1 then t.sms.(i).acc <- 0
  done;
  List.iter (fun (addr, data) -> t.imem.(addr) <- data) (List.rev !imem);
  (* F7: a write to the address equal to an SM's PC abandons that SM's IMEM instruction: its
     side-set flag, IRQ wait and IMEM stall reason are cleared. The value does not matter,
     and the delay counter is untouched. This overrides the SM's own attempt of this cycle. *)
  List.iter
    (fun (addr, _) ->
      Array.iteri
        (fun i sm ->
          if fetch0.(i) = addr
          then (
            sm.side_done <- false;
            sm.irq_wait <- None;
            sm.stall <- No_stall))
        t.sms)
    !imem;
  List.iter (fun (sm, w) -> latch_instr t.sms.(sm) w) (List.rev !instrs);
  (* FDEBUG (H8): the host set and the SMs' sets both win over a clear. *)
  Array.iteri
    (fun i sm ->
      let set = fdbg_of_sm sm in
      let hs = fdbg_clear_of_mask !fd_set i in
      fdbg_store
        sm
        (fdbg_merge
           ~pre:pre_flags.(i)
           ~clear:(fdbg_clear_of_mask !fd_mask i)
           ~set:
             { f_txstall = set.f_txstall || hs.f_txstall
             ; f_txover = set.f_txover || hs.f_txover
             ; f_rxunder = set.f_rxunder || hs.f_rxunder
             ; f_rxstall = set.f_rxstall || hs.f_rxstall
             ; f_illegal = set.f_illegal || hs.f_illegal
             }))
    t.sms;
  t.cycle <- t.cycle + 1;
  { pads = pad; rx_data = List.rev !rx_data }
;;

(* One system clock cycle with no host operations. Returns the pad levels seen at the start
   of this cycle. *)
let step ?host t = (step_ex ?host t).pads

(* Pads at the start of the cycle, before the next step: (level, output enable). Both are
   32-bit masks. The level is the PIO output level where the pin is driven, and the external
   level elsewhere. *)
let pads t = pad_now t, t.pin_dir

(* Block-level register values (RP2040 layouts, datasheet 3.7). *)
let pins_out t = t.pin_level
let pins_oe t = t.pin_dir

(* Head of the RX FIFO of SM [i], 0 if it is empty: the combinational rxf_data (H2). *)
let rx_head t i =
  match (host_sm t i).rx.Fifo.items with
  | [] -> 0
  | w :: _ -> w
;;

let fstat t =
  let v = ref 0 in
  Array.iteri
    (fun i sm ->
      if Fifo.empty sm.tx then v := !v lor (1 lsl (24 + i));
      if Fifo.full sm.tx then v := !v lor (1 lsl (16 + i));
      if Fifo.empty sm.rx then v := !v lor (1 lsl (8 + i));
      if Fifo.full sm.rx then v := !v lor (1 lsl i))
    t.sms;
  !v
;;

let flevel t =
  let v = ref 0 in
  Array.iteri
    (fun i sm ->
      v := !v lor ((Fifo.level sm.tx land 15) lsl (8 * i));
      v := !v lor ((Fifo.level sm.rx land 15) lsl ((8 * i) + 4)))
    t.sms;
  !v
;;

(* FDEBUG, with the Polyglot ILLEGAL flag at [31:28]. *)
let fdebug t =
  let v = ref 0 in
  Array.iteri
    (fun i sm ->
      if sm.txstall then v := !v lor (1 lsl (24 + i));
      if sm.txover then v := !v lor (1 lsl (16 + i));
      if sm.rxunder then v := !v lor (1 lsl (8 + i));
      if sm.rxstall then v := !v lor (1 lsl i);
      if sm.illegal then v := !v lor (1 lsl (28 + i)))
    t.sms;
  !v
;;

(* ------------------------------------------------------------------------------------ *)
(* Immediate host operations, between cycles. Each is the effect of the matching
   [Host_op.t] in a cycle with no SM activity. *)

let write_tx t i w =
  let sm = host_sm t i in
  if Fifo.full sm.tx then sm.txover <- true else Fifo.push sm.tx (w land m32)
;;

let read_rx t i =
  let sm = host_sm t i in
  match Fifo.pop sm.rx with
  | Some w -> Some w
  | None ->
    sm.rxunder <- true;
    None
;;

let write_instr t i w = latch_instr (host_sm t i) w
let set_enabled t i b = (host_sm t i).enabled <- b
let sm_restart t mask = restart_sms t mask

let clkdiv_restart t mask =
  Array.iteri (fun i sm -> if bit mask i = 1 then sm.acc <- 0) t.sms
;;

(* Host write-1-to-clear on the IRQ register (datasheet 3.7, IRQ). *)
let clear_irq t mask = t.irq <- t.irq land lnot mask land 0xFF

(* IRQ_FORCE (datasheet 3.7). *)
let force_irq t mask = t.irq <- (t.irq lor mask) land 0xFF

let clear_fdebug t mask =
  Array.iteri
    (fun i sm ->
      fdbg_store
        sm
        (fdbg_merge ~pre:(fdbg_of_sm sm) ~clear:(fdbg_clear_of_mask mask i) ~set:fdbg_none))
    t.sms
;;

let flush_fifos t mask =
  Array.iteri
    (fun i sm ->
      if bit mask i = 1
      then (
        Fifo.flush sm.tx;
        Fifo.flush sm.rx))
    t.sms
;;

let write_imem t addr data = t.imem.(addr land 63) <- data land 0xFFFF

(* SMn_EXT.PAGE (bit 0 of EXT) for SM [i]. A level: it applies to the fetch of the next step
   (engine.md 9). *)
let set_page t i v = (host_sm t i).page <- v land 1

(* ------------------------------------------------------------------------------------ *)
(* Debug view, for the block 2 lockstep harness. *)

(* Sticky OUT_STICKY state of an SM: (level mask, level value, dir mask, dir value). *)
type sticky_view = int * int * int * int

type debug =
  { pc : int
  ; x : int
  ; y : int
  ; isr : int
  ; isr_count : int
  ; osr : int
  ; osr_count : int
  ; tx_fifo : int list (* head first *)
  ; rx_fifo : int list
  ; tx_level : int
  ; rx_level : int
  ; delay : int (* remaining delay ticks *)
  ; acc : int (* clock divider phase P, 1/256 units (R10) *)
  ; stall : stall
  ; stall_code : int (* DBG_CNT.stall_reason code, see [stall_code] *)
  ; enabled : bool
  ; illegal : bool
  ; latch : latch (* pending EXEC or host instruction *)
  ; irq_wait : int option (* IMEM IRQ instruction waiting on a flag *)
  ; latch_irq_wait : int option (* latched EXEC or host IRQ instruction waiting on a flag *)
  ; latch_stall : stall (* stall of the latched instruction; [stall] reports it when set *)
  ; exec_stalled : bool (* a host instruction is latched and its latest attempt stalled (F4) *)
  ; side_done : bool
  ; host_side_done : bool
  ; sticky : sticky_view
  ; txstall : bool
  ; txover : bool
  ; rxunder : bool
  ; rxstall : bool
  ; instr : int (* IMEM word at the fetch address (dbg_instr, engine.md 3) *)
  }

(* DBG_CNT.stall_reason, as DESIGN.md 7 now defines it: one code per stall reason, 0 for none. *)
let stall_code = function
  | No_stall -> 0
  | Stall_tx_empty -> 1
  | Stall_rx_full -> 2
  | Stall_autopull -> 3
  | Stall_wait_gpio -> 4
  | Stall_wait_pin -> 5
  | Stall_wait_irq -> 6
  | Stall_irq_wait -> 7
;;

let stall_name = function
  | No_stall -> "none"
  | Stall_tx_empty -> "tx_empty"
  | Stall_rx_full -> "rx_full"
  | Stall_autopull -> "autopull"
  | Stall_wait_gpio -> "wait_gpio"
  | Stall_wait_pin -> "wait_pin"
  | Stall_wait_irq -> "wait_irq"
  | Stall_irq_wait -> "irq_wait"
;;

let debug t i =
  let sm = host_sm t i in
  (* A stalled latched instruction is the current one; otherwise the IMEM reason applies.
     Completing a latched instruction never changes the IMEM reason (see README). *)
  let effective = if sm.latch_stall <> No_stall then sm.latch_stall else sm.stall in
  { pc = sm.pc
  ; x = sm.x
  ; y = sm.y
  ; isr = sm.isr
  ; isr_count = sm.isr_count
  ; osr = sm.osr
  ; osr_count = sm.osr_count
  ; tx_fifo = sm.tx.Fifo.items
  ; rx_fifo = sm.rx.Fifo.items
  ; tx_level = Fifo.level sm.tx
  ; rx_level = Fifo.level sm.rx
  ; delay = sm.delay
  ; acc = sm.acc
  ; stall = effective
  ; stall_code = stall_code effective
  ; latch_stall = sm.latch_stall
  ; enabled = sm.enabled
  ; illegal = sm.illegal
  ; latch = sm.latch
  ; irq_wait = sm.irq_wait
  ; latch_irq_wait = sm.latch_irq_wait
  ; exec_stalled =
      (match sm.latch with
       | Host_latch _ -> sm.latch_stall <> No_stall
       | No_latch | Exec_latch _ -> false)
  ; side_done = sm.side_done
  ; host_side_done = sm.host_side_done
  ; sticky = pinw_to_tuple sm.sticky
  ; txstall = sm.txstall
  ; txover = sm.txover
  ; rxunder = sm.rxunder
  ; rxstall = sm.rxstall
  ; instr = t.imem.(fetch_addr sm)
  }
;;

(* DBG_CNT (DESIGN.md 7): ISR count [5:0], OSR count [13:8], delay [20:16], stall reason
   [27:24]. All other bits 0. *)
let dbg_cnt t i =
  let d = debug t i in
  (d.isr_count land 63)
  lor ((d.osr_count land 63) lsl 8)
  lor ((d.delay land 31) lsl 16)
  lor (d.stall_code lsl 24)
;;
