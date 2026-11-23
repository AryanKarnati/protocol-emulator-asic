(* Biasing and coverage of the pio_block generator (docs/engine.md F7, F8, 8.3; chip.md 8.3).

   A generated case is run once on the reference (pgsim) to observe, cycle by cycle, which SMs
   are stalled, where each SM fetches, which RX FIFOs hold a word, and what the registers show.
   [retarget] then steers the random events toward live states: an IMEM write at the fetch
   address of a stalled instruction (F7), and an RX select of a non-empty FIFO. [coverage] counts
   the scenarios a case reaches, using the same observation. *)

type step =
  { inp : Ports.inputs
  ; regs : Ports.outputs
  ; probe : Dut.probe
  }

(* The reference run of a case: one [step] per cycle of [Case.dense], the load phase included. *)
let observe (c : Case.t) : step array =
  let d =
    Dut.pgsim (module Pgsim : Dut.PGSIM) ~name:"observe" ~pads_from_pins_in:false
      ~num_sms:c.Case.num_sms
  in
  Array.map
    (fun inp ->
      let regs = d.Dut.regs inp in
      let probe = d.Dut.probe inp in
      ignore (d.Dut.cycle inp);
      { inp; regs; probe })
    (Case.dense c)
;;

let run_steps (obs : step array) = Array.sub obs Case.load_cycles (Array.length obs - Case.load_cycles)

(* The run-cycle index [cy] and SM [sm] pairs where SM [sm] is stalled, with its fetch address. *)
let stalled_fetches (c : Case.t) (run : step array) =
  let acc = ref [] in
  Array.iteri
    (fun cy s ->
      for sm = 0 to c.Case.num_sms - 1 do
        if s.probe.Dut.stalled.(sm) then acc := (cy, s.probe.Dut.fetch.(sm)) :: !acc
      done)
    run;
  Array.of_list (List.rev !acc)
;;

let nonempty_sms (c : Case.t) (s : step) =
  List.filter (fun sm -> s.probe.Dut.rx_nonempty.(sm)) (List.init c.Case.num_sms Fun.id)
;;

(* Steer the events of [c] toward live states, using the observation of [c] itself. The result is
   normalised. Deterministic for a given [rng]. *)
let retarget ~(rng : Random.State.t) (c : Case.t) : Case.t =
  let obs = observe c in
  let run = run_steps obs in
  let n_run = Array.length run in
  let pick arr = arr.(Random.State.int rng (Array.length arr)) in
  (* 1. RX selects: move a select of an empty FIFO to a non-empty one, and add selects of
        non-empty FIFOs at random cycles. *)
  let select_events =
    List.map
      (fun (cy, ev) ->
        match ev with
        | Case.Rxf_sel sm when cy < n_run ->
          (match nonempty_sms c run.(cy) with
           | [] -> cy, ev
           | ne when not (List.mem sm ne) && Random.State.int rng 10 < 8 ->
             cy, Case.Rxf_sel (List.nth ne (Random.State.int rng (List.length ne)))
           | _ -> cy, ev)
        | _ -> cy, ev)
      c.Case.events
  in
  let busy = Array.of_list (List.filter (fun cy -> nonempty_sms c run.(cy) <> []) (List.init n_run Fun.id)) in
  let extra_selects =
    if Array.length busy = 0
    then []
    else
      List.init 6 (fun _ ->
        let cy = pick busy in
        let ne = nonempty_sms c run.(cy) in
        cy, Case.Rxf_sel (List.nth ne (Random.State.int rng (List.length ne))))
  in
  (* 2. IMEM writes at the live fetch address of stalled instructions (F7). *)
  let stalled = stalled_fetches c run in
  let has_imem_write cy =
    List.exists (fun (k, ev) -> k = cy && match ev with Case.Imem_write _ -> true | _ -> false) c.Case.events
  in
  let writes =
    if Array.length stalled = 0
    then []
    else
      List.filter_map
        (fun _ ->
          let cy, fetch = pick stalled in
          if has_imem_write cy
          then None
          else Some (cy, Case.Imem_write (fetch, Random.State.int rng 0x10000)))
        (List.init 8 Fun.id)
  in
  (* 3. RX fills with data: a forced IN PINS,32 then a forced PUSH block, so the ISR holds the pin
        levels of the cycle and RX FIFO 0..3 gets a non-zero word (engine.md 6, R6, F1). *)
  let fills =
    List.concat
      (List.init 6 (fun _ ->
         let sm = Random.State.int rng c.Case.num_sms in
         let cy = Random.State.int rng (max 1 (n_run - 1)) in
         [ cy, Case.Instr_write (sm, 0x4000)
         ; cy + 1, Case.Instr_write (sm, 0x8020) ]))
  in
  let events = select_events @ extra_selects @ writes @ fills in
  (* One IMEM write per cycle, and one select per cycle (normalise keeps the first of each). *)
  Case.normalise { c with Case.events }
;;

(* ------------------------------------------------------------------------------------------ *)
(* Coverage: the scenarios a case reaches. Each is a boolean per case. *)

let scenario_names =
  [ "rxf_data nonzero for a present rxf_sm"
  ; "rxf_sm selects a non-empty RX FIFO"
  ; "RX pop of a non-empty FIFO"
  ; "RX pop of an empty FIFO (RXUNDER)"
  ; "IMEM write at a live fetch address"
  ; "IMEM write at a live fetch address of a stalled instruction"
  ; "IMEM write to page 1"
  ; "PAGE change (F8)"
  ; "PAGE change while an instruction is stalled (F8)"
  ; "FDEBUG set"
  ; "FDEBUG set and clear in one cycle"
  ; "reset in the run"
  ; "forced instruction written"
  ; "SM enabled"
  ]
;;

let scenarios (c : Case.t) : (string * bool) list =
  let obs = observe c in
  let run = run_steps obs in
  let flag = Array.make (List.length scenario_names) false in
  let set i = flag.(i) <- true in
  let num = c.Case.num_sms in
  let prev_page = Array.make 4 0 in
  Array.iteri
    (fun cy s ->
      let i = s.inp in
      if i.Ports.rst_n = false then set 11;
      (match i.Ports.rxf_pop with
       | Some sm when sm < num ->
         set 2;
         if s.probe.Dut.rx_nonempty.(sm) then set 1 else set 3
       | _ -> ());
      if i.Ports.rxf_sm < num && s.regs.Ports.rxf_data <> 0 then set 0;
      if i.Ports.rxf_sm < num && s.probe.Dut.rx_nonempty.(i.Ports.rxf_sm) then set 1;
      (match i.Ports.imem_write with
       | Some (a, _) ->
         if a >= 32 then set 6;
         let live = ref false and stalled = ref false in
         for sm = 0 to num - 1 do
           if s.probe.Dut.fetch.(sm) = a
           then (
             live := true;
             if s.probe.Dut.stalled.(sm) then stalled := true)
         done;
         if !live then set 4;
         if !stalled then set 5
       | None -> ());
      for sm = 0 to num - 1 do
        let page = i.Ports.sm_ext.(sm) land 1 in
        if page <> prev_page.(sm) && cy > 0
        then (
          set 7;
          if s.probe.Dut.stalled.(sm) then set 8);
        prev_page.(sm) <- page
      done;
      if i.Ports.fdebug_set <> 0 then set 9;
      if i.Ports.fdebug_set <> 0 && i.Ports.fdebug_clear <> 0 then set 10;
      if i.Ports.instr_write <> None then set 12;
      if i.Ports.sm_enable <> 0 then set 13)
    run;
  List.mapi (fun k name -> name, flag.(k)) scenario_names
;;
