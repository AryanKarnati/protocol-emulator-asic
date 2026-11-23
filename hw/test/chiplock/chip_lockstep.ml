(* The top-level lockstep (docs/chip.md 11): the RTL chip (Cyclesim of Polyglot_hw.Chip) and the
   whole-chip model (Chip), fed the same pins, compared every cycle. The model's [observe] and
   [bus_ports] and the RTL's port reads use the same names, so a difference is named by port.

   Reset: a case's rst cycle calls [Chip.reset] and Cyclesim.reset on the RTL, and nothing is
   compared in it (chip.md 10). IMEM is kept on both sides.

   uio_in: the RTL gets the pad rule of chip.md 9.2 applied to its own uio_out and uio_oe in the
   same cycle, with the case's external levels. The model applies the same rule internally, so a
   difference in the pads shows up in the compared ports. *)

module Sim = Hardcaml.Cyclesim

let bits w v = Hardcaml.Bits.of_int ~width:w v
let to_int b = Hardcaml.Bits.to_int b
let out sim name = to_int !(Sim.out_port ~clock_edge:Hardcaml.Side.Before sim name)
let set sim name w v = Sim.in_port sim name := bits w v

let bus_names = [ "dbg_bus_write"; "dbg_bus_read"; "dbg_bus_commit"; "dbg_bus_addr"; "dbg_bus_wdata"; "dbg_bus_rdata" ]

let rtl_create ~num_sms =
  let sim = Sim.create (Polyglot_hw.Chip.circuit ~num_sms ~imem_depth:64 ~sram:false) in
  Sim.reset sim;
  Sim.cycle_check sim;
  sim
;;

let rtl_reset sim =
  Sim.reset sim;
  Sim.cycle_check sim
;;

(* Drive one cycle's pins and settle the outputs. uio_in follows the pad rule on the RTL's own
   uio_out and uio_oe (chip.md 9.2). *)
let rtl_drive sim ~ui ~uio =
  set sim "rst_n" 1 1;
  set sim "ui_in" 8 ui;
  set sim "uio_in" 8 0;
  Sim.cycle_before_clock_edge sim;
  let oe = out sim "uio_oe" and uo = out sim "uio_out" in
  set sim "uio_in" 8 (((oe land uo) lor (uio land lnot oe)) land 0xFF);
  Sim.cycle_before_clock_edge sim
;;

let rtl_clock sim =
  Sim.cycle_at_clock_edge sim;
  Sim.cycle_after_clock_edge sim;
  Sim.cycle_check sim
;;

(* The RTL's values of the bus ports, masked the same way as {!Chip.bus_ports}. *)
let mask_bus (v : (string * int) list) : (string * int) list =
  let g n = List.assoc n v in
  let w = g "dbg_bus_write" = 1 and r = g "dbg_bus_read" = 1 and c = g "dbg_bus_commit" = 1 in
  [ "dbg_bus_write", g "dbg_bus_write"
  ; "dbg_bus_read", g "dbg_bus_read"
  ; "dbg_bus_commit", g "dbg_bus_commit"
  ; "dbg_bus_addr", (if w || r || c then g "dbg_bus_addr" else 0)
  ; "dbg_bus_wdata", (if w then g "dbg_bus_wdata" else 0)
  ; "dbg_bus_rdata", (if r then g "dbg_bus_rdata" else 0)
  ]
;;

type failure =
  { cycle : int
  ; port : string
  ; model : int
  ; rtl : int
  }

type outcome =
  | Pass of { cycles : int }
  | Fail of failure

(* The model side: the whole-chip model, or a faulty copy of it (chip mutants). *)
module type MODEL = sig
  type t
  type outputs

  val create : ?num_sms:int -> unit -> t
  val reset : t -> unit
  val observe : t -> (string * int) list
  val step : t -> ui_in:int -> uio_ext:int -> outputs
  val bus_ports : outputs -> (string * int) list
end

let chip_model : (module MODEL) = (module Chip)

let describe (f : failure) =
  Printf.sprintf "MISMATCH at cycle %d, port %s: model (pgsim chip) = 0x%x, rtl = 0x%x" f.cycle f.port
    f.model f.rtl
;;

(* Run one case; stop at the first difference. *)
let run ?(model = chip_model) (c : Chip_case.t) : outcome =
  let module M = (val model : MODEL) in
  let c = Chip_case.normalise c in
  let num_sms = c.Chip_case.num_sms in
  let m = M.create ~num_sms () in
  let sim = rtl_create ~num_sms in
  let n = Array.length c.Chip_case.cycles in
  let result = ref None in
  let k = ref 0 in
  while Option.is_none !result && !k < n do
    let y = c.Chip_case.cycles.(!k) in
    if y.Chip_case.rst
    then (
      M.reset m;
      rtl_reset sim)
    else (
      let mobs = M.observe m in
      rtl_drive sim ~ui:y.Chip_case.ui ~uio:y.Chip_case.uio;
      let robs =
        List.map (fun (name, _) -> name, out sim name) mobs
      in
      let rbus = mask_bus (List.map (fun n -> n, out sim n) bus_names) in
      let mismatch = List.find_opt (fun (name, v) -> List.assoc name robs <> v) mobs in
      (match mismatch with
       | Some (name, v) ->
         result := Some (Fail { cycle = !k; port = name; model = v; rtl = List.assoc name robs })
       | None ->
         let out_m = M.step m ~ui_in:y.Chip_case.ui ~uio_ext:y.Chip_case.uio in
         let mbus = M.bus_ports out_m in
         (match List.find_opt (fun (name, v) -> List.assoc name rbus <> v) mbus with
          | Some (name, v) ->
            result := Some (Fail { cycle = !k; port = name; model = v; rtl = List.assoc name rbus })
          | None -> rtl_clock sim)));
    incr k
  done;
  match !result with
  | Some o -> o
  | None -> Pass { cycles = n }
;;

(* Shrink a failing case: cut it after the failing cycle, then delete chunks of cycles while the
   case still fails. Deleting cycles changes the pin sequence, but every sequence has a defined
   result, so a smaller case is a valid case. *)
let shrink ?model ?(limit = 400) (c : Chip_case.t) (f : failure) : Chip_case.t * failure * int =
  let c = { c with Chip_case.cycles = Array.sub c.Chip_case.cycles 0 (f.cycle + 1) } in
  let steps = ref 0 in
  let best = ref c and best_f = ref f in
  let chunk = ref (Array.length !best.Chip_case.cycles / 2) in
  while !chunk >= 1 && !steps < limit do
    let i = ref 0 in
    while !i < Array.length !best.Chip_case.cycles && !steps < limit do
      let cur = !best.Chip_case.cycles in
      let len = Array.length cur in
      let hi = min len (!i + !chunk) in
      if hi - !i > 0 && len - (hi - !i) > 0
      then (
        incr steps;
        let cand =
          { !best with
            Chip_case.cycles = Array.append (Array.sub cur 0 !i) (Array.sub cur hi (len - hi))
          }
        in
        match run ?model cand with
        | Fail g ->
          best := cand;
          best_f := g
        | Pass _ -> i := !i + !chunk)
      else i := !i + !chunk
    done;
    chunk := !chunk / 2
  done;
  !best, !best_f, !steps
;;
