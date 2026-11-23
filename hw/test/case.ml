(* A lockstep case: an IMEM image, the initial configuration, and a sparse stimulus.

   A case is self-contained. [to_json] writes everything a DUT needs to replay it, so the
   RTL lane can run a case file without this library's generator.

   Timeline. The load phase is 32 cycles with rst_n high, during which the IMEM image is
   written one word per cycle, the configuration is presented, SM_ENABLE is 0 and the pads
   are 0. Run cycle 0 is the first cycle after the load phase. Event cycles are run cycles.

   Level events (external pads, enables, configuration, sync bypass) hold from their cycle
   on. Pulse events apply in their cycle only. Config events are only valid in a cycle in
   which the SM is disabled, and FJOIN never changes after the load phase (the register
   block would flush the FIFOs with it, and that is not part of this harness). [normalise]
   makes any case valid, so generators and shrinkers can build cases without checking. *)

type sm_cfg =
  { clkdiv : int
  ; execctrl : int
  ; shiftctrl : int
  ; pinctrl : int
  }

type event =
  | Ext_pins of int
  | Pin_set of int * int (** one pad: pin, level (0 or 1), from this cycle on *)
  | Sm_enable of int
  | Sm_config of int * sm_cfg
  | Sync_bypass of int
  | Tx_push of int * int
  | Rx_pop of int
  | Instr_write of int * int
  | Sm_restart of int
  | Clkdiv_restart of int
  | Fifo_flush of int
  | Irq_clear of int
  | Irq_force of int
  | Fdebug_clear of int
  | Imem_write of int * int
  | Sm_ext of int * int (** SM, level: SMn_EXT, bit 0 is PAGE, from this cycle on *)
  | Rxf_sel of int (** the RX FIFO whose head rxf_data shows, from this cycle on *)
  | Fdebug_set of int (** FDEBUG flags to set, layout as [Fdebug_clear] *)
  | Reset_low (** rst_n low for this cycle and the next (engine.md 5: at least 2 cycles) *)

type t =
  { num_sms : int
  ; imem : int array (* 64 words, pages 0 and 1; words past the program are 0, which is JMP 0 *)
  ; initial : sm_cfg array (* 4 entries; entries past num_sms are ignored *)
  ; initial_sync : int
  ; cycles : int (* run cycles, after the 32-cycle load phase *)
  ; events : (int * event) list (* (run cycle, event), in any order *)
  }

let imem_words = 64
let load_cycles = imem_words
let m32 = 0xFFFF_FFFF
let fjoin_mask = 0xC000_0000
let fdebug_layout = 0xFF0F_0F0F (* bits 31:28, 27:24, 19:16, 11:8, 3:0; see engine.md 3 *)

let default_cfg =
  let c = Pgsim.Config.reset in
  { clkdiv = Pgsim.Config.clkdiv_register c
  ; execctrl = Pgsim.Config.execctrl_register c
  ; shiftctrl = Pgsim.Config.shiftctrl_register c
  ; pinctrl = Pgsim.Config.pinctrl_register c
  }
;;

(* Make one configuration valid (engine.md 3, "Setting both FJOIN bits ...", INT = 0 rules).
   [fjoin] is the FJOIN field the SM already has, which a config event keeps. *)
let norm_cfg ?fjoin c =
  let clkdiv =
    let int = (c.clkdiv lsr 16) land 0xFFFF in
    if int = 0 then c.clkdiv land 0xFFFF_0000 else c.clkdiv land m32
  in
  let execctrl = c.execctrl land lnot ((0x3F lsl 18) lor (1 lsl 31)) land m32 in
  let side_en = (execctrl lsr 30) land 1 = 1 in
  let sc = min 5 ((c.pinctrl lsr 29) land 7) in
  let sc = if side_en then max 1 sc else sc in
  let pinctrl = (c.pinctrl land 0x1FFF_FFFF) lor (sc lsl 29) in
  let shiftctrl =
    let s = c.shiftctrl land m32 in
    match fjoin with
    | Some f -> (s land lnot fjoin_mask) lor (f land fjoin_mask)
    | None -> if s land fjoin_mask = fjoin_mask then s land lnot (1 lsl 30) else s
  in
  { clkdiv; execctrl; shiftctrl; pinctrl }
