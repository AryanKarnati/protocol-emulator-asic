(* Random cases with Base_quickcheck: generators, shrinkers, and search.

   Programs are legal words (all nine instructions, jump targets inside the program), with
   a small rate of reserved and LCU words so that the ILLEGAL path is exercised directly. The
   configuration is within the contract. The stimulus covers pads (levels, single-pin changes,
   one-cycle pulses), enables (mostly on, from cycle 0), host operations, IRQ and FDEBUG
   writes, and mid-run resets. Every case goes through [Case.normalise], so shrinking can cut
   cases freely and still yield a valid one. *)

module G = Base_quickcheck.Generator
module S = Base_quickcheck.Shrinker
module Isa = Polyglot_isa.Isa
module Config = Pgsim.Config
module Sequence = Base.Sequence

let bind x f = G.bind x ~f
let int_g lo hi = G.int_inclusive lo hi
let bool_g = G.bool
let pick xs = G.of_list xs
let weighted xs = G.weighted_union xs
let ret = G.return
let delay_side_g = int_g 0 31
let w32_g = int_g 0 0xFFFF_FFFF

(* Reserved and LCU words (engine.md 9.1; the three extension encodings of 9.2). Written as
   raw words, since Isa.t cannot name a reserved field value. *)
let reserved_words =
  [ 0xA060 (* MOV destination 011 *)
  ; 0xA018 (* MOV operation 11 *)
  ; 0xA004 (* MOV source 100, CRC (LCU) *)
  ; 0x4088 (* IN source 100, LCU *)
  ; 0x40A8 (* IN source 101, status (reserved in v0) *)
  ; 0xE060 (* SET destination 011, LCU *)
  ; 0x2065 (* WAIT source 11 *)
  ; 0xC008 (* IRQ index bit 3 *)
  ; 0xC080 (* IRQ bit 7 *)
  ]
;;

let instr_g ~len : Isa.t G.t =
  let jmp =
    G.map3
      (pick [ Isa.Always; Not_x; X_dec; Not_y; Y_dec; X_ne_y; Jmp_pin; Not_osre ])
      (int_g 0 (len - 1))
      delay_side_g
      ~f:(fun cond addr ds -> Isa.Jmp { delay_side = ds; cond; addr })
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

(* One program word: legal, or (at a small rate) a reserved or LCU word. *)
let prog_word_g ~len =
  weighted
    [ 0.97, G.map (instr_g ~len) ~f:Isa.encode
    ; 0.03, pick reserved_words
    ]
;;

(* A word for a forced or IMEM write: mostly legal, sometimes any 16-bit word. *)
let word_g ~len =
  weighted [ 0.9, G.map (instr_g ~len) ~f:Isa.encode; 0.1, int_g 0 0xFFFF ]
;;

let program_g len : int list G.t = G.list_with_length (prog_word_g ~len) ~length:len

(* ------------------------------------------------------------------------------------ *)
(* Configuration (datasheet 3.7 fields, through the RP2040 register encoders) *)

(* The clock divider, weighted to the cases that matter: exactly 1.0, small and large
   integer parts, and INT = 0 (65536). INT = 0 with FRAC <> 0 is outside the contract. *)
let clkdiv_g : (int * int) G.t =
  weighted
    [ 0.35, ret (1, 0)
    ; 0.15, G.map (int_g 0 255) ~f:(fun f -> 1, f)
    ; 0.2, G.map (G.both (int_g 2 6) (int_g 0 255)) ~f:(fun (i, f) -> i, (if f < 128 then 0 else f))
    ; 0.1, G.map (G.both (int_g 7 255) (int_g 0 255)) ~f:(fun (i, f) -> i, (if f < 128 then 0 else f))
    ; 0.05, ret (0, 0)
    ; 0.05, G.map (int_g 0 255) ~f:(fun f -> 0, (if f = 0 then 0 else 0))
    ]
;;

(* Thresholds: boundary values often, the whole range otherwise. Register 0 means 32. *)
let thresh_g = weighted [ 0.4, pick [ 1; 2; 31; 32 ]; 0.2, int_g 7 9; 0.4, int_g 1 32 ]

let sm_cfg_g ~len ~fjoin : Case.sm_cfg G.t =
  let ( let* ) x f = bind x f in
  let ( let+ ) x f = G.map x ~f in
  let* clkint, clkfrac = clkdiv_g in
  let* side_en = bool_g in
  let* side_pindir = bool_g in
  let* jmp_pin = int_g 0 31 in
  let* out_sticky = bool_g in
  let* wa = int_g 0 (len - 1) in
  let* wb = int_g 0 (len - 1) in
  let* status_rx = bool_g in
  let* status_n = int_g 0 15 in
  let* pull_thresh = thresh_g in
  let* push_thresh = thresh_g in
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

