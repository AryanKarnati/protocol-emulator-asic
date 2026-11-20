// SPDX-License-Identifier: Apache-2.0
//
// test reference only, not for synthesis.
//
// Behavioural model of the block 1 gate design, written from docs/gate.md only.
// It exists so that test/test.py can be run before the Hardcaml RTL exists.
// It is deliberately simple and has no structure in common with the RTL.

`default_nettype none

module tt_um_aryankarnati_polyglot (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // Reset synchronizer: 2 FFs, asynchronous assert, release after 2 clocks.
  reg sync1, sync2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync1 <= 1'b0;
      sync2 <= 1'b0;
    end else begin
      sync1 <= 1'b1;
      sync2 <= sync1;
    end
  end
  wire rst = !sync2;  // active high, asynchronous to clk

  wire [2:0] cmd     = ui_in[2:0];
  wire [1:0] byte_sel = ui_in[4:3];
  wire       view    = ui_in[5];
  wire [7:0] data    = uio_in;

  localparam CMD_NOP = 3'b000, CMD_PUSH = 3'b001, CMD_POP = 3'b010,
             CMD_INT_LO = 3'b011, CMD_INT_HI = 3'b100, CMD_FRAC = 3'b101,
             CMD_DIV_RESTART = 3'b110, CMD_CLEAR = 3'b111;

  // FIFO: 4 x 32 bit, q[0] is the head.
  reg [31:0] q [0:3];
  reg [2:0]  cnt;
  reg        ovf, unf;

  // Divider: divisor in 1/256 units, acc in 1/256 units.
  reg [15:0] div_int;
  reg [7:0]  div_frac;
  reg [23:0] acc;
  // INT = 0 means 65536. Divisor D256 = INT * 256 + FRAC (25 bits to hold 65536 * 256).
  wire [24:0] d_int  = (div_int == 16'd0) ? 25'h1_0000 : {9'd0, div_int};
  wire [24:0] d_full = {d_int[16:0], 8'h00} + {17'd0, div_frac};
  wire [24:0] t     = {1'b0, acc} + 25'd256;
  wire        tick  = (t >= d_full);

  wire [31:0] word = {data, data, data, data} ^ 32'h0123_4567;
  wire [31:0] head = (cnt == 3'd0) ? 32'h0 : q[0];
  wire [7:0]  head_byte = head >> {byte_sel, 3'b000};
  wire [7:0]  status = {tick, cnt, cnt == 3'd4, cnt == 3'd0, ovf, unf};

  integer i;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      cnt <= 3'd0;
      ovf <= 1'b0;
      unf <= 1'b0;
      div_int <= 16'd1;
      div_frac <= 8'd0;
      acc <= 24'd0;
      for (i = 0; i < 4; i = i + 1) q[i] <= 32'h0;
    end else begin
      // Divider: the accumulator counts 256 per cycle and wraps at the divisor.
      acc <= tick ? (t - {1'b0, d_full}) : t[23:0];
      case (cmd)
        CMD_NOP: ;
        CMD_PUSH: begin
          if (cnt != 3'd4) begin
            q[cnt] <= word;
            cnt <= cnt + 3'd1;
          end else begin
            ovf <= 1'b1;
          end
        end
        CMD_POP: begin
          if (cnt != 3'd0) begin
            q[0] <= q[1];
            q[1] <= q[2];
            q[2] <= q[3];
            cnt <= cnt - 3'd1;
          end else begin
            unf <= 1'b1;
          end
        end
        CMD_INT_LO: div_int[7:0] <= data;
        CMD_INT_HI: div_int[15:8] <= data;
        CMD_FRAC:   div_frac <= data;
        CMD_DIV_RESTART: acc <= 24'd0;
        CMD_CLEAR: begin
          ovf <= 1'b0;
          unf <= 1'b0;
        end
        default: ;
      endcase
    end
  end

  assign uo_out  = view ? status : head_byte;
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  wire _unused = &{ena, ui_in[7:6], 1'b0};

endmodule

`default_nettype wire