;;

let fjoin_of c = c.shiftctrl land fjoin_mask

(* Make a case valid. Total: any case is mapped to a valid case with the same intent. *)
let normalise (c : t) : t =
  let num_sms = max 1 (min 4 c.num_sms) in
  let cycles = max 1 (min 20_000 c.cycles) in
  let imem =
    Array.init imem_words (fun i -> if i < Array.length c.imem then c.imem.(i) land 0xFFFF else 0)
  in
  let initial =
    Array.init 4 (fun i ->
      let s = if i < Array.length c.initial then c.initial.(i) else default_cfg in
      norm_cfg s)
  in
  let fjoin = Array.map fjoin_of initial in
  let enable = ref 0 in
  let cur_fjoin = Array.copy fjoin in
  let cur_cfg = Array.copy initial in
  let events =
    c.events
    |> List.filter (fun (cy, _) -> cy >= 0 && cy < cycles)
    |> List.stable_sort (fun (a, _) (b, _) -> compare a b)
  in
  (* One pulse of each kind per cycle, as the port list allows. *)
  let used = Hashtbl.create 16 in
  let once cy kind = if Hashtbl.mem used (cy, kind) then false else (Hashtbl.add used (cy, kind) (); true) in
  let events =
    List.filter_map
      (fun (cy, ev) ->
        match ev with
        | Ext_pins v -> Some (cy, Ext_pins (v land m32))
        | Pin_set (p, l) -> Some (cy, Pin_set (p land 31, l land 1))
        | Sm_enable v ->
          enable := v land 0xF;
          Some (cy, Sm_enable (v land 0xF))
        | Sm_config (sm, cfg) ->
          let sm = sm land 3 in
          if (!enable lsr sm) land 1 = 1
          then None
          else (
            let n = norm_cfg ~fjoin:cur_fjoin.(sm) cfg in
            cur_cfg.(sm) <- n;
            Some (cy, Sm_config (sm, n)))
        | Sync_bypass v -> Some (cy, Sync_bypass (v land m32))
        | Tx_push (sm, d) -> if once cy `Tx then Some (cy, Tx_push (sm land 3, d land m32)) else None
        | Rx_pop sm -> if once cy `Rx then Some (cy, Rx_pop (sm land 3)) else None
        | Instr_write (sm, d) ->
          if once cy `Instr then Some (cy, Instr_write (sm land 3, d land 0xFFFF)) else None
        | Sm_restart m -> Some (cy, Sm_restart (m land 0xF))
        | Clkdiv_restart m -> Some (cy, Clkdiv_restart (m land 0xF))
        | Fifo_flush m -> Some (cy, Fifo_flush (m land 0xF))
        | Irq_clear m -> Some (cy, Irq_clear (m land 0xFF))
        | Irq_force m -> Some (cy, Irq_force (m land 0xFF))
        | Fdebug_clear m -> Some (cy, Fdebug_clear (m land fdebug_layout))
        | Imem_write (a, d) ->
          if once cy `Imem then Some (cy, Imem_write (a land 63, d land 0xFFFF)) else None
        | Sm_ext (sm, v) -> Some (cy, Sm_ext (sm land 3, v land 1))
        | Rxf_sel sm -> Some (cy, Rxf_sel (sm land 3))
        | Fdebug_set m -> Some (cy, Fdebug_set (m land fdebug_layout))
        | Reset_low -> Some (cy, Reset_low))
      events
  in
  ignore cur_cfg;
  { num_sms
  ; imem
  ; initial
  ; initial_sync = c.initial_sync land m32
  ; cycles
  ; events
  }
