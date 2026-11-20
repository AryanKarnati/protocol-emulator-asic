module fifo (
    data_in,
    push,
    pop,
    rst_n,
    clk,
    head,
    level,
    full,
    empty,
    push_dropped,
    pop_empty
);

    input [31:0] data_in;
    input push;
    input pop;
    input rst_n;
    input clk;
    output [31:0] head;
    output [3:0] level;
    output full;
    output empty;
    output push_dropped;
    output pop_empty;

    wire _22;
    wire _25;
    wire gnd;
    wire [3:0] _27;
    wire [1:0] _71;
    wire _72;
    wire _73;
    wire [31:0] _70;
    reg [31:0] word_3;
    wire [1:0] _65;
    wire _66;
    wire _67;
    reg [31:0] word_2;
    wire [1:0] _59;
    wire _60;
    wire _61;
    reg [31:0] word_1;
    wire [1:0] _53;
    wire [1:0] _29;
    reg [1:0] _34;
    wire [1:0] wr_ptr;
    wire _54;
    wire _55;
    wire [31:0] _8;
    reg [31:0] word_0;
    wire [2:0] empty_0;
    wire vdd;
    wire [2:0] _44;
    wire [2:0] _41;
    wire [2:0] full_0;
    wire push_dropped_0;
    wire push_ok;
    wire _10;
    wire _33;
    wire [2:0] _36;
    wire [2:0] _37;
    wire [2:0] _42;
    reg [2:0] _46;
    wire [2:0] count;
    wire pop_empty_0;
    wire pop_ok;
    wire _13;
    wire _40;
    wire _15;
    wire _17;
    wire [1:0] _48;
    reg [1:0] _50;
    wire [1:0] rd_ptr;
    reg [31:0] head_0;
    assign _22 = _13 & pop_empty_0;
    assign _25 = _10 & push_dropped_0;
    assign gnd = 1'b0;
    assign _27 = { gnd,
                   count };
    assign _71 = 2'b11;
    assign _72 = wr_ptr == _71;
    assign _73 = _33 & _72;
    assign _70 = 32'b00000000000000000000000000000000;
    always @(posedge _17) begin
        if (_73)
            word_3 <= _8;
    end
    assign _65 = 2'b10;
    assign _66 = wr_ptr == _65;
    assign _67 = _33 & _66;
    always @(posedge _17) begin
        if (_67)
            word_2 <= _8;
    end
    assign _59 = 2'b01;
    assign _60 = wr_ptr == _59;
    assign _61 = _33 & _60;
    always @(posedge _17) begin
        if (_61)
            word_1 <= _8;
    end
    assign _53 = 2'b00;
    assign _29 = wr_ptr + _59;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            _34 <= _53;
        else
            if (_33)
                _34 <= _29;
    end
    assign wr_ptr = _34;
    assign _54 = wr_ptr == _53;
    assign _55 = _33 & _54;
    assign _8 = data_in;
    always @(posedge _17) begin
        if (_55)
            word_0 <= _8;
    end
    assign empty_0 = 3'b000;
    assign vdd = 1'b1;
    assign _44 = 3'b000;
    assign _41 = { _53,
                   _40 };
    assign full_0 = 3'b100;
    assign push_dropped_0 = count == full_0;
    assign push_ok = ~ push_dropped_0;
    assign _10 = push;
    assign _33 = _10 & push_ok;
    assign _36 = { _53,
                   _33 };
    assign _37 = count + _36;
    assign _42 = _37 - _41;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            _46 <= _44;
        else
            _46 <= _42;
    end
    assign count = _46;
    assign pop_empty_0 = count == empty_0;
    assign pop_ok = ~ pop_empty_0;
    assign _13 = pop;
    assign _40 = _13 & pop_ok;
    assign _15 = rst_n;
    assign _17 = clk;
    assign _48 = rd_ptr + _59;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            _50 <= _53;
        else
            if (_40)
                _50 <= _48;
    end
    assign rd_ptr = _50;
    always @* begin
        case (rd_ptr)
        0:
            head_0 <= word_0;
        1:
            head_0 <= word_1;
        2:
            head_0 <= word_2;
        default:
            head_0 <= word_3;
        endcase
    end
    assign head = head_0;
    assign level = _27;
    assign full = push_dropped_0;
    assign empty = pop_empty_0;
    assign push_dropped = _25;
    assign pop_empty = _22;

