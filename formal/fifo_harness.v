// Formal harness for the block 1 FIFO (fifo_4x32: 4 entries of 32 bits).
//
// Source of the properties: docs/gate.md (FIFO commands) and the contract in hw/fifo.mli.
// The harness reads only the DUT's ports. It does not look inside the DUT.
//
// Tracked token: the accepted push with ordinal tk (counting from 0 since reset) carries
// the fixed value tv. Every other accepted push carries a value different from tv. With
// that, "head equals tv" holds exactly when the token is the head word.

module fifo_harness (input clk);

  // Reset: rst_n is low in the first step only, then high for the rest of the run.
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;

  // Free inputs.
  (* anyseq *) wire push;
  (* anyseq *) wire pop;
  (* anyseq *) wire [31:0] data_in;

  // The tracked token: arbitrary but fixed ordinal and value.
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

  // Accepted pushes and pops since reset, mod 256.
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

  // Input constraints. Commands are idle during reset. The tracked push carries tv,
  // and every other accepted push carries something else.
  always @(*) begin
    if (!rst_n) begin
      assume (!push);
      assume (!pop);
    end
    if (acc_push && npush == tk) assume (data_in == tv);
    if (acc_push && npush != tk) assume (data_in != tv);
  end

  // Properties. Checked from the first step after reset.
  always @(*) begin
    if (started) begin
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

`ifdef TOKEN
      // P4. Tracked token. When the FIFO holds words, the head equals tv exactly when
      //     the head is the token (ordinal tk). This gives order (the token leaves in
      //     its place), no loss (the token is the head when its turn comes) and no
      //     duplication (no other word equals tv).
      if (level != 3'd0) assert ((head == tv) == (npop == tk));
`endif
    end
  end

  // Covers: each property's trigger is reached, so the properties are not vacuous.
  always @(*) begin
    if (started) begin
      cover (full);
      cover (push_dropped);
      cover (pop_empty);
`ifdef TOKEN
      cover (acc_pop && npop == tk);
`endif
      cover (push && pop && full);
      cover (push && pop && empty);
    end
  end

endmodule