;;

(* ------------------------------------------------------------------------------------ *)
(* Dense per-cycle inputs. Index n covers the load phase (n < 32) and then the run cycles
   (index 32 + c for run cycle c). *)

let dense (c : t) : Ports.inputs array =
  let n_total = load_cycles + c.cycles in
  let by_cycle = Array.make c.cycles [] in
  List.iter (fun (cy, ev) -> by_cycle.(cy) <- ev :: by_cycle.(cy)) c.events;
  Array.iteri (fun i l -> by_cycle.(i) <- List.rev l) by_cycle;
  let rst = Array.make (max 1 c.cycles) false in
  List.iter
    (fun (cy, ev) ->
      if ev = Reset_low
      then (
        rst.(cy) <- true;
        if cy + 1 < c.cycles then rst.(cy + 1) <- true))
    c.events;
  let sm_enable = ref 0 in
  let clkdiv = Array.map (fun s -> s.clkdiv) c.initial in
  let execctrl = Array.map (fun s -> s.execctrl) c.initial in
  let shiftctrl = Array.map (fun s -> s.shiftctrl) c.initial in
  let pinctrl = Array.map (fun s -> s.pinctrl) c.initial in
  let sync = ref c.initial_sync in
  let ext = ref 0 in
  let sm_ext = Array.make 4 0 in
  let rxf_sel = ref 0 in
  Array.init n_total (fun n ->
    let idle = Ports.idle ~rst_n:true in
    let idle = if n >= load_cycles && rst.(n - load_cycles) then { idle with Ports.rst_n = false } else idle in
    if n < load_cycles
    then
      { idle with
        Ports.clkdiv = Array.copy clkdiv
      ; execctrl = Array.copy execctrl
      ; shiftctrl = Array.copy shiftctrl
      ; pinctrl = Array.copy pinctrl
      ; sync_bypass = !sync
      ; pins_ext = !ext
      ; imem_write = Some (n, c.imem.(n))
      ; sm_ext = Array.copy sm_ext
      ; rxf_sm = !rxf_sel
      }
    else (
      let cy = n - load_cycles in
      let pulses = ref idle in
      List.iter
        (fun ev ->
          match ev with
          | Ext_pins v -> ext := v
          | Pin_set (p, l) -> ext := (!ext land lnot (1 lsl p)) lor (l lsl p)
          | Sm_enable v -> sm_enable := v
          | Sm_config (sm, cfg) ->
            clkdiv.(sm) <- cfg.clkdiv;
            execctrl.(sm) <- cfg.execctrl;
            shiftctrl.(sm) <- cfg.shiftctrl;
            pinctrl.(sm) <- cfg.pinctrl
          | Sync_bypass v -> sync := v
          | Tx_push (sm, d) -> pulses := { !pulses with Ports.txf_push = Some (sm, d) }
          | Rx_pop sm ->
            rxf_sel := sm;
            pulses := { !pulses with Ports.rxf_pop = Some sm }
          | Sm_ext (sm, v) -> sm_ext.(sm) <- v
          | Rxf_sel sm -> rxf_sel := sm
          | Fdebug_set m -> pulses := { !pulses with Ports.fdebug_set = m }
          | Instr_write (sm, d) -> pulses := { !pulses with Ports.instr_write = Some (sm, d) }
          | Sm_restart m -> pulses := { !pulses with Ports.sm_restart = m }
          | Clkdiv_restart m -> pulses := { !pulses with Ports.clkdiv_restart = m }
          | Fifo_flush m -> pulses := { !pulses with Ports.fifo_flush = m }
          | Irq_clear m -> pulses := { !pulses with Ports.irq_clear = m }
          | Irq_force m -> pulses := { !pulses with Ports.irq_force = m }
          | Fdebug_clear m -> pulses := { !pulses with Ports.fdebug_clear = m }
          | Imem_write (a, d) -> pulses := { !pulses with Ports.imem_write = Some (a, d) }
          | Reset_low -> ())
        by_cycle.(cy);
      { !pulses with
        Ports.sm_enable = !sm_enable
      ; clkdiv = Array.copy clkdiv
      ; execctrl = Array.copy execctrl
      ; shiftctrl = Array.copy shiftctrl
      ; pinctrl = Array.copy pinctrl
      ; sync_bypass = !sync
      ; pins_ext = !ext
      ; sm_ext = Array.copy sm_ext
      ; rxf_sm = (match !pulses.Ports.rxf_pop with Some s -> s | None -> !rxf_sel)
      }))