endmodule
module clkdiv (
    rst_n,
    clk,
    frac,
    int_,
    restart,
    tick
);

    input rst_n;
    input clk;
    input [7:0] frac;
    input [15:0] int_;
    input restart;
    output tick;

    wire [24:0] _13;
    wire vdd;
    wire [24:0] _29;
    wire _2;
    wire _4;
    wire [24:0] _20;
    wire [7:0] _6;
    wire [23:0] _18;
    wire gnd;
    wire [24:0] _19;
    wire [15:0] _15;
    wire [15:0] _8;
    wire _16;
    wire [24:0] tick_int;
    wire [24:0] _24;
    wire [24:0] _25;
    wire _10;
    wire [24:0] _27;
    reg [24:0] _31;
    wire [24:0] phase;
    wire [24:0] phase_plus_step;
    wire _22;
    wire _23;
    assign _13 = 25'b0000000000000000100000000;
    assign vdd = 1'b1;
    assign _29 = 25'b0000000000000000000000000;
    assign _2 = rst_n;
    assign _4 = clk;
    assign _20 = 25'b1000000000000000000000000;
    assign _6 = frac;
    assign _18 = { _8,
                   _6 };
    assign gnd = 1'b0;
    assign _19 = { gnd,
                   _18 };
    assign _15 = 16'b0000000000000000;
    assign _8 = int_;
    assign _16 = _8 == _15;
    assign tick_int = _16 ? _20 : _19;
    assign _24 = phase_plus_step - tick_int;
    assign _25 = _23 ? _24 : phase_plus_step;
    assign _10 = restart;
    assign _27 = _10 ? _29 : _25;
    always @(posedge _4 or negedge _2) begin
        if (_2 == 0)
            _31 <= _29;
        else
            _31 <= _27;
    end
    assign phase = _31;
    assign phase_plus_step = phase + _13;
    assign _22 = phase_plus_step < tick_int;
    assign _23 = ~ _22;
    assign tick = _23;

