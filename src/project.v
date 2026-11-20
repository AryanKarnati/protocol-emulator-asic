`default_nettype none

// Tiny Tapeout wrapper: maps the pads to the generated module polyglot (hw/).
// Nothing else lives here.
module tt_um_aryankarnati_polyglot (
    input  wire [7:0] ui_in,   // Dedicated inputs
    output wire [7:0] uo_out,  // Dedicated outputs
    input  wire [7:0] uio_in,  // IOs: input path
    output wire [7:0] uio_out, // IOs: output path
    output wire [7:0] uio_oe,  // IOs: enable path (1 = output)
    input  wire       ena,     // ignored
    input  wire       clk,
    input  wire       rst_n
);

  // ena is unused: the design is always on.
  wire _unused = &{ena, 1'b0};

  polyglot u_polyglot (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
