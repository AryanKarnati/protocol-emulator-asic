// Written by the checker (the checker's harness, copied into formal/ unchanged; credited in PROPERTIES.md).
// STATUS: PROVED (checker, k-induction k=2, z3, <1 s, all three join modes, unbounded).
// Fix to the OPEN attempt: two missing invariants, both added in the "Level" block below.
//   (a) level <= capacity (cap_tx / cap_rx; a capacity-0 FIFO stays at level 0);
//   (b) level equals np - nq as an exact 8-bit difference, not only mod 16. With only the
//       4-bit form the induction state may have np - nq = 16 + level, so the ordinals
//       (nq + j) used by the slot check are inconsistent with the queued words. That was the
//       spurious counterexample ("an arbitrary queued word equals tv").
// Needs the debug netlist from tools/add_fifo_join_debug.py (not yet a Makefile target).
// Kill-checks run against it: the six fifo_join__*.sed mutants (the four that touch
// storage, pointers or flush are killed; tx_dropped_without_full and underflow_masked_by_push
// are flag mutants outside this harness), plus rd_wrap_3, rxbase_const4, txlast_const3.
// Attempted unbounded tracked-token proof for fifo_join (engine.md sections 2, 3, 5: H1, H2,
// H6 and the F1 to F4 analogue), by k-induction.
//
// The join mode is fixed for the run by an anyconst: none, TX joined, or RX joined.
// Capacities: TX = 8 with join_tx, 0 with join_rx, otherwise 4. RX is the reverse.
//
// Counters (mod 256): tx_np and rx_np count accepted host TX pushes and accepted SM RX
// pushes. tx_nq and rx_nq count accepted SM TX pops and accepted host RX pops. A flush
// resets all four to 0, as the DUT resets its pointers to 0 on a flush. So the pointers
// stay equal to the counts modulo the capacity, in every mode.
//
// Tracked token: the accepted TX push with ordinal tk carries tv, and every other accepted
// TX push carries a different value. The same for RX. A flush drops queued words, and the
// counters restart, so a token pushed again after a flush is again the token with ordinal tk.
//
// Auxiliary invariants, checked and proved together:
//   - the pointers equal the counts modulo the capacity (TX and RX);
//   - LEVEL is the count difference;
//   - for each queued slot j, the word in that slot is tv exactly when its ordinal is tk;
//   - HEAD is the word at the read pointer, and equals tv exactly when the head is the token.
// Proved with k-induction (fifo_join.sby prove). The debug netlist (tools/add_fifo_join_debug.py)
// exposes the words and pointers. The base netlist is checked by fifo_join_harness.v.

