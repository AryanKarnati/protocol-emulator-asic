module clkdiv_gap_harness (input clk);
  reg started = 1'b0;
  always @(posedge clk) started <= 1'b1;
  wire rst_n = started;
  (* anyseq *) wire restart;
  (* anyconst *) reg [15:0] I;
  (* anyconst *) reg [7:0] F;
  wire tick; wire [24:0] phase;
  clkdiv_dbg dut(.clk(clk),.rst_n(rst_n),.int_(I),.frac(F),.restart(restart),.tick(tick),.phase(phase));
  wire [31:0] dq = (I==0) ? 32'h1000000 : {8'b0, I, F};
  wire [31:0] intv = (I==0) ? 32'd65536 : {16'b0,I};
  always @(*) begin
    assume (!(I==0 && F!=0));
    if (!rst_n) assume(!restart);
  end
  reg seen = 0; reg [31:0] A = 0, B = 0, g = 0;   // g: cycles since last tick/restart
  always @(posedge clk) begin
    if (!rst_n || restart) begin seen<=0; A<=0; B<=0; g<=0; end
    else begin
      A <= A + 256 - (tick ? dq : 0);
      if (tick) begin seen<=1; B <= A + 256 - dq; g <= 0; end else g <= g + 1;
    end
  end
  // gap check
  wire [31:0] gap = g + 1;
  always @(*) if (started) begin
    // DUT phase equals the R10 reference accumulator (reset and restart both give 0)
    assert (phase == A[24:0]);
    assert (A < dq);
    assert (g < 32'h20000); assert (A == B + 256*g);
    assert (seen ? (B < 256) : (B == 0));
    assert (tick == (A + 256 >= dq));
    if (I==1 && F==0) assert (tick);
    if (tick && seen) begin
      assert (gap == intv || gap == intv + 1);
      if (F==0) assert (gap == intv);
    end
    if (!seen && tick) assert (g + 1 <= intv + 1);  // first tick by cycle INT+1 (cycle idx g)
  end
endmodule
