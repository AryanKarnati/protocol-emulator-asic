open Hardcaml
open Signal

module type Params = sig
  val width : int
  val depth : int
end

(* Number of bits needed to hold values 0 .. n - 1. *)
let bits_for n =
  let rec go bits = if 1 lsl bits >= n then bits else go (bits + 1) in
  go 0
;;

module Make (P : Params) = struct
  let () =
    if P.depth < 2 || P.depth land (P.depth - 1) <> 0
    then invalid_arg (Printf.sprintf "fifo depth must be a power of two >= 2, got %d" P.depth)
  ;;

  let addr_bits = bits_for P.depth

  (* The level counts 0 .. depth. *)
  let level_bits = bits_for (P.depth + 1)

  module I = struct
    type 'a t =
      { clk : 'a
      ; rst_n : 'a
      ; push : 'a
      ; pop : 'a
      ; data_in : 'a [@bits P.width]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { head : 'a [@bits P.width]
      ; level : 'a [@bits level_bits]
      ; full : 'a
      ; empty : 'a
      ; push_dropped : 'a
      ; pop_empty : 'a
      }
    [@@deriving hardcaml]
  end

  let create (_scope : Scope.t) (i : _ I.t) =
    let reset_spec ~reset_to =
      Reg_spec.override
        (Reg_spec.create () ~clock:i.clk)
        ~reset:i.rst_n
        ~reset_edge:Edge.Falling
        ~reset_to
    in
    let spec_addr = reset_spec ~reset_to:(zero addr_bits) in
    let spec_level = reset_spec ~reset_to:(zero level_bits) in
    let level = wire level_bits in
    let full = (level ==: of_int ~width:level_bits P.depth) -- "full" in
    let empty = (level ==: zero level_bits) -- "empty" in
    let push_ok = (i.push &: ~:full) -- "push_ok" in
    let pop_ok = (i.pop &: ~:empty) -- "pop_ok" in
    let push_dropped = (i.push &: full) -- "push_dropped" in
    let pop_empty = (i.pop &: empty) -- "pop_empty" in
    let wr_ptr = wire addr_bits in
    let wr_ptr_q =
      reg spec_addr ~enable:push_ok (wr_ptr +: one addr_bits) -- "wr_ptr_q"
    in
    wr_ptr <== wr_ptr_q;
    let rd_ptr = wire addr_bits in
    let rd_ptr_q =
      reg spec_addr ~enable:pop_ok (rd_ptr +: one addr_bits) -- "rd_ptr_q"
    in
    rd_ptr <== rd_ptr_q;
    let level_up = uresize push_ok level_bits -- "level_up" in
    let level_down = uresize pop_ok level_bits -- "level_down" in
    let level_q =
      reg spec_level (level +: level_up -: level_down) -- "level_q"
    in
    level <== level_q;
    let words =
      List.init P.depth (fun k ->
        (* Storage needs no reset: it is only read while the FIFO holds data. *)
        let sel = (wr_ptr ==: of_int ~width:addr_bits k) -- Printf.sprintf "wr_sel_%d" k in
        let enable = (push_ok &: sel) -- Printf.sprintf "word_%d_en" k in
        reg (Reg_spec.create () ~clock:i.clk) ~enable i.data_in -- Printf.sprintf "word_%d" k)
    in
    let head = mux rd_ptr words -- "head" in
    { O.head; level; full; empty; push_dropped; pop_empty }
  ;;

  module Hier = Hierarchy.In_scope (I) (O)

  let name = Printf.sprintf "fifo_%dx%d" P.depth P.width
  let hierarchical scope i = Hier.hierarchical ~scope ~name create i
end
