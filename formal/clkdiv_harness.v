// Formal harness for the block 1 clock divider (clkdiv: 16.8 fractional enable).
//
// Source of the properties: docs/gate.md ("Clock divider behaviour", properties 1 to 3)
// and DESIGN.md section 17. The harness reads only the DUT's ports. It does not look
// inside the DUT.
//
// Divisor: D = INT + FRAC/256, so Dq = 256*INT + FRAC. INT and FRAC are arbitrary but
// fixed for the whole run. INT is bounded to 1..BMAX (INT = 0 means 65536 and is not
// checked here). This bound is a limit of the bounded check, not part of the spec.
//
// Cycle numbering: cycle 0 is the cycle just after the restart edge. Counters:
//   cc    = index of the cycle whose tick is sampled at the next rising edge;
//   ntick = number of ticks in cycles 0 .. cc-1 since the last restart.
//
// Closed form (K1). Restart sets the divider phase to 0. Let N be the number of ticks
// since the last restart, and A = 256*c - Dq*N in cycle c. Then 0 <= A < Dq, and
// tick = 1 iff A + 256 >= Dq. Equivalently N = floor(256*c / Dq). The harness keeps A as a
// reference register (additions and comparisons only). K1 is checked on every cycle.
// It is stronger than the spec, which only bounds the first tick (C2). The spec
// properties D2 to D5 follow from K1 by arithmetic. D2 to D4 are also checked directly on
// the observed ticks.

module clkdiv_harness (input clk);

  localparam BMAX = 2;

  // Reset: rst_n is low in the first step only, then high for the rest of the run.
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;

  (* anyseq *) wire restart;

  // Arbitrary but fixed divisor. A run can pin it with -DFIXED_INT=n -DFIXED_FRAC=f
  // (constant divisor, much faster for the solver, one divisor per run).
`ifdef FIXED_INT
  wire [15:0] H_INT = `FIXED_INT;
  wire [7:0] H_FRAC = `FIXED_FRAC;
`else
  (* anyconst *) reg [15:0] H_INT;
  (* anyconst *) reg [7:0] H_FRAC;
`endif

  wire tick;

  clkdiv dut (
    .clk(clk),
    .rst_n(rst_n),
    .int_(H_INT),
    .frac(H_FRAC),
    .restart(restart),
    .tick(tick)
  );

  // Dq = 256*INT + FRAC.
  wire [15:0] dq = {H_INT[7:0], H_FRAC};

  // Monitor state. Reset counts as a restart at cycle 0 (the DUT's reset phase is 0).
  reg seen = 1'b0;            // a tick has come since the last restart
  reg [15:0] cc = 16'd0;      // index of the cycle whose tick is sampled at the next edge
  reg [15:0] last = 16'd0;    // cycle of the most recent tick since the last restart
  reg [15:0] ntick = 16'd0;   // ticks since the last restart
  reg [15:0] A = 16'd0;       // reference phase: 256*c - Dq*ntick

  always @(posedge clk) begin
    if (!rst_n || restart) begin
      seen <= 1'b0;
      cc <= 16'd0;
      ntick <= 16'd0;
      A <= 16'd0;
    end else begin
      cc <= cc + 16'd1;
      A <= A + 16'd256 - (tick ? dq : 16'd0);
      if (tick) begin
        seen <= 1'b1;
        last <= cc;
        ntick <= ntick + 16'd1;
      end
    end
  end

  // Input constraints.
  always @(*) begin
    assume (H_INT >= 16'd1 && H_INT <= BMAX);
    if (!rst_n) assume (!restart);
  end

  // Properties, checked at each rising edge for the cycle that edge ends.
  always @(posedge clk) begin
    if (started) begin
      // D1. INT = 1 and FRAC = 0: TICK is 1 in every cycle.
      if (H_INT == 16'd1 && H_FRAC == 8'd0) assert (tick);

      // K1. Closed form of the tick schedule from the last restart (see header).
      assert (tick == (A + 16'd256 >= dq));
      assert (A < dq);

      // D2. The first tick after a restart comes at cycle INT + 1 or earlier.
      if (!seen && cc == H_INT + 16'd1) assert (tick);

      if (tick && seen) begin
        // D3. Gap between consecutive ticks is INT or INT + 1.
        assert (cc - last == H_INT || cc - last == H_INT + 16'd1);
        // D4. With FRAC = 0, every gap is exactly INT.
        if (H_FRAC == 8'd0) assert (cc - last == H_INT);
      end
    end
  end

  // Covers: the triggers are reached, so the properties are not vacuous. Each cover
  // is only reachable for some divisors, so a fixed-divisor run selects its covers:
  // COVER_NONZERO (FRAC != 0 only), COVER_ZERO (FRAC = 0 only), COVER_WINDOW (256 ticks,
  // needs about 256 x D cycles). The restart cover is always on.
  always @(posedge clk) begin
    if (started) begin
`ifdef COVER_NONZERO
      cover (rst_n && !restart && tick && seen && H_FRAC != 8'd0
             && cc - last == H_INT + 16'd1);
      // The first tick at cycle INT (the latest the closed form allows for FRAC != 0).
      cover (rst_n && !restart && !seen && cc == H_INT && tick && H_FRAC != 8'd0);
`endif
`ifdef COVER_ZERO
      cover (rst_n && !restart && tick && seen && H_FRAC == 8'd0);
`endif
`ifdef COVER_WINDOW
      cover (rst_n && !restart && tick && ntick >= 16'd256);
`endif
      cover (rst_n && restart && ntick > 16'd0);
    end
  end

endmodule
