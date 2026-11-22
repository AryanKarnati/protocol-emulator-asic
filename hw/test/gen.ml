(* Random cases with Base_quickcheck: generators, shrinkers, and a shrinking search.

   Programs are legal words (all nine instructions, jump targets inside the program), the
   configuration is within the contract, and the stimulus covers pads, enables, host
   operations and IRQ and FDEBUG writes. Every generated case goes through
   [Case.normalise], so the shrinker can cut it freely and still get a valid case. *)

module G = Base_quickcheck.Generator
module S = Base_quickcheck.Shrinker
module Isa = Polyglot_isa.Isa
module Config = Pgsim.Config
module Sequence = Base.Sequence

(* ------------------------------------------------------------------------------------ *)
(* Instructions *)

let bind x f = G.bind x ~f
let pick xs = G.of_list xs
let _ = Sequence.empty
let bool_g = G.bool
let int_g lo hi = G.int_inclusive lo hi
let delay_side_g = int_g 0 31

let instr_g ~len : Isa.t G.t =
  let jmp =
    G.map3
      (pick [ Isa.Always; Not_x; X_dec; Not_y; Y_dec; X_ne_y; Jmp_pin; Not_osre ])
      (int_g 0 (len - 1))
      delay_side_g
      ~f:(fun cond addr ds ->
      Isa.Jmp { delay_side = ds; cond; addr })
  in
  let wait =
    bind (G.both bool_g delay_side_g) (fun (polarity, ds) ->
      G.map
        (G.union
           [ G.map (int_g 0 31) ~f:(fun n -> Isa.Wsrc_gpio n)
           ; G.map (int_g 0 31) ~f:(fun n -> Isa.Wsrc_pin n)
           ; G.map (G.both (int_g 0 7) bool_g) ~f:(fun (index, rel) -> Isa.Wsrc_irq { index; rel })
           ])
        ~f:(fun source -> Isa.Wait { delay_side = ds; polarity; source }))
  in
  let inp =
    G.map3
      (pick [ Isa.In_pins; In_x; In_y; In_null; In_isr; In_osr ])
      (int_g 1 32) delay_side_g
      ~f:(fun source bit_count ds -> Isa.In { delay_side = ds; source; bit_count })
  in
  let out =
    G.map3
      (pick [ Isa.Out_pins; Out_x; Out_y; Out_null; Out_pindirs; Out_pc; Out_isr; Out_exec ])
      (int_g 1 32) delay_side_g
      ~f:(fun dest bit_count ds -> Isa.Out { delay_side = ds; dest; bit_count })
  in
  let push =
    G.map3 bool_g bool_g delay_side_g ~f:(fun if_full block ds ->
      Isa.Push { delay_side = ds; if_full; block })
  in
  let pull =
    G.map3 bool_g bool_g delay_side_g ~f:(fun if_empty block ds ->
      Isa.Pull { delay_side = ds; if_empty; block })
  in
  let mov =
    G.map3
      (G.both
         (pick [ Isa.Mov_pins; Mov_x; Mov_y; Mov_exec; Mov_pc; Mov_isr; Mov_osr ])
         (pick [ Isa.Op_none; Op_invert; Op_reverse ]))
      (pick [ Isa.Ms_pins; Ms_x; Ms_y; Ms_null; Ms_status; Ms_isr; Ms_osr ])
      delay_side_g
      ~f:(fun (dest, op) source ds -> Isa.Mov { delay_side = ds; dest; op; source })
  in
  let irq =
    bind (G.both bool_g bool_g) (fun (clear, wait) ->
      G.map3 (int_g 0 7) bool_g delay_side_g ~f:(fun index rel ds ->
        Isa.Irq { delay_side = ds; clear; wait; index; rel }))
  in
  let set =
    G.map3
      (pick [ Isa.Set_pins; Set_x; Set_y; Set_pindirs ])
      (int_g 0 31) delay_side_g
      ~f:(fun dest data ds -> Isa.Set { delay_side = ds; dest; data })
  in
  G.union [ jmp; wait; inp; out; push; pull; mov; irq; set ]
;;

