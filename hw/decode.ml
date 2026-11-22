(* Combinational instruction decoder for block 2 (engine.md section 4).

   Each output is a function of the 16-bit word and the side-set configuration. The
   legality rules follow DESIGN.md 9.1 and Isa.is_legal exactly, so [legal] equals
   [Isa.is_legal (Isa.decode instr)]. The LCU extension encodings (IN 100, MOV source 100,
   SET 011) are legal here; the engine rejects them in block 2 (engine.md R12). *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { instr : 'a [@bits 16]
    ; sideset_count : 'a [@bits 3]
    ; side_en : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { legal : 'a
    ; is_jmp : 'a
    ; is_wait : 'a
    ; is_in : 'a
    ; is_out : 'a
    ; is_push : 'a
    ; is_pull : 'a
    ; is_mov : 'a
    ; is_irq : 'a
    ; is_set : 'a
    ; uses_lcu : 'a
    ; side_valid : 'a
    ; side_value : 'a [@bits 5]
    ; delay : 'a [@bits 5]
    ; bit_count : 'a [@bits 6]
    }
  [@@deriving hardcaml]
end

let c3 k = of_int ~width:3 k
let c2 k = of_int ~width:2 k

let create (_scope : Scope.t) (i : _ I.t) =
  let w = i.instr in
  let bit n = select w n n in
  let top = select w 15 13 in
  let ds = select w 12 8 in
  let low5 = select w 4 0 in
  let wsrc = select w 6 5 in
  let dest_io = select w 7 5 in
  let op_mov = select w 4 3 in
  let src_mov = select w 2 0 in
  (* Per-class legality (DESIGN.md 9.1, Isa.decode). *)
  let ok_wait =
    (* source 11 is JMPPIN (RP2350 v1); source IRQ with index bit 3 is PREV/NEXT *)
    (wsrc <>: c2 3) &: ~:((wsrc ==: c2 2) &: bit 3)
  in
  let ok_in = dest_io <>: c3 5 (* source 101 is In_status: not legal *) in
  let ok_pp = low5 ==: zero 5 in
  let ok_mov = (dest_io <>: c3 3) &: (op_mov <>: c2 3) in
  let ok_irq = ~:(bit 7) &: ~:(bit 3) in
  let ok_set = dest_io <: c3 5 in
  let legal =
    mux top [ vdd; ok_wait; ok_in; vdd; ok_pp; ok_mov; ok_irq; ok_set ] -- "legal"
  in
  let is_top k = legal &: (top ==: c3 k) in
  let is_jmp = is_top 0 -- "is_jmp" in
  let is_wait = is_top 1 -- "is_wait" in
  let is_in = is_top 2 -- "is_in" in
  let is_out = is_top 3 -- "is_out" in
  let is_push = (is_top 4 &: ~:(bit 7)) -- "is_push" in
  let is_pull = (is_top 4 &: bit 7) -- "is_pull" in
  let is_mov = is_top 5 -- "is_mov" in
  let is_irq = is_top 6 -- "is_irq" in
  let is_set = is_top 7 -- "is_set" in
  let uses_lcu =
    (legal
     &: ((top ==: c3 2) &: (dest_io ==: c3 4)
         |: ((top ==: c3 5) &: (src_mov ==: c3 4))
         |: ((top ==: c3 7) &: (dest_io ==: c3 3))))
    -- "uses_lcu"
  in
  (* Side-set and delay split (Isa.Side.split), for every count 0..5 and both enable
     values. [ds] is the 5-bit field, bits 12:8. The delay is the low 5 - count bits.
     Side-set value bits are the next count bits, and with enable the top of them is
     the enable bit, so the value has count - 1 bits. *)
  let count = i.sideset_count in
  let en = i.side_en in
  let field lo n =
    if n = 0 then zero 5 else uresize (select ds (lo + n - 1) lo) 5
  in
  let cases f = List.init 6 f in
  let delay_for c =
    let db = 5 - c in
    if db = 0 then zero 5 else field 0 db
  in
  let side_en_for c =
    if c <= 1 then zero 5 else field (5 - c) (c - 1)
  in
  let side_noen_for c =
    if c = 0 then zero 5 else field (5 - c) c
  in
  let delay = mux count (cases delay_for) -- "delay" in
  let side_valid =
    ((count <>: zero 3) &: (~:en |: select ds 4 4 (* ds[4] is the enable bit *)))
    -- "side_valid"
  in
  (* With no side-set the value is 0 (Isa.Side.split gives None, so there is no value). *)
  let side_value =
    mux2
      side_valid
      (mux2 en (mux count (cases side_en_for)) (mux count (cases side_noen_for)))
      (zero 5)
    -- "side_value"
  in
  (* Bit count: 1..32 for a legal IN or OUT, 32 for the encoding 0; otherwise 0. *)
  let cnt5 = low5 in
  let bc = mux2 (cnt5 ==: zero 5) (of_int ~width:6 32) (uresize cnt5 6) in
  let bit_count = mux2 (is_in |: is_out) bc (zero 6) -- "bit_count" in
  { O.legal
  ; is_jmp
  ; is_wait
  ; is_in
  ; is_out
  ; is_push
  ; is_pull
  ; is_mov
  ; is_irq
  ; is_set
  ; uses_lcu
  ; side_valid
  ; side_value
  ; delay
  ; bit_count
  }
;;

module Hier = Hierarchy.In_scope (I) (O)

let hierarchical scope i = Hier.hierarchical ~scope ~name:"decode" create i

let circuit () =
  let scope = Scope.create () in
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name:"decode" (create scope)
;;
