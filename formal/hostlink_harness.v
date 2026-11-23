// Host-link properties (DESIGN section 17, docs/chip.md sections 5 to 7), checked on the
// generated `hostlink` module (`gen_verilog hostlink`).
//
// Written from docs/chip.md only. The RTL was not read for this harness. The harness holds a
// reference monitor that follows chip.md 6.1 to 6.5 cycle by cycle: the synchronisers, the
// events, the bit numbering, the frame layout, the bus pulses and the MISO shift register.
// Every output of the DUT is compared with the monitor in every cycle after reset.
//
// Ports only: the harness reads the DUT's ports and nothing else.
//
// Conventions from chip.md:
//   - cycle 0 is the first cycle after reset; before it the synchronisers hold the idle values
//     (SCK 0, MOSI 0, CS_N 1);
//   - s1 takes the pin, s2 takes s1, s3 takes s2, so in cycle t, sck2 = SCK(t-2), sck3 = SCK(t-3);
//   - a bit delivered by a RISE is mosi2, and the RISE of bit b is the (b)th RISE of its frame,
//     numbered from 0.
//
// Modelling choices, each one a disclosed limit (PROPERTIES.md, "Host link"):
//   - The bit counter is 19 bits. A frame longer than 2^19 bits wraps it. The wrap is invisible
//     to every property because the word index m only enters through m mod 2^14 (addr_m is mod
//     2^16 and 4m has bit 0 and 1 clear) and the word phase only through b mod 32. The sticky
//     flag `big` keeps the "at least 56 bits in this frame" comparisons right after a wrap.
//   - Reset (chip.md 7, C2 resolved): while rst_n is low every flop holds its reset value, so
//     miso is 0 and there are no bus pulses. The monitor is reset the same way.
//   - MISO is compared with the shift register of chip.md 6.5. Two properties: (a) the exact
//     rule, unconditional; (b) the hold rule for a counted rise, under the host obligations of
//     chip.md 6.6 (H-SCK, H-CS, H-RST), stated in the MISO section. With MISO_UNCOND (b) is
//     checked without those obligations and is expected to fail (miso_uncond task).