(* A word for an instruction memory or forced write: legal, or any 16-bit word. *)
let word_g ~len = G.weighted_union [ 0.9, G.map (instr_g ~len) ~f:Isa.encode; 0.1, int_g 0 0xFFFF ]

let program_g len : int list G.t = G.list_with_length (G.map (instr_g ~len) ~f:Isa.encode) ~length:len

(* ------------------------------------------------------------------------------------ *)
(* Configuration (datasheet 3.7 fields, through the RP2040 register encoders) *)

let sm_cfg_g ~len ~fjoin : Case.sm_cfg G.t =
  let ( let* ) x f = bind x f in
  let ( let+ ) x f = G.map x ~f in
  let* clkint = int_g 1 6 in
  let* clkfrac = int_g 0 255 in
  let* side_en = bool_g in
  let* side_pindir = bool_g in
  let* jmp_pin = int_g 0 31 in
  let* out_sticky = bool_g in
  let* wa = int_g 0 (len - 1) in
  let* wb = int_g 0 (len - 1) in
  let* status_rx = bool_g in
  let* status_n = int_g 0 15 in
  let* pull_thresh = int_g 1 32 in
  let* push_thresh = int_g 1 32 in
  let* out_right = bool_g in
  let* in_right = bool_g in
  let* autopull = bool_g in
  let* autopush = bool_g in
  let* sideset_count = int_g 0 5 in
  let* set_count = int_g 0 5 in
  let* out_count = int_g 0 32 in
  let* in_base = int_g 0 31 in
  let* sideset_base = int_g 0 31 in
  let* set_base = int_g 0 31 in
  let+ out_base = int_g 0 31 in
  let c =
    { Config.clkdiv_int = clkint
    ; clkdiv_frac = clkfrac
    ; side_en
    ; side_pindir
    ; jmp_pin
    ; out_sticky
    ; wrap_top = max wa wb
    ; wrap_bottom = min wa wb
    ; status_rx
    ; status_n
    ; fjoin_rx = fst fjoin
    ; fjoin_tx = snd fjoin
    ; pull_thresh
    ; push_thresh
    ; out_right
    ; in_right
    ; autopull
    ; autopush
    ; sideset_count
    ; set_count
    ; out_count
    ; in_base
    ; sideset_base
    ; set_base
    ; out_base
    }
  in
  { Case.clkdiv = Config.clkdiv_register c
  ; execctrl = Config.execctrl_register c
  ; shiftctrl = Config.shiftctrl_register c
  ; pinctrl = Config.pinctrl_register c
  }
;;

(* FJOIN never changes after the load phase (see Case), so it is chosen once per SM. *)
let fjoin_g = G.map (int_g 0 2) ~f:(fun k -> k = 1, k = 2)

(* ------------------------------------------------------------------------------------ *)
(* Stimulus *)

let event_g ~len ~num_sms:_ (cycle : int) : (int * Case.event) G.t =
  let sm = int_g 0 3 in
  let w32 = int_g 0 0xFFFF_FFFF in
  let mask n = int_g 0 n in
  let ev =
    G.union
      [ G.map w32 ~f:(fun v -> Case.Ext_pins v)
      ; G.map (int_g 0 15) ~f:(fun v -> Case.Sm_enable v)
      ; bind (G.both sm (fjoin_g)) (fun (sm, fj) ->
          G.map (sm_cfg_g ~len ~fjoin:fj) ~f:(fun c -> Case.Sm_config (sm, c)))
      ; G.map w32 ~f:(fun v -> Case.Sync_bypass v)
      ; G.map (G.both sm w32) ~f:(fun (sm, d) -> Case.Tx_push (sm, d))
      ; G.map sm ~f:(fun s -> Case.Rx_pop s)
      ; G.map (G.both sm (word_g ~len)) ~f:(fun (s, d) -> Case.Instr_write (s, d))
      ; G.map (mask 15) ~f:(fun m -> Case.Sm_restart m)
      ; G.map (mask 15) ~f:(fun m -> Case.Clkdiv_restart m)
      ; G.map (mask 15) ~f:(fun m -> Case.Fifo_flush m)
      ; G.map (mask 255) ~f:(fun m -> Case.Irq_clear m)
      ; G.map (mask 255) ~f:(fun m -> Case.Irq_force m)
      ; G.map w32 ~f:(fun m -> Case.Fdebug_clear m)
      ; G.map (G.both (int_g 0 31) (word_g ~len:32)) ~f:(fun (a, d) -> Case.Imem_write (a, d))
      ]
  in
  G.map ev ~f:(fun e -> cycle, e)