;;

(* ------------------------------------------------------------------------------------ *)
(* JSON. The format is documented by [to_json]; [of_json] reads it back. *)

let format_name = "polyglot-lockstep-case"

let event_to_json cy ev : Yojson.Safe.t =
  let base op fields = `Assoc (("cycle", `Int cy) :: ("op", `String op) :: fields) in
  let i k v = k, `Int v in
  match ev with
  | Ext_pins v -> base "ext_pins" [ i "pins" v ]
  | Pin_set (p, l) -> base "pin_set" [ i "pin" p; i "level" l ]
  | Sm_enable v -> base "sm_enable" [ i "mask" v ]
  | Sm_config (sm, c) ->
    base
      "sm_config"
      [ i "sm" sm
      ; i "clkdiv" c.clkdiv
      ; i "execctrl" c.execctrl
      ; i "shiftctrl" c.shiftctrl
      ; i "pinctrl" c.pinctrl
      ]
  | Sync_bypass v -> base "sync_bypass" [ i "value" v ]
  | Tx_push (sm, d) -> base "tx_push" [ i "sm" sm; i "data" d ]
  | Rx_pop sm -> base "rx_pop" [ i "sm" sm ]
  | Instr_write (sm, d) -> base "instr_write" [ i "sm" sm; i "data" d ]
  | Sm_restart m -> base "sm_restart" [ i "mask" m ]
  | Clkdiv_restart m -> base "clkdiv_restart" [ i "mask" m ]
  | Fifo_flush m -> base "fifo_flush" [ i "mask" m ]
  | Irq_clear m -> base "irq_clear" [ i "mask" m ]
  | Irq_force m -> base "irq_force" [ i "mask" m ]
  | Fdebug_clear m -> base "fdebug_clear" [ i "mask" m ]
  | Imem_write (a, d) -> base "imem_write" [ i "addr" a; i "data" d ]
  | Sm_ext (sm, v) -> base "sm_ext" [ i "sm" sm; i "value" v ]
  | Rxf_sel sm -> base "rxf_sel" [ i "sm" sm ]
  | Fdebug_set m -> base "fdebug_set" [ i "mask" m ]
  | Reset_low -> base "reset_low" []
;;

let cfg_to_json c : Yojson.Safe.t =
  `Assoc
    [ "clkdiv", `Int c.clkdiv
    ; "execctrl", `Int c.execctrl
    ; "shiftctrl", `Int c.shiftctrl
    ; "pinctrl", `Int c.pinctrl
    ]
;;

let to_json (c : t) : Yojson.Safe.t =
  `Assoc
    [ "format", `String format_name
    ; "version", `Int 2
    ; "num_sms", `Int c.num_sms
    ; "load_cycles", `Int load_cycles
    ; "cycles", `Int c.cycles
    ; "imem", `List (Array.to_list (Array.map (fun w -> `Int w) c.imem))
    ; "initial", `List (Array.to_list (Array.map cfg_to_json c.initial))
    ; "initial_sync_bypass", `Int c.initial_sync
    ; "events", `List (List.map (fun (cy, ev) -> event_to_json cy ev) c.events)
    ]
;;

let to_text c = Yojson.Safe.pretty_to_string (to_json c)

let of_json (j : Yojson.Safe.t) : t =
  let open Yojson.Safe.Util in
  let int k o = to_int (member k o) in
  let cfg o =
    { clkdiv = int "clkdiv" o; execctrl = int "execctrl" o; shiftctrl = int "shiftctrl" o; pinctrl = int "pinctrl" o }
  in
  if member "format" j <> `String format_name then failwith "not a lockstep case file";
  let event o =
    let cy = int "cycle" o in
    let ev =
      match to_string (member "op" o) with
      | "ext_pins" -> Ext_pins (int "pins" o)
      | "pin_set" -> Pin_set (int "pin" o, int "level" o)
      | "sm_enable" -> Sm_enable (int "mask" o)
      | "sm_config" -> Sm_config (int "sm" o, cfg o)
      | "sync_bypass" -> Sync_bypass (int "value" o)
      | "tx_push" -> Tx_push (int "sm" o, int "data" o)
      | "rx_pop" -> Rx_pop (int "sm" o)
      | "instr_write" -> Instr_write (int "sm" o, int "data" o)
      | "sm_restart" -> Sm_restart (int "mask" o)
      | "clkdiv_restart" -> Clkdiv_restart (int "mask" o)
      | "fifo_flush" -> Fifo_flush (int "mask" o)
      | "irq_clear" -> Irq_clear (int "mask" o)
      | "irq_force" -> Irq_force (int "mask" o)
      | "fdebug_clear" -> Fdebug_clear (int "mask" o)
      | "imem_write" -> Imem_write (int "addr" o, int "data" o)
      | "sm_ext" -> Sm_ext (int "sm" o, int "value" o)
      | "rxf_sel" -> Rxf_sel (int "sm" o)
      | "fdebug_set" -> Fdebug_set (int "mask" o)
      | "reset_low" -> Reset_low
      | op -> failwith ("unknown event op " ^ op)
    in
    cy, ev
  in
  (* Version 1 files have 32 words; the rest of IMEM is zero. *)
  let imem = to_list (member "imem" j) |> List.map to_int |> Array.of_list in
  if Array.length imem <> 32 && Array.length imem <> imem_words
  then failwith "imem must have 32 or 64 words";
  let imem = Array.init imem_words (fun i -> if i < Array.length imem then imem.(i) else 0) in
  let initial = to_list (member "initial" j) |> List.map cfg |> Array.of_list in
  if Array.length initial <> 4 then failwith "initial must have 4 entries";
  { num_sms = int "num_sms" j
  ; imem
  ; initial
  ; initial_sync = int "initial_sync_bypass" j
  ; cycles = int "cycles" j
  ; events = to_list (member "events" j) |> List.map event
  }
;;

let of_text s = of_json (Yojson.Safe.from_string s)
let read_file path = of_json (Yojson.Safe.from_file path)

let write_file path c =
  let oc = open_out path in
  output_string oc (to_text c);
  output_char oc '\n';
  close_out oc
;;

let kind_name = function
  | Ext_pins _ -> "ext_pins"
  | Pin_set _ -> "pin_set"
  | Sm_enable _ -> "sm_enable"
  | Sm_config _ -> "sm_config"
  | Sync_bypass _ -> "sync_bypass"
  | Tx_push _ -> "tx_push"
  | Rx_pop _ -> "rx_pop"
  | Instr_write _ -> "instr_write"
  | Sm_restart _ -> "sm_restart"
  | Clkdiv_restart _ -> "clkdiv_restart"
  | Fifo_flush _ -> "fifo_flush"
  | Irq_clear _ -> "irq_clear"
  | Irq_force _ -> "irq_force"
  | Fdebug_clear _ -> "fdebug_clear"
  | Imem_write _ -> "imem_write"
  | Sm_ext _ -> "sm_ext"
  | Rxf_sel _ -> "rxf_sel"
  | Fdebug_set _ -> "fdebug_set"
  | Reset_low -> "reset_low"
;;
