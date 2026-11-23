`default_nettype none
`timescale 1ns / 1ps

/* Testbench for the Tiny Tapeout top. cocotb (test.py) drives the pins through the
   regs below, so the SPI host is an ordinary cocotbext-spi master on three signals:

     spi_sck  = ui_in[5], spi_mosi = ui_in[6], spi_cs_n = ui_in[7], spi_miso = uo_out[7]
     ext_ui   = ui_in[4:0], the external levels of pins 16 to 20
     ext_uio  = the level of each uio pad that the chip does not drive (1 = pulled up)

   A uio pad that the chip drives (uio_oe = 1) shows the chip's level, including a 0 from
   open-drain. Any other pad shows ext_uio. This is the pad rule of engine.md R1.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  // At gate level (GATES=yes defines GL_TEST) only the testbench's own pins are dumped:
  // a full dump of every gate net over a whole run is too large.
  initial begin
    $dumpfile("tb.fst");
`ifdef GL_TEST
    $dumpvars(1, tb);
`else
    $dumpvars(0, tb);
`endif
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg spi_sck;
  reg spi_mosi;
  reg spi_cs_n;
  reg [4:0] ext_ui;
  reg [7:0] ext_uio;

  wire [7:0] ui_in = {spi_cs_n, spi_mosi, spi_sck, ext_ui};
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  wire [7:0] uio_in = (uio_oe & uio_out) | (~uio_oe & ext_uio);
  wire       spi_miso = uo_out[7];

  tt_um_aryankarnati_polyglot user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
