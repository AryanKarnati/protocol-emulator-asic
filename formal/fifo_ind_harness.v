// Unbounded tracked-token proof for the block 1 FIFO (fifo_4x32), written by the checker.
//
// Uses the debug netlist (tools/add_fifo_debug.py) that exposes the four storage words and
// the pointers. The auxiliary invariants are: the pointers equal the push and pop counts mod
// 4; LEVEL is the count difference; and for every slot j in the queue, the word at rd+j is tv
// exactly when the ordinal npop+j is the token tk. Proved by k-induction, k = 2 (see
// fifo_ind.sby). The base netlist, without the debug ports, is checked by fifo.sby.

module fifo_ind_harness (input clk);
  reg started = 0; always @(posedge clk) started <= 1; wire rst_n = started;
  (* anyseq *) wire push; (* anyseq *) wire pop; (* anyseq *) wire [31:0] data_in;
  (* anyconst *) reg [7:0] tk; (* anyconst *) reg [31:0] tv;
  wire [31:0] head, w0,w1,w2,w3; wire [2:0] level; wire full, empty, pd, pe; wire [1:0] rdp, wrp;
  fifo_4x32 dut(.data_in(data_in),.push(push),.pop(pop),.rst_n(rst_n),.clk(clk),.head(head),.level(level),
    .full(full),.empty(empty),.push_dropped(pd),.pop_empty(pe),.w0(w0),.w1(w1),.w2(w2),.w3(w3),.rdp(rdp),.wrp(wrp));
  wire acc_push = rst_n && push && !full; wire acc_pop = rst_n && pop && !empty;
  reg [7:0] npush = 0, npop = 0;
  always @(posedge clk) if (!rst_n) begin npush<=0; npop<=0; end else begin
    if (acc_push) npush<=npush+1; if (acc_pop) npop<=npop+1; end
  always @(*) begin
    if (!rst_n) begin assume(!push); assume(!pop); end
    if (acc_push && npush==tk) assume(data_in==tv);
    if (acc_push && npush!=tk) assume(data_in!=tv);
  end
  function [31:0] wd(input [1:0] i); wd = i==0?w0:i==1?w1:i==2?w2:w3; endfunction
  integer j;
  always @(*) if (started) begin
    assert (level <= 4);
    assert (level == npush[2:0]-npop[2:0] || (level==4 && npush[2:0]-npop[2:0]==4));
    assert (rdp == npop[1:0]); assert (wrp == npush[1:0]);
    assert ({5'b0,level} == ({24'b0,npush} - {24'b0,npop}) % 256);
    for (j=0;j<4;j=j+1)
      if (level > j) assert ((wd(rdp + j[1:0]) == tv) == ((npop + j[7:0]) == tk));
    if (level != 0) assert ((head == tv) == (npop == tk));
  end
endmodule
