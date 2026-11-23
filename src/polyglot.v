module decode (
    side_en,
    sideset_count,
    instr,
    legal,
    is_jmp,
    is_wait,
    is_in,
    is_out,
    is_push,
    is_pull,
    is_mov,
    is_irq,
    is_set,
    uses_lcu,
    side_valid,
    side_value,
    delay,
    bit_count
);

    input side_en;
    input [2:0] sideset_count;
    input [15:0] instr;
    output legal;
    output is_jmp;
    output is_wait;
    output is_in;
    output is_out;
    output is_push;
    output is_pull;
    output is_mov;
    output is_irq;
    output is_set;
    output uses_lcu;
    output side_valid;
    output [4:0] side_value;
    output [4:0] delay;
    output [5:0] bit_count;

    wire [5:0] _69;
    wire [5:0] _68;
    wire [4:0] _65;
    wire _66;
    wire [5:0] _70;
    wire [5:0] _64;
    wire _63;
    wire [5:0] bit_count_0;
    wire _82;
    wire [3:0] _81;
    wire [4:0] _83;
    wire [1:0] _79;
    wire [2:0] _78;
    wire [4:0] _80;
    wire [2:0] _76;
    wire [1:0] _75;
    wire [4:0] _77;
    wire [3:0] _73;
    wire [4:0] _74;
    reg [4:0] delay_0;
    wire [3:0] _118;
    wire [4:0] _119;
    wire [2:0] _116;
    wire [4:0] _117;
    wire [1:0] _113;
    wire [4:0] _114;
    wire _110;
    wire [4:0] _111;
    reg [4:0] _120;
    wire [3:0] _104;
    wire gnd;
    wire [4:0] _105;
    wire [2:0] _102;
    wire [4:0] _103;
    wire [1:0] _99;
    wire [4:0] _100;
    wire _96;
    wire [4:0] _97;
    reg [4:0] _106;
    wire [4:0] _121;
    wire [4:0] side_value_0;
    wire [4:0] _72;
    wire _90;
    wire _5;
    wire _89;
    wire _91;
    wire [2:0] _7;
    wire _87;
    wire _88;
    wire side_valid_0;
    wire [2:0] _137;
    wire _138;
    wire [2:0] _135;
    wire _136;
    wire _139;
    wire [2:0] _131;
    wire [2:0] _130;
    wire _132;
    wire [2:0] _128;
    wire _129;
    wire _133;
    wire _126;
    wire [2:0] _123;
    wire _124;
    wire _127;
    wire _134;
    wire _140;
    wire uses_lcu_0;
    wire _143;
    wire is_set_0;
    wire [2:0] _145;
    wire _146;
    wire is_irq_0;
    wire _149;
    wire is_mov_0;
    wire _154;
    wire _152;
    wire _153;
    wire is_pull_0;
    wire _159;
    wire _160;
    wire _157;
    wire _158;
    wire is_push_0;
    wire _61;
    wire is_out_0;
    wire _58;
    wire is_in_0;
    wire [2:0] _162;
    wire _163;
    wire is_wait_0;
    wire _166;
    wire is_jmp_0;
    wire _55;
    wire _51;
    wire _52;
    wire _49;
    wire _50;
    wire _53;
    wire [1:0] _45;
    wire [1:0] _44;
    wire _46;
    wire _47;
    wire _42;
    wire _43;
    wire _48;
    wire [4:0] _38;
    wire _40;
    wire [2:0] _34;
    wire _36;
    wire _37;
    wire _30;
    wire [1:0] _28;
    wire _29;
    wire _31;
    wire _32;
    wire [1:0] _24;
    wire _26;
    wire _27;
    wire _33;
    wire vdd;
    wire [15:0] _20;
    wire [2:0] _22;
    reg legal_0;
    assign _69 = 6'b100000;
    assign _68 = { gnd,
                   _38 };
    assign _65 = 5'b00000;
    assign _66 = _38 == _65;
    assign _70 = _66 ? _69 : _68;
    assign _64 = 6'b000000;
    assign _63 = is_in_0 | is_out_0;
    assign bit_count_0 = _63 ? _70 : _64;
    assign _82 = _72[0:0];
    assign _81 = 4'b0000;
    assign _83 = { _81,
                   _82 };
    assign _79 = _72[1:0];
    assign _78 = 3'b000;
    assign _80 = { _78,
                   _79 };
    assign _76 = _72[2:0];
    assign _75 = 2'b00;
    assign _77 = { _75,
                   _76 };
    assign _73 = _72[3:0];
    assign _74 = { gnd,
                   _73 };
    always @* begin
        case (_7)
        0:
            delay_0 <= _72;
        1:
            delay_0 <= _74;
        2:
            delay_0 <= _77;
        3:
            delay_0 <= _80;
        4:
            delay_0 <= _83;
        default:
            delay_0 <= _65;
        endcase
    end
    assign _118 = _72[3:0];
    assign _119 = { gnd,
                    _118 };
    assign _116 = _72[3:1];
    assign _117 = { _75,
                    _116 };
    assign _113 = _72[3:2];
    assign _114 = { _78,
                    _113 };
    assign _110 = _72[3:3];
    assign _111 = { _81,
                    _110 };
    always @* begin
        case (_7)
        0:
            _120 <= _65;
        1:
            _120 <= _65;
        2:
            _120 <= _111;
        3:
            _120 <= _114;
        4:
            _120 <= _117;
        default:
            _120 <= _119;
        endcase
    end
    assign _104 = _72[4:1];
    assign gnd = 1'b0;
    assign _105 = { gnd,
                    _104 };
    assign _102 = _72[4:2];
    assign _103 = { _75,
                    _102 };
    assign _99 = _72[4:3];
    assign _100 = { _78,
                    _99 };
    assign _96 = _72[4:4];
    assign _97 = { _81,
                   _96 };
    always @* begin
        case (_7)
        0:
            _106 <= _65;
        1:
            _106 <= _97;
        2:
            _106 <= _100;
        3:
            _106 <= _103;
        4:
            _106 <= _105;
        default:
            _106 <= _72;
        endcase
    end
    assign _121 = _5 ? _120 : _106;
    assign side_value_0 = side_valid_0 ? _121 : _65;
    assign _72 = _20[12:8];
    assign _90 = _72[4:4];
    assign _5 = side_en;
    assign _89 = ~ _5;
    assign _91 = _89 | _90;
    assign _7 = sideset_count;
    assign _87 = _7 == _78;
    assign _88 = ~ _87;
    assign side_valid_0 = _88 & _91;
    assign _137 = 3'b011;
    assign _138 = _34 == _137;
    assign _135 = 3'b111;
    assign _136 = _22 == _135;
    assign _139 = _136 & _138;
    assign _131 = 3'b100;
    assign _130 = _20[2:0];
    assign _132 = _130 == _131;
    assign _128 = 3'b101;
    assign _129 = _22 == _128;
    assign _133 = _129 & _132;
    assign _126 = _34 == _131;
    assign _123 = 3'b010;
    assign _124 = _22 == _123;
    assign _127 = _124 & _126;
    assign _134 = _127 | _133;
    assign _140 = _134 | _139;
    assign uses_lcu_0 = legal_0 & _140;
    assign _143 = _22 == _135;
    assign is_set_0 = legal_0 & _143;
    assign _145 = 3'b110;
    assign _146 = _22 == _145;
    assign is_irq_0 = legal_0 & _146;
    assign _149 = _22 == _128;
    assign is_mov_0 = legal_0 & _149;
    assign _154 = _20[7:7];
    assign _152 = _22 == _131;
    assign _153 = legal_0 & _152;
    assign is_pull_0 = _153 & _154;
    assign _159 = _20[7:7];
    assign _160 = ~ _159;
    assign _157 = _22 == _131;
    assign _158 = legal_0 & _157;
    assign is_push_0 = _158 & _160;
    assign _61 = _22 == _137;
    assign is_out_0 = legal_0 & _61;
    assign _58 = _22 == _123;
    assign is_in_0 = legal_0 & _58;
    assign _162 = 3'b001;
    assign _163 = _22 == _162;
    assign is_wait_0 = legal_0 & _163;
    assign _166 = _22 == _78;
    assign is_jmp_0 = legal_0 & _166;
    assign _55 = _34 < _128;
    assign _51 = _20[3:3];
    assign _52 = ~ _51;
    assign _49 = _20[7:7];
    assign _50 = ~ _49;
    assign _53 = _50 & _52;
    assign _45 = 2'b11;
    assign _44 = _20[4:3];
    assign _46 = _44 == _45;
    assign _47 = ~ _46;
    assign _42 = _34 == _137;
    assign _43 = ~ _42;
    assign _48 = _43 & _47;
    assign _38 = _20[4:0];
    assign _40 = _38 == _65;
    assign _34 = _20[7:5];
    assign _36 = _34 == _128;
    assign _37 = ~ _36;
    assign _30 = _20[3:3];
    assign _28 = 2'b10;
    assign _29 = _24 == _28;
    assign _31 = _29 & _30;
    assign _32 = ~ _31;
    assign _24 = _20[6:5];
    assign _26 = _24 == _45;
    assign _27 = ~ _26;
    assign _33 = _27 & _32;
    assign vdd = 1'b1;
    assign _20 = instr;
    assign _22 = _20[15:13];
    always @* begin
        case (_22)
        0:
            legal_0 <= vdd;
        1:
            legal_0 <= _33;
        2:
            legal_0 <= _37;
        3:
            legal_0 <= vdd;
        4:
            legal_0 <= _40;
        5:
            legal_0 <= _48;
        6:
            legal_0 <= _53;
        default:
            legal_0 <= _55;
        endcase
    end
    assign legal = legal_0;
    assign is_jmp = is_jmp_0;
    assign is_wait = is_wait_0;
    assign is_in = is_in_0;
    assign is_out = is_out_0;
    assign is_push = is_push_0;
    assign is_pull = is_pull_0;
    assign is_mov = is_mov_0;
    assign is_irq = is_irq_0;
    assign is_set = is_set_0;
    assign uses_lcu = uses_lcu_0;
    assign side_valid = side_valid_0;
    assign side_value = side_value_0;
    assign delay = delay_0;
    assign bit_count = bit_count_0;

endmodule
module clkdiv_dbg (
    rst_n,
    clk,
    frac,
    int_,
    restart,
    tick,
    phase
);

    input rst_n;
    input clk;
    input [7:0] frac;
    input [15:0] int_;
    input restart;
    output tick;
    output [24:0] phase;

    wire [24:0] _14;
    wire vdd;
    wire [24:0] _30;
    wire _3;
    wire _5;
    wire [24:0] _21;
    wire [7:0] _7;
    wire [23:0] _19;
    wire gnd;
    wire [24:0] _20;
    wire [15:0] _16;
    wire [15:0] _9;
    wire int_is_zero;
    wire [24:0] divisor;
    wire [24:0] _25;
    wire [24:0] _26;
    wire _11;
    wire [24:0] _28;
    reg [24:0] phase_q;
    wire [24:0] _12;
    wire [24:0] phase_sum;
    wire _23;
    wire tick_now;
    assign _14 = 25'b0000000000000000100000000;
    assign vdd = 1'b1;
    assign _30 = 25'b0000000000000000000000000;
    assign _3 = rst_n;
    assign _5 = clk;
    assign _21 = 25'b1000000000000000000000000;
    assign _7 = frac;
    assign _19 = { _9,
                   _7 };
    assign gnd = 1'b0;
    assign _20 = { gnd,
                   _19 };
    assign _16 = 16'b0000000000000000;
    assign _9 = int_;
    assign int_is_zero = _9 == _16;
    assign divisor = int_is_zero ? _21 : _20;
    assign _25 = phase_sum - divisor;
    assign _26 = tick_now ? _25 : phase_sum;
    assign _11 = restart;
    assign _28 = _11 ? _30 : _26;
    always @(posedge _5 or negedge _3) begin
        if (_3 == 0)
            phase_q <= _30;
        else
            phase_q <= _28;
    end
    assign _12 = phase_q;
    assign phase_sum = _12 + _14;
    assign _23 = phase_sum < divisor;
    assign tick_now = ~ _23;
    assign tick = tick_now;
    assign phase = phase_q;

