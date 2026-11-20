open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; int_ : 'a [@bits 16]
    ; frac : 'a [@bits 8]
    ; restart : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { tick : 'a } [@@deriving hardcaml]
end

(* The phase is kept in units of 1/256 cycle. Each cycle it gains 256, and a tick fires
   when it reaches the divisor, which is 256 * D = 256 * INT + FRAC. Ticks therefore fall
   at cycles ceil (Dq * (m + 1) / 256) after the restart, for tick number m. Consecutive
   gaps are floor(D) or ceil(D), and any 256 gaps sum to exactly Dq. *)
let phase_bits = 25

let create (_scope : Scope.t) (i : _ I.t) =
  let divisor =
    (* INT = 0 means 65536, i.e. 2^24 in these units. *)
    let is_zero = i.int_ ==: zero 16 in
    mux2
      is_zero
      (of_int ~width:phase_bits (1 lsl 24))
      (uresize (concat_msb [ i.int_; i.frac ]) phase_bits)
  in
  let spec =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to:(zero phase_bits)
  in
  let phase = wire phase_bits -- "phase" in
  let sum = phase +: of_int ~width:phase_bits 256 -- "phase_plus_step" in
  let tick = sum >=: divisor -- "tick_int" in
  let next = mux2 tick (sum -: divisor) sum in
  let next = mux2 i.restart (zero phase_bits) next in
  phase <== reg spec next;
  { O.tick }
;;

module Hier = Hierarchy.In_scope (I) (O)

let hierarchical scope i = Hier.hierarchical ~scope ~name:"clkdiv" create i
