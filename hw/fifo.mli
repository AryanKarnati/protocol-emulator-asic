(** Synchronous FIFO with power-of-two depth and fixed word width.

    A push succeeds iff the FIFO was not full before the rising edge. A pop succeeds iff
    it was not empty before the edge. Both can happen in the same cycle. [push_dropped]
    and [pop_empty] are high in the cycle when a push hits a full FIFO or a pop hits an
    empty one. Reset is asynchronous and active low ([rst_n]).

    [head] shows the word at the read pointer. It is undefined while the FIFO is empty,
    so callers must gate it with [empty]. *)

open Hardcaml

module type Width = sig
  val width : int
end

module Make (W : Width) : sig
  module I : sig
    type 'a t =
      { clk : 'a
      ; rst_n : 'a
      ; push : 'a
      ; pop : 'a
      ; data_in : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { head : 'a
      ; level : 'a
      ; full : 'a
      ; empty : 'a
      ; push_dropped : 'a
      ; pop_empty : 'a
      }
    [@@deriving hardcaml]
  end

  (** Flat instantiation, [depth] must be a power of two. *)
  val create : depth:int -> Scope.t -> Signal.t I.t -> Signal.t O.t

  (** Hierarchical instantiation: the FIFO appears as module [fifo]. *)
  val hierarchical : depth:int -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