endmodule
module sm (
    page,
    imem_abandon,
    irq_q,
    sm_num,
    instr_data,
    tx_head,
    rx_full,
    rx_level,
    tx_level,
    execctrl,
    in_sel,
    pinctrl,
    clkdiv_restart,
    clkdiv_frac,
    clkdiv_int,
    rst_n,
    clk,
    enable,
    tx_empty,
    shiftctrl,
    imem_word,
    restart,
    instr_write,
    pc,
    lvl_mask,
    lvl_val,
    dir_mask,
    dir_val,
    irq_set,
    irq_clr,
    tx_pop,
    rx_push,
    rx_push_data,
    txstall,
    rxstall,
    illegal,
    x,
    y,
    isr,
    osr,
    dbg_cnt,
    exec_stalled,
    phase
);

    input page;
    input imem_abandon;
    input [7:0] irq_q;
    input [1:0] sm_num;
    input [15:0] instr_data;
    input [31:0] tx_head;
    input rx_full;
    input [3:0] rx_level;
    input [3:0] tx_level;
    input [31:0] execctrl;
    input [31:0] in_sel;
    input [31:0] pinctrl;
    input clkdiv_restart;
    input [7:0] clkdiv_frac;
    input [15:0] clkdiv_int;
    input rst_n;
    input clk;
    input enable;
    input tx_empty;
    input [31:0] shiftctrl;
    input [15:0] imem_word;
    input restart;
    input instr_write;
    output [4:0] pc;
    output [31:0] lvl_mask;
    output [31:0] lvl_val;
    output [31:0] dir_mask;
    output [31:0] dir_val;
    output [7:0] irq_set;
    output [7:0] irq_clr;
    output tx_pop;
    output rx_push;
    output [31:0] rx_push_data;
    output txstall;
    output rxstall;
    output illegal;
    output [31:0] x;
    output [31:0] y;
    output [31:0] isr;
    output [31:0] osr;
    output [31:0] dbg_cnt;
    output exec_stalled;
    output [24:0] phase;

    wire [24:0] _91;
    wire _325;
    wire _2;
    wire _322;
    wire _323;
    wire exec_stalled_next;
    reg exec_stalled_q;
    wire [1:0] _444;
    wire [2:0] _442;
    wire [3:0] _420;
    wire [3:0] imem_stall_base;
    wire [3:0] _416;
    wire [3:0] imem_stall_next;
    reg [3:0] imem_stall_q;
    wire [3:0] _4;
    wire [3:0] _413;
    wire [3:0] _411;
    wire [3:0] _409;
    wire [3:0] _406;
    wire [3:0] _404;
    wire [3:0] _403;
    reg [3:0] _407;
    wire [3:0] _401;
    wire [3:0] _402;
    wire [3:0] _408;
    wire [3:0] _410;
    wire [3:0] _412;
    wire _399;
    wire [3:0] stall_code;
    wire [3:0] stall_reason_now;
    wire [3:0] _431;
    wire [3:0] latch_stall_next;
    reg [3:0] latch_stall_q;
    wire [3:0] _5;
    wire _439;
    wire _440;
    wire [3:0] stall_reason;
    wire [31:0] dbg_cnt_0;
    wire _936;
    wire illegal_0;
    wire _938;
    wire rxstall_0;
    wire out_empty_stall;
    wire txstall_0;
    wire [31:0] rx_push_data_0;
    wire rx_push_0;
    wire _944;
    wire _945;
    wire tx_pop_0;
    wire _976;
    wire _977;
    wire [2:0] _972;
    wire _973;
    wire _974;
    wire [2:0] _969;
    wire _970;
    wire _971;
    wire [2:0] _966;
    wire _967;
    wire _968;
    wire [2:0] _963;
    wire _964;
    wire _965;
    wire [2:0] _960;
    wire _961;
    wire _962;
    wire [2:0] _957;
    wire _958;
    wire _959;
    wire [2:0] _954;
    wire _955;
    wire [1:0] _949;
    wire _950;
    wire wait_done;
    wire _951;
    wire wait_irq_clr;
    wire irq_clr_now;
    wire _953;
    wire _956;
    wire [7:0] irq_clr_out;
    wire _1003;
    wire _1004;
    wire _1000;
    wire _1001;
    wire _997;
    wire _998;
    wire _994;
    wire _995;
    wire _991;
    wire _992;
    wire _988;
    wire _989;
    wire _985;
    wire _986;
    wire _982;
    wire _979;
    wire irq_set_now;
    wire _983;
    wire [7:0] irq_set_out;
    wire [31:0] _1314;
    wire _1172;
    wire [1:0] _1173;
    wire [3:0] _1174;
    wire [7:0] _1175;
    wire [15:0] _1176;
    wire [31:0] _1177;
    wire [31:0] _1178;
    wire [31:0] dir_eff_val;
    wire [31:0] _1315;
    wire [31:0] ss_dir_val;
    wire [31:0] dir_val_out;
    wire _1317;
    wire [1:0] _1318;
    wire [3:0] _1319;
    wire [7:0] _1320;
    wire [15:0] _1321;
    wire [31:0] _1322;
    wire [31:0] _1323;
    wire [31:0] dir_eff_mask;
    wire [31:0] ss_dir_mask;
    wire [31:0] dir_mask_out;
    wire [31:0] _1356;
    wire [31:0] _1341;
    wire [1:0] _1179;
    wire [3:0] _1180;
    wire [7:0] _1181;
    wire [15:0] _1182;
    wire [31:0] _1183;
    wire [31:0] dir_new_val;
    wire [15:0] _1212;
    wire [15:0] _1211;
    wire [31:0] _1213;
    wire [7:0] _1208;
    wire [23:0] _1207;
    wire [31:0] _1209;
    wire [3:0] _1204;
    wire [27:0] _1203;
    wire [31:0] _1205;
    wire [1:0] _1200;
    wire [29:0] _1199;
    wire [31:0] _1201;
    wire _1196;
    wire [30:0] _1195;
    wire [31:0] _1197;
    wire [31:0] _1193;
    wire [31:0] _1194;
    wire _1192;
    wire [31:0] _1198;
    wire _1191;
    wire [31:0] _1202;
    wire _1190;
    wire [31:0] _1206;
    wire _1189;
    wire [31:0] _1210;
    wire _1188;
    wire [31:0] _1214;
    wire [31:0] pin_val;
    wire [1:0] _1332;
    wire [3:0] _1333;
    wire [7:0] _1334;
    wire [15:0] _1335;
    wire [31:0] _1336;
    wire [31:0] lvl_new_val;
    wire [31:0] _1338;
    wire [31:0] _1339;
    wire [31:0] _1340;
    reg [31:0] sticky_val_q;
    wire [31:0] _21;
    wire _1345;
    wire _1346;
    wire [1:0] _1347;
    wire [3:0] _1348;
    wire [7:0] _1349;
    wire [15:0] _1350;
    wire [31:0] _1351;
    wire [31:0] _1352;
    wire [31:0] lvl_eff_val;
    wire [31:0] _1357;
    wire [31:0] _1343;
    wire [15:0] _1032;
    wire [15:0] _1031;
    wire [31:0] _1033;
    wire [7:0] _1028;
    wire [23:0] _1027;
    wire [31:0] _1029;
    wire [3:0] _1024;
    wire [27:0] _1023;
    wire [31:0] _1025;
    wire [1:0] _1020;
    wire [29:0] _1019;
    wire [31:0] _1021;
    wire _1016;
    wire [30:0] _1015;
    wire [31:0] _1017;
    wire [4:0] _1013;
    wire [26:0] _1012;
    wire [31:0] _1014;
    wire _1011;
    wire [31:0] _1018;
    wire _1010;
    wire [31:0] _1022;
    wire _1009;
    wire [31:0] _1026;
    wire _1008;
    wire [31:0] _1030;
    wire _1007;
    wire [31:0] _1034;
    wire [31:0] ss_val;
    wire [31:0] ss_lvl_val;
    wire [31:0] lvl_val_out;
    wire [1:0] _1324;
    wire [3:0] _1325;
    wire [7:0] _1326;
    wire [15:0] _1327;
    wire [31:0] _1328;
    wire [31:0] dir_new_mask;
    wire [15:0] _1307;
    wire [15:0] _1306;
    wire [31:0] _1308;
    wire [7:0] _1303;
    wire [23:0] _1302;
    wire [31:0] _1304;
    wire [3:0] _1299;
    wire [27:0] _1298;
    wire [31:0] _1300;
    wire [1:0] _1295;
    wire [29:0] _1294;
    wire [31:0] _1296;
    wire _1291;
    wire [30:0] _1290;
    wire [31:0] _1292;
    wire [5:0] _1287;
    wire _1288;
    wire [5:0] _1285;
    wire _1286;
    wire [5:0] _1283;
    wire _1284;
    wire [5:0] _1281;
    wire _1282;
    wire [5:0] _1279;
    wire _1280;
    wire [5:0] _1277;
    wire _1278;
    wire [5:0] _1275;
    wire _1276;
    wire [5:0] _1273;
    wire _1274;
    wire [5:0] _1271;
    wire _1272;
    wire [5:0] _1269;
    wire _1270;
    wire [5:0] _1267;
    wire _1268;
    wire [5:0] _1265;
    wire _1266;
    wire [5:0] _1263;
    wire _1264;
    wire [5:0] _1261;
    wire _1262;
    wire [5:0] _1259;
    wire _1260;
    wire [5:0] _1257;
    wire _1258;
    wire [5:0] _1255;
    wire _1256;
    wire [5:0] _1253;
    wire _1254;
    wire [5:0] _1251;
    wire _1252;
    wire [5:0] _1249;
    wire _1250;
    wire [5:0] _1247;
    wire _1248;
    wire [5:0] _1245;
    wire _1246;
    wire [5:0] _1243;
    wire _1244;
    wire [5:0] _1241;
    wire _1242;
    wire [5:0] _1239;
    wire _1240;
    wire [5:0] _1237;
    wire _1238;
    wire [5:0] _1235;
    wire _1236;
    wire [5:0] _1233;
    wire _1234;
    wire [5:0] _1231;
    wire _1232;
    wire [5:0] _1229;
    wire _1230;
    wire [5:0] _1227;
    wire _1228;
    wire [2:0] _1223;
    wire [5:0] _1224;
    wire [5:0] _1221;
    wire [5:0] _1225;
    wire [5:0] _1220;
    wire _1226;
    wire [31:0] _1289;
    wire _1219;
    wire [31:0] _1293;
    wire _1218;
    wire [31:0] _1297;
    wire _1217;
    wire [31:0] _1301;
    wire _1216;
    wire [31:0] _1305;
    wire [4:0] _1186;
    wire [4:0] _1185;
    wire set_write;
    wire [4:0] _1187;
    wire _1215;
    wire [31:0] pin_mask;
    wire [1:0] _1359;
    wire [3:0] _1360;
    wire [7:0] _1361;
    wire [15:0] _1362;
    wire [31:0] _1363;
    wire [31:0] lvl_new_mask;
    wire [31:0] _1365;
    wire [31:0] _1366;
    wire [31:0] _1367;
    reg [31:0] sticky_mask_q;
    wire [31:0] _23;
    wire _1370;
    wire _1371;
    reg sticky_isdir_q;
    wire _24;
    wire _1382;
    wire _1170;
    wire _1171;
    wire _1383;
    wire [1:0] _1384;
    wire [3:0] _1385;
    wire [7:0] _1386;
    wire [15:0] _1387;
    wire [31:0] _1388;
    wire [31:0] _1389;
    wire _1166;
    wire set_dirs;
    wire _1163;
    wire out_dirs;
    wire dir_write_now;
    wire _1159;
    wire set_pins;
    wire _1155;
    wire mov_pins;
    wire _1152;
    wire out_pins;
    wire _1157;
    wire lvl_write_now;
    wire write_any;
    wire [31:0] lvl_eff_mask;
    wire _1144;
    wire [1:0] _1145;
    wire [3:0] _1146;
    wire [7:0] _1147;
    wire [15:0] _1148;
    wire [31:0] _1149;
    wire [31:0] _1354;
    wire _1135;
    wire _1374;
    wire latch_ss_next;
    reg latch_ss_q;
    wire _25;
    wire _1130;
    wire _1378;
    wire imem_ss_next;
    reg imem_ss_q;
    wire _26;
    wire imem_ss_base;
    wire ss_flag;
    wire _1133;
    wire _1134;
    wire ss_apply;
    wire [1:0] _1137;
    wire [3:0] _1138;
    wire [7:0] _1139;
    wire [15:0] _1140;
    wire [31:0] _1141;
    wire [15:0] _1127;
    wire [15:0] _1126;
    wire [31:0] _1128;
    wire [7:0] _1123;
    wire [23:0] _1122;
    wire [31:0] _1124;
    wire [3:0] _1119;
    wire [27:0] _1118;
    wire [31:0] _1120;
    wire [1:0] _1115;
    wire [29:0] _1114;
    wire [31:0] _1116;
    wire _1111;
    wire [30:0] _1110;
    wire [31:0] _1112;
    wire _1108;
    wire _1106;
    wire _1104;
    wire _1102;
    wire _1100;
    wire _1098;
    wire _1096;
    wire _1094;
    wire _1092;
    wire _1090;
    wire _1088;
    wire _1086;
    wire _1084;
    wire _1082;
    wire _1080;
    wire _1078;
    wire _1076;
    wire _1074;
    wire _1072;
    wire _1070;
    wire _1068;
    wire _1066;
    wire _1064;
    wire _1062;
    wire _1060;
    wire _1058;
    wire _1056;
    wire _1054;
    wire _1052;
    wire _1050;
    wire _1048;
    wire [4:0] _1043;
    wire [5:0] _1044;
    wire [5:0] _1042;
    wire [5:0] ss_nbits;
    wire _1046;
    wire [31:0] _1109;
    wire _1039;
    wire [31:0] _1113;
    wire _1038;
    wire [31:0] _1117;
    wire _1037;
    wire [31:0] _1121;
    wire _1036;
    wire [31:0] _1125;
    wire [4:0] _1006;
    wire _1035;
    wire [31:0] _1129;
    wire [31:0] ss_mask;
    wire [31:0] ss_lvl_mask;
    wire [31:0] lvl_mask_out;
    wire [4:0] _1404;
    wire [4:0] _1402;
    wire [4:0] _1401;
    wire [4:0] _1403;
    wire [4:0] pc_target;
    wire [4:0] _1398;
    wire [4:0] _1396;
    wire [4:0] _1397;
    wire [4:0] _1394;
    wire _1395;
    wire [4:0] pc_adv;
    wire [4:0] _28;
    wire _1392;
    wire imem_done;
    wire [4:0] _1400;
    wire _390;
    wire mov_pc;
    wire _382;
    wire out_pc;
    wire _375;
    wire _373;
    wire _372;
    wire _371;
    wire _370;
    wire _369;
    wire _368;
    wire _367;
    wire _366;
    wire _365;
    wire _364;
    wire _363;
    wire _362;
    wire _361;
    wire _360;
    wire _359;
    wire _358;
    wire _357;
    wire _356;
    wire _355;
    wire _354;
    wire _353;
    wire _352;
    wire _351;
    wire _350;
    wire _349;
    wire _348;
    wire _347;
    wire _346;
    wire _345;
    wire _344;
    wire _343;
    wire _342;
    wire [4:0] _341;
    reg _374;
    wire _339;
    wire _340;
    wire _338;
    wire _337;
    wire _335;
    wire _334;
    reg jmp_cond_val;
    wire _330;
    wire _93;
    wire _94;
    wire _97;
    wire _100;
    wire _1410;
    wire latch_forced_next;
    reg latch_forced_q;
    wire _29;
    wire _1414;
    wire _422;
    wire clr_latch_scope;
    wire latch_irqw_next;
    reg latch_irqw_q;
    wire _30;
    reg page_prev_q;
    wire _31;
    wire _33;
    wire page_chg;
    wire _315;
    wire [4:0] _1434;
    wire [4:0] _1429;
    wire exec_form;
    wire [4:0] _1431;
    wire _1426;
    wire _1424;
    wire complete;
    wire _1427;
    wire [4:0] _1432;
    wire _1422;
    wire _1420;
    wire _1421;
    wire dec_now;
    wire [4:0] delay_next;
    wire [4:0] _1437;
    reg [4:0] delay_q;
    wire [4:0] _34;
    wire delay_zero;
    wire _102;
    wire _103;
    wire attempt_imem;
    wire _1441;
    wire _36;
    wire pc_write_latch;
    wire _394;
    wire imem_clr;
    wire imem_irqw_next;
    reg imem_irqw_q;
    wire _37;
    wire imem_irqw_base;
    wire irq_state;
    wire _318;
    wire _319;
    wire _312;
    wire _309;
    wire _310;
    wire _307;
    wire _306;
    wire _308;
    wire irq_set_form;
    wire irqw_form;
    wire irq_stall;
    wire _301;
    wire _297;
    wire _296;
    wire _295;
    wire _294;
    wire _293;
    wire _292;
    wire _291;
    wire [7:0] _39;
    wire _290;
    wire [1:0] _41;
    wire [1:0] _286;
    wire [1:0] _287;
    wire _285;
    wire [2:0] _288;
    wire [2:0] _284;
    wire _283;
    wire [2:0] flag_idx;
    reg flag_val;
    wire _281;
    wire _280;
    wire _279;
    wire _278;
    wire _277;
    wire _276;
    wire _275;
    wire _274;
    wire _273;
    wire _272;
    wire _271;
    wire _270;
    wire _269;
    wire _268;
    wire _267;
    wire _266;
    wire _265;
    wire _264;
    wire _263;
    wire _262;
    wire _261;
    wire _260;
    wire _259;
    wire _258;
    wire _257;
    wire _256;
    wire _255;
    wire _254;
    wire _253;
    wire _252;
    wire _251;
    wire _250;
    reg _282;
    wire _222;
    wire _221;
    wire _220;
    wire _219;
    wire _218;
    wire _217;
    wire _216;
    wire _215;
    wire _214;
    wire _213;
    wire _212;
    wire _211;
    wire _210;
    wire _209;
    wire _208;
    wire _207;
    wire _206;
    wire _205;
    wire _204;
    wire _203;
    wire _202;
    wire _201;
    wire _200;
    wire _199;
    wire _198;
    wire _197;
    wire _196;
    wire _195;
    wire _194;
    wire _193;
    wire _192;
    wire _191;
    wire [4:0] _190;
    reg _223;
    wire [1:0] _189;
    reg wait_bit;
    wire wait_cond;
    wire _303;
    wire _187;
    wire _186;
    wire _188;
    wire wait_stall;
    wire _175;
    wire in_stall;
    wire _154;
    wire pull_stall;
    wire _132;
    wire push_stall;
    wire _157;
    wire _177;
    wire _185;
    wire _305;
    wire stall;
    wire _327;
    wire latch_done;
    wire _1478;
    wire _424;
    wire _378;
    wire _179;
    wire _112;
    wire _113;
    wire _108;
    wire [2:0] _107;
    wire [15:0] _1476;
    wire [15:0] _43;
    wire [15:0] _1471;
    wire _879;
    wire _877;
    wire _875;
    wire _873;
    wire _871;
    wire _869;
    wire _867;
    wire _865;
    wire _863;
    wire _861;
    wire _859;
    wire _857;
    wire _855;
    wire _853;
    wire _851;
    wire _849;
    wire _847;
    wire _845;
    wire _843;
    wire _841;
    wire _839;
    wire _837;
    wire _835;
    wire _833;
    wire _831;
    wire _829;
    wire _827;
    wire _825;
    wire _823;
    wire _821;
    wire _819;
    wire _817;
    wire [31:0] _880;
    wire [31:0] _881;
    wire [15:0] _812;
    wire [31:0] _813;
    wire [23:0] _808;
    wire [7:0] _807;
    wire [31:0] _809;
    wire [27:0] _804;
    wire [31:0] _805;
    wire [29:0] _800;
    wire [31:0] _801;
    wire [30:0] _796;
    wire [31:0] _797;
    wire [31:0] _45;
    wire [15:0] _595;
    wire [31:0] _596;
    wire [23:0] _591;
    wire [31:0] _592;
    wire [27:0] _587;
    wire [31:0] _588;
    wire [29:0] _583;
    wire [31:0] _584;
    wire [30:0] _579;
    wire [31:0] _580;
    wire _577;
    wire [31:0] _581;
    wire _576;
    wire [31:0] _585;
    wire _575;
    wire [31:0] _589;
    wire _574;
    wire [31:0] _593;
    wire [4:0] _572;
    wire _573;
    wire [31:0] _597;
    wire [5:0] _570;
    wire _571;
    wire [31:0] _598;
    wire [15:0] _565;
    wire [31:0] _567;
    wire [23:0] _561;
    wire [31:0] _563;
    wire [27:0] _557;
    wire [31:0] _559;
    wire [29:0] _553;
    wire [31:0] _555;
    wire [30:0] _549;
    wire [31:0] _551;
    wire _548;
    wire [31:0] _552;
    wire _547;
    wire [31:0] _556;
    wire _546;
    wire [31:0] _560;
    wire _545;
    wire [31:0] _564;
    wire [4:0] _543;
    wire _544;
    wire [31:0] _568;
    wire _542;
    wire [31:0] _569;
    wire [31:0] osr_shifted;
    wire _535;
    wire _534;
    wire _533;
    wire _532;
    wire _531;
    wire _530;
    wire _529;
    wire _528;
    wire _527;
    wire _526;
    wire _525;
    wire _524;
    wire _523;
    wire _522;
    wire _521;
    wire _520;
    wire _519;
    wire _518;
    wire _517;
    wire _516;
    wire _515;
    wire _514;
    wire _513;
    wire _512;
    wire _511;
    wire _510;
    wire _509;
    wire _508;
    wire _507;
    wire _506;
    wire _505;
    wire _504;
    wire [31:0] _536;
    wire [31:0] _503;
    wire [15:0] _776;
    wire [31:0] _778;
    wire [23:0] _772;
    wire [31:0] _774;
    wire [27:0] _768;
    wire [31:0] _770;
    wire [29:0] _764;
    wire [31:0] _766;
    wire [30:0] _760;
    wire [31:0] _762;
    wire _759;
    wire [31:0] _763;
    wire _758;
    wire [31:0] _767;
    wire _757;
    wire [31:0] _771;
    wire _756;
    wire [31:0] _775;
    wire [4:0] _754;
    wire _755;
    wire [31:0] _779;
    wire [5:0] _751;
    wire _753;
    wire [31:0] _780;
    wire [15:0] _746;
    wire [31:0] _747;
    wire [23:0] _742;
    wire [31:0] _743;
    wire [27:0] _738;
    wire [31:0] _739;
    wire [29:0] _734;
    wire [31:0] _735;
    wire [30:0] _730;
    wire [31:0] _731;
    wire _728;
    wire [31:0] _732;
    wire _727;
    wire [31:0] _736;
    wire _726;
    wire [31:0] _740;
    wire _725;
    wire [31:0] _744;
    wire [4:0] _723;
    wire _724;
    wire [31:0] _748;
    wire _722;
    wire [31:0] _749;
    wire [31:0] _781;
    wire _717;
    wire _715;
    wire _713;
    wire _711;
    wire _709;
    wire _707;
    wire _705;
    wire _703;
    wire _701;
    wire _699;
    wire _697;
    wire _695;
    wire _693;
    wire _691;
    wire _689;
    wire _687;
    wire _685;
    wire _683;
    wire _681;
    wire _679;
    wire _677;
    wire _675;
    wire _673;
    wire _671;
    wire _669;
    wire _667;
    wire _665;
    wire _663;
    wire _661;
    wire _659;
    wire _657;
    wire _655;
    wire [31:0] _718;
    wire [2:0] _652;
    reg [31:0] _653;
    wire [31:0] in_data;
    wire [15:0] _647;
    wire [31:0] _649;
    wire [23:0] _643;
    wire [31:0] _645;
    wire [27:0] _639;
    wire [31:0] _641;
    wire [29:0] _635;
    wire [31:0] _637;
    wire [30:0] _631;
    wire [31:0] _633;
    wire _630;
    wire [31:0] _634;
    wire _629;
    wire [31:0] _638;
    wire _628;
    wire [31:0] _642;
    wire _627;
    wire [31:0] _646;
    wire [4:0] _625;
    wire _626;
    wire [31:0] _650;
    wire _624;
    wire [31:0] _651;
    wire [31:0] _720;
    wire _622;
    wire [31:0] isr_new_in;
    wire [31:0] _783;
    wire _611;
    wire [5:0] _169;
    wire [6:0] _166;
    wire [6:0] _164;
    wire _620;
    wire in_shift;
    wire [5:0] _1446;
    wire _616;
    wire push_fire;
    wire _47;
    wire _131;
    wire _613;
    wire [5:0] _124;
    wire [4:0] _120;
    wire _122;
    wire [5:0] _126;
    wire _127;
    wire _118;
    wire _119;
    wire push_noop;
    wire _129;
    wire _116;
    wire _115;
    wire _117;
    wire push_try;
    wire _614;
    wire push_drop;
    wire push_clr;
    wire _1445;
    wire [5:0] _1448;
    wire [5:0] _1449;
    wire [5:0] isr_cnt_next;
    wire [5:0] _1453;
    reg [5:0] isr_cnt_q;
    wire [5:0] _48;
    wire [6:0] _162;
    wire [6:0] _165;
    wire _167;
    wire _168;
    wire [5:0] isr_cnt_new;
    wire _172;
    wire _173;
    wire _161;
    wire in_thr_hit;
    wire _159;
    wire _158;
    wire _160;
    wire _610;
    wire in_push;
    wire _619;
    wire [31:0] _784;
    wire _608;
    wire out_isr;
    wire [31:0] _883;
    wire _605;
    wire mov_isr;
    wire [31:0] isr_next;
    wire [31:0] _886;
    reg [31:0] isr_q;
    wire [31:0] _49;
    wire [3:0] _51;
    wire _495;
    wire [3:0] _493;
    wire [3:0] _53;
    wire _494;
    wire [31:0] _55;
    wire _492;
    wire status_bit;
    wire [1:0] _497;
    wire [3:0] _498;
    wire [7:0] _499;
    wire [15:0] _500;
    wire [31:0] _501;
    wire [31:0] _911;
    wire [31:0] _912;
    wire _903;
    wire set_y;
    wire [31:0] _908;
    wire _896;
    wire out_y;
    wire [31:0] _909;
    wire _893;
    wire mov_y;
    wire [31:0] _910;
    wire _890;
    wire y_dec;
    wire [31:0] y_next;
    reg [31:0] y_q;
    wire [31:0] _56;
    wire [31:0] _932;
    wire [4:0] _906;
    wire [31:0] _907;
    wire [2:0] _901;
    wire _926;
    wire _899;
    wire _898;
    wire _900;
    wire set_x;
    wire [31:0] _928;
    wire [2:0] _380;
    wire _923;
    wire out_x;
    wire [31:0] _929;
    wire _920;
    wire mov_x;
    wire [31:0] _930;
    wire [2:0] _332;
    wire _917;
    wire x_dec;
    wire [31:0] x_next;
    reg [31:0] x_q;
    wire [31:0] _57;
    wire [15:0] _247;
    wire [15:0] _246;
    wire [31:0] _248;
    wire [23:0] _243;
    wire [7:0] _242;
    wire [31:0] _244;
    wire [27:0] _239;
    wire [3:0] _238;
    wire [31:0] _240;
    wire [29:0] _235;
    wire [1:0] _234;
    wire [31:0] _236;
    wire [30:0] _231;
    wire _230;
    wire [31:0] _232;
    wire [31:0] _59;
    wire _229;
    wire [31:0] _233;
    wire _228;
    wire [31:0] _237;
    wire _227;
    wire [31:0] _241;
    wire _226;
    wire [31:0] _245;
    wire [31:0] _61;
    wire [4:0] _224;
    wire _225;
    wire [31:0] _249;
    wire [2:0] _490;
    reg [31:0] mov_src_val;
    wire [1:0] _489;
    reg [31:0] mov_data;
    wire [31:0] _538;
    wire [31:0] _539;
    wire [31:0] _600;
    wire _459;
    wire [5:0] _453;
    wire [6:0] _448;
    wire vdd;
    wire [5:0] _1463;
    wire _486;
    wire _481;
    wire _475;
    wire _472;
    wire _473;
    wire _470;
    wire _468;
    wire _63;
    wire [7:0] _65;
    wire [15:0] _67;
    wire _69;
    wire _71;
    wire [25:0] _90;
    wire _95;
    wire _73;
    wire tick_en;
    wire _467;
    wire _469;
    wire _471;
    wire _474;
    wire _476;
    wire _482;
    wire tx_pop_refill;
    wire _484;
    wire mov_osr;
    wire _155;
    wire _478;
    wire _477;
    wire pull_nb_empty;
    wire _464;
    wire _148;
    wire _141;
    wire _149;
    wire _139;
    wire _140;
    wire _150;
    wire pull_noop;
    wire _152;
    wire _135;
    wire _134;
    wire _136;
    wire pull_try;
    wire pull_data;
    wire pull_clr;
    wire _75;
    wire _461;
    wire [5:0] _145;
    wire [4:0] _142;
    wire _144;
    wire [5:0] _147;
    wire _181;
    wire _182;
    wire autopull_hit;
    wire out_hit;
    wire out_refill_stall;
    wire _1457;
    wire _1458;
    wire _1459;
    wire [5:0] _1461;
    wire [5:0] osr_cnt_next;
    wire [5:0] _1466;
    reg [5:0] osr_cnt_q;
    wire [5:0] _76;
    wire gnd;
    wire [6:0] _447;
    wire [6:0] _449;
    wire _451;
    wire _452;
    wire [5:0] osr_cnt_after;
    wire _456;
    wire _457;
    wire _137;
    wire _446;
    wire _458;
    wire out_refill_after;
    wire _463;
    wire _466;
    wire _488;
    wire [31:0] osr_next;
    reg [31:0] osr_q;
    wire [31:0] _77;
    wire _794;
    wire [31:0] _798;
    wire _793;
    wire [31:0] _802;
    wire _792;
    wire [31:0] _806;
    wire _791;
    wire [31:0] _810;
    wire [4:0] _789;
    wire _790;
    wire [31:0] _814;
    wire [5:0] _163;
    wire [5:0] _786;
    wire _788;
    wire [31:0] _815;
    wire [31:0] _79;
    wire _540;
    wire [31:0] out_data;
    wire [15:0] _1470;
    wire [2:0] _388;
    wire _427;
    wire _386;
    wire _385;
    wire _387;
    wire mov_exec;
    wire [15:0] exec_lo16;
    wire [15:0] _1473;
    wire [15:0] latch_instr_next;
    reg [15:0] latch_instr_q;
    wire [15:0] _80;
    wire [15:0] _82;
    wire [15:0] word;
    wire [27:0] _110;
    wire _111;
    wire ok;
    wire _178;
    wire _180;
    wire out_run;
    wire out_exec;
    wire exec_set;
    wire _1479;
    wire _84;
    wire _1480;
    wire _86;
    wire latch_valid_next;
    reg latch_valid_q;
    wire _87;
    wire forced_act;
    wire attempt_latch;
    wire attempt;
    wire _329;
    wire _331;
    wire jmp_taken;
    wire _384;
    wire pc_write_now;
    wire [4:0] pc_next;
    reg [4:0] pc_q;
    assign _91 = _90[25:1];
    assign _325 = 1'b0;
    assign _2 = exec_stalled_q;
    assign _322 = forced_act ? stall : _2;
    assign _323 = _86 ? gnd : _322;
    assign exec_stalled_next = _84 ? gnd : _323;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            exec_stalled_q <= gnd;
        else
            exec_stalled_q <= exec_stalled_next;
    end
    assign _444 = 2'b00;
    assign _442 = 3'b000;
    assign _420 = 4'b0000;
    assign imem_stall_base = page_chg ? _420 : _4;
    assign _416 = attempt_imem ? stall_reason_now : imem_stall_base;
    assign imem_stall_next = imem_clr ? _420 : _416;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            imem_stall_q <= _420;
        else
            imem_stall_q <= imem_stall_next;
    end
    assign _4 = imem_stall_q;
    assign _413 = 4'b0010;
    assign _411 = 4'b0001;
    assign _409 = 4'b0011;
    assign _406 = 4'b0110;
    assign _404 = 4'b0101;
    assign _403 = 4'b0100;
    always @* begin
        case (_189)
        0:
            _407 <= _403;
        1:
            _407 <= _404;
        2:
            _407 <= _406;
        default:
            _407 <= _406;
        endcase
    end
    assign _401 = 4'b0111;
    assign _402 = irq_stall ? _401 : _420;
    assign _408 = wait_stall ? _407 : _402;
    assign _410 = out_hit ? _409 : _408;
    assign _412 = pull_stall ? _411 : _410;
    assign _399 = push_stall | in_stall;
    assign stall_code = _399 ? _413 : _412;
    assign stall_reason_now = stall ? stall_code : _420;
    assign _431 = attempt_latch ? stall_reason_now : _5;
    assign latch_stall_next = clr_latch_scope ? _420 : _431;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_stall_q <= _420;
        else
            latch_stall_q <= latch_stall_next;
    end
    assign _5 = latch_stall_q;
    assign _439 = _5 == _420;
    assign _440 = ~ _439;
    assign stall_reason = _440 ? _5 : _4;
    assign dbg_cnt_0 = { _420,
                         stall_reason,
                         _442,
                         _34,
                         _444,
                         _76,
                         _444,
                         _48 };
    assign _936 = ~ ok;
    assign illegal_0 = attempt & _936;
    assign _938 = push_stall | push_drop;
    assign rxstall_0 = _938 | in_stall;
    assign out_empty_stall = out_hit & _75;
    assign txstall_0 = pull_stall | out_empty_stall;
    assign rx_push_data_0 = in_push ? isr_new_in : _49;
    assign rx_push_0 = push_fire | in_push;
    assign _944 = pull_data | out_refill_stall;
    assign _945 = _944 | out_refill_after;
    assign tx_pop_0 = _945 | tx_pop_refill;
    assign _976 = flag_idx == _442;
    assign _977 = _953 & _976;
    assign _972 = 3'b001;
    assign _973 = flag_idx == _972;
    assign _974 = _953 & _973;
    assign _969 = 3'b010;
    assign _970 = flag_idx == _969;
    assign _971 = _953 & _970;
    assign _966 = 3'b011;
    assign _967 = flag_idx == _966;
    assign _968 = _953 & _967;
    assign _963 = 3'b100;
    assign _964 = flag_idx == _963;
    assign _965 = _953 & _964;
    assign _960 = 3'b101;
    assign _961 = flag_idx == _960;
    assign _962 = _953 & _961;
    assign _957 = 3'b110;
    assign _958 = flag_idx == _957;
    assign _959 = _953 & _958;
    assign _954 = 3'b111;
    assign _955 = flag_idx == _954;
    assign _949 = 2'b10;
    assign _950 = _189 == _949;
    assign wait_done = _188 & wait_cond;
    assign _951 = wait_done & _950;
    assign wait_irq_clr = _951 & _301;
    assign irq_clr_now = _308 & _309;
    assign _953 = irq_clr_now | wait_irq_clr;
    assign _956 = _953 & _955;
    assign irq_clr_out = { _956,
                           _959,
                           _962,
                           _965,
                           _968,
                           _971,
                           _974,
                           _977 };
    assign _1003 = flag_idx == _442;
    assign _1004 = irq_set_now & _1003;
    assign _1000 = flag_idx == _972;
    assign _1001 = irq_set_now & _1000;
    assign _997 = flag_idx == _969;
    assign _998 = irq_set_now & _997;
    assign _994 = flag_idx == _966;
    assign _995 = irq_set_now & _994;
    assign _991 = flag_idx == _963;
    assign _992 = irq_set_now & _991;
    assign _988 = flag_idx == _960;
    assign _989 = irq_set_now & _988;
    assign _985 = flag_idx == _957;
    assign _986 = irq_set_now & _985;
    assign _982 = flag_idx == _954;
    assign _979 = ~ irq_state;
    assign irq_set_now = irq_set_form & _979;
    assign _983 = irq_set_now & _982;
    assign irq_set_out = { _983,
                           _986,
                           _989,
                           _992,
                           _995,
                           _998,
                           _1001,
                           _1004 };
    assign _1314 = ~ ss_dir_mask;
    assign _1172 = _1171 & _24;
    assign _1173 = { _1172,
                     _1172 };
    assign _1174 = { _1173,
                     _1173 };
    assign _1175 = { _1174,
                     _1174 };
    assign _1176 = { _1175,
                     _1175 };
    assign _1177 = { _1176,
                     _1176 };
    assign _1178 = _1177 & _21;
    assign dir_eff_val = write_any ? dir_new_val : _1178;
    assign _1315 = dir_eff_val & _1314;
    assign ss_dir_val = ss_val & _1149;
    assign dir_val_out = ss_dir_val | _1315;
    assign _1317 = _1171 & _24;
    assign _1318 = { _1317,
                     _1317 };
    assign _1319 = { _1318,
                     _1318 };
    assign _1320 = { _1319,
                     _1319 };
    assign _1321 = { _1320,
                     _1320 };
    assign _1322 = { _1321,
                     _1321 };
    assign _1323 = _1322 & _23;
    assign dir_eff_mask = write_any ? dir_new_mask : _1323;
    assign ss_dir_mask = ss_mask & _1149;
    assign dir_mask_out = ss_dir_mask | dir_eff_mask;
    assign _1356 = ~ ss_lvl_mask;
    assign _1341 = 32'b00000000000000000000000000000000;
    assign _1179 = { dir_write_now,
                     dir_write_now };
    assign _1180 = { _1179,
                     _1179 };
    assign _1181 = { _1180,
                     _1180 };
    assign _1182 = { _1181,
                     _1181 };
    assign _1183 = { _1182,
                     _1182 };
    assign dir_new_val = _1183 & pin_val;
    assign _1212 = _1210[31:16];
    assign _1211 = _1210[15:0];
    assign _1213 = { _1211,
                     _1212 };
    assign _1208 = _1206[31:24];
    assign _1207 = _1206[23:0];
    assign _1209 = { _1207,
                     _1208 };
    assign _1204 = _1202[31:28];
    assign _1203 = _1202[27:0];
    assign _1205 = { _1203,
                     _1204 };
    assign _1200 = _1198[31:30];
    assign _1199 = _1198[29:0];
    assign _1201 = { _1199,
                     _1200 };
    assign _1196 = _1194[31:31];
    assign _1195 = _1194[30:0];
    assign _1197 = { _1195,
                     _1196 };
    assign _1193 = set_write ? _907 : out_data;
    assign _1194 = mov_pins ? mov_data : _1193;
    assign _1192 = _1187[0:0];
    assign _1198 = _1192 ? _1197 : _1194;
    assign _1191 = _1187[1:1];
    assign _1202 = _1191 ? _1201 : _1198;
    assign _1190 = _1187[2:2];
    assign _1206 = _1190 ? _1205 : _1202;
    assign _1189 = _1187[3:3];
    assign _1210 = _1189 ? _1209 : _1206;
    assign _1188 = _1187[4:4];
    assign _1214 = _1188 ? _1213 : _1210;
    assign pin_val = _1214 & pin_mask;
    assign _1332 = { lvl_write_now,
                     lvl_write_now };
    assign _1333 = { _1332,
                     _1332 };
    assign _1334 = { _1333,
                     _1333 };
    assign _1335 = { _1334,
                     _1334 };
    assign _1336 = { _1335,
                     _1335 };
    assign lvl_new_val = _1336 & pin_val;
    assign _1338 = dir_write_now ? dir_new_val : lvl_new_val;
    assign _1339 = write_any ? _1338 : _21;
    assign _1340 = _84 ? _1341 : _1339;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            sticky_val_q <= _1341;
        else
            sticky_val_q <= _1340;
    end
    assign _21 = sticky_val_q;
    assign _1345 = ~ _24;
    assign _1346 = _1171 & _1345;
    assign _1347 = { _1346,
                     _1346 };
    assign _1348 = { _1347,
                     _1347 };
    assign _1349 = { _1348,
                     _1348 };
    assign _1350 = { _1349,
                     _1349 };
    assign _1351 = { _1350,
                     _1350 };
    assign _1352 = _1351 & _21;
    assign lvl_eff_val = write_any ? lvl_new_val : _1352;
    assign _1357 = lvl_eff_val & _1356;
    assign _1343 = ~ _1149;
    assign _1032 = _1030[31:16];
    assign _1031 = _1030[15:0];
    assign _1033 = { _1031,
                     _1032 };
    assign _1028 = _1026[31:24];
    assign _1027 = _1026[23:0];
    assign _1029 = { _1027,
                     _1028 };
    assign _1024 = _1022[31:28];
    assign _1023 = _1022[27:0];
    assign _1025 = { _1023,
                     _1024 };
    assign _1020 = _1018[31:30];
    assign _1019 = _1018[29:0];
    assign _1021 = { _1019,
                     _1020 };
    assign _1016 = _1014[31:31];
    assign _1015 = _1014[30:0];
    assign _1017 = { _1015,
                     _1016 };
    assign _1013 = _110[16:12];
    assign _1012 = 27'b000000000000000000000000000;
    assign _1014 = { _1012,
                     _1013 };
    assign _1011 = _1006[0:0];
    assign _1018 = _1011 ? _1017 : _1014;
    assign _1010 = _1006[1:1];
    assign _1022 = _1010 ? _1021 : _1018;
    assign _1009 = _1006[2:2];
    assign _1026 = _1009 ? _1025 : _1022;
    assign _1008 = _1006[3:3];
    assign _1030 = _1008 ? _1029 : _1026;
    assign _1007 = _1006[4:4];
    assign _1034 = _1007 ? _1033 : _1030;
    assign ss_val = _1034 & ss_mask;
    assign ss_lvl_val = ss_val & _1343;
    assign lvl_val_out = ss_lvl_val | _1357;
    assign _1324 = { dir_write_now,
                     dir_write_now };
    assign _1325 = { _1324,
                     _1324 };
    assign _1326 = { _1325,
                     _1325 };
    assign _1327 = { _1326,
                     _1326 };
    assign _1328 = { _1327,
                     _1327 };
    assign dir_new_mask = _1328 & pin_mask;
    assign _1307 = _1305[31:16];
    assign _1306 = _1305[15:0];
    assign _1308 = { _1306,
                     _1307 };
    assign _1303 = _1301[31:24];
    assign _1302 = _1301[23:0];
    assign _1304 = { _1302,
                     _1303 };
    assign _1299 = _1297[31:28];
    assign _1298 = _1297[27:0];
    assign _1300 = { _1298,
                     _1299 };
    assign _1295 = _1293[31:30];
    assign _1294 = _1293[29:0];
    assign _1296 = { _1294,
                     _1295 };
    assign _1291 = _1289[31:31];
    assign _1290 = _1289[30:0];
    assign _1292 = { _1290,
                     _1291 };
    assign _1287 = 6'b000000;
    assign _1288 = _1287 < _1225;
    assign _1285 = 6'b000001;
    assign _1286 = _1285 < _1225;
    assign _1283 = 6'b000010;
    assign _1284 = _1283 < _1225;
    assign _1281 = 6'b000011;
    assign _1282 = _1281 < _1225;
    assign _1279 = 6'b000100;
    assign _1280 = _1279 < _1225;
    assign _1277 = 6'b000101;
    assign _1278 = _1277 < _1225;
    assign _1275 = 6'b000110;
    assign _1276 = _1275 < _1225;
    assign _1273 = 6'b000111;
    assign _1274 = _1273 < _1225;
    assign _1271 = 6'b001000;
    assign _1272 = _1271 < _1225;
    assign _1269 = 6'b001001;
    assign _1270 = _1269 < _1225;
    assign _1267 = 6'b001010;
    assign _1268 = _1267 < _1225;
    assign _1265 = 6'b001011;
    assign _1266 = _1265 < _1225;
    assign _1263 = 6'b001100;
    assign _1264 = _1263 < _1225;
    assign _1261 = 6'b001101;
    assign _1262 = _1261 < _1225;
    assign _1259 = 6'b001110;
    assign _1260 = _1259 < _1225;
    assign _1257 = 6'b001111;
    assign _1258 = _1257 < _1225;
    assign _1255 = 6'b010000;
    assign _1256 = _1255 < _1225;
    assign _1253 = 6'b010001;
    assign _1254 = _1253 < _1225;
    assign _1251 = 6'b010010;
    assign _1252 = _1251 < _1225;
    assign _1249 = 6'b010011;
    assign _1250 = _1249 < _1225;
    assign _1247 = 6'b010100;
    assign _1248 = _1247 < _1225;
    assign _1245 = 6'b010101;
    assign _1246 = _1245 < _1225;
    assign _1243 = 6'b010110;
    assign _1244 = _1243 < _1225;
    assign _1241 = 6'b010111;
    assign _1242 = _1241 < _1225;
    assign _1239 = 6'b011000;
    assign _1240 = _1239 < _1225;
    assign _1237 = 6'b011001;
    assign _1238 = _1237 < _1225;
    assign _1235 = 6'b011010;
    assign _1236 = _1235 < _1225;
    assign _1233 = 6'b011011;
    assign _1234 = _1233 < _1225;
    assign _1231 = 6'b011100;
    assign _1232 = _1231 < _1225;
    assign _1229 = 6'b011101;
    assign _1230 = _1229 < _1225;
    assign _1227 = 6'b011110;
    assign _1228 = _1227 < _1225;
    assign _1223 = _61[28:26];
    assign _1224 = { _442,
                     _1223 };
    assign _1221 = _61[25:20];
    assign _1225 = set_write ? _1224 : _1221;
    assign _1220 = 6'b011111;
    assign _1226 = _1220 < _1225;
    assign _1289 = { _1226,
                     _1228,
                     _1230,
                     _1232,
                     _1234,
                     _1236,
                     _1238,
                     _1240,
                     _1242,
                     _1244,
                     _1246,
                     _1248,
                     _1250,
                     _1252,
                     _1254,
                     _1256,
                     _1258,
                     _1260,
                     _1262,
                     _1264,
                     _1266,
                     _1268,
                     _1270,
                     _1272,
                     _1274,
                     _1276,
                     _1278,
                     _1280,
                     _1282,
                     _1284,
                     _1286,
                     _1288 };
    assign _1219 = _1187[0:0];
    assign _1293 = _1219 ? _1292 : _1289;
    assign _1218 = _1187[1:1];
    assign _1297 = _1218 ? _1296 : _1293;
    assign _1217 = _1187[2:2];
    assign _1301 = _1217 ? _1300 : _1297;
    assign _1216 = _1187[3:3];
    assign _1305 = _1216 ? _1304 : _1301;
    assign _1186 = _61[9:5];
    assign _1185 = _61[4:0];
    assign set_write = set_pins | set_dirs;
    assign _1187 = set_write ? _1186 : _1185;
    assign _1215 = _1187[4:4];
    assign pin_mask = _1215 ? _1308 : _1305;
    assign _1359 = { lvl_write_now,
                     lvl_write_now };
    assign _1360 = { _1359,
                     _1359 };
    assign _1361 = { _1360,
                     _1360 };
    assign _1362 = { _1361,
                     _1361 };
    assign _1363 = { _1362,
                     _1362 };
    assign lvl_new_mask = _1363 & pin_mask;
    assign _1365 = dir_write_now ? dir_new_mask : lvl_new_mask;
    assign _1366 = write_any ? _1365 : _23;
    assign _1367 = _84 ? _1341 : _1366;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            sticky_mask_q <= _1341;
        else
            sticky_mask_q <= _1367;
    end
    assign _23 = sticky_mask_q;
    assign _1370 = write_any ? dir_write_now : _24;
    assign _1371 = _84 ? gnd : _1370;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            sticky_isdir_q <= gnd;
        else
            sticky_isdir_q <= _1371;
    end
    assign _24 = sticky_isdir_q;
    assign _1382 = ~ _24;
    assign _1170 = _55[17:17];
    assign _1171 = _1170 & _73;
    assign _1383 = _1171 & _1382;
    assign _1384 = { _1383,
                     _1383 };
    assign _1385 = { _1384,
                     _1384 };
    assign _1386 = { _1385,
                     _1385 };
    assign _1387 = { _1386,
                     _1386 };
    assign _1388 = { _1387,
                     _1387 };
    assign _1389 = _1388 & _23;
    assign _1166 = _901 == _963;
    assign set_dirs = _900 & _1166;
    assign _1163 = _380 == _963;
    assign out_dirs = out_run & _1163;
    assign dir_write_now = out_dirs | set_dirs;
    assign _1159 = _901 == _442;
    assign set_pins = _900 & _1159;
    assign _1155 = _388 == _442;
    assign mov_pins = _387 & _1155;
    assign _1152 = _380 == _442;
    assign out_pins = out_run & _1152;
    assign _1157 = out_pins | mov_pins;
    assign lvl_write_now = _1157 | set_pins;
    assign write_any = lvl_write_now | dir_write_now;
    assign lvl_eff_mask = write_any ? lvl_new_mask : _1389;
    assign _1144 = _55[29:29];
    assign _1145 = { _1144,
                     _1144 };
    assign _1146 = { _1145,
                     _1145 };
    assign _1147 = { _1146,
                     _1146 };
    assign _1148 = { _1147,
                     _1147 };
    assign _1149 = { _1148,
                     _1148 };
    assign _1354 = ~ _1149;
    assign _1135 = _110[11:11];
    assign _1374 = attempt_latch ? stall : _25;
    assign latch_ss_next = clr_latch_scope ? gnd : _1374;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_ss_q <= gnd;
        else
            latch_ss_q <= latch_ss_next;
    end
    assign _25 = latch_ss_q;
    assign _1130 = ~ page_chg;
    assign _1378 = attempt_imem ? stall : imem_ss_base;
    assign imem_ss_next = imem_clr ? gnd : _1378;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            imem_ss_q <= gnd;
        else
            imem_ss_q <= imem_ss_next;
    end
    assign _26 = imem_ss_q;
    assign imem_ss_base = _26 & _1130;
    assign ss_flag = _87 ? _25 : imem_ss_base;
    assign _1133 = ~ ss_flag;
    assign _1134 = attempt & _1133;
    assign ss_apply = _1134 & _1135;
    assign _1137 = { ss_apply,
                     ss_apply };
    assign _1138 = { _1137,
                     _1137 };
    assign _1139 = { _1138,
                     _1138 };
    assign _1140 = { _1139,
                     _1139 };
    assign _1141 = { _1140,
                     _1140 };
    assign _1127 = _1125[31:16];
    assign _1126 = _1125[15:0];
    assign _1128 = { _1126,
                     _1127 };
    assign _1123 = _1121[31:24];
    assign _1122 = _1121[23:0];
    assign _1124 = { _1122,
                     _1123 };
    assign _1119 = _1117[31:28];
    assign _1118 = _1117[27:0];
    assign _1120 = { _1118,
                     _1119 };
    assign _1115 = _1113[31:30];
    assign _1114 = _1113[29:0];
    assign _1116 = { _1114,
                     _1115 };
    assign _1111 = _1109[31:31];
    assign _1110 = _1109[30:0];
    assign _1112 = { _1110,
                     _1111 };
    assign _1108 = _1287 < ss_nbits;
    assign _1106 = _1285 < ss_nbits;
    assign _1104 = _1283 < ss_nbits;
    assign _1102 = _1281 < ss_nbits;
    assign _1100 = _1279 < ss_nbits;
    assign _1098 = _1277 < ss_nbits;
    assign _1096 = _1275 < ss_nbits;
    assign _1094 = _1273 < ss_nbits;
    assign _1092 = _1271 < ss_nbits;
    assign _1090 = _1269 < ss_nbits;
    assign _1088 = _1267 < ss_nbits;
    assign _1086 = _1265 < ss_nbits;
    assign _1084 = _1263 < ss_nbits;
    assign _1082 = _1261 < ss_nbits;
    assign _1080 = _1259 < ss_nbits;
    assign _1078 = _1257 < ss_nbits;
    assign _1076 = _1255 < ss_nbits;
    assign _1074 = _1253 < ss_nbits;
    assign _1072 = _1251 < ss_nbits;
    assign _1070 = _1249 < ss_nbits;
    assign _1068 = _1247 < ss_nbits;
    assign _1066 = _1245 < ss_nbits;
    assign _1064 = _1243 < ss_nbits;
    assign _1062 = _1241 < ss_nbits;
    assign _1060 = _1239 < ss_nbits;
    assign _1058 = _1237 < ss_nbits;
    assign _1056 = _1235 < ss_nbits;
    assign _1054 = _1233 < ss_nbits;
    assign _1052 = _1231 < ss_nbits;
    assign _1050 = _1229 < ss_nbits;
    assign _1048 = _1227 < ss_nbits;
    assign _1043 = 5'b00000;
    assign _1044 = { _1043,
                     _108 };
    assign _1042 = { _442,
                     _107 };
    assign ss_nbits = _1042 - _1044;
    assign _1046 = _1220 < ss_nbits;
    assign _1109 = { _1046,
                     _1048,
                     _1050,
                     _1052,
                     _1054,
                     _1056,
                     _1058,
                     _1060,
                     _1062,
                     _1064,
                     _1066,
                     _1068,
                     _1070,
                     _1072,
                     _1074,
                     _1076,
                     _1078,
                     _1080,
                     _1082,
                     _1084,
                     _1086,
                     _1088,
                     _1090,
                     _1092,
                     _1094,
                     _1096,
                     _1098,
                     _1100,
                     _1102,
                     _1104,
                     _1106,
                     _1108 };
    assign _1039 = _1006[0:0];
    assign _1113 = _1039 ? _1112 : _1109;
    assign _1038 = _1006[1:1];
    assign _1117 = _1038 ? _1116 : _1113;
    assign _1037 = _1006[2:2];
    assign _1121 = _1037 ? _1120 : _1117;
    assign _1036 = _1006[3:3];
    assign _1125 = _1036 ? _1124 : _1121;
    assign _1006 = _61[14:10];
    assign _1035 = _1006[4:4];
    assign _1129 = _1035 ? _1128 : _1125;
    assign ss_mask = _1129 & _1141;
    assign ss_lvl_mask = ss_mask & _1354;
    assign lvl_mask_out = ss_lvl_mask | lvl_eff_mask;
    assign _1404 = word[4:0];
    assign _1402 = out_data[4:0];
    assign _1401 = mov_data[4:0];
    assign _1403 = out_pc ? _1402 : _1401;
    assign pc_target = jmp_taken ? _1404 : _1403;
    assign _1398 = _55[11:7];
    assign _1396 = 5'b00001;
    assign _1397 = _28 + _1396;
    assign _1394 = _55[16:12];
    assign _1395 = _28 == _1394;
    assign pc_adv = _1395 ? _1398 : _1397;
    assign _28 = pc_q;
    assign _1392 = ~ stall;
    assign imem_done = attempt_imem & _1392;
    assign _1400 = imem_done ? pc_adv : _28;
    assign _390 = _388 == _960;
    assign mov_pc = _387 & _390;
    assign _382 = _380 == _960;
    assign out_pc = out_run & _382;
    assign _375 = _76 < _147;
    assign _373 = _59[31:31];
    assign _372 = _59[30:30];
    assign _371 = _59[29:29];
    assign _370 = _59[28:28];
    assign _369 = _59[27:27];
    assign _368 = _59[26:26];
    assign _367 = _59[25:25];
    assign _366 = _59[24:24];
    assign _365 = _59[23:23];
    assign _364 = _59[22:22];
    assign _363 = _59[21:21];
    assign _362 = _59[20:20];
    assign _361 = _59[19:19];
    assign _360 = _59[18:18];
    assign _359 = _59[17:17];
    assign _358 = _59[16:16];
    assign _357 = _59[15:15];
    assign _356 = _59[14:14];
    assign _355 = _59[13:13];
    assign _354 = _59[12:12];
    assign _353 = _59[11:11];
    assign _352 = _59[10:10];
    assign _351 = _59[9:9];
    assign _350 = _59[8:8];
    assign _349 = _59[7:7];
    assign _348 = _59[6:6];
    assign _347 = _59[5:5];
    assign _346 = _59[4:4];
    assign _345 = _59[3:3];
    assign _344 = _59[2:2];
    assign _343 = _59[1:1];
    assign _342 = _59[0:0];
    assign _341 = _55[28:24];
    always @* begin
        case (_341)
        0:
            _374 <= _342;
        1:
            _374 <= _343;
        2:
            _374 <= _344;
        3:
            _374 <= _345;
        4:
            _374 <= _346;
        5:
            _374 <= _347;
        6:
            _374 <= _348;
        7:
            _374 <= _349;
        8:
            _374 <= _350;
        9:
            _374 <= _351;
        10:
            _374 <= _352;
        11:
            _374 <= _353;
        12:
            _374 <= _354;
        13:
            _374 <= _355;
        14:
            _374 <= _356;
        15:
            _374 <= _357;
        16:
            _374 <= _358;
        17:
            _374 <= _359;
        18:
            _374 <= _360;
        19:
            _374 <= _361;
        20:
            _374 <= _362;
        21:
            _374 <= _363;
        22:
            _374 <= _364;
        23:
            _374 <= _365;
        24:
            _374 <= _366;
        25:
            _374 <= _367;
        26:
            _374 <= _368;
        27:
            _374 <= _369;
        28:
            _374 <= _370;
        29:
            _374 <= _371;
        30:
            _374 <= _372;
        default:
            _374 <= _373;
        endcase
    end
    assign _339 = _57 == _56;
    assign _340 = ~ _339;
    assign _338 = ~ _337;
    assign _337 = _56 == _1341;
    assign _335 = ~ _334;
    assign _334 = _57 == _1341;
    always @* begin
        case (_332)
        0:
            jmp_cond_val <= vdd;
        1:
            jmp_cond_val <= _334;
        2:
            jmp_cond_val <= _335;
        3:
            jmp_cond_val <= _337;
        4:
            jmp_cond_val <= _338;
        5:
            jmp_cond_val <= _340;
        6:
            jmp_cond_val <= _374;
        default:
            jmp_cond_val <= _375;
        endcase
    end
    assign _330 = _110[1:1];
    assign _93 = ~ _29;
    assign _94 = _87 & _93;
    assign _97 = _94 & tick_en;
    assign _100 = _97 & delay_zero;
    assign _1410 = exec_set ? gnd : _29;
    assign latch_forced_next = _86 ? vdd : _1410;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_forced_q <= gnd;
        else
            latch_forced_q <= latch_forced_next;
    end
    assign _29 = latch_forced_q;
    assign _1414 = attempt_latch ? irq_stall : _30;
    assign _422 = _84 | _86;
    assign clr_latch_scope = _422 | exec_set;
    assign latch_irqw_next = clr_latch_scope ? gnd : _1414;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_irqw_q <= gnd;
        else
            latch_irqw_q <= latch_irqw_next;
    end
    assign _30 = latch_irqw_q;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            page_prev_q <= gnd;
        else
            page_prev_q <= _33;
    end
    assign _31 = page_prev_q;
    assign _33 = page;
    assign page_chg = _33 ^ _31;
    assign _315 = ~ page_chg;
    assign _1434 = _34 - _1396;
    assign _1429 = _110[21:17];
    assign exec_form = out_exec | mov_exec;
    assign _1431 = exec_form ? _1043 : _1429;
    assign _1426 = ~ forced_act;
    assign _1424 = ~ stall;
    assign complete = attempt & _1424;
    assign _1427 = complete & _1426;
    assign _1432 = _1427 ? _1431 : _34;
    assign _1422 = ~ delay_zero;
    assign _1420 = ~ forced_act;
    assign _1421 = tick_en & _1420;
    assign dec_now = _1421 & _1422;
    assign delay_next = dec_now ? _1434 : _1432;
    assign _1437 = _84 ? _1043 : delay_next;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            delay_q <= _1043;
        else
            delay_q <= _1437;
    end
    assign _34 = delay_q;
    assign delay_zero = _34 == _1043;
    assign _102 = ~ _87;
    assign _103 = _102 & tick_en;
    assign attempt_imem = _103 & delay_zero;
    assign _1441 = attempt_imem ? irq_stall : imem_irqw_base;
    assign _36 = imem_abandon;
    assign pc_write_latch = latch_done & pc_write_now;
    assign _394 = _84 | pc_write_latch;
    assign imem_clr = _394 | _36;
    assign imem_irqw_next = imem_clr ? gnd : _1441;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            imem_irqw_q <= gnd;
        else
            imem_irqw_q <= imem_irqw_next;
    end
    assign _37 = imem_irqw_q;
    assign imem_irqw_base = _37 & _315;
    assign irq_state = _87 ? _30 : imem_irqw_base;
    assign _318 = ~ irq_state;
    assign _319 = _318 | flag_val;
    assign _312 = word[5:5];
    assign _309 = word[6:6];
    assign _310 = ~ _309;
    assign _307 = _110[8:8];
    assign _306 = attempt & ok;
    assign _308 = _306 & _307;
    assign irq_set_form = _308 & _310;
    assign irqw_form = irq_set_form & _312;
    assign irq_stall = irqw_form & _319;
    assign _301 = word[7:7];
    assign _297 = _39[7:7];
    assign _296 = _39[6:6];
    assign _295 = _39[5:5];
    assign _294 = _39[4:4];
    assign _293 = _39[3:3];
    assign _292 = _39[2:2];
    assign _291 = _39[1:1];
    assign _39 = irq_q;
    assign _290 = _39[0:0];
    assign _41 = sm_num;
    assign _286 = _284[1:0];
    assign _287 = _286 + _41;
    assign _285 = _284[2:2];
    assign _288 = { _285,
                    _287 };
    assign _284 = word[2:0];
    assign _283 = word[4:4];
    assign flag_idx = _283 ? _288 : _284;
    always @* begin
        case (flag_idx)
        0:
            flag_val <= _290;
        1:
            flag_val <= _291;
        2:
            flag_val <= _292;
        3:
            flag_val <= _293;
        4:
            flag_val <= _294;
        5:
            flag_val <= _295;
        6:
            flag_val <= _296;
        default:
            flag_val <= _297;
        endcase
    end
    assign _281 = _249[31:31];
    assign _280 = _249[30:30];
    assign _279 = _249[29:29];
    assign _278 = _249[28:28];
    assign _277 = _249[27:27];
    assign _276 = _249[26:26];
    assign _275 = _249[25:25];
    assign _274 = _249[24:24];
    assign _273 = _249[23:23];
    assign _272 = _249[22:22];
    assign _271 = _249[21:21];
    assign _270 = _249[20:20];
    assign _269 = _249[19:19];
    assign _268 = _249[18:18];
    assign _267 = _249[17:17];
    assign _266 = _249[16:16];
    assign _265 = _249[15:15];
    assign _264 = _249[14:14];
    assign _263 = _249[13:13];
    assign _262 = _249[12:12];
    assign _261 = _249[11:11];
    assign _260 = _249[10:10];
    assign _259 = _249[9:9];
    assign _258 = _249[8:8];
    assign _257 = _249[7:7];
    assign _256 = _249[6:6];
    assign _255 = _249[5:5];
    assign _254 = _249[4:4];
    assign _253 = _249[3:3];
    assign _252 = _249[2:2];
    assign _251 = _249[1:1];
    assign _250 = _249[0:0];
    always @* begin
        case (_190)
        0:
            _282 <= _250;
        1:
            _282 <= _251;
        2:
            _282 <= _252;
        3:
            _282 <= _253;
        4:
            _282 <= _254;
        5:
            _282 <= _255;
        6:
            _282 <= _256;
        7:
            _282 <= _257;
        8:
            _282 <= _258;
        9:
            _282 <= _259;
        10:
            _282 <= _260;
        11:
            _282 <= _261;
        12:
            _282 <= _262;
        13:
            _282 <= _263;
        14:
            _282 <= _264;
        15:
            _282 <= _265;
        16:
            _282 <= _266;
        17:
            _282 <= _267;
        18:
            _282 <= _268;
        19:
            _282 <= _269;
        20:
            _282 <= _270;
        21:
            _282 <= _271;
        22:
            _282 <= _272;
        23:
            _282 <= _273;
        24:
            _282 <= _274;
        25:
            _282 <= _275;
        26:
            _282 <= _276;
        27:
            _282 <= _277;
        28:
            _282 <= _278;
        29:
            _282 <= _279;
        30:
            _282 <= _280;
        default:
            _282 <= _281;
        endcase
    end
    assign _222 = _59[31:31];
    assign _221 = _59[30:30];
    assign _220 = _59[29:29];
    assign _219 = _59[28:28];
    assign _218 = _59[27:27];
    assign _217 = _59[26:26];
    assign _216 = _59[25:25];
    assign _215 = _59[24:24];
    assign _214 = _59[23:23];
    assign _213 = _59[22:22];
    assign _212 = _59[21:21];
    assign _211 = _59[20:20];
    assign _210 = _59[19:19];
    assign _209 = _59[18:18];
    assign _208 = _59[17:17];
    assign _207 = _59[16:16];
    assign _206 = _59[15:15];
    assign _205 = _59[14:14];
    assign _204 = _59[13:13];
    assign _203 = _59[12:12];
    assign _202 = _59[11:11];
    assign _201 = _59[10:10];
    assign _200 = _59[9:9];
    assign _199 = _59[8:8];
    assign _198 = _59[7:7];
    assign _197 = _59[6:6];
    assign _196 = _59[5:5];
    assign _195 = _59[4:4];
    assign _194 = _59[3:3];
    assign _193 = _59[2:2];
    assign _192 = _59[1:1];
    assign _191 = _59[0:0];
    assign _190 = word[4:0];
    always @* begin
        case (_190)
        0:
            _223 <= _191;
        1:
            _223 <= _192;
        2:
            _223 <= _193;
        3:
            _223 <= _194;
        4:
            _223 <= _195;
        5:
            _223 <= _196;
        6:
            _223 <= _197;
        7:
            _223 <= _198;
        8:
            _223 <= _199;
        9:
            _223 <= _200;
        10:
            _223 <= _201;
        11:
            _223 <= _202;
        12:
            _223 <= _203;
        13:
            _223 <= _204;
        14:
            _223 <= _205;
        15:
            _223 <= _206;
        16:
            _223 <= _207;
        17:
            _223 <= _208;
        18:
            _223 <= _209;
        19:
            _223 <= _210;
        20:
            _223 <= _211;
        21:
            _223 <= _212;
        22:
            _223 <= _213;
        23:
            _223 <= _214;
        24:
            _223 <= _215;
        25:
            _223 <= _216;
        26:
            _223 <= _217;
        27:
            _223 <= _218;
        28:
            _223 <= _219;
        29:
            _223 <= _220;
        30:
            _223 <= _221;
        default:
            _223 <= _222;
        endcase
    end
    assign _189 = word[6:5];
    always @* begin
        case (_189)
        0:
            wait_bit <= _223;
        1:
            wait_bit <= _282;
        2:
            wait_bit <= flag_val;
        default:
            wait_bit <= vdd;
        endcase
    end
    assign wait_cond = wait_bit == _301;
    assign _303 = ~ wait_cond;
    assign _187 = _110[2:2];
    assign _186 = attempt & ok;
    assign _188 = _186 & _187;
    assign wait_stall = _188 & _303;
    assign _175 = _160 & in_thr_hit;
    assign in_stall = _175 & _47;
    assign _154 = pull_try & _75;
    assign pull_stall = _154 & _155;
    assign _132 = push_try & _131;
    assign push_stall = _132 & _47;
    assign _157 = push_stall | pull_stall;
    assign _177 = _157 | in_stall;
    assign _185 = _177 | out_hit;
    assign _305 = _185 | wait_stall;
    assign stall = _305 | irq_stall;
    assign _327 = ~ stall;
    assign latch_done = attempt_latch & _327;
    assign _1478 = latch_done ? gnd : _87;
    assign _424 = _380 == _954;
    assign _378 = ~ autopull_hit;
    assign _179 = _110[4:4];
    assign _112 = _110[10:10];
    assign _113 = ~ _112;
    assign _108 = _55[30:30];
    assign _107 = _61[31:29];
    assign _1476 = 16'b0000000000000000;
    assign _43 = instr_data;
    assign _1471 = mov_data[15:0];
    assign _879 = _1287 < _163;
    assign _877 = _1285 < _163;
    assign _875 = _1283 < _163;
    assign _873 = _1281 < _163;
    assign _871 = _1279 < _163;
    assign _869 = _1277 < _163;
    assign _867 = _1275 < _163;
    assign _865 = _1273 < _163;
    assign _863 = _1271 < _163;
    assign _861 = _1269 < _163;
    assign _859 = _1267 < _163;
    assign _857 = _1265 < _163;
    assign _855 = _1263 < _163;
    assign _853 = _1261 < _163;
    assign _851 = _1259 < _163;
    assign _849 = _1257 < _163;
    assign _847 = _1255 < _163;
    assign _845 = _1253 < _163;
    assign _843 = _1251 < _163;
    assign _841 = _1249 < _163;
    assign _839 = _1247 < _163;
    assign _837 = _1245 < _163;
    assign _835 = _1243 < _163;
    assign _833 = _1241 < _163;
    assign _831 = _1239 < _163;
    assign _829 = _1237 < _163;
    assign _827 = _1235 < _163;
    assign _825 = _1233 < _163;
    assign _823 = _1231 < _163;
    assign _821 = _1229 < _163;
    assign _819 = _1227 < _163;
    assign _817 = _1220 < _163;
    assign _880 = { _817,
                    _819,
                    _821,
                    _823,
                    _825,
                    _827,
                    _829,
                    _831,
                    _833,
                    _835,
                    _837,
                    _839,
                    _841,
                    _843,
                    _845,
                    _847,
                    _849,
                    _851,
                    _853,
                    _855,
                    _857,
                    _859,
                    _861,
                    _863,
                    _865,
                    _867,
                    _869,
                    _871,
                    _873,
                    _875,
                    _877,
                    _879 };
    assign _881 = _77 & _880;
    assign _812 = _810[31:16];
    assign _813 = { _1476,
                    _812 };
    assign _808 = _806[31:8];
    assign _807 = 8'b00000000;
    assign _809 = { _807,
                    _808 };
    assign _804 = _802[31:4];
    assign _805 = { _420,
                    _804 };
    assign _800 = _798[31:2];
    assign _801 = { _444,
                    _800 };
    assign _796 = _77[31:1];
    assign _797 = { _325,
                    _796 };
    assign _45 = tx_head;
    assign _595 = _593[31:16];
    assign _596 = { _1476,
                    _595 };
    assign _591 = _589[31:8];
    assign _592 = { _807,
                    _591 };
    assign _587 = _585[31:4];
    assign _588 = { _420,
                    _587 };
    assign _583 = _581[31:2];
    assign _584 = { _444,
                    _583 };
    assign _579 = _77[31:1];
    assign _580 = { _325,
                    _579 };
    assign _577 = _572[0:0];
    assign _581 = _577 ? _580 : _77;
    assign _576 = _572[1:1];
    assign _585 = _576 ? _584 : _581;
    assign _575 = _572[2:2];
    assign _589 = _575 ? _588 : _585;
    assign _574 = _572[3:3];
    assign _593 = _574 ? _592 : _589;
    assign _572 = _163[4:0];
    assign _573 = _572[4:4];
    assign _597 = _573 ? _596 : _593;
    assign _570 = 6'b100000;
    assign _571 = _163 == _570;
    assign _598 = _571 ? _1341 : _597;
    assign _565 = _564[15:0];
    assign _567 = { _565,
                    _1476 };
    assign _561 = _560[23:0];
    assign _563 = { _561,
                    _807 };
    assign _557 = _556[27:0];
    assign _559 = { _557,
                    _420 };
    assign _553 = _552[29:0];
    assign _555 = { _553,
                    _444 };
    assign _549 = _77[30:0];
    assign _551 = { _549,
                    _325 };
    assign _548 = _543[0:0];
    assign _552 = _548 ? _551 : _77;
    assign _547 = _543[1:1];
    assign _556 = _547 ? _555 : _552;
    assign _546 = _543[2:2];
    assign _560 = _546 ? _559 : _556;
    assign _545 = _543[3:3];
    assign _564 = _545 ? _563 : _560;
    assign _543 = _163[4:0];
    assign _544 = _543[4:4];
    assign _568 = _544 ? _567 : _564;
    assign _542 = _163 == _570;
    assign _569 = _542 ? _1341 : _568;
    assign osr_shifted = _540 ? _598 : _569;
    assign _535 = mov_src_val[31:31];
    assign _534 = mov_src_val[30:30];
    assign _533 = mov_src_val[29:29];
    assign _532 = mov_src_val[28:28];
    assign _531 = mov_src_val[27:27];
    assign _530 = mov_src_val[26:26];
    assign _529 = mov_src_val[25:25];
    assign _528 = mov_src_val[24:24];
    assign _527 = mov_src_val[23:23];
    assign _526 = mov_src_val[22:22];
    assign _525 = mov_src_val[21:21];
    assign _524 = mov_src_val[20:20];
    assign _523 = mov_src_val[19:19];
    assign _522 = mov_src_val[18:18];
    assign _521 = mov_src_val[17:17];
    assign _520 = mov_src_val[16:16];
    assign _519 = mov_src_val[15:15];
    assign _518 = mov_src_val[14:14];
    assign _517 = mov_src_val[13:13];
    assign _516 = mov_src_val[12:12];
    assign _515 = mov_src_val[11:11];
    assign _514 = mov_src_val[10:10];
    assign _513 = mov_src_val[9:9];
    assign _512 = mov_src_val[8:8];
    assign _511 = mov_src_val[7:7];
    assign _510 = mov_src_val[6:6];
    assign _509 = mov_src_val[5:5];
    assign _508 = mov_src_val[4:4];
    assign _507 = mov_src_val[3:3];
    assign _506 = mov_src_val[2:2];
    assign _505 = mov_src_val[1:1];
    assign _504 = mov_src_val[0:0];
    assign _536 = { _504,
                    _505,
                    _506,
                    _507,
                    _508,
                    _509,
                    _510,
                    _511,
                    _512,
                    _513,
                    _514,
                    _515,
                    _516,
                    _517,
                    _518,
                    _519,
                    _520,
                    _521,
                    _522,
                    _523,
                    _524,
                    _525,
                    _526,
                    _527,
                    _528,
                    _529,
                    _530,
                    _531,
                    _532,
                    _533,
                    _534,
                    _535 };
    assign _503 = ~ mov_src_val;
    assign _776 = _775[15:0];
    assign _778 = { _776,
                    _1476 };
    assign _772 = _771[23:0];
    assign _774 = { _772,
                    _807 };
    assign _768 = _767[27:0];
    assign _770 = { _768,
                    _420 };
    assign _764 = _763[29:0];
    assign _766 = { _764,
                    _444 };
    assign _760 = in_data[30:0];
    assign _762 = { _760,
                    _325 };
    assign _759 = _754[0:0];
    assign _763 = _759 ? _762 : in_data;
    assign _758 = _754[1:1];
    assign _767 = _758 ? _766 : _763;
    assign _757 = _754[2:2];
    assign _771 = _757 ? _770 : _767;
    assign _756 = _754[3:3];
    assign _775 = _756 ? _774 : _771;
    assign _754 = _751[4:0];
    assign _755 = _754[4:4];
    assign _779 = _755 ? _778 : _775;
    assign _751 = _570 - _163;
    assign _753 = _751 == _570;
    assign _780 = _753 ? _1341 : _779;
    assign _746 = _744[31:16];
    assign _747 = { _1476,
                    _746 };
    assign _742 = _740[31:8];
    assign _743 = { _807,
                    _742 };
    assign _738 = _736[31:4];
    assign _739 = { _420,
                    _738 };
    assign _734 = _732[31:2];
    assign _735 = { _444,
                    _734 };
    assign _730 = _49[31:1];
    assign _731 = { _325,
                    _730 };
    assign _728 = _723[0:0];
    assign _732 = _728 ? _731 : _49;
    assign _727 = _723[1:1];
    assign _736 = _727 ? _735 : _732;
    assign _726 = _723[2:2];
    assign _740 = _726 ? _739 : _736;
    assign _725 = _723[3:3];
    assign _744 = _725 ? _743 : _740;
    assign _723 = _163[4:0];
    assign _724 = _723[4:4];
    assign _748 = _724 ? _747 : _744;
    assign _722 = _163 == _570;
    assign _749 = _722 ? _1341 : _748;
    assign _781 = _749 | _780;
    assign _717 = _1287 < _163;
    assign _715 = _1285 < _163;
    assign _713 = _1283 < _163;
    assign _711 = _1281 < _163;
    assign _709 = _1279 < _163;
    assign _707 = _1277 < _163;
    assign _705 = _1275 < _163;
    assign _703 = _1273 < _163;
    assign _701 = _1271 < _163;
    assign _699 = _1269 < _163;
    assign _697 = _1267 < _163;
    assign _695 = _1265 < _163;
    assign _693 = _1263 < _163;
    assign _691 = _1261 < _163;
    assign _689 = _1259 < _163;
    assign _687 = _1257 < _163;
    assign _685 = _1255 < _163;
    assign _683 = _1253 < _163;
    assign _681 = _1251 < _163;
    assign _679 = _1249 < _163;
    assign _677 = _1247 < _163;
    assign _675 = _1245 < _163;
    assign _673 = _1243 < _163;
    assign _671 = _1241 < _163;
    assign _669 = _1239 < _163;
    assign _667 = _1237 < _163;
    assign _665 = _1235 < _163;
    assign _663 = _1233 < _163;
    assign _661 = _1231 < _163;
    assign _659 = _1229 < _163;
    assign _657 = _1227 < _163;
    assign _655 = _1220 < _163;
    assign _718 = { _655,
                    _657,
                    _659,
                    _661,
                    _663,
                    _665,
                    _667,
                    _669,
                    _671,
                    _673,
                    _675,
                    _677,
                    _679,
                    _681,
                    _683,
                    _685,
                    _687,
                    _689,
                    _691,
                    _693,
                    _695,
                    _697,
                    _699,
                    _701,
                    _703,
                    _705,
                    _707,
                    _709,
                    _711,
                    _713,
                    _715,
                    _717 };
    assign _652 = word[7:5];
    always @* begin
        case (_652)
        0:
            _653 <= _249;
        1:
            _653 <= _57;
        2:
            _653 <= _56;
        3:
            _653 <= _1341;
        4:
            _653 <= _1341;
        5:
            _653 <= _1341;
        6:
            _653 <= _49;
        default:
            _653 <= _77;
        endcase
    end
    assign in_data = _653 & _718;
    assign _647 = _646[15:0];
    assign _649 = { _647,
                    _1476 };
    assign _643 = _642[23:0];
    assign _645 = { _643,
                    _807 };
    assign _639 = _638[27:0];
    assign _641 = { _639,
                    _420 };
    assign _635 = _634[29:0];
    assign _637 = { _635,
                    _444 };
    assign _631 = _49[30:0];
    assign _633 = { _631,
                    _325 };
    assign _630 = _625[0:0];
    assign _634 = _630 ? _633 : _49;
    assign _629 = _625[1:1];
    assign _638 = _629 ? _637 : _634;
    assign _628 = _625[2:2];
    assign _642 = _628 ? _641 : _638;
    assign _627 = _625[3:3];
    assign _646 = _627 ? _645 : _642;
    assign _625 = _163[4:0];
    assign _626 = _625[4:4];
    assign _650 = _626 ? _649 : _646;
    assign _624 = _163 == _570;
    assign _651 = _624 ? _1341 : _650;
    assign _720 = _651 | in_data;
    assign _622 = _79[18:18];
    assign isr_new_in = _622 ? _781 : _720;
    assign _783 = in_shift ? isr_new_in : _49;
    assign _611 = ~ _47;
    assign _169 = _165[5:0];
    assign _166 = 7'b0100000;
    assign _164 = { gnd,
                    _163 };
    assign _620 = ~ in_thr_hit;
    assign in_shift = _160 & _620;
    assign _1446 = in_shift ? isr_cnt_new : _48;
    assign _616 = ~ _47;
    assign push_fire = push_try & _616;
    assign _47 = rx_full;
    assign _131 = word[5:5];
    assign _613 = ~ _131;
    assign _124 = { gnd,
                    _120 };
    assign _120 = _79[24:20];
    assign _122 = _120 == _1043;
    assign _126 = _122 ? _570 : _124;
    assign _127 = _48 < _126;
    assign _118 = word[6:6];
    assign _119 = _117 & _118;
    assign push_noop = _119 & _127;
    assign _129 = ~ push_noop;
    assign _116 = _110[5:5];
    assign _115 = attempt & ok;
    assign _117 = _115 & _116;
    assign push_try = _117 & _129;
    assign _614 = push_try & _613;
    assign push_drop = _614 & _47;
    assign push_clr = push_drop | push_fire;
    assign _1445 = in_push | push_clr;
    assign _1448 = _1445 ? _1287 : _1446;
    assign _1449 = out_isr ? _163 : _1448;
    assign isr_cnt_next = mov_isr ? _1287 : _1449;
    assign _1453 = _84 ? _1287 : isr_cnt_next;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            isr_cnt_q <= _1287;
        else
            isr_cnt_q <= _1453;
    end
    assign _48 = isr_cnt_q;
    assign _162 = { gnd,
                    _48 };
    assign _165 = _162 + _164;
    assign _167 = _165 < _166;
    assign _168 = ~ _167;
    assign isr_cnt_new = _168 ? _570 : _169;
    assign _172 = isr_cnt_new < _126;
    assign _173 = ~ _172;
    assign _161 = _79[16:16];
    assign in_thr_hit = _161 & _173;
    assign _159 = _110[3:3];
    assign _158 = attempt & ok;
    assign _160 = _158 & _159;
    assign _610 = _160 & in_thr_hit;
    assign in_push = _610 & _611;
    assign _619 = in_push | push_clr;
    assign _784 = _619 ? _1341 : _783;
    assign _608 = _380 == _957;
    assign out_isr = out_run & _608;
    assign _883 = out_isr ? out_data : _784;
    assign _605 = _388 == _957;
    assign mov_isr = _387 & _605;
    assign isr_next = mov_isr ? mov_data : _883;
    assign _886 = _84 ? _1341 : isr_next;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            isr_q <= _1341;
        else
            isr_q <= _886;
    end
    assign _49 = isr_q;
    assign _51 = rx_level;
    assign _495 = _51 < _493;
    assign _493 = _55[3:0];
    assign _53 = tx_level;
    assign _494 = _53 < _493;
    assign _55 = execctrl;
    assign _492 = _55[4:4];
    assign status_bit = _492 ? _495 : _494;
    assign _497 = { status_bit,
                    status_bit };
    assign _498 = { _497,
                    _497 };
    assign _499 = { _498,
                    _498 };
    assign _500 = { _499,
                    _499 };
    assign _501 = { _500,
                    _500 };
    assign _911 = 32'b00000000000000000000000000000001;
    assign _912 = _56 - _911;
    assign _903 = _901 == _969;
    assign set_y = _900 & _903;
    assign _908 = set_y ? _907 : _56;
    assign _896 = _380 == _969;
    assign out_y = out_run & _896;
    assign _909 = out_y ? out_data : _908;
    assign _893 = _388 == _969;
    assign mov_y = _387 & _893;
    assign _910 = mov_y ? mov_data : _909;
    assign _890 = _332 == _963;
    assign y_dec = _331 & _890;
    assign y_next = y_dec ? _912 : _910;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            y_q <= _1341;
        else
            y_q <= y_next;
    end
    assign _56 = y_q;
    assign _932 = _57 - _911;
    assign _906 = word[4:0];
    assign _907 = { _1012,
                    _906 };
    assign _901 = word[7:5];
    assign _926 = _901 == _972;
    assign _899 = _110[9:9];
    assign _898 = attempt & ok;
    assign _900 = _898 & _899;
    assign set_x = _900 & _926;
    assign _928 = set_x ? _907 : _57;
    assign _380 = word[7:5];
    assign _923 = _380 == _972;
    assign out_x = out_run & _923;
    assign _929 = out_x ? out_data : _928;
    assign _920 = _388 == _972;
    assign mov_x = _387 & _920;
    assign _930 = mov_x ? mov_data : _929;
    assign _332 = word[7:5];
    assign _917 = _332 == _969;
    assign x_dec = _331 & _917;
    assign x_next = x_dec ? _932 : _930;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            x_q <= _1341;
        else
            x_q <= x_next;
    end
    assign _57 = x_q;
    assign _247 = _245[31:16];
    assign _246 = _245[15:0];
    assign _248 = { _246,
                    _247 };
    assign _243 = _241[31:8];
    assign _242 = _241[7:0];
    assign _244 = { _242,
                    _243 };
    assign _239 = _237[31:4];
    assign _238 = _237[3:0];
    assign _240 = { _238,
                    _239 };
    assign _235 = _233[31:2];
    assign _234 = _233[1:0];
    assign _236 = { _234,
                    _235 };
    assign _231 = _59[31:1];
    assign _230 = _59[0:0];
    assign _232 = { _230,
                    _231 };
    assign _59 = in_sel;
    assign _229 = _224[0:0];
    assign _233 = _229 ? _232 : _59;
    assign _228 = _224[1:1];
    assign _237 = _228 ? _236 : _233;
    assign _227 = _224[2:2];
    assign _241 = _227 ? _240 : _237;
    assign _226 = _224[3:3];
    assign _245 = _226 ? _244 : _241;
    assign _61 = pinctrl;
    assign _224 = _61[19:15];
    assign _225 = _224[4:4];
    assign _249 = _225 ? _248 : _245;
    assign _490 = word[2:0];
    always @* begin
        case (_490)
        0:
            mov_src_val <= _249;
        1:
            mov_src_val <= _57;
        2:
            mov_src_val <= _56;
        3:
            mov_src_val <= _1341;
        4:
            mov_src_val <= _1341;
        5:
            mov_src_val <= _501;
        6:
            mov_src_val <= _49;
        default:
            mov_src_val <= _77;
        endcase
    end
    assign _489 = word[4:3];
    always @* begin
        case (_489)
        0:
            mov_data <= mov_src_val;
        1:
            mov_data <= _503;
        2:
            mov_data <= _536;
        default:
            mov_data <= mov_src_val;
        endcase
    end
    assign _538 = mov_osr ? mov_data : _77;
    assign _539 = pull_nb_empty ? _57 : _538;
    assign _600 = out_run ? osr_shifted : _539;
    assign _459 = ~ _75;
    assign _453 = _449[5:0];
    assign _448 = { gnd,
                    _163 };
    assign vdd = 1'b1;
    assign _1463 = out_refill_after ? _1287 : osr_cnt_after;
    assign _486 = ~ mov_osr;
    assign _481 = ~ pull_clr;
    assign _475 = ~ _75;
    assign _472 = _76 < _147;
    assign _473 = ~ _472;
    assign _470 = ~ _180;
    assign _468 = ~ forced_act;
    assign _63 = clkdiv_restart;
    assign _65 = clkdiv_frac;
    assign _67 = clkdiv_int;
    assign _69 = rst_n;
    assign _71 = clk;
    clkdiv_dbg
        clkdiv_dbg
        ( .clk(_71),
          .rst_n(_69),
          .int_(_67),
          .frac(_65),
          .restart(_63),
          .phase(_90[25:1]),
          .tick(_90[0:0]) );
    assign _95 = _90[0:0];
    assign _73 = enable;
    assign tick_en = _73 & _95;
    assign _467 = _137 & tick_en;
    assign _469 = _467 & _468;
    assign _471 = _469 & _470;
    assign _474 = _471 & _473;
    assign _476 = _474 & _475;
    assign _482 = _476 & _481;
    assign tx_pop_refill = _482 & _486;
    assign _484 = _388 == _954;
    assign mov_osr = _387 & _484;
    assign _155 = word[5:5];
    assign _478 = ~ _155;
    assign _477 = pull_try & _75;
    assign pull_nb_empty = _477 & _478;
    assign _464 = ~ _75;
    assign _148 = _76 < _147;
    assign _141 = word[6:6];
    assign _149 = _141 & _148;
    assign _139 = _76 == _1287;
    assign _140 = _137 & _139;
    assign _150 = _140 | _149;
    assign pull_noop = _136 & _150;
    assign _152 = ~ pull_noop;
    assign _135 = _110[6:6];
    assign _134 = attempt & ok;
    assign _136 = _134 & _135;
    assign pull_try = _136 & _152;
    assign pull_data = pull_try & _464;
    assign pull_clr = pull_data | pull_nb_empty;
    assign _75 = tx_empty;
    assign _461 = ~ _75;
    assign _145 = { gnd,
                    _142 };
    assign _142 = _79[29:25];
    assign _144 = _142 == _1043;
    assign _147 = _144 ? _570 : _145;
    assign _181 = _76 < _147;
    assign _182 = ~ _181;
    assign autopull_hit = _137 & _182;
    assign out_hit = _180 & autopull_hit;
    assign out_refill_stall = out_hit & _461;
    assign _1457 = out_refill_stall | pull_clr;
    assign _1458 = _1457 | mov_osr;
    assign _1459 = _1458 | tx_pop_refill;
    assign _1461 = _1459 ? _1287 : _76;
    assign osr_cnt_next = out_run ? _1463 : _1461;
    assign _1466 = _84 ? _570 : osr_cnt_next;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            osr_cnt_q <= _570;
        else
            osr_cnt_q <= _1466;
    end
    assign _76 = osr_cnt_q;
    assign gnd = 1'b0;
    assign _447 = { gnd,
                    _76 };
    assign _449 = _447 + _448;
    assign _451 = _449 < _166;
    assign _452 = ~ _451;
    assign osr_cnt_after = _452 ? _570 : _453;
    assign _456 = osr_cnt_after < _147;
    assign _457 = ~ _456;
    assign _137 = _79[17:17];
    assign _446 = out_run & _137;
    assign _458 = _446 & _457;
    assign out_refill_after = _458 & _459;
    assign _463 = out_refill_after | out_refill_stall;
    assign _466 = _463 | pull_data;
    assign _488 = _466 | tx_pop_refill;
    assign osr_next = _488 ? _45 : _600;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            osr_q <= _1341;
        else
            osr_q <= osr_next;
    end
    assign _77 = osr_q;
    assign _794 = _789[0:0];
    assign _798 = _794 ? _797 : _77;
    assign _793 = _789[1:1];
    assign _802 = _793 ? _801 : _798;
    assign _792 = _789[2:2];
    assign _806 = _792 ? _805 : _802;
    assign _791 = _789[3:3];
    assign _810 = _791 ? _809 : _806;
    assign _789 = _786[4:0];
    assign _790 = _789[4:4];
    assign _814 = _790 ? _813 : _810;
    assign _163 = _110[27:22];
    assign _786 = _570 - _163;
    assign _788 = _786 == _570;
    assign _815 = _788 ? _1341 : _814;
    assign _79 = shiftctrl;
    assign _540 = _79[19:19];
    assign out_data = _540 ? _881 : _815;
    assign _1470 = out_data[15:0];
    assign _388 = word[7:5];
    assign _427 = _388 == _963;
    assign _386 = _110[7:7];
    assign _385 = attempt & ok;
    assign _387 = _385 & _386;
    assign mov_exec = _387 & _427;
    assign exec_lo16 = mov_exec ? _1471 : _1470;
    assign _1473 = exec_set ? exec_lo16 : _80;
    assign latch_instr_next = _86 ? _43 : _1473;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_instr_q <= _1476;
        else
            latch_instr_q <= latch_instr_next;
    end
    assign _80 = latch_instr_q;
    assign _82 = imem_word;
    assign word = _87 ? _80 : _82;
    decode
        decode
        ( .instr(word),
          .sideset_count(_107),
          .side_en(_108),
          .bit_count(_110[27:22]),
          .delay(_110[21:17]),
          .side_value(_110[16:12]),
          .side_valid(_110[11:11]),
          .uses_lcu(_110[10:10]),
          .is_set(_110[9:9]),
          .is_irq(_110[8:8]),
          .is_mov(_110[7:7]),
          .is_pull(_110[6:6]),
          .is_push(_110[5:5]),
          .is_out(_110[4:4]),
          .is_in(_110[3:3]),
          .is_wait(_110[2:2]),
          .is_jmp(_110[1:1]),
          .legal(_110[0:0]) );
    assign _111 = _110[0:0];
    assign ok = _111 & _113;
    assign _178 = attempt & ok;
    assign _180 = _178 & _179;
    assign out_run = _180 & _378;
    assign out_exec = out_run & _424;
    assign exec_set = out_exec | mov_exec;
    assign _1479 = exec_set ? vdd : _1478;
    assign _84 = restart;
    assign _1480 = _84 ? gnd : _1479;
    assign _86 = instr_write;
    assign latch_valid_next = _86 ? vdd : _1480;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            latch_valid_q <= gnd;
        else
            latch_valid_q <= latch_valid_next;
    end
    assign _87 = latch_valid_q;
    assign forced_act = _87 & _29;
    assign attempt_latch = forced_act | _100;
    assign attempt = attempt_latch | attempt_imem;
    assign _329 = attempt & ok;
    assign _331 = _329 & _330;
    assign jmp_taken = _331 & jmp_cond_val;
    assign _384 = jmp_taken | out_pc;
    assign pc_write_now = _384 | mov_pc;
    assign pc_next = pc_write_now ? pc_target : _1400;
    always @(posedge _71 or negedge _69) begin
        if (_69 == 0)
            pc_q <= _1043;
        else
            pc_q <= pc_next;
    end
    assign pc = pc_q;
    assign lvl_mask = lvl_mask_out;
    assign lvl_val = lvl_val_out;
    assign dir_mask = dir_mask_out;
    assign dir_val = dir_val_out;
    assign irq_set = irq_set_out;
    assign irq_clr = irq_clr_out;
    assign tx_pop = tx_pop_0;
    assign rx_push = rx_push_0;
    assign rx_push_data = rx_push_data_0;
    assign txstall = txstall_0;
    assign rxstall = rxstall_0;
    assign illegal = illegal_0;
    assign x = x_q;
    assign y = y_q;
    assign isr = isr_q;
    assign osr = osr_q;
    assign dbg_cnt = dbg_cnt_0;
    assign exec_stalled = exec_stalled_q;
    assign phase = _91;

