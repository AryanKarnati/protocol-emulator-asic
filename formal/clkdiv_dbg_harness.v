// Unbounded proof of the block 2 divider against a reference accumulator (engine.md R10).
//
// Source: docs/engine.md R10 alone. D = 256*INT + FRAC, with INT = 0 meaning 65536.
// Each cycle: S = P + 256; tick = (S >= D); P becomes S - D on a tick, otherwise S.
// P resets to 0, and a restart sets it to 0 at the end of the cycle (H4). The divider runs
// whether or not the SM is enabled. The harness does not look inside clkdiv_dbg.
//
// INT, FRAC, restart and reset are free in every cycle, so every divisor and every
// restart pattern is covered. The only input constraint is the contract's exclusion
// (INT = 0 with FRAC != 0).
//
// The invariant is phase equality: dbg_phase == P_ref. It is inductive by itself (both
// registers see the same inputs and the same update rule), so k-induction with k = 1
// proves it for all reachable and unreachable states, which means unboundedly.

module clkdiv_dbg_harness (input clk);

  // Reset: rst_n is low in the first step only, then high for the rest of the run.
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;

  (* anyseq *) wire [15:0] int_;
  (* anyseq *) wire [7:0] frac;
  (* anyseq *) wire restart;

  wire tick;
  wire [24:0] phase;

  clkdiv_dbg dut (
    .clk(clk),
    .rst_n(rst_n),
    .int_(int_),
    .frac(frac),
    .restart(restart),
    .tick(tick),
    .phase(phase)
  );

  // Contract: INT = 0 with FRAC != 0 is outside the contract.
  always @(*) begin
    if (int_ == 16'd0) assume (frac == 8'd0);
  end

  // Reference accumulator from R10.
  wire [24:0] D = (int_ == 16'd0) ? 25'h1000000 : {1'b0, int_, frac};
  reg [24:0] P_ref = 25'd0;
  wire [24:0] S_ref = P_ref + 25'd256;
  wire tick_ref = (S_ref >= D);

  always @(posedge clk) begin
    if (!rst_n || restart) P_ref <= 25'd0;
    else P_ref <= tick_ref ? (S_ref - D) : S_ref;
  end

  // The invariant: DUT phase and tick equal the reference, in every cycle after reset.
  always @(*) begin
    if (started) begin
      assert (phase == P_ref);
      assert (tick == tick_ref);
    end
  end

  // Covers (cover mode only): the update rules are all exercised.
  always @(*) begin
    if (started) begin
      cover (tick);
      cover (!tick);
      cover (restart && P_ref != 25'd0);
      cover (int_ == 16'd0);
      // The divisor was lowered without a restart, so the phase is above it (clkdiv.mli).
      cover (phase > D);
    end
  end

endmodule
