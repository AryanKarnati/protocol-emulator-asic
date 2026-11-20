open Hardcaml
open Signal

module type Width = sig
  val width : int
end

(* Number of bits needed to hold values 0 .. n - 1. *)
let bits_for n =
  let rec go bits = if 1 lsl bits >= n then bits else go (bits + 1) in
  go 0
;;

module Make (W : Width) = struct
  module I = struct
    type 'a t =
      { clk : 'a
      ; rst_n : 'a
      ; push : 'a
      ; pop : 'a
      ; data_in : 'a [@bits W.width]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { head : 'a [@bits W.width]
      ; level : 'a [@bits 4]
      ; full : 'a
      ; empty : 'a
      ; push_dropped : 'a
      ; pop_empty : 'a
      }
    [@@deriving hardcaml]
  end

  let create ~depth (_scope : Scope.t) (i : _ I.t) =
    if depth < 2 || depth land (depth - 1) <> 0
    then invalid_arg (Printf.sprintf "fifo depth must be a power of two >= 2, got %d" depth);
    let addr_bits = bits_for depth in
    let count_bits = bits_for (depth + 1) in
    let reset_spec ~reset_to =
      Reg_spec.override
        (Reg_spec.create () ~clock:i.clk)
        ~reset:i.rst_n
        ~reset_edge:Edge.Falling
        ~reset_to
    in
    let spec_addr = reset_spec ~reset_to:(zero addr_bits) in
    let spec_count = reset_spec ~reset_to:(zero count_bits) in
    let count = wire count_bits -- "count" in
    let full = count ==: of_int ~width:count_bits depth -- "full" in
    let empty = count ==: zero count_bits -- "empty" in
    let push_ok = i.push &: ~:full -- "push_ok" in
    let pop_ok = i.pop &: ~:empty -- "pop_ok" in
    let push_dropped = i.push &: full -- "push_dropped" in
    let pop_empty = i.pop &: empty -- "pop_empty" in
    let wr_ptr = wire addr_bits -- "wr_ptr" in
    let rd_ptr = wire addr_bits -- "rd_ptr" in
    wr_ptr <== reg spec_addr ~enable:push_ok (wr_ptr +: one addr_bits);
    rd_ptr <== reg spec_addr ~enable:pop_ok (rd_ptr +: one addr_bits);
    let count_up = uresize push_ok count_bits in
    let count_down = uresize pop_ok count_bits in
    count <== reg spec_count (count +: count_up -: count_down);
    let words =
      List.init depth (fun k ->
        (* Storage needs no reset: it is only read while the FIFO holds data. *)
        let enable = push_ok &: (wr_ptr ==: of_int ~width:addr_bits k) in
        reg (Reg_spec.create () ~clock:i.clk) ~enable i.data_in
        -- Printf.sprintf "word_%d" k)
    in
    let head = mux rd_ptr words -- "head" in
    { O.head
    ; level = uresize count 4
    ; full
    ; empty
    ; push_dropped
    ; pop_empty
    }
  ;;

  module Hier = Hierarchy.In_scope (I) (O)

  let hierarchical ~depth scope i =
    Hier.hierarchical ~scope ~name:"fifo" (create ~depth) i
  ;;
end