endmodule
module fifo_join (
    host_rx_pop,
    sm_rx_push,
    host_tx_data,
    sm_rx_data,
    rst_n,
    clk,
    join_tx,
    join_rx,
    host_tx_push,
    sm_tx_pop,
    flush,
    tx_head,
    tx_level,
    tx_full,
    tx_empty,
    tx_dropped,
    rx_head,
    rx_level,
    rx_full,
    rx_empty,
    rx_underflow
);

    input host_rx_pop;
    input sm_rx_push;
    input [31:0] host_tx_data;
    input [31:0] sm_rx_data;
    input rst_n;
    input clk;
    input join_tx;
    input join_rx;
    input host_tx_push;
    input sm_tx_pop;
    input flush;
    output [31:0] tx_head;
    output [3:0] tx_level;
    output tx_full;
    output tx_empty;
    output tx_dropped;
    output [31:0] rx_head;
    output [3:0] rx_level;
    output rx_full;
    output rx_empty;
    output rx_underflow;

    wire rx_underflow_0;
    wire [2:0] _64;
    wire [2:0] _56;
    wire [2:0] _57;
    wire _55;
    wire [2:0] _59;
    wire [2:0] _60;
    wire [2:0] _62;
    reg [2:0] rx_rd_q;
    wire [2:0] _5;
    wire [2:0] rx_rd_phys;
    reg [31:0] rx_head_0;
    wire tx_dropped_0;
    wire [2:0] _193;
    wire _194;
    wire _195;
    wire _191;
    wire _192;
    wire word_7_en;
    wire [31:0] _189;
    wire _185;
    wire _186;
    wire [31:0] _187;
    reg [31:0] word_7;
    wire [2:0] _179;
    wire _180;
    wire _181;
    wire _177;
    wire _178;
    wire word_6_en;
    wire _171;
    wire _172;
    wire [31:0] _173;
    reg [31:0] word_6;
    wire [2:0] _165;
    wire _166;
    wire _167;
    wire _163;
    wire _164;
    wire word_5_en;
    wire _157;
    wire _158;
    wire [31:0] _159;
    reg [31:0] word_5;
    wire [2:0] _151;
    wire _152;
    wire _153;
    wire _149;
    wire _150;
    wire word_4_en;
    wire _143;
    wire _144;
    wire [31:0] _145;
    reg [31:0] word_4;
    wire [2:0] _137;
    wire _138;
    wire _139;
    wire _135;
    wire _136;
    wire word_3_en;
    wire _129;
    wire _130;
    wire [31:0] _131;
    reg [31:0] word_3;
    wire [2:0] _123;
    wire _124;
    wire _125;
    wire _121;
    wire _122;
    wire word_2_en;
    wire _115;
    wire _116;
    wire [31:0] _117;
    reg [31:0] word_2;
    wire _110;
    wire _111;
    wire _107;
    wire _108;
    wire word_1_en;
    wire _101;
    wire _102;
    wire [31:0] _103;
    reg [31:0] word_1;
    wire [2:0] rx_base;
    wire [2:0] _204;
    wire [2:0] _52;
    wire [2:0] rx_last;
    wire _202;
    wire [2:0] _206;
    wire [2:0] _207;
    wire [2:0] _209;
    reg [2:0] rx_wr_q;
    wire [2:0] _11;
    wire [2:0] rx_wr_phys;
    wire _96;
    wire _92;
    wire [3:0] _45;
    wire [3:0] _43;
    wire [3:0] _42;
    wire [3:0] _44;
    wire [3:0] rx_cap;
    wire rx_empty_0;
    wire _48;
    wire _13;
    wire rx_pop_ok;
    wire [3:0] _216;
    wire [3:0] _213;
    wire [3:0] _214;
    wire [3:0] _217;
    wire [3:0] _219;
    reg [3:0] rx_level_q;
    wire [3:0] _14;
    wire rx_full_0;
    wire _90;
    wire _16;
    wire _91;
    wire rx_store;
    wire _97;
    wire _88;
    wire _89;
    wire word_0_en;
    wire [31:0] _18;
    wire [31:0] _20;
    wire [2:0] _230;
    wire _228;
    wire [2:0] _232;
    wire [2:0] _233;
    wire [2:0] _235;
    reg [2:0] tx_wr_q;
    wire [2:0] tx_wr_phys;
    wire _82;
    wire _83;
    wire [31:0] _84;
    reg [31:0] word_0;
    wire [2:0] _253;
    wire [2:0] _225;
    wire [2:0] tx_last;
    wire _251;
    wire [2:0] _255;
    wire vdd;
    wire _23;
    wire _25;
    wire [3:0] _244;
    wire _79;
    wire _27;
    wire [3:0] _73;
    wire _29;
    wire [3:0] tx_cap;
    wire tx_full_0;
    wire _77;
    wire _31;
    wire _78;
    wire tx_store;
    wire [3:0] _239;
    wire [3:0] _240;
    wire [3:0] _245;
    wire [3:0] _247;
    reg [3:0] tx_level_q;
    wire [3:0] _32;
    wire tx_empty_0;
    wire _242;
    wire _34;
    wire tx_pop_ok;
    wire [2:0] _256;
    wire _36;
    wire [2:0] _258;
    reg [2:0] tx_rd_q;
    wire [2:0] tx_rd_phys;
    reg [31:0] tx_head_0;
    assign rx_underflow_0 = _13 & rx_empty_0;
    assign _64 = 3'b000;
    assign _56 = 3'b001;
    assign _57 = _5 + _56;
    assign _55 = _5 == rx_last;
    assign _59 = _55 ? _64 : _57;
    assign _60 = rx_pop_ok ? _59 : _5;
    assign _62 = _36 ? _64 : _60;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            rx_rd_q <= _64;
        else
            rx_rd_q <= _62;
    end
    assign _5 = rx_rd_q;
    assign rx_rd_phys = _5 + rx_base;
    always @* begin
        case (rx_rd_phys)
        0:
            rx_head_0 <= word_0;
        1:
            rx_head_0 <= word_1;
        2:
            rx_head_0 <= word_2;
        3:
            rx_head_0 <= word_3;
        4:
            rx_head_0 <= word_4;
        5:
            rx_head_0 <= word_5;
        6:
            rx_head_0 <= word_6;
        default:
            rx_head_0 <= word_7;
        endcase
    end
    assign tx_dropped_0 = _31 & tx_full_0;
    assign _193 = 3'b111;
    assign _194 = rx_wr_phys == _193;
    assign _195 = rx_store & _194;
    assign _191 = tx_wr_phys == _193;
    assign _192 = tx_store & _191;
    assign word_7_en = _192 | _195;
    assign _189 = 32'b00000000000000000000000000000000;
    assign _185 = tx_wr_phys == _193;
    assign _186 = tx_store & _185;
    assign _187 = _186 ? _18 : _20;
    always @(posedge _25) begin
        if (word_7_en)
            word_7 <= _187;
    end
    assign _179 = 3'b110;
    assign _180 = rx_wr_phys == _179;
    assign _181 = rx_store & _180;
    assign _177 = tx_wr_phys == _179;
    assign _178 = tx_store & _177;
    assign word_6_en = _178 | _181;
    assign _171 = tx_wr_phys == _179;
    assign _172 = tx_store & _171;
    assign _173 = _172 ? _18 : _20;
    always @(posedge _25) begin
        if (word_6_en)
            word_6 <= _173;
    end
    assign _165 = 3'b101;
    assign _166 = rx_wr_phys == _165;
    assign _167 = rx_store & _166;
    assign _163 = tx_wr_phys == _165;
    assign _164 = tx_store & _163;
    assign word_5_en = _164 | _167;
    assign _157 = tx_wr_phys == _165;
    assign _158 = tx_store & _157;
    assign _159 = _158 ? _18 : _20;
    always @(posedge _25) begin
        if (word_5_en)
            word_5 <= _159;
    end
    assign _151 = 3'b100;
    assign _152 = rx_wr_phys == _151;
    assign _153 = rx_store & _152;
    assign _149 = tx_wr_phys == _151;
    assign _150 = tx_store & _149;
    assign word_4_en = _150 | _153;
    assign _143 = tx_wr_phys == _151;
    assign _144 = tx_store & _143;
    assign _145 = _144 ? _18 : _20;
    always @(posedge _25) begin
        if (word_4_en)
            word_4 <= _145;
    end
    assign _137 = 3'b011;
    assign _138 = rx_wr_phys == _137;
    assign _139 = rx_store & _138;
    assign _135 = tx_wr_phys == _137;
    assign _136 = tx_store & _135;
    assign word_3_en = _136 | _139;
    assign _129 = tx_wr_phys == _137;
    assign _130 = tx_store & _129;
    assign _131 = _130 ? _18 : _20;
    always @(posedge _25) begin
        if (word_3_en)
            word_3 <= _131;
    end
    assign _123 = 3'b010;
    assign _124 = rx_wr_phys == _123;
    assign _125 = rx_store & _124;
    assign _121 = tx_wr_phys == _123;
    assign _122 = tx_store & _121;
    assign word_2_en = _122 | _125;
    assign _115 = tx_wr_phys == _123;
    assign _116 = tx_store & _115;
    assign _117 = _116 ? _18 : _20;
    always @(posedge _25) begin
        if (word_2_en)
            word_2 <= _117;
    end
    assign _110 = rx_wr_phys == _56;
    assign _111 = rx_store & _110;
    assign _107 = tx_wr_phys == _56;
    assign _108 = tx_store & _107;
    assign word_1_en = _108 | _111;
    assign _101 = tx_wr_phys == _56;
    assign _102 = tx_store & _101;
    assign _103 = _102 ? _18 : _20;
    always @(posedge _25) begin
        if (word_1_en)
            word_1 <= _103;
    end
    assign rx_base = _29 ? _64 : _151;
    assign _204 = _11 + _56;
    assign _52 = _29 ? _193 : _137;
    assign rx_last = _27 ? _64 : _52;
    assign _202 = _11 == rx_last;
    assign _206 = _202 ? _64 : _204;
    assign _207 = rx_store ? _206 : _11;
    assign _209 = _36 ? _64 : _207;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            rx_wr_q <= _64;
        else
            rx_wr_q <= _209;
    end
    assign _11 = rx_wr_q;
    assign rx_wr_phys = _11 + rx_base;
    assign _96 = rx_wr_phys == _64;
    assign _92 = ~ _36;
    assign _45 = 4'b0000;
    assign _43 = 4'b1000;
    assign _42 = 4'b0100;
    assign _44 = _29 ? _43 : _42;
    assign rx_cap = _27 ? _45 : _44;
    assign rx_empty_0 = _14 == _45;
    assign _48 = ~ rx_empty_0;
    assign _13 = host_rx_pop;
    assign rx_pop_ok = _13 & _48;
    assign _216 = { _64,
                    rx_pop_ok };
    assign _213 = { _64,
                    rx_store };
    assign _214 = _14 + _213;
    assign _217 = _214 - _216;
    assign _219 = _36 ? _45 : _217;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            rx_level_q <= _45;
        else
            rx_level_q <= _219;
    end
    assign _14 = rx_level_q;
    assign rx_full_0 = _14 == rx_cap;
    assign _90 = ~ rx_full_0;
    assign _16 = sm_rx_push;
    assign _91 = _16 & _90;
    assign rx_store = _91 & _92;
    assign _97 = rx_store & _96;
    assign _88 = tx_wr_phys == _64;
    assign _89 = tx_store & _88;
    assign word_0_en = _89 | _97;
    assign _18 = host_tx_data;
    assign _20 = sm_rx_data;
    assign _230 = tx_wr_phys + _56;
    assign _228 = tx_wr_phys == tx_last;
    assign _232 = _228 ? _64 : _230;
    assign _233 = tx_store ? _232 : tx_wr_phys;
    assign _235 = _36 ? _64 : _233;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            tx_wr_q <= _64;
        else
            tx_wr_q <= _235;
    end
    assign tx_wr_phys = tx_wr_q;
    assign _82 = tx_wr_phys == _64;
    assign _83 = tx_store & _82;
    assign _84 = _83 ? _18 : _20;
    always @(posedge _25) begin
        if (word_0_en)
            word_0 <= _84;
    end
    assign _253 = tx_rd_phys + _56;
    assign _225 = _27 ? _193 : _137;
    assign tx_last = _29 ? _64 : _225;
    assign _251 = tx_rd_phys == tx_last;
    assign _255 = _251 ? _64 : _253;
    assign vdd = 1'b1;
    assign _23 = rst_n;
    assign _25 = clk;
    assign _244 = { _64,
                    tx_pop_ok };
    assign _79 = ~ _36;
    assign _27 = join_tx;
    assign _73 = _27 ? _43 : _42;
    assign _29 = join_rx;
    assign tx_cap = _29 ? _45 : _73;
    assign tx_full_0 = _32 == tx_cap;
    assign _77 = ~ tx_full_0;
    assign _31 = host_tx_push;
    assign _78 = _31 & _77;
    assign tx_store = _78 & _79;
    assign _239 = { _64,
                    tx_store };
    assign _240 = _32 + _239;
    assign _245 = _240 - _244;
    assign _247 = _36 ? _45 : _245;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            tx_level_q <= _45;
        else
            tx_level_q <= _247;
    end
    assign _32 = tx_level_q;
    assign tx_empty_0 = _32 == _45;
    assign _242 = ~ tx_empty_0;
    assign _34 = sm_tx_pop;
    assign tx_pop_ok = _34 & _242;
    assign _256 = tx_pop_ok ? _255 : tx_rd_phys;
    assign _36 = flush;
    assign _258 = _36 ? _64 : _256;
    always @(posedge _25 or negedge _23) begin
        if (_23 == 0)
            tx_rd_q <= _64;
        else
            tx_rd_q <= _258;
    end
    assign tx_rd_phys = tx_rd_q;
    always @* begin
        case (tx_rd_phys)
        0:
            tx_head_0 <= word_0;
        1:
            tx_head_0 <= word_1;
        2:
            tx_head_0 <= word_2;
        3:
            tx_head_0 <= word_3;
        4:
            tx_head_0 <= word_4;
        5:
            tx_head_0 <= word_5;
        6:
            tx_head_0 <= word_6;
        default:
            tx_head_0 <= word_7;
        endcase
    end
    assign tx_head = tx_head_0;
    assign tx_level = _32;
    assign tx_full = tx_full_0;
    assign tx_empty = tx_empty_0;
    assign tx_dropped = tx_dropped_0;
    assign rx_head = rx_head_0;
    assign rx_level = _14;
    assign rx_full = rx_full_0;
    assign rx_empty = rx_empty_0;
    assign rx_underflow = rx_underflow_0;

