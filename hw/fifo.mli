(** Synchronous FIFO with a power-of-two depth and a fixed word width.

    Reset is asynchronous and active low ([rst_n]). Storage is not reset: [head] is
    undefined while the FIFO is empty, so callers must gate it with [empty].

    Contract for a cycle in which [push] and [pop] are both high:
    - Full FIFO: the push is dropped, even though a pop happens in the same cycle. The
      pop succeeds and [push_dropped] is high.
    - Empty FIFO: the push is accepted, and the pop is refused and [pop_empty] is high.
      The word pushed is not visible to that pop: there is no bypass.
    - Otherwise both succeed and [level] is unchanged.

    A push succeeds iff the FIFO was not full before the rising edge. A pop succeeds iff
    it was not empty before the edge. [push_dropped] and [pop_empty] are combinational
    pulses: high in the cycle in which the command is sampled. *)

open Hardcaml

module type Params = sig
  (** Word width in bits. *)
  val width : int

  (** Number of entries. Must be a power of two, at least 2. *)
  val depth : int
end

module Make (_ : Params) : sig
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
        (** Number of words held, 0 to [depth]. Width is [bits_for (depth + 1)]. *)
      ; full : 'a
      ; empty : 'a
      ; push_dropped : 'a
      ; pop_empty : 'a
      }
    [@@deriving hardcaml]
  end

  (** Flat instantiation: the logic is inlined into the parent. *)
  val create : Scope.t -> Signal.t I.t -> Signal.t O.t

  (** Hierarchical instantiation. The module is named [fifo_<depth>x<width>], for example
      [fifo_4x32], so FIFOs of different sizes never share a module name. *)
  val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
end