endmodule
module polyglot (
    uio_in,
    rst_n,
    clk,
    ui_in,
    uo_out,
    uio_out,
    uio_oe
);

    input [7:0] uio_in;
    input rst_n;
    input clk;
    input [7:0] ui_in;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] _15;
    wire _42;
    wire _40;
    wire _27;
    wire _28;
    wire _41;
    reg _43;
    wire underflow;
    wire _46;
    wire [2:0] _24;
    wire _25;
    wire clear_flags;
    wire _44;
    wire _45;
    wire _47;
    reg _49;
    wire overflow;
    wire _87;
    wire [3:0] _85;
    wire [2:0] _86;
    wire [2:0] _69;
    wire _70;
    wire div_restart;
    wire [2:0] _65;
    wire _66;
    wire wr_frac;
    reg [7:0] div_frac;
    wire [2:0] _58;
    wire _59;
    wire wr_int_lo;
    wire [7:0] _56;
    reg [7:0] div_int_lo;
    wire [2:0] _52;
    wire _53;
    wire wr_int_hi;
    reg [7:0] div_int_hi;
    wire [15:0] div_int;
    wire _73;
    wire _5;
    wire [7:0] status;
    wire [7:0] _81;
    wire [7:0] _80;
    wire [7:0] _79;
    wire [31:0] _77;
    wire [7:0] _78;
    wire [1:0] byte_sel;
    reg [7:0] head_byte;
    wire [31:0] push_word;
    wire [7:0] _7;
    wire [31:0] _35;
    wire [31:0] _37;
    wire [2:0] _32;
    wire _33;
    wire do_pop;
    wire [2:0] _29;
    wire [2:0] cmd;
    wire _30;
    wire do_push;
    wire gnd;
    wire _9;
    wire vdd;
    reg rst_sync1;
    reg core_rst_n;
    wire _11;
    wire [39:0] _39;
    wire _75;
    wire [7:0] data_view;
    wire [7:0] _13;
    wire view;
    wire [7:0] uo_out_0;
    assign _15 = 8'b00000000;
    assign _42 = 1'b0;
    assign _40 = _39[39:39];
    assign _27 = ~ clear_flags;
    assign _28 = underflow & _27;
    assign _41 = _28 | _40;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _43 <= gnd;
        else
            _43 <= _41;
    end
    assign underflow = _43;
    assign _46 = _39[38:38];
    assign _24 = 3'b111;
    assign _25 = cmd == _24;
    assign clear_flags = core_rst_n & _25;
    assign _44 = ~ clear_flags;
    assign _45 = overflow & _44;
    assign _47 = _45 | _46;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _49 <= gnd;
        else
            _49 <= _47;
    end
    assign overflow = _49;
    assign _87 = _39[36:36];
    assign _85 = _39[35:32];
    assign _86 = _85[2:0];
    assign _69 = 3'b110;
    assign _70 = cmd == _69;
    assign div_restart = core_rst_n & _70;
    assign _65 = 3'b101;
    assign _66 = cmd == _65;
    assign wr_frac = core_rst_n & _66;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            div_frac <= _15;
        else
            if (wr_frac)
                div_frac <= _7;
    end
    assign _58 = 3'b011;
    assign _59 = cmd == _58;
    assign wr_int_lo = core_rst_n & _59;
    assign _56 = 8'b00000001;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            div_int_lo <= _56;
        else
            if (wr_int_lo)
                div_int_lo <= _7;
    end
    assign _52 = 3'b100;
    assign _53 = cmd == _52;
    assign wr_int_hi = core_rst_n & _53;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            div_int_hi <= _15;
        else
            if (wr_int_hi)
                div_int_hi <= _7;
    end
    assign div_int = { div_int_hi,
                       div_int_lo };
    clkdiv
        clkdiv
        ( .clk(_11),
          .rst_n(core_rst_n),
          .int_(div_int),
          .frac(div_frac),
          .restart(div_restart),
          .tick(_73) );
    assign _5 = _73;
    assign status = { _5,
                      _86,
                      _87,
                      _75,
                      overflow,
                      underflow };
    assign _81 = _77[31:24];
    assign _80 = _77[23:16];
    assign _79 = _77[15:8];
    assign _77 = _39[31:0];
    assign _78 = _77[7:0];
    assign byte_sel = _13[4:3];
    always @* begin
        case (byte_sel)
        0:
            head_byte <= _78;
        1:
            head_byte <= _79;
        2:
            head_byte <= _80;
        default:
            head_byte <= _81;
        endcase
    end
    assign push_word = 32'b00000001001000110100010101100111;
    assign _7 = uio_in;
    assign _35 = { _7,
                   _7,
                   _7,
                   _7 };
    assign _37 = _35 ^ push_word;
    assign _32 = 3'b010;
    assign _33 = cmd == _32;
    assign do_pop = core_rst_n & _33;
    assign _29 = 3'b001;
    assign cmd = _13[2:0];
    assign _30 = cmd == _29;
    assign do_push = core_rst_n & _30;
    assign gnd = 1'b0;
    assign _9 = rst_n;
    assign vdd = 1'b1;
    always @(posedge _11 or negedge _9) begin
        if (_9 == 0)
            rst_sync1 <= gnd;
        else
            rst_sync1 <= vdd;
    end
    always @(posedge _11 or negedge _9) begin
        if (_9 == 0)
            core_rst_n <= gnd;
        else
            core_rst_n <= rst_sync1;
    end
    assign _11 = clk;
    fifo
        fifo
        ( .clk(_11),
          .rst_n(core_rst_n),
          .push(do_push),
          .pop(do_pop),
          .data_in(_37),
          .pop_empty(_39[39:39]),
          .push_dropped(_39[38:38]),
          .empty(_39[37:37]),
          .full(_39[36:36]),
          .level(_39[35:32]),
          .head(_39[31:0]) );
    assign _75 = _39[37:37];
    assign data_view = _75 ? _15 : head_byte;
    assign _13 = ui_in;
    assign view = _13[5:5];
    assign uo_out_0 = view ? status : data_view;
    assign uo_out = uo_out_0;
    assign uio_out = _15;
    assign uio_oe = _15;

endmodule
