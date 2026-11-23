// SPI testbench for polyglot with sram = true (chip.md 6 and 8.4). The macro is the stand-in
// in sram_standin.v. Pin cycles are one clock period each; SCK phases are 3 cycles.
`timescale 1ns/1ps
module tb_sram;
  reg clk = 0;
  reg rst_n = 0;
  reg [7:0] ui_in = 8'h80;   // CS_N high
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out, uio_out, uio_oe;
  integer fails = 0, checks = 0;

  polyglot dut (
      .clk(clk), .rst_n(rst_n), .ui_in(ui_in), .uio_in(uio_in),
      .uo_out(uo_out), .uio_out(uio_out), .uio_oe(uio_oe));

  always #5 clk = ~clk;

  reg [95:0] tx;      // transmitted bits, bit 0 of the frame is tx[nb-1]
  integer nb;
  reg [127:0] ms;     // MISO sampled at the rise of each bit

  // One pin cycle: set SCK, MOSI, CS_N, then sample MISO a little after the edge.
  task pin(input s, input m, input c);
    begin
      @(negedge clk);
      ui_in = {c, m, s, ui_in[4:0]};
      #1;
    end
  endtask

  task xfer;
    integer j, k;
    begin
      for (k = 0; k < 4; k = k + 1) pin(0, 0, 0);
      for (j = 0; j < nb; j = j + 1) begin
        for (k = 0; k < 3; k = k + 1) pin(0, tx[nb-1-j], 0);
        pin(1, tx[nb-1-j], 0);
        ms[j] = uo_out[7];
        pin(1, tx[nb-1-j], 0);
        pin(1, tx[nb-1-j], 0);
      end
      for (k = 0; k < 3; k = k + 1) pin(0, 0, 0);
      for (k = 0; k < 4; k = k + 1) pin(0, 0, 1);
    end
  endtask

  // The 24-bit header: R, F, six zero bits, ADDR[15:0].
  function [23:0] hdr(input r, input f, input [15:0] addr);
    hdr = {r, f, 6'b0, addr};
  endfunction

  // Data word m of a frame: bits 32+32m .. 63+32m, MSB first.
  function [31:0] word(input integer m);
    integer k;
    begin
      word = 0;
      for (k = 0; k < 32; k = k + 1) word[31-k] = ms[32 + 32*m + k];
    end
  endfunction

  task expect32(input [255:0] what, input [31:0] got, input [31:0] want);
    begin
      checks = checks + 1;
      if (got !== want) begin
        fails = fails + 1;
        $display("FAIL %0s: got %h want %h", what, got, want);
      end
    end
  endtask

  task write_word(input [15:0] addr, input [31:0] data);
    begin
      tx = {hdr(0, 0, addr), data};
      nb = 56;
      xfer;
    end
  endtask

  task read_word(input [15:0] addr, output [31:0] data);
    begin
      tx = {hdr(1, 0, addr), 40'h0};
      nb = 64;
      xfer;
      data = word(0);
    end
  endtask

  reg [31:0] v;
  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    // HWCFG: 4 SMs, IMEM 64, SRAM present (bit 25), version 1.
    read_word(16'h0004, v);
    expect32("HWCFG with SRAM", v, 32'h12400404);

    // Full-word writes and reads across the window: 0x400 (word 0), 0x7FC (word 255),
    // 0x800 (word 256), 0xBFC (word 511).
    write_word(16'h0400, 32'hCAFE1234);
    write_word(16'h07FC, 32'h11223344);
    write_word(16'h0800, 32'h0BADBEEF);
    write_word(16'h0BFC, 32'hA5A5F00F);
    read_word(16'h0400, v); expect32("0x400 readback", v, 32'hCAFE1234);
    read_word(16'h07FC, v); expect32("0x7FC readback", v, 32'h11223344);
    read_word(16'h0800, v); expect32("0x800 readback", v, 32'h0BADBEEF);
    read_word(16'h0BFC, v); expect32("0xBFC readback", v, 32'hA5A5F00F);

    // Overwrite, then an F = 1 burst of two words at 0x400: both reads see the same word.
    write_word(16'h0400, 32'hDEADC0DE);
    tx = {hdr(1, 1, 16'h0400), 72'h0};
    nb = 96;
    xfer;
    expect32("F=1 burst word 0", word(0), 32'hDEADC0DE);
    expect32("F=1 burst word 1", word(1), 32'hDEADC0DE);

    // An unmapped address in the window's neighbourhood (0xC00) reads 0.
    read_word(16'h0C00, v); expect32("0xC00 unmapped", v, 32'h0);

    $display("checks: %0d, failures: %0d", checks, fails);
    if (fails != 0) $display("RESULT FAIL");
    else $display("RESULT PASS");
    $finish;
  end
endmodule
