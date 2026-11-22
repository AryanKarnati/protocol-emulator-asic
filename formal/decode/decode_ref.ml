(* Reference outputs of the block 2 decoder, from docs/engine.md section 4 and the ISA
   library (polyglot_isa). Written from the contract, not from hw/decode.ml. *)

module Isa = Polyglot_isa.Isa

type expected =
  { legal : bool
  ; is_jmp : bool
  ; is_wait : bool
  ; is_in : bool
  ; is_out : bool
  ; is_push : bool
  ; is_pull : bool
  ; is_mov : bool
  ; is_irq : bool
  ; is_set : bool
  ; uses_lcu : bool
  ; side_valid : bool
  ; side_value : int
  ; delay : int
  ; bit_count : int
  }

(* Every valid side-set configuration: count 0 to 5, enable only with count >= 1. *)
let configs =
  [ 0, false
  ; 1, false
  ; 2, false
  ; 3, false
  ; 4, false
  ; 5, false
  ; 1, true
  ; 2, true
  ; 3, true
  ; 4, true
  ; 5, true
  ]
;;

let expected ~instr ~count ~enable =
  let t = Isa.decode instr in
  let legal = Isa.is_legal t in
  let kind p = legal && p in
  let split = Isa.Side.split { Isa.Side.count; enable } (Isa.delay_side t) in
  { legal
  ; is_jmp = kind (match t with Isa.Jmp _ -> true | _ -> false)
  ; is_wait = kind (match t with Isa.Wait _ -> true | _ -> false)
  ; is_in = kind (match t with Isa.In _ -> true | _ -> false)
  ; is_out = kind (match t with Isa.Out _ -> true | _ -> false)
  ; is_push = kind (match t with Isa.Push _ -> true | _ -> false)
  ; is_pull = kind (match t with Isa.Pull _ -> true | _ -> false)
  ; is_mov = kind (match t with Isa.Mov _ -> true | _ -> false)
  ; is_irq = kind (match t with Isa.Irq _ -> true | _ -> false)
  ; is_set = kind (match t with Isa.Set _ -> true | _ -> false)
  ; uses_lcu =
      (match t with
       | Isa.In { source = Isa.In_lcu; _ }
       | Isa.Mov { source = Isa.Ms_crc; _ }
       | Isa.Set { dest = Isa.Set_lcu; _ } -> true
       | _ -> false)
  ; side_valid = Option.is_some split.side
  ; side_value = Option.value split.side ~default:0
  ; delay = split.delay
  ; bit_count =
      (if not legal
       then 0
       else (
         match t with
         | Isa.In { bit_count; _ } | Isa.Out { bit_count; _ } -> bit_count
         | _ -> 0))
  }
;;

(* Names of the outputs that disagree. side_value is compared only when side_valid is 1
   in the reference (engine.md section 4). *)
let diffs ~(got : expected) (exp : expected) =
  let d name cond acc = if cond then name :: acc else acc in
  []
  |> d "legal" (got.legal <> exp.legal)
  |> d "is_jmp" (got.is_jmp <> exp.is_jmp)
  |> d "is_wait" (got.is_wait <> exp.is_wait)
  |> d "is_in" (got.is_in <> exp.is_in)
  |> d "is_out" (got.is_out <> exp.is_out)
  |> d "is_push" (got.is_push <> exp.is_push)
  |> d "is_pull" (got.is_pull <> exp.is_pull)
  |> d "is_mov" (got.is_mov <> exp.is_mov)
  |> d "is_irq" (got.is_irq <> exp.is_irq)
  |> d "is_set" (got.is_set <> exp.is_set)
  |> d "uses_lcu" (got.uses_lcu <> exp.uses_lcu)
  |> d "side_valid" (got.side_valid <> exp.side_valid)
  |> d "side_value" (exp.side_valid && got.side_value <> exp.side_value)
  |> d "delay" (got.delay <> exp.delay)
  |> d "bit_count" (got.bit_count <> exp.bit_count)
  |> List.rev
;;

let to_string (e : expected) =
  Printf.sprintf
    "legal=%b jmp=%b wait=%b in=%b out=%b push=%b pull=%b mov=%b irq=%b set=%b lcu=%b \
     sv=%b sval=%d delay=%d bits=%d"
    e.legal
    e.is_jmp
    e.is_wait
    e.is_in
    e.is_out
    e.is_push
    e.is_pull
    e.is_mov
    e.is_irq
    e.is_set
    e.uses_lcu
    e.side_valid
    e.side_value
    e.delay
    e.bit_count
;;
