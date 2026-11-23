// Lemma: the saturating-position monitor (pos, mw, mc) used in pos_harness.v agrees with the
// closed-form monitor of hostlink_harness.v (b, big, phase tests, m = (b - k) >> 5).
module hostlink_harness (input clk);
  reg started = 0;
  always @(posedge clk) started <= 1;
  (* anyseq *) wire rst_n; (* anyseq *) wire sck; (* anyseq *) wire mosi; (* anyseq *) wire cs_n;
  always @(*) if (!started) assume(!rst_n);
  reg sck1 = 0, sck2 = 0, sck3 = 0; reg mo1 = 0, mo2 = 0; reg cs1 = 1, cs2 = 1, cs3 = 1;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin sck1<=0; sck2<=0; sck3<=0; mo1<=0; mo2<=0; cs1<=1; cs2<=1; cs3<=1; end
    else begin sck1<=sck; sck2<=sck1; sck3<=sck2; mo1<=mosi; mo2<=mo1; cs1<=cs_n; cs2<=cs1; cs3<=cs2; end
  wire START = !cs2 && cs3;
  wire END_  = cs2 && !cs3;
  wire RISE  = sck2 && !sck3 && !cs2 && !cs3;
  reg inframe = 0; reg R = 0;
  // closed form
  reg [18:0] b = 0; reg big = 0;
  function ge; input [18:0] bb; input big_in; input [6:0] x; ge = big_in || (bb >= {12'b0, x}); endfunction
  wire ge31 = ge(b, big, 7'd31); wire ge32 = ge(b, big, 7'd32); wire ge55 = ge(b, big, 7'd55);
  wire [13:0] m_w = ((b - 19'd55) >> 5); wire [13:0] m_r = ((b - 19'd31) >> 5); wire [13:0] m_c = ((b - 19'd32) >> 5);
  wire phase_w = ((b - 19'd55) & 19'd31) == 0; wire phase_r = ((b - 19'd31) & 19'd31) == 0; wire phase_c = ((b - 19'd32) & 19'd31) == 0;
  wire in_rise = RISE && inframe;
  wire e_w = rst_n && in_rise && !R && ge55 && phase_w;
  wire e_r = rst_n && in_rise &&  R && ge31 && phase_r;
  wire e_c = rst_n && in_rise &&  R && ge32 && phase_c;
  // position form
  reg [5:0] pos = 0; reg [13:0] mw = 0, mc = 0;
  wire p_w = rst_n && in_rise && !R && pos == 6'd55;
  wire p_r = rst_n && in_rise &&  R && pos == 6'd31;
  wire p_c = rst_n && in_rise &&  R && pos == 6'd32;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin inframe<=0; R<=0; b<=0; big<=0; pos<=0; mw<=0; mc<=0; end
    else begin
      if (START) begin inframe<=1; b<=0; big<=0; pos<=0; mw<=0; mc<=0; end
      else if (END_) inframe<=0;
      else if (RISE) begin
        b <= b + 19'd1; if (b == 19'd55) big <= 1;
        pos <= (pos == 6'd55) ? 6'd24 : pos + 6'd1;
        if (p_w) mw <= mw + 14'd1;
        if (p_c) mc <= mc + 14'd1;
        if (b == 19'd0 && !big) R <= mo2;
      end
    end
  always @(*) if (started) begin
    assert (e_w == p_w); assert (e_r == p_r); assert (e_c == p_c);
    assert (inframe == !cs3);
    if (inframe) begin
      assert (big ? (pos >= 6'd24 && pos <= 6'd55 && pos[4:0] == b[4:0]) : (b <= 19'd55 && pos == b[5:0]));
      if (!big && b == 19'd0) begin assert (mw == 0); assert (mc == 0); end
      else begin
        if (!R) begin assert (mc == 0); assert (mw == ((big || b >= 19'd24) ? ((b - 19'd24) >> 5) : 14'd0)); end
        else    begin assert (mw == 0); assert (mc == ((b - 19'd1) >> 5)); end
      end
    end
    if (e_w) assert (m_w == mw);
    if (e_r) assert (m_r == mc);
    if (e_c) assert (m_c == mc);
  end
endmodule
