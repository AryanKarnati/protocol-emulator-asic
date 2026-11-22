// Bounded direct check of D5: after a restart, the tick 256 places after tick m comes exactly
// Dq = 256 INT + FRAC cycles after tick m. Fixed divisor (FIXED_INT, FIXED_FRAC given with -D),
// restart free in every cycle, bounded depth (clkdiv_d5.sby). This is a cross-check of the
// argument in PROPERTIES.md, not an unbounded proof.
//
// Cycle numbering as in clkdiv_harness.v: cc is the cycle whose tick is sampled at the edge.
// tt[m mod 256] holds the cycle of tick m. At tick number nt >= 256, tt[nt mod 256] is the
// tick 256 places earlier, so the difference must equal Dq.

module clkdiv_d5_harness (input clk);

  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;

  (* anyseq *) wire restart;

  wire [15:0] int_ = `FIXED_INT;
  wire [7:0] frac = `FIXED_FRAC;

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

  wire [15:0] dq = {int_[7:0], frac};

  reg [15:0] cc = 16'd0;
  reg [15:0] nt = 16'd0;
  reg [15:0] tt [0:255];

  always @(posedge clk) begin
    if (!rst_n || restart) begin
      cc <= 16'd0;
      nt <= 16'd0;
    end else begin
      cc <= cc + 16'd1;
      if (tick) begin
        tt[nt[7:0]] <= cc;
        nt <= nt + 16'd1;
      end
    end
  end

  always @(*) begin
    if (started && rst_n && !restart && tick && nt >= 16'd256)
      assert (cc - tt[nt[7:0]] == dq);
  end

endmodule