module fifo_join_ind_harness (input clk);

  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;

  (* anyseq *) wire host_tx_push;
  (* anyseq *) wire [31:0] host_tx_data;
  (* anyseq *) wire sm_tx_pop;
  (* anyseq *) wire sm_rx_push;
  (* anyseq *) wire [31:0] sm_rx_data;
  (* anyseq *) wire host_rx_pop;
  (* anyseq *) wire flush;

  (* anyconst *) reg mode_tx;
  (* anyconst *) reg mode_rx;
  (* anyconst *) reg [7:0] tk;
  (* anyconst *) reg [31:0] tv;

  wire join_tx = mode_tx;
  wire join_rx = mode_rx;

  wire [31:0] tx_head, rx_head;
  wire [3:0] tx_level, rx_level;
  wire tx_full, tx_empty, tx_dropped, rx_full, rx_empty, rx_underflow;
  wire [31:0] w0, w1, w2, w3, w4, w5, w6, w7;
  wire [2:0] txrd, txwr, rxrd, rxwr, rxbase;

  fifo_join dut (
    .clk(clk),
    .rst_n(rst_n),
    .join_tx(join_tx),
    .join_rx(join_rx),
    .flush(flush),
    .host_tx_push(host_tx_push),
    .host_tx_data(host_tx_data),
    .sm_tx_pop(sm_tx_pop),
    .sm_rx_push(sm_rx_push),
    .sm_rx_data(sm_rx_data),
    .host_rx_pop(host_rx_pop),
    .tx_head(tx_head),
    .tx_level(tx_level),
    .tx_full(tx_full),
    .tx_empty(tx_empty),
    .tx_dropped(tx_dropped),
    .rx_head(rx_head),
    .rx_level(rx_level),
    .rx_full(rx_full),
    .rx_empty(rx_empty),
    .rx_underflow(rx_underflow),
    .w0(w0), .w1(w1), .w2(w2), .w3(w3), .w4(w4), .w5(w5), .w6(w6), .w7(w7),
    .txrd(txrd), .txwr(txwr), .rxrd(rxrd), .rxwr(rxwr), .rxbase(rxbase)
  );

  wire [3:0] cap_tx = join_tx ? 4'd8 : (join_rx ? 4'd0 : 4'd4);
  wire [3:0] cap_rx = join_rx ? 4'd8 : (join_tx ? 4'd0 : 4'd4);
  wire [2:0] mtx = cap_tx[2:0] - 3'd1;   // valid when cap_tx is 4 or 8
  wire [2:0] mrx = cap_rx[2:0] - 3'd1;

  wire acc_tx_push = rst_n && host_tx_push && !tx_full;
  wire acc_tx_pop = rst_n && sm_tx_pop && !tx_empty;
  wire acc_rx_push = rst_n && sm_rx_push && !rx_full;
  wire acc_rx_pop = rst_n && host_rx_pop && !rx_empty;

  reg [7:0] tx_np = 8'd0, tx_nq = 8'd0, rx_np = 8'd0, rx_nq = 8'd0;

  always @(posedge clk) begin
    if (!rst_n || flush) begin
      tx_np <= 8'd0;
      tx_nq <= 8'd0;
      rx_np <= 8'd0;
      rx_nq <= 8'd0;
    end else begin
      if (acc_tx_push) tx_np <= tx_np + 8'd1;
      if (acc_tx_pop) tx_nq <= tx_nq + 8'd1;
      if (acc_rx_push) rx_np <= rx_np + 8'd1;
      if (acc_rx_pop) rx_nq <= rx_nq + 8'd1;
    end
  end

  // Input constraints.
  always @(*) begin
    assume (!(mode_tx && mode_rx));
    if (!rst_n) begin
      assume (!host_tx_push);
      assume (!sm_tx_pop);
      assume (!sm_rx_push);
      assume (!host_rx_pop);
      assume (!flush);
    end
    // Contract: the SM does not pop an empty TX FIFO, nor push a full RX FIFO.
    if (rst_n) begin
      assume (!sm_tx_pop || !tx_empty);
      assume (!sm_rx_push || !rx_full);
    end
    // The tracked pushes.
    if (acc_tx_push && tx_np == tk) assume (host_tx_data == tv);
    if (acc_tx_push && tx_np != tk) assume (host_tx_data != tv);
    if (acc_rx_push && rx_np == tk) assume (sm_rx_data == tv);
    if (acc_rx_push && rx_np != tk) assume (sm_rx_data != tv);
  end

  function [31:0] wsel(input [2:0] i);
    case (i)
      3'd0: wsel = w0;
      3'd1: wsel = w1;
      3'd2: wsel = w2;
      3'd3: wsel = w3;
      3'd4: wsel = w4;
      3'd5: wsel = w5;
      3'd6: wsel = w6;
      default: wsel = w7;
    endcase
  endfunction

  integer j;
  reg [2:0] p;
  always @(*) begin
    if (started) begin
      // Level never exceeds the capacity (a capacity-0 FIFO stays at 0).
      assert (tx_level <= cap_tx);
      assert (rx_level <= cap_rx);
      // Level is the count difference.
      assert (tx_level == tx_np[3:0] - tx_nq[3:0]);
      assert (rx_level == rx_np[3:0] - rx_nq[3:0]);
      // Exact (8-bit) count difference: the 4-bit form alone lets np - nq be 16 + level.
      assert ({4'b0, tx_level} == tx_np - tx_nq);
      assert ({4'b0, rx_level} == rx_np - rx_nq);

      // Pointers are the counts modulo the capacity (a capacity-0 side has no pointer rule).
      if (cap_tx != 4'd0) begin
        assert (txrd == (tx_nq[2:0] & mtx));
        assert (txwr == (tx_np[2:0] & mtx));
      end
      if (cap_rx != 4'd0) begin
        assert (rxrd == (rx_nq[2:0] & mrx));
        assert (rxwr == (rx_np[2:0] & mrx));
      end

      // TX slots: queued slot j holds tv exactly when its ordinal is tk. TX starts at word 0.
      for (j = 0; j < 8; j = j + 1) begin
        if (j < tx_level) begin
          p = (txrd + j[2:0]) & mtx;
          assert ((wsel(p) == tv) == ((tx_nq + j[7:0]) == tk));
        end
      end
      // RX slots: the RX half starts at rxbase.
      for (j = 0; j < 8; j = j + 1) begin
        if (j < rx_level) begin
          p = rxbase + ((rxrd + j[2:0]) & mrx);
          assert ((wsel(p) == tv) == ((rx_nq + j[7:0]) == tk));
        end
      end

      // Heads: the head is the word at the read pointer, and it is tv exactly when the head
      // is the token (F4 analogue, H2 judged at the start of the cycle).
      if (tx_level != 4'd0) begin
        assert (tx_head == wsel(txrd));
        assert ((tx_head == tv) == (tx_nq == tk));
      end
      if (rx_level != 4'd0) begin
        assert (rx_head == wsel(rxbase + rxrd));
        assert ((rx_head == tv) == (rx_nq == tk));
      end
    end
  end

endmodule
