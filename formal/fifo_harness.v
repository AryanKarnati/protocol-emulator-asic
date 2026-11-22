// Formal harness for the block 1 FIFO (fifo_4x32: 4 entries of 32 bits).
//
// Source of the properties: docs/gate.md (FIFO commands) and the contract in hw/fifo.mli.
// The harness reads only the DUT's ports. It does not look inside the DUT.
//
// Checked here, by k-induction (fifo.sby flags_prove):
//   P1 LEVEL, P2 FULL and EMPTY, P3 the overflow and underflow pulses, and
//   R1 the reset state, while rst_n is low, including a reset in the middle of a run.
// The tracked-token property (order, no loss, no duplication) is in fifo_ind_harness.v,
// which needs the debug netlist. The TOKEN define here only adds its cover (fifo.sby).

module fifo_harness (input clk);

  // Reset: low in the first step, and again whenever rst_req is high (a mid-run reset).
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  (* anyseq *) wire rst_req;
  wire rst_n = started && !rst_req;

  // Free inputs.
  (* anyseq *) wire push;
  (* anyseq *) wire pop;
  (* anyseq *) wire [31:0] data_in;

  // The tracked token (TOKEN cover only): arbitrary but fixed ordinal and value.
  (* anyconst *) reg [7:0] tk;
  (* anyconst *) reg [31:0] tv;

  wire [31:0] head;
  wire [2:0] level;
  wire full;
  wire empty;
  wire push_dropped;
  wire pop_empty;

  fifo_4x32 dut (
    .data_in(data_in),
    .push(push),
    .pop(pop),
    .rst_n(rst_n),
    .clk(clk),
    .head(head),
    .level(level),
    .full(full),
    .empty(empty),
    .push_dropped(push_dropped),
    .pop_empty(pop_empty)
  );

  // Accepted operations, from the contract: a push succeeds iff the FIFO was not full
  // before the edge, and a pop succeeds iff it was not empty before the edge.
  wire acc_push = rst_n && push && !full;
  wire acc_pop = rst_n && pop && !empty;

  // Whether the FIFO held words in the previous cycle with rst_n high (for the cover).
  reg had_words = 1'b0;
  always @(posedge clk) had_words <= rst_n && (level != 3'd0);

  // Accepted pushes and pops since the last reset, mod 256.
  reg [7:0] npush = 8'd0;
  reg [7:0] npop = 8'd0;
  always @(posedge clk) begin
    if (!rst_n) begin
      npush <= 8'd0;
      npop <= 8'd0;
    end else begin
      if (acc_push) npush <= npush + 8'd1;
      if (acc_pop) npop <= npop + 8'd1;
    end
  end

  // Input constraints. Commands are idle during reset.
  always @(*) begin
    if (!rst_n) begin
      assume (!push);
      assume (!pop);
    end
  end

  // Reset state (R1). While rst_n is low, the outputs show the reset state.
  always @(*) begin
    if (!rst_n) begin
      assert (level == 3'd0);
      assert (empty);
      assert (!full);
    end
  end

  // Properties, from the first step after reset, and in every cycle with rst_n high.
  always @(*) begin
    if (started && rst_n) begin
      // P1. LEVEL is the number of accepted pushes minus accepted pops (the count is
      //     exact, since LEVEL is 0 to 4 and the counts are compared mod 8).
      assert (level == npush[2:0] - npop[2:0]);

      // P2. FULL and EMPTY follow from LEVEL.
      assert (full == (level == 3'd4));
      assert (empty == (level == 3'd0));

      // P3. Overflow and underflow pulses: a push into a full FIFO, and a pop from an
      //     empty FIFO, are reported in the cycle they are sampled.
      assert (push_dropped == (push && full));
      assert (pop_empty == (pop && empty));
    end
  end

  // Covers: each trigger is reached, so the properties are not vacuous.
  always @(*) begin
    if (started) begin
      cover (full);
      cover (push_dropped);
      cover (pop_empty);
      cover (push && pop && full);
      cover (push && pop && empty);
      // A reset with words in the FIFO: LEVEL reads 0 during reset, so use the previous cycle.
      cover (!rst_n && started && had_words);
`ifdef TOKEN
      cover (acc_pop && npop == tk);
`endif
    end
  end

endmodule
