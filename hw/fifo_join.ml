(* The TX and RX FIFOs of one state machine, with FIFO join (datasheet 3.5.3, engine.md
   2 and 3, rules H1, H2 and H6).

   The two FIFOs share one store of 8 words:
   - not joined: TX uses words 0 to 3, RX uses words 4 to 7, each with capacity 4;
   - FJOIN_TX: TX uses all 8 words, capacity 8, and RX has capacity 0;
   - FJOIN_RX: RX uses all 8 words, capacity 8, and TX has capacity 0.
   With capacity 0 a FIFO reads as both full and empty, with level 0.

   Pointers are 3 bits and wrap at the capacity. Words are not reset.

   Per cycle, the start-of-cycle state decides every push and pop:
   - a host TX push into a full FIFO is dropped and [tx_dropped] is high (H1);
   - a host RX pop from an empty FIFO returns 0 and [rx_underflow] is high (H2);
   - [flush] empties both FIFOs at the end of the cycle, and overrides any push in
     that cycle (H6). Pops still return the head of the start-of-cycle state.

   The SM pops TX only when it is not empty, and pushes RX only when it is not full,
   so the SM never presents a pop from an empty FIFO or a push to a full one. *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; join_tx : 'a
    ; join_rx : 'a
    ; flush : 'a
    ; host_tx_push : 'a
    ; host_tx_data : 'a [@bits 32]
    ; sm_tx_pop : 'a
    ; sm_rx_push : 'a
    ; sm_rx_data : 'a [@bits 32]
    ; host_rx_pop : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { tx_head : 'a [@bits 32]
    ; tx_level : 'a [@bits 4]
    ; tx_full : 'a
    ; tx_empty : 'a
    ; tx_dropped : 'a
    ; rx_head : 'a [@bits 32]
    ; rx_level : 'a [@bits 4]
    ; rx_full : 'a
    ; rx_empty : 'a
    ; rx_underflow : 'a
    }
  [@@deriving hardcaml]
end

let create (_scope : Scope.t) (i : _ I.t) =
  let reset_spec =
    Reg_spec.override
      (Reg_spec.create () ~clock:i.clk)
      ~reset:i.rst_n
      ~reset_edge:Edge.Falling
      ~reset_to:(zero 4)
  in
  let spec_ptr = Reg_spec.override reset_spec ~reset_to:(zero 3) in
  (* Capacities. Joining one direction gives the other direction 0 words. Setting both
     bits is outside engine.md, and gives 0 to both (datasheet 3.5.3). *)
  let tx_cap = mux2 i.join_rx (zero 4) (mux2 i.join_tx (of_int ~width:4 8) (of_int ~width:4 4)) -- "tx_cap" in
  let rx_cap = mux2 i.join_tx (zero 4) (mux2 i.join_rx (of_int ~width:4 8) (of_int ~width:4 4)) -- "rx_cap" in
  (* Index of the last word of each FIFO, to wrap the pointers. *)
  let tx_last = mux2 i.join_rx (zero 3) (mux2 i.join_tx (of_int ~width:3 7) (of_int ~width:3 3)) -- "tx_last" in
  let rx_last = mux2 i.join_tx (zero 3) (mux2 i.join_rx (of_int ~width:3 7) (of_int ~width:3 3)) -- "rx_last" in
  (* First word of RX in the store: 0 when RX is joined, otherwise 4. *)
  let rx_base = mux2 i.join_rx (zero 3) (of_int ~width:3 4) -- "rx_base" in
  let wrap p last = mux2 (p ==: last) (zero 3) (p +: one 3) in
  let tx_level = wire 4 in
  let rx_level = wire 4 in
  let tx_wr = wire 3 in
  let tx_rd = wire 3 in
  let rx_wr = wire 3 in
  let rx_rd = wire 3 in
  let tx_full = (tx_level ==: tx_cap) -- "tx_full" in
  let tx_empty = (tx_level ==: zero 4) -- "tx_empty" in
  let rx_full = (rx_level ==: rx_cap) -- "rx_full" in
  let rx_empty = (rx_level ==: zero 4) -- "rx_empty" in
  let tx_dropped = (i.host_tx_push &: tx_full) -- "tx_dropped" in
  let rx_underflow = (i.host_rx_pop &: rx_empty) -- "rx_underflow" in
  (* Accepted operations. A flush overrides the stores (H6). *)
  let tx_store = (i.host_tx_push &: ~:tx_full &: ~:(i.flush)) -- "tx_store" in
  let tx_pop_ok = (i.sm_tx_pop &: ~:tx_empty) -- "tx_pop_ok" in
  let rx_store = (i.sm_rx_push &: ~:rx_full &: ~:(i.flush)) -- "rx_store" in
  let rx_pop_ok = (i.host_rx_pop &: ~:rx_empty) -- "rx_pop_ok" in
  let tx_level_q =
    reg
      (Reg_spec.override reset_spec ~reset_to:(zero 4))
      (mux2
         i.flush
         (zero 4)
         (tx_level +: uresize tx_store 4 -: uresize tx_pop_ok 4))
    -- "tx_level_q"
  in
  tx_level <== tx_level_q;
  let rx_level_q =
    reg
      (Reg_spec.override reset_spec ~reset_to:(zero 4))
      (mux2
         i.flush
         (zero 4)
         (rx_level +: uresize rx_store 4 -: uresize rx_pop_ok 4))
    -- "rx_level_q"
  in
  rx_level <== rx_level_q;
  (* Pointer after a flush (H6), a push or pop, or unchanged. *)
  let next_ptr ~inc ~cur ~last = mux2 i.flush (zero 3) (mux2 inc (wrap cur last) cur) in
  let tx_wr_q =
    reg spec_ptr
      (next_ptr ~inc:tx_store ~cur:tx_wr ~last:tx_last)
    -- "tx_wr_q"
  in
  tx_wr <== tx_wr_q;
  let tx_rd_q =
    reg spec_ptr
      (next_ptr ~inc:tx_pop_ok ~cur:tx_rd ~last:tx_last)
    -- "tx_rd_q"
  in
  tx_rd <== tx_rd_q;
  let rx_wr_q =
    reg spec_ptr
      (next_ptr ~inc:rx_store ~cur:rx_wr ~last:rx_last)
    -- "rx_wr_q"
  in
  rx_wr <== rx_wr_q;
  let rx_rd_q =
    reg spec_ptr
      (next_ptr ~inc:rx_pop_ok ~cur:rx_rd ~last:rx_last)
    -- "rx_rd_q"
  in
  rx_rd <== rx_rd_q;
  (* Physical word indices. *)
  let tx_wr_phys = tx_wr -- "tx_wr_phys" in
  let rx_wr_phys = (rx_wr +: rx_base) -- "rx_wr_phys" in
  let tx_rd_phys = tx_rd -- "tx_rd_phys" in
  let rx_rd_phys = (rx_rd +: rx_base) -- "rx_rd_phys" in
  let tx_sel k = tx_store &: (tx_wr_phys ==: of_int ~width:3 k) in
  let rx_sel k = rx_store &: (rx_wr_phys ==: of_int ~width:3 k) in
  let words =
    List.init 8 (fun k ->
      let en = (tx_sel k |: rx_sel k) -- Printf.sprintf "word_%d_en" k in
      let data = mux2 (tx_sel k) i.host_tx_data i.sm_rx_data in
      reg (Reg_spec.create () ~clock:i.clk) ~enable:en data -- Printf.sprintf "word_%d" k)
  in
  let tx_head = mux tx_rd_phys words -- "tx_head" in
  let rx_head = mux rx_rd_phys words -- "rx_head" in
  { O.tx_head
  ; tx_level = tx_level
  ; tx_full
  ; tx_empty
  ; tx_dropped
  ; rx_head
  ; rx_level = rx_level
  ; rx_full
  ; rx_empty
  ; rx_underflow
  }
;;

module Hier = Hierarchy.In_scope (I) (O)

let hierarchical scope i = Hier.hierarchical ~scope ~name:"fifo_join" create i