;;

(* Weight the kinds so that pads, enables and host operations dominate and configuration
   changes are rare. The cycle of each event is drawn uniformly. *)
let events_g ~len ~num_sms ~cycles : (int * Case.event) list G.t =
  bind (int_g 0 80) (fun n ->
    G.all
      (List.init n (fun _ ->
         bind (int_g 0 (cycles - 1)) (fun cy -> event_g ~len ~num_sms cy))))
;;

(* ------------------------------------------------------------------------------------ *)
(* Whole cases *)

let case_g : Case.t G.t =
  let ( let* ) x f = bind x f in
  let ( let+ ) x f = G.map x ~f in
  let* len = int_g 1 32 in
  let* num_sms = int_g 1 4 in
  let* prog = program_g len in
  let* initial = G.all (List.init 4 (fun _ -> let* fj = fjoin_g in sm_cfg_g ~len ~fjoin:fj)) in
  let* cycles = int_g 20 300 in
  let+ events = events_g ~len ~num_sms ~cycles in
  let imem = Array.make 32 0 in
  List.iteri (fun i w -> imem.(i) <- w) prog;
  Case.normalise
    { num_sms; imem; initial = Array.of_list initial; initial_sync = 0; cycles; events }
;;

(* ------------------------------------------------------------------------------------ *)
(* Shrinking: smaller cases, each still valid after [Case.normalise]. *)

let shrink_event (ev : Case.event) : Case.event list =
  let zero_data = function
    | Case.Ext_pins v when v <> 0 -> [ Case.Ext_pins 0 ]
    | Case.Tx_push (sm, d) when d <> 0 -> [ Case.Tx_push (sm, 0) ]
    | Case.Instr_write (sm, d) when d <> 0 -> [ Case.Instr_write (sm, 0) ]
    | Case.Imem_write (a, d) when d <> 0 -> [ Case.Imem_write (a, 0) ]
    | Case.Sync_bypass v when v <> 0 -> [ Case.Sync_bypass 0 ]
    | Case.Irq_force m when m <> 0 -> [ Case.Irq_force 0 ]
    | Case.Irq_clear m when m <> 0 -> [ Case.Irq_clear 0 ]
    | Case.Fdebug_clear m when m <> 0 -> [ Case.Fdebug_clear 0 ]
    | Case.Sm_config (sm, _) -> [ Case.Sm_config (sm, Case.default_cfg) ]
    | _ -> []
  in
  zero_data ev
;;

