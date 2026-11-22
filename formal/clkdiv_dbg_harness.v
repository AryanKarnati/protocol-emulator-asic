// Unbounded proof of the divider against the reference accumulator in engine.md R10.
// Used for both netlists: the block 2 divider (clkdiv_dbg, from formal/gen) and the block 1
// divider in debug form (clkdiv, with a phase output added by tools/add_clkdiv_debug.py).
//
// Source: docs/engine.md R10 alone. D = 256*INT + FRAC, with INT = 0 meaning 65536.
// Each cycle: S = P + 256; tick = (S >= D); P becomes S - D on a tick, otherwise S.
// P resets to 0, and a restart sets it to 0 at the end of the cycle (H4). The divider runs
// whether or not the SM is enabled.
//
// INT, FRAC, restart and reset are free in every cycle, so every divisor, every change of
// divisor in the middle of a run, every restart pattern and every reset in the middle of a
// run is covered. The only input constraint is the contract's exclusion (INT = 0 with
// FRAC != 0).
//
// Checked (k-induction, k = 1, unbounded):
//   - while rst_n is low: the phase is 0 and TICK is (256 >= D), the reset state;
//   - in every cycle with rst_n high: dbg_phase == P_ref and tick == tick_ref.
// The invariant is phase equality. It is inductive by itself, since both registers see the
// same inputs and the same update rule. The properties D1 to D5 and the gap properties are
// consequences of this equality (PROPERTIES.md), not separate checks here.

module clkdiv_dbg_harness (input clk);

  // Reset: low in the first step, and again whenever rst_req is high (a mid-run reset).
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  (* anyseq *) wire rst_req;
  wire rst_n = started && !rst_req;

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

  // Reset state: while rst_n is low, the phase is 0 and TICK is 1 iff 256 >= D (the reset
  // phase is 0, so the first cycle's tick is (0 + 256 >= D)).
  always @(*) begin
    if (!rst_n) begin
      assert (phase == 25'd0);
      assert (tick == (25'd256 >= D));
    end
  end

  // The invariant: DUT phase and tick equal the reference, in every cycle with rst_n high.
  always @(*) begin
    if (started && rst_n) begin
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
      cover (rst_n && phase > D);
      cover (!rst_n && P_ref != 25'd0);
    end
  end

endmodule
