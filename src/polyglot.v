module fifo_4x32 (
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
    output [2:0] level;
    output full;
    output empty;
    output push_dropped;
    output pop_empty;

    wire pop_empty_0;
    wire push_dropped_0;
    wire [1:0] _69;
    wire wr_sel_3;
    wire word_3_en;
    wire [31:0] _68;
    reg [31:0] word_3;
    wire [1:0] _63;
    wire wr_sel_2;
    wire word_2_en;
    reg [31:0] word_2;
    wire [1:0] _57;
    wire wr_sel_1;
    wire word_1_en;
    reg [31:0] word_1;
    wire [1:0] _51;
    wire [1:0] _27;
    reg [1:0] wr_ptr_q;
    wire [1:0] _6;
    wire wr_sel_0;
    wire word_0_en;
    wire [31:0] _8;
    reg [31:0] word_0;
    wire [2:0] _20;
    wire vdd;
    wire [2:0] level_down;
    wire [2:0] _23;
    wire full_0;
    wire _30;
    wire _10;
    wire push_ok;
    wire [2:0] level_up;
    wire [2:0] _35;
    wire [2:0] _40;
    reg [2:0] level_q;
    wire [2:0] _11;
    wire empty_0;
    wire _37;
    wire _13;
    wire pop_ok;
    wire _15;
    wire _17;
    wire [1:0] _46;
    reg [1:0] rd_ptr_q;
    wire [1:0] _18;
    reg [31:0] head_0;
    assign pop_empty_0 = _13 & empty_0;
    assign push_dropped_0 = _10 & full_0;
    assign _69 = 2'b11;
    assign wr_sel_3 = _6 == _69;
    assign word_3_en = push_ok & wr_sel_3;
    assign _68 = 32'b00000000000000000000000000000000;
    always @(posedge _17) begin
        if (word_3_en)
            word_3 <= _8;
    end
    assign _63 = 2'b10;
    assign wr_sel_2 = _6 == _63;
    assign word_2_en = push_ok & wr_sel_2;
    always @(posedge _17) begin
        if (word_2_en)
            word_2 <= _8;
    end
    assign _57 = 2'b01;
    assign wr_sel_1 = _6 == _57;
    assign word_1_en = push_ok & wr_sel_1;
    always @(posedge _17) begin
        if (word_1_en)
            word_1 <= _8;
    end
    assign _51 = 2'b00;
    assign _27 = _6 + _57;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            wr_ptr_q <= _51;
        else
            if (push_ok)
                wr_ptr_q <= _27;
    end
    assign _6 = wr_ptr_q;
    assign wr_sel_0 = _6 == _51;
    assign word_0_en = push_ok & wr_sel_0;
    assign _8 = data_in;
    always @(posedge _17) begin
        if (word_0_en)
            word_0 <= _8;
    end
    assign _20 = 3'b000;
    assign vdd = 1'b1;
    assign level_down = { _51,
                          pop_ok };
    assign _23 = 3'b100;
    assign full_0 = _11 == _23;
    assign _30 = ~ full_0;
    assign _10 = push;
    assign push_ok = _10 & _30;
    assign level_up = { _51,
                        push_ok };
    assign _35 = _11 + level_up;
    assign _40 = _35 - level_down;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            level_q <= _20;
        else
            level_q <= _40;
    end
    assign _11 = level_q;
    assign empty_0 = _11 == _20;
    assign _37 = ~ empty_0;
    assign _13 = pop;
    assign pop_ok = _13 & _37;
    assign _15 = rst_n;
    assign _17 = clk;
    assign _46 = _18 + _57;
    always @(posedge _17 or negedge _15) begin
        if (_15 == 0)
            rd_ptr_q <= _51;
        else
            if (pop_ok)
                rd_ptr_q <= _46;
    end
    assign _18 = rd_ptr_q;
    always @* begin
        case (_18)
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
    assign level = _11;
    assign full = full_0;
    assign empty = empty_0;
    assign push_dropped = push_dropped_0;
    assign pop_empty = pop_empty_0;

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
    wire int_is_zero;
    wire [24:0] divisor;
    wire [24:0] _24;
    wire [24:0] _25;
    wire _10;
    wire [24:0] _27;
    reg [24:0] phase_q;
    wire [24:0] _11;
    wire [24:0] phase_sum;
    wire _22;
    wire tick_now;
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
    assign int_is_zero = _8 == _15;
    assign divisor = int_is_zero ? _20 : _19;
    assign _24 = phase_sum - divisor;
    assign _25 = tick_now ? _24 : phase_sum;
    assign _10 = restart;
    assign _27 = _10 ? _29 : _25;
    always @(posedge _4 or negedge _2) begin
        if (_2 == 0)
            phase_q <= _29;
        else
            phase_q <= _27;
    end
    assign _11 = phase_q;
    assign phase_sum = _11 + _13;
    assign _22 = phase_sum < divisor;
    assign tick_now = ~ _22;
    assign tick = tick_now;

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
    wire _3;
    wire _28;
    wire _41;
    reg underflow_q;
    wire _46;
    wire [2:0] _24;
    wire _25;
    wire clear_flags;
    wire _44;
    wire _4;
    wire _45;
    wire _47;
    reg overflow_q;
    wire _86;
    wire [2:0] _85;
    wire [2:0] _69;
    wire _70;
    wire div_restart;
    wire [2:0] _65;
    wire _66;
    wire wr_frac;
    reg [7:0] frac_q;
    wire [2:0] _58;
    wire _59;
    wire wr_int_lo;
    wire [7:0] _56;
    reg [7:0] int_lo_q;
    wire [2:0] _52;
    wire _53;
    wire wr_int_hi;
    reg [7:0] int_hi_q;
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
    wire [31:0] _36;
    wire [7:0] _7;
    wire [31:0] _35;
    wire [31:0] push_word;
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
    wire [38:0] _39;
    wire _75;
    wire [7:0] data_view;
    wire [7:0] _13;
    wire view;
    wire [7:0] uo_out_0;
    assign _15 = 8'b00000000;
    assign _42 = 1'b0;
    assign _40 = _39[38:38];
    assign _27 = ~ clear_flags;
    assign _3 = underflow_q;
    assign _28 = _3 & _27;
    assign _41 = _28 | _40;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            underflow_q <= gnd;
        else
            underflow_q <= _41;
    end
    assign _46 = _39[37:37];
    assign _24 = 3'b111;
    assign _25 = cmd == _24;
    assign clear_flags = core_rst_n & _25;
    assign _44 = ~ clear_flags;
    assign _4 = overflow_q;
    assign _45 = _4 & _44;
    assign _47 = _45 | _46;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            overflow_q <= gnd;
        else
            overflow_q <= _47;
    end
    assign _86 = _39[35:35];
    assign _85 = _39[34:32];
    assign _69 = 3'b110;
    assign _70 = cmd == _69;
    assign div_restart = core_rst_n & _70;
    assign _65 = 3'b101;
    assign _66 = cmd == _65;
    assign wr_frac = core_rst_n & _66;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            frac_q <= _15;
        else
            if (wr_frac)
                frac_q <= _7;
    end
    assign _58 = 3'b011;
    assign _59 = cmd == _58;
    assign wr_int_lo = core_rst_n & _59;
    assign _56 = 8'b00000001;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            int_lo_q <= _56;
        else
            if (wr_int_lo)
                int_lo_q <= _7;
    end
    assign _52 = 3'b100;
    assign _53 = cmd == _52;
    assign wr_int_hi = core_rst_n & _53;
    always @(posedge _11 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            int_hi_q <= _15;
        else
            if (wr_int_hi)
                int_hi_q <= _7;
    end
    assign div_int = { int_hi_q,
                       int_lo_q };
    clkdiv
        clkdiv
        ( .clk(_11),
          .rst_n(core_rst_n),
          .int_(div_int),
          .frac(frac_q),
          .restart(div_restart),
          .tick(_73) );
    assign _5 = _73;
    assign status = { _5,
                      _85,
                      _86,
                      _75,
                      overflow_q,
                      underflow_q };
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
    assign _36 = 32'b00000001001000110100010101100111;
    assign _7 = uio_in;
    assign _35 = { _7,
                   _7,
                   _7,
                   _7 };
    assign push_word = _35 ^ _36;
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
    fifo_4x32
        fifo_4x32
        ( .clk(_11),
          .rst_n(core_rst_n),
          .push(do_push),
          .pop(do_pop),
          .data_in(push_word),
          .pop_empty(_39[38:38]),
          .push_dropped(_39[37:37]),
          .empty(_39[36:36]),
          .full(_39[35:35]),
          .level(_39[34:32]),
          .head(_39[31:0]) );
    assign _75 = _39[36:36];
    assign data_view = _75 ? _15 : head_byte;
    assign _13 = ui_in;
    assign view = _13[5:5];
    assign uo_out_0 = view ? status : data_view;
    assign uo_out = uo_out_0;
    assign uio_out = _15;
    assign uio_oe = _15;

endmodule
