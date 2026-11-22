// Written by the checker (the checker's harness, copied into formal/ unchanged; credited in PROPERTIES.md).
// Formal harness for fifo_join (the TX and RX FIFOs of one SM with FIFO join).
//
// Sources: docs/engine.md section 2 (capacities), section 3 (fifo_join ports and the
// capacity-0 rule), section 5 rules H1, H2 and H6, and hw/fifo_join.mli. The harness reads
// only the DUT's ports and does not look inside the DUT.
//
// Capacities: not joined, TX 4 and RX 4. join_tx: TX 8, RX 0. join_rx: TX 0, RX 8.
// A capacity-0 FIFO reads as full and empty with level 0.
//
// One anyconst picks the join mode for the whole run. The mode is one of: none, TX joined,
// RX joined (both at once is outside the contract).
//
// Counters (mod 256): tx_np and tx_nq count accepted host pushes and accepted SM pops of
// the TX FIFO; rx_np and rx_nq count accepted SM pushes and accepted host pops of RX. A
// flush sets the pop counter to the push counter, which empties the FIFO and drops any
// tracked token still in it. So the tracked-token checks stay valid across flushes.
//
// TOKEN defines the tracked-token properties, which are not 1-inductive and are checked by
// bounded model checking (see fifo_join.sby). The rest is checked by k-induction.