let shrink_case (c : Case.t) : Case.t Sequence.t =
  let open Sequence in
  let n = List.length c.Case.events in
  let drop_range lo hi =
    List.filteri (fun i _ -> i < lo || i >= hi) c.Case.events
  in
  let drops =
    if n = 0
    then empty
    else
      of_list
        (List.map
           (fun events -> { c with Case.events })
           ([ drop_range 0 (n / 2); drop_range (n / 2) n ]
            @ (if n <= 40 then List.init n (fun i -> drop_range i (i + 1)) else [])))
  in
  let replace_each =
    of_list
      (List.concat
         (List.mapi
            (fun i (cy, ev) ->
              List.map
                (fun ev' ->
                  { c with
                    Case.events = List.mapi (fun j e -> if i = j then cy, ev' else e) c.Case.events
                  })
                (shrink_event ev))
            c.Case.events))
  in
  let shorter =
    if c.Case.cycles > 1
    then (
      let cy' = max 1 (c.Case.cycles / 2) in
      singleton
        { c with
          Case.cycles = cy'
        ; events = List.filter (fun (cy, _) -> cy < cy') c.Case.events
        })
    else empty
  in
  let fewer_sms = if c.Case.num_sms > 1 then singleton { c with Case.num_sms = c.Case.num_sms - 1 } else empty in
  let imem_zeroed =
    of_list
      (List.filter_map
         (fun i ->
           if c.Case.imem.(i) = 0
           then None
           else (
             let imem = Array.copy c.Case.imem in
             imem.(i) <- 0;
             Some { c with Case.imem }))
         (List.init 32 Fun.id))
  in
  let initial_default =
    of_list
      (List.filter_map
         (fun i ->
           if c.Case.initial.(i) = Case.default_cfg
           then None
           else (
             let initial = Array.copy c.Case.initial in
             initial.(i) <- Case.default_cfg;
             Some { c with Case.initial }))
         (List.init 4 Fun.id))
  in
  List.fold_left append empty [ shorter; drops; replace_each; fewer_sms; imem_zeroed; initial_default ]
;;

let shrinker : Case.t S.t = S.create shrink_case
let generator : Case.t G.t = case_g

(* ------------------------------------------------------------------------------------ *)
(* Search *)

type search_result =
  | Passed of { count : int; total_cycles : int; seconds : float }
  | Failed of
      { index : int (** which generated case failed (0-based) *)
      ; case : Case.t (** the shrunk case, normalised *)
      ; failure : Lockstep.failure
      ; shrink_steps : int
      }

(* Greedy shrinking: take the first candidate that still fails, repeat. [limit] bounds the
   number of candidates tried, so a shrink always ends. *)
let shrink_failing ~check ~limit (c : Case.t) (f : Lockstep.failure) =
  let tried = ref 0 in
  let rec go c f steps =
    let next =
      Sequence.find_map (shrink_case c) ~f:(fun cand ->
        if !tried >= limit
        then None
        else (
          incr tried;
          let cand = Case.normalise cand in
          match check cand with
          | Lockstep.Fail f' -> Some (cand, f', steps + 1)
          | Lockstep.Pass _ -> None))
    in
    match next with
    | Some (c', f', steps') -> go c' f' steps'
    | None -> c, f, steps
  in
  go c f 0
;;

(* Generate [count] cases from [seed] and run [check] on each. On the first failure, shrink
   it and stop. [check] runs the lockstep on one case. *)
let search ?(seed = 1) ?sms ?(shrink_limit = 2000) ~check ~count () : search_result =
  let random = Splittable_random.create (Base.Random.State.make [| seed |]) in
  let t0 = Sys.time () in
  let total_cycles = ref 0 in
  let rec loop i =
    if i >= count
    then Passed { count; total_cycles = !total_cycles; seconds = Sys.time () -. t0 }
    else (
      let c = G.generate generator ~size:(i mod 31) ~random in
      let c = match sms with Some n -> { c with Case.num_sms = n } | None -> c in
      let c = Case.normalise c in
      match check c with
      | Lockstep.Pass { cycles } ->
        total_cycles := !total_cycles + cycles;
        loop (i + 1)
      | Lockstep.Fail f ->
        let c', f', steps = shrink_failing ~check ~limit:shrink_limit c f in
        Failed { index = i; case = c'; failure = f'; shrink_steps = steps })
  in
  loop 0
;;

(* One generated case, the i-th from [seed], for hand-off files. *)
let generate_one ~seed i : Case.t =
  let random = Splittable_random.create (Base.Random.State.make [| seed; i |]) in
  Case.normalise (G.generate generator ~size:(i mod 31) ~random)
;;

(* Generate [count] cases and run every one (no stop at the first failure). Returns the
   failing ones as (index, case, failure). [sms] pins num_sms when given. *)
let search_all ?(seed = 1) ?sms ~check ~count () =
  let random = Splittable_random.create (Base.Random.State.make [| seed |]) in
  let fails = ref [] in
  let passed = ref 0 in
  let total_cycles = ref 0 in
  let t0 = Sys.time () in
  for i = 0 to count - 1 do
    let c = G.generate generator ~size:(i mod 31) ~random in
    let c = match sms with Some n -> { c with Case.num_sms = n } | None -> c in
    let c = Case.normalise c in
    match check c with
    | Lockstep.Pass { cycles } ->
      incr passed;
      total_cycles := !total_cycles + cycles
    | Lockstep.Fail f -> fails := (i, c, f) :: !fails
  done;
  !passed, List.rev !fails, !total_cycles, Sys.time () -. t0
;;
