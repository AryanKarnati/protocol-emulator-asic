module clkdiv_d1_harness (input clk);
  reg started = 0; always @(posedge clk) started <= 1; wire rst_n = started;
  (* anyseq *) wire restart; (* anyseq *) wire [15:0] I; (* anyseq *) wire [7:0] F;
  wire tick; wire [24:0] phase;
  clkdiv_dbg dut(.clk(clk),.rst_n(rst_n),.int_(I),.frac(F),.restart(restart),.tick(tick),.phase(phase));
  always @(*) begin assume(!(I==0 && F!=0)); if (!rst_n) assume(!restart); end
  always @(*) if (started) begin
    assert (phase < 25'h1000000);
    if (I==1 && F==0) assert (tick);   // any history, any restart pattern, any prior divisor
  end
endmodule