endmodule
module pio_block (
    fdebug_set,
    fdebug_clear,
    irq_force,
    irq_clear,
    ext2,
    pinctrl2,
    shiftctrl2,
    execctrl2,
    clkdiv2,
    ext1,
    pinctrl1,
    shiftctrl1,
    execctrl1,
    clkdiv1,
    ext0,
    pinctrl0,
    shiftctrl0,
    execctrl0,
    clkdiv0,
    rxf_sm,
    rxf_pop,
    txf_data,
    txf_sm,
    txf_push,
    fifo_flush,
    pins_in,
    sync_bypass,
    imem_addr,
    imem_write,
    imem_data,
    ext3,
    instr_data,
    instr_sm,
    instr_write,
    pinctrl3,
    shiftctrl3,
    execctrl3,
    clkdiv3,
    clkdiv_restart,
    sm_restart,
    sm_enable,
    rst_n,
    clock,
    pins_out,
    pins_oe,
    irq,
    rxf_data,
    fstat,
    flevel,
    fdebug,
    dbg_pc0,
    dbg_pc1,
    dbg_pc2,
    dbg_pc3,
    dbg_x0,
    dbg_x1,
    dbg_x2,
    dbg_x3,
    dbg_y0,
    dbg_y1,
    dbg_y2,
    dbg_y3,
    dbg_isr0,
    dbg_isr1,
    dbg_isr2,
    dbg_isr3,
    dbg_osr0,
    dbg_osr1,
    dbg_osr2,
    dbg_osr3,
    dbg_cnt0,
    dbg_cnt1,
    dbg_cnt2,
    dbg_cnt3,
    dbg_exec_stalled0,
    dbg_exec_stalled1,
    dbg_exec_stalled2,
    dbg_exec_stalled3,
    dbg_phase0,
    dbg_phase1,
    dbg_phase2,
    dbg_phase3,
    dbg_instr0,
    dbg_instr1,
    dbg_instr2,
    dbg_instr3
);

    input [31:0] fdebug_set;
    input [31:0] fdebug_clear;
    input [7:0] irq_force;
    input [7:0] irq_clear;
    input [31:0] ext2;
    input [31:0] pinctrl2;
    input [31:0] shiftctrl2;
    input [31:0] execctrl2;
    input [31:0] clkdiv2;
    input [31:0] ext1;
    input [31:0] pinctrl1;
    input [31:0] shiftctrl1;
    input [31:0] execctrl1;
    input [31:0] clkdiv1;
    input [31:0] ext0;
    input [31:0] pinctrl0;
    input [31:0] shiftctrl0;
    input [31:0] execctrl0;
    input [31:0] clkdiv0;
    input [1:0] rxf_sm;
    input rxf_pop;
    input [31:0] txf_data;
    input [1:0] txf_sm;
    input txf_push;
    input [3:0] fifo_flush;
    input [31:0] pins_in;
    input [31:0] sync_bypass;
    input [5:0] imem_addr;
    input imem_write;
    input [15:0] imem_data;
    input [31:0] ext3;
    input [15:0] instr_data;
    input [1:0] instr_sm;
    input instr_write;
    input [31:0] pinctrl3;
    input [31:0] shiftctrl3;
    input [31:0] execctrl3;
    input [31:0] clkdiv3;
    input [3:0] clkdiv_restart;
    input [3:0] sm_restart;
    input [3:0] sm_enable;
    input rst_n;
    input clock;
    output [31:0] pins_out;
    output [31:0] pins_oe;
    output [7:0] irq;
    output [31:0] rxf_data;
    output [31:0] fstat;
    output [31:0] flevel;
    output [31:0] fdebug;
    output [4:0] dbg_pc0;
    output [4:0] dbg_pc1;
    output [4:0] dbg_pc2;
    output [4:0] dbg_pc3;
    output [31:0] dbg_x0;
    output [31:0] dbg_x1;
    output [31:0] dbg_x2;
    output [31:0] dbg_x3;
    output [31:0] dbg_y0;
    output [31:0] dbg_y1;
    output [31:0] dbg_y2;
    output [31:0] dbg_y3;
    output [31:0] dbg_isr0;
    output [31:0] dbg_isr1;
    output [31:0] dbg_isr2;
    output [31:0] dbg_isr3;
    output [31:0] dbg_osr0;
    output [31:0] dbg_osr1;
    output [31:0] dbg_osr2;
    output [31:0] dbg_osr3;
    output [31:0] dbg_cnt0;
    output [31:0] dbg_cnt1;
    output [31:0] dbg_cnt2;
    output [31:0] dbg_cnt3;
    output dbg_exec_stalled0;
    output dbg_exec_stalled1;
    output dbg_exec_stalled2;
    output dbg_exec_stalled3;
    output [24:0] dbg_phase0;
    output [24:0] dbg_phase1;
    output [24:0] dbg_phase2;
    output [24:0] dbg_phase3;
    output [15:0] dbg_instr0;
    output [15:0] dbg_instr1;
    output [15:0] dbg_instr2;
    output [15:0] dbg_instr3;

    wire [24:0] _313;
    wire [24:0] _326;
    wire [24:0] _339;
    wire [24:0] _352;
    wire _353;
    wire _354;
    wire _355;
    wire _356;
    wire [31:0] _357;
    wire [31:0] _358;
    wire [31:0] _359;
    wire [31:0] _360;
    wire [31:0] _361;
    wire [31:0] _362;
    wire [31:0] _363;
    wire [31:0] _364;
    wire [31:0] _365;
    wire [31:0] _366;
    wire [31:0] _367;
    wire [31:0] _368;
    wire [31:0] _369;
    wire [31:0] _370;
    wire [31:0] _371;
    wire [31:0] _372;
    wire [31:0] _373;
    wire [31:0] _374;
    wire [31:0] _375;
    wire [31:0] _376;
    wire [31:0] _490;
    wire _486;
    wire _485;
    wire _484;
    wire _483;
    wire [3:0] _482;
    wire _481;
    wire _480;
    wire _479;
    wire _478;
    wire _476;
    wire _475;
    wire _474;
    wire _473;
    wire _471;
    wire _470;
    wire _469;
    wire _468;
    wire _467;
    wire _466;
    wire _465;
    wire [31:0] _38;
    wire _464;
    wire [31:0] _487;
    wire _461;
    wire _460;
    wire _459;
    wire _458;
    wire _456;
    wire _455;
    wire _454;
    wire _453;
    wire _451;
    wire _436;
    wire _421;
    wire _406;
    wire _390;
    wire _389;
    wire _388;
    wire _387;
    wire _386;
    wire _385;
    wire _384;
    wire _383;
    wire [31:0] _462;
    wire [31:0] _40;
    wire [31:0] _381;
    wire [31:0] _41;
    wire [31:0] _382;
    wire [31:0] _463;
    wire [31:0] _488;
    reg [31:0] fdebug_q;
    wire _531;
    wire _530;
    wire _529;
    wire _528;
    wire _526;
    wire _525;
    wire _524;
    wire _523;
    wire _521;
    wire _520;
    wire _519;
    wire _518;
    wire _516;
    wire _515;
    wire _514;
    wire _513;
    wire _511;
    wire _510;
    wire _509;
    wire _508;
    wire _506;
    wire _505;
    wire _504;
    wire _503;
    wire _501;
    wire _500;
    wire _499;
    wire _498;
    wire _496;
    wire _495;
    wire _494;
    wire _493;
    wire [31:0] _532;
    wire _542;
    wire _541;
    wire _540;
    wire _539;
    wire [31:0] _553;
    wire [31:0] _563;
    wire _544;
    wire [31:0] _565;
    wire [31:0] _560;
    wire _545;
    wire [31:0] _562;
    wire [31:0] _557;
    wire _546;
    wire [31:0] _559;
    wire [31:0] _554;
    wire _547;
    wire [31:0] _556;
    reg [31:0] rxf_data_0;
    wire [31:0] _47;
    wire [31:0] _604;
    wire [31:0] _605;
    wire [31:0] _602;
    wire [31:0] _601;
    wire [31:0] _603;
    wire [31:0] _606;
    wire [31:0] _600;
    wire [31:0] _607;
    wire [31:0] _598;
    wire [31:0] _597;
    wire [31:0] _599;
    wire [31:0] _608;
    wire [31:0] _596;
    wire [31:0] _609;
    wire [31:0] _594;
    wire [31:0] _593;
    wire [31:0] _595;
    wire [31:0] _610;
    wire [31:0] _592;
    wire [31:0] _611;
    wire [31:0] _590;
    wire [31:0] _589;
    wire [31:0] _591;
    wire [31:0] _612;
    reg [31:0] pins_oe_q;
    wire [31:0] _49;
    wire [31:0] _631;
    wire [31:0] _632;
    wire [31:0] _629;
    wire [31:0] _628;
    wire [31:0] _630;
    wire [31:0] _633;
    wire [31:0] _627;
    wire [31:0] _634;
    wire [31:0] _625;
    wire [31:0] _624;
    wire [31:0] _626;
    wire [31:0] _635;
    wire [31:0] _623;
    wire [31:0] _636;
    wire [31:0] _621;
    wire [31:0] _620;
    wire [31:0] _622;
    wire [31:0] _637;
    wire [31:0] _619;
    wire [31:0] _638;
    wire [31:0] _617;
    wire _310;
    wire _645;
    wire _646;
    wire _50;
    wire [7:0] _587;
    wire [7:0] _52;
    wire [7:0] _582;
    wire [7:0] _580;
    wire [7:0] _578;
    wire [7:0] _577;
    wire [7:0] _579;
    wire [7:0] _581;
    wire [7:0] _583;
    wire [7:0] _54;
    wire [7:0] _572;
    wire _323;
    wire _649;
    wire _650;
    wire _55;
    wire [3:0] _502;
    wire [3:0] _56;
    wire _550;
    wire _57;
    wire [3:0] _507;
    wire [3:0] _58;
    wire _535;
    wire _59;
    wire [1:0] _416;
    wire _417;
    wire _418;
    wire [31:0] _415;
    wire _414;
    wire _413;
    wire _411;
    wire _412;
    wire _409;
    wire _408;
    wire _407;
    wire [77:0] _420;
    wire [31:0] _651;
    wire [31:0] _60;
    wire [4:0] _378;
    wire [31:0] _62;
    wire _647;
    wire [5:0] _648;
    reg [15:0] _1036;
    wire [15:0] _63;
    wire _321;
    wire _322;
    wire [31:0] _65;
    wire [31:0] _67;
    wire [31:0] _69;
    wire [7:0] _319;
    wire [31:0] _71;
    wire [15:0] _318;
    wire _317;
    wire _316;
    wire _315;
    wire [371:0] _325;
    wire [7:0] _570;
    wire _336;
    wire _1039;
    wire _1040;
    wire _72;
    wire [3:0] _512;
    wire [3:0] _73;
    wire _551;
    wire _74;
    wire [3:0] _517;
    wire [3:0] _75;
    wire _536;
    wire _76;
    wire [1:0] _431;
    wire _432;
    wire _433;
    wire [31:0] _430;
    wire _429;
    wire _428;
    wire _426;
    wire _427;
    wire _424;
    wire _423;
    wire _422;
    wire [77:0] _435;
    wire [31:0] _1041;
    wire [31:0] _77;
    wire [4:0] _379;
    wire [31:0] _79;
    wire _1037;
    wire [5:0] _1038;
    reg [15:0] _1042;
    wire [15:0] _80;
    wire _334;
    wire _335;
    wire [31:0] _82;
    wire [31:0] _84;
    wire [31:0] _86;
    wire [7:0] _332;
    wire [31:0] _88;
    wire [15:0] _331;
    wire _330;
    wire _329;
    wire _328;
    wire [371:0] _338;
    wire [7:0] _568;
    wire _349;
    wire _1045;
    wire _1046;
    wire _89;
    wire [3:0] _522;
    wire [3:0] _90;
    wire _552;
    wire _91;
    wire [3:0] _527;
    wire [3:0] _92;
    wire _537;
    wire _93;
    wire [1:0] _446;
    wire _447;
    wire _448;
    wire [31:0] _445;
    wire _444;
    wire _443;
    wire _441;
    wire _442;
    wire _439;
    wire _438;
    wire _437;
    wire [77:0] _450;
    wire [31:0] _1047;
    wire [31:0] _94;
    wire [4:0] _380;
    wire [31:0] _96;
    wire _1043;
    wire [5:0] _1044;
    reg [15:0] _1048;
    wire [15:0] _97;
    wire _347;
    wire _348;
    wire [31:0] _99;
    wire [31:0] _101;
    wire [31:0] _103;
    wire [7:0] _345;
    wire [31:0] _105;
    wire [15:0] _344;
    wire _343;
    wire _342;
    wire _341;
    wire [371:0] _351;
    wire [7:0] _567;
    wire [7:0] _569;
    wire [7:0] _571;
    wire [7:0] _573;
    wire [7:0] _574;
    wire [7:0] _575;
    wire [7:0] _576;
    wire [7:0] _584;
    wire [7:0] _585;
    reg [7:0] irq_q;
    wire [7:0] _106;
    wire [3:0] _492;
    wire [3:0] _107;
    wire _549;
    wire _108;
    wire [3:0] _497;
    wire [3:0] _109;
    wire _534;
    wire _110;
    wire [1:0] _401;
    wire [1:0] _112;
    wire _402;
    wire _114;
    wire _403;
    wire [31:0] _400;
    wire _399;
    wire _398;
    wire [31:0] _116;
    wire [1:0] _118;
    wire _396;
    wire _120;
    wire _397;
    wire [3:0] _122;
    wire _394;
    wire _393;
    wire _392;
    wire [77:0] _405;
    wire [31:0] _1049;
    wire [31:0] _123;
    wire _307;
    wire _306;
    wire _305;
    wire _308;
    wire _303;
    wire _302;
    wire _301;
    wire _304;
    wire _299;
    wire _298;
    wire _297;
    wire _300;
    wire _295;
    wire _294;
    wire _293;
    wire _296;
    wire _291;
    wire _290;
    wire _289;
    wire _292;
    wire _287;
    wire _286;
    wire _285;
    wire _288;
    wire _283;
    wire _282;
    wire _281;
    wire _284;
    wire _279;
    wire _278;
    wire _277;
    wire _280;
    wire _275;
    wire _274;
    wire _273;
    wire _276;
    wire _271;
    wire _270;
    wire _269;
    wire _272;
    wire _267;
    wire _266;
    wire _265;
    wire _268;
    wire _263;
    wire _262;
    wire _261;
    wire _264;
    wire _259;
    wire _258;
    wire _257;
    wire _260;
    wire _255;
    wire _254;
    wire _253;
    wire _256;
    wire _251;
    wire _250;
    wire _249;
    wire _252;
    wire _247;
    wire _246;
    wire _245;
    wire _248;
    wire _243;
    wire _242;
    wire _241;
    wire _244;
    wire _239;
    wire _238;
    wire _237;
    wire _240;
    wire _235;
    wire _234;
    wire _233;
    wire _236;
    wire _231;
    wire _230;
    wire _229;
    wire _232;
    wire _227;
    wire _226;
    wire _225;
    wire _228;
    wire _223;
    wire _222;
    wire _221;
    wire _224;
    wire _219;
    wire _218;
    wire _217;
    wire _220;
    wire _215;
    wire _214;
    wire _213;
    wire _216;
    wire _211;
    wire _210;
    wire _209;
    wire _212;
    wire _207;
    wire _206;
    wire _205;
    wire _208;
    wire _203;
    wire _202;
    wire _201;
    wire _204;
    wire _199;
    wire _198;
    wire _197;
    wire _200;
    wire _195;
    wire _194;
    wire _193;
    wire _196;
    wire _191;
    wire _190;
    wire _189;
    wire _192;
    wire _187;
    wire _186;
    wire _185;
    wire _188;
    wire _183;
    wire vdd;
    wire [31:0] _125;
    reg [31:0] in_r1;
    reg [31:0] in_r2;
    reg [31:0] in_r3;
    wire _182;
    wire [31:0] _127;
    wire _171;
    wire _184;
    wire [31:0] in_sel;
    wire [5:0] _1032;
    wire _1033;
    wire _1034;
    wire [15:0] _1031;
    reg [15:0] imem_63;
    wire [5:0] _1026;
    wire _1027;
    wire _1028;
    reg [15:0] imem_62;
    wire [5:0] _1020;
    wire _1021;
    wire _1022;
    reg [15:0] imem_61;
    wire [5:0] _1014;
    wire _1015;
    wire _1016;
    reg [15:0] imem_60;
    wire [5:0] _1008;
    wire _1009;
    wire _1010;
    reg [15:0] imem_59;
    wire [5:0] _1002;
    wire _1003;
    wire _1004;
    reg [15:0] imem_58;
    wire [5:0] _996;
    wire _997;
    wire _998;
    reg [15:0] imem_57;
    wire [5:0] _990;
    wire _991;
    wire _992;
    reg [15:0] imem_56;
    wire [5:0] _984;
    wire _985;
    wire _986;
    reg [15:0] imem_55;
    wire [5:0] _978;
    wire _979;
    wire _980;
    reg [15:0] imem_54;
    wire [5:0] _972;
    wire _973;
    wire _974;
    reg [15:0] imem_53;
    wire [5:0] _966;
    wire _967;
    wire _968;
    reg [15:0] imem_52;
    wire [5:0] _960;
    wire _961;
    wire _962;
    reg [15:0] imem_51;
    wire [5:0] _954;
    wire _955;
    wire _956;
    reg [15:0] imem_50;
    wire [5:0] _948;
    wire _949;
    wire _950;
    reg [15:0] imem_49;
    wire [5:0] _942;
    wire _943;
    wire _944;
    reg [15:0] imem_48;
    wire [5:0] _936;
    wire _937;
    wire _938;
    reg [15:0] imem_47;
    wire [5:0] _930;
    wire _931;
    wire _932;
    reg [15:0] imem_46;
    wire [5:0] _924;
    wire _925;
    wire _926;
    reg [15:0] imem_45;
    wire [5:0] _918;
    wire _919;
    wire _920;
    reg [15:0] imem_44;
    wire [5:0] _912;
    wire _913;
    wire _914;
    reg [15:0] imem_43;
    wire [5:0] _906;
    wire _907;
    wire _908;
    reg [15:0] imem_42;
    wire [5:0] _900;
    wire _901;
    wire _902;
    reg [15:0] imem_41;
    wire [5:0] _894;
    wire _895;
    wire _896;
    reg [15:0] imem_40;
    wire [5:0] _888;
    wire _889;
    wire _890;
    reg [15:0] imem_39;
    wire [5:0] _882;
    wire _883;
    wire _884;
    reg [15:0] imem_38;
    wire [5:0] _876;
    wire _877;
    wire _878;
    reg [15:0] imem_37;
    wire [5:0] _870;
    wire _871;
    wire _872;
    reg [15:0] imem_36;
    wire [5:0] _864;
    wire _865;
    wire _866;
    reg [15:0] imem_35;
    wire [5:0] _858;
    wire _859;
    wire _860;
    reg [15:0] imem_34;
    wire [5:0] _852;
    wire _853;
    wire _854;
    reg [15:0] imem_33;
    wire [5:0] _846;
    wire _847;
    wire _848;
    reg [15:0] imem_32;
    wire [5:0] _840;
    wire _841;
    wire _842;
    reg [15:0] imem_31;
    wire [5:0] _834;
    wire _835;
    wire _836;
    reg [15:0] imem_30;
    wire [5:0] _828;
    wire _829;
    wire _830;
    reg [15:0] imem_29;
    wire [5:0] _822;
    wire _823;
    wire _824;
    reg [15:0] imem_28;
    wire [5:0] _816;
    wire _817;
    wire _818;
    reg [15:0] imem_27;
    wire [5:0] _810;
    wire _811;
    wire _812;
    reg [15:0] imem_26;
    wire [5:0] _804;
    wire _805;
    wire _806;
    reg [15:0] imem_25;
    wire [5:0] _798;
    wire _799;
    wire _800;
    reg [15:0] imem_24;
    wire [5:0] _792;
    wire _793;
    wire _794;
    reg [15:0] imem_23;
    wire [5:0] _786;
    wire _787;
    wire _788;
    reg [15:0] imem_22;
    wire [5:0] _780;
    wire _781;
    wire _782;
    reg [15:0] imem_21;
    wire [5:0] _774;
    wire _775;
    wire _776;
    reg [15:0] imem_20;
    wire [5:0] _768;
    wire _769;
    wire _770;
    reg [15:0] imem_19;
    wire [5:0] _762;
    wire _763;
    wire _764;
    reg [15:0] imem_18;
    wire [5:0] _756;
    wire _757;
    wire _758;
    reg [15:0] imem_17;
    wire [5:0] _750;
    wire _751;
    wire _752;
    reg [15:0] imem_16;
    wire [5:0] _744;
    wire _745;
    wire _746;
    reg [15:0] imem_15;
    wire [5:0] _738;
    wire _739;
    wire _740;
    reg [15:0] imem_14;
    wire [5:0] _732;
    wire _733;
    wire _734;
    reg [15:0] imem_13;
    wire [5:0] _726;
    wire _727;
    wire _728;
    reg [15:0] imem_12;
    wire [5:0] _720;
    wire _721;
    wire _722;
    reg [15:0] imem_11;
    wire [5:0] _714;
    wire _715;
    wire _716;
    reg [15:0] imem_10;
    wire [5:0] _708;
    wire _709;
    wire _710;
    reg [15:0] imem_9;
    wire [5:0] _702;
    wire _703;
    wire _704;
    reg [15:0] imem_8;
    wire [5:0] _696;
    wire _697;
    wire _698;
    reg [15:0] imem_7;
    wire [5:0] _690;
    wire _691;
    wire _692;
    reg [15:0] imem_6;
    wire [5:0] _684;
    wire _685;
    wire _686;
    reg [15:0] imem_5;
    wire [5:0] _678;
    wire _679;
    wire _680;
    reg [15:0] imem_4;
    wire [5:0] _672;
    wire _673;
    wire _674;
    reg [15:0] imem_3;
    wire [5:0] _666;
    wire _667;
    wire _668;
    reg [15:0] imem_2;
    wire [5:0] _660;
    wire _661;
    wire _662;
    reg [15:0] imem_1;
    wire [5:0] _654;
    wire [5:0] imem_write_idx;
    wire _655;
    wire _131;
    wire _656;
    wire [15:0] _133;
    reg [15:0] imem_0;
    wire [4:0] _377;
    wire [31:0] _135;
    wire _643;
    wire [5:0] _644;
    reg [15:0] _1050;
    wire [15:0] _136;
    wire [15:0] _138;
    wire [1:0] _140;
    wire _169;
    wire _142;
    wire _170;
    wire [31:0] _144;
    wire [31:0] _146;
    wire [31:0] _148;
    wire [7:0] _167;
    wire [31:0] _150;
    wire [15:0] _166;
    wire [3:0] _152;
    wire _165;
    wire [3:0] _154;
    wire _164;
    wire [3:0] _156;
    wire _163;
    wire _158;
    wire _160;
    wire [371:0] _312;
    wire [31:0] _616;
    wire [31:0] _618;
    wire [31:0] _639;
    reg [31:0] pins_out_q;
    assign _313 = _312[371:347];
    assign _326 = _325[371:347];
    assign _339 = _338[371:347];
    assign _352 = _351[371:347];
    assign _353 = _312[346:346];
    assign _354 = _325[346:346];
    assign _355 = _338[346:346];
    assign _356 = _351[346:346];
    assign _357 = _312[345:314];
    assign _358 = _325[345:314];
    assign _359 = _338[345:314];
    assign _360 = _351[345:314];
    assign _361 = _312[313:282];
    assign _362 = _325[313:282];
    assign _363 = _338[313:282];
    assign _364 = _351[313:282];
    assign _365 = _312[281:250];
    assign _366 = _325[281:250];
    assign _367 = _338[281:250];
    assign _368 = _351[281:250];
    assign _369 = _312[249:218];
    assign _370 = _325[249:218];
    assign _371 = _338[249:218];
    assign _372 = _351[249:218];
    assign _373 = _312[217:186];
    assign _374 = _325[217:186];
    assign _375 = _338[217:186];
    assign _376 = _351[217:186];
    assign _490 = 32'b00000000000000000000000000000000;
    assign _486 = _38[0:0];
    assign _485 = _38[1:1];
    assign _484 = _38[2:2];
    assign _483 = _38[3:3];
    assign _482 = 4'b0000;
    assign _481 = _38[8:8];
    assign _480 = _38[9:9];
    assign _479 = _38[10:10];
    assign _478 = _38[11:11];
    assign _476 = _38[16:16];
    assign _475 = _38[17:17];
    assign _474 = _38[18:18];
    assign _473 = _38[19:19];
    assign _471 = _38[24:24];
    assign _470 = _38[25:25];
    assign _469 = _38[26:26];
    assign _468 = _38[27:27];
    assign _467 = _38[28:28];
    assign _466 = _38[29:29];
    assign _465 = _38[30:30];
    assign _38 = fdebug_set;
    assign _464 = _38[31:31];
    assign _487 = { _464,
                    _465,
                    _466,
                    _467,
                    _468,
                    _469,
                    _470,
                    _471,
                    _482,
                    _473,
                    _474,
                    _475,
                    _476,
                    _482,
                    _478,
                    _479,
                    _480,
                    _481,
                    _482,
                    _483,
                    _484,
                    _485,
                    _486 };
    assign _461 = _351[184:184];
    assign _460 = _338[184:184];
    assign _459 = _325[184:184];
    assign _458 = _312[184:184];
    assign _456 = _450[77:77];
    assign _455 = _435[77:77];
    assign _454 = _420[77:77];
    assign _453 = _405[77:77];
    assign _451 = _450[38:38];
    assign _436 = _435[38:38];
    assign _421 = _420[38:38];
    assign _406 = _405[38:38];
    assign _390 = _351[183:183];
    assign _389 = _338[183:183];
    assign _388 = _325[183:183];
    assign _387 = _312[183:183];
    assign _386 = _351[185:185];
    assign _385 = _338[185:185];
    assign _384 = _325[185:185];
    assign _383 = _312[185:185];
    assign _462 = { _383,
                    _384,
                    _385,
                    _386,
                    _387,
                    _388,
                    _389,
                    _390,
                    _482,
                    _406,
                    _421,
                    _436,
                    _451,
                    _482,
                    _453,
                    _454,
                    _455,
                    _456,
                    _482,
                    _458,
                    _459,
                    _460,
                    _461 };
    assign _40 = fdebug_clear;
    assign _381 = ~ _40;
    assign _41 = fdebug_q;
    assign _382 = _41 & _381;
    assign _463 = _382 | _462;
    assign _488 = _463 | _487;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            fdebug_q <= _490;
        else
            fdebug_q <= _488;
    end
    assign _531 = _527[0:0];
    assign _530 = _527[1:1];
    assign _529 = _527[2:2];
    assign _528 = _527[3:3];
    assign _526 = _522[0:0];
    assign _525 = _522[1:1];
    assign _524 = _522[2:2];
    assign _523 = _522[3:3];
    assign _521 = _517[0:0];
    assign _520 = _517[1:1];
    assign _519 = _517[2:2];
    assign _518 = _517[3:3];
    assign _516 = _512[0:0];
    assign _515 = _512[1:1];
    assign _514 = _512[2:2];
    assign _513 = _512[3:3];
    assign _511 = _507[0:0];
    assign _510 = _507[1:1];
    assign _509 = _507[2:2];
    assign _508 = _507[3:3];
    assign _506 = _502[0:0];
    assign _505 = _502[1:1];
    assign _504 = _502[2:2];
    assign _503 = _502[3:3];
    assign _501 = _497[0:0];
    assign _500 = _497[1:1];
    assign _499 = _497[2:2];
    assign _498 = _497[3:3];
    assign _496 = _492[0:0];
    assign _495 = _492[1:1];
    assign _494 = _492[2:2];
    assign _493 = _492[3:3];
    assign _532 = { _493,
                    _494,
                    _495,
                    _496,
                    _498,
                    _499,
                    _500,
                    _501,
                    _503,
                    _504,
                    _505,
                    _506,
                    _508,
                    _509,
                    _510,
                    _511,
                    _513,
                    _514,
                    _515,
                    _516,
                    _518,
                    _519,
                    _520,
                    _521,
                    _523,
                    _524,
                    _525,
                    _526,
                    _528,
                    _529,
                    _530,
                    _531 };
    assign _542 = _450[36:36];
    assign _541 = _435[36:36];
    assign _540 = _420[36:36];
    assign _539 = _405[36:36];
    assign _553 = { _482,
                    _534,
                    _535,
                    _536,
                    _537,
                    _482,
                    _539,
                    _540,
                    _541,
                    _542,
                    _482,
                    _544,
                    _545,
                    _546,
                    _547,
                    _482,
                    _549,
                    _550,
                    _551,
                    _552 };
    assign _563 = _405[70:39];
    assign _544 = _405[76:76];
    assign _565 = _544 ? _490 : _563;
    assign _560 = _420[70:39];
    assign _545 = _420[76:76];
    assign _562 = _545 ? _490 : _560;
    assign _557 = _435[70:39];
    assign _546 = _435[76:76];
    assign _559 = _546 ? _490 : _557;
    assign _554 = _450[70:39];
    assign _547 = _450[76:76];
    assign _556 = _547 ? _490 : _554;
    always @* begin
        case (_112)
        0:
            rxf_data_0 <= _556;
        1:
            rxf_data_0 <= _559;
        2:
            rxf_data_0 <= _562;
        default:
            rxf_data_0 <= _565;
        endcase
    end
    assign _47 = pins_oe_q;
    assign _604 = ~ _601;
    assign _605 = _604 & _47;
    assign _602 = _351[132:101];
    assign _601 = _351[100:69];
    assign _603 = _601 & _602;
    assign _606 = _603 | _605;
    assign _600 = ~ _597;
    assign _607 = _600 & _606;
    assign _598 = _338[132:101];
    assign _597 = _338[100:69];
    assign _599 = _597 & _598;
    assign _608 = _599 | _607;
    assign _596 = ~ _593;
    assign _609 = _596 & _608;
    assign _594 = _325[132:101];
    assign _593 = _325[100:69];
    assign _595 = _593 & _594;
    assign _610 = _595 | _609;
    assign _592 = ~ _589;
    assign _611 = _592 & _610;
    assign _590 = _312[132:101];
    assign _589 = _312[100:69];
    assign _591 = _589 & _590;
    assign _612 = _591 | _611;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            pins_oe_q <= _490;
        else
            pins_oe_q <= _612;
    end
    assign _49 = pins_out_q;
    assign _631 = ~ _628;
    assign _632 = _631 & _49;
    assign _629 = _351[68:37];
    assign _628 = _351[36:5];
    assign _630 = _628 & _629;
    assign _633 = _630 | _632;
    assign _627 = ~ _624;
    assign _634 = _627 & _633;
    assign _625 = _338[68:37];
    assign _624 = _338[36:5];
    assign _626 = _624 & _625;
    assign _635 = _626 | _634;
    assign _623 = ~ _620;
    assign _636 = _623 & _635;
    assign _621 = _325[68:37];
    assign _620 = _325[36:5];
    assign _622 = _620 & _621;
    assign _637 = _622 | _636;
    assign _619 = ~ _616;
    assign _638 = _619 & _637;
    assign _617 = _312[68:37];
    assign _310 = _135[0:0];
    assign _645 = imem_write_idx == _644;
    assign _646 = _131 & _645;
    assign _50 = _646;
    assign _587 = 8'b00000000;
    assign _52 = irq_force;
    assign _582 = _312[140:133];
    assign _580 = _325[140:133];
    assign _578 = _338[140:133];
    assign _577 = _351[140:133];
    assign _579 = _577 | _578;
    assign _581 = _579 | _580;
    assign _583 = _581 | _582;
    assign _54 = irq_clear;
    assign _572 = _312[148:141];
    assign _323 = _62[0:0];
    assign _649 = imem_write_idx == _648;
    assign _650 = _131 & _649;
    assign _55 = _650;
    assign _502 = _420[74:71];
    assign _56 = _502;
    assign _550 = _420[75:75];
    assign _57 = _550;
    assign _507 = _420[35:32];
    assign _58 = _507;
    assign _535 = _420[37:37];
    assign _59 = _535;
    assign _416 = 2'b10;
    assign _417 = _112 == _416;
    assign _418 = _114 & _417;
    assign _415 = _325[182:151];
    assign _414 = _325[150:150];
    assign _413 = _325[149:149];
    assign _411 = _118 == _416;
    assign _412 = _120 & _411;
    assign _409 = _122[2:2];
    assign _408 = _67[31:31];
    assign _407 = _67[30:30];
    fifo_join
        fifo_join_1
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_407),
          .join_rx(_408),
          .flush(_409),
          .host_tx_push(_412),
          .host_tx_data(_116),
          .sm_tx_pop(_413),
          .sm_rx_push(_414),
          .sm_rx_data(_415),
          .host_rx_pop(_418),
          .rx_underflow(_420[77:77]),
          .rx_empty(_420[76:76]),
          .rx_full(_420[75:75]),
          .rx_level(_420[74:71]),
          .rx_head(_420[70:39]),
          .tx_dropped(_420[38:38]),
          .tx_empty(_420[37:37]),
          .tx_full(_420[36:36]),
          .tx_level(_420[35:32]),
          .tx_head(_420[31:0]) );
    assign _651 = _420[31:0];
    assign _60 = _651;
    assign _378 = _325[4:0];
    assign _62 = ext2;
    assign _647 = _62[0:0];
    assign _648 = { _647,
                    _378 };
    always @* begin
        case (_648)
        0:
            _1036 <= imem_0;
        1:
            _1036 <= imem_1;
        2:
            _1036 <= imem_2;
        3:
            _1036 <= imem_3;
        4:
            _1036 <= imem_4;
        5:
            _1036 <= imem_5;
        6:
            _1036 <= imem_6;
        7:
            _1036 <= imem_7;
        8:
            _1036 <= imem_8;
        9:
            _1036 <= imem_9;
        10:
            _1036 <= imem_10;
        11:
            _1036 <= imem_11;
        12:
            _1036 <= imem_12;
        13:
            _1036 <= imem_13;
        14:
            _1036 <= imem_14;
        15:
            _1036 <= imem_15;
        16:
            _1036 <= imem_16;
        17:
            _1036 <= imem_17;
        18:
            _1036 <= imem_18;
        19:
            _1036 <= imem_19;
        20:
            _1036 <= imem_20;
        21:
            _1036 <= imem_21;
        22:
            _1036 <= imem_22;
        23:
            _1036 <= imem_23;
        24:
            _1036 <= imem_24;
        25:
            _1036 <= imem_25;
        26:
            _1036 <= imem_26;
        27:
            _1036 <= imem_27;
        28:
            _1036 <= imem_28;
        29:
            _1036 <= imem_29;
        30:
            _1036 <= imem_30;
        31:
            _1036 <= imem_31;
        32:
            _1036 <= imem_32;
        33:
            _1036 <= imem_33;
        34:
            _1036 <= imem_34;
        35:
            _1036 <= imem_35;
        36:
            _1036 <= imem_36;
        37:
            _1036 <= imem_37;
        38:
            _1036 <= imem_38;
        39:
            _1036 <= imem_39;
        40:
            _1036 <= imem_40;
        41:
            _1036 <= imem_41;
        42:
            _1036 <= imem_42;
        43:
            _1036 <= imem_43;
        44:
            _1036 <= imem_44;
        45:
            _1036 <= imem_45;
        46:
            _1036 <= imem_46;
        47:
            _1036 <= imem_47;
        48:
            _1036 <= imem_48;
        49:
            _1036 <= imem_49;
        50:
            _1036 <= imem_50;
        51:
            _1036 <= imem_51;
        52:
            _1036 <= imem_52;
        53:
            _1036 <= imem_53;
        54:
            _1036 <= imem_54;
        55:
            _1036 <= imem_55;
        56:
            _1036 <= imem_56;
        57:
            _1036 <= imem_57;
        58:
            _1036 <= imem_58;
        59:
            _1036 <= imem_59;
        60:
            _1036 <= imem_60;
        61:
            _1036 <= imem_61;
        62:
            _1036 <= imem_62;
        default:
            _1036 <= imem_63;
        endcase
    end
    assign _63 = _1036;
    assign _321 = _140 == _416;
    assign _322 = _142 & _321;
    assign _65 = pinctrl2;
    assign _67 = shiftctrl2;
    assign _69 = execctrl2;
    assign _319 = _71[15:8];
    assign _71 = clkdiv2;
    assign _318 = _71[31:16];
    assign _317 = _152[2:2];
    assign _316 = _154[2:2];
    assign _315 = _156[2:2];
    sm
        sm_1
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_416),
          .enable(_315),
          .restart(_316),
          .clkdiv_restart(_317),
          .clkdiv_int(_318),
          .clkdiv_frac(_319),
          .execctrl(_69),
          .shiftctrl(_67),
          .pinctrl(_65),
          .instr_write(_322),
          .instr_data(_138),
          .imem_word(_63),
          .in_sel(in_sel),
          .tx_head(_60),
          .tx_empty(_59),
          .tx_level(_58),
          .rx_full(_57),
          .rx_level(_56),
          .irq_q(_106),
          .imem_abandon(_55),
          .page(_323),
          .phase(_325[371:347]),
          .exec_stalled(_325[346:346]),
          .dbg_cnt(_325[345:314]),
          .osr(_325[313:282]),
          .isr(_325[281:250]),
          .y(_325[249:218]),
          .x(_325[217:186]),
          .illegal(_325[185:185]),
          .rxstall(_325[184:184]),
          .txstall(_325[183:183]),
          .rx_push_data(_325[182:151]),
          .rx_push(_325[150:150]),
          .tx_pop(_325[149:149]),
          .irq_clr(_325[148:141]),
          .irq_set(_325[140:133]),
          .dir_val(_325[132:101]),
          .dir_mask(_325[100:69]),
          .lvl_val(_325[68:37]),
          .lvl_mask(_325[36:5]),
          .pc(_325[4:0]) );
    assign _570 = _325[148:141];
    assign _336 = _79[0:0];
    assign _1039 = imem_write_idx == _1038;
    assign _1040 = _131 & _1039;
    assign _72 = _1040;
    assign _512 = _435[74:71];
    assign _73 = _512;
    assign _551 = _435[75:75];
    assign _74 = _551;
    assign _517 = _435[35:32];
    assign _75 = _517;
    assign _536 = _435[37:37];
    assign _76 = _536;
    assign _431 = 2'b01;
    assign _432 = _112 == _431;
    assign _433 = _114 & _432;
    assign _430 = _338[182:151];
    assign _429 = _338[150:150];
    assign _428 = _338[149:149];
    assign _426 = _118 == _431;
    assign _427 = _120 & _426;
    assign _424 = _122[1:1];
    assign _423 = _84[31:31];
    assign _422 = _84[30:30];
    fifo_join
        fifo_join_0
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_422),
          .join_rx(_423),
          .flush(_424),
          .host_tx_push(_427),
          .host_tx_data(_116),
          .sm_tx_pop(_428),
          .sm_rx_push(_429),
          .sm_rx_data(_430),
          .host_rx_pop(_433),
          .rx_underflow(_435[77:77]),
          .rx_empty(_435[76:76]),
          .rx_full(_435[75:75]),
          .rx_level(_435[74:71]),
          .rx_head(_435[70:39]),
          .tx_dropped(_435[38:38]),
          .tx_empty(_435[37:37]),
          .tx_full(_435[36:36]),
          .tx_level(_435[35:32]),
          .tx_head(_435[31:0]) );
    assign _1041 = _435[31:0];
    assign _77 = _1041;
    assign _379 = _338[4:0];
    assign _79 = ext1;
    assign _1037 = _79[0:0];
    assign _1038 = { _1037,
                     _379 };
    always @* begin
        case (_1038)
        0:
            _1042 <= imem_0;
        1:
            _1042 <= imem_1;
        2:
            _1042 <= imem_2;
        3:
            _1042 <= imem_3;
        4:
            _1042 <= imem_4;
        5:
            _1042 <= imem_5;
        6:
            _1042 <= imem_6;
        7:
            _1042 <= imem_7;
        8:
            _1042 <= imem_8;
        9:
            _1042 <= imem_9;
        10:
            _1042 <= imem_10;
        11:
            _1042 <= imem_11;
        12:
            _1042 <= imem_12;
        13:
            _1042 <= imem_13;
        14:
            _1042 <= imem_14;
        15:
            _1042 <= imem_15;
        16:
            _1042 <= imem_16;
        17:
            _1042 <= imem_17;
        18:
            _1042 <= imem_18;
        19:
            _1042 <= imem_19;
        20:
            _1042 <= imem_20;
        21:
            _1042 <= imem_21;
        22:
            _1042 <= imem_22;
        23:
            _1042 <= imem_23;
        24:
            _1042 <= imem_24;
        25:
            _1042 <= imem_25;
        26:
            _1042 <= imem_26;
        27:
            _1042 <= imem_27;
        28:
            _1042 <= imem_28;
        29:
            _1042 <= imem_29;
        30:
            _1042 <= imem_30;
        31:
            _1042 <= imem_31;
        32:
            _1042 <= imem_32;
        33:
            _1042 <= imem_33;
        34:
            _1042 <= imem_34;
        35:
            _1042 <= imem_35;
        36:
            _1042 <= imem_36;
        37:
            _1042 <= imem_37;
        38:
            _1042 <= imem_38;
        39:
            _1042 <= imem_39;
        40:
            _1042 <= imem_40;
        41:
            _1042 <= imem_41;
        42:
            _1042 <= imem_42;
        43:
            _1042 <= imem_43;
        44:
            _1042 <= imem_44;
        45:
            _1042 <= imem_45;
        46:
            _1042 <= imem_46;
        47:
            _1042 <= imem_47;
        48:
            _1042 <= imem_48;
        49:
            _1042 <= imem_49;
        50:
            _1042 <= imem_50;
        51:
            _1042 <= imem_51;
        52:
            _1042 <= imem_52;
        53:
            _1042 <= imem_53;
        54:
            _1042 <= imem_54;
        55:
            _1042 <= imem_55;
        56:
            _1042 <= imem_56;
        57:
            _1042 <= imem_57;
        58:
            _1042 <= imem_58;
        59:
            _1042 <= imem_59;
        60:
            _1042 <= imem_60;
        61:
            _1042 <= imem_61;
        62:
            _1042 <= imem_62;
        default:
            _1042 <= imem_63;
        endcase
    end
    assign _80 = _1042;
    assign _334 = _140 == _431;
    assign _335 = _142 & _334;
    assign _82 = pinctrl1;
    assign _84 = shiftctrl1;
    assign _86 = execctrl1;
    assign _332 = _88[15:8];
    assign _88 = clkdiv1;
    assign _331 = _88[31:16];
    assign _330 = _152[1:1];
    assign _329 = _154[1:1];
    assign _328 = _156[1:1];
    sm
        sm_0
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_431),
          .enable(_328),
          .restart(_329),
          .clkdiv_restart(_330),
          .clkdiv_int(_331),
          .clkdiv_frac(_332),
          .execctrl(_86),
          .shiftctrl(_84),
          .pinctrl(_82),
          .instr_write(_335),
          .instr_data(_138),
          .imem_word(_80),
          .in_sel(in_sel),
          .tx_head(_77),
          .tx_empty(_76),
          .tx_level(_75),
          .rx_full(_74),
          .rx_level(_73),
          .irq_q(_106),
          .imem_abandon(_72),
          .page(_336),
          .phase(_338[371:347]),
          .exec_stalled(_338[346:346]),
          .dbg_cnt(_338[345:314]),
          .osr(_338[313:282]),
          .isr(_338[281:250]),
          .y(_338[249:218]),
          .x(_338[217:186]),
          .illegal(_338[185:185]),
          .rxstall(_338[184:184]),
          .txstall(_338[183:183]),
          .rx_push_data(_338[182:151]),
          .rx_push(_338[150:150]),
          .tx_pop(_338[149:149]),
          .irq_clr(_338[148:141]),
          .irq_set(_338[140:133]),
          .dir_val(_338[132:101]),
          .dir_mask(_338[100:69]),
          .lvl_val(_338[68:37]),
          .lvl_mask(_338[36:5]),
          .pc(_338[4:0]) );
    assign _568 = _338[148:141];
    assign _349 = _96[0:0];
    assign _1045 = imem_write_idx == _1044;
    assign _1046 = _131 & _1045;
    assign _89 = _1046;
    assign _522 = _450[74:71];
    assign _90 = _522;
    assign _552 = _450[75:75];
    assign _91 = _552;
    assign _527 = _450[35:32];
    assign _92 = _527;
    assign _537 = _450[37:37];
    assign _93 = _537;
    assign _446 = 2'b00;
    assign _447 = _112 == _446;
    assign _448 = _114 & _447;
    assign _445 = _351[182:151];
    assign _444 = _351[150:150];
    assign _443 = _351[149:149];
    assign _441 = _118 == _446;
    assign _442 = _120 & _441;
    assign _439 = _122[0:0];
    assign _438 = _101[31:31];
    assign _437 = _101[30:30];
    fifo_join
        fifo_join
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_437),
          .join_rx(_438),
          .flush(_439),
          .host_tx_push(_442),
          .host_tx_data(_116),
          .sm_tx_pop(_443),
          .sm_rx_push(_444),
          .sm_rx_data(_445),
          .host_rx_pop(_448),
          .rx_underflow(_450[77:77]),
          .rx_empty(_450[76:76]),
          .rx_full(_450[75:75]),
          .rx_level(_450[74:71]),
          .rx_head(_450[70:39]),
          .tx_dropped(_450[38:38]),
          .tx_empty(_450[37:37]),
          .tx_full(_450[36:36]),
          .tx_level(_450[35:32]),
          .tx_head(_450[31:0]) );
    assign _1047 = _450[31:0];
    assign _94 = _1047;
    assign _380 = _351[4:0];
    assign _96 = ext0;
    assign _1043 = _96[0:0];
    assign _1044 = { _1043,
                     _380 };
    always @* begin
        case (_1044)
        0:
            _1048 <= imem_0;
        1:
            _1048 <= imem_1;
        2:
            _1048 <= imem_2;
        3:
            _1048 <= imem_3;
        4:
            _1048 <= imem_4;
        5:
            _1048 <= imem_5;
        6:
            _1048 <= imem_6;
        7:
            _1048 <= imem_7;
        8:
            _1048 <= imem_8;
        9:
            _1048 <= imem_9;
        10:
            _1048 <= imem_10;
        11:
            _1048 <= imem_11;
        12:
            _1048 <= imem_12;
        13:
            _1048 <= imem_13;
        14:
            _1048 <= imem_14;
        15:
            _1048 <= imem_15;
        16:
            _1048 <= imem_16;
        17:
            _1048 <= imem_17;
        18:
            _1048 <= imem_18;
        19:
            _1048 <= imem_19;
        20:
            _1048 <= imem_20;
        21:
            _1048 <= imem_21;
        22:
            _1048 <= imem_22;
        23:
            _1048 <= imem_23;
        24:
            _1048 <= imem_24;
        25:
            _1048 <= imem_25;
        26:
            _1048 <= imem_26;
        27:
            _1048 <= imem_27;
        28:
            _1048 <= imem_28;
        29:
            _1048 <= imem_29;
        30:
            _1048 <= imem_30;
        31:
            _1048 <= imem_31;
        32:
            _1048 <= imem_32;
        33:
            _1048 <= imem_33;
        34:
            _1048 <= imem_34;
        35:
            _1048 <= imem_35;
        36:
            _1048 <= imem_36;
        37:
            _1048 <= imem_37;
        38:
            _1048 <= imem_38;
        39:
            _1048 <= imem_39;
        40:
            _1048 <= imem_40;
        41:
            _1048 <= imem_41;
        42:
            _1048 <= imem_42;
        43:
            _1048 <= imem_43;
        44:
            _1048 <= imem_44;
        45:
            _1048 <= imem_45;
        46:
            _1048 <= imem_46;
        47:
            _1048 <= imem_47;
        48:
            _1048 <= imem_48;
        49:
            _1048 <= imem_49;
        50:
            _1048 <= imem_50;
        51:
            _1048 <= imem_51;
        52:
            _1048 <= imem_52;
        53:
            _1048 <= imem_53;
        54:
            _1048 <= imem_54;
        55:
            _1048 <= imem_55;
        56:
            _1048 <= imem_56;
        57:
            _1048 <= imem_57;
        58:
            _1048 <= imem_58;
        59:
            _1048 <= imem_59;
        60:
            _1048 <= imem_60;
        61:
            _1048 <= imem_61;
        62:
            _1048 <= imem_62;
        default:
            _1048 <= imem_63;
        endcase
    end
    assign _97 = _1048;
    assign _347 = _140 == _446;
    assign _348 = _142 & _347;
    assign _99 = pinctrl0;
    assign _101 = shiftctrl0;
    assign _103 = execctrl0;
    assign _345 = _105[15:8];
    assign _105 = clkdiv0;
    assign _344 = _105[31:16];
    assign _343 = _152[0:0];
    assign _342 = _154[0:0];
    assign _341 = _156[0:0];
    sm
        sm
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_446),
          .enable(_341),
          .restart(_342),
          .clkdiv_restart(_343),
          .clkdiv_int(_344),
          .clkdiv_frac(_345),
          .execctrl(_103),
          .shiftctrl(_101),
          .pinctrl(_99),
          .instr_write(_348),
          .instr_data(_138),
          .imem_word(_97),
          .in_sel(in_sel),
          .tx_head(_94),
          .tx_empty(_93),
          .tx_level(_92),
          .rx_full(_91),
          .rx_level(_90),
          .irq_q(_106),
          .imem_abandon(_89),
          .page(_349),
          .phase(_351[371:347]),
          .exec_stalled(_351[346:346]),
          .dbg_cnt(_351[345:314]),
          .osr(_351[313:282]),
          .isr(_351[281:250]),
          .y(_351[249:218]),
          .x(_351[217:186]),
          .illegal(_351[185:185]),
          .rxstall(_351[184:184]),
          .txstall(_351[183:183]),
          .rx_push_data(_351[182:151]),
          .rx_push(_351[150:150]),
          .tx_pop(_351[149:149]),
          .irq_clr(_351[148:141]),
          .irq_set(_351[140:133]),
          .dir_val(_351[132:101]),
          .dir_mask(_351[100:69]),
          .lvl_val(_351[68:37]),
          .lvl_mask(_351[36:5]),
          .pc(_351[4:0]) );
    assign _567 = _351[148:141];
    assign _569 = _567 | _568;
    assign _571 = _569 | _570;
    assign _573 = _571 | _572;
    assign _574 = _573 | _54;
    assign _575 = ~ _574;
    assign _576 = _106 & _575;
    assign _584 = _576 | _583;
    assign _585 = _584 | _52;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            irq_q <= _587;
        else
            irq_q <= _585;
    end
    assign _106 = irq_q;
    assign _492 = _405[74:71];
    assign _107 = _492;
    assign _549 = _405[75:75];
    assign _108 = _549;
    assign _497 = _405[35:32];
    assign _109 = _497;
    assign _534 = _405[37:37];
    assign _110 = _534;
    assign _401 = 2'b11;
    assign _112 = rxf_sm;
    assign _402 = _112 == _401;
    assign _114 = rxf_pop;
    assign _403 = _114 & _402;
    assign _400 = _312[182:151];
    assign _399 = _312[150:150];
    assign _398 = _312[149:149];
    assign _116 = txf_data;
    assign _118 = txf_sm;
    assign _396 = _118 == _401;
    assign _120 = txf_push;
    assign _397 = _120 & _396;
    assign _122 = fifo_flush;
    assign _394 = _122[3:3];
    assign _393 = _146[31:31];
    assign _392 = _146[30:30];
    fifo_join
        fifo_join_2
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_392),
          .join_rx(_393),
          .flush(_394),
          .host_tx_push(_397),
          .host_tx_data(_116),
          .sm_tx_pop(_398),
          .sm_rx_push(_399),
          .sm_rx_data(_400),
          .host_rx_pop(_403),
          .rx_underflow(_405[77:77]),
          .rx_empty(_405[76:76]),
          .rx_full(_405[75:75]),
          .rx_level(_405[74:71]),
          .rx_head(_405[70:39]),
          .tx_dropped(_405[38:38]),
          .tx_empty(_405[37:37]),
          .tx_full(_405[36:36]),
          .tx_level(_405[35:32]),
          .tx_head(_405[31:0]) );
    assign _1049 = _405[31:0];
    assign _123 = _1049;
    assign _307 = in_r1[0:0];
    assign _306 = in_r3[0:0];
    assign _305 = _127[0:0];
    assign _308 = _305 ? _307 : _306;
    assign _303 = in_r1[1:1];
    assign _302 = in_r3[1:1];
    assign _301 = _127[1:1];
    assign _304 = _301 ? _303 : _302;
    assign _299 = in_r1[2:2];
    assign _298 = in_r3[2:2];
    assign _297 = _127[2:2];
    assign _300 = _297 ? _299 : _298;
    assign _295 = in_r1[3:3];
    assign _294 = in_r3[3:3];
    assign _293 = _127[3:3];
    assign _296 = _293 ? _295 : _294;
    assign _291 = in_r1[4:4];
    assign _290 = in_r3[4:4];
    assign _289 = _127[4:4];
    assign _292 = _289 ? _291 : _290;
    assign _287 = in_r1[5:5];
    assign _286 = in_r3[5:5];
    assign _285 = _127[5:5];
    assign _288 = _285 ? _287 : _286;
    assign _283 = in_r1[6:6];
    assign _282 = in_r3[6:6];
    assign _281 = _127[6:6];
    assign _284 = _281 ? _283 : _282;
    assign _279 = in_r1[7:7];
    assign _278 = in_r3[7:7];
    assign _277 = _127[7:7];
    assign _280 = _277 ? _279 : _278;
    assign _275 = in_r1[8:8];
    assign _274 = in_r3[8:8];
    assign _273 = _127[8:8];
    assign _276 = _273 ? _275 : _274;
    assign _271 = in_r1[9:9];
    assign _270 = in_r3[9:9];
    assign _269 = _127[9:9];
    assign _272 = _269 ? _271 : _270;
    assign _267 = in_r1[10:10];
    assign _266 = in_r3[10:10];
    assign _265 = _127[10:10];
    assign _268 = _265 ? _267 : _266;
    assign _263 = in_r1[11:11];
    assign _262 = in_r3[11:11];
    assign _261 = _127[11:11];
    assign _264 = _261 ? _263 : _262;
    assign _259 = in_r1[12:12];
    assign _258 = in_r3[12:12];
    assign _257 = _127[12:12];
    assign _260 = _257 ? _259 : _258;
    assign _255 = in_r1[13:13];
    assign _254 = in_r3[13:13];
    assign _253 = _127[13:13];
    assign _256 = _253 ? _255 : _254;
    assign _251 = in_r1[14:14];
    assign _250 = in_r3[14:14];
    assign _249 = _127[14:14];
    assign _252 = _249 ? _251 : _250;
    assign _247 = in_r1[15:15];
    assign _246 = in_r3[15:15];
    assign _245 = _127[15:15];
    assign _248 = _245 ? _247 : _246;
    assign _243 = in_r1[16:16];
    assign _242 = in_r3[16:16];
    assign _241 = _127[16:16];
    assign _244 = _241 ? _243 : _242;
    assign _239 = in_r1[17:17];
    assign _238 = in_r3[17:17];
    assign _237 = _127[17:17];
    assign _240 = _237 ? _239 : _238;
    assign _235 = in_r1[18:18];
    assign _234 = in_r3[18:18];
    assign _233 = _127[18:18];
    assign _236 = _233 ? _235 : _234;
    assign _231 = in_r1[19:19];
    assign _230 = in_r3[19:19];
    assign _229 = _127[19:19];
    assign _232 = _229 ? _231 : _230;
    assign _227 = in_r1[20:20];
    assign _226 = in_r3[20:20];
    assign _225 = _127[20:20];
    assign _228 = _225 ? _227 : _226;
    assign _223 = in_r1[21:21];
    assign _222 = in_r3[21:21];
    assign _221 = _127[21:21];
    assign _224 = _221 ? _223 : _222;
    assign _219 = in_r1[22:22];
    assign _218 = in_r3[22:22];
    assign _217 = _127[22:22];
    assign _220 = _217 ? _219 : _218;
    assign _215 = in_r1[23:23];
    assign _214 = in_r3[23:23];
    assign _213 = _127[23:23];
    assign _216 = _213 ? _215 : _214;
    assign _211 = in_r1[24:24];
    assign _210 = in_r3[24:24];
    assign _209 = _127[24:24];
    assign _212 = _209 ? _211 : _210;
    assign _207 = in_r1[25:25];
    assign _206 = in_r3[25:25];
    assign _205 = _127[25:25];
    assign _208 = _205 ? _207 : _206;
    assign _203 = in_r1[26:26];
    assign _202 = in_r3[26:26];
    assign _201 = _127[26:26];
    assign _204 = _201 ? _203 : _202;
    assign _199 = in_r1[27:27];
    assign _198 = in_r3[27:27];
    assign _197 = _127[27:27];
    assign _200 = _197 ? _199 : _198;
    assign _195 = in_r1[28:28];
    assign _194 = in_r3[28:28];
    assign _193 = _127[28:28];
    assign _196 = _193 ? _195 : _194;
    assign _191 = in_r1[29:29];
    assign _190 = in_r3[29:29];
    assign _189 = _127[29:29];
    assign _192 = _189 ? _191 : _190;
    assign _187 = in_r1[30:30];
    assign _186 = in_r3[30:30];
    assign _185 = _127[30:30];
    assign _188 = _185 ? _187 : _186;
    assign _183 = in_r1[31:31];
    assign vdd = 1'b1;
    assign _125 = pins_in;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            in_r1 <= _490;
        else
            in_r1 <= _125;
    end
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            in_r2 <= _490;
        else
            in_r2 <= in_r1;
    end
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            in_r3 <= _490;
        else
            in_r3 <= in_r2;
    end
    assign _182 = in_r3[31:31];
    assign _127 = sync_bypass;
    assign _171 = _127[31:31];
    assign _184 = _171 ? _183 : _182;
    assign in_sel = { _184,
                      _188,
                      _192,
                      _196,
                      _200,
                      _204,
                      _208,
                      _212,
                      _216,
                      _220,
                      _224,
                      _228,
                      _232,
                      _236,
                      _240,
                      _244,
                      _248,
                      _252,
                      _256,
                      _260,
                      _264,
                      _268,
                      _272,
                      _276,
                      _280,
                      _284,
                      _288,
                      _292,
                      _296,
                      _300,
                      _304,
                      _308 };
    assign _1032 = 6'b111111;
    assign _1033 = imem_write_idx == _1032;
    assign _1034 = _131 & _1033;
    assign _1031 = 16'b0000000000000000;
    always @(posedge _160) begin
        if (_1034)
            imem_63 <= _133;
    end
    assign _1026 = 6'b111110;
    assign _1027 = imem_write_idx == _1026;
    assign _1028 = _131 & _1027;
    always @(posedge _160) begin
        if (_1028)
            imem_62 <= _133;
    end
    assign _1020 = 6'b111101;
    assign _1021 = imem_write_idx == _1020;
    assign _1022 = _131 & _1021;
    always @(posedge _160) begin
        if (_1022)
            imem_61 <= _133;
    end
    assign _1014 = 6'b111100;
    assign _1015 = imem_write_idx == _1014;
    assign _1016 = _131 & _1015;
    always @(posedge _160) begin
        if (_1016)
            imem_60 <= _133;
    end
    assign _1008 = 6'b111011;
    assign _1009 = imem_write_idx == _1008;
    assign _1010 = _131 & _1009;
    always @(posedge _160) begin
        if (_1010)
            imem_59 <= _133;
    end
    assign _1002 = 6'b111010;
    assign _1003 = imem_write_idx == _1002;
    assign _1004 = _131 & _1003;
    always @(posedge _160) begin
        if (_1004)
            imem_58 <= _133;
    end
    assign _996 = 6'b111001;
    assign _997 = imem_write_idx == _996;
    assign _998 = _131 & _997;
    always @(posedge _160) begin
        if (_998)
            imem_57 <= _133;
    end
    assign _990 = 6'b111000;
    assign _991 = imem_write_idx == _990;
    assign _992 = _131 & _991;
    always @(posedge _160) begin
        if (_992)
            imem_56 <= _133;
    end
    assign _984 = 6'b110111;
    assign _985 = imem_write_idx == _984;
    assign _986 = _131 & _985;
    always @(posedge _160) begin
        if (_986)
            imem_55 <= _133;
    end
    assign _978 = 6'b110110;
    assign _979 = imem_write_idx == _978;
    assign _980 = _131 & _979;
    always @(posedge _160) begin
        if (_980)
            imem_54 <= _133;
    end
    assign _972 = 6'b110101;
    assign _973 = imem_write_idx == _972;
    assign _974 = _131 & _973;
    always @(posedge _160) begin
        if (_974)
            imem_53 <= _133;
    end
    assign _966 = 6'b110100;
    assign _967 = imem_write_idx == _966;
    assign _968 = _131 & _967;
    always @(posedge _160) begin
        if (_968)
            imem_52 <= _133;
    end
    assign _960 = 6'b110011;
    assign _961 = imem_write_idx == _960;
    assign _962 = _131 & _961;
    always @(posedge _160) begin
        if (_962)
            imem_51 <= _133;
    end
    assign _954 = 6'b110010;
    assign _955 = imem_write_idx == _954;
    assign _956 = _131 & _955;
    always @(posedge _160) begin
        if (_956)
            imem_50 <= _133;
    end
    assign _948 = 6'b110001;
    assign _949 = imem_write_idx == _948;
    assign _950 = _131 & _949;
    always @(posedge _160) begin
        if (_950)
            imem_49 <= _133;
    end
    assign _942 = 6'b110000;
    assign _943 = imem_write_idx == _942;
    assign _944 = _131 & _943;
    always @(posedge _160) begin
        if (_944)
            imem_48 <= _133;
    end
    assign _936 = 6'b101111;
    assign _937 = imem_write_idx == _936;
    assign _938 = _131 & _937;
    always @(posedge _160) begin
        if (_938)
            imem_47 <= _133;
    end
    assign _930 = 6'b101110;
    assign _931 = imem_write_idx == _930;
    assign _932 = _131 & _931;
    always @(posedge _160) begin
        if (_932)
            imem_46 <= _133;
    end
    assign _924 = 6'b101101;
    assign _925 = imem_write_idx == _924;
    assign _926 = _131 & _925;
    always @(posedge _160) begin
        if (_926)
            imem_45 <= _133;
    end
    assign _918 = 6'b101100;
    assign _919 = imem_write_idx == _918;
    assign _920 = _131 & _919;
    always @(posedge _160) begin
        if (_920)
            imem_44 <= _133;
    end
    assign _912 = 6'b101011;
    assign _913 = imem_write_idx == _912;
    assign _914 = _131 & _913;
    always @(posedge _160) begin
        if (_914)
            imem_43 <= _133;
    end
    assign _906 = 6'b101010;
    assign _907 = imem_write_idx == _906;
    assign _908 = _131 & _907;
    always @(posedge _160) begin
        if (_908)
            imem_42 <= _133;
    end
    assign _900 = 6'b101001;
    assign _901 = imem_write_idx == _900;
    assign _902 = _131 & _901;
    always @(posedge _160) begin
        if (_902)
            imem_41 <= _133;
    end
    assign _894 = 6'b101000;
    assign _895 = imem_write_idx == _894;
    assign _896 = _131 & _895;
    always @(posedge _160) begin
        if (_896)
            imem_40 <= _133;
    end
    assign _888 = 6'b100111;
    assign _889 = imem_write_idx == _888;
    assign _890 = _131 & _889;
    always @(posedge _160) begin
        if (_890)
            imem_39 <= _133;
    end
    assign _882 = 6'b100110;
    assign _883 = imem_write_idx == _882;
    assign _884 = _131 & _883;
    always @(posedge _160) begin
        if (_884)
            imem_38 <= _133;
    end
    assign _876 = 6'b100101;
    assign _877 = imem_write_idx == _876;
    assign _878 = _131 & _877;
    always @(posedge _160) begin
        if (_878)
            imem_37 <= _133;
    end
    assign _870 = 6'b100100;
    assign _871 = imem_write_idx == _870;
    assign _872 = _131 & _871;
    always @(posedge _160) begin
        if (_872)
            imem_36 <= _133;
    end
    assign _864 = 6'b100011;
    assign _865 = imem_write_idx == _864;
    assign _866 = _131 & _865;
    always @(posedge _160) begin
        if (_866)
            imem_35 <= _133;
    end
    assign _858 = 6'b100010;
    assign _859 = imem_write_idx == _858;
    assign _860 = _131 & _859;
    always @(posedge _160) begin
        if (_860)
            imem_34 <= _133;
    end
    assign _852 = 6'b100001;
    assign _853 = imem_write_idx == _852;
    assign _854 = _131 & _853;
    always @(posedge _160) begin
        if (_854)
            imem_33 <= _133;
    end
    assign _846 = 6'b100000;
    assign _847 = imem_write_idx == _846;
    assign _848 = _131 & _847;
    always @(posedge _160) begin
        if (_848)
            imem_32 <= _133;
    end
    assign _840 = 6'b011111;
    assign _841 = imem_write_idx == _840;
    assign _842 = _131 & _841;
    always @(posedge _160) begin
        if (_842)
            imem_31 <= _133;
    end
    assign _834 = 6'b011110;
    assign _835 = imem_write_idx == _834;
    assign _836 = _131 & _835;
    always @(posedge _160) begin
        if (_836)
            imem_30 <= _133;
    end
    assign _828 = 6'b011101;
    assign _829 = imem_write_idx == _828;
    assign _830 = _131 & _829;
    always @(posedge _160) begin
        if (_830)
            imem_29 <= _133;
    end
    assign _822 = 6'b011100;
    assign _823 = imem_write_idx == _822;
    assign _824 = _131 & _823;
    always @(posedge _160) begin
        if (_824)
            imem_28 <= _133;
    end
    assign _816 = 6'b011011;
    assign _817 = imem_write_idx == _816;
    assign _818 = _131 & _817;
    always @(posedge _160) begin
        if (_818)
            imem_27 <= _133;
    end
    assign _810 = 6'b011010;
    assign _811 = imem_write_idx == _810;
    assign _812 = _131 & _811;
    always @(posedge _160) begin
        if (_812)
            imem_26 <= _133;
    end
    assign _804 = 6'b011001;
    assign _805 = imem_write_idx == _804;
    assign _806 = _131 & _805;
    always @(posedge _160) begin
        if (_806)
            imem_25 <= _133;
    end
    assign _798 = 6'b011000;
    assign _799 = imem_write_idx == _798;
    assign _800 = _131 & _799;
    always @(posedge _160) begin
        if (_800)
            imem_24 <= _133;
    end
    assign _792 = 6'b010111;
    assign _793 = imem_write_idx == _792;
    assign _794 = _131 & _793;
    always @(posedge _160) begin
        if (_794)
            imem_23 <= _133;
    end
    assign _786 = 6'b010110;
    assign _787 = imem_write_idx == _786;
    assign _788 = _131 & _787;
    always @(posedge _160) begin
        if (_788)
            imem_22 <= _133;
    end
    assign _780 = 6'b010101;
    assign _781 = imem_write_idx == _780;
    assign _782 = _131 & _781;
    always @(posedge _160) begin
        if (_782)
            imem_21 <= _133;
    end
    assign _774 = 6'b010100;
    assign _775 = imem_write_idx == _774;
    assign _776 = _131 & _775;
    always @(posedge _160) begin
        if (_776)
            imem_20 <= _133;
    end
    assign _768 = 6'b010011;
    assign _769 = imem_write_idx == _768;
    assign _770 = _131 & _769;
    always @(posedge _160) begin
        if (_770)
            imem_19 <= _133;
    end
    assign _762 = 6'b010010;
    assign _763 = imem_write_idx == _762;
    assign _764 = _131 & _763;
    always @(posedge _160) begin
        if (_764)
            imem_18 <= _133;
    end
    assign _756 = 6'b010001;
    assign _757 = imem_write_idx == _756;
    assign _758 = _131 & _757;
    always @(posedge _160) begin
        if (_758)
            imem_17 <= _133;
    end
    assign _750 = 6'b010000;
    assign _751 = imem_write_idx == _750;
    assign _752 = _131 & _751;
    always @(posedge _160) begin
        if (_752)
            imem_16 <= _133;
    end
    assign _744 = 6'b001111;
    assign _745 = imem_write_idx == _744;
    assign _746 = _131 & _745;
    always @(posedge _160) begin
        if (_746)
            imem_15 <= _133;
    end
    assign _738 = 6'b001110;
    assign _739 = imem_write_idx == _738;
    assign _740 = _131 & _739;
    always @(posedge _160) begin
        if (_740)
            imem_14 <= _133;
    end
    assign _732 = 6'b001101;
    assign _733 = imem_write_idx == _732;
    assign _734 = _131 & _733;
    always @(posedge _160) begin
        if (_734)
            imem_13 <= _133;
    end
    assign _726 = 6'b001100;
    assign _727 = imem_write_idx == _726;
    assign _728 = _131 & _727;
    always @(posedge _160) begin
        if (_728)
            imem_12 <= _133;
    end
    assign _720 = 6'b001011;
    assign _721 = imem_write_idx == _720;
    assign _722 = _131 & _721;
    always @(posedge _160) begin
        if (_722)
            imem_11 <= _133;
    end
    assign _714 = 6'b001010;
    assign _715 = imem_write_idx == _714;
    assign _716 = _131 & _715;
    always @(posedge _160) begin
        if (_716)
            imem_10 <= _133;
    end
    assign _708 = 6'b001001;
    assign _709 = imem_write_idx == _708;
    assign _710 = _131 & _709;
    always @(posedge _160) begin
        if (_710)
            imem_9 <= _133;
    end
    assign _702 = 6'b001000;
    assign _703 = imem_write_idx == _702;
    assign _704 = _131 & _703;
    always @(posedge _160) begin
        if (_704)
            imem_8 <= _133;
    end
    assign _696 = 6'b000111;
    assign _697 = imem_write_idx == _696;
    assign _698 = _131 & _697;
    always @(posedge _160) begin
        if (_698)
            imem_7 <= _133;
    end
    assign _690 = 6'b000110;
    assign _691 = imem_write_idx == _690;
    assign _692 = _131 & _691;
    always @(posedge _160) begin
        if (_692)
            imem_6 <= _133;
    end
    assign _684 = 6'b000101;
    assign _685 = imem_write_idx == _684;
    assign _686 = _131 & _685;
    always @(posedge _160) begin
        if (_686)
            imem_5 <= _133;
    end
    assign _678 = 6'b000100;
    assign _679 = imem_write_idx == _678;
    assign _680 = _131 & _679;
    always @(posedge _160) begin
        if (_680)
            imem_4 <= _133;
    end
    assign _672 = 6'b000011;
    assign _673 = imem_write_idx == _672;
    assign _674 = _131 & _673;
    always @(posedge _160) begin
        if (_674)
            imem_3 <= _133;
    end
    assign _666 = 6'b000010;
    assign _667 = imem_write_idx == _666;
    assign _668 = _131 & _667;
    always @(posedge _160) begin
        if (_668)
            imem_2 <= _133;
    end
    assign _660 = 6'b000001;
    assign _661 = imem_write_idx == _660;
    assign _662 = _131 & _661;
    always @(posedge _160) begin
        if (_662)
            imem_1 <= _133;
    end
    assign _654 = 6'b000000;
    assign imem_write_idx = imem_addr;
    assign _655 = imem_write_idx == _654;
    assign _131 = imem_write;
    assign _656 = _131 & _655;
    assign _133 = imem_data;
    always @(posedge _160) begin
        if (_656)
            imem_0 <= _133;
    end
    assign _377 = _312[4:0];
    assign _135 = ext3;
    assign _643 = _135[0:0];
    assign _644 = { _643,
                    _377 };
    always @* begin
        case (_644)
        0:
            _1050 <= imem_0;
        1:
            _1050 <= imem_1;
        2:
            _1050 <= imem_2;
        3:
            _1050 <= imem_3;
        4:
            _1050 <= imem_4;
        5:
            _1050 <= imem_5;
        6:
            _1050 <= imem_6;
        7:
            _1050 <= imem_7;
        8:
            _1050 <= imem_8;
        9:
            _1050 <= imem_9;
        10:
            _1050 <= imem_10;
        11:
            _1050 <= imem_11;
        12:
            _1050 <= imem_12;
        13:
            _1050 <= imem_13;
        14:
            _1050 <= imem_14;
        15:
            _1050 <= imem_15;
        16:
            _1050 <= imem_16;
        17:
            _1050 <= imem_17;
        18:
            _1050 <= imem_18;
        19:
            _1050 <= imem_19;
        20:
            _1050 <= imem_20;
        21:
            _1050 <= imem_21;
        22:
            _1050 <= imem_22;
        23:
            _1050 <= imem_23;
        24:
            _1050 <= imem_24;
        25:
            _1050 <= imem_25;
        26:
            _1050 <= imem_26;
        27:
            _1050 <= imem_27;
        28:
            _1050 <= imem_28;
        29:
            _1050 <= imem_29;
        30:
            _1050 <= imem_30;
        31:
            _1050 <= imem_31;
        32:
            _1050 <= imem_32;
        33:
            _1050 <= imem_33;
        34:
            _1050 <= imem_34;
        35:
            _1050 <= imem_35;
        36:
            _1050 <= imem_36;
        37:
            _1050 <= imem_37;
        38:
            _1050 <= imem_38;
        39:
            _1050 <= imem_39;
        40:
            _1050 <= imem_40;
        41:
            _1050 <= imem_41;
        42:
            _1050 <= imem_42;
        43:
            _1050 <= imem_43;
        44:
            _1050 <= imem_44;
        45:
            _1050 <= imem_45;
        46:
            _1050 <= imem_46;
        47:
            _1050 <= imem_47;
        48:
            _1050 <= imem_48;
        49:
            _1050 <= imem_49;
        50:
            _1050 <= imem_50;
        51:
            _1050 <= imem_51;
        52:
            _1050 <= imem_52;
        53:
            _1050 <= imem_53;
        54:
            _1050 <= imem_54;
        55:
            _1050 <= imem_55;
        56:
            _1050 <= imem_56;
        57:
            _1050 <= imem_57;
        58:
            _1050 <= imem_58;
        59:
            _1050 <= imem_59;
        60:
            _1050 <= imem_60;
        61:
            _1050 <= imem_61;
        62:
            _1050 <= imem_62;
        default:
            _1050 <= imem_63;
        endcase
    end
    assign _136 = _1050;
    assign _138 = instr_data;
    assign _140 = instr_sm;
    assign _169 = _140 == _401;
    assign _142 = instr_write;
    assign _170 = _142 & _169;
    assign _144 = pinctrl3;
    assign _146 = shiftctrl3;
    assign _148 = execctrl3;
    assign _167 = _150[15:8];
    assign _150 = clkdiv3;
    assign _166 = _150[31:16];
    assign _152 = clkdiv_restart;
    assign _165 = _152[3:3];
    assign _154 = sm_restart;
    assign _164 = _154[3:3];
    assign _156 = sm_enable;
    assign _163 = _156[3:3];
    assign _158 = rst_n;
    assign _160 = clock;
    sm
        sm_2
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_401),
          .enable(_163),
          .restart(_164),
          .clkdiv_restart(_165),
          .clkdiv_int(_166),
          .clkdiv_frac(_167),
          .execctrl(_148),
          .shiftctrl(_146),
          .pinctrl(_144),
          .instr_write(_170),
          .instr_data(_138),
          .imem_word(_136),
          .in_sel(in_sel),
          .tx_head(_123),
          .tx_empty(_110),
          .tx_level(_109),
          .rx_full(_108),
          .rx_level(_107),
          .irq_q(_106),
          .imem_abandon(_50),
          .page(_310),
          .phase(_312[371:347]),
          .exec_stalled(_312[346:346]),
          .dbg_cnt(_312[345:314]),
          .osr(_312[313:282]),
          .isr(_312[281:250]),
          .y(_312[249:218]),
          .x(_312[217:186]),
          .illegal(_312[185:185]),
          .rxstall(_312[184:184]),
          .txstall(_312[183:183]),
          .rx_push_data(_312[182:151]),
          .rx_push(_312[150:150]),
          .tx_pop(_312[149:149]),
          .irq_clr(_312[148:141]),
          .irq_set(_312[140:133]),
          .dir_val(_312[132:101]),
          .dir_mask(_312[100:69]),
          .lvl_val(_312[68:37]),
          .lvl_mask(_312[36:5]),
          .pc(_312[4:0]) );
    assign _616 = _312[36:5];
    assign _618 = _616 & _617;
    assign _639 = _618 | _638;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            pins_out_q <= _490;
        else
            pins_out_q <= _639;
    end
    assign pins_out = pins_out_q;
    assign pins_oe = pins_oe_q;
    assign irq = irq_q;
    assign rxf_data = rxf_data_0;
    assign fstat = _553;
    assign flevel = _532;
    assign fdebug = fdebug_q;
    assign dbg_pc0 = _380;
    assign dbg_pc1 = _379;
    assign dbg_pc2 = _378;
    assign dbg_pc3 = _377;
    assign dbg_x0 = _376;
    assign dbg_x1 = _375;
    assign dbg_x2 = _374;
    assign dbg_x3 = _373;
    assign dbg_y0 = _372;
    assign dbg_y1 = _371;
    assign dbg_y2 = _370;
    assign dbg_y3 = _369;
    assign dbg_isr0 = _368;
    assign dbg_isr1 = _367;
    assign dbg_isr2 = _366;
    assign dbg_isr3 = _365;
    assign dbg_osr0 = _364;
    assign dbg_osr1 = _363;
    assign dbg_osr2 = _362;
    assign dbg_osr3 = _361;
    assign dbg_cnt0 = _360;
    assign dbg_cnt1 = _359;
    assign dbg_cnt2 = _358;
    assign dbg_cnt3 = _357;
    assign dbg_exec_stalled0 = _356;
    assign dbg_exec_stalled1 = _355;
    assign dbg_exec_stalled2 = _354;
    assign dbg_exec_stalled3 = _353;
    assign dbg_phase0 = _352;
    assign dbg_phase1 = _339;
    assign dbg_phase2 = _326;
    assign dbg_phase3 = _313;
    assign dbg_instr0 = _97;
    assign dbg_instr1 = _80;
    assign dbg_instr2 = _63;
    assign dbg_instr3 = _136;

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

    wire [7:0] _175;
    wire [7:0] _176;
    wire [7:0] _59;
    wire [7:0] _177;
    wire [7:0] _178;
    wire [7:0] _174;
    wire [7:0] _179;
    wire [5:0] _450;
    wire [11:0] _446;
    wire _443;
    wire _442;
    wire _441;
    wire _440;
    wire [11:0] _444;
    wire [11:0] _445;
    wire _447;
    wire _448;
    wire _439;
    wire _437;
    wire _438;
    wire _449;
    wire [31:0] _425;
    wire [23:0] _421;
    wire _194;
    wire _195;
    wire _192;
    wire _193;
    wire _190;
    wire _191;
    wire _188;
    wire _189;
    wire _186;
    wire _187;
    wire _184;
    wire _185;
    wire _182;
    wire _183;
    wire _180;
    wire _181;
    wire [7:0] _196;
    wire [7:0] _3;
    wire [31:0] _422;
    wire [31:0] _659;
    wire [31:0] _4;
    wire [5:0] _755;
    wire _756;
    wire _754;
    wire _757;
    reg [31:0] _758;
    wire [31:0] _660;
    wire [31:0] _5;
    wire [31:0] _661;
    wire [31:0] _6;
    wire [31:0] _7;
    wire [7:0] _750;
    wire [31:0] _751;
    wire [5:0] _170;
    wire _171;
    wire _168;
    wire _172;
    wire [7:0] _72;
    reg [7:0] _173;
    wire [31:0] _749;
    wire [5:0] _432;
    wire _433;
    wire _431;
    wire _434;
    wire [11:0] _428;
    reg [11:0] _435;
    wire [19:0] _746;
    wire [31:0] _747;
    wire [7:0] _662;
    wire [7:0] _8;
    wire [31:0] _745;
    wire [31:0] _663;
    wire [31:0] _9;
    wire [31:0] _664;
    wire [31:0] _10;
    wire [27:0] _742;
    wire [31:0] _743;
    wire [31:0] _741;
    wire [31:0] _740;
    reg [31:0] _759;
    wire [31:0] _665;
    wire [31:0] _11;
    wire [31:0] _666;
    wire [31:0] _12;
    wire [31:0] _667;
    wire [31:0] _13;
    wire [31:0] _668;
    wire [31:0] _14;
    wire [31:0] _669;
    wire [31:0] _15;
    wire [30:0] _735;
    wire [31:0] _736;
    wire [15:0] _670;
    wire [15:0] _16;
    wire [15:0] _733;
    wire [31:0] _734;
    wire [4:0] _671;
    wire [4:0] _17;
    wire [26:0] _731;
    wire [31:0] _732;
    wire [30:0] _729;
    wire _672;
    wire _18;
    wire [31:0] _730;
    reg [31:0] _737;
    wire [31:0] _673;
    wire [31:0] _19;
    wire [31:0] _674;
    wire [31:0] _20;
    wire [31:0] _675;
    wire [31:0] _21;
    wire [31:0] _676;
    wire [31:0] _22;
    wire [31:0] _677;
    wire [31:0] _23;
    wire [31:0] _727;
    wire [15:0] _678;
    wire [15:0] _24;
    wire [31:0] _725;
    wire [4:0] _679;
    wire [4:0] _25;
    wire [31:0] _723;
    wire [30:0] _720;
    wire _680;
    wire _26;
    wire [31:0] _721;
    reg [31:0] _728;
    wire [31:0] _681;
    wire [31:0] _27;
    wire [31:0] _682;
    wire [31:0] _28;
    wire [31:0] _683;
    wire [31:0] _29;
    wire [31:0] _684;
    wire [31:0] _30;
    wire [31:0] _685;
    wire [31:0] _31;
    wire [31:0] _718;
    wire [15:0] _686;
    wire [15:0] _32;
    wire [31:0] _716;
    wire [4:0] _687;
    wire [4:0] _33;
    wire [31:0] _714;
    wire [30:0] _711;
    wire _688;
    wire _34;
    wire [31:0] _712;
    reg [31:0] _719;
    wire [31:0] _689;
    wire [31:0] _35;
    wire [31:0] _690;
    wire [31:0] _36;
    wire [31:0] _691;
    wire [31:0] _37;
    wire [31:0] _692;
    wire [31:0] _38;
    wire [31:0] _693;
    wire [31:0] _39;
    wire [31:0] _709;
    wire [15:0] _694;
    wire [15:0] _40;
    wire [31:0] _707;
    wire [4:0] _695;
    wire [4:0] _41;
    wire [31:0] _705;
    wire [30:0] _702;
    wire [1:0] _652;
    wire _653;
    wire _650;
    wire _651;
    wire _654;
    wire [1:0] _647;
    wire _648;
    wire _645;
    wire _646;
    wire _649;
    wire [1:0] _642;
    wire _643;
    wire _640;
    wire _641;
    wire _644;
    wire [1:0] _637;
    wire _638;
    wire _635;
    wire _636;
    wire _639;
    wire [31:0] _656;
    wire [3:0] _629;
    wire _630;
    wire _627;
    wire _625;
    wire _628;
    wire _631;
    wire _624;
    wire _622;
    reg _632;
    wire [31:0] _633;
    wire _617;
    wire _614;
    wire _612;
    wire _615;
    wire _618;
    wire _609;
    reg _619;
    wire [31:0] _620;
    wire _604;
    wire _601;
    wire _599;
    wire _602;
    wire _605;
    wire _596;
    reg _606;
    wire [31:0] _607;
    wire _591;
    wire _588;
    wire _586;
    wire _589;
    wire _592;
    wire _583;
    reg _593;
    wire [31:0] _594;
    wire [15:0] _581;
    wire _578;
    wire _575;
    wire _576;
    wire _577;
    wire _579;
    wire _580;
    wire [15:0] _574;
    wire [3:0] _571;
    wire _572;
    wire _570;
    wire _573;
    wire _563;
    wire _562;
    wire _561;
    wire [31:0] _696;
    wire [31:0] _42;
    wire _560;
    reg _564;
    reg _567;
    wire _568;
    wire [3:0] _556;
    wire [3:0] _555;
    wire _557;
    wire _558;
    wire [4:0] _552;
    wire _553;
    wire _550;
    wire _551;
    wire _554;
    wire _559;
    wire _569;
    wire [1:0] _549;
    wire [3:0] _545;
    wire _547;
    wire _544;
    wire _548;
    wire [5:0] _539;
    wire _540;
    wire _538;
    wire _541;
    wire [31:0] _543;
    wire [7:0] _536;
    wire [5:0] _532;
    wire _533;
    wire _531;
    wire _534;
    wire [7:0] _537;
    wire [7:0] _529;
    wire [5:0] _525;
    wire _526;
    wire _524;
    wire _527;
    wire [7:0] _530;
    wire [1:0] _519;
    wire [1:0] _518;
    wire _520;
    wire _521;
    wire [3:0] _515;
    wire _516;
    wire _513;
    wire _511;
    wire _514;
    wire _517;
    wire _522;
    wire [1:0] _507;
    wire [1:0] _506;
    wire _508;
    wire _509;
    wire _504;
    wire _501;
    wire _499;
    wire _502;
    wire _505;
    wire _510;
    wire [1:0] _495;
    wire [1:0] _494;
    wire _496;
    wire _497;
    wire _492;
    wire _489;
    wire _487;
    wire _490;
    wire _493;
    wire _498;
    wire [1:0] _483;
    wire [1:0] _482;
    wire _484;
    wire _485;
    wire _480;
    wire _477;
    wire _475;
    wire _478;
    wire _481;
    wire _486;
    wire [3:0] _523;
    wire _472;
    wire _473;
    wire _470;
    wire _471;
    wire _468;
    wire _469;
    wire _466;
    wire _467;
    wire [3:0] _474;
    wire _463;
    wire _464;
    wire _461;
    wire _462;
    wire _459;
    wire _460;
    wire _457;
    wire [5:0] _454;
    wire _455;
    wire _453;
    wire _456;
    wire _458;
    wire [3:0] _465;
    wire [7:0] _44;
    wire [31:0] _452;
    wire [5:0] _401;
    wire _402;
    wire _400;
    wire _403;
    wire [23:0] _397;
    reg [23:0] _404;
    wire [31:0] _405;
    wire _393;
    wire _390;
    wire _388;
    wire _391;
    wire _394;
    wire [31:0] _386;
    reg [31:0] _395;
    wire _383;
    wire _380;
    wire _378;
    wire _381;
    wire _384;
    reg [31:0] _385;
    wire _373;
    wire _370;
    wire _368;
    wire _371;
    wire _374;
    reg [31:0] _375;
    wire _363;
    wire _360;
    wire _358;
    wire _361;
    wire _364;
    reg [31:0] _365;
    wire _353;
    wire _350;
    wire _348;
    wire _351;
    wire _354;
    wire [31:0] _346;
    wire [31:0] _344;
    wire [31:0] _345;
    reg [31:0] _355;
    wire _341;
    wire _338;
    wire _336;
    wire _339;
    wire _342;
    wire [31:0] _333;
    reg [31:0] _343;
    wire _329;
    wire _326;
    wire _324;
    wire _327;
    wire _330;
    wire [31:0] _321;
    reg [31:0] _331;
    wire _317;
    wire _314;
    wire _312;
    wire _315;
    wire _318;
    wire [31:0] _309;
    reg [31:0] _319;
    wire [3:0] _304;
    wire _305;
    wire _302;
    wire _300;
    wire _303;
    wire _306;
    wire [31:0] _298;
    wire [31:0] _296;
    wire [31:0] _297;
    reg [31:0] _307;
    wire _293;
    wire _290;
    wire _288;
    wire _291;
    wire _294;
    wire [31:0] _285;
    reg [31:0] _295;
    wire _281;
    wire _278;
    wire _276;
    wire _279;
    wire _282;
    wire [31:0] _273;
    reg [31:0] _283;
    wire _269;
    wire _266;
    wire _264;
    wire _267;
    wire _270;
    wire [31:0] _261;
    reg [31:0] _271;
    wire [3:0] _256;
    wire _257;
    wire _254;
    wire _252;
    wire _255;
    wire _258;
    wire [31:0] _250;
    wire [31:0] _248;
    wire [31:0] _249;
    reg [31:0] _259;
    wire _245;
    wire _242;
    wire _240;
    wire _243;
    wire _246;
    wire [31:0] _237;
    reg [31:0] _247;
    wire _233;
    wire _230;
    wire _228;
    wire _231;
    wire _234;
    wire [31:0] _225;
    reg [31:0] _235;
    wire [5:0] _169;
    wire _202;
    wire _200;
    wire _203;
    wire [3:0] _197;
    reg [3:0] _204;
    wire [1027:0] _658;
    wire _697;
    wire _45;
    wire [31:0] _703;
    wire _221;
    wire _217;
    wire [4:0] _129;
    wire _130;
    wire _127;
    wire _105;
    wire _128;
    wire _131;
    wire _214;
    wire _218;
    wire _222;
    wire [31:0] _206;
    reg [31:0] _223;
    wire [3:0] _219;
    reg [31:0] _710;
    wire [1:0] _215;
    reg [31:0] _738;
    wire _211;
    wire _212;
    wire _209;
    wire _210;
    wire _213;
    wire [31:0] _739;
    wire _165;
    wire _166;
    wire _162;
    wire _163;
    wire [5:0] _160;
    wire [30:0] _698;
    reg [30:0] _701;
    wire [30:0] _46;
    wire [31:0] _71;
    wire [13:0] _152;
    wire [15:0] _154;
    wire [15:0] _149;
    wire [15:0] _150;
    wire [15:0] _47;
    wire [4:0] _143;
    wire _144;
    wire _141;
    wire _142;
    wire _145;
    reg _146;
    wire _147;
    wire _137;
    wire _135;
    wire _138;
    wire _133;
    wire _139;
    wire _148;
    wire [15:0] _151;
    wire _132;
    wire [15:0] _155;
    reg [15:0] _158;
    wire [5:0] _159;
    wire _161;
    wire _164;
    wire _167;
    wire [31:0] _760;
    wire [31:0] _48;
    wire [30:0] _414;
    wire [31:0] _416;
    wire [4:0] _411;
    wire _412;
    wire [4:0] _123;
    wire _124;
    wire _107;
    wire _108;
    wire _125;
    wire _60;
    reg _68;
    reg _70;
    reg _126;
    wire [4:0] _98;
    wire [4:0] _114;
    wire _111;
    wire _109;
    wire _112;
    wire [4:0] _116;
    wire [4:0] _117;
    wire [4:0] _119;
    reg [4:0] _122;
    wire [4:0] _49;
    wire _99;
    wire _100;
    wire _50;
    wire _101;
    wire _97;
    wire _102;
    reg _104;
    wire _409;
    wire _410;
    wire _413;
    wire [31:0] _417;
    wire [31:0] _51;
    wire _93;
    wire _89;
    reg _81;
    wire _82;
    wire _75;
    reg _77;
    reg _79;
    wire _83;
    wire _90;
    wire _94;
    wire [31:0] _418;
    wire _407;
    wire _408;
    wire [31:0] _420;
    reg _92;
    wire gnd;
    wire _53;
    wire vdd;
    reg rst_sync1;
    reg core_rst_n;
    wire _55;
    wire [7:0] _57;
    wire _84;
    reg _86;
    reg _88;
    wire _95;
    wire _96;
    wire [31:0] _423;
    reg [31:0] _426;
    wire _427;
    wire [7:0] _451;
    assign _175 = _173 & _174;
    assign _176 = ~ _175;
    assign _59 = _5[7:0];
    assign _177 = _59 & _176;
    assign _178 = ~ _173;
    assign _174 = _6[7:0];
    assign _179 = _174 & _178;
    assign _450 = _6[13:8];
    assign _446 = 12'b000000000000;
    assign _443 = _8[0:0];
    assign _442 = _8[1:1];
    assign _441 = _8[2:2];
    assign _440 = _8[3:3];
    assign _444 = { _181,
                    _183,
                    _185,
                    _187,
                    _189,
                    _191,
                    _193,
                    _195,
                    _440,
                    _441,
                    _442,
                    _443 };
    assign _445 = _435 & _444;
    assign _447 = _445 == _446;
    assign _448 = ~ _447;
    assign _439 = _6[14:14];
    assign _437 = _435 == _446;
    assign _438 = ~ _437;
    assign _449 = _438 ? _448 : _439;
    assign _425 = 32'b00000000000000000000000000000000;
    assign _421 = 24'b000000000000000000000000;
    assign _194 = _42[8:8];
    assign _195 = ~ _194;
    assign _192 = _42[9:9];
    assign _193 = ~ _192;
    assign _190 = _42[10:10];
    assign _191 = ~ _190;
    assign _188 = _42[11:11];
    assign _189 = ~ _188;
    assign _186 = _42[16:16];
    assign _187 = ~ _186;
    assign _184 = _42[17:17];
    assign _185 = ~ _184;
    assign _182 = _42[18:18];
    assign _183 = ~ _182;
    assign _180 = _42[19:19];
    assign _181 = ~ _180;
    assign _196 = { _181,
                    _183,
                    _185,
                    _187,
                    _189,
                    _191,
                    _193,
                    _195 };
    assign _3 = _196;
    assign _422 = { _3,
                    _421 };
    assign _659 = _658[103:72];
    assign _4 = _659;
    assign _755 = 6'b001110;
    assign _756 = _169 == _755;
    assign _754 = _131 & _167;
    assign _757 = _754 & _756;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _758 <= _425;
        else
            if (_757)
                _758 <= _71;
    end
    assign _660 = _658[63:32];
    assign _5 = _660;
    assign _661 = _658[31:0];
    assign _6 = _661;
    assign _7 = _452;
    assign _750 = 8'b00000000;
    assign _751 = { _750,
                    _404 };
    assign _170 = 6'b001001;
    assign _171 = _169 == _170;
    assign _168 = _131 & _167;
    assign _172 = _168 & _171;
    assign _72 = _71[7:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _173 <= _750;
        else
            if (_172)
                _173 <= _72;
    end
    assign _749 = { _421,
                    _173 };
    assign _432 = 6'b001000;
    assign _433 = _169 == _432;
    assign _431 = _131 & _167;
    assign _434 = _431 & _433;
    assign _428 = _71[11:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _435 <= _446;
        else
            if (_434)
                _435 <= _428;
    end
    assign _746 = 20'b00000000000000000000;
    assign _747 = { _746,
                    _435 };
    assign _662 = _658[71:64];
    assign _8 = _662;
    assign _745 = { _421,
                    _8 };
    assign _663 = _658[167:136];
    assign _9 = _663;
    assign _664 = _658[199:168];
    assign _10 = _664;
    assign _742 = 28'b0000000000000000000000000000;
    assign _743 = { _742,
                    _204 };
    assign _741 = 32'b00010000010000000000010000000100;
    assign _740 = 32'b01010000010011000100011101010100;
    always @* begin
        case (_169)
        0:
            _759 <= _740;
        1:
            _759 <= _741;
        2:
            _759 <= _743;
        3:
            _759 <= _42;
        4:
            _759 <= _10;
        5:
            _759 <= _9;
        6:
            _759 <= _745;
        7:
            _759 <= _425;
        8:
            _759 <= _747;
        9:
            _759 <= _749;
        10:
            _759 <= _751;
        11:
            _759 <= _7;
        12:
            _759 <= _6;
        13:
            _759 <= _5;
        14:
            _759 <= _758;
        15:
            _759 <= _425;
        16:
            _759 <= _425;
        17:
            _759 <= _425;
        18:
            _759 <= _425;
        19:
            _759 <= _425;
        20:
            _759 <= _4;
        21:
            _759 <= _4;
        22:
            _759 <= _4;
        23:
            _759 <= _4;
        24:
            _759 <= _425;
        25:
            _759 <= _425;
        26:
            _759 <= _425;
        27:
            _759 <= _425;
        28:
            _759 <= _425;
        29:
            _759 <= _425;
        30:
            _759 <= _425;
        31:
            _759 <= _425;
        32:
            _759 <= _425;
        33:
            _759 <= _425;
        34:
            _759 <= _425;
        35:
            _759 <= _425;
        36:
            _759 <= _425;
        37:
            _759 <= _425;
        38:
            _759 <= _425;
        39:
            _759 <= _425;
        40:
            _759 <= _425;
        41:
            _759 <= _425;
        42:
            _759 <= _425;
        43:
            _759 <= _425;
        44:
            _759 <= _425;
        45:
            _759 <= _425;
        46:
            _759 <= _425;
        47:
            _759 <= _425;
        48:
            _759 <= _425;
        49:
            _759 <= _425;
        50:
            _759 <= _425;
        51:
            _759 <= _425;
        52:
            _759 <= _425;
        53:
            _759 <= _425;
        54:
            _759 <= _425;
        55:
            _759 <= _425;
        56:
            _759 <= _425;
        57:
            _759 <= _425;
        58:
            _759 <= _425;
        59:
            _759 <= _425;
        60:
            _759 <= _425;
        61:
            _759 <= _425;
        62:
            _759 <= _425;
        default:
            _759 <= _425;
        endcase
    end
    assign _665 = _658[859:828];
    assign _11 = _665;
    assign _666 = _658[731:700];
    assign _12 = _666;
    assign _667 = _658[603:572];
    assign _13 = _667;
    assign _668 = _658[475:444];
    assign _14 = _668;
    assign _669 = _658[347:316];
    assign _15 = _669;
    assign _735 = 31'b0000000000000000000000000000000;
    assign _736 = { _735,
                    _632 };
    assign _670 = _658[1027:1012];
    assign _16 = _670;
    assign _733 = 16'b0000000000000000;
    assign _734 = { _733,
                    _16 };
    assign _671 = _658[219:215];
    assign _17 = _671;
    assign _731 = 27'b000000000000000000000000000;
    assign _732 = { _731,
                    _17 };
    assign _729 = _307[30:0];
    assign _672 = _658[863:863];
    assign _18 = _672;
    assign _730 = { _18,
                    _729 };
    always @* begin
        case (_219)
        0:
            _737 <= _259;
        1:
            _737 <= _730;
        2:
            _737 <= _355;
        3:
            _737 <= _732;
        4:
            _737 <= _734;
        5:
            _737 <= _395;
        6:
            _737 <= _736;
        7:
            _737 <= _425;
        8:
            _737 <= _425;
        9:
            _737 <= _425;
        10:
            _737 <= _425;
        11:
            _737 <= _15;
        12:
            _737 <= _14;
        13:
            _737 <= _13;
        14:
            _737 <= _12;
        default:
            _737 <= _11;
        endcase
    end
    assign _673 = _658[827:796];
    assign _19 = _673;
    assign _674 = _658[699:668];
    assign _20 = _674;
    assign _675 = _658[571:540];
    assign _21 = _675;
    assign _676 = _658[443:412];
    assign _22 = _676;
    assign _677 = _658[315:284];
    assign _23 = _677;
    assign _727 = { _735,
                    _619 };
    assign _678 = _658[1011:996];
    assign _24 = _678;
    assign _725 = { _733,
                    _24 };
    assign _679 = _658[214:210];
    assign _25 = _679;
    assign _723 = { _731,
                    _25 };
    assign _720 = _295[30:0];
    assign _680 = _658[862:862];
    assign _26 = _680;
    assign _721 = { _26,
                    _720 };
    always @* begin
        case (_219)
        0:
            _728 <= _247;
        1:
            _728 <= _721;
        2:
            _728 <= _343;
        3:
            _728 <= _723;
        4:
            _728 <= _725;
        5:
            _728 <= _385;
        6:
            _728 <= _727;
        7:
            _728 <= _425;
        8:
            _728 <= _425;
        9:
            _728 <= _425;
        10:
            _728 <= _425;
        11:
            _728 <= _23;
        12:
            _728 <= _22;
        13:
            _728 <= _21;
        14:
            _728 <= _20;
        default:
            _728 <= _19;
        endcase
    end
    assign _681 = _658[795:764];
    assign _27 = _681;
    assign _682 = _658[667:636];
    assign _28 = _682;
    assign _683 = _658[539:508];
    assign _29 = _683;
    assign _684 = _658[411:380];
    assign _30 = _684;
    assign _685 = _658[283:252];
    assign _31 = _685;
    assign _718 = { _735,
                    _606 };
    assign _686 = _658[995:980];
    assign _32 = _686;
    assign _716 = { _733,
                    _32 };
    assign _687 = _658[209:205];
    assign _33 = _687;
    assign _714 = { _731,
                    _33 };
    assign _711 = _283[30:0];
    assign _688 = _658[861:861];
    assign _34 = _688;
    assign _712 = { _34,
                    _711 };
    always @* begin
        case (_219)
        0:
            _719 <= _235;
        1:
            _719 <= _712;
        2:
            _719 <= _331;
        3:
            _719 <= _714;
        4:
            _719 <= _716;
        5:
            _719 <= _375;
        6:
            _719 <= _718;
        7:
            _719 <= _425;
        8:
            _719 <= _425;
        9:
            _719 <= _425;
        10:
            _719 <= _425;
        11:
            _719 <= _31;
        12:
            _719 <= _30;
        13:
            _719 <= _29;
        14:
            _719 <= _28;
        default:
            _719 <= _27;
        endcase
    end
    assign _689 = _658[763:732];
    assign _35 = _689;
    assign _690 = _658[635:604];
    assign _36 = _690;
    assign _691 = _658[507:476];
    assign _37 = _691;
    assign _692 = _658[379:348];
    assign _38 = _692;
    assign _693 = _658[251:220];
    assign _39 = _693;
    assign _709 = { _735,
                    _593 };
    assign _694 = _658[979:964];
    assign _40 = _694;
    assign _707 = { _733,
                    _40 };
    assign _695 = _658[204:200];
    assign _41 = _695;
    assign _705 = { _731,
                    _41 };
    assign _702 = _271[30:0];
    assign _652 = 2'b00;
    assign _653 = _549 == _652;
    assign _650 = _554 & _558;
    assign _651 = _650 & _567;
    assign _654 = _651 & _653;
    assign _647 = 2'b01;
    assign _648 = _549 == _647;
    assign _645 = _554 & _558;
    assign _646 = _645 & _567;
    assign _649 = _646 & _648;
    assign _642 = 2'b10;
    assign _643 = _549 == _642;
    assign _640 = _554 & _558;
    assign _641 = _640 & _567;
    assign _644 = _641 & _643;
    assign _637 = 2'b11;
    assign _638 = _549 == _637;
    assign _635 = _554 & _558;
    assign _636 = _635 & _567;
    assign _639 = _636 & _638;
    assign _656 = { _746,
                    _639,
                    _644,
                    _649,
                    _654,
                    _750 };
    assign _629 = 4'b0110;
    assign _630 = _219 == _629;
    assign _627 = _215 == _637;
    assign _625 = _131 & _213;
    assign _628 = _625 & _627;
    assign _631 = _628 & _630;
    assign _624 = 1'b0;
    assign _622 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _632 <= _624;
        else
            if (_631)
                _632 <= _622;
    end
    assign _633 = { _735,
                    _632 };
    assign _617 = _219 == _629;
    assign _614 = _215 == _642;
    assign _612 = _131 & _213;
    assign _615 = _612 & _614;
    assign _618 = _615 & _617;
    assign _609 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _619 <= _624;
        else
            if (_618)
                _619 <= _609;
    end
    assign _620 = { _735,
                    _619 };
    assign _604 = _219 == _629;
    assign _601 = _215 == _647;
    assign _599 = _131 & _213;
    assign _602 = _599 & _601;
    assign _605 = _602 & _604;
    assign _596 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _606 <= _624;
        else
            if (_605)
                _606 <= _596;
    end
    assign _607 = { _735,
                    _606 };
    assign _591 = _219 == _629;
    assign _588 = _215 == _652;
    assign _586 = _131 & _213;
    assign _589 = _586 & _588;
    assign _592 = _589 & _591;
    assign _583 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _593 <= _624;
        else
            if (_592)
                _593 <= _583;
    end
    assign _594 = { _735,
                    _593 };
    assign _581 = _71[15:0];
    assign _578 = _158[8:8];
    assign _575 = _158[9:9];
    assign _576 = ~ _575;
    assign _577 = _161 & _576;
    assign _579 = _577 & _578;
    assign _580 = _579 & _131;
    assign _574 = _71[15:0];
    assign _571 = 4'b0100;
    assign _572 = _219 == _571;
    assign _570 = _131 & _213;
    assign _573 = _570 & _572;
    assign _563 = _42[11:11];
    assign _562 = _42[10:10];
    assign _561 = _42[9:9];
    assign _696 = _658[135:104];
    assign _42 = _696;
    assign _560 = _42[8:8];
    always @* begin
        case (_549)
        0:
            _564 <= _560;
        1:
            _564 <= _561;
        2:
            _564 <= _562;
        default:
            _564 <= _563;
        endcase
    end
    always @(posedge _55) begin
        if (_413)
            _567 <= _564;
    end
    assign _568 = ~ _567;
    assign _556 = 4'b0101;
    assign _555 = _169[5:2];
    assign _557 = _555 == _556;
    assign _558 = _167 & _557;
    assign _552 = 5'b01000;
    assign _553 = _122 == _552;
    assign _550 = _94 & _104;
    assign _551 = _550 & _126;
    assign _554 = _551 & _553;
    assign _559 = _554 & _558;
    assign _569 = _559 & _568;
    assign _549 = _169[1:0];
    assign _545 = _169[5:2];
    assign _547 = _545 == _571;
    assign _544 = _131 & _167;
    assign _548 = _544 & _547;
    assign _539 = 6'b000100;
    assign _540 = _169 == _539;
    assign _538 = _131 & _167;
    assign _541 = _538 & _540;
    assign _543 = _541 ? _71 : _425;
    assign _536 = _71[7:0];
    assign _532 = 6'b000111;
    assign _533 = _169 == _532;
    assign _531 = _131 & _167;
    assign _534 = _531 & _533;
    assign _537 = _534 ? _536 : _750;
    assign _529 = _71[7:0];
    assign _525 = 6'b000110;
    assign _526 = _169 == _525;
    assign _524 = _131 & _167;
    assign _527 = _524 & _526;
    assign _530 = _527 ? _529 : _750;
    assign _519 = _319[31:30];
    assign _518 = _71[31:30];
    assign _520 = _518 == _519;
    assign _521 = ~ _520;
    assign _515 = 4'b0010;
    assign _516 = _219 == _515;
    assign _513 = _215 == _652;
    assign _511 = _131 & _213;
    assign _514 = _511 & _513;
    assign _517 = _514 & _516;
    assign _522 = _517 & _521;
    assign _507 = _331[31:30];
    assign _506 = _71[31:30];
    assign _508 = _506 == _507;
    assign _509 = ~ _508;
    assign _504 = _219 == _515;
    assign _501 = _215 == _647;
    assign _499 = _131 & _213;
    assign _502 = _499 & _501;
    assign _505 = _502 & _504;
    assign _510 = _505 & _509;
    assign _495 = _343[31:30];
    assign _494 = _71[31:30];
    assign _496 = _494 == _495;
    assign _497 = ~ _496;
    assign _492 = _219 == _515;
    assign _489 = _215 == _642;
    assign _487 = _131 & _213;
    assign _490 = _487 & _489;
    assign _493 = _490 & _492;
    assign _498 = _493 & _497;
    assign _483 = _355[31:30];
    assign _482 = _71[31:30];
    assign _484 = _482 == _483;
    assign _485 = ~ _484;
    assign _480 = _219 == _515;
    assign _477 = _215 == _637;
    assign _475 = _131 & _213;
    assign _478 = _475 & _477;
    assign _481 = _478 & _480;
    assign _486 = _481 & _485;
    assign _523 = { _486,
                    _498,
                    _510,
                    _522 };
    assign _472 = _71[8:8];
    assign _473 = _456 & _472;
    assign _470 = _71[9:9];
    assign _471 = _456 & _470;
    assign _468 = _71[10:10];
    assign _469 = _456 & _468;
    assign _466 = _71[11:11];
    assign _467 = _456 & _466;
    assign _474 = { _467,
                    _469,
                    _471,
                    _473 };
    assign _463 = _71[4:4];
    assign _464 = _456 & _463;
    assign _461 = _71[5:5];
    assign _462 = _456 & _461;
    assign _459 = _71[6:6];
    assign _460 = _456 & _459;
    assign _457 = _71[7:7];
    assign _454 = 6'b000010;
    assign _455 = _169 == _454;
    assign _453 = _131 & _167;
    assign _456 = _453 & _455;
    assign _458 = _456 & _457;
    assign _465 = { _458,
                    _460,
                    _462,
                    _464 };
    assign _44 = uio_in;
    assign _452 = { _750,
                    _57,
                    _451,
                    _44 };
    assign _401 = 6'b001010;
    assign _402 = _169 == _401;
    assign _400 = _131 & _167;
    assign _403 = _400 & _402;
    assign _397 = _71[23:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _404 <= _421;
        else
            if (_403)
                _404 <= _397;
    end
    assign _405 = { _750,
                    _404 };
    assign _393 = _219 == _556;
    assign _390 = _215 == _637;
    assign _388 = _131 & _213;
    assign _391 = _388 & _390;
    assign _394 = _391 & _393;
    assign _386 = 32'b00010100000000000000000000000000;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _395 <= _386;
        else
            if (_394)
                _395 <= _71;
    end
    assign _383 = _219 == _556;
    assign _380 = _215 == _642;
    assign _378 = _131 & _213;
    assign _381 = _378 & _380;
    assign _384 = _381 & _383;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _385 <= _386;
        else
            if (_384)
                _385 <= _71;
    end
    assign _373 = _219 == _556;
    assign _370 = _215 == _647;
    assign _368 = _131 & _213;
    assign _371 = _368 & _370;
    assign _374 = _371 & _373;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _375 <= _386;
        else
            if (_374)
                _375 <= _71;
    end
    assign _363 = _219 == _556;
    assign _360 = _215 == _652;
    assign _358 = _131 & _213;
    assign _361 = _358 & _360;
    assign _364 = _361 & _363;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _365 <= _386;
        else
            if (_364)
                _365 <= _71;
    end
    assign _353 = _219 == _515;
    assign _350 = _215 == _637;
    assign _348 = _131 & _213;
    assign _351 = _348 & _350;
    assign _354 = _351 & _353;
    assign _346 = 32'b00000000000011000000000000000000;
    assign _344 = 32'b11111111111111110000000000000000;
    assign _345 = _71 & _344;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _355 <= _346;
        else
            if (_354)
                _355 <= _345;
    end
    assign _341 = _219 == _515;
    assign _338 = _215 == _642;
    assign _336 = _131 & _213;
    assign _339 = _336 & _338;
    assign _342 = _339 & _341;
    assign _333 = _71 & _344;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _343 <= _346;
        else
            if (_342)
                _343 <= _333;
    end
    assign _329 = _219 == _515;
    assign _326 = _215 == _647;
    assign _324 = _131 & _213;
    assign _327 = _324 & _326;
    assign _330 = _327 & _329;
    assign _321 = _71 & _344;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _331 <= _346;
        else
            if (_330)
                _331 <= _321;
    end
    assign _317 = _219 == _515;
    assign _314 = _215 == _652;
    assign _312 = _131 & _213;
    assign _315 = _312 & _314;
    assign _318 = _315 & _317;
    assign _309 = _71 & _344;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _319 <= _346;
        else
            if (_318)
                _319 <= _309;
    end
    assign _304 = 4'b0001;
    assign _305 = _219 == _304;
    assign _302 = _215 == _637;
    assign _300 = _131 & _213;
    assign _303 = _300 & _302;
    assign _306 = _303 & _305;
    assign _298 = 32'b00000000000000011111000000000000;
    assign _296 = 32'b01111111111111111111111110011111;
    assign _297 = _71 & _296;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _307 <= _298;
        else
            if (_306)
                _307 <= _297;
    end
    assign _293 = _219 == _304;
    assign _290 = _215 == _642;
    assign _288 = _131 & _213;
    assign _291 = _288 & _290;
    assign _294 = _291 & _293;
    assign _285 = _71 & _296;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _295 <= _298;
        else
            if (_294)
                _295 <= _285;
    end
    assign _281 = _219 == _304;
    assign _278 = _215 == _647;
    assign _276 = _131 & _213;
    assign _279 = _276 & _278;
    assign _282 = _279 & _281;
    assign _273 = _71 & _296;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _283 <= _298;
        else
            if (_282)
                _283 <= _273;
    end
    assign _269 = _219 == _304;
    assign _266 = _215 == _652;
    assign _264 = _131 & _213;
    assign _267 = _264 & _266;
    assign _270 = _267 & _269;
    assign _261 = _71 & _296;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _271 <= _298;
        else
            if (_270)
                _271 <= _261;
    end
    assign _256 = 4'b0000;
    assign _257 = _219 == _256;
    assign _254 = _215 == _637;
    assign _252 = _131 & _213;
    assign _255 = _252 & _254;
    assign _258 = _255 & _257;
    assign _250 = 32'b00000000000000010000000000000000;
    assign _248 = 32'b11111111111111111111111100000000;
    assign _249 = _71 & _248;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _259 <= _250;
        else
            if (_258)
                _259 <= _249;
    end
    assign _245 = _219 == _256;
    assign _242 = _215 == _642;
    assign _240 = _131 & _213;
    assign _243 = _240 & _242;
    assign _246 = _243 & _245;
    assign _237 = _71 & _248;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _247 <= _250;
        else
            if (_246)
                _247 <= _237;
    end
    assign _233 = _219 == _256;
    assign _230 = _215 == _647;
    assign _228 = _131 & _213;
    assign _231 = _228 & _230;
    assign _234 = _231 & _233;
    assign _225 = _71 & _248;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _235 <= _250;
        else
            if (_234)
                _235 <= _225;
    end
    assign _169 = _158[7:2];
    assign _202 = _169 == _454;
    assign _200 = _131 & _167;
    assign _203 = _200 & _202;
    assign _197 = _71[3:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _204 <= _256;
        else
            if (_203)
                _204 <= _197;
    end
    pio_block
        pio_block
        ( .clock(_55),
          .rst_n(core_rst_n),
          .sm_enable(_204),
          .clkdiv0(_223),
          .clkdiv1(_235),
          .clkdiv2(_247),
          .clkdiv3(_259),
          .execctrl0(_271),
          .execctrl1(_283),
          .execctrl2(_295),
          .execctrl3(_307),
          .shiftctrl0(_319),
          .shiftctrl1(_331),
          .shiftctrl2(_343),
          .shiftctrl3(_355),
          .pinctrl0(_365),
          .pinctrl1(_375),
          .pinctrl2(_385),
          .pinctrl3(_395),
          .sync_bypass(_405),
          .pins_in(_452),
          .sm_restart(_465),
          .clkdiv_restart(_474),
          .fifo_flush(_523),
          .irq_clear(_530),
          .irq_force(_537),
          .fdebug_clear(_543),
          .txf_push(_548),
          .txf_sm(_549),
          .txf_data(_71),
          .rxf_pop(_569),
          .rxf_sm(_549),
          .instr_write(_573),
          .instr_sm(_215),
          .instr_data(_574),
          .imem_write(_580),
          .imem_addr(_169),
          .imem_data(_581),
          .ext0(_594),
          .ext1(_607),
          .ext2(_620),
          .ext3(_633),
          .fdebug_set(_656),
          .dbg_instr3(_658[1027:1012]),
          .dbg_instr2(_658[1011:996]),
          .dbg_instr1(_658[995:980]),
          .dbg_instr0(_658[979:964]),
          .dbg_phase3(_658[963:939]),
          .dbg_phase2(_658[938:914]),
          .dbg_phase1(_658[913:889]),
          .dbg_phase0(_658[888:864]),
          .dbg_exec_stalled3(_658[863:863]),
          .dbg_exec_stalled2(_658[862:862]),
          .dbg_exec_stalled1(_658[861:861]),
          .dbg_exec_stalled0(_658[860:860]),
          .dbg_cnt3(_658[859:828]),
          .dbg_cnt2(_658[827:796]),
          .dbg_cnt1(_658[795:764]),
          .dbg_cnt0(_658[763:732]),
          .dbg_osr3(_658[731:700]),
          .dbg_osr2(_658[699:668]),
          .dbg_osr1(_658[667:636]),
          .dbg_osr0(_658[635:604]),
          .dbg_isr3(_658[603:572]),
          .dbg_isr2(_658[571:540]),
          .dbg_isr1(_658[539:508]),
          .dbg_isr0(_658[507:476]),
          .dbg_y3(_658[475:444]),
          .dbg_y2(_658[443:412]),
          .dbg_y1(_658[411:380]),
          .dbg_y0(_658[379:348]),
          .dbg_x3(_658[347:316]),
          .dbg_x2(_658[315:284]),
          .dbg_x1(_658[283:252]),
          .dbg_x0(_658[251:220]),
          .dbg_pc3(_658[219:215]),
          .dbg_pc2(_658[214:210]),
          .dbg_pc1(_658[209:205]),
          .dbg_pc0(_658[204:200]),
          .fdebug(_658[199:168]),
          .flevel(_658[167:136]),
          .fstat(_658[135:104]),
          .rxf_data(_658[103:72]),
          .irq(_658[71:64]),
          .pins_oe(_658[63:32]),
          .pins_out(_658[31:0]) );
    assign _697 = _658[860:860];
    assign _45 = _697;
    assign _703 = { _45,
                    _702 };
    assign _221 = _219 == _256;
    assign _217 = _215 == _652;
    assign _129 = 5'b11111;
    assign _130 = _122 == _129;
    assign _127 = ~ _126;
    assign _105 = _94 & _104;
    assign _128 = _105 & _127;
    assign _131 = _128 & _130;
    assign _214 = _131 & _213;
    assign _218 = _214 & _217;
    assign _222 = _218 & _221;
    assign _206 = _71 & _248;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _223 <= _250;
        else
            if (_222)
                _223 <= _206;
    end
    assign _219 = _158[5:2];
    always @* begin
        case (_219)
        0:
            _710 <= _223;
        1:
            _710 <= _703;
        2:
            _710 <= _319;
        3:
            _710 <= _705;
        4:
            _710 <= _707;
        5:
            _710 <= _365;
        6:
            _710 <= _709;
        7:
            _710 <= _425;
        8:
            _710 <= _425;
        9:
            _710 <= _425;
        10:
            _710 <= _425;
        11:
            _710 <= _39;
        12:
            _710 <= _38;
        13:
            _710 <= _37;
        14:
            _710 <= _36;
        default:
            _710 <= _35;
        endcase
    end
    assign _215 = _158[7:6];
    always @* begin
        case (_215)
        0:
            _738 <= _710;
        1:
            _738 <= _719;
        2:
            _738 <= _728;
        default:
            _738 <= _737;
        endcase
    end
    assign _211 = _158[8:8];
    assign _212 = ~ _211;
    assign _209 = _158[9:9];
    assign _210 = _161 & _209;
    assign _213 = _210 & _212;
    assign _739 = _213 ? _738 : _425;
    assign _165 = _158[8:8];
    assign _166 = ~ _165;
    assign _162 = _158[9:9];
    assign _163 = ~ _162;
    assign _160 = 6'b000000;
    assign _698 = _71[30:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _701 <= _735;
        else
            if (_94)
                _701 <= _698;
    end
    assign _46 = _701;
    assign _71 = { _46,
                   _70 };
    assign _152 = _71[15:2];
    assign _154 = { _152,
                    _652 };
    assign _149 = 16'b0000000000000100;
    assign _150 = _47 + _149;
    assign _47 = _158;
    assign _143 = 5'b00001;
    assign _144 = _122 == _143;
    assign _141 = ~ _104;
    assign _142 = _94 & _141;
    assign _145 = _142 & _144;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _146 <= gnd;
        else
            if (_145)
                _146 <= _70;
    end
    assign _147 = ~ _146;
    assign _137 = _122 == _552;
    assign _135 = _122 == _129;
    assign _138 = _126 ? _137 : _135;
    assign _133 = _94 & _104;
    assign _139 = _133 & _138;
    assign _148 = _139 & _147;
    assign _151 = _148 ? _150 : _47;
    assign _132 = _94 & _112;
    assign _155 = _132 ? _154 : _151;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _158 <= _733;
        else
            _158 <= _155;
    end
    assign _159 = _158[15:10];
    assign _161 = _159 == _160;
    assign _164 = _161 & _163;
    assign _167 = _164 & _166;
    assign _760 = _167 ? _759 : _739;
    assign _48 = _760;
    assign _414 = _51[30:0];
    assign _416 = { _414,
                    _624 };
    assign _411 = 5'b00111;
    assign _412 = _122 == _411;
    assign _123 = 5'b00000;
    assign _124 = _122 == _123;
    assign _107 = ~ _104;
    assign _108 = _94 & _107;
    assign _125 = _108 & _124;
    assign _60 = _57[6:6];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _68 <= gnd;
        else
            _68 <= _60;
    end
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _70 <= gnd;
        else
            _70 <= _68;
    end
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _126 <= gnd;
        else
            if (_125)
                _126 <= _70;
    end
    assign _98 = 5'b10111;
    assign _114 = _49 + _143;
    assign _111 = _49 == _98;
    assign _109 = ~ _50;
    assign _112 = _109 & _111;
    assign _116 = _112 ? _123 : _114;
    assign _117 = _94 ? _116 : _49;
    assign _119 = _96 ? _123 : _117;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _122 <= _123;
        else
            _122 <= _119;
    end
    assign _49 = _122;
    assign _99 = _49 == _98;
    assign _100 = _94 & _99;
    assign _50 = _104;
    assign _101 = _50 | _100;
    assign _97 = ~ _96;
    assign _102 = _97 & _101;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _104 <= gnd;
        else
            _104 <= _102;
    end
    assign _409 = _94 & _104;
    assign _410 = _409 & _126;
    assign _413 = _410 & _412;
    assign _417 = _413 ? _48 : _416;
    assign _51 = _426;
    assign _93 = ~ _92;
    assign _89 = ~ _88;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _81 <= gnd;
        else
            _81 <= _79;
    end
    assign _82 = ~ _81;
    assign _75 = _57[5:5];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _77 <= gnd;
        else
            _77 <= _75;
    end
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _79 <= gnd;
        else
            _79 <= _77;
    end
    assign _83 = _79 & _82;
    assign _90 = _83 & _89;
    assign _94 = _90 & _93;
    assign _418 = _94 ? _417 : _51;
    assign _407 = ~ _92;
    assign _408 = _88 & _407;
    assign _420 = _408 ? _425 : _418;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _92 <= vdd;
        else
            _92 <= _88;
    end
    assign gnd = 1'b0;
    assign _53 = rst_n;
    assign vdd = 1'b1;
    always @(posedge _55 or negedge _53) begin
        if (_53 == 0)
            rst_sync1 <= gnd;
        else
            rst_sync1 <= vdd;
    end
    always @(posedge _55 or negedge _53) begin
        if (_53 == 0)
            core_rst_n <= gnd;
        else
            core_rst_n <= rst_sync1;
    end
    assign _55 = clk;
    assign _57 = ui_in;
    assign _84 = _57[7:7];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _86 <= vdd;
        else
            _86 <= _84;
    end
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _88 <= vdd;
        else
            _88 <= _86;
    end
    assign _95 = ~ _88;
    assign _96 = _95 & _92;
    assign _423 = _96 ? _422 : _420;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _426 <= _425;
        else
            _426 <= _423;
    end
    assign _427 = _426[31:31];
    assign _451 = { _427,
                    _449,
                    _450 };
    assign uo_out = _451;
    assign uio_out = _179;
    assign uio_oe = _177;

endmodule
