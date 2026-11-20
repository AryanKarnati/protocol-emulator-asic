(** 16.8 fractional clock-enable divider (DESIGN.md 8.1).

    The divisor is D = INT + FRAC/256, with INT = 0 meaning 65536 (FRAC must then be 0).
    [tick] is high in every cycle in which the divided clock would have a rising edge.

    [restart] (synchronous, sampled at the rising edge) restarts the phase. The first
    tick comes at most INT + 1 cycles after the restart edge. Writes to [int_] and [frac]
    take effect without a restart; they do not restart the phase.

    Reset is asynchronous and active low ([rst_n]). [tick] is a combinational function of
    registered state only. *)

open Hardcaml

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; int_ : 'a
    ; frac : 'a
    ; restart : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { tick : 'a } [@@deriving hardcaml]
end

(** Flat instantiation: the logic is inlined into the parent. *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t

(** Hierarchical instantiation: the divider appears as module [clkdiv]. *)
val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