module hostlink_harness (input clk);

  // Cycle 0 is the first cycle of the formal run. Outputs are checked from cycle 1 on.
  reg started = 0;
  always @(posedge clk) started <= 1;

  // Free inputs: every pin, the status byte and the read data.
  (* anyseq *) wire rst_n;
  (* anyseq *) wire sck;
  (* anyseq *) wire mosi;
  (* anyseq *) wire cs_n;
  (* anyseq *) wire [7:0] status;
  (* anyseq *) wire [31:0] rdata;

  // DUT outputs.
  wire miso, bus_write, bus_read, bus_commit;
  wire [15:0] bus_addr;
  wire [31:0] bus_wdata;

  hostlink dut (
    .clock(clk), .rst_n(rst_n), .sck(sck), .mosi(mosi), .cs_n(cs_n),
    .status(status), .rdata(rdata),
    .miso(miso), .bus_write(bus_write), .bus_read(bus_read), .bus_commit(bus_commit),
    .bus_addr(bus_addr), .bus_wdata(bus_wdata));

  // Reset at cycle 0: the first cycle is in reset, so the step case starts from reset.
  always @(*) if (!started) assume(!rst_n);

  // ---------------------------------------------------------------------------
  // 6.1 Synchronisers (reference monitor). Idle: SCK 0, MOSI 0, CS_N 1.
  // ---------------------------------------------------------------------------
  reg sck1 = 0, sck2 = 0, sck3 = 0;
  reg mo1 = 0, mo2 = 0, mo3 = 0;
  reg cs1 = 1, cs2 = 1, cs3 = 1;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      sck1 <= 0; sck2 <= 0; sck3 <= 0;
      mo1 <= 0;  mo2 <= 0;  mo3 <= 0;
      cs1 <= 1;  cs2 <= 1;  cs3 <= 1;
    end else begin
      sck1 <= sck;  sck2 <= sck1;  sck3 <= sck2;
      mo1 <= mosi;  mo2 <= mo1;    mo3 <= mo2;
      cs1 <= cs_n;  cs2 <= cs1;    cs3 <= cs2;
    end

  // ---------------------------------------------------------------------------
  // 6.2 Events
  // ---------------------------------------------------------------------------
  wire START = !cs2 && cs3;                       // cs_n2 = 0, cs_n3 = 1
  wire END_  = cs2 && !cs3;                       // cs_n2 = 1, cs_n3 = 0
  wire RISE  = sck2 && !sck3 && !cs2 && !cs3;     // the bit delivered is mo2

  // ---------------------------------------------------------------------------
  // 6.3 Frame state
  // ---------------------------------------------------------------------------
  reg inframe = 0;
  reg [18:0] b = 0;          // bit number of the next RISE in the frame (wraps, see above)
  reg big = 0;               // set after the RISE of bit 55: at least 56 bits in this frame
  reg R = 0, F = 0;          // command bits: bit 0 (R) and bit 1 (F)
  reg [15:0] adr = 0;        // ADDR[15:0], bits 8 to 23
  reg [31:0] rx = 0;         // the last 32 delivered bits, MSB first
  reg [31:0] sr = 0;         // MISO shift register (6.5); MISO = sr[31]

  // Shift in the bit of this RISE. Only meaningful at a RISE.
  wire [31:0] rx_new = {rx[30:0], mo2};

  // "bit number >= x" in this frame, for x <= 56.
  function ge;
    input [18:0] bb;
    input big_in;
    input [6:0] x;
    ge = big_in || (bb >= {12'b0, x});
  endfunction

  wire ge31 = ge(b, big, 7'd31);
  wire ge32 = ge(b, big, 7'd32);
  wire ge55 = ge(b, big, 7'd55);

  // Word index of each access, mod 2^14, and the word phase test.
  wire [13:0] m_w = ((b - 19'd55) >> 5);   // write words: bit 55 + 32m
  wire [13:0] m_r = ((b - 19'd31) >> 5);   // read words:  bit 31 + 32m
  wire [13:0] m_c = ((b - 19'd32) >> 5);   // commit:      bit 32 + 32m

  wire phase_w = ((b - 19'd55) & 19'd31) == 0;
  wire phase_r = ((b - 19'd31) & 19'd31) == 0;
  wire phase_c = ((b - 19'd32) & 19'd31) == 0;

  // addr_m (6.3): ADDR when F = 1, else ADDR + 4m. Bits [1:0] cleared.
  function [15:0] addr_of;
    input f;
    input [15:0] a;
    input [13:0] m;
    reg [15:0] t;
    begin
      t = f ? a : (a + {m, 2'b00});
      addr_of = t & 16'hFFFC;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // 6.4 Bus accesses (expected), gated by reset
  // ---------------------------------------------------------------------------
  wire in_rise = RISE && inframe;
  wire e_w = rst_n && in_rise && !R && ge55 && phase_w;     // write word m
  wire e_r = rst_n && in_rise &&  R && ge31 && phase_r;     // read word m
  wire e_c = rst_n && in_rise &&  R && ge32 && phase_c;     // commit of word m

  wire [15:0] ea_w = addr_of(F, adr, m_w);
  wire [15:0] ea_r = addr_of(F, adr, m_r);
  wire [15:0] ea_c = addr_of(F, adr, m_c);

  wire [31:0] e_wdata = rx_new;   // word m: the 31 earlier bits and this cycle's bit

  // ---------------------------------------------------------------------------
  // Monitor state update
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      inframe <= 0; b <= 0; big <= 0; R <= 0; F <= 0; adr <= 0; rx <= 0; sr <= 0;
    end else begin
      if (START) begin
        inframe <= 1; b <= 0; big <= 0;
        sr <= {status, 24'b0};
      end else if (END_) begin
        inframe <= 0;
        sr <= 0;
      end else if (RISE) begin
        // Bit b of the frame is mo2.
        rx <= rx_new;
        b <= b + 19'd1;
        if (b == 19'd55) big <= 1;
        if (b == 19'd0) R <= mo2;
        if (b == 19'd1) F <= mo2;
        if (b == 19'd23) adr <= rx_new[15:0];
        // 6.5: a read access loads the read value, any other RISE shifts left.
        if (e_r) sr <= rdata;
        else     sr <= {sr[30:0], 1'b0};
      end
    end

  // ---------------------------------------------------------------------------
  // Checks. Every output is compared with the monitor in every cycle from cycle 1.
  // ---------------------------------------------------------------------------
  always @(*) if (started) begin
    // Reset: the link is idle.
    if (!rst_n) begin
      assert (miso == 1'b0);
      assert (bus_write == 1'b0);
      assert (bus_read == 1'b0);
      assert (bus_commit == 1'b0);
    end

    // 6.5 MISO, every cycle.
    assert (miso == (rst_n ? sr[31] : 1'b0));

    // 6.5 MISO is 0 between frames.
    if (rst_n && !inframe) assert (miso == 1'b0);

    // 6.4 bus pulses, every cycle.
    assert (bus_write  == e_w);
    assert (bus_read   == e_r);
    assert (bus_commit == e_c);

    // At most one pulse per cycle.
    assert ((bus_write + bus_read + bus_commit) <= 1);

    // Address and data, in the cycles that have a pulse.
    if (e_w) begin
      assert (bus_addr == ea_w);
      assert (bus_wdata == e_wdata);
      assert (bus_addr[1:0] == 2'b00);
    end
    if (e_r) begin
      assert (bus_addr == ea_r);
      assert (bus_addr[1:0] == 2'b00);
    end
    if (e_c) begin
      assert (bus_addr == ea_c);
      assert (bus_addr[1:0] == 2'b00);
    end

    // No write without a complete word inside one frame: a write pulse needs the frame and
    // the 32 bits of the word, which is what e_w encodes.
    if (bus_write) begin
      assert (inframe);
      assert (!R);
    end
  end

  // ---------------------------------------------------------------------------
  // 6.5 MISO. Two properties, as chip.md 6.5 now states them.
  //
  // (a) Exact rule, unconditional. MISO changes only in the cycle right after a START, RISE or
  //     END, and reset clears it. Stated as: if MISO(t) differs from MISO(t-1), then an event
  //     happened in cycle t-1, or rst_n is low in cycle t or t-1.
  //
  // (b) Hold rule, under the host obligations of chip.md 6.6. For a counted rise of SCK in pin
  //     cycle c (SCK(c) = 1, SCK(c-1) = 0, CS_N(c-1) = CS_N(c) = 0), MISO is constant over
  //     cycles c, c+1, c+2 when the host has followed 6.6 around the rise:
  //       - H-SCK: SCK(c-2) = 0 (the low phase is at least 2 cycles);
  //       - H-CS: CS_N does not change in cycles c-2 or c-1 (a CS_N fall at c-2 or c-1 is
  //         fewer than 3 cycles before the rise, and a CS_N rise is not a counted rise);
  //       - H-RST: rst_n is high in cycles c, c+1, c+2.
  //     With MISO_UNCOND the three conditions are dropped; that run is expected to fail.
  //     (The window check uses the pin history from cycle 0, where the pins before cycle 0 are
  //     taken as idle, as chip.md 6.1 says.)
  // ---------------------------------------------------------------------------
  wire EVT = START || END_ || (RISE && inframe);   // an update of the MISO register
  reg evt_d1 = 0;                                  // EVT(t-1)
  reg miso_d1 = 0, miso_d2 = 0;
  reg [1:0] rh = 2'b11;        // rh[0] = rst_n(t-1), rh[1] = rst_n(t-2)
  reg [6:0] sk_hist = 7'h00;   // sk_hist[k] = SCK(t-1-k)
  reg [6:0] cs_hist = 7'h7f;   // cs_hist[k] = CS_N(t-1-k); idle (1) before cycle 0

  always @(posedge clk) begin
    evt_d1 <= EVT;
    miso_d1 <= miso;
    miso_d2 <= miso_d1;
    rh <= {rh[0], rst_n};
    // Pins during reset count as idle, as chip.md 6.1 says for the time before cycle 0.
    sk_hist <= {sk_hist[5:0], rst_n ? sck : 1'b0};
    cs_hist <= {cs_hist[5:0], rst_n ? cs_n : 1'b1};
  end

  // (a) every cycle from cycle 1.
  always @(*) if (started && rst_n && (miso != miso_d1)) begin
    assert (evt_d1 || !rh[0]);
  end

  // (b) the window for a rise at c = t-2. Pin history: SCK(c) = sk_hist[1], SCK(c-1) =
  // sk_hist[2], SCK(c-2) = sk_hist[3]; CS_N(c) = cs_hist[1], CS_N(c-1) = cs_hist[2],
  // CS_N(c-2) = cs_hist[3], CS_N(c-3) = cs_hist[4].
  wire counted_c = sk_hist[1] && !sk_hist[2] && !cs_hist[1] && !cs_hist[2];
  wire hsck_ok = !sk_hist[3];
  wire hcs_ok  = (cs_hist[3] == cs_hist[4]) && (cs_hist[2] == cs_hist[3]);
  wire hrst_ok = rst_n && rh[0] && rh[1];
`ifdef MISO_UNCOND
  wire host_ok = 1'b1;
`else
  wire host_ok = hsck_ok && hcs_ok && hrst_ok;
`endif

  always @(*) if (started && counted_c && host_ok) begin
    assert (miso == miso_d1);
    assert (miso_d1 == miso_d2);
  end

  // ---------------------------------------------------------------------------
  // Covers: the interesting cases are reached.
  // ---------------------------------------------------------------------------
`ifdef FORMAL
  always @(*) if (started) begin
    cover (e_w);                              // a write word
    cover (e_c);                              // a read commit
    cover (e_w && ge55 && (m_w != 0));        // a second write word
    cover (inframe && END_ && !e_c);          // frame ends with nothing pending
    cover (START && status[7]);               // STATUS bit 7 on the link
  end
`endif

endmodule
