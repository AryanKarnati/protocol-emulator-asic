(** The TX and RX FIFOs of one state machine, with FIFO join (datasheet 3.5.3; engine.md
    sections 2, 3 and rules H1, H2, H6).

    One store of 8 words is shared. Not joined: TX has words 0 to 3 and RX words 4 to 7,
    each of capacity 4. [join_tx]: TX has capacity 8 and RX capacity 0. [join_rx]: the
    reverse. A capacity-0 FIFO reads as full and empty, with level 0.

    Host push and host pop are judged against the start-of-cycle state:
    - [host_tx_push] into a full TX FIFO is dropped, and [tx_dropped] is high (TXOVER);
    - [host_rx_pop] from an empty RX FIFO leaves [rx_head] as it is, and [rx_underflow]
      is high (RXUNDER). The caller gates [rx_head] with [rx_empty].

    The SM must not present [sm_tx_pop] on an empty TX FIFO, nor [sm_rx_push] on a full
    RX FIFO. [flush] empties both FIFOs at the end of the cycle and overrides pushes in
    that cycle. Pops still return the start-of-cycle head.

    Reset is asynchronous and active low. Storage is not reset. *)

open Hardcaml

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; join_tx : 'a
    ; join_rx : 'a
    ; flush : 'a
    ; host_tx_push : 'a
    ; host_tx_data : 'a
    ; sm_tx_pop : 'a
    ; sm_rx_push : 'a
    ; sm_rx_data : 'a
    ; host_rx_pop : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { tx_head : 'a
    ; tx_level : 'a
    ; tx_full : 'a
    ; tx_empty : 'a
    ; tx_dropped : 'a
    ; rx_head : 'a
    ; rx_level : 'a
    ; rx_full : 'a
    ; rx_empty : 'a
    ; rx_underflow : 'a
    }
  [@@deriving hardcaml]
end

(** Flat instantiation: the logic is inlined into the parent. *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t

(** Hierarchical instantiation: the FIFO pair appears as module [fifo_join]. *)
val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