(* SM_ENABLE levels: mostly SM 0 alone, or all four, otherwise anything. *)
let enable_g =
  weighted [ 0.4, ret 1; 0.15, ret 0xF; 0.15, ret 3; 0.1, ret 5; 0.2, int_g 0 15 ]
;;

(* ------------------------------------------------------------------------------------ *)
(* Stimulus *)

let sm_g = int_g 0 3

(* One event at [cycle], as a list (a pin pulse is two events). *)
let event_g ~len ~cycles (cycle : int) : (int * Case.event) list G.t =
  let single e = ret [ cycle, e ] in
  let kinds =
    [ (* pad changes: single pins and pulses are the common ones *)
      G.map (G.both (int_g 0 31) bool_g) ~f:(fun (p, l) -> [ cycle, Case.Pin_set (p, Bool.to_int l) ])
    ; G.map (G.both (int_g 0 7) bool_g) ~f:(fun (p, l) -> [ cycle, Case.Pin_set (p, Bool.to_int l) ])
    ; bind (int_g 0 7) (fun p ->
        let width = if cycle + 1 < cycles then 1 else 0 in
        ret
          ((cycle, Case.Pin_set (p, 1))
           :: (if width = 1 then [ cycle + 1, Case.Pin_set (p, 0) ] else [])))
    ; G.map w32_g ~f:(fun v -> [ cycle, Case.Ext_pins v ])
    ; G.map enable_g ~f:(fun v -> [ cycle, Case.Sm_enable v ])
    ; bind (G.both sm_g fjoin_g) (fun (sm, fj) ->
        G.map (sm_cfg_g ~len ~fjoin:fj) ~f:(fun c -> [ cycle, Case.Sm_config (sm, c) ]))
    ; G.map w32_g ~f:(fun v -> [ cycle, Case.Sync_bypass v ])
    ; G.map (G.both sm_g w32_g) ~f:(fun (sm, d) -> [ cycle, Case.Tx_push (sm, d) ])
    ; G.map sm_g ~f:(fun s -> [ cycle, Case.Rx_pop s ])
    ; G.map (G.both sm_g (word_g ~len)) ~f:(fun (s, d) -> [ cycle, Case.Instr_write (s, d) ])
    ; G.map (int_g 0 15) ~f:(fun m -> [ cycle, Case.Sm_restart m ])
    ; G.map (int_g 0 15) ~f:(fun m -> [ cycle, Case.Clkdiv_restart m ])
    ; G.map (int_g 0 15) ~f:(fun m -> [ cycle, Case.Fifo_flush m ])
    ; G.map (int_g 0 255) ~f:(fun m -> [ cycle, Case.Irq_clear m ])
    ; G.map (int_g 0 255) ~f:(fun m -> [ cycle, Case.Irq_force m ])
    ; G.map w32_g ~f:(fun m -> [ cycle, Case.Fdebug_clear m ])
    ; G.map (G.both (int_g 0 31) (word_g ~len:32)) ~f:(fun (a, d) -> [ cycle, Case.Imem_write (a, d) ])
    ; single Case.Reset_low
    ]
  in
  G.union kinds
;;

let events_g ~len ~cycles : (int * Case.event) list G.t =
  bind (int_g 0 80) (fun n ->
    G.map (G.all (List.init n (fun _ -> bind (int_g 0 (cycles - 1)) (fun cy -> event_g ~len ~cycles cy))))
      ~f:List.concat)
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
  (* Most cases enable an SM at cycle 0, so the program runs from the start. *)
  let* enable0 =
    weighted [ 0.85, G.map enable_g ~f:(fun v -> [ 0, Case.Sm_enable v ]); 0.15, ret [] ]
  in
  let* sync = weighted [ 0.4, ret 0; 0.2, ret 0xFFFF_FFFF; 0.2, w32_g; 0.2, int_g 0 0xFF ] in
  (* One mid-run reset in about one case in six. *)
  let* resets =
    weighted [ 0.85, ret []; 0.15, G.map (int_g 1 (max 1 (cycles - 2))) ~f:(fun c -> [ c, Case.Reset_low ]) ]
  in
  let+ events = events_g ~len ~cycles in
  let imem = Array.make 32 0 in
  List.iteri (fun i w -> imem.(i) <- w) prog;
  Case.normalise
    { num_sms
    ; imem
    ; initial = Array.of_list initial
    ; initial_sync = sync
    ; cycles
    ; events = enable0 @ resets @ events
    }
;;

let generator : Case.t G.t = case_g

(* ------------------------------------------------------------------------------------ *)
(* Shrinking. Candidates are smaller cases; each is normalised before it is run. The
   greedy search accepts a candidate only if [score] drops, so it always ends. *)