module fifo_join_harness (input clk);

  // Reset: rst_n is low in the first step only, then high for the rest of the run.
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  (* anyseq *) wire rst_req;
  wire rst_n = started && !rst_req;

  (* anyseq *) wire host_tx_push;
  (* anyseq *) wire [31:0] host_tx_data;
  (* anyseq *) wire sm_tx_pop;
  (* anyseq *) wire sm_rx_push;
  (* anyseq *) wire [31:0] sm_rx_data;
  (* anyseq *) wire host_rx_pop;
  (* anyseq *) wire flush;

  // The join mode, fixed for the run. join_tx and join_rx are never both 1.
  (* anyconst *) reg mode_tx;
  (* anyconst *) reg mode_rx;

  // The tracked token: ordinal tk and value tv, in the TX FIFO (host pushes) or RX (SM pushes).
  (* anyconst *) reg [7:0] tk;
  (* anyconst *) reg [31:0] tv;

  wire join_tx = mode_tx;
  wire join_rx = mode_rx;

  wire [31:0] tx_head;
  wire [3:0] tx_level;
  wire tx_full;
  wire tx_empty;
  wire tx_dropped;
  wire [31:0] rx_head;
  wire [3:0] rx_level;
  wire rx_full;
  wire rx_empty;
  wire rx_underflow;

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
    .rx_underflow(rx_underflow)
  );

  // Capacities by mode (engine.md section 2 and 3).
  wire [3:0] tx_cap = join_tx ? 4'd8 : (join_rx ? 4'd0 : 4'd4);
  wire [3:0] rx_cap = join_rx ? 4'd8 : (join_tx ? 4'd0 : 4'd4);

  // Accepted operations. A host TX push is dropped when the FIFO is full at the start of
  // the cycle (H1). A host RX pop is refused when the FIFO is empty at the start (H2).
  wire acc_tx_push = rst_n && host_tx_push && !tx_full;
  wire acc_tx_pop = rst_n && sm_tx_pop && !tx_empty;
  wire acc_rx_push = rst_n && sm_rx_push && !rx_full;
  wire acc_rx_pop = rst_n && host_rx_pop && !rx_empty;

  reg [7:0] tx_np = 8'd0;
  reg [7:0] tx_nq = 8'd0;
  reg [7:0] rx_np = 8'd0;
  reg [7:0] rx_nq = 8'd0;
  reg flush_prev = 1'b0;

  wire [7:0] tx_np_next = tx_np + {7'd0, acc_tx_push};
  wire [7:0] rx_np_next = rx_np + {7'd0, acc_rx_push};

  always @(posedge clk) begin
    flush_prev <= rst_n && flush;
    if (!rst_n) begin
      tx_np <= 8'd0;
      tx_nq <= 8'd0;
      rx_np <= 8'd0;
      rx_nq <= 8'd0;
    end else begin
      tx_np <= tx_np_next;
      rx_np <= rx_np_next;
      // A flush empties the FIFO, so the pop count catches up with the push count.
      tx_nq <= flush ? tx_np_next : tx_nq + {7'd0, acc_tx_pop};
      rx_nq <= flush ? rx_np_next : rx_nq + {7'd0, acc_rx_pop};
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
`ifdef TOKEN
    // The tracked TX push (ordinal tk) carries tv; other accepted TX pushes do not.
    if (acc_tx_push && tx_np == tk) assume (host_tx_data == tv);
    if (acc_tx_push && tx_np != tk) assume (host_tx_data != tv);
    // The same for RX, on SM pushes.
    if (acc_rx_push && rx_np == tk) assume (sm_rx_data == tv);
    if (acc_rx_push && rx_np != tk) assume (sm_rx_data != tv);
`endif
  end

  // R1 (outside the gate below): while rst_n is low both FIFOs read empty, level 0.
  always @(*) if (!rst_n) assert (tx_level == 4'd0 && rx_level == 4'd0 && tx_empty && rx_empty);

  // Properties. Checked while rst_n is high (the counters reset at the edge, the DUT at once).
  always @(*) begin
    if (started && rst_n) begin
      // P1. Each LEVEL is the accepted pushes minus the accepted pops since the last flush
      //     (the counters are exact: LEVEL is at most 8 and they are compared mod 16).
      assert (tx_level == tx_np[3:0] - tx_nq[3:0]);
      assert (rx_level == rx_np[3:0] - rx_nq[3:0]);

      // P2. FULL and EMPTY follow from LEVEL and the capacity. A capacity-0 FIFO is full
      //     and empty with LEVEL 0.
      assert (tx_full == (tx_level == tx_cap));
      assert (tx_empty == (tx_level == 4'd0));
      assert (rx_full == (rx_level == rx_cap));
      assert (rx_empty == (rx_level == 4'd0));
      if (tx_cap == 4'd0) assert (tx_full && tx_empty && tx_level == 4'd0);
      if (rx_cap == 4'd0) assert (rx_full && rx_empty && rx_level == 4'd0);

      // P3. H1 and H2: a host TX push into a full FIFO is reported, and a host RX pop from
      //     an empty FIFO is reported, in the cycle they are sampled.
      assert (tx_dropped == (host_tx_push && tx_full));
      assert (rx_underflow == (host_rx_pop && rx_empty));

      // P4. H6: after a flush both FIFOs are empty.
      if (flush_prev) assert (tx_level == 4'd0 && rx_level == 4'd0);
    end
  end

`ifdef TOKEN
  // P5. TX token (F1 to F4 analogue, host pushes, SM pops). When the TX FIFO holds words,
  //     its head equals tv exactly when the head is the token (ordinal tk). So the token
  //     leaves in order, is not lost, and is not duplicated.
  // P6. The same for RX, with SM pushes and host pops. The head is read at the start of
  //     the cycle (H2).
  always @(*) begin
    if (started) begin
      if (tx_level != 4'd0) assert ((tx_head == tv) == (tx_nq == tk));
      if (rx_level != 4'd0) assert ((rx_head == tv) == (rx_nq == tk));
    end
  end
`endif

  // Covers: each trigger is reached, so the properties are not vacuous.
  always @(*) begin
    if (started) begin
      cover (join_tx);
      cover (join_rx);
      cover (!join_tx && !join_rx);
      cover (tx_dropped);
      cover (rx_underflow);
      cover (host_tx_push && tx_full && sm_tx_pop);
      cover (host_rx_pop && rx_empty && sm_rx_push);
      cover (flush && tx_level != 4'd0);
      cover (flush && rx_level != 4'd0);
`ifdef TOKEN
      cover (acc_tx_pop && tx_nq == tk);
      cover (acc_rx_pop && rx_nq == tk);
`endif
    end
  end

endmodule
