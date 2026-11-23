// STAND-IN model of RM_IHPSG13_1P_512x32_c2_bm_bist, written from the port list and the
// behaviour in flow/SRAM.md. It is NOT the PDK model. The PDK file
// (ihp-sg13g2/libs.ref/sg13g2_sram/verilog) must replace this before the result counts.
// Read is registered (1-cycle latency, read-first); write mask A_BM; A_DLY must be 1.
module RM_IHPSG13_1P_512x32_c2_bm_bist (
    input         A_CLK,
    input         A_MEN,
    input         A_WEN,
    input         A_REN,
    input  [8:0]  A_ADDR,
    input  [31:0] A_DIN,
    input         A_DLY,
    output reg [31:0] A_DOUT,
    input  [31:0] A_BM,
    input         A_BIST_CLK,
    input         A_BIST_EN,
    input         A_BIST_MEN,
    input         A_BIST_WEN,
    input         A_BIST_REN,
    input  [8:0]  A_BIST_ADDR,
    input  [31:0] A_BIST_DIN,
    input  [31:0] A_BIST_BM
);
  reg [31:0] mem [0:511];
  always @(posedge A_CLK) begin
    if (!A_DLY) $display("ERROR: A_DLY must be 1");
    if (A_MEN && A_WEN) mem[A_ADDR] <= (mem[A_ADDR] & ~A_BM) | (A_DIN & A_BM);
    if (A_MEN && A_REN) A_DOUT <= mem[A_ADDR];
  end
endmodule