let popcount x =
  let rec go x acc = if x = 0 then acc else go (x land (x - 1)) (acc + 1) in
  go (x land 0xFFFF_FFFF) 0
;;

let event_bits (ev : Case.event) =
  match ev with
  | Case.Ext_pins v | Sync_bypass v -> popcount v
  | Pin_set (p, l) -> p + l
  | Sm_enable v -> popcount v
  | Sm_config (sm, c) ->
    sm + popcount c.Case.clkdiv + popcount c.execctrl + popcount c.shiftctrl + popcount c.pinctrl
  | Tx_push (sm, d) | Instr_write (sm, d) -> sm + popcount d
  | Rx_pop sm -> sm
  | Sm_restart m | Clkdiv_restart m | Fifo_flush m | Irq_clear m | Irq_force m | Fdebug_clear m ->
    popcount m
  | Imem_write (a, d) -> a + popcount d
  | Reset_low -> 0
;;

let nondefault_regs (c : Case.t) =
  Array.fold_left
    (fun acc (s : Case.sm_cfg) ->
      let d = Case.default_cfg in
      acc
      + (if s.clkdiv <> d.clkdiv then 1 else 0)
      + (if s.execctrl <> d.execctrl then 1 else 0)
      + (if s.shiftctrl <> d.shiftctrl then 1 else 0)
      + if s.pinctrl <> d.pinctrl then 1 else 0)
    0 c.Case.initial
;;

(* Lexicographic: fewer events, shorter, fewer non-zero words, fewer non-default config
   registers, fewer set bits in the payloads. *)
let score (c : Case.t) =
  ( List.length c.Case.events
  , c.Case.cycles
  , Array.fold_left (fun a w -> if w <> 0 then a + 1 else a) 0 c.Case.imem
  , nondefault_regs c
  , List.fold_left (fun a (_, ev) -> a + event_bits ev) 0 c.Case.events
    + Array.fold_left (fun a w -> a + popcount w) 0 c.Case.imem )
;;

(* A NOP for shrinking: MOV Y, Y (a legal instruction that does nothing visible). *)
let nop_word = Isa.encode (Isa.Mov { delay_side = 0; dest = Mov_y; op = Op_none; source = Ms_y })

let shrink_event (ev : Case.event) : Case.event list =
  match ev with
  | Case.Ext_pins v when v <> 0 -> [ Case.Ext_pins 0 ]
  | Case.Pin_set (p, 1) -> [ Case.Pin_set (p, 0) ]
  | Case.Tx_push (sm, d) when d <> 0 -> [ Case.Tx_push (sm, 0) ]
  | Case.Instr_write (sm, d) when d <> 0 -> [ Case.Instr_write (sm, 0); Case.Instr_write (sm, nop_word) ]
  | Case.Imem_write (a, d) when d <> 0 -> [ Case.Imem_write (a, 0); Case.Imem_write (a, nop_word) ]
  | Case.Sync_bypass v when v <> 0 -> [ Case.Sync_bypass 0 ]
  | Case.Irq_force m when m <> 0 -> [ Case.Irq_force 0 ]
  | Case.Irq_clear m when m <> 0 -> [ Case.Irq_clear 0 ]
  | Case.Fdebug_clear m when m <> 0 -> [ Case.Fdebug_clear 0 ]
  | Case.Sm_config (sm, c) ->
    let d = Case.default_cfg in
    (* whole config to default, then one register at a time *)
    [ Case.Sm_config (sm, d)
    ; Case.Sm_config (sm, { c with clkdiv = d.clkdiv })
    ; Case.Sm_config (sm, { c with execctrl = d.execctrl })
    ; Case.Sm_config (sm, { c with shiftctrl = d.shiftctrl })
    ; Case.Sm_config (sm, { c with pinctrl = d.pinctrl })
    ]
  | _ -> []
;;

let shrink_case (c : Case.t) : Case.t Sequence.t =
  let open Sequence in
  let evs = c.Case.events in
  let n = List.length evs in
  let drop_range lo hi = List.filteri (fun i _ -> i < lo || i >= hi) evs in
  (* Delta debugging: remove chunks of decreasing size, then single events. *)
  let chunk_sizes =
    let rec go k acc = if k < 1 then acc else go (k / 2) (if List.mem k acc then acc else k :: acc) in
    go (max 1 (n / 2)) []
  in
  let drops =
    List.concat_map
      (fun k ->
        List.init ((n + k - 1) / k) (fun j -> j * k)
        |> List.map (fun lo -> { c with Case.events = drop_range lo (min n (lo + k)) }))
      chunk_sizes
  in
  (* Earlier cycles: halve each event's cycle, or move it one cycle earlier. *)
  let moves =
    List.concat
      (List.mapi
         (fun i (cy, ev) ->
           if cy = 0
           then []
           else
             List.map
               (fun cy' ->
                 { c with
                   Case.events = List.mapi (fun j e -> if i = j then cy', ev else e) evs
                 })
               (List.sort_uniq Stdlib.compare [ cy / 2; cy - 1 ]))
         evs)
  in
  (* Idle prefix: shift every event to start at cycle 0 and cut the cycles. *)
  let trim =
    match evs with
    | [] -> []
    | _ ->
      let m = List.fold_left (fun a (cy, _) -> min a cy) max_int evs in
      if m > 0
      then
        [ { c with
            Case.cycles = max 1 (c.Case.cycles - m)
          ; events = List.map (fun (cy, ev) -> cy - m, ev) evs
          }
        ]
      else []
  in
  let replace_each =
    List.concat
      (List.mapi
         (fun i (cy, ev) ->
           List.map
             (fun ev' ->
               { c with Case.events = List.mapi (fun j e -> if i = j then cy, ev' else e) evs })
             (shrink_event ev))
         evs)
  in
  let shorter =
    if c.Case.cycles > 1
    then
      [ { c with
          Case.cycles = max 1 (c.Case.cycles / 2)
        ; events = List.filter (fun (cy, _) -> cy < max 1 (c.Case.cycles / 2)) evs
        }
      ]
    else []
  in
  let fewer_sms = if c.Case.num_sms > 1 then [ { c with Case.num_sms = c.Case.num_sms - 1 } ] else [] in
  let imem_words =
    List.concat
      (List.init 32 (fun i ->
         let w = c.Case.imem.(i) in
         if w = 0
         then []
         else (
           let zero = Array.copy c.Case.imem in
           zero.(i) <- 0;
           let nop = Array.copy c.Case.imem in
           nop.(i) <- nop_word;
           [ { c with Case.imem = zero }; { c with Case.imem = nop } ])))
  in
  let initial_regs =
    List.concat
      (List.init 4 (fun i ->
         let s = c.Case.initial.(i) in
         let d = Case.default_cfg in
         let with_ f =
           let initial = Array.copy c.Case.initial in
           initial.(i) <- f;
           { c with Case.initial }
         in
         List.filter_map
           (fun (cur, def, f) -> if cur = def then None else Some (with_ (f def)))
           [ s.clkdiv, d.clkdiv, (fun v -> { s with clkdiv = v })
           ; s.execctrl, d.execctrl, (fun v -> { s with execctrl = v })
           ; s.shiftctrl, d.shiftctrl, (fun v -> { s with shiftctrl = v })
           ; s.pinctrl, d.pinctrl, (fun v -> { s with pinctrl = v })
           ]))
  in
  let sync0 = if c.Case.initial_sync <> 0 then [ { c with Case.initial_sync = 0 } ] else [] in
  of_list
    (List.concat
       [ trim
       ; drops
       ; shorter
       ; fewer_sms
       ; imem_words
       ; initial_regs
       ; sync0
       ; moves
       ; replace_each
       ])
;;

let shrinker : Case.t S.t = S.create shrink_case

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

(* Greedy shrinking: take the first candidate that still fails and scores lower, repeat.
   [limit] bounds the candidates tried in total. *)
let shrink_failing ~check ~limit (c : Case.t) (f : Lockstep.failure) =
  let tried = ref 0 in
  let rec go c f steps =
    let s0 = score c in
    let next =
      Sequence.find_map (shrink_case c) ~f:(fun cand ->
        if !tried >= limit
        then None
        else (
          let cand = Case.normalise cand in
          if Stdlib.compare (score cand) s0 >= 0
          then None
          else (
            incr tried;
            match check cand with
            | Lockstep.Fail f' -> Some (cand, f', steps + 1)
            | Lockstep.Pass _ -> None)))
    in
    match next with
    | Some (c', f', steps') -> go c' f' steps'
    | None -> c, f, steps
  in
  go c f 0
;;

(* One generated case, the i-th from [seed], for hand-off files. *)
let generate_one ~seed i : Case.t =
  let random = Splittable_random.create (Base.Random.State.make [| seed; i |]) in
  Case.normalise (G.generate generator ~size:(i mod 31) ~random)
;;

(* Generate [count] cases from [seed] and run [check] on each. On the first failure, shrink
   it and stop. [sms] pins num_sms when given. *)
let search ?(seed = 1) ?sms ?(shrink_limit = 4000) ~check ~count () : search_result =
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

(* Generate [count] cases and run every one (no stop at the first failure). Returns the
   failing ones as (index, case, failure). *)
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
