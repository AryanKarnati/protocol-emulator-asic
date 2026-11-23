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

    wire [24:0] _88;
    wire _319;
    wire _2;
    wire _316;
    wire _317;
    wire exec_stalled_next;
    reg exec_stalled_q;
    wire [1:0] _436;
    wire [2:0] _434;
    wire [3:0] _412;
    wire [3:0] _408;
    wire [3:0] imem_stall_next;
    reg [3:0] imem_stall_q;
    wire [3:0] _4;
    wire [3:0] _405;
    wire [3:0] _403;
    wire [3:0] _401;
    wire [3:0] _398;
    wire [3:0] _396;
    wire [3:0] _395;
    reg [3:0] _399;
    wire [3:0] _393;
    wire [3:0] _394;
    wire [3:0] _400;
    wire [3:0] _402;
    wire [3:0] _404;
    wire _391;
    wire [3:0] stall_code;
    wire [3:0] stall_reason_now;
    wire [3:0] _423;
    wire [3:0] latch_stall_next;
    reg [3:0] latch_stall_q;
    wire [3:0] _5;
    wire _431;
    wire _432;
    wire [3:0] stall_reason;
    wire [31:0] dbg_cnt_0;
    wire _928;
    wire illegal_0;
    wire _930;
    wire rxstall_0;
    wire out_empty_stall;
    wire txstall_0;
    wire [31:0] rx_push_data_0;
    wire rx_push_0;
    wire _936;
    wire _937;
    wire tx_pop_0;
    wire _968;
    wire _969;
    wire [2:0] _964;
    wire _965;
    wire _966;
    wire [2:0] _961;
    wire _962;
    wire _963;
    wire [2:0] _958;
    wire _959;
    wire _960;
    wire [2:0] _955;
    wire _956;
    wire _957;
    wire [2:0] _952;
    wire _953;
    wire _954;
    wire [2:0] _949;
    wire _950;
    wire _951;
    wire [2:0] _946;
    wire _947;
    wire [1:0] _941;
    wire _942;
    wire wait_done;
    wire _943;
    wire wait_irq_clr;
    wire irq_clr_now;
    wire _945;
    wire _948;
    wire [7:0] irq_clr_out;
    wire _995;
    wire _996;
    wire _992;
    wire _993;
    wire _989;
    wire _990;
    wire _986;
    wire _987;
    wire _983;
    wire _984;
    wire _980;
    wire _981;
    wire _977;
    wire _978;
    wire _974;
    wire _971;
    wire irq_set_now;
    wire _975;
    wire [7:0] irq_set_out;
    wire [31:0] _1304;
    wire _1162;
    wire [1:0] _1163;
    wire [3:0] _1164;
    wire [7:0] _1165;
    wire [15:0] _1166;
    wire [31:0] _1167;
    wire [31:0] _1168;
    wire [31:0] dir_eff_val;
    wire [31:0] _1305;
    wire [31:0] ss_dir_val;
    wire [31:0] dir_val_out;
    wire _1307;
    wire [1:0] _1308;
    wire [3:0] _1309;
    wire [7:0] _1310;
    wire [15:0] _1311;
    wire [31:0] _1312;
    wire [31:0] _1313;
    wire [31:0] dir_eff_mask;
    wire [31:0] ss_dir_mask;
    wire [31:0] dir_mask_out;
    wire [31:0] _1346;
    wire [31:0] _1331;
    wire [1:0] _1169;
    wire [3:0] _1170;
    wire [7:0] _1171;
    wire [15:0] _1172;
    wire [31:0] _1173;
    wire [31:0] dir_new_val;
    wire [15:0] _1202;
    wire [15:0] _1201;
    wire [31:0] _1203;
    wire [7:0] _1198;
    wire [23:0] _1197;
    wire [31:0] _1199;
    wire [3:0] _1194;
    wire [27:0] _1193;
    wire [31:0] _1195;
    wire [1:0] _1190;
    wire [29:0] _1189;
    wire [31:0] _1191;
    wire _1186;
    wire [30:0] _1185;
    wire [31:0] _1187;
    wire [31:0] _1183;
    wire [31:0] _1184;
    wire _1182;
    wire [31:0] _1188;
    wire _1181;
    wire [31:0] _1192;
    wire _1180;
    wire [31:0] _1196;
    wire _1179;
    wire [31:0] _1200;
    wire _1178;
    wire [31:0] _1204;
    wire [31:0] pin_val;
    wire [1:0] _1322;
    wire [3:0] _1323;
    wire [7:0] _1324;
    wire [15:0] _1325;
    wire [31:0] _1326;
    wire [31:0] lvl_new_val;
    wire [31:0] _1328;
    wire [31:0] _1329;
    wire [31:0] _1330;
    reg [31:0] sticky_val_q;
    wire [31:0] _21;
    wire _1335;
    wire _1336;
    wire [1:0] _1337;
    wire [3:0] _1338;
    wire [7:0] _1339;
    wire [15:0] _1340;
    wire [31:0] _1341;
    wire [31:0] _1342;
    wire [31:0] lvl_eff_val;
    wire [31:0] _1347;
    wire [31:0] _1333;
    wire [15:0] _1024;
    wire [15:0] _1023;
    wire [31:0] _1025;
    wire [7:0] _1020;
    wire [23:0] _1019;
    wire [31:0] _1021;
    wire [3:0] _1016;
    wire [27:0] _1015;
    wire [31:0] _1017;
    wire [1:0] _1012;
    wire [29:0] _1011;
    wire [31:0] _1013;
    wire _1008;
    wire [30:0] _1007;
    wire [31:0] _1009;
    wire [4:0] _1005;
    wire [26:0] _1004;
    wire [31:0] _1006;
    wire _1003;
    wire [31:0] _1010;
    wire _1002;
    wire [31:0] _1014;
    wire _1001;
    wire [31:0] _1018;
    wire _1000;
    wire [31:0] _1022;
    wire _999;
    wire [31:0] _1026;
    wire [31:0] ss_val;
    wire [31:0] ss_lvl_val;
    wire [31:0] lvl_val_out;
    wire [1:0] _1314;
    wire [3:0] _1315;
    wire [7:0] _1316;
    wire [15:0] _1317;
    wire [31:0] _1318;
    wire [31:0] dir_new_mask;
    wire [15:0] _1297;
    wire [15:0] _1296;
    wire [31:0] _1298;
    wire [7:0] _1293;
    wire [23:0] _1292;
    wire [31:0] _1294;
    wire [3:0] _1289;
    wire [27:0] _1288;
    wire [31:0] _1290;
    wire [1:0] _1285;
    wire [29:0] _1284;
    wire [31:0] _1286;
    wire _1281;
    wire [30:0] _1280;
    wire [31:0] _1282;
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
    wire [5:0] _1225;
    wire _1226;
    wire [5:0] _1223;
    wire _1224;
    wire [5:0] _1221;
    wire _1222;
    wire [5:0] _1219;
    wire _1220;
    wire [5:0] _1217;
    wire _1218;
    wire [2:0] _1213;
    wire [5:0] _1214;
    wire [5:0] _1211;
    wire [5:0] _1215;
    wire [5:0] _1210;
    wire _1216;
    wire [31:0] _1279;
    wire _1209;
    wire [31:0] _1283;
    wire _1208;
    wire [31:0] _1287;
    wire _1207;
    wire [31:0] _1291;
    wire _1206;
    wire [31:0] _1295;
    wire [4:0] _1176;
    wire [4:0] _1175;
    wire set_write;
    wire [4:0] _1177;
    wire _1205;
    wire [31:0] pin_mask;
    wire [1:0] _1349;
    wire [3:0] _1350;
    wire [7:0] _1351;
    wire [15:0] _1352;
    wire [31:0] _1353;
    wire [31:0] lvl_new_mask;
    wire [31:0] _1355;
    wire [31:0] _1356;
    wire [31:0] _1357;
    reg [31:0] sticky_mask_q;
    wire [31:0] _23;
    wire _1360;
    wire _1361;
    reg sticky_isdir_q;
    wire _24;
    wire _1372;
    wire _1160;
    wire _1161;
    wire _1373;
    wire [1:0] _1374;
    wire [3:0] _1375;
    wire [7:0] _1376;
    wire [15:0] _1377;
    wire [31:0] _1378;
    wire [31:0] _1379;
    wire _1156;
    wire set_dirs;
    wire _1153;
    wire out_dirs;
    wire dir_write_now;
    wire _1149;
    wire set_pins;
    wire _1145;
    wire mov_pins;
    wire _1142;
    wire out_pins;
    wire _1147;
    wire lvl_write_now;
    wire write_any;
    wire [31:0] lvl_eff_mask;
    wire _1134;
    wire [1:0] _1135;
    wire [3:0] _1136;
    wire [7:0] _1137;
    wire [15:0] _1138;
    wire [31:0] _1139;
    wire [31:0] _1344;
    wire _1125;
    wire _1364;
    wire latch_ss_next;
    reg latch_ss_q;
    wire _25;
    wire _1368;
    wire imem_ss_next;
    reg imem_ss_q;
    wire _26;
    wire ss_flag;
    wire _1123;
    wire _1124;
    wire ss_apply;
    wire [1:0] _1127;
    wire [3:0] _1128;
    wire [7:0] _1129;
    wire [15:0] _1130;
    wire [31:0] _1131;
    wire [15:0] _1119;
    wire [15:0] _1118;
    wire [31:0] _1120;
    wire [7:0] _1115;
    wire [23:0] _1114;
    wire [31:0] _1116;
    wire [3:0] _1111;
    wire [27:0] _1110;
    wire [31:0] _1112;
    wire [1:0] _1107;
    wire [29:0] _1106;
    wire [31:0] _1108;
    wire _1103;
    wire [30:0] _1102;
    wire [31:0] _1104;
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
    wire _1046;
    wire _1044;
    wire _1042;
    wire _1040;
    wire [4:0] _1035;
    wire [5:0] _1036;
    wire [5:0] _1034;
    wire [5:0] ss_nbits;
    wire _1038;
    wire [31:0] _1101;
    wire _1031;
    wire [31:0] _1105;
    wire _1030;
    wire [31:0] _1109;
    wire _1029;
    wire [31:0] _1113;
    wire _1028;
    wire [31:0] _1117;
    wire [4:0] _998;
    wire _1027;
    wire [31:0] _1121;
    wire [31:0] ss_mask;
    wire [31:0] ss_lvl_mask;
    wire [31:0] lvl_mask_out;
    wire [4:0] _1394;
    wire [4:0] _1392;
    wire [4:0] _1391;
    wire [4:0] _1393;
    wire [4:0] pc_target;
    wire [4:0] _1388;
    wire [4:0] _1386;
    wire [4:0] _1387;
    wire [4:0] _1384;
    wire _1385;
    wire [4:0] pc_adv;
    wire [4:0] _28;
    wire _1382;
    wire imem_done;
    wire [4:0] _1390;
    wire _384;
    wire mov_pc;
    wire _376;
    wire out_pc;
    wire _369;
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
    wire _341;
    wire _340;
    wire _339;
    wire _338;
    wire _337;
    wire _336;
    wire [4:0] _335;
    reg _368;
    wire _333;
    wire _334;
    wire _332;
    wire _331;
    wire _329;
    wire _328;
    reg jmp_cond_val;
    wire _324;
    wire _90;
    wire _91;
    wire _94;
    wire _97;
    wire _1400;
    wire latch_forced_next;
    reg latch_forced_q;
    wire _29;
    wire _1404;
    wire _414;
    wire clr_latch_scope;
    wire latch_irqw_next;
    reg latch_irqw_q;
    wire _30;
    wire [4:0] _1422;
    wire [4:0] _1417;
    wire exec_form;
    wire [4:0] _1419;
    wire _1414;
    wire _1412;
    wire complete;
    wire _1415;
    wire [4:0] _1420;
    wire _1410;
    wire _1408;
    wire _1409;
    wire dec_now;
    wire [4:0] delay_next;
    wire [4:0] _1425;
    reg [4:0] delay_q;
    wire [4:0] _31;
    wire delay_zero;
    wire _99;
    wire _100;
    wire attempt_imem;
    wire _1429;
    wire _33;
    wire pc_write_latch;
    wire _388;
    wire imem_clr;
    wire imem_irqw_next;
    reg imem_irqw_q;
    wire _34;
    wire irq_state;
    wire _312;
    wire _313;
    wire _309;
    wire _306;
    wire _307;
    wire _304;
    wire _303;
    wire _305;
    wire irq_set_form;
    wire irqw_form;
    wire irq_stall;
    wire _298;
    wire _294;
    wire _293;
    wire _292;
    wire _291;
    wire _290;
    wire _289;
    wire _288;
    wire [7:0] _36;
    wire _287;
    wire [1:0] _38;
    wire [1:0] _283;
    wire [1:0] _284;
    wire _282;
    wire [2:0] _285;
    wire [2:0] _281;
    wire _280;
    wire [2:0] flag_idx;
    reg flag_val;
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
    wire _249;
    wire _248;
    wire _247;
    reg _279;
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
    wire _190;
    wire _189;
    wire _188;
    wire [4:0] _187;
    reg _220;
    wire [1:0] _186;
    reg wait_bit;
    wire wait_cond;
    wire _300;
    wire _184;
    wire _183;
    wire _185;
    wire wait_stall;
    wire _172;
    wire in_stall;
    wire _151;
    wire pull_stall;
    wire _129;
    wire push_stall;
    wire _154;
    wire _174;
    wire _182;
    wire _302;
    wire stall;
    wire _321;
    wire latch_done;
    wire _1466;
    wire _416;
    wire _372;
    wire _176;
    wire _109;
    wire _110;
    wire _105;
    wire [2:0] _104;
    wire [15:0] _1464;
    wire [15:0] _40;
    wire [15:0] _1459;
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
    wire _815;
    wire _813;
    wire _811;
    wire _809;
    wire [31:0] _872;
    wire [31:0] _873;
    wire [15:0] _804;
    wire [31:0] _805;
    wire [23:0] _800;
    wire [7:0] _799;
    wire [31:0] _801;
    wire [27:0] _796;
    wire [31:0] _797;
    wire [29:0] _792;
    wire [31:0] _793;
    wire [30:0] _788;
    wire [31:0] _789;
    wire [31:0] _42;
    wire [15:0] _587;
    wire [31:0] _588;
    wire [23:0] _583;
    wire [31:0] _584;
    wire [27:0] _579;
    wire [31:0] _580;
    wire [29:0] _575;
    wire [31:0] _576;
    wire [30:0] _571;
    wire [31:0] _572;
    wire _569;
    wire [31:0] _573;
    wire _568;
    wire [31:0] _577;
    wire _567;
    wire [31:0] _581;
    wire _566;
    wire [31:0] _585;
    wire [4:0] _564;
    wire _565;
    wire [31:0] _589;
    wire [5:0] _562;
    wire _563;
    wire [31:0] _590;
    wire [15:0] _557;
    wire [31:0] _559;
    wire [23:0] _553;
    wire [31:0] _555;
    wire [27:0] _549;
    wire [31:0] _551;
    wire [29:0] _545;
    wire [31:0] _547;
    wire [30:0] _541;
    wire [31:0] _543;
    wire _540;
    wire [31:0] _544;
    wire _539;
    wire [31:0] _548;
    wire _538;
    wire [31:0] _552;
    wire _537;
    wire [31:0] _556;
    wire [4:0] _535;
    wire _536;
    wire [31:0] _560;
    wire _534;
    wire [31:0] _561;
    wire [31:0] osr_shifted;
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
    wire _503;
    wire _502;
    wire _501;
    wire _500;
    wire _499;
    wire _498;
    wire _497;
    wire _496;
    wire [31:0] _528;
    wire [31:0] _495;
    wire [15:0] _768;
    wire [31:0] _770;
    wire [23:0] _764;
    wire [31:0] _766;
    wire [27:0] _760;
    wire [31:0] _762;
    wire [29:0] _756;
    wire [31:0] _758;
    wire [30:0] _752;
    wire [31:0] _754;
    wire _751;
    wire [31:0] _755;
    wire _750;
    wire [31:0] _759;
    wire _749;
    wire [31:0] _763;
    wire _748;
    wire [31:0] _767;
    wire [4:0] _746;
    wire _747;
    wire [31:0] _771;
    wire [5:0] _743;
    wire _745;
    wire [31:0] _772;
    wire [15:0] _738;
    wire [31:0] _739;
    wire [23:0] _734;
    wire [31:0] _735;
    wire [27:0] _730;
    wire [31:0] _731;
    wire [29:0] _726;
    wire [31:0] _727;
    wire [30:0] _722;
    wire [31:0] _723;
    wire _720;
    wire [31:0] _724;
    wire _719;
    wire [31:0] _728;
    wire _718;
    wire [31:0] _732;
    wire _717;
    wire [31:0] _736;
    wire [4:0] _715;
    wire _716;
    wire [31:0] _740;
    wire _714;
    wire [31:0] _741;
    wire [31:0] _773;
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
    wire _653;
    wire _651;
    wire _649;
    wire _647;
    wire [31:0] _710;
    wire [2:0] _644;
    reg [31:0] _645;
    wire [31:0] in_data;
    wire [15:0] _639;
    wire [31:0] _641;
    wire [23:0] _635;
    wire [31:0] _637;
    wire [27:0] _631;
    wire [31:0] _633;
    wire [29:0] _627;
    wire [31:0] _629;
    wire [30:0] _623;
    wire [31:0] _625;
    wire _622;
    wire [31:0] _626;
    wire _621;
    wire [31:0] _630;
    wire _620;
    wire [31:0] _634;
    wire _619;
    wire [31:0] _638;
    wire [4:0] _617;
    wire _618;
    wire [31:0] _642;
    wire _616;
    wire [31:0] _643;
    wire [31:0] _712;
    wire _614;
    wire [31:0] isr_new_in;
    wire [31:0] _775;
    wire _603;
    wire [5:0] _166;
    wire [6:0] _163;
    wire [6:0] _161;
    wire _612;
    wire in_shift;
    wire [5:0] _1434;
    wire _608;
    wire push_fire;
    wire _44;
    wire _128;
    wire _605;
    wire [5:0] _121;
    wire [4:0] _117;
    wire _119;
    wire [5:0] _123;
    wire _124;
    wire _115;
    wire _116;
    wire push_noop;
    wire _126;
    wire _113;
    wire _112;
    wire _114;
    wire push_try;
    wire _606;
    wire push_drop;
    wire push_clr;
    wire _1433;
    wire [5:0] _1436;
    wire [5:0] _1437;
    wire [5:0] isr_cnt_next;
    wire [5:0] _1441;
    reg [5:0] isr_cnt_q;
    wire [5:0] _45;
    wire [6:0] _159;
    wire [6:0] _162;
    wire _164;
    wire _165;
    wire [5:0] isr_cnt_new;
    wire _169;
    wire _170;
    wire _158;
    wire in_thr_hit;
    wire _156;
    wire _155;
    wire _157;
    wire _602;
    wire in_push;
    wire _611;
    wire [31:0] _776;
    wire _600;
    wire out_isr;
    wire [31:0] _875;
    wire _597;
    wire mov_isr;
    wire [31:0] isr_next;
    wire [31:0] _878;
    reg [31:0] isr_q;
    wire [31:0] _46;
    wire [3:0] _48;
    wire _487;
    wire [3:0] _485;
    wire [3:0] _50;
    wire _486;
    wire [31:0] _52;
    wire _484;
    wire status_bit;
    wire [1:0] _489;
    wire [3:0] _490;
    wire [7:0] _491;
    wire [15:0] _492;
    wire [31:0] _493;
    wire [31:0] _903;
    wire [31:0] _904;
    wire _895;
    wire set_y;
    wire [31:0] _900;
    wire _888;
    wire out_y;
    wire [31:0] _901;
    wire _885;
    wire mov_y;
    wire [31:0] _902;
    wire _882;
    wire y_dec;
    wire [31:0] y_next;
    reg [31:0] y_q;
    wire [31:0] _53;
    wire [31:0] _924;
    wire [4:0] _898;
    wire [31:0] _899;
    wire [2:0] _893;
    wire _918;
    wire _891;
    wire _890;
    wire _892;
    wire set_x;
    wire [31:0] _920;
    wire [2:0] _374;
    wire _915;
    wire out_x;
    wire [31:0] _921;
    wire _912;
    wire mov_x;
    wire [31:0] _922;
    wire [2:0] _326;
    wire _909;
    wire x_dec;
    wire [31:0] x_next;
    reg [31:0] x_q;
    wire [31:0] _54;
    wire [15:0] _244;
    wire [15:0] _243;
    wire [31:0] _245;
    wire [23:0] _240;
    wire [7:0] _239;
    wire [31:0] _241;
    wire [27:0] _236;
    wire [3:0] _235;
    wire [31:0] _237;
    wire [29:0] _232;
    wire [1:0] _231;
    wire [31:0] _233;
    wire [30:0] _228;
    wire _227;
    wire [31:0] _229;
    wire [31:0] _56;
    wire _226;
    wire [31:0] _230;
    wire _225;
    wire [31:0] _234;
    wire _224;
    wire [31:0] _238;
    wire _223;
    wire [31:0] _242;
    wire [31:0] _58;
    wire [4:0] _221;
    wire _222;
    wire [31:0] _246;
    wire [2:0] _482;
    reg [31:0] mov_src_val;
    wire [1:0] _481;
    reg [31:0] mov_data;
    wire [31:0] _530;
    wire [31:0] _531;
    wire [31:0] _592;
    wire _451;
    wire [5:0] _445;
    wire [6:0] _440;
    wire vdd;
    wire [5:0] _1451;
    wire _478;
    wire _473;
    wire _467;
    wire _464;
    wire _465;
    wire _462;
    wire _460;
    wire _60;
    wire [7:0] _62;
    wire [15:0] _64;
    wire _66;
    wire _68;
    wire [25:0] _87;
    wire _92;
    wire _70;
    wire tick_en;
    wire _459;
    wire _461;
    wire _463;
    wire _466;
    wire _468;
    wire _474;
    wire tx_pop_refill;
    wire _476;
    wire mov_osr;
    wire _152;
    wire _470;
    wire _469;
    wire pull_nb_empty;
    wire _456;
    wire _145;
    wire _138;
    wire _146;
    wire _136;
    wire _137;
    wire _147;
    wire pull_noop;
    wire _149;
    wire _132;
    wire _131;
    wire _133;
    wire pull_try;
    wire pull_data;
    wire pull_clr;
    wire _72;
    wire _453;
    wire [5:0] _142;
    wire [4:0] _139;
    wire _141;
    wire [5:0] _144;
    wire _178;
    wire _179;
    wire autopull_hit;
    wire out_hit;
    wire out_refill_stall;
    wire _1445;
    wire _1446;
    wire _1447;
    wire [5:0] _1449;
    wire [5:0] osr_cnt_next;
    wire [5:0] _1454;
    reg [5:0] osr_cnt_q;
    wire [5:0] _73;
    wire gnd;
    wire [6:0] _439;
    wire [6:0] _441;
    wire _443;
    wire _444;
    wire [5:0] osr_cnt_after;
    wire _448;
    wire _449;
    wire _134;
    wire _438;
    wire _450;
    wire out_refill_after;
    wire _455;
    wire _458;
    wire _480;
    wire [31:0] osr_next;
    reg [31:0] osr_q;
    wire [31:0] _74;
    wire _786;
    wire [31:0] _790;
    wire _785;
    wire [31:0] _794;
    wire _784;
    wire [31:0] _798;
    wire _783;
    wire [31:0] _802;
    wire [4:0] _781;
    wire _782;
    wire [31:0] _806;
    wire [5:0] _160;
    wire [5:0] _778;
    wire _780;
    wire [31:0] _807;
    wire [31:0] _76;
    wire _532;
    wire [31:0] out_data;
    wire [15:0] _1458;
    wire [2:0] _382;
    wire _419;
    wire _380;
    wire _379;
    wire _381;
    wire mov_exec;
    wire [15:0] exec_lo16;
    wire [15:0] _1461;
    wire [15:0] latch_instr_next;
    reg [15:0] latch_instr_q;
    wire [15:0] _77;
    wire [15:0] _79;
    wire [15:0] word;
    wire [27:0] _107;
    wire _108;
    wire ok;
    wire _175;
    wire _177;
    wire out_run;
    wire out_exec;
    wire exec_set;
    wire _1467;
    wire _81;
    wire _1468;
    wire _83;
    wire latch_valid_next;
    reg latch_valid_q;
    wire _84;
    wire forced_act;
    wire attempt_latch;
    wire attempt;
    wire _323;
    wire _325;
    wire jmp_taken;
    wire _378;
    wire pc_write_now;
    wire [4:0] pc_next;
    reg [4:0] pc_q;
    assign _88 = _87[25:1];
    assign _319 = 1'b0;
    assign _2 = exec_stalled_q;
    assign _316 = forced_act ? stall : _2;
    assign _317 = _83 ? gnd : _316;
    assign exec_stalled_next = _81 ? gnd : _317;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            exec_stalled_q <= gnd;
        else
            exec_stalled_q <= exec_stalled_next;
    end
    assign _436 = 2'b00;
    assign _434 = 3'b000;
    assign _412 = 4'b0000;
    assign _408 = attempt_imem ? stall_reason_now : _4;
    assign imem_stall_next = imem_clr ? _412 : _408;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            imem_stall_q <= _412;
        else
            imem_stall_q <= imem_stall_next;
    end
    assign _4 = imem_stall_q;
    assign _405 = 4'b0010;
    assign _403 = 4'b0001;
    assign _401 = 4'b0011;
    assign _398 = 4'b0110;
    assign _396 = 4'b0101;
    assign _395 = 4'b0100;
    always @* begin
        case (_186)
        0:
            _399 <= _395;
        1:
            _399 <= _396;
        2:
            _399 <= _398;
        default:
            _399 <= _398;
        endcase
    end
    assign _393 = 4'b0111;
    assign _394 = irq_stall ? _393 : _412;
    assign _400 = wait_stall ? _399 : _394;
    assign _402 = out_hit ? _401 : _400;
    assign _404 = pull_stall ? _403 : _402;
    assign _391 = push_stall | in_stall;
    assign stall_code = _391 ? _405 : _404;
    assign stall_reason_now = stall ? stall_code : _412;
    assign _423 = attempt_latch ? stall_reason_now : _5;
    assign latch_stall_next = clr_latch_scope ? _412 : _423;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_stall_q <= _412;
        else
            latch_stall_q <= latch_stall_next;
    end
    assign _5 = latch_stall_q;
    assign _431 = _5 == _412;
    assign _432 = ~ _431;
    assign stall_reason = _432 ? _5 : _4;
    assign dbg_cnt_0 = { _412,
                         stall_reason,
                         _434,
                         _31,
                         _436,
                         _73,
                         _436,
                         _45 };
    assign _928 = ~ ok;
    assign illegal_0 = attempt & _928;
    assign _930 = push_stall | push_drop;
    assign rxstall_0 = _930 | in_stall;
    assign out_empty_stall = out_hit & _72;
    assign txstall_0 = pull_stall | out_empty_stall;
    assign rx_push_data_0 = in_push ? isr_new_in : _46;
    assign rx_push_0 = push_fire | in_push;
    assign _936 = pull_data | out_refill_stall;
    assign _937 = _936 | out_refill_after;
    assign tx_pop_0 = _937 | tx_pop_refill;
    assign _968 = flag_idx == _434;
    assign _969 = _945 & _968;
    assign _964 = 3'b001;
    assign _965 = flag_idx == _964;
    assign _966 = _945 & _965;
    assign _961 = 3'b010;
    assign _962 = flag_idx == _961;
    assign _963 = _945 & _962;
    assign _958 = 3'b011;
    assign _959 = flag_idx == _958;
    assign _960 = _945 & _959;
    assign _955 = 3'b100;
    assign _956 = flag_idx == _955;
    assign _957 = _945 & _956;
    assign _952 = 3'b101;
    assign _953 = flag_idx == _952;
    assign _954 = _945 & _953;
    assign _949 = 3'b110;
    assign _950 = flag_idx == _949;
    assign _951 = _945 & _950;
    assign _946 = 3'b111;
    assign _947 = flag_idx == _946;
    assign _941 = 2'b10;
    assign _942 = _186 == _941;
    assign wait_done = _185 & wait_cond;
    assign _943 = wait_done & _942;
    assign wait_irq_clr = _943 & _298;
    assign irq_clr_now = _305 & _306;
    assign _945 = irq_clr_now | wait_irq_clr;
    assign _948 = _945 & _947;
    assign irq_clr_out = { _948,
                           _951,
                           _954,
                           _957,
                           _960,
                           _963,
                           _966,
                           _969 };
    assign _995 = flag_idx == _434;
    assign _996 = irq_set_now & _995;
    assign _992 = flag_idx == _964;
    assign _993 = irq_set_now & _992;
    assign _989 = flag_idx == _961;
    assign _990 = irq_set_now & _989;
    assign _986 = flag_idx == _958;
    assign _987 = irq_set_now & _986;
    assign _983 = flag_idx == _955;
    assign _984 = irq_set_now & _983;
    assign _980 = flag_idx == _952;
    assign _981 = irq_set_now & _980;
    assign _977 = flag_idx == _949;
    assign _978 = irq_set_now & _977;
    assign _974 = flag_idx == _946;
    assign _971 = ~ irq_state;
    assign irq_set_now = irq_set_form & _971;
    assign _975 = irq_set_now & _974;
    assign irq_set_out = { _975,
                           _978,
                           _981,
                           _984,
                           _987,
                           _990,
                           _993,
                           _996 };
    assign _1304 = ~ ss_dir_mask;
    assign _1162 = _1161 & _24;
    assign _1163 = { _1162,
                     _1162 };
    assign _1164 = { _1163,
                     _1163 };
    assign _1165 = { _1164,
                     _1164 };
    assign _1166 = { _1165,
                     _1165 };
    assign _1167 = { _1166,
                     _1166 };
    assign _1168 = _1167 & _21;
    assign dir_eff_val = write_any ? dir_new_val : _1168;
    assign _1305 = dir_eff_val & _1304;
    assign ss_dir_val = ss_val & _1139;
    assign dir_val_out = ss_dir_val | _1305;
    assign _1307 = _1161 & _24;
    assign _1308 = { _1307,
                     _1307 };
    assign _1309 = { _1308,
                     _1308 };
    assign _1310 = { _1309,
                     _1309 };
    assign _1311 = { _1310,
                     _1310 };
    assign _1312 = { _1311,
                     _1311 };
    assign _1313 = _1312 & _23;
    assign dir_eff_mask = write_any ? dir_new_mask : _1313;
    assign ss_dir_mask = ss_mask & _1139;
    assign dir_mask_out = ss_dir_mask | dir_eff_mask;
    assign _1346 = ~ ss_lvl_mask;
    assign _1331 = 32'b00000000000000000000000000000000;
    assign _1169 = { dir_write_now,
                     dir_write_now };
    assign _1170 = { _1169,
                     _1169 };
    assign _1171 = { _1170,
                     _1170 };
    assign _1172 = { _1171,
                     _1171 };
    assign _1173 = { _1172,
                     _1172 };
    assign dir_new_val = _1173 & pin_val;
    assign _1202 = _1200[31:16];
    assign _1201 = _1200[15:0];
    assign _1203 = { _1201,
                     _1202 };
    assign _1198 = _1196[31:24];
    assign _1197 = _1196[23:0];
    assign _1199 = { _1197,
                     _1198 };
    assign _1194 = _1192[31:28];
    assign _1193 = _1192[27:0];
    assign _1195 = { _1193,
                     _1194 };
    assign _1190 = _1188[31:30];
    assign _1189 = _1188[29:0];
    assign _1191 = { _1189,
                     _1190 };
    assign _1186 = _1184[31:31];
    assign _1185 = _1184[30:0];
    assign _1187 = { _1185,
                     _1186 };
    assign _1183 = set_write ? _899 : out_data;
    assign _1184 = mov_pins ? mov_data : _1183;
    assign _1182 = _1177[0:0];
    assign _1188 = _1182 ? _1187 : _1184;
    assign _1181 = _1177[1:1];
    assign _1192 = _1181 ? _1191 : _1188;
    assign _1180 = _1177[2:2];
    assign _1196 = _1180 ? _1195 : _1192;
    assign _1179 = _1177[3:3];
    assign _1200 = _1179 ? _1199 : _1196;
    assign _1178 = _1177[4:4];
    assign _1204 = _1178 ? _1203 : _1200;
    assign pin_val = _1204 & pin_mask;
    assign _1322 = { lvl_write_now,
                     lvl_write_now };
    assign _1323 = { _1322,
                     _1322 };
    assign _1324 = { _1323,
                     _1323 };
    assign _1325 = { _1324,
                     _1324 };
    assign _1326 = { _1325,
                     _1325 };
    assign lvl_new_val = _1326 & pin_val;
    assign _1328 = dir_write_now ? dir_new_val : lvl_new_val;
    assign _1329 = write_any ? _1328 : _21;
    assign _1330 = _81 ? _1331 : _1329;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            sticky_val_q <= _1331;
        else
            sticky_val_q <= _1330;
    end
    assign _21 = sticky_val_q;
    assign _1335 = ~ _24;
    assign _1336 = _1161 & _1335;
    assign _1337 = { _1336,
                     _1336 };
    assign _1338 = { _1337,
                     _1337 };
    assign _1339 = { _1338,
                     _1338 };
    assign _1340 = { _1339,
                     _1339 };
    assign _1341 = { _1340,
                     _1340 };
    assign _1342 = _1341 & _21;
    assign lvl_eff_val = write_any ? lvl_new_val : _1342;
    assign _1347 = lvl_eff_val & _1346;
    assign _1333 = ~ _1139;
    assign _1024 = _1022[31:16];
    assign _1023 = _1022[15:0];
    assign _1025 = { _1023,
                     _1024 };
    assign _1020 = _1018[31:24];
    assign _1019 = _1018[23:0];
    assign _1021 = { _1019,
                     _1020 };
    assign _1016 = _1014[31:28];
    assign _1015 = _1014[27:0];
    assign _1017 = { _1015,
                     _1016 };
    assign _1012 = _1010[31:30];
    assign _1011 = _1010[29:0];
    assign _1013 = { _1011,
                     _1012 };
    assign _1008 = _1006[31:31];
    assign _1007 = _1006[30:0];
    assign _1009 = { _1007,
                     _1008 };
    assign _1005 = _107[16:12];
    assign _1004 = 27'b000000000000000000000000000;
    assign _1006 = { _1004,
                     _1005 };
    assign _1003 = _998[0:0];
    assign _1010 = _1003 ? _1009 : _1006;
    assign _1002 = _998[1:1];
    assign _1014 = _1002 ? _1013 : _1010;
    assign _1001 = _998[2:2];
    assign _1018 = _1001 ? _1017 : _1014;
    assign _1000 = _998[3:3];
    assign _1022 = _1000 ? _1021 : _1018;
    assign _999 = _998[4:4];
    assign _1026 = _999 ? _1025 : _1022;
    assign ss_val = _1026 & ss_mask;
    assign ss_lvl_val = ss_val & _1333;
    assign lvl_val_out = ss_lvl_val | _1347;
    assign _1314 = { dir_write_now,
                     dir_write_now };
    assign _1315 = { _1314,
                     _1314 };
    assign _1316 = { _1315,
                     _1315 };
    assign _1317 = { _1316,
                     _1316 };
    assign _1318 = { _1317,
                     _1317 };
    assign dir_new_mask = _1318 & pin_mask;
    assign _1297 = _1295[31:16];
    assign _1296 = _1295[15:0];
    assign _1298 = { _1296,
                     _1297 };
    assign _1293 = _1291[31:24];
    assign _1292 = _1291[23:0];
    assign _1294 = { _1292,
                     _1293 };
    assign _1289 = _1287[31:28];
    assign _1288 = _1287[27:0];
    assign _1290 = { _1288,
                     _1289 };
    assign _1285 = _1283[31:30];
    assign _1284 = _1283[29:0];
    assign _1286 = { _1284,
                     _1285 };
    assign _1281 = _1279[31:31];
    assign _1280 = _1279[30:0];
    assign _1282 = { _1280,
                     _1281 };
    assign _1277 = 6'b000000;
    assign _1278 = _1277 < _1215;
    assign _1275 = 6'b000001;
    assign _1276 = _1275 < _1215;
    assign _1273 = 6'b000010;
    assign _1274 = _1273 < _1215;
    assign _1271 = 6'b000011;
    assign _1272 = _1271 < _1215;
    assign _1269 = 6'b000100;
    assign _1270 = _1269 < _1215;
    assign _1267 = 6'b000101;
    assign _1268 = _1267 < _1215;
    assign _1265 = 6'b000110;
    assign _1266 = _1265 < _1215;
    assign _1263 = 6'b000111;
    assign _1264 = _1263 < _1215;
    assign _1261 = 6'b001000;
    assign _1262 = _1261 < _1215;
    assign _1259 = 6'b001001;
    assign _1260 = _1259 < _1215;
    assign _1257 = 6'b001010;
    assign _1258 = _1257 < _1215;
    assign _1255 = 6'b001011;
    assign _1256 = _1255 < _1215;
    assign _1253 = 6'b001100;
    assign _1254 = _1253 < _1215;
    assign _1251 = 6'b001101;
    assign _1252 = _1251 < _1215;
    assign _1249 = 6'b001110;
    assign _1250 = _1249 < _1215;
    assign _1247 = 6'b001111;
    assign _1248 = _1247 < _1215;
    assign _1245 = 6'b010000;
    assign _1246 = _1245 < _1215;
    assign _1243 = 6'b010001;
    assign _1244 = _1243 < _1215;
    assign _1241 = 6'b010010;
    assign _1242 = _1241 < _1215;
    assign _1239 = 6'b010011;
    assign _1240 = _1239 < _1215;
    assign _1237 = 6'b010100;
    assign _1238 = _1237 < _1215;
    assign _1235 = 6'b010101;
    assign _1236 = _1235 < _1215;
    assign _1233 = 6'b010110;
    assign _1234 = _1233 < _1215;
    assign _1231 = 6'b010111;
    assign _1232 = _1231 < _1215;
    assign _1229 = 6'b011000;
    assign _1230 = _1229 < _1215;
    assign _1227 = 6'b011001;
    assign _1228 = _1227 < _1215;
    assign _1225 = 6'b011010;
    assign _1226 = _1225 < _1215;
    assign _1223 = 6'b011011;
    assign _1224 = _1223 < _1215;
    assign _1221 = 6'b011100;
    assign _1222 = _1221 < _1215;
    assign _1219 = 6'b011101;
    assign _1220 = _1219 < _1215;
    assign _1217 = 6'b011110;
    assign _1218 = _1217 < _1215;
    assign _1213 = _58[28:26];
    assign _1214 = { _434,
                     _1213 };
    assign _1211 = _58[25:20];
    assign _1215 = set_write ? _1214 : _1211;
    assign _1210 = 6'b011111;
    assign _1216 = _1210 < _1215;
    assign _1279 = { _1216,
                     _1218,
                     _1220,
                     _1222,
                     _1224,
                     _1226,
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
                     _1278 };
    assign _1209 = _1177[0:0];
    assign _1283 = _1209 ? _1282 : _1279;
    assign _1208 = _1177[1:1];
    assign _1287 = _1208 ? _1286 : _1283;
    assign _1207 = _1177[2:2];
    assign _1291 = _1207 ? _1290 : _1287;
    assign _1206 = _1177[3:3];
    assign _1295 = _1206 ? _1294 : _1291;
    assign _1176 = _58[9:5];
    assign _1175 = _58[4:0];
    assign set_write = set_pins | set_dirs;
    assign _1177 = set_write ? _1176 : _1175;
    assign _1205 = _1177[4:4];
    assign pin_mask = _1205 ? _1298 : _1295;
    assign _1349 = { lvl_write_now,
                     lvl_write_now };
    assign _1350 = { _1349,
                     _1349 };
    assign _1351 = { _1350,
                     _1350 };
    assign _1352 = { _1351,
                     _1351 };
    assign _1353 = { _1352,
                     _1352 };
    assign lvl_new_mask = _1353 & pin_mask;
    assign _1355 = dir_write_now ? dir_new_mask : lvl_new_mask;
    assign _1356 = write_any ? _1355 : _23;
    assign _1357 = _81 ? _1331 : _1356;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            sticky_mask_q <= _1331;
        else
            sticky_mask_q <= _1357;
    end
    assign _23 = sticky_mask_q;
    assign _1360 = write_any ? dir_write_now : _24;
    assign _1361 = _81 ? gnd : _1360;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            sticky_isdir_q <= gnd;
        else
            sticky_isdir_q <= _1361;
    end
    assign _24 = sticky_isdir_q;
    assign _1372 = ~ _24;
    assign _1160 = _52[17:17];
    assign _1161 = _1160 & _70;
    assign _1373 = _1161 & _1372;
    assign _1374 = { _1373,
                     _1373 };
    assign _1375 = { _1374,
                     _1374 };
    assign _1376 = { _1375,
                     _1375 };
    assign _1377 = { _1376,
                     _1376 };
    assign _1378 = { _1377,
                     _1377 };
    assign _1379 = _1378 & _23;
    assign _1156 = _893 == _955;
    assign set_dirs = _892 & _1156;
    assign _1153 = _374 == _955;
    assign out_dirs = out_run & _1153;
    assign dir_write_now = out_dirs | set_dirs;
    assign _1149 = _893 == _434;
    assign set_pins = _892 & _1149;
    assign _1145 = _382 == _434;
    assign mov_pins = _381 & _1145;
    assign _1142 = _374 == _434;
    assign out_pins = out_run & _1142;
    assign _1147 = out_pins | mov_pins;
    assign lvl_write_now = _1147 | set_pins;
    assign write_any = lvl_write_now | dir_write_now;
    assign lvl_eff_mask = write_any ? lvl_new_mask : _1379;
    assign _1134 = _52[29:29];
    assign _1135 = { _1134,
                     _1134 };
    assign _1136 = { _1135,
                     _1135 };
    assign _1137 = { _1136,
                     _1136 };
    assign _1138 = { _1137,
                     _1137 };
    assign _1139 = { _1138,
                     _1138 };
    assign _1344 = ~ _1139;
    assign _1125 = _107[11:11];
    assign _1364 = attempt_latch ? stall : _25;
    assign latch_ss_next = clr_latch_scope ? gnd : _1364;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_ss_q <= gnd;
        else
            latch_ss_q <= latch_ss_next;
    end
    assign _25 = latch_ss_q;
    assign _1368 = attempt_imem ? stall : _26;
    assign imem_ss_next = imem_clr ? gnd : _1368;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            imem_ss_q <= gnd;
        else
            imem_ss_q <= imem_ss_next;
    end
    assign _26 = imem_ss_q;
    assign ss_flag = _84 ? _25 : _26;
    assign _1123 = ~ ss_flag;
    assign _1124 = attempt & _1123;
    assign ss_apply = _1124 & _1125;
    assign _1127 = { ss_apply,
                     ss_apply };
    assign _1128 = { _1127,
                     _1127 };
    assign _1129 = { _1128,
                     _1128 };
    assign _1130 = { _1129,
                     _1129 };
    assign _1131 = { _1130,
                     _1130 };
    assign _1119 = _1117[31:16];
    assign _1118 = _1117[15:0];
    assign _1120 = { _1118,
                     _1119 };
    assign _1115 = _1113[31:24];
    assign _1114 = _1113[23:0];
    assign _1116 = { _1114,
                     _1115 };
    assign _1111 = _1109[31:28];
    assign _1110 = _1109[27:0];
    assign _1112 = { _1110,
                     _1111 };
    assign _1107 = _1105[31:30];
    assign _1106 = _1105[29:0];
    assign _1108 = { _1106,
                     _1107 };
    assign _1103 = _1101[31:31];
    assign _1102 = _1101[30:0];
    assign _1104 = { _1102,
                     _1103 };
    assign _1100 = _1277 < ss_nbits;
    assign _1098 = _1275 < ss_nbits;
    assign _1096 = _1273 < ss_nbits;
    assign _1094 = _1271 < ss_nbits;
    assign _1092 = _1269 < ss_nbits;
    assign _1090 = _1267 < ss_nbits;
    assign _1088 = _1265 < ss_nbits;
    assign _1086 = _1263 < ss_nbits;
    assign _1084 = _1261 < ss_nbits;
    assign _1082 = _1259 < ss_nbits;
    assign _1080 = _1257 < ss_nbits;
    assign _1078 = _1255 < ss_nbits;
    assign _1076 = _1253 < ss_nbits;
    assign _1074 = _1251 < ss_nbits;
    assign _1072 = _1249 < ss_nbits;
    assign _1070 = _1247 < ss_nbits;
    assign _1068 = _1245 < ss_nbits;
    assign _1066 = _1243 < ss_nbits;
    assign _1064 = _1241 < ss_nbits;
    assign _1062 = _1239 < ss_nbits;
    assign _1060 = _1237 < ss_nbits;
    assign _1058 = _1235 < ss_nbits;
    assign _1056 = _1233 < ss_nbits;
    assign _1054 = _1231 < ss_nbits;
    assign _1052 = _1229 < ss_nbits;
    assign _1050 = _1227 < ss_nbits;
    assign _1048 = _1225 < ss_nbits;
    assign _1046 = _1223 < ss_nbits;
    assign _1044 = _1221 < ss_nbits;
    assign _1042 = _1219 < ss_nbits;
    assign _1040 = _1217 < ss_nbits;
    assign _1035 = 5'b00000;
    assign _1036 = { _1035,
                     _105 };
    assign _1034 = { _434,
                     _104 };
    assign ss_nbits = _1034 - _1036;
    assign _1038 = _1210 < ss_nbits;
    assign _1101 = { _1038,
                     _1040,
                     _1042,
                     _1044,
                     _1046,
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
                     _1100 };
    assign _1031 = _998[0:0];
    assign _1105 = _1031 ? _1104 : _1101;
    assign _1030 = _998[1:1];
    assign _1109 = _1030 ? _1108 : _1105;
    assign _1029 = _998[2:2];
    assign _1113 = _1029 ? _1112 : _1109;
    assign _1028 = _998[3:3];
    assign _1117 = _1028 ? _1116 : _1113;
    assign _998 = _58[14:10];
    assign _1027 = _998[4:4];
    assign _1121 = _1027 ? _1120 : _1117;
    assign ss_mask = _1121 & _1131;
    assign ss_lvl_mask = ss_mask & _1344;
    assign lvl_mask_out = ss_lvl_mask | lvl_eff_mask;
    assign _1394 = word[4:0];
    assign _1392 = out_data[4:0];
    assign _1391 = mov_data[4:0];
    assign _1393 = out_pc ? _1392 : _1391;
    assign pc_target = jmp_taken ? _1394 : _1393;
    assign _1388 = _52[11:7];
    assign _1386 = 5'b00001;
    assign _1387 = _28 + _1386;
    assign _1384 = _52[16:12];
    assign _1385 = _28 == _1384;
    assign pc_adv = _1385 ? _1388 : _1387;
    assign _28 = pc_q;
    assign _1382 = ~ stall;
    assign imem_done = attempt_imem & _1382;
    assign _1390 = imem_done ? pc_adv : _28;
    assign _384 = _382 == _952;
    assign mov_pc = _381 & _384;
    assign _376 = _374 == _952;
    assign out_pc = out_run & _376;
    assign _369 = _73 < _144;
    assign _367 = _56[31:31];
    assign _366 = _56[30:30];
    assign _365 = _56[29:29];
    assign _364 = _56[28:28];
    assign _363 = _56[27:27];
    assign _362 = _56[26:26];
    assign _361 = _56[25:25];
    assign _360 = _56[24:24];
    assign _359 = _56[23:23];
    assign _358 = _56[22:22];
    assign _357 = _56[21:21];
    assign _356 = _56[20:20];
    assign _355 = _56[19:19];
    assign _354 = _56[18:18];
    assign _353 = _56[17:17];
    assign _352 = _56[16:16];
    assign _351 = _56[15:15];
    assign _350 = _56[14:14];
    assign _349 = _56[13:13];
    assign _348 = _56[12:12];
    assign _347 = _56[11:11];
    assign _346 = _56[10:10];
    assign _345 = _56[9:9];
    assign _344 = _56[8:8];
    assign _343 = _56[7:7];
    assign _342 = _56[6:6];
    assign _341 = _56[5:5];
    assign _340 = _56[4:4];
    assign _339 = _56[3:3];
    assign _338 = _56[2:2];
    assign _337 = _56[1:1];
    assign _336 = _56[0:0];
    assign _335 = _52[28:24];
    always @* begin
        case (_335)
        0:
            _368 <= _336;
        1:
            _368 <= _337;
        2:
            _368 <= _338;
        3:
            _368 <= _339;
        4:
            _368 <= _340;
        5:
            _368 <= _341;
        6:
            _368 <= _342;
        7:
            _368 <= _343;
        8:
            _368 <= _344;
        9:
            _368 <= _345;
        10:
            _368 <= _346;
        11:
            _368 <= _347;
        12:
            _368 <= _348;
        13:
            _368 <= _349;
        14:
            _368 <= _350;
        15:
            _368 <= _351;
        16:
            _368 <= _352;
        17:
            _368 <= _353;
        18:
            _368 <= _354;
        19:
            _368 <= _355;
        20:
            _368 <= _356;
        21:
            _368 <= _357;
        22:
            _368 <= _358;
        23:
            _368 <= _359;
        24:
            _368 <= _360;
        25:
            _368 <= _361;
        26:
            _368 <= _362;
        27:
            _368 <= _363;
        28:
            _368 <= _364;
        29:
            _368 <= _365;
        30:
            _368 <= _366;
        default:
            _368 <= _367;
        endcase
    end
    assign _333 = _54 == _53;
    assign _334 = ~ _333;
    assign _332 = ~ _331;
    assign _331 = _53 == _1331;
    assign _329 = ~ _328;
    assign _328 = _54 == _1331;
    always @* begin
        case (_326)
        0:
            jmp_cond_val <= vdd;
        1:
            jmp_cond_val <= _328;
        2:
            jmp_cond_val <= _329;
        3:
            jmp_cond_val <= _331;
        4:
            jmp_cond_val <= _332;
        5:
            jmp_cond_val <= _334;
        6:
            jmp_cond_val <= _368;
        default:
            jmp_cond_val <= _369;
        endcase
    end
    assign _324 = _107[1:1];
    assign _90 = ~ _29;
    assign _91 = _84 & _90;
    assign _94 = _91 & tick_en;
    assign _97 = _94 & delay_zero;
    assign _1400 = exec_set ? gnd : _29;
    assign latch_forced_next = _83 ? vdd : _1400;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_forced_q <= gnd;
        else
            latch_forced_q <= latch_forced_next;
    end
    assign _29 = latch_forced_q;
    assign _1404 = attempt_latch ? irq_stall : _30;
    assign _414 = _81 | _83;
    assign clr_latch_scope = _414 | exec_set;
    assign latch_irqw_next = clr_latch_scope ? gnd : _1404;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_irqw_q <= gnd;
        else
            latch_irqw_q <= latch_irqw_next;
    end
    assign _30 = latch_irqw_q;
    assign _1422 = _31 - _1386;
    assign _1417 = _107[21:17];
    assign exec_form = out_exec | mov_exec;
    assign _1419 = exec_form ? _1035 : _1417;
    assign _1414 = ~ forced_act;
    assign _1412 = ~ stall;
    assign complete = attempt & _1412;
    assign _1415 = complete & _1414;
    assign _1420 = _1415 ? _1419 : _31;
    assign _1410 = ~ delay_zero;
    assign _1408 = ~ forced_act;
    assign _1409 = tick_en & _1408;
    assign dec_now = _1409 & _1410;
    assign delay_next = dec_now ? _1422 : _1420;
    assign _1425 = _81 ? _1035 : delay_next;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            delay_q <= _1035;
        else
            delay_q <= _1425;
    end
    assign _31 = delay_q;
    assign delay_zero = _31 == _1035;
    assign _99 = ~ _84;
    assign _100 = _99 & tick_en;
    assign attempt_imem = _100 & delay_zero;
    assign _1429 = attempt_imem ? irq_stall : _34;
    assign _33 = imem_abandon;
    assign pc_write_latch = latch_done & pc_write_now;
    assign _388 = _81 | pc_write_latch;
    assign imem_clr = _388 | _33;
    assign imem_irqw_next = imem_clr ? gnd : _1429;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            imem_irqw_q <= gnd;
        else
            imem_irqw_q <= imem_irqw_next;
    end
    assign _34 = imem_irqw_q;
    assign irq_state = _84 ? _30 : _34;
    assign _312 = ~ irq_state;
    assign _313 = _312 | flag_val;
    assign _309 = word[5:5];
    assign _306 = word[6:6];
    assign _307 = ~ _306;
    assign _304 = _107[8:8];
    assign _303 = attempt & ok;
    assign _305 = _303 & _304;
    assign irq_set_form = _305 & _307;
    assign irqw_form = irq_set_form & _309;
    assign irq_stall = irqw_form & _313;
    assign _298 = word[7:7];
    assign _294 = _36[7:7];
    assign _293 = _36[6:6];
    assign _292 = _36[5:5];
    assign _291 = _36[4:4];
    assign _290 = _36[3:3];
    assign _289 = _36[2:2];
    assign _288 = _36[1:1];
    assign _36 = irq_q;
    assign _287 = _36[0:0];
    assign _38 = sm_num;
    assign _283 = _281[1:0];
    assign _284 = _283 + _38;
    assign _282 = _281[2:2];
    assign _285 = { _282,
                    _284 };
    assign _281 = word[2:0];
    assign _280 = word[4:4];
    assign flag_idx = _280 ? _285 : _281;
    always @* begin
        case (flag_idx)
        0:
            flag_val <= _287;
        1:
            flag_val <= _288;
        2:
            flag_val <= _289;
        3:
            flag_val <= _290;
        4:
            flag_val <= _291;
        5:
            flag_val <= _292;
        6:
            flag_val <= _293;
        default:
            flag_val <= _294;
        endcase
    end
    assign _278 = _246[31:31];
    assign _277 = _246[30:30];
    assign _276 = _246[29:29];
    assign _275 = _246[28:28];
    assign _274 = _246[27:27];
    assign _273 = _246[26:26];
    assign _272 = _246[25:25];
    assign _271 = _246[24:24];
    assign _270 = _246[23:23];
    assign _269 = _246[22:22];
    assign _268 = _246[21:21];
    assign _267 = _246[20:20];
    assign _266 = _246[19:19];
    assign _265 = _246[18:18];
    assign _264 = _246[17:17];
    assign _263 = _246[16:16];
    assign _262 = _246[15:15];
    assign _261 = _246[14:14];
    assign _260 = _246[13:13];
    assign _259 = _246[12:12];
    assign _258 = _246[11:11];
    assign _257 = _246[10:10];
    assign _256 = _246[9:9];
    assign _255 = _246[8:8];
    assign _254 = _246[7:7];
    assign _253 = _246[6:6];
    assign _252 = _246[5:5];
    assign _251 = _246[4:4];
    assign _250 = _246[3:3];
    assign _249 = _246[2:2];
    assign _248 = _246[1:1];
    assign _247 = _246[0:0];
    always @* begin
        case (_187)
        0:
            _279 <= _247;
        1:
            _279 <= _248;
        2:
            _279 <= _249;
        3:
            _279 <= _250;
        4:
            _279 <= _251;
        5:
            _279 <= _252;
        6:
            _279 <= _253;
        7:
            _279 <= _254;
        8:
            _279 <= _255;
        9:
            _279 <= _256;
        10:
            _279 <= _257;
        11:
            _279 <= _258;
        12:
            _279 <= _259;
        13:
            _279 <= _260;
        14:
            _279 <= _261;
        15:
            _279 <= _262;
        16:
            _279 <= _263;
        17:
            _279 <= _264;
        18:
            _279 <= _265;
        19:
            _279 <= _266;
        20:
            _279 <= _267;
        21:
            _279 <= _268;
        22:
            _279 <= _269;
        23:
            _279 <= _270;
        24:
            _279 <= _271;
        25:
            _279 <= _272;
        26:
            _279 <= _273;
        27:
            _279 <= _274;
        28:
            _279 <= _275;
        29:
            _279 <= _276;
        30:
            _279 <= _277;
        default:
            _279 <= _278;
        endcase
    end
    assign _219 = _56[31:31];
    assign _218 = _56[30:30];
    assign _217 = _56[29:29];
    assign _216 = _56[28:28];
    assign _215 = _56[27:27];
    assign _214 = _56[26:26];
    assign _213 = _56[25:25];
    assign _212 = _56[24:24];
    assign _211 = _56[23:23];
    assign _210 = _56[22:22];
    assign _209 = _56[21:21];
    assign _208 = _56[20:20];
    assign _207 = _56[19:19];
    assign _206 = _56[18:18];
    assign _205 = _56[17:17];
    assign _204 = _56[16:16];
    assign _203 = _56[15:15];
    assign _202 = _56[14:14];
    assign _201 = _56[13:13];
    assign _200 = _56[12:12];
    assign _199 = _56[11:11];
    assign _198 = _56[10:10];
    assign _197 = _56[9:9];
    assign _196 = _56[8:8];
    assign _195 = _56[7:7];
    assign _194 = _56[6:6];
    assign _193 = _56[5:5];
    assign _192 = _56[4:4];
    assign _191 = _56[3:3];
    assign _190 = _56[2:2];
    assign _189 = _56[1:1];
    assign _188 = _56[0:0];
    assign _187 = word[4:0];
    always @* begin
        case (_187)
        0:
            _220 <= _188;
        1:
            _220 <= _189;
        2:
            _220 <= _190;
        3:
            _220 <= _191;
        4:
            _220 <= _192;
        5:
            _220 <= _193;
        6:
            _220 <= _194;
        7:
            _220 <= _195;
        8:
            _220 <= _196;
        9:
            _220 <= _197;
        10:
            _220 <= _198;
        11:
            _220 <= _199;
        12:
            _220 <= _200;
        13:
            _220 <= _201;
        14:
            _220 <= _202;
        15:
            _220 <= _203;
        16:
            _220 <= _204;
        17:
            _220 <= _205;
        18:
            _220 <= _206;
        19:
            _220 <= _207;
        20:
            _220 <= _208;
        21:
            _220 <= _209;
        22:
            _220 <= _210;
        23:
            _220 <= _211;
        24:
            _220 <= _212;
        25:
            _220 <= _213;
        26:
            _220 <= _214;
        27:
            _220 <= _215;
        28:
            _220 <= _216;
        29:
            _220 <= _217;
        30:
            _220 <= _218;
        default:
            _220 <= _219;
        endcase
    end
    assign _186 = word[6:5];
    always @* begin
        case (_186)
        0:
            wait_bit <= _220;
        1:
            wait_bit <= _279;
        2:
            wait_bit <= flag_val;
        default:
            wait_bit <= vdd;
        endcase
    end
    assign wait_cond = wait_bit == _298;
    assign _300 = ~ wait_cond;
    assign _184 = _107[2:2];
    assign _183 = attempt & ok;
    assign _185 = _183 & _184;
    assign wait_stall = _185 & _300;
    assign _172 = _157 & in_thr_hit;
    assign in_stall = _172 & _44;
    assign _151 = pull_try & _72;
    assign pull_stall = _151 & _152;
    assign _129 = push_try & _128;
    assign push_stall = _129 & _44;
    assign _154 = push_stall | pull_stall;
    assign _174 = _154 | in_stall;
    assign _182 = _174 | out_hit;
    assign _302 = _182 | wait_stall;
    assign stall = _302 | irq_stall;
    assign _321 = ~ stall;
    assign latch_done = attempt_latch & _321;
    assign _1466 = latch_done ? gnd : _84;
    assign _416 = _374 == _946;
    assign _372 = ~ autopull_hit;
    assign _176 = _107[4:4];
    assign _109 = _107[10:10];
    assign _110 = ~ _109;
    assign _105 = _52[30:30];
    assign _104 = _58[31:29];
    assign _1464 = 16'b0000000000000000;
    assign _40 = instr_data;
    assign _1459 = mov_data[15:0];
    assign _871 = _1277 < _160;
    assign _869 = _1275 < _160;
    assign _867 = _1273 < _160;
    assign _865 = _1271 < _160;
    assign _863 = _1269 < _160;
    assign _861 = _1267 < _160;
    assign _859 = _1265 < _160;
    assign _857 = _1263 < _160;
    assign _855 = _1261 < _160;
    assign _853 = _1259 < _160;
    assign _851 = _1257 < _160;
    assign _849 = _1255 < _160;
    assign _847 = _1253 < _160;
    assign _845 = _1251 < _160;
    assign _843 = _1249 < _160;
    assign _841 = _1247 < _160;
    assign _839 = _1245 < _160;
    assign _837 = _1243 < _160;
    assign _835 = _1241 < _160;
    assign _833 = _1239 < _160;
    assign _831 = _1237 < _160;
    assign _829 = _1235 < _160;
    assign _827 = _1233 < _160;
    assign _825 = _1231 < _160;
    assign _823 = _1229 < _160;
    assign _821 = _1227 < _160;
    assign _819 = _1225 < _160;
    assign _817 = _1223 < _160;
    assign _815 = _1221 < _160;
    assign _813 = _1219 < _160;
    assign _811 = _1217 < _160;
    assign _809 = _1210 < _160;
    assign _872 = { _809,
                    _811,
                    _813,
                    _815,
                    _817,
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
                    _871 };
    assign _873 = _74 & _872;
    assign _804 = _802[31:16];
    assign _805 = { _1464,
                    _804 };
    assign _800 = _798[31:8];
    assign _799 = 8'b00000000;
    assign _801 = { _799,
                    _800 };
    assign _796 = _794[31:4];
    assign _797 = { _412,
                    _796 };
    assign _792 = _790[31:2];
    assign _793 = { _436,
                    _792 };
    assign _788 = _74[31:1];
    assign _789 = { _319,
                    _788 };
    assign _42 = tx_head;
    assign _587 = _585[31:16];
    assign _588 = { _1464,
                    _587 };
    assign _583 = _581[31:8];
    assign _584 = { _799,
                    _583 };
    assign _579 = _577[31:4];
    assign _580 = { _412,
                    _579 };
    assign _575 = _573[31:2];
    assign _576 = { _436,
                    _575 };
    assign _571 = _74[31:1];
    assign _572 = { _319,
                    _571 };
    assign _569 = _564[0:0];
    assign _573 = _569 ? _572 : _74;
    assign _568 = _564[1:1];
    assign _577 = _568 ? _576 : _573;
    assign _567 = _564[2:2];
    assign _581 = _567 ? _580 : _577;
    assign _566 = _564[3:3];
    assign _585 = _566 ? _584 : _581;
    assign _564 = _160[4:0];
    assign _565 = _564[4:4];
    assign _589 = _565 ? _588 : _585;
    assign _562 = 6'b100000;
    assign _563 = _160 == _562;
    assign _590 = _563 ? _1331 : _589;
    assign _557 = _556[15:0];
    assign _559 = { _557,
                    _1464 };
    assign _553 = _552[23:0];
    assign _555 = { _553,
                    _799 };
    assign _549 = _548[27:0];
    assign _551 = { _549,
                    _412 };
    assign _545 = _544[29:0];
    assign _547 = { _545,
                    _436 };
    assign _541 = _74[30:0];
    assign _543 = { _541,
                    _319 };
    assign _540 = _535[0:0];
    assign _544 = _540 ? _543 : _74;
    assign _539 = _535[1:1];
    assign _548 = _539 ? _547 : _544;
    assign _538 = _535[2:2];
    assign _552 = _538 ? _551 : _548;
    assign _537 = _535[3:3];
    assign _556 = _537 ? _555 : _552;
    assign _535 = _160[4:0];
    assign _536 = _535[4:4];
    assign _560 = _536 ? _559 : _556;
    assign _534 = _160 == _562;
    assign _561 = _534 ? _1331 : _560;
    assign osr_shifted = _532 ? _590 : _561;
    assign _527 = mov_src_val[31:31];
    assign _526 = mov_src_val[30:30];
    assign _525 = mov_src_val[29:29];
    assign _524 = mov_src_val[28:28];
    assign _523 = mov_src_val[27:27];
    assign _522 = mov_src_val[26:26];
    assign _521 = mov_src_val[25:25];
    assign _520 = mov_src_val[24:24];
    assign _519 = mov_src_val[23:23];
    assign _518 = mov_src_val[22:22];
    assign _517 = mov_src_val[21:21];
    assign _516 = mov_src_val[20:20];
    assign _515 = mov_src_val[19:19];
    assign _514 = mov_src_val[18:18];
    assign _513 = mov_src_val[17:17];
    assign _512 = mov_src_val[16:16];
    assign _511 = mov_src_val[15:15];
    assign _510 = mov_src_val[14:14];
    assign _509 = mov_src_val[13:13];
    assign _508 = mov_src_val[12:12];
    assign _507 = mov_src_val[11:11];
    assign _506 = mov_src_val[10:10];
    assign _505 = mov_src_val[9:9];
    assign _504 = mov_src_val[8:8];
    assign _503 = mov_src_val[7:7];
    assign _502 = mov_src_val[6:6];
    assign _501 = mov_src_val[5:5];
    assign _500 = mov_src_val[4:4];
    assign _499 = mov_src_val[3:3];
    assign _498 = mov_src_val[2:2];
    assign _497 = mov_src_val[1:1];
    assign _496 = mov_src_val[0:0];
    assign _528 = { _496,
                    _497,
                    _498,
                    _499,
                    _500,
                    _501,
                    _502,
                    _503,
                    _504,
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
                    _527 };
    assign _495 = ~ mov_src_val;
    assign _768 = _767[15:0];
    assign _770 = { _768,
                    _1464 };
    assign _764 = _763[23:0];
    assign _766 = { _764,
                    _799 };
    assign _760 = _759[27:0];
    assign _762 = { _760,
                    _412 };
    assign _756 = _755[29:0];
    assign _758 = { _756,
                    _436 };
    assign _752 = in_data[30:0];
    assign _754 = { _752,
                    _319 };
    assign _751 = _746[0:0];
    assign _755 = _751 ? _754 : in_data;
    assign _750 = _746[1:1];
    assign _759 = _750 ? _758 : _755;
    assign _749 = _746[2:2];
    assign _763 = _749 ? _762 : _759;
    assign _748 = _746[3:3];
    assign _767 = _748 ? _766 : _763;
    assign _746 = _743[4:0];
    assign _747 = _746[4:4];
    assign _771 = _747 ? _770 : _767;
    assign _743 = _562 - _160;
    assign _745 = _743 == _562;
    assign _772 = _745 ? _1331 : _771;
    assign _738 = _736[31:16];
    assign _739 = { _1464,
                    _738 };
    assign _734 = _732[31:8];
    assign _735 = { _799,
                    _734 };
    assign _730 = _728[31:4];
    assign _731 = { _412,
                    _730 };
    assign _726 = _724[31:2];
    assign _727 = { _436,
                    _726 };
    assign _722 = _46[31:1];
    assign _723 = { _319,
                    _722 };
    assign _720 = _715[0:0];
    assign _724 = _720 ? _723 : _46;
    assign _719 = _715[1:1];
    assign _728 = _719 ? _727 : _724;
    assign _718 = _715[2:2];
    assign _732 = _718 ? _731 : _728;
    assign _717 = _715[3:3];
    assign _736 = _717 ? _735 : _732;
    assign _715 = _160[4:0];
    assign _716 = _715[4:4];
    assign _740 = _716 ? _739 : _736;
    assign _714 = _160 == _562;
    assign _741 = _714 ? _1331 : _740;
    assign _773 = _741 | _772;
    assign _709 = _1277 < _160;
    assign _707 = _1275 < _160;
    assign _705 = _1273 < _160;
    assign _703 = _1271 < _160;
    assign _701 = _1269 < _160;
    assign _699 = _1267 < _160;
    assign _697 = _1265 < _160;
    assign _695 = _1263 < _160;
    assign _693 = _1261 < _160;
    assign _691 = _1259 < _160;
    assign _689 = _1257 < _160;
    assign _687 = _1255 < _160;
    assign _685 = _1253 < _160;
    assign _683 = _1251 < _160;
    assign _681 = _1249 < _160;
    assign _679 = _1247 < _160;
    assign _677 = _1245 < _160;
    assign _675 = _1243 < _160;
    assign _673 = _1241 < _160;
    assign _671 = _1239 < _160;
    assign _669 = _1237 < _160;
    assign _667 = _1235 < _160;
    assign _665 = _1233 < _160;
    assign _663 = _1231 < _160;
    assign _661 = _1229 < _160;
    assign _659 = _1227 < _160;
    assign _657 = _1225 < _160;
    assign _655 = _1223 < _160;
    assign _653 = _1221 < _160;
    assign _651 = _1219 < _160;
    assign _649 = _1217 < _160;
    assign _647 = _1210 < _160;
    assign _710 = { _647,
                    _649,
                    _651,
                    _653,
                    _655,
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
                    _709 };
    assign _644 = word[7:5];
    always @* begin
        case (_644)
        0:
            _645 <= _246;
        1:
            _645 <= _54;
        2:
            _645 <= _53;
        3:
            _645 <= _1331;
        4:
            _645 <= _1331;
        5:
            _645 <= _1331;
        6:
            _645 <= _46;
        default:
            _645 <= _74;
        endcase
    end
    assign in_data = _645 & _710;
    assign _639 = _638[15:0];
    assign _641 = { _639,
                    _1464 };
    assign _635 = _634[23:0];
    assign _637 = { _635,
                    _799 };
    assign _631 = _630[27:0];
    assign _633 = { _631,
                    _412 };
    assign _627 = _626[29:0];
    assign _629 = { _627,
                    _436 };
    assign _623 = _46[30:0];
    assign _625 = { _623,
                    _319 };
    assign _622 = _617[0:0];
    assign _626 = _622 ? _625 : _46;
    assign _621 = _617[1:1];
    assign _630 = _621 ? _629 : _626;
    assign _620 = _617[2:2];
    assign _634 = _620 ? _633 : _630;
    assign _619 = _617[3:3];
    assign _638 = _619 ? _637 : _634;
    assign _617 = _160[4:0];
    assign _618 = _617[4:4];
    assign _642 = _618 ? _641 : _638;
    assign _616 = _160 == _562;
    assign _643 = _616 ? _1331 : _642;
    assign _712 = _643 | in_data;
    assign _614 = _76[18:18];
    assign isr_new_in = _614 ? _773 : _712;
    assign _775 = in_shift ? isr_new_in : _46;
    assign _603 = ~ _44;
    assign _166 = _162[5:0];
    assign _163 = 7'b0100000;
    assign _161 = { gnd,
                    _160 };
    assign _612 = ~ in_thr_hit;
    assign in_shift = _157 & _612;
    assign _1434 = in_shift ? isr_cnt_new : _45;
    assign _608 = ~ _44;
    assign push_fire = push_try & _608;
    assign _44 = rx_full;
    assign _128 = word[5:5];
    assign _605 = ~ _128;
    assign _121 = { gnd,
                    _117 };
    assign _117 = _76[24:20];
    assign _119 = _117 == _1035;
    assign _123 = _119 ? _562 : _121;
    assign _124 = _45 < _123;
    assign _115 = word[6:6];
    assign _116 = _114 & _115;
    assign push_noop = _116 & _124;
    assign _126 = ~ push_noop;
    assign _113 = _107[5:5];
    assign _112 = attempt & ok;
    assign _114 = _112 & _113;
    assign push_try = _114 & _126;
    assign _606 = push_try & _605;
    assign push_drop = _606 & _44;
    assign push_clr = push_drop | push_fire;
    assign _1433 = in_push | push_clr;
    assign _1436 = _1433 ? _1277 : _1434;
    assign _1437 = out_isr ? _160 : _1436;
    assign isr_cnt_next = mov_isr ? _1277 : _1437;
    assign _1441 = _81 ? _1277 : isr_cnt_next;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            isr_cnt_q <= _1277;
        else
            isr_cnt_q <= _1441;
    end
    assign _45 = isr_cnt_q;
    assign _159 = { gnd,
                    _45 };
    assign _162 = _159 + _161;
    assign _164 = _162 < _163;
    assign _165 = ~ _164;
    assign isr_cnt_new = _165 ? _562 : _166;
    assign _169 = isr_cnt_new < _123;
    assign _170 = ~ _169;
    assign _158 = _76[16:16];
    assign in_thr_hit = _158 & _170;
    assign _156 = _107[3:3];
    assign _155 = attempt & ok;
    assign _157 = _155 & _156;
    assign _602 = _157 & in_thr_hit;
    assign in_push = _602 & _603;
    assign _611 = in_push | push_clr;
    assign _776 = _611 ? _1331 : _775;
    assign _600 = _374 == _949;
    assign out_isr = out_run & _600;
    assign _875 = out_isr ? out_data : _776;
    assign _597 = _382 == _949;
    assign mov_isr = _381 & _597;
    assign isr_next = mov_isr ? mov_data : _875;
    assign _878 = _81 ? _1331 : isr_next;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            isr_q <= _1331;
        else
            isr_q <= _878;
    end
    assign _46 = isr_q;
    assign _48 = rx_level;
    assign _487 = _48 < _485;
    assign _485 = _52[3:0];
    assign _50 = tx_level;
    assign _486 = _50 < _485;
    assign _52 = execctrl;
    assign _484 = _52[4:4];
    assign status_bit = _484 ? _487 : _486;
    assign _489 = { status_bit,
                    status_bit };
    assign _490 = { _489,
                    _489 };
    assign _491 = { _490,
                    _490 };
    assign _492 = { _491,
                    _491 };
    assign _493 = { _492,
                    _492 };
    assign _903 = 32'b00000000000000000000000000000001;
    assign _904 = _53 - _903;
    assign _895 = _893 == _961;
    assign set_y = _892 & _895;
    assign _900 = set_y ? _899 : _53;
    assign _888 = _374 == _961;
    assign out_y = out_run & _888;
    assign _901 = out_y ? out_data : _900;
    assign _885 = _382 == _961;
    assign mov_y = _381 & _885;
    assign _902 = mov_y ? mov_data : _901;
    assign _882 = _326 == _955;
    assign y_dec = _325 & _882;
    assign y_next = y_dec ? _904 : _902;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            y_q <= _1331;
        else
            y_q <= y_next;
    end
    assign _53 = y_q;
    assign _924 = _54 - _903;
    assign _898 = word[4:0];
    assign _899 = { _1004,
                    _898 };
    assign _893 = word[7:5];
    assign _918 = _893 == _964;
    assign _891 = _107[9:9];
    assign _890 = attempt & ok;
    assign _892 = _890 & _891;
    assign set_x = _892 & _918;
    assign _920 = set_x ? _899 : _54;
    assign _374 = word[7:5];
    assign _915 = _374 == _964;
    assign out_x = out_run & _915;
    assign _921 = out_x ? out_data : _920;
    assign _912 = _382 == _964;
    assign mov_x = _381 & _912;
    assign _922 = mov_x ? mov_data : _921;
    assign _326 = word[7:5];
    assign _909 = _326 == _961;
    assign x_dec = _325 & _909;
    assign x_next = x_dec ? _924 : _922;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            x_q <= _1331;
        else
            x_q <= x_next;
    end
    assign _54 = x_q;
    assign _244 = _242[31:16];
    assign _243 = _242[15:0];
    assign _245 = { _243,
                    _244 };
    assign _240 = _238[31:8];
    assign _239 = _238[7:0];
    assign _241 = { _239,
                    _240 };
    assign _236 = _234[31:4];
    assign _235 = _234[3:0];
    assign _237 = { _235,
                    _236 };
    assign _232 = _230[31:2];
    assign _231 = _230[1:0];
    assign _233 = { _231,
                    _232 };
    assign _228 = _56[31:1];
    assign _227 = _56[0:0];
    assign _229 = { _227,
                    _228 };
    assign _56 = in_sel;
    assign _226 = _221[0:0];
    assign _230 = _226 ? _229 : _56;
    assign _225 = _221[1:1];
    assign _234 = _225 ? _233 : _230;
    assign _224 = _221[2:2];
    assign _238 = _224 ? _237 : _234;
    assign _223 = _221[3:3];
    assign _242 = _223 ? _241 : _238;
    assign _58 = pinctrl;
    assign _221 = _58[19:15];
    assign _222 = _221[4:4];
    assign _246 = _222 ? _245 : _242;
    assign _482 = word[2:0];
    always @* begin
        case (_482)
        0:
            mov_src_val <= _246;
        1:
            mov_src_val <= _54;
        2:
            mov_src_val <= _53;
        3:
            mov_src_val <= _1331;
        4:
            mov_src_val <= _1331;
        5:
            mov_src_val <= _493;
        6:
            mov_src_val <= _46;
        default:
            mov_src_val <= _74;
        endcase
    end
    assign _481 = word[4:3];
    always @* begin
        case (_481)
        0:
            mov_data <= mov_src_val;
        1:
            mov_data <= _495;
        2:
            mov_data <= _528;
        default:
            mov_data <= mov_src_val;
        endcase
    end
    assign _530 = mov_osr ? mov_data : _74;
    assign _531 = pull_nb_empty ? _54 : _530;
    assign _592 = out_run ? osr_shifted : _531;
    assign _451 = ~ _72;
    assign _445 = _441[5:0];
    assign _440 = { gnd,
                    _160 };
    assign vdd = 1'b1;
    assign _1451 = out_refill_after ? _1277 : osr_cnt_after;
    assign _478 = ~ mov_osr;
    assign _473 = ~ pull_clr;
    assign _467 = ~ _72;
    assign _464 = _73 < _144;
    assign _465 = ~ _464;
    assign _462 = ~ _177;
    assign _460 = ~ forced_act;
    assign _60 = clkdiv_restart;
    assign _62 = clkdiv_frac;
    assign _64 = clkdiv_int;
    assign _66 = rst_n;
    assign _68 = clk;
    clkdiv_dbg
        clkdiv_dbg
        ( .clk(_68),
          .rst_n(_66),
          .int_(_64),
          .frac(_62),
          .restart(_60),
          .phase(_87[25:1]),
          .tick(_87[0:0]) );
    assign _92 = _87[0:0];
    assign _70 = enable;
    assign tick_en = _70 & _92;
    assign _459 = _134 & tick_en;
    assign _461 = _459 & _460;
    assign _463 = _461 & _462;
    assign _466 = _463 & _465;
    assign _468 = _466 & _467;
    assign _474 = _468 & _473;
    assign tx_pop_refill = _474 & _478;
    assign _476 = _382 == _946;
    assign mov_osr = _381 & _476;
    assign _152 = word[5:5];
    assign _470 = ~ _152;
    assign _469 = pull_try & _72;
    assign pull_nb_empty = _469 & _470;
    assign _456 = ~ _72;
    assign _145 = _73 < _144;
    assign _138 = word[6:6];
    assign _146 = _138 & _145;
    assign _136 = _73 == _1277;
    assign _137 = _134 & _136;
    assign _147 = _137 | _146;
    assign pull_noop = _133 & _147;
    assign _149 = ~ pull_noop;
    assign _132 = _107[6:6];
    assign _131 = attempt & ok;
    assign _133 = _131 & _132;
    assign pull_try = _133 & _149;
    assign pull_data = pull_try & _456;
    assign pull_clr = pull_data | pull_nb_empty;
    assign _72 = tx_empty;
    assign _453 = ~ _72;
    assign _142 = { gnd,
                    _139 };
    assign _139 = _76[29:25];
    assign _141 = _139 == _1035;
    assign _144 = _141 ? _562 : _142;
    assign _178 = _73 < _144;
    assign _179 = ~ _178;
    assign autopull_hit = _134 & _179;
    assign out_hit = _177 & autopull_hit;
    assign out_refill_stall = out_hit & _453;
    assign _1445 = out_refill_stall | pull_clr;
    assign _1446 = _1445 | mov_osr;
    assign _1447 = _1446 | tx_pop_refill;
    assign _1449 = _1447 ? _1277 : _73;
    assign osr_cnt_next = out_run ? _1451 : _1449;
    assign _1454 = _81 ? _562 : osr_cnt_next;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            osr_cnt_q <= _562;
        else
            osr_cnt_q <= _1454;
    end
    assign _73 = osr_cnt_q;
    assign gnd = 1'b0;
    assign _439 = { gnd,
                    _73 };
    assign _441 = _439 + _440;
    assign _443 = _441 < _163;
    assign _444 = ~ _443;
    assign osr_cnt_after = _444 ? _562 : _445;
    assign _448 = osr_cnt_after < _144;
    assign _449 = ~ _448;
    assign _134 = _76[17:17];
    assign _438 = out_run & _134;
    assign _450 = _438 & _449;
    assign out_refill_after = _450 & _451;
    assign _455 = out_refill_after | out_refill_stall;
    assign _458 = _455 | pull_data;
    assign _480 = _458 | tx_pop_refill;
    assign osr_next = _480 ? _42 : _592;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            osr_q <= _1331;
        else
            osr_q <= osr_next;
    end
    assign _74 = osr_q;
    assign _786 = _781[0:0];
    assign _790 = _786 ? _789 : _74;
    assign _785 = _781[1:1];
    assign _794 = _785 ? _793 : _790;
    assign _784 = _781[2:2];
    assign _798 = _784 ? _797 : _794;
    assign _783 = _781[3:3];
    assign _802 = _783 ? _801 : _798;
    assign _781 = _778[4:0];
    assign _782 = _781[4:4];
    assign _806 = _782 ? _805 : _802;
    assign _160 = _107[27:22];
    assign _778 = _562 - _160;
    assign _780 = _778 == _562;
    assign _807 = _780 ? _1331 : _806;
    assign _76 = shiftctrl;
    assign _532 = _76[19:19];
    assign out_data = _532 ? _873 : _807;
    assign _1458 = out_data[15:0];
    assign _382 = word[7:5];
    assign _419 = _382 == _955;
    assign _380 = _107[7:7];
    assign _379 = attempt & ok;
    assign _381 = _379 & _380;
    assign mov_exec = _381 & _419;
    assign exec_lo16 = mov_exec ? _1459 : _1458;
    assign _1461 = exec_set ? exec_lo16 : _77;
    assign latch_instr_next = _83 ? _40 : _1461;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_instr_q <= _1464;
        else
            latch_instr_q <= latch_instr_next;
    end
    assign _77 = latch_instr_q;
    assign _79 = imem_word;
    assign word = _84 ? _77 : _79;
    decode
        decode
        ( .instr(word),
          .sideset_count(_104),
          .side_en(_105),
          .bit_count(_107[27:22]),
          .delay(_107[21:17]),
          .side_value(_107[16:12]),
          .side_valid(_107[11:11]),
          .uses_lcu(_107[10:10]),
          .is_set(_107[9:9]),
          .is_irq(_107[8:8]),
          .is_mov(_107[7:7]),
          .is_pull(_107[6:6]),
          .is_push(_107[5:5]),
          .is_out(_107[4:4]),
          .is_in(_107[3:3]),
          .is_wait(_107[2:2]),
          .is_jmp(_107[1:1]),
          .legal(_107[0:0]) );
    assign _108 = _107[0:0];
    assign ok = _108 & _110;
    assign _175 = attempt & ok;
    assign _177 = _175 & _176;
    assign out_run = _177 & _372;
    assign out_exec = out_run & _416;
    assign exec_set = out_exec | mov_exec;
    assign _1467 = exec_set ? vdd : _1466;
    assign _81 = restart;
    assign _1468 = _81 ? gnd : _1467;
    assign _83 = instr_write;
    assign latch_valid_next = _83 ? vdd : _1468;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            latch_valid_q <= gnd;
        else
            latch_valid_q <= latch_valid_next;
    end
    assign _84 = latch_valid_q;
    assign forced_act = _84 & _29;
    assign attempt_latch = forced_act | _97;
    assign attempt = attempt_latch | attempt_imem;
    assign _323 = attempt & ok;
    assign _325 = _323 & _324;
    assign jmp_taken = _325 & jmp_cond_val;
    assign _378 = jmp_taken | out_pc;
    assign pc_write_now = _378 | mov_pc;
    assign pc_next = pc_write_now ? pc_target : _1390;
    always @(posedge _68 or negedge _66) begin
        if (_66 == 0)
            pc_q <= _1035;
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
    assign phase = _88;

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

    wire [24:0] _312;
    wire [24:0] _324;
    wire [24:0] _336;
    wire [24:0] _348;
    wire _349;
    wire _350;
    wire _351;
    wire _352;
    wire [31:0] _353;
    wire [31:0] _354;
    wire [31:0] _355;
    wire [31:0] _356;
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
    wire [31:0] _486;
    wire _482;
    wire _481;
    wire _480;
    wire _479;
    wire [3:0] _478;
    wire _477;
    wire _476;
    wire _475;
    wire _474;
    wire _472;
    wire _471;
    wire _470;
    wire _469;
    wire _467;
    wire _466;
    wire _465;
    wire _464;
    wire _463;
    wire _462;
    wire _461;
    wire [31:0] _38;
    wire _460;
    wire [31:0] _483;
    wire _457;
    wire _456;
    wire _455;
    wire _454;
    wire _452;
    wire _451;
    wire _450;
    wire _449;
    wire _447;
    wire _432;
    wire _417;
    wire _402;
    wire _386;
    wire _385;
    wire _384;
    wire _383;
    wire _382;
    wire _381;
    wire _380;
    wire _379;
    wire [31:0] _458;
    wire [31:0] _40;
    wire [31:0] _377;
    wire [31:0] _41;
    wire [31:0] _378;
    wire [31:0] _459;
    wire [31:0] _484;
    reg [31:0] fdebug_q;
    wire _527;
    wire _526;
    wire _525;
    wire _524;
    wire _522;
    wire _521;
    wire _520;
    wire _519;
    wire _517;
    wire _516;
    wire _515;
    wire _514;
    wire _512;
    wire _511;
    wire _510;
    wire _509;
    wire _507;
    wire _506;
    wire _505;
    wire _504;
    wire _502;
    wire _501;
    wire _500;
    wire _499;
    wire _497;
    wire _496;
    wire _495;
    wire _494;
    wire _492;
    wire _491;
    wire _490;
    wire _489;
    wire [31:0] _528;
    wire _538;
    wire _537;
    wire _536;
    wire _535;
    wire [31:0] _549;
    wire [31:0] _559;
    wire _540;
    wire [31:0] _561;
    wire [31:0] _556;
    wire _541;
    wire [31:0] _558;
    wire [31:0] _553;
    wire _542;
    wire [31:0] _555;
    wire [31:0] _550;
    wire _543;
    wire [31:0] _552;
    reg [31:0] rxf_data_0;
    wire [31:0] _47;
    wire [31:0] _600;
    wire [31:0] _601;
    wire [31:0] _598;
    wire [31:0] _597;
    wire [31:0] _599;
    wire [31:0] _602;
    wire [31:0] _596;
    wire [31:0] _603;
    wire [31:0] _594;
    wire [31:0] _593;
    wire [31:0] _595;
    wire [31:0] _604;
    wire [31:0] _592;
    wire [31:0] _605;
    wire [31:0] _590;
    wire [31:0] _589;
    wire [31:0] _591;
    wire [31:0] _606;
    wire [31:0] _588;
    wire [31:0] _607;
    wire [31:0] _586;
    wire [31:0] _585;
    wire [31:0] _587;
    wire [31:0] _608;
    reg [31:0] pins_oe_q;
    wire [31:0] _49;
    wire [31:0] _627;
    wire [31:0] _628;
    wire [31:0] _625;
    wire [31:0] _624;
    wire [31:0] _626;
    wire [31:0] _629;
    wire [31:0] _623;
    wire [31:0] _630;
    wire [31:0] _621;
    wire [31:0] _620;
    wire [31:0] _622;
    wire [31:0] _631;
    wire [31:0] _619;
    wire [31:0] _632;
    wire [31:0] _617;
    wire [31:0] _616;
    wire [31:0] _618;
    wire [31:0] _633;
    wire [31:0] _615;
    wire [31:0] _634;
    wire [31:0] _613;
    wire _641;
    wire _642;
    wire _50;
    wire [7:0] _583;
    wire [7:0] _52;
    wire [7:0] _578;
    wire [7:0] _576;
    wire [7:0] _574;
    wire [7:0] _573;
    wire [7:0] _575;
    wire [7:0] _577;
    wire [7:0] _579;
    wire [7:0] _54;
    wire [7:0] _568;
    wire _645;
    wire _646;
    wire _55;
    wire [3:0] _498;
    wire [3:0] _56;
    wire _546;
    wire _57;
    wire [3:0] _503;
    wire [3:0] _58;
    wire _531;
    wire _59;
    wire [1:0] _412;
    wire _413;
    wire _414;
    wire [31:0] _411;
    wire _410;
    wire _409;
    wire _407;
    wire _408;
    wire _405;
    wire _404;
    wire _403;
    wire [77:0] _416;
    wire [31:0] _647;
    wire [31:0] _60;
    wire [4:0] _374;
    wire [31:0] _62;
    wire _643;
    wire [5:0] _644;
    reg [15:0] _1032;
    wire [15:0] _63;
    wire _320;
    wire _321;
    wire [31:0] _65;
    wire [31:0] _67;
    wire [31:0] _69;
    wire [7:0] _318;
    wire [31:0] _71;
    wire [15:0] _317;
    wire _316;
    wire _315;
    wire _314;
    wire [371:0] _323;
    wire [7:0] _566;
    wire _1035;
    wire _1036;
    wire _72;
    wire [3:0] _508;
    wire [3:0] _73;
    wire _547;
    wire _74;
    wire [3:0] _513;
    wire [3:0] _75;
    wire _532;
    wire _76;
    wire [1:0] _427;
    wire _428;
    wire _429;
    wire [31:0] _426;
    wire _425;
    wire _424;
    wire _422;
    wire _423;
    wire _420;
    wire _419;
    wire _418;
    wire [77:0] _431;
    wire [31:0] _1037;
    wire [31:0] _77;
    wire [4:0] _375;
    wire [31:0] _79;
    wire _1033;
    wire [5:0] _1034;
    reg [15:0] _1038;
    wire [15:0] _80;
    wire _332;
    wire _333;
    wire [31:0] _82;
    wire [31:0] _84;
    wire [31:0] _86;
    wire [7:0] _330;
    wire [31:0] _88;
    wire [15:0] _329;
    wire _328;
    wire _327;
    wire _326;
    wire [371:0] _335;
    wire [7:0] _564;
    wire _1041;
    wire _1042;
    wire _89;
    wire [3:0] _518;
    wire [3:0] _90;
    wire _548;
    wire _91;
    wire [3:0] _523;
    wire [3:0] _92;
    wire _533;
    wire _93;
    wire [1:0] _442;
    wire _443;
    wire _444;
    wire [31:0] _441;
    wire _440;
    wire _439;
    wire _437;
    wire _438;
    wire _435;
    wire _434;
    wire _433;
    wire [77:0] _446;
    wire [31:0] _1043;
    wire [31:0] _94;
    wire [4:0] _376;
    wire [31:0] _96;
    wire _1039;
    wire [5:0] _1040;
    reg [15:0] _1044;
    wire [15:0] _97;
    wire _344;
    wire _345;
    wire [31:0] _99;
    wire [31:0] _101;
    wire [31:0] _103;
    wire [7:0] _342;
    wire [31:0] _105;
    wire [15:0] _341;
    wire _340;
    wire _339;
    wire _338;
    wire [371:0] _347;
    wire [7:0] _563;
    wire [7:0] _565;
    wire [7:0] _567;
    wire [7:0] _569;
    wire [7:0] _570;
    wire [7:0] _571;
    wire [7:0] _572;
    wire [7:0] _580;
    wire [7:0] _581;
    reg [7:0] irq_q;
    wire [7:0] _106;
    wire [3:0] _488;
    wire [3:0] _107;
    wire _545;
    wire _108;
    wire [3:0] _493;
    wire [3:0] _109;
    wire _530;
    wire _110;
    wire [1:0] _397;
    wire [1:0] _112;
    wire _398;
    wire _114;
    wire _399;
    wire [31:0] _396;
    wire _395;
    wire _394;
    wire [31:0] _116;
    wire [1:0] _118;
    wire _392;
    wire _120;
    wire _393;
    wire [3:0] _122;
    wire _390;
    wire _389;
    wire _388;
    wire [77:0] _401;
    wire [31:0] _1045;
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
    wire [5:0] _1028;
    wire _1029;
    wire _1030;
    wire [15:0] _1027;
    reg [15:0] imem_63;
    wire [5:0] _1022;
    wire _1023;
    wire _1024;
    reg [15:0] imem_62;
    wire [5:0] _1016;
    wire _1017;
    wire _1018;
    reg [15:0] imem_61;
    wire [5:0] _1010;
    wire _1011;
    wire _1012;
    reg [15:0] imem_60;
    wire [5:0] _1004;
    wire _1005;
    wire _1006;
    reg [15:0] imem_59;
    wire [5:0] _998;
    wire _999;
    wire _1000;
    reg [15:0] imem_58;
    wire [5:0] _992;
    wire _993;
    wire _994;
    reg [15:0] imem_57;
    wire [5:0] _986;
    wire _987;
    wire _988;
    reg [15:0] imem_56;
    wire [5:0] _980;
    wire _981;
    wire _982;
    reg [15:0] imem_55;
    wire [5:0] _974;
    wire _975;
    wire _976;
    reg [15:0] imem_54;
    wire [5:0] _968;
    wire _969;
    wire _970;
    reg [15:0] imem_53;
    wire [5:0] _962;
    wire _963;
    wire _964;
    reg [15:0] imem_52;
    wire [5:0] _956;
    wire _957;
    wire _958;
    reg [15:0] imem_51;
    wire [5:0] _950;
    wire _951;
    wire _952;
    reg [15:0] imem_50;
    wire [5:0] _944;
    wire _945;
    wire _946;
    reg [15:0] imem_49;
    wire [5:0] _938;
    wire _939;
    wire _940;
    reg [15:0] imem_48;
    wire [5:0] _932;
    wire _933;
    wire _934;
    reg [15:0] imem_47;
    wire [5:0] _926;
    wire _927;
    wire _928;
    reg [15:0] imem_46;
    wire [5:0] _920;
    wire _921;
    wire _922;
    reg [15:0] imem_45;
    wire [5:0] _914;
    wire _915;
    wire _916;
    reg [15:0] imem_44;
    wire [5:0] _908;
    wire _909;
    wire _910;
    reg [15:0] imem_43;
    wire [5:0] _902;
    wire _903;
    wire _904;
    reg [15:0] imem_42;
    wire [5:0] _896;
    wire _897;
    wire _898;
    reg [15:0] imem_41;
    wire [5:0] _890;
    wire _891;
    wire _892;
    reg [15:0] imem_40;
    wire [5:0] _884;
    wire _885;
    wire _886;
    reg [15:0] imem_39;
    wire [5:0] _878;
    wire _879;
    wire _880;
    reg [15:0] imem_38;
    wire [5:0] _872;
    wire _873;
    wire _874;
    reg [15:0] imem_37;
    wire [5:0] _866;
    wire _867;
    wire _868;
    reg [15:0] imem_36;
    wire [5:0] _860;
    wire _861;
    wire _862;
    reg [15:0] imem_35;
    wire [5:0] _854;
    wire _855;
    wire _856;
    reg [15:0] imem_34;
    wire [5:0] _848;
    wire _849;
    wire _850;
    reg [15:0] imem_33;
    wire [5:0] _842;
    wire _843;
    wire _844;
    reg [15:0] imem_32;
    wire [5:0] _836;
    wire _837;
    wire _838;
    reg [15:0] imem_31;
    wire [5:0] _830;
    wire _831;
    wire _832;
    reg [15:0] imem_30;
    wire [5:0] _824;
    wire _825;
    wire _826;
    reg [15:0] imem_29;
    wire [5:0] _818;
    wire _819;
    wire _820;
    reg [15:0] imem_28;
    wire [5:0] _812;
    wire _813;
    wire _814;
    reg [15:0] imem_27;
    wire [5:0] _806;
    wire _807;
    wire _808;
    reg [15:0] imem_26;
    wire [5:0] _800;
    wire _801;
    wire _802;
    reg [15:0] imem_25;
    wire [5:0] _794;
    wire _795;
    wire _796;
    reg [15:0] imem_24;
    wire [5:0] _788;
    wire _789;
    wire _790;
    reg [15:0] imem_23;
    wire [5:0] _782;
    wire _783;
    wire _784;
    reg [15:0] imem_22;
    wire [5:0] _776;
    wire _777;
    wire _778;
    reg [15:0] imem_21;
    wire [5:0] _770;
    wire _771;
    wire _772;
    reg [15:0] imem_20;
    wire [5:0] _764;
    wire _765;
    wire _766;
    reg [15:0] imem_19;
    wire [5:0] _758;
    wire _759;
    wire _760;
    reg [15:0] imem_18;
    wire [5:0] _752;
    wire _753;
    wire _754;
    reg [15:0] imem_17;
    wire [5:0] _746;
    wire _747;
    wire _748;
    reg [15:0] imem_16;
    wire [5:0] _740;
    wire _741;
    wire _742;
    reg [15:0] imem_15;
    wire [5:0] _734;
    wire _735;
    wire _736;
    reg [15:0] imem_14;
    wire [5:0] _728;
    wire _729;
    wire _730;
    reg [15:0] imem_13;
    wire [5:0] _722;
    wire _723;
    wire _724;
    reg [15:0] imem_12;
    wire [5:0] _716;
    wire _717;
    wire _718;
    reg [15:0] imem_11;
    wire [5:0] _710;
    wire _711;
    wire _712;
    reg [15:0] imem_10;
    wire [5:0] _704;
    wire _705;
    wire _706;
    reg [15:0] imem_9;
    wire [5:0] _698;
    wire _699;
    wire _700;
    reg [15:0] imem_8;
    wire [5:0] _692;
    wire _693;
    wire _694;
    reg [15:0] imem_7;
    wire [5:0] _686;
    wire _687;
    wire _688;
    reg [15:0] imem_6;
    wire [5:0] _680;
    wire _681;
    wire _682;
    reg [15:0] imem_5;
    wire [5:0] _674;
    wire _675;
    wire _676;
    reg [15:0] imem_4;
    wire [5:0] _668;
    wire _669;
    wire _670;
    reg [15:0] imem_3;
    wire [5:0] _662;
    wire _663;
    wire _664;
    reg [15:0] imem_2;
    wire [5:0] _656;
    wire _657;
    wire _658;
    reg [15:0] imem_1;
    wire [5:0] _650;
    wire [5:0] imem_write_idx;
    wire _651;
    wire _131;
    wire _652;
    wire [15:0] _133;
    reg [15:0] imem_0;
    wire [4:0] _373;
    wire [31:0] _135;
    wire _639;
    wire [5:0] _640;
    reg [15:0] _1046;
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
    wire [371:0] _311;
    wire [31:0] _612;
    wire [31:0] _614;
    wire [31:0] _635;
    reg [31:0] pins_out_q;
    assign _312 = _311[371:347];
    assign _324 = _323[371:347];
    assign _336 = _335[371:347];
    assign _348 = _347[371:347];
    assign _349 = _311[346:346];
    assign _350 = _323[346:346];
    assign _351 = _335[346:346];
    assign _352 = _347[346:346];
    assign _353 = _311[345:314];
    assign _354 = _323[345:314];
    assign _355 = _335[345:314];
    assign _356 = _347[345:314];
    assign _357 = _311[313:282];
    assign _358 = _323[313:282];
    assign _359 = _335[313:282];
    assign _360 = _347[313:282];
    assign _361 = _311[281:250];
    assign _362 = _323[281:250];
    assign _363 = _335[281:250];
    assign _364 = _347[281:250];
    assign _365 = _311[249:218];
    assign _366 = _323[249:218];
    assign _367 = _335[249:218];
    assign _368 = _347[249:218];
    assign _369 = _311[217:186];
    assign _370 = _323[217:186];
    assign _371 = _335[217:186];
    assign _372 = _347[217:186];
    assign _486 = 32'b00000000000000000000000000000000;
    assign _482 = _38[0:0];
    assign _481 = _38[1:1];
    assign _480 = _38[2:2];
    assign _479 = _38[3:3];
    assign _478 = 4'b0000;
    assign _477 = _38[8:8];
    assign _476 = _38[9:9];
    assign _475 = _38[10:10];
    assign _474 = _38[11:11];
    assign _472 = _38[16:16];
    assign _471 = _38[17:17];
    assign _470 = _38[18:18];
    assign _469 = _38[19:19];
    assign _467 = _38[24:24];
    assign _466 = _38[25:25];
    assign _465 = _38[26:26];
    assign _464 = _38[27:27];
    assign _463 = _38[28:28];
    assign _462 = _38[29:29];
    assign _461 = _38[30:30];
    assign _38 = fdebug_set;
    assign _460 = _38[31:31];
    assign _483 = { _460,
                    _461,
                    _462,
                    _463,
                    _464,
                    _465,
                    _466,
                    _467,
                    _478,
                    _469,
                    _470,
                    _471,
                    _472,
                    _478,
                    _474,
                    _475,
                    _476,
                    _477,
                    _478,
                    _479,
                    _480,
                    _481,
                    _482 };
    assign _457 = _347[184:184];
    assign _456 = _335[184:184];
    assign _455 = _323[184:184];
    assign _454 = _311[184:184];
    assign _452 = _446[77:77];
    assign _451 = _431[77:77];
    assign _450 = _416[77:77];
    assign _449 = _401[77:77];
    assign _447 = _446[38:38];
    assign _432 = _431[38:38];
    assign _417 = _416[38:38];
    assign _402 = _401[38:38];
    assign _386 = _347[183:183];
    assign _385 = _335[183:183];
    assign _384 = _323[183:183];
    assign _383 = _311[183:183];
    assign _382 = _347[185:185];
    assign _381 = _335[185:185];
    assign _380 = _323[185:185];
    assign _379 = _311[185:185];
    assign _458 = { _379,
                    _380,
                    _381,
                    _382,
                    _383,
                    _384,
                    _385,
                    _386,
                    _478,
                    _402,
                    _417,
                    _432,
                    _447,
                    _478,
                    _449,
                    _450,
                    _451,
                    _452,
                    _478,
                    _454,
                    _455,
                    _456,
                    _457 };
    assign _40 = fdebug_clear;
    assign _377 = ~ _40;
    assign _41 = fdebug_q;
    assign _378 = _41 & _377;
    assign _459 = _378 | _458;
    assign _484 = _459 | _483;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            fdebug_q <= _486;
        else
            fdebug_q <= _484;
    end
    assign _527 = _523[0:0];
    assign _526 = _523[1:1];
    assign _525 = _523[2:2];
    assign _524 = _523[3:3];
    assign _522 = _518[0:0];
    assign _521 = _518[1:1];
    assign _520 = _518[2:2];
    assign _519 = _518[3:3];
    assign _517 = _513[0:0];
    assign _516 = _513[1:1];
    assign _515 = _513[2:2];
    assign _514 = _513[3:3];
    assign _512 = _508[0:0];
    assign _511 = _508[1:1];
    assign _510 = _508[2:2];
    assign _509 = _508[3:3];
    assign _507 = _503[0:0];
    assign _506 = _503[1:1];
    assign _505 = _503[2:2];
    assign _504 = _503[3:3];
    assign _502 = _498[0:0];
    assign _501 = _498[1:1];
    assign _500 = _498[2:2];
    assign _499 = _498[3:3];
    assign _497 = _493[0:0];
    assign _496 = _493[1:1];
    assign _495 = _493[2:2];
    assign _494 = _493[3:3];
    assign _492 = _488[0:0];
    assign _491 = _488[1:1];
    assign _490 = _488[2:2];
    assign _489 = _488[3:3];
    assign _528 = { _489,
                    _490,
                    _491,
                    _492,
                    _494,
                    _495,
                    _496,
                    _497,
                    _499,
                    _500,
                    _501,
                    _502,
                    _504,
                    _505,
                    _506,
                    _507,
                    _509,
                    _510,
                    _511,
                    _512,
                    _514,
                    _515,
                    _516,
                    _517,
                    _519,
                    _520,
                    _521,
                    _522,
                    _524,
                    _525,
                    _526,
                    _527 };
    assign _538 = _446[36:36];
    assign _537 = _431[36:36];
    assign _536 = _416[36:36];
    assign _535 = _401[36:36];
    assign _549 = { _478,
                    _530,
                    _531,
                    _532,
                    _533,
                    _478,
                    _535,
                    _536,
                    _537,
                    _538,
                    _478,
                    _540,
                    _541,
                    _542,
                    _543,
                    _478,
                    _545,
                    _546,
                    _547,
                    _548 };
    assign _559 = _401[70:39];
    assign _540 = _401[76:76];
    assign _561 = _540 ? _486 : _559;
    assign _556 = _416[70:39];
    assign _541 = _416[76:76];
    assign _558 = _541 ? _486 : _556;
    assign _553 = _431[70:39];
    assign _542 = _431[76:76];
    assign _555 = _542 ? _486 : _553;
    assign _550 = _446[70:39];
    assign _543 = _446[76:76];
    assign _552 = _543 ? _486 : _550;
    always @* begin
        case (_112)
        0:
            rxf_data_0 <= _552;
        1:
            rxf_data_0 <= _555;
        2:
            rxf_data_0 <= _558;
        default:
            rxf_data_0 <= _561;
        endcase
    end
    assign _47 = pins_oe_q;
    assign _600 = ~ _597;
    assign _601 = _600 & _47;
    assign _598 = _347[132:101];
    assign _597 = _347[100:69];
    assign _599 = _597 & _598;
    assign _602 = _599 | _601;
    assign _596 = ~ _593;
    assign _603 = _596 & _602;
    assign _594 = _335[132:101];
    assign _593 = _335[100:69];
    assign _595 = _593 & _594;
    assign _604 = _595 | _603;
    assign _592 = ~ _589;
    assign _605 = _592 & _604;
    assign _590 = _323[132:101];
    assign _589 = _323[100:69];
    assign _591 = _589 & _590;
    assign _606 = _591 | _605;
    assign _588 = ~ _585;
    assign _607 = _588 & _606;
    assign _586 = _311[132:101];
    assign _585 = _311[100:69];
    assign _587 = _585 & _586;
    assign _608 = _587 | _607;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            pins_oe_q <= _486;
        else
            pins_oe_q <= _608;
    end
    assign _49 = pins_out_q;
    assign _627 = ~ _624;
    assign _628 = _627 & _49;
    assign _625 = _347[68:37];
    assign _624 = _347[36:5];
    assign _626 = _624 & _625;
    assign _629 = _626 | _628;
    assign _623 = ~ _620;
    assign _630 = _623 & _629;
    assign _621 = _335[68:37];
    assign _620 = _335[36:5];
    assign _622 = _620 & _621;
    assign _631 = _622 | _630;
    assign _619 = ~ _616;
    assign _632 = _619 & _631;
    assign _617 = _323[68:37];
    assign _616 = _323[36:5];
    assign _618 = _616 & _617;
    assign _633 = _618 | _632;
    assign _615 = ~ _612;
    assign _634 = _615 & _633;
    assign _613 = _311[68:37];
    assign _641 = imem_write_idx == _640;
    assign _642 = _131 & _641;
    assign _50 = _642;
    assign _583 = 8'b00000000;
    assign _52 = irq_force;
    assign _578 = _311[140:133];
    assign _576 = _323[140:133];
    assign _574 = _335[140:133];
    assign _573 = _347[140:133];
    assign _575 = _573 | _574;
    assign _577 = _575 | _576;
    assign _579 = _577 | _578;
    assign _54 = irq_clear;
    assign _568 = _311[148:141];
    assign _645 = imem_write_idx == _644;
    assign _646 = _131 & _645;
    assign _55 = _646;
    assign _498 = _416[74:71];
    assign _56 = _498;
    assign _546 = _416[75:75];
    assign _57 = _546;
    assign _503 = _416[35:32];
    assign _58 = _503;
    assign _531 = _416[37:37];
    assign _59 = _531;
    assign _412 = 2'b10;
    assign _413 = _112 == _412;
    assign _414 = _114 & _413;
    assign _411 = _323[182:151];
    assign _410 = _323[150:150];
    assign _409 = _323[149:149];
    assign _407 = _118 == _412;
    assign _408 = _120 & _407;
    assign _405 = _122[2:2];
    assign _404 = _67[31:31];
    assign _403 = _67[30:30];
    fifo_join
        fifo_join_1
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_403),
          .join_rx(_404),
          .flush(_405),
          .host_tx_push(_408),
          .host_tx_data(_116),
          .sm_tx_pop(_409),
          .sm_rx_push(_410),
          .sm_rx_data(_411),
          .host_rx_pop(_414),
          .rx_underflow(_416[77:77]),
          .rx_empty(_416[76:76]),
          .rx_full(_416[75:75]),
          .rx_level(_416[74:71]),
          .rx_head(_416[70:39]),
          .tx_dropped(_416[38:38]),
          .tx_empty(_416[37:37]),
          .tx_full(_416[36:36]),
          .tx_level(_416[35:32]),
          .tx_head(_416[31:0]) );
    assign _647 = _416[31:0];
    assign _60 = _647;
    assign _374 = _323[4:0];
    assign _62 = ext2;
    assign _643 = _62[0:0];
    assign _644 = { _643,
                    _374 };
    always @* begin
        case (_644)
        0:
            _1032 <= imem_0;
        1:
            _1032 <= imem_1;
        2:
            _1032 <= imem_2;
        3:
            _1032 <= imem_3;
        4:
            _1032 <= imem_4;
        5:
            _1032 <= imem_5;
        6:
            _1032 <= imem_6;
        7:
            _1032 <= imem_7;
        8:
            _1032 <= imem_8;
        9:
            _1032 <= imem_9;
        10:
            _1032 <= imem_10;
        11:
            _1032 <= imem_11;
        12:
            _1032 <= imem_12;
        13:
            _1032 <= imem_13;
        14:
            _1032 <= imem_14;
        15:
            _1032 <= imem_15;
        16:
            _1032 <= imem_16;
        17:
            _1032 <= imem_17;
        18:
            _1032 <= imem_18;
        19:
            _1032 <= imem_19;
        20:
            _1032 <= imem_20;
        21:
            _1032 <= imem_21;
        22:
            _1032 <= imem_22;
        23:
            _1032 <= imem_23;
        24:
            _1032 <= imem_24;
        25:
            _1032 <= imem_25;
        26:
            _1032 <= imem_26;
        27:
            _1032 <= imem_27;
        28:
            _1032 <= imem_28;
        29:
            _1032 <= imem_29;
        30:
            _1032 <= imem_30;
        31:
            _1032 <= imem_31;
        32:
            _1032 <= imem_32;
        33:
            _1032 <= imem_33;
        34:
            _1032 <= imem_34;
        35:
            _1032 <= imem_35;
        36:
            _1032 <= imem_36;
        37:
            _1032 <= imem_37;
        38:
            _1032 <= imem_38;
        39:
            _1032 <= imem_39;
        40:
            _1032 <= imem_40;
        41:
            _1032 <= imem_41;
        42:
            _1032 <= imem_42;
        43:
            _1032 <= imem_43;
        44:
            _1032 <= imem_44;
        45:
            _1032 <= imem_45;
        46:
            _1032 <= imem_46;
        47:
            _1032 <= imem_47;
        48:
            _1032 <= imem_48;
        49:
            _1032 <= imem_49;
        50:
            _1032 <= imem_50;
        51:
            _1032 <= imem_51;
        52:
            _1032 <= imem_52;
        53:
            _1032 <= imem_53;
        54:
            _1032 <= imem_54;
        55:
            _1032 <= imem_55;
        56:
            _1032 <= imem_56;
        57:
            _1032 <= imem_57;
        58:
            _1032 <= imem_58;
        59:
            _1032 <= imem_59;
        60:
            _1032 <= imem_60;
        61:
            _1032 <= imem_61;
        62:
            _1032 <= imem_62;
        default:
            _1032 <= imem_63;
        endcase
    end
    assign _63 = _1032;
    assign _320 = _140 == _412;
    assign _321 = _142 & _320;
    assign _65 = pinctrl2;
    assign _67 = shiftctrl2;
    assign _69 = execctrl2;
    assign _318 = _71[15:8];
    assign _71 = clkdiv2;
    assign _317 = _71[31:16];
    assign _316 = _152[2:2];
    assign _315 = _154[2:2];
    assign _314 = _156[2:2];
    sm
        sm_1
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_412),
          .enable(_314),
          .restart(_315),
          .clkdiv_restart(_316),
          .clkdiv_int(_317),
          .clkdiv_frac(_318),
          .execctrl(_69),
          .shiftctrl(_67),
          .pinctrl(_65),
          .instr_write(_321),
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
          .phase(_323[371:347]),
          .exec_stalled(_323[346:346]),
          .dbg_cnt(_323[345:314]),
          .osr(_323[313:282]),
          .isr(_323[281:250]),
          .y(_323[249:218]),
          .x(_323[217:186]),
          .illegal(_323[185:185]),
          .rxstall(_323[184:184]),
          .txstall(_323[183:183]),
          .rx_push_data(_323[182:151]),
          .rx_push(_323[150:150]),
          .tx_pop(_323[149:149]),
          .irq_clr(_323[148:141]),
          .irq_set(_323[140:133]),
          .dir_val(_323[132:101]),
          .dir_mask(_323[100:69]),
          .lvl_val(_323[68:37]),
          .lvl_mask(_323[36:5]),
          .pc(_323[4:0]) );
    assign _566 = _323[148:141];
    assign _1035 = imem_write_idx == _1034;
    assign _1036 = _131 & _1035;
    assign _72 = _1036;
    assign _508 = _431[74:71];
    assign _73 = _508;
    assign _547 = _431[75:75];
    assign _74 = _547;
    assign _513 = _431[35:32];
    assign _75 = _513;
    assign _532 = _431[37:37];
    assign _76 = _532;
    assign _427 = 2'b01;
    assign _428 = _112 == _427;
    assign _429 = _114 & _428;
    assign _426 = _335[182:151];
    assign _425 = _335[150:150];
    assign _424 = _335[149:149];
    assign _422 = _118 == _427;
    assign _423 = _120 & _422;
    assign _420 = _122[1:1];
    assign _419 = _84[31:31];
    assign _418 = _84[30:30];
    fifo_join
        fifo_join_0
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_418),
          .join_rx(_419),
          .flush(_420),
          .host_tx_push(_423),
          .host_tx_data(_116),
          .sm_tx_pop(_424),
          .sm_rx_push(_425),
          .sm_rx_data(_426),
          .host_rx_pop(_429),
          .rx_underflow(_431[77:77]),
          .rx_empty(_431[76:76]),
          .rx_full(_431[75:75]),
          .rx_level(_431[74:71]),
          .rx_head(_431[70:39]),
          .tx_dropped(_431[38:38]),
          .tx_empty(_431[37:37]),
          .tx_full(_431[36:36]),
          .tx_level(_431[35:32]),
          .tx_head(_431[31:0]) );
    assign _1037 = _431[31:0];
    assign _77 = _1037;
    assign _375 = _335[4:0];
    assign _79 = ext1;
    assign _1033 = _79[0:0];
    assign _1034 = { _1033,
                     _375 };
    always @* begin
        case (_1034)
        0:
            _1038 <= imem_0;
        1:
            _1038 <= imem_1;
        2:
            _1038 <= imem_2;
        3:
            _1038 <= imem_3;
        4:
            _1038 <= imem_4;
        5:
            _1038 <= imem_5;
        6:
            _1038 <= imem_6;
        7:
            _1038 <= imem_7;
        8:
            _1038 <= imem_8;
        9:
            _1038 <= imem_9;
        10:
            _1038 <= imem_10;
        11:
            _1038 <= imem_11;
        12:
            _1038 <= imem_12;
        13:
            _1038 <= imem_13;
        14:
            _1038 <= imem_14;
        15:
            _1038 <= imem_15;
        16:
            _1038 <= imem_16;
        17:
            _1038 <= imem_17;
        18:
            _1038 <= imem_18;
        19:
            _1038 <= imem_19;
        20:
            _1038 <= imem_20;
        21:
            _1038 <= imem_21;
        22:
            _1038 <= imem_22;
        23:
            _1038 <= imem_23;
        24:
            _1038 <= imem_24;
        25:
            _1038 <= imem_25;
        26:
            _1038 <= imem_26;
        27:
            _1038 <= imem_27;
        28:
            _1038 <= imem_28;
        29:
            _1038 <= imem_29;
        30:
            _1038 <= imem_30;
        31:
            _1038 <= imem_31;
        32:
            _1038 <= imem_32;
        33:
            _1038 <= imem_33;
        34:
            _1038 <= imem_34;
        35:
            _1038 <= imem_35;
        36:
            _1038 <= imem_36;
        37:
            _1038 <= imem_37;
        38:
            _1038 <= imem_38;
        39:
            _1038 <= imem_39;
        40:
            _1038 <= imem_40;
        41:
            _1038 <= imem_41;
        42:
            _1038 <= imem_42;
        43:
            _1038 <= imem_43;
        44:
            _1038 <= imem_44;
        45:
            _1038 <= imem_45;
        46:
            _1038 <= imem_46;
        47:
            _1038 <= imem_47;
        48:
            _1038 <= imem_48;
        49:
            _1038 <= imem_49;
        50:
            _1038 <= imem_50;
        51:
            _1038 <= imem_51;
        52:
            _1038 <= imem_52;
        53:
            _1038 <= imem_53;
        54:
            _1038 <= imem_54;
        55:
            _1038 <= imem_55;
        56:
            _1038 <= imem_56;
        57:
            _1038 <= imem_57;
        58:
            _1038 <= imem_58;
        59:
            _1038 <= imem_59;
        60:
            _1038 <= imem_60;
        61:
            _1038 <= imem_61;
        62:
            _1038 <= imem_62;
        default:
            _1038 <= imem_63;
        endcase
    end
    assign _80 = _1038;
    assign _332 = _140 == _427;
    assign _333 = _142 & _332;
    assign _82 = pinctrl1;
    assign _84 = shiftctrl1;
    assign _86 = execctrl1;
    assign _330 = _88[15:8];
    assign _88 = clkdiv1;
    assign _329 = _88[31:16];
    assign _328 = _152[1:1];
    assign _327 = _154[1:1];
    assign _326 = _156[1:1];
    sm
        sm_0
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_427),
          .enable(_326),
          .restart(_327),
          .clkdiv_restart(_328),
          .clkdiv_int(_329),
          .clkdiv_frac(_330),
          .execctrl(_86),
          .shiftctrl(_84),
          .pinctrl(_82),
          .instr_write(_333),
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
          .phase(_335[371:347]),
          .exec_stalled(_335[346:346]),
          .dbg_cnt(_335[345:314]),
          .osr(_335[313:282]),
          .isr(_335[281:250]),
          .y(_335[249:218]),
          .x(_335[217:186]),
          .illegal(_335[185:185]),
          .rxstall(_335[184:184]),
          .txstall(_335[183:183]),
          .rx_push_data(_335[182:151]),
          .rx_push(_335[150:150]),
          .tx_pop(_335[149:149]),
          .irq_clr(_335[148:141]),
          .irq_set(_335[140:133]),
          .dir_val(_335[132:101]),
          .dir_mask(_335[100:69]),
          .lvl_val(_335[68:37]),
          .lvl_mask(_335[36:5]),
          .pc(_335[4:0]) );
    assign _564 = _335[148:141];
    assign _1041 = imem_write_idx == _1040;
    assign _1042 = _131 & _1041;
    assign _89 = _1042;
    assign _518 = _446[74:71];
    assign _90 = _518;
    assign _548 = _446[75:75];
    assign _91 = _548;
    assign _523 = _446[35:32];
    assign _92 = _523;
    assign _533 = _446[37:37];
    assign _93 = _533;
    assign _442 = 2'b00;
    assign _443 = _112 == _442;
    assign _444 = _114 & _443;
    assign _441 = _347[182:151];
    assign _440 = _347[150:150];
    assign _439 = _347[149:149];
    assign _437 = _118 == _442;
    assign _438 = _120 & _437;
    assign _435 = _122[0:0];
    assign _434 = _101[31:31];
    assign _433 = _101[30:30];
    fifo_join
        fifo_join
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_433),
          .join_rx(_434),
          .flush(_435),
          .host_tx_push(_438),
          .host_tx_data(_116),
          .sm_tx_pop(_439),
          .sm_rx_push(_440),
          .sm_rx_data(_441),
          .host_rx_pop(_444),
          .rx_underflow(_446[77:77]),
          .rx_empty(_446[76:76]),
          .rx_full(_446[75:75]),
          .rx_level(_446[74:71]),
          .rx_head(_446[70:39]),
          .tx_dropped(_446[38:38]),
          .tx_empty(_446[37:37]),
          .tx_full(_446[36:36]),
          .tx_level(_446[35:32]),
          .tx_head(_446[31:0]) );
    assign _1043 = _446[31:0];
    assign _94 = _1043;
    assign _376 = _347[4:0];
    assign _96 = ext0;
    assign _1039 = _96[0:0];
    assign _1040 = { _1039,
                     _376 };
    always @* begin
        case (_1040)
        0:
            _1044 <= imem_0;
        1:
            _1044 <= imem_1;
        2:
            _1044 <= imem_2;
        3:
            _1044 <= imem_3;
        4:
            _1044 <= imem_4;
        5:
            _1044 <= imem_5;
        6:
            _1044 <= imem_6;
        7:
            _1044 <= imem_7;
        8:
            _1044 <= imem_8;
        9:
            _1044 <= imem_9;
        10:
            _1044 <= imem_10;
        11:
            _1044 <= imem_11;
        12:
            _1044 <= imem_12;
        13:
            _1044 <= imem_13;
        14:
            _1044 <= imem_14;
        15:
            _1044 <= imem_15;
        16:
            _1044 <= imem_16;
        17:
            _1044 <= imem_17;
        18:
            _1044 <= imem_18;
        19:
            _1044 <= imem_19;
        20:
            _1044 <= imem_20;
        21:
            _1044 <= imem_21;
        22:
            _1044 <= imem_22;
        23:
            _1044 <= imem_23;
        24:
            _1044 <= imem_24;
        25:
            _1044 <= imem_25;
        26:
            _1044 <= imem_26;
        27:
            _1044 <= imem_27;
        28:
            _1044 <= imem_28;
        29:
            _1044 <= imem_29;
        30:
            _1044 <= imem_30;
        31:
            _1044 <= imem_31;
        32:
            _1044 <= imem_32;
        33:
            _1044 <= imem_33;
        34:
            _1044 <= imem_34;
        35:
            _1044 <= imem_35;
        36:
            _1044 <= imem_36;
        37:
            _1044 <= imem_37;
        38:
            _1044 <= imem_38;
        39:
            _1044 <= imem_39;
        40:
            _1044 <= imem_40;
        41:
            _1044 <= imem_41;
        42:
            _1044 <= imem_42;
        43:
            _1044 <= imem_43;
        44:
            _1044 <= imem_44;
        45:
            _1044 <= imem_45;
        46:
            _1044 <= imem_46;
        47:
            _1044 <= imem_47;
        48:
            _1044 <= imem_48;
        49:
            _1044 <= imem_49;
        50:
            _1044 <= imem_50;
        51:
            _1044 <= imem_51;
        52:
            _1044 <= imem_52;
        53:
            _1044 <= imem_53;
        54:
            _1044 <= imem_54;
        55:
            _1044 <= imem_55;
        56:
            _1044 <= imem_56;
        57:
            _1044 <= imem_57;
        58:
            _1044 <= imem_58;
        59:
            _1044 <= imem_59;
        60:
            _1044 <= imem_60;
        61:
            _1044 <= imem_61;
        62:
            _1044 <= imem_62;
        default:
            _1044 <= imem_63;
        endcase
    end
    assign _97 = _1044;
    assign _344 = _140 == _442;
    assign _345 = _142 & _344;
    assign _99 = pinctrl0;
    assign _101 = shiftctrl0;
    assign _103 = execctrl0;
    assign _342 = _105[15:8];
    assign _105 = clkdiv0;
    assign _341 = _105[31:16];
    assign _340 = _152[0:0];
    assign _339 = _154[0:0];
    assign _338 = _156[0:0];
    sm
        sm
        ( .clk(_160),
          .rst_n(_158),
          .sm_num(_442),
          .enable(_338),
          .restart(_339),
          .clkdiv_restart(_340),
          .clkdiv_int(_341),
          .clkdiv_frac(_342),
          .execctrl(_103),
          .shiftctrl(_101),
          .pinctrl(_99),
          .instr_write(_345),
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
          .phase(_347[371:347]),
          .exec_stalled(_347[346:346]),
          .dbg_cnt(_347[345:314]),
          .osr(_347[313:282]),
          .isr(_347[281:250]),
          .y(_347[249:218]),
          .x(_347[217:186]),
          .illegal(_347[185:185]),
          .rxstall(_347[184:184]),
          .txstall(_347[183:183]),
          .rx_push_data(_347[182:151]),
          .rx_push(_347[150:150]),
          .tx_pop(_347[149:149]),
          .irq_clr(_347[148:141]),
          .irq_set(_347[140:133]),
          .dir_val(_347[132:101]),
          .dir_mask(_347[100:69]),
          .lvl_val(_347[68:37]),
          .lvl_mask(_347[36:5]),
          .pc(_347[4:0]) );
    assign _563 = _347[148:141];
    assign _565 = _563 | _564;
    assign _567 = _565 | _566;
    assign _569 = _567 | _568;
    assign _570 = _569 | _54;
    assign _571 = ~ _570;
    assign _572 = _106 & _571;
    assign _580 = _572 | _579;
    assign _581 = _580 | _52;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            irq_q <= _583;
        else
            irq_q <= _581;
    end
    assign _106 = irq_q;
    assign _488 = _401[74:71];
    assign _107 = _488;
    assign _545 = _401[75:75];
    assign _108 = _545;
    assign _493 = _401[35:32];
    assign _109 = _493;
    assign _530 = _401[37:37];
    assign _110 = _530;
    assign _397 = 2'b11;
    assign _112 = rxf_sm;
    assign _398 = _112 == _397;
    assign _114 = rxf_pop;
    assign _399 = _114 & _398;
    assign _396 = _311[182:151];
    assign _395 = _311[150:150];
    assign _394 = _311[149:149];
    assign _116 = txf_data;
    assign _118 = txf_sm;
    assign _392 = _118 == _397;
    assign _120 = txf_push;
    assign _393 = _120 & _392;
    assign _122 = fifo_flush;
    assign _390 = _122[3:3];
    assign _389 = _146[31:31];
    assign _388 = _146[30:30];
    fifo_join
        fifo_join_2
        ( .clk(_160),
          .rst_n(_158),
          .join_tx(_388),
          .join_rx(_389),
          .flush(_390),
          .host_tx_push(_393),
          .host_tx_data(_116),
          .sm_tx_pop(_394),
          .sm_rx_push(_395),
          .sm_rx_data(_396),
          .host_rx_pop(_399),
          .rx_underflow(_401[77:77]),
          .rx_empty(_401[76:76]),
          .rx_full(_401[75:75]),
          .rx_level(_401[74:71]),
          .rx_head(_401[70:39]),
          .tx_dropped(_401[38:38]),
          .tx_empty(_401[37:37]),
          .tx_full(_401[36:36]),
          .tx_level(_401[35:32]),
          .tx_head(_401[31:0]) );
    assign _1045 = _401[31:0];
    assign _123 = _1045;
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
            in_r1 <= _486;
        else
            in_r1 <= _125;
    end
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            in_r2 <= _486;
        else
            in_r2 <= in_r1;
    end
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            in_r3 <= _486;
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
    assign _1028 = 6'b111111;
    assign _1029 = imem_write_idx == _1028;
    assign _1030 = _131 & _1029;
    assign _1027 = 16'b0000000000000000;
    always @(posedge _160) begin
        if (_1030)
            imem_63 <= _133;
    end
    assign _1022 = 6'b111110;
    assign _1023 = imem_write_idx == _1022;
    assign _1024 = _131 & _1023;
    always @(posedge _160) begin
        if (_1024)
            imem_62 <= _133;
    end
    assign _1016 = 6'b111101;
    assign _1017 = imem_write_idx == _1016;
    assign _1018 = _131 & _1017;
    always @(posedge _160) begin
        if (_1018)
            imem_61 <= _133;
    end
    assign _1010 = 6'b111100;
    assign _1011 = imem_write_idx == _1010;
    assign _1012 = _131 & _1011;
    always @(posedge _160) begin
        if (_1012)
            imem_60 <= _133;
    end
    assign _1004 = 6'b111011;
    assign _1005 = imem_write_idx == _1004;
    assign _1006 = _131 & _1005;
    always @(posedge _160) begin
        if (_1006)
            imem_59 <= _133;
    end
    assign _998 = 6'b111010;
    assign _999 = imem_write_idx == _998;
    assign _1000 = _131 & _999;
    always @(posedge _160) begin
        if (_1000)
            imem_58 <= _133;
    end
    assign _992 = 6'b111001;
    assign _993 = imem_write_idx == _992;
    assign _994 = _131 & _993;
    always @(posedge _160) begin
        if (_994)
            imem_57 <= _133;
    end
    assign _986 = 6'b111000;
    assign _987 = imem_write_idx == _986;
    assign _988 = _131 & _987;
    always @(posedge _160) begin
        if (_988)
            imem_56 <= _133;
    end
    assign _980 = 6'b110111;
    assign _981 = imem_write_idx == _980;
    assign _982 = _131 & _981;
    always @(posedge _160) begin
        if (_982)
            imem_55 <= _133;
    end
    assign _974 = 6'b110110;
    assign _975 = imem_write_idx == _974;
    assign _976 = _131 & _975;
    always @(posedge _160) begin
        if (_976)
            imem_54 <= _133;
    end
    assign _968 = 6'b110101;
    assign _969 = imem_write_idx == _968;
    assign _970 = _131 & _969;
    always @(posedge _160) begin
        if (_970)
            imem_53 <= _133;
    end
    assign _962 = 6'b110100;
    assign _963 = imem_write_idx == _962;
    assign _964 = _131 & _963;
    always @(posedge _160) begin
        if (_964)
            imem_52 <= _133;
    end
    assign _956 = 6'b110011;
    assign _957 = imem_write_idx == _956;
    assign _958 = _131 & _957;
    always @(posedge _160) begin
        if (_958)
            imem_51 <= _133;
    end
    assign _950 = 6'b110010;
    assign _951 = imem_write_idx == _950;
    assign _952 = _131 & _951;
    always @(posedge _160) begin
        if (_952)
            imem_50 <= _133;
    end
    assign _944 = 6'b110001;
    assign _945 = imem_write_idx == _944;
    assign _946 = _131 & _945;
    always @(posedge _160) begin
        if (_946)
            imem_49 <= _133;
    end
    assign _938 = 6'b110000;
    assign _939 = imem_write_idx == _938;
    assign _940 = _131 & _939;
    always @(posedge _160) begin
        if (_940)
            imem_48 <= _133;
    end
    assign _932 = 6'b101111;
    assign _933 = imem_write_idx == _932;
    assign _934 = _131 & _933;
    always @(posedge _160) begin
        if (_934)
            imem_47 <= _133;
    end
    assign _926 = 6'b101110;
    assign _927 = imem_write_idx == _926;
    assign _928 = _131 & _927;
    always @(posedge _160) begin
        if (_928)
            imem_46 <= _133;
    end
    assign _920 = 6'b101101;
    assign _921 = imem_write_idx == _920;
    assign _922 = _131 & _921;
    always @(posedge _160) begin
        if (_922)
            imem_45 <= _133;
    end
    assign _914 = 6'b101100;
    assign _915 = imem_write_idx == _914;
    assign _916 = _131 & _915;
    always @(posedge _160) begin
        if (_916)
            imem_44 <= _133;
    end
    assign _908 = 6'b101011;
    assign _909 = imem_write_idx == _908;
    assign _910 = _131 & _909;
    always @(posedge _160) begin
        if (_910)
            imem_43 <= _133;
    end
    assign _902 = 6'b101010;
    assign _903 = imem_write_idx == _902;
    assign _904 = _131 & _903;
    always @(posedge _160) begin
        if (_904)
            imem_42 <= _133;
    end
    assign _896 = 6'b101001;
    assign _897 = imem_write_idx == _896;
    assign _898 = _131 & _897;
    always @(posedge _160) begin
        if (_898)
            imem_41 <= _133;
    end
    assign _890 = 6'b101000;
    assign _891 = imem_write_idx == _890;
    assign _892 = _131 & _891;
    always @(posedge _160) begin
        if (_892)
            imem_40 <= _133;
    end
    assign _884 = 6'b100111;
    assign _885 = imem_write_idx == _884;
    assign _886 = _131 & _885;
    always @(posedge _160) begin
        if (_886)
            imem_39 <= _133;
    end
    assign _878 = 6'b100110;
    assign _879 = imem_write_idx == _878;
    assign _880 = _131 & _879;
    always @(posedge _160) begin
        if (_880)
            imem_38 <= _133;
    end
    assign _872 = 6'b100101;
    assign _873 = imem_write_idx == _872;
    assign _874 = _131 & _873;
    always @(posedge _160) begin
        if (_874)
            imem_37 <= _133;
    end
    assign _866 = 6'b100100;
    assign _867 = imem_write_idx == _866;
    assign _868 = _131 & _867;
    always @(posedge _160) begin
        if (_868)
            imem_36 <= _133;
    end
    assign _860 = 6'b100011;
    assign _861 = imem_write_idx == _860;
    assign _862 = _131 & _861;
    always @(posedge _160) begin
        if (_862)
            imem_35 <= _133;
    end
    assign _854 = 6'b100010;
    assign _855 = imem_write_idx == _854;
    assign _856 = _131 & _855;
    always @(posedge _160) begin
        if (_856)
            imem_34 <= _133;
    end
    assign _848 = 6'b100001;
    assign _849 = imem_write_idx == _848;
    assign _850 = _131 & _849;
    always @(posedge _160) begin
        if (_850)
            imem_33 <= _133;
    end
    assign _842 = 6'b100000;
    assign _843 = imem_write_idx == _842;
    assign _844 = _131 & _843;
    always @(posedge _160) begin
        if (_844)
            imem_32 <= _133;
    end
    assign _836 = 6'b011111;
    assign _837 = imem_write_idx == _836;
    assign _838 = _131 & _837;
    always @(posedge _160) begin
        if (_838)
            imem_31 <= _133;
    end
    assign _830 = 6'b011110;
    assign _831 = imem_write_idx == _830;
    assign _832 = _131 & _831;
    always @(posedge _160) begin
        if (_832)
            imem_30 <= _133;
    end
    assign _824 = 6'b011101;
    assign _825 = imem_write_idx == _824;
    assign _826 = _131 & _825;
    always @(posedge _160) begin
        if (_826)
            imem_29 <= _133;
    end
    assign _818 = 6'b011100;
    assign _819 = imem_write_idx == _818;
    assign _820 = _131 & _819;
    always @(posedge _160) begin
        if (_820)
            imem_28 <= _133;
    end
    assign _812 = 6'b011011;
    assign _813 = imem_write_idx == _812;
    assign _814 = _131 & _813;
    always @(posedge _160) begin
        if (_814)
            imem_27 <= _133;
    end
    assign _806 = 6'b011010;
    assign _807 = imem_write_idx == _806;
    assign _808 = _131 & _807;
    always @(posedge _160) begin
        if (_808)
            imem_26 <= _133;
    end
    assign _800 = 6'b011001;
    assign _801 = imem_write_idx == _800;
    assign _802 = _131 & _801;
    always @(posedge _160) begin
        if (_802)
            imem_25 <= _133;
    end
    assign _794 = 6'b011000;
    assign _795 = imem_write_idx == _794;
    assign _796 = _131 & _795;
    always @(posedge _160) begin
        if (_796)
            imem_24 <= _133;
    end
    assign _788 = 6'b010111;
    assign _789 = imem_write_idx == _788;
    assign _790 = _131 & _789;
    always @(posedge _160) begin
        if (_790)
            imem_23 <= _133;
    end
    assign _782 = 6'b010110;
    assign _783 = imem_write_idx == _782;
    assign _784 = _131 & _783;
    always @(posedge _160) begin
        if (_784)
            imem_22 <= _133;
    end
    assign _776 = 6'b010101;
    assign _777 = imem_write_idx == _776;
    assign _778 = _131 & _777;
    always @(posedge _160) begin
        if (_778)
            imem_21 <= _133;
    end
    assign _770 = 6'b010100;
    assign _771 = imem_write_idx == _770;
    assign _772 = _131 & _771;
    always @(posedge _160) begin
        if (_772)
            imem_20 <= _133;
    end
    assign _764 = 6'b010011;
    assign _765 = imem_write_idx == _764;
    assign _766 = _131 & _765;
    always @(posedge _160) begin
        if (_766)
            imem_19 <= _133;
    end
    assign _758 = 6'b010010;
    assign _759 = imem_write_idx == _758;
    assign _760 = _131 & _759;
    always @(posedge _160) begin
        if (_760)
            imem_18 <= _133;
    end
    assign _752 = 6'b010001;
    assign _753 = imem_write_idx == _752;
    assign _754 = _131 & _753;
    always @(posedge _160) begin
        if (_754)
            imem_17 <= _133;
    end
    assign _746 = 6'b010000;
    assign _747 = imem_write_idx == _746;
    assign _748 = _131 & _747;
    always @(posedge _160) begin
        if (_748)
            imem_16 <= _133;
    end
    assign _740 = 6'b001111;
    assign _741 = imem_write_idx == _740;
    assign _742 = _131 & _741;
    always @(posedge _160) begin
        if (_742)
            imem_15 <= _133;
    end
    assign _734 = 6'b001110;
    assign _735 = imem_write_idx == _734;
    assign _736 = _131 & _735;
    always @(posedge _160) begin
        if (_736)
            imem_14 <= _133;
    end
    assign _728 = 6'b001101;
    assign _729 = imem_write_idx == _728;
    assign _730 = _131 & _729;
    always @(posedge _160) begin
        if (_730)
            imem_13 <= _133;
    end
    assign _722 = 6'b001100;
    assign _723 = imem_write_idx == _722;
    assign _724 = _131 & _723;
    always @(posedge _160) begin
        if (_724)
            imem_12 <= _133;
    end
    assign _716 = 6'b001011;
    assign _717 = imem_write_idx == _716;
    assign _718 = _131 & _717;
    always @(posedge _160) begin
        if (_718)
            imem_11 <= _133;
    end
    assign _710 = 6'b001010;
    assign _711 = imem_write_idx == _710;
    assign _712 = _131 & _711;
    always @(posedge _160) begin
        if (_712)
            imem_10 <= _133;
    end
    assign _704 = 6'b001001;
    assign _705 = imem_write_idx == _704;
    assign _706 = _131 & _705;
    always @(posedge _160) begin
        if (_706)
            imem_9 <= _133;
    end
    assign _698 = 6'b001000;
    assign _699 = imem_write_idx == _698;
    assign _700 = _131 & _699;
    always @(posedge _160) begin
        if (_700)
            imem_8 <= _133;
    end
    assign _692 = 6'b000111;
    assign _693 = imem_write_idx == _692;
    assign _694 = _131 & _693;
    always @(posedge _160) begin
        if (_694)
            imem_7 <= _133;
    end
    assign _686 = 6'b000110;
    assign _687 = imem_write_idx == _686;
    assign _688 = _131 & _687;
    always @(posedge _160) begin
        if (_688)
            imem_6 <= _133;
    end
    assign _680 = 6'b000101;
    assign _681 = imem_write_idx == _680;
    assign _682 = _131 & _681;
    always @(posedge _160) begin
        if (_682)
            imem_5 <= _133;
    end
    assign _674 = 6'b000100;
    assign _675 = imem_write_idx == _674;
    assign _676 = _131 & _675;
    always @(posedge _160) begin
        if (_676)
            imem_4 <= _133;
    end
    assign _668 = 6'b000011;
    assign _669 = imem_write_idx == _668;
    assign _670 = _131 & _669;
    always @(posedge _160) begin
        if (_670)
            imem_3 <= _133;
    end
    assign _662 = 6'b000010;
    assign _663 = imem_write_idx == _662;
    assign _664 = _131 & _663;
    always @(posedge _160) begin
        if (_664)
            imem_2 <= _133;
    end
    assign _656 = 6'b000001;
    assign _657 = imem_write_idx == _656;
    assign _658 = _131 & _657;
    always @(posedge _160) begin
        if (_658)
            imem_1 <= _133;
    end
    assign _650 = 6'b000000;
    assign imem_write_idx = imem_addr;
    assign _651 = imem_write_idx == _650;
    assign _131 = imem_write;
    assign _652 = _131 & _651;
    assign _133 = imem_data;
    always @(posedge _160) begin
        if (_652)
            imem_0 <= _133;
    end
    assign _373 = _311[4:0];
    assign _135 = ext3;
    assign _639 = _135[0:0];
    assign _640 = { _639,
                    _373 };
    always @* begin
        case (_640)
        0:
            _1046 <= imem_0;
        1:
            _1046 <= imem_1;
        2:
            _1046 <= imem_2;
        3:
            _1046 <= imem_3;
        4:
            _1046 <= imem_4;
        5:
            _1046 <= imem_5;
        6:
            _1046 <= imem_6;
        7:
            _1046 <= imem_7;
        8:
            _1046 <= imem_8;
        9:
            _1046 <= imem_9;
        10:
            _1046 <= imem_10;
        11:
            _1046 <= imem_11;
        12:
            _1046 <= imem_12;
        13:
            _1046 <= imem_13;
        14:
            _1046 <= imem_14;
        15:
            _1046 <= imem_15;
        16:
            _1046 <= imem_16;
        17:
            _1046 <= imem_17;
        18:
            _1046 <= imem_18;
        19:
            _1046 <= imem_19;
        20:
            _1046 <= imem_20;
        21:
            _1046 <= imem_21;
        22:
            _1046 <= imem_22;
        23:
            _1046 <= imem_23;
        24:
            _1046 <= imem_24;
        25:
            _1046 <= imem_25;
        26:
            _1046 <= imem_26;
        27:
            _1046 <= imem_27;
        28:
            _1046 <= imem_28;
        29:
            _1046 <= imem_29;
        30:
            _1046 <= imem_30;
        31:
            _1046 <= imem_31;
        32:
            _1046 <= imem_32;
        33:
            _1046 <= imem_33;
        34:
            _1046 <= imem_34;
        35:
            _1046 <= imem_35;
        36:
            _1046 <= imem_36;
        37:
            _1046 <= imem_37;
        38:
            _1046 <= imem_38;
        39:
            _1046 <= imem_39;
        40:
            _1046 <= imem_40;
        41:
            _1046 <= imem_41;
        42:
            _1046 <= imem_42;
        43:
            _1046 <= imem_43;
        44:
            _1046 <= imem_44;
        45:
            _1046 <= imem_45;
        46:
            _1046 <= imem_46;
        47:
            _1046 <= imem_47;
        48:
            _1046 <= imem_48;
        49:
            _1046 <= imem_49;
        50:
            _1046 <= imem_50;
        51:
            _1046 <= imem_51;
        52:
            _1046 <= imem_52;
        53:
            _1046 <= imem_53;
        54:
            _1046 <= imem_54;
        55:
            _1046 <= imem_55;
        56:
            _1046 <= imem_56;
        57:
            _1046 <= imem_57;
        58:
            _1046 <= imem_58;
        59:
            _1046 <= imem_59;
        60:
            _1046 <= imem_60;
        61:
            _1046 <= imem_61;
        62:
            _1046 <= imem_62;
        default:
            _1046 <= imem_63;
        endcase
    end
    assign _136 = _1046;
    assign _138 = instr_data;
    assign _140 = instr_sm;
    assign _169 = _140 == _397;
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
          .sm_num(_397),
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
          .phase(_311[371:347]),
          .exec_stalled(_311[346:346]),
          .dbg_cnt(_311[345:314]),
          .osr(_311[313:282]),
          .isr(_311[281:250]),
          .y(_311[249:218]),
          .x(_311[217:186]),
          .illegal(_311[185:185]),
          .rxstall(_311[184:184]),
          .txstall(_311[183:183]),
          .rx_push_data(_311[182:151]),
          .rx_push(_311[150:150]),
          .tx_pop(_311[149:149]),
          .irq_clr(_311[148:141]),
          .irq_set(_311[140:133]),
          .dir_val(_311[132:101]),
          .dir_mask(_311[100:69]),
          .lvl_val(_311[68:37]),
          .lvl_mask(_311[36:5]),
          .pc(_311[4:0]) );
    assign _612 = _311[36:5];
    assign _614 = _612 & _613;
    assign _635 = _614 | _634;
    always @(posedge _160 or negedge _158) begin
        if (_158 == 0)
            pins_out_q <= _486;
        else
            pins_out_q <= _635;
    end
    assign pins_out = pins_out_q;
    assign pins_oe = pins_oe_q;
    assign irq = irq_q;
    assign rxf_data = rxf_data_0;
    assign fstat = _549;
    assign flevel = _528;
    assign fdebug = fdebug_q;
    assign dbg_pc0 = _376;
    assign dbg_pc1 = _375;
    assign dbg_pc2 = _374;
    assign dbg_pc3 = _373;
    assign dbg_x0 = _372;
    assign dbg_x1 = _371;
    assign dbg_x2 = _370;
    assign dbg_x3 = _369;
    assign dbg_y0 = _368;
    assign dbg_y1 = _367;
    assign dbg_y2 = _366;
    assign dbg_y3 = _365;
    assign dbg_isr0 = _364;
    assign dbg_isr1 = _363;
    assign dbg_isr2 = _362;
    assign dbg_isr3 = _361;
    assign dbg_osr0 = _360;
    assign dbg_osr1 = _359;
    assign dbg_osr2 = _358;
    assign dbg_osr3 = _357;
    assign dbg_cnt0 = _356;
    assign dbg_cnt1 = _355;
    assign dbg_cnt2 = _354;
    assign dbg_cnt3 = _353;
    assign dbg_exec_stalled0 = _352;
    assign dbg_exec_stalled1 = _351;
    assign dbg_exec_stalled2 = _350;
    assign dbg_exec_stalled3 = _349;
    assign dbg_phase0 = _348;
    assign dbg_phase1 = _336;
    assign dbg_phase2 = _324;
    assign dbg_phase3 = _312;
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

    wire [7:0] _177;
    wire [7:0] _178;
    wire [7:0] _59;
    wire [7:0] _179;
    wire [7:0] _180;
    wire [7:0] _176;
    wire [7:0] _181;
    wire [5:0] _452;
    wire [11:0] _448;
    wire _445;
    wire _444;
    wire _443;
    wire _442;
    wire [11:0] _446;
    wire [11:0] _447;
    wire _449;
    wire _450;
    wire _441;
    wire _439;
    wire _440;
    wire _451;
    wire [31:0] _427;
    wire [23:0] _423;
    wire _196;
    wire _197;
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
    wire [7:0] _198;
    wire [7:0] _3;
    wire [31:0] _424;
    wire [31:0] _661;
    wire [31:0] _4;
    wire [5:0] _757;
    wire _758;
    wire _756;
    wire _759;
    reg [31:0] _760;
    wire [31:0] _662;
    wire [31:0] _5;
    wire [31:0] _663;
    wire [31:0] _6;
    wire [31:0] _7;
    wire [7:0] _752;
    wire [31:0] _753;
    wire [5:0] _172;
    wire _173;
    wire _170;
    wire _174;
    wire [7:0] _72;
    reg [7:0] _175;
    wire [31:0] _751;
    wire [5:0] _434;
    wire _435;
    wire _433;
    wire _436;
    wire [11:0] _430;
    reg [11:0] _437;
    wire [19:0] _748;
    wire [31:0] _749;
    wire [7:0] _664;
    wire [7:0] _8;
    wire [31:0] _747;
    wire [31:0] _665;
    wire [31:0] _9;
    wire [31:0] _666;
    wire [31:0] _10;
    wire [27:0] _744;
    wire [31:0] _745;
    wire [31:0] _743;
    wire [31:0] _742;
    reg [31:0] _761;
    wire [31:0] _667;
    wire [31:0] _11;
    wire [31:0] _668;
    wire [31:0] _12;
    wire [31:0] _669;
    wire [31:0] _13;
    wire [31:0] _670;
    wire [31:0] _14;
    wire [31:0] _671;
    wire [31:0] _15;
    wire [30:0] _737;
    wire [31:0] _738;
    wire [15:0] _672;
    wire [15:0] _16;
    wire [15:0] _735;
    wire [31:0] _736;
    wire [4:0] _673;
    wire [4:0] _17;
    wire [26:0] _733;
    wire [31:0] _734;
    wire [30:0] _731;
    wire _674;
    wire _18;
    wire [31:0] _732;
    reg [31:0] _739;
    wire [31:0] _675;
    wire [31:0] _19;
    wire [31:0] _676;
    wire [31:0] _20;
    wire [31:0] _677;
    wire [31:0] _21;
    wire [31:0] _678;
    wire [31:0] _22;
    wire [31:0] _679;
    wire [31:0] _23;
    wire [31:0] _729;
    wire [15:0] _680;
    wire [15:0] _24;
    wire [31:0] _727;
    wire [4:0] _681;
    wire [4:0] _25;
    wire [31:0] _725;
    wire [30:0] _722;
    wire _682;
    wire _26;
    wire [31:0] _723;
    reg [31:0] _730;
    wire [31:0] _683;
    wire [31:0] _27;
    wire [31:0] _684;
    wire [31:0] _28;
    wire [31:0] _685;
    wire [31:0] _29;
    wire [31:0] _686;
    wire [31:0] _30;
    wire [31:0] _687;
    wire [31:0] _31;
    wire [31:0] _720;
    wire [15:0] _688;
    wire [15:0] _32;
    wire [31:0] _718;
    wire [4:0] _689;
    wire [4:0] _33;
    wire [31:0] _716;
    wire [30:0] _713;
    wire _690;
    wire _34;
    wire [31:0] _714;
    reg [31:0] _721;
    wire [31:0] _691;
    wire [31:0] _35;
    wire [31:0] _692;
    wire [31:0] _36;
    wire [31:0] _693;
    wire [31:0] _37;
    wire [31:0] _694;
    wire [31:0] _38;
    wire [31:0] _695;
    wire [31:0] _39;
    wire [31:0] _711;
    wire [15:0] _696;
    wire [15:0] _40;
    wire [31:0] _709;
    wire [4:0] _697;
    wire [4:0] _41;
    wire [31:0] _707;
    wire [30:0] _704;
    wire [1:0] _654;
    wire _655;
    wire _652;
    wire _653;
    wire _656;
    wire [1:0] _649;
    wire _650;
    wire _647;
    wire _648;
    wire _651;
    wire [1:0] _644;
    wire _645;
    wire _642;
    wire _643;
    wire _646;
    wire [1:0] _639;
    wire _640;
    wire _637;
    wire _638;
    wire _641;
    wire [31:0] _658;
    wire [3:0] _631;
    wire _632;
    wire _629;
    wire _627;
    wire _630;
    wire _633;
    wire _626;
    wire _624;
    reg _634;
    wire [31:0] _635;
    wire _619;
    wire _616;
    wire _614;
    wire _617;
    wire _620;
    wire _611;
    reg _621;
    wire [31:0] _622;
    wire _606;
    wire _603;
    wire _601;
    wire _604;
    wire _607;
    wire _598;
    reg _608;
    wire [31:0] _609;
    wire _593;
    wire _590;
    wire _588;
    wire _591;
    wire _594;
    wire _585;
    reg _595;
    wire [31:0] _596;
    wire [15:0] _583;
    wire _580;
    wire _577;
    wire _578;
    wire _579;
    wire _581;
    wire _582;
    wire [15:0] _576;
    wire [3:0] _573;
    wire _574;
    wire _572;
    wire _575;
    wire _565;
    wire _564;
    wire _563;
    wire [31:0] _698;
    wire [31:0] _42;
    wire _562;
    reg _566;
    reg _569;
    wire _570;
    wire [3:0] _558;
    wire [3:0] _557;
    wire _559;
    wire _560;
    wire [4:0] _554;
    wire _555;
    wire _552;
    wire _553;
    wire _556;
    wire _561;
    wire _571;
    wire [1:0] _551;
    wire [3:0] _547;
    wire _549;
    wire _546;
    wire _550;
    wire [5:0] _541;
    wire _542;
    wire _540;
    wire _543;
    wire [31:0] _545;
    wire [7:0] _538;
    wire [5:0] _534;
    wire _535;
    wire _533;
    wire _536;
    wire [7:0] _539;
    wire [7:0] _531;
    wire [5:0] _527;
    wire _528;
    wire _526;
    wire _529;
    wire [7:0] _532;
    wire [1:0] _521;
    wire [1:0] _520;
    wire _522;
    wire _523;
    wire [3:0] _517;
    wire _518;
    wire _515;
    wire _513;
    wire _516;
    wire _519;
    wire _524;
    wire [1:0] _509;
    wire [1:0] _508;
    wire _510;
    wire _511;
    wire _506;
    wire _503;
    wire _501;
    wire _504;
    wire _507;
    wire _512;
    wire [1:0] _497;
    wire [1:0] _496;
    wire _498;
    wire _499;
    wire _494;
    wire _491;
    wire _489;
    wire _492;
    wire _495;
    wire _500;
    wire [1:0] _485;
    wire [1:0] _484;
    wire _486;
    wire _487;
    wire _482;
    wire _479;
    wire _477;
    wire _480;
    wire _483;
    wire _488;
    wire [3:0] _525;
    wire _474;
    wire _475;
    wire _472;
    wire _473;
    wire _470;
    wire _471;
    wire _468;
    wire _469;
    wire [3:0] _476;
    wire _465;
    wire _466;
    wire _463;
    wire _464;
    wire _461;
    wire _462;
    wire _459;
    wire [5:0] _456;
    wire _457;
    wire _455;
    wire _458;
    wire _460;
    wire [3:0] _467;
    wire [7:0] _44;
    wire [31:0] _454;
    wire [5:0] _403;
    wire _404;
    wire _402;
    wire _405;
    wire [23:0] _399;
    reg [23:0] _406;
    wire [31:0] _407;
    wire _395;
    wire _392;
    wire _390;
    wire _393;
    wire _396;
    wire [31:0] _388;
    reg [31:0] _397;
    wire _385;
    wire _382;
    wire _380;
    wire _383;
    wire _386;
    reg [31:0] _387;
    wire _375;
    wire _372;
    wire _370;
    wire _373;
    wire _376;
    reg [31:0] _377;
    wire _365;
    wire _362;
    wire _360;
    wire _363;
    wire _366;
    reg [31:0] _367;
    wire _355;
    wire _352;
    wire _350;
    wire _353;
    wire _356;
    wire [31:0] _348;
    wire [31:0] _346;
    wire [31:0] _347;
    reg [31:0] _357;
    wire _343;
    wire _340;
    wire _338;
    wire _341;
    wire _344;
    wire [31:0] _335;
    reg [31:0] _345;
    wire _331;
    wire _328;
    wire _326;
    wire _329;
    wire _332;
    wire [31:0] _323;
    reg [31:0] _333;
    wire _319;
    wire _316;
    wire _314;
    wire _317;
    wire _320;
    wire [31:0] _311;
    reg [31:0] _321;
    wire [3:0] _306;
    wire _307;
    wire _304;
    wire _302;
    wire _305;
    wire _308;
    wire [31:0] _300;
    wire [31:0] _298;
    wire [31:0] _299;
    reg [31:0] _309;
    wire _295;
    wire _292;
    wire _290;
    wire _293;
    wire _296;
    wire [31:0] _287;
    reg [31:0] _297;
    wire _283;
    wire _280;
    wire _278;
    wire _281;
    wire _284;
    wire [31:0] _275;
    reg [31:0] _285;
    wire _271;
    wire _268;
    wire _266;
    wire _269;
    wire _272;
    wire [31:0] _263;
    reg [31:0] _273;
    wire [3:0] _258;
    wire _259;
    wire _256;
    wire _254;
    wire _257;
    wire _260;
    wire [31:0] _252;
    wire [31:0] _250;
    wire [31:0] _251;
    reg [31:0] _261;
    wire _247;
    wire _244;
    wire _242;
    wire _245;
    wire _248;
    wire [31:0] _239;
    reg [31:0] _249;
    wire _235;
    wire _232;
    wire _230;
    wire _233;
    wire _236;
    wire [31:0] _227;
    reg [31:0] _237;
    wire [5:0] _171;
    wire _204;
    wire _202;
    wire _205;
    wire [3:0] _199;
    reg [3:0] _206;
    wire [1027:0] _660;
    wire _699;
    wire _45;
    wire [31:0] _705;
    wire _223;
    wire _219;
    wire [4:0] _130;
    wire _131;
    wire _128;
    wire _105;
    wire _129;
    wire _132;
    wire _216;
    wire _220;
    wire _224;
    wire [31:0] _208;
    reg [31:0] _225;
    wire [3:0] _221;
    reg [31:0] _712;
    wire [1:0] _217;
    reg [31:0] _740;
    wire _213;
    wire _214;
    wire _211;
    wire _212;
    wire _215;
    wire [31:0] _741;
    wire _167;
    wire _168;
    wire _164;
    wire _165;
    wire [5:0] _162;
    wire [30:0] _700;
    reg [30:0] _703;
    wire [30:0] _46;
    wire [31:0] _71;
    wire [13:0] _154;
    wire [15:0] _156;
    wire [15:0] _151;
    wire [15:0] _152;
    wire [15:0] _47;
    wire [4:0] _145;
    wire _146;
    wire _143;
    wire _144;
    wire _147;
    reg _148;
    wire _149;
    wire _138;
    wire _136;
    wire _139;
    wire _134;
    wire _140;
    wire _150;
    wire [15:0] _153;
    wire _133;
    wire [15:0] _157;
    reg [15:0] _160;
    wire [5:0] _161;
    wire _163;
    wire _166;
    wire _169;
    wire [31:0] _762;
    wire [31:0] _48;
    wire [30:0] _416;
    wire [31:0] _418;
    wire [4:0] _413;
    wire _414;
    wire [4:0] _124;
    wire _125;
    wire _108;
    wire _109;
    wire _126;
    wire _60;
    reg _68;
    reg _70;
    reg _127;
    wire [4:0] _98;
    wire [4:0] _115;
    wire _112;
    wire _110;
    wire _113;
    wire [4:0] _117;
    wire [4:0] _118;
    wire [4:0] _120;
    reg [4:0] _123;
    wire [4:0] _49;
    wire _99;
    wire _100;
    wire _50;
    wire _101;
    wire _97;
    wire _102;
    reg _104;
    wire _411;
    wire _412;
    wire _415;
    wire [31:0] _419;
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
    wire [31:0] _420;
    wire _409;
    wire _410;
    wire [31:0] _422;
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
    wire [31:0] _425;
    reg [31:0] _428;
    wire _429;
    wire [7:0] _453;
    assign _177 = _175 & _176;
    assign _178 = ~ _177;
    assign _59 = _5[7:0];
    assign _179 = _59 & _178;
    assign _180 = ~ _175;
    assign _176 = _6[7:0];
    assign _181 = _176 & _180;
    assign _452 = _6[13:8];
    assign _448 = 12'b000000000000;
    assign _445 = _8[0:0];
    assign _444 = _8[1:1];
    assign _443 = _8[2:2];
    assign _442 = _8[3:3];
    assign _446 = { _183,
                    _185,
                    _187,
                    _189,
                    _191,
                    _193,
                    _195,
                    _197,
                    _442,
                    _443,
                    _444,
                    _445 };
    assign _447 = _437 & _446;
    assign _449 = _447 == _448;
    assign _450 = ~ _449;
    assign _441 = _6[14:14];
    assign _439 = _437 == _448;
    assign _440 = ~ _439;
    assign _451 = _440 ? _450 : _441;
    assign _427 = 32'b00000000000000000000000000000000;
    assign _423 = 24'b000000000000000000000000;
    assign _196 = _42[8:8];
    assign _197 = ~ _196;
    assign _194 = _42[9:9];
    assign _195 = ~ _194;
    assign _192 = _42[10:10];
    assign _193 = ~ _192;
    assign _190 = _42[11:11];
    assign _191 = ~ _190;
    assign _188 = _42[16:16];
    assign _189 = ~ _188;
    assign _186 = _42[17:17];
    assign _187 = ~ _186;
    assign _184 = _42[18:18];
    assign _185 = ~ _184;
    assign _182 = _42[19:19];
    assign _183 = ~ _182;
    assign _198 = { _183,
                    _185,
                    _187,
                    _189,
                    _191,
                    _193,
                    _195,
                    _197 };
    assign _3 = _198;
    assign _424 = { _3,
                    _423 };
    assign _661 = _660[103:72];
    assign _4 = _661;
    assign _757 = 6'b001110;
    assign _758 = _171 == _757;
    assign _756 = _132 & _169;
    assign _759 = _756 & _758;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _760 <= _427;
        else
            if (_759)
                _760 <= _71;
    end
    assign _662 = _660[63:32];
    assign _5 = _662;
    assign _663 = _660[31:0];
    assign _6 = _663;
    assign _7 = _454;
    assign _752 = 8'b00000000;
    assign _753 = { _752,
                    _406 };
    assign _172 = 6'b001001;
    assign _173 = _171 == _172;
    assign _170 = _132 & _169;
    assign _174 = _170 & _173;
    assign _72 = _71[7:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _175 <= _752;
        else
            if (_174)
                _175 <= _72;
    end
    assign _751 = { _423,
                    _175 };
    assign _434 = 6'b001000;
    assign _435 = _171 == _434;
    assign _433 = _132 & _169;
    assign _436 = _433 & _435;
    assign _430 = _71[11:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _437 <= _448;
        else
            if (_436)
                _437 <= _430;
    end
    assign _748 = 20'b00000000000000000000;
    assign _749 = { _748,
                    _437 };
    assign _664 = _660[71:64];
    assign _8 = _664;
    assign _747 = { _423,
                    _8 };
    assign _665 = _660[167:136];
    assign _9 = _665;
    assign _666 = _660[199:168];
    assign _10 = _666;
    assign _744 = 28'b0000000000000000000000000000;
    assign _745 = { _744,
                    _206 };
    assign _743 = 32'b00010000010000000000010000000100;
    assign _742 = 32'b01010000010011000100011101010100;
    always @* begin
        case (_171)
        0:
            _761 <= _742;
        1:
            _761 <= _743;
        2:
            _761 <= _745;
        3:
            _761 <= _42;
        4:
            _761 <= _10;
        5:
            _761 <= _9;
        6:
            _761 <= _747;
        7:
            _761 <= _427;
        8:
            _761 <= _749;
        9:
            _761 <= _751;
        10:
            _761 <= _753;
        11:
            _761 <= _7;
        12:
            _761 <= _6;
        13:
            _761 <= _5;
        14:
            _761 <= _760;
        15:
            _761 <= _427;
        16:
            _761 <= _427;
        17:
            _761 <= _427;
        18:
            _761 <= _427;
        19:
            _761 <= _427;
        20:
            _761 <= _4;
        21:
            _761 <= _4;
        22:
            _761 <= _4;
        23:
            _761 <= _4;
        24:
            _761 <= _427;
        25:
            _761 <= _427;
        26:
            _761 <= _427;
        27:
            _761 <= _427;
        28:
            _761 <= _427;
        29:
            _761 <= _427;
        30:
            _761 <= _427;
        31:
            _761 <= _427;
        32:
            _761 <= _427;
        33:
            _761 <= _427;
        34:
            _761 <= _427;
        35:
            _761 <= _427;
        36:
            _761 <= _427;
        37:
            _761 <= _427;
        38:
            _761 <= _427;
        39:
            _761 <= _427;
        40:
            _761 <= _427;
        41:
            _761 <= _427;
        42:
            _761 <= _427;
        43:
            _761 <= _427;
        44:
            _761 <= _427;
        45:
            _761 <= _427;
        46:
            _761 <= _427;
        47:
            _761 <= _427;
        48:
            _761 <= _427;
        49:
            _761 <= _427;
        50:
            _761 <= _427;
        51:
            _761 <= _427;
        52:
            _761 <= _427;
        53:
            _761 <= _427;
        54:
            _761 <= _427;
        55:
            _761 <= _427;
        56:
            _761 <= _427;
        57:
            _761 <= _427;
        58:
            _761 <= _427;
        59:
            _761 <= _427;
        60:
            _761 <= _427;
        61:
            _761 <= _427;
        62:
            _761 <= _427;
        default:
            _761 <= _427;
        endcase
    end
    assign _667 = _660[859:828];
    assign _11 = _667;
    assign _668 = _660[731:700];
    assign _12 = _668;
    assign _669 = _660[603:572];
    assign _13 = _669;
    assign _670 = _660[475:444];
    assign _14 = _670;
    assign _671 = _660[347:316];
    assign _15 = _671;
    assign _737 = 31'b0000000000000000000000000000000;
    assign _738 = { _737,
                    _634 };
    assign _672 = _660[1027:1012];
    assign _16 = _672;
    assign _735 = 16'b0000000000000000;
    assign _736 = { _735,
                    _16 };
    assign _673 = _660[219:215];
    assign _17 = _673;
    assign _733 = 27'b000000000000000000000000000;
    assign _734 = { _733,
                    _17 };
    assign _731 = _309[30:0];
    assign _674 = _660[863:863];
    assign _18 = _674;
    assign _732 = { _18,
                    _731 };
    always @* begin
        case (_221)
        0:
            _739 <= _261;
        1:
            _739 <= _732;
        2:
            _739 <= _357;
        3:
            _739 <= _734;
        4:
            _739 <= _736;
        5:
            _739 <= _397;
        6:
            _739 <= _738;
        7:
            _739 <= _427;
        8:
            _739 <= _427;
        9:
            _739 <= _427;
        10:
            _739 <= _427;
        11:
            _739 <= _15;
        12:
            _739 <= _14;
        13:
            _739 <= _13;
        14:
            _739 <= _12;
        default:
            _739 <= _11;
        endcase
    end
    assign _675 = _660[827:796];
    assign _19 = _675;
    assign _676 = _660[699:668];
    assign _20 = _676;
    assign _677 = _660[571:540];
    assign _21 = _677;
    assign _678 = _660[443:412];
    assign _22 = _678;
    assign _679 = _660[315:284];
    assign _23 = _679;
    assign _729 = { _737,
                    _621 };
    assign _680 = _660[1011:996];
    assign _24 = _680;
    assign _727 = { _735,
                    _24 };
    assign _681 = _660[214:210];
    assign _25 = _681;
    assign _725 = { _733,
                    _25 };
    assign _722 = _297[30:0];
    assign _682 = _660[862:862];
    assign _26 = _682;
    assign _723 = { _26,
                    _722 };
    always @* begin
        case (_221)
        0:
            _730 <= _249;
        1:
            _730 <= _723;
        2:
            _730 <= _345;
        3:
            _730 <= _725;
        4:
            _730 <= _727;
        5:
            _730 <= _387;
        6:
            _730 <= _729;
        7:
            _730 <= _427;
        8:
            _730 <= _427;
        9:
            _730 <= _427;
        10:
            _730 <= _427;
        11:
            _730 <= _23;
        12:
            _730 <= _22;
        13:
            _730 <= _21;
        14:
            _730 <= _20;
        default:
            _730 <= _19;
        endcase
    end
    assign _683 = _660[795:764];
    assign _27 = _683;
    assign _684 = _660[667:636];
    assign _28 = _684;
    assign _685 = _660[539:508];
    assign _29 = _685;
    assign _686 = _660[411:380];
    assign _30 = _686;
    assign _687 = _660[283:252];
    assign _31 = _687;
    assign _720 = { _737,
                    _608 };
    assign _688 = _660[995:980];
    assign _32 = _688;
    assign _718 = { _735,
                    _32 };
    assign _689 = _660[209:205];
    assign _33 = _689;
    assign _716 = { _733,
                    _33 };
    assign _713 = _285[30:0];
    assign _690 = _660[861:861];
    assign _34 = _690;
    assign _714 = { _34,
                    _713 };
    always @* begin
        case (_221)
        0:
            _721 <= _237;
        1:
            _721 <= _714;
        2:
            _721 <= _333;
        3:
            _721 <= _716;
        4:
            _721 <= _718;
        5:
            _721 <= _377;
        6:
            _721 <= _720;
        7:
            _721 <= _427;
        8:
            _721 <= _427;
        9:
            _721 <= _427;
        10:
            _721 <= _427;
        11:
            _721 <= _31;
        12:
            _721 <= _30;
        13:
            _721 <= _29;
        14:
            _721 <= _28;
        default:
            _721 <= _27;
        endcase
    end
    assign _691 = _660[763:732];
    assign _35 = _691;
    assign _692 = _660[635:604];
    assign _36 = _692;
    assign _693 = _660[507:476];
    assign _37 = _693;
    assign _694 = _660[379:348];
    assign _38 = _694;
    assign _695 = _660[251:220];
    assign _39 = _695;
    assign _711 = { _737,
                    _595 };
    assign _696 = _660[979:964];
    assign _40 = _696;
    assign _709 = { _735,
                    _40 };
    assign _697 = _660[204:200];
    assign _41 = _697;
    assign _707 = { _733,
                    _41 };
    assign _704 = _273[30:0];
    assign _654 = 2'b00;
    assign _655 = _551 == _654;
    assign _652 = _556 & _560;
    assign _653 = _652 & _569;
    assign _656 = _653 & _655;
    assign _649 = 2'b01;
    assign _650 = _551 == _649;
    assign _647 = _556 & _560;
    assign _648 = _647 & _569;
    assign _651 = _648 & _650;
    assign _644 = 2'b10;
    assign _645 = _551 == _644;
    assign _642 = _556 & _560;
    assign _643 = _642 & _569;
    assign _646 = _643 & _645;
    assign _639 = 2'b11;
    assign _640 = _551 == _639;
    assign _637 = _556 & _560;
    assign _638 = _637 & _569;
    assign _641 = _638 & _640;
    assign _658 = { _748,
                    _641,
                    _646,
                    _651,
                    _656,
                    _752 };
    assign _631 = 4'b0110;
    assign _632 = _221 == _631;
    assign _629 = _217 == _639;
    assign _627 = _132 & _215;
    assign _630 = _627 & _629;
    assign _633 = _630 & _632;
    assign _626 = 1'b0;
    assign _624 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _634 <= _626;
        else
            if (_633)
                _634 <= _624;
    end
    assign _635 = { _737,
                    _634 };
    assign _619 = _221 == _631;
    assign _616 = _217 == _644;
    assign _614 = _132 & _215;
    assign _617 = _614 & _616;
    assign _620 = _617 & _619;
    assign _611 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _621 <= _626;
        else
            if (_620)
                _621 <= _611;
    end
    assign _622 = { _737,
                    _621 };
    assign _606 = _221 == _631;
    assign _603 = _217 == _649;
    assign _601 = _132 & _215;
    assign _604 = _601 & _603;
    assign _607 = _604 & _606;
    assign _598 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _608 <= _626;
        else
            if (_607)
                _608 <= _598;
    end
    assign _609 = { _737,
                    _608 };
    assign _593 = _221 == _631;
    assign _590 = _217 == _654;
    assign _588 = _132 & _215;
    assign _591 = _588 & _590;
    assign _594 = _591 & _593;
    assign _585 = _71[0:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _595 <= _626;
        else
            if (_594)
                _595 <= _585;
    end
    assign _596 = { _737,
                    _595 };
    assign _583 = _71[15:0];
    assign _580 = _160[8:8];
    assign _577 = _160[9:9];
    assign _578 = ~ _577;
    assign _579 = _163 & _578;
    assign _581 = _579 & _580;
    assign _582 = _581 & _132;
    assign _576 = _71[15:0];
    assign _573 = 4'b0100;
    assign _574 = _221 == _573;
    assign _572 = _132 & _215;
    assign _575 = _572 & _574;
    assign _565 = _42[11:11];
    assign _564 = _42[10:10];
    assign _563 = _42[9:9];
    assign _698 = _660[135:104];
    assign _42 = _698;
    assign _562 = _42[8:8];
    always @* begin
        case (_551)
        0:
            _566 <= _562;
        1:
            _566 <= _563;
        2:
            _566 <= _564;
        default:
            _566 <= _565;
        endcase
    end
    always @(posedge _55) begin
        if (_415)
            _569 <= _566;
    end
    assign _570 = ~ _569;
    assign _558 = 4'b0101;
    assign _557 = _171[5:2];
    assign _559 = _557 == _558;
    assign _560 = _169 & _559;
    assign _554 = 5'b01000;
    assign _555 = _123 == _554;
    assign _552 = _94 & _104;
    assign _553 = _552 & _127;
    assign _556 = _553 & _555;
    assign _561 = _556 & _560;
    assign _571 = _561 & _570;
    assign _551 = _171[1:0];
    assign _547 = _171[5:2];
    assign _549 = _547 == _573;
    assign _546 = _132 & _169;
    assign _550 = _546 & _549;
    assign _541 = 6'b000100;
    assign _542 = _171 == _541;
    assign _540 = _132 & _169;
    assign _543 = _540 & _542;
    assign _545 = _543 ? _71 : _427;
    assign _538 = _71[7:0];
    assign _534 = 6'b000111;
    assign _535 = _171 == _534;
    assign _533 = _132 & _169;
    assign _536 = _533 & _535;
    assign _539 = _536 ? _538 : _752;
    assign _531 = _71[7:0];
    assign _527 = 6'b000110;
    assign _528 = _171 == _527;
    assign _526 = _132 & _169;
    assign _529 = _526 & _528;
    assign _532 = _529 ? _531 : _752;
    assign _521 = _321[31:30];
    assign _520 = _71[31:30];
    assign _522 = _520 == _521;
    assign _523 = ~ _522;
    assign _517 = 4'b0010;
    assign _518 = _221 == _517;
    assign _515 = _217 == _654;
    assign _513 = _132 & _215;
    assign _516 = _513 & _515;
    assign _519 = _516 & _518;
    assign _524 = _519 & _523;
    assign _509 = _333[31:30];
    assign _508 = _71[31:30];
    assign _510 = _508 == _509;
    assign _511 = ~ _510;
    assign _506 = _221 == _517;
    assign _503 = _217 == _649;
    assign _501 = _132 & _215;
    assign _504 = _501 & _503;
    assign _507 = _504 & _506;
    assign _512 = _507 & _511;
    assign _497 = _345[31:30];
    assign _496 = _71[31:30];
    assign _498 = _496 == _497;
    assign _499 = ~ _498;
    assign _494 = _221 == _517;
    assign _491 = _217 == _644;
    assign _489 = _132 & _215;
    assign _492 = _489 & _491;
    assign _495 = _492 & _494;
    assign _500 = _495 & _499;
    assign _485 = _357[31:30];
    assign _484 = _71[31:30];
    assign _486 = _484 == _485;
    assign _487 = ~ _486;
    assign _482 = _221 == _517;
    assign _479 = _217 == _639;
    assign _477 = _132 & _215;
    assign _480 = _477 & _479;
    assign _483 = _480 & _482;
    assign _488 = _483 & _487;
    assign _525 = { _488,
                    _500,
                    _512,
                    _524 };
    assign _474 = _71[8:8];
    assign _475 = _458 & _474;
    assign _472 = _71[9:9];
    assign _473 = _458 & _472;
    assign _470 = _71[10:10];
    assign _471 = _458 & _470;
    assign _468 = _71[11:11];
    assign _469 = _458 & _468;
    assign _476 = { _469,
                    _471,
                    _473,
                    _475 };
    assign _465 = _71[4:4];
    assign _466 = _458 & _465;
    assign _463 = _71[5:5];
    assign _464 = _458 & _463;
    assign _461 = _71[6:6];
    assign _462 = _458 & _461;
    assign _459 = _71[7:7];
    assign _456 = 6'b000010;
    assign _457 = _171 == _456;
    assign _455 = _132 & _169;
    assign _458 = _455 & _457;
    assign _460 = _458 & _459;
    assign _467 = { _460,
                    _462,
                    _464,
                    _466 };
    assign _44 = uio_in;
    assign _454 = { _752,
                    _57,
                    _453,
                    _44 };
    assign _403 = 6'b001010;
    assign _404 = _171 == _403;
    assign _402 = _132 & _169;
    assign _405 = _402 & _404;
    assign _399 = _71[23:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _406 <= _423;
        else
            if (_405)
                _406 <= _399;
    end
    assign _407 = { _752,
                    _406 };
    assign _395 = _221 == _558;
    assign _392 = _217 == _639;
    assign _390 = _132 & _215;
    assign _393 = _390 & _392;
    assign _396 = _393 & _395;
    assign _388 = 32'b00010100000000000000000000000000;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _397 <= _388;
        else
            if (_396)
                _397 <= _71;
    end
    assign _385 = _221 == _558;
    assign _382 = _217 == _644;
    assign _380 = _132 & _215;
    assign _383 = _380 & _382;
    assign _386 = _383 & _385;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _387 <= _388;
        else
            if (_386)
                _387 <= _71;
    end
    assign _375 = _221 == _558;
    assign _372 = _217 == _649;
    assign _370 = _132 & _215;
    assign _373 = _370 & _372;
    assign _376 = _373 & _375;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _377 <= _388;
        else
            if (_376)
                _377 <= _71;
    end
    assign _365 = _221 == _558;
    assign _362 = _217 == _654;
    assign _360 = _132 & _215;
    assign _363 = _360 & _362;
    assign _366 = _363 & _365;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _367 <= _388;
        else
            if (_366)
                _367 <= _71;
    end
    assign _355 = _221 == _517;
    assign _352 = _217 == _639;
    assign _350 = _132 & _215;
    assign _353 = _350 & _352;
    assign _356 = _353 & _355;
    assign _348 = 32'b00000000000011000000000000000000;
    assign _346 = 32'b11111111111111110000000000000000;
    assign _347 = _71 & _346;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _357 <= _348;
        else
            if (_356)
                _357 <= _347;
    end
    assign _343 = _221 == _517;
    assign _340 = _217 == _644;
    assign _338 = _132 & _215;
    assign _341 = _338 & _340;
    assign _344 = _341 & _343;
    assign _335 = _71 & _346;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _345 <= _348;
        else
            if (_344)
                _345 <= _335;
    end
    assign _331 = _221 == _517;
    assign _328 = _217 == _649;
    assign _326 = _132 & _215;
    assign _329 = _326 & _328;
    assign _332 = _329 & _331;
    assign _323 = _71 & _346;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _333 <= _348;
        else
            if (_332)
                _333 <= _323;
    end
    assign _319 = _221 == _517;
    assign _316 = _217 == _654;
    assign _314 = _132 & _215;
    assign _317 = _314 & _316;
    assign _320 = _317 & _319;
    assign _311 = _71 & _346;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _321 <= _348;
        else
            if (_320)
                _321 <= _311;
    end
    assign _306 = 4'b0001;
    assign _307 = _221 == _306;
    assign _304 = _217 == _639;
    assign _302 = _132 & _215;
    assign _305 = _302 & _304;
    assign _308 = _305 & _307;
    assign _300 = 32'b00000000000000011111000000000000;
    assign _298 = 32'b01111111111111111111111110011111;
    assign _299 = _71 & _298;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _309 <= _300;
        else
            if (_308)
                _309 <= _299;
    end
    assign _295 = _221 == _306;
    assign _292 = _217 == _644;
    assign _290 = _132 & _215;
    assign _293 = _290 & _292;
    assign _296 = _293 & _295;
    assign _287 = _71 & _298;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _297 <= _300;
        else
            if (_296)
                _297 <= _287;
    end
    assign _283 = _221 == _306;
    assign _280 = _217 == _649;
    assign _278 = _132 & _215;
    assign _281 = _278 & _280;
    assign _284 = _281 & _283;
    assign _275 = _71 & _298;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _285 <= _300;
        else
            if (_284)
                _285 <= _275;
    end
    assign _271 = _221 == _306;
    assign _268 = _217 == _654;
    assign _266 = _132 & _215;
    assign _269 = _266 & _268;
    assign _272 = _269 & _271;
    assign _263 = _71 & _298;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _273 <= _300;
        else
            if (_272)
                _273 <= _263;
    end
    assign _258 = 4'b0000;
    assign _259 = _221 == _258;
    assign _256 = _217 == _639;
    assign _254 = _132 & _215;
    assign _257 = _254 & _256;
    assign _260 = _257 & _259;
    assign _252 = 32'b00000000000000010000000000000000;
    assign _250 = 32'b11111111111111111111111100000000;
    assign _251 = _71 & _250;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _261 <= _252;
        else
            if (_260)
                _261 <= _251;
    end
    assign _247 = _221 == _258;
    assign _244 = _217 == _644;
    assign _242 = _132 & _215;
    assign _245 = _242 & _244;
    assign _248 = _245 & _247;
    assign _239 = _71 & _250;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _249 <= _252;
        else
            if (_248)
                _249 <= _239;
    end
    assign _235 = _221 == _258;
    assign _232 = _217 == _649;
    assign _230 = _132 & _215;
    assign _233 = _230 & _232;
    assign _236 = _233 & _235;
    assign _227 = _71 & _250;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _237 <= _252;
        else
            if (_236)
                _237 <= _227;
    end
    assign _171 = _160[7:2];
    assign _204 = _171 == _456;
    assign _202 = _132 & _169;
    assign _205 = _202 & _204;
    assign _199 = _71[3:0];
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _206 <= _258;
        else
            if (_205)
                _206 <= _199;
    end
    pio_block
        pio_block
        ( .clock(_55),
          .rst_n(core_rst_n),
          .sm_enable(_206),
          .clkdiv0(_225),
          .clkdiv1(_237),
          .clkdiv2(_249),
          .clkdiv3(_261),
          .execctrl0(_273),
          .execctrl1(_285),
          .execctrl2(_297),
          .execctrl3(_309),
          .shiftctrl0(_321),
          .shiftctrl1(_333),
          .shiftctrl2(_345),
          .shiftctrl3(_357),
          .pinctrl0(_367),
          .pinctrl1(_377),
          .pinctrl2(_387),
          .pinctrl3(_397),
          .sync_bypass(_407),
          .pins_in(_454),
          .sm_restart(_467),
          .clkdiv_restart(_476),
          .fifo_flush(_525),
          .irq_clear(_532),
          .irq_force(_539),
          .fdebug_clear(_545),
          .txf_push(_550),
          .txf_sm(_551),
          .txf_data(_71),
          .rxf_pop(_571),
          .rxf_sm(_551),
          .instr_write(_575),
          .instr_sm(_217),
          .instr_data(_576),
          .imem_write(_582),
          .imem_addr(_171),
          .imem_data(_583),
          .ext0(_596),
          .ext1(_609),
          .ext2(_622),
          .ext3(_635),
          .fdebug_set(_658),
          .dbg_instr3(_660[1027:1012]),
          .dbg_instr2(_660[1011:996]),
          .dbg_instr1(_660[995:980]),
          .dbg_instr0(_660[979:964]),
          .dbg_phase3(_660[963:939]),
          .dbg_phase2(_660[938:914]),
          .dbg_phase1(_660[913:889]),
          .dbg_phase0(_660[888:864]),
          .dbg_exec_stalled3(_660[863:863]),
          .dbg_exec_stalled2(_660[862:862]),
          .dbg_exec_stalled1(_660[861:861]),
          .dbg_exec_stalled0(_660[860:860]),
          .dbg_cnt3(_660[859:828]),
          .dbg_cnt2(_660[827:796]),
          .dbg_cnt1(_660[795:764]),
          .dbg_cnt0(_660[763:732]),
          .dbg_osr3(_660[731:700]),
          .dbg_osr2(_660[699:668]),
          .dbg_osr1(_660[667:636]),
          .dbg_osr0(_660[635:604]),
          .dbg_isr3(_660[603:572]),
          .dbg_isr2(_660[571:540]),
          .dbg_isr1(_660[539:508]),
          .dbg_isr0(_660[507:476]),
          .dbg_y3(_660[475:444]),
          .dbg_y2(_660[443:412]),
          .dbg_y1(_660[411:380]),
          .dbg_y0(_660[379:348]),
          .dbg_x3(_660[347:316]),
          .dbg_x2(_660[315:284]),
          .dbg_x1(_660[283:252]),
          .dbg_x0(_660[251:220]),
          .dbg_pc3(_660[219:215]),
          .dbg_pc2(_660[214:210]),
          .dbg_pc1(_660[209:205]),
          .dbg_pc0(_660[204:200]),
          .fdebug(_660[199:168]),
          .flevel(_660[167:136]),
          .fstat(_660[135:104]),
          .rxf_data(_660[103:72]),
          .irq(_660[71:64]),
          .pins_oe(_660[63:32]),
          .pins_out(_660[31:0]) );
    assign _699 = _660[860:860];
    assign _45 = _699;
    assign _705 = { _45,
                    _704 };
    assign _223 = _221 == _258;
    assign _219 = _217 == _654;
    assign _130 = 5'b11111;
    assign _131 = _123 == _130;
    assign _128 = ~ _127;
    assign _105 = _94 & _104;
    assign _129 = _105 & _128;
    assign _132 = _129 & _131;
    assign _216 = _132 & _215;
    assign _220 = _216 & _219;
    assign _224 = _220 & _223;
    assign _208 = _71 & _250;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _225 <= _252;
        else
            if (_224)
                _225 <= _208;
    end
    assign _221 = _160[5:2];
    always @* begin
        case (_221)
        0:
            _712 <= _225;
        1:
            _712 <= _705;
        2:
            _712 <= _321;
        3:
            _712 <= _707;
        4:
            _712 <= _709;
        5:
            _712 <= _367;
        6:
            _712 <= _711;
        7:
            _712 <= _427;
        8:
            _712 <= _427;
        9:
            _712 <= _427;
        10:
            _712 <= _427;
        11:
            _712 <= _39;
        12:
            _712 <= _38;
        13:
            _712 <= _37;
        14:
            _712 <= _36;
        default:
            _712 <= _35;
        endcase
    end
    assign _217 = _160[7:6];
    always @* begin
        case (_217)
        0:
            _740 <= _712;
        1:
            _740 <= _721;
        2:
            _740 <= _730;
        default:
            _740 <= _739;
        endcase
    end
    assign _213 = _160[8:8];
    assign _214 = ~ _213;
    assign _211 = _160[9:9];
    assign _212 = _163 & _211;
    assign _215 = _212 & _214;
    assign _741 = _215 ? _740 : _427;
    assign _167 = _160[8:8];
    assign _168 = ~ _167;
    assign _164 = _160[9:9];
    assign _165 = ~ _164;
    assign _162 = 6'b000000;
    assign _700 = _71[30:0];
    always @(posedge _55) begin
        if (_94)
            _703 <= _700;
    end
    assign _46 = _703;
    assign _71 = { _46,
                   _70 };
    assign _154 = _71[15:2];
    assign _156 = { _154,
                    _654 };
    assign _151 = 16'b0000000000000100;
    assign _152 = _47 + _151;
    assign _47 = _160;
    assign _145 = 5'b00001;
    assign _146 = _123 == _145;
    assign _143 = ~ _104;
    assign _144 = _94 & _143;
    assign _147 = _144 & _146;
    always @(posedge _55) begin
        if (_147)
            _148 <= _70;
    end
    assign _149 = ~ _148;
    assign _138 = _123 == _554;
    assign _136 = _123 == _130;
    assign _139 = _127 ? _138 : _136;
    assign _134 = _94 & _104;
    assign _140 = _134 & _139;
    assign _150 = _140 & _149;
    assign _153 = _150 ? _152 : _47;
    assign _133 = _94 & _113;
    assign _157 = _133 ? _156 : _153;
    always @(posedge _55) begin
        _160 <= _157;
    end
    assign _161 = _160[15:10];
    assign _163 = _161 == _162;
    assign _166 = _163 & _165;
    assign _169 = _166 & _168;
    assign _762 = _169 ? _761 : _741;
    assign _48 = _762;
    assign _416 = _51[30:0];
    assign _418 = { _416,
                    _626 };
    assign _413 = 5'b00111;
    assign _414 = _123 == _413;
    assign _124 = 5'b00000;
    assign _125 = _123 == _124;
    assign _108 = ~ _104;
    assign _109 = _94 & _108;
    assign _126 = _109 & _125;
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
    always @(posedge _55) begin
        if (_126)
            _127 <= _70;
    end
    assign _98 = 5'b10111;
    assign _115 = _49 + _145;
    assign _112 = _49 == _98;
    assign _110 = ~ _50;
    assign _113 = _110 & _112;
    assign _117 = _113 ? _124 : _115;
    assign _118 = _94 ? _117 : _49;
    assign _120 = _96 ? _124 : _118;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _123 <= _124;
        else
            _123 <= _120;
    end
    assign _49 = _123;
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
    assign _411 = _94 & _104;
    assign _412 = _411 & _127;
    assign _415 = _412 & _414;
    assign _419 = _415 ? _48 : _418;
    assign _51 = _428;
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
    assign _420 = _94 ? _419 : _51;
    assign _409 = ~ _92;
    assign _410 = _88 & _409;
    assign _422 = _410 ? _427 : _420;
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
    assign _425 = _96 ? _424 : _422;
    always @(posedge _55 or negedge core_rst_n) begin
        if (core_rst_n == 0)
            _428 <= _427;
        else
            _428 <= _425;
    end
    assign _429 = _428[31:31];
    assign _453 = { _429,
                    _451,
                    _452 };
    assign uo_out = _453;
    assign uio_out = _181;
    assign uio_oe = _179;

endmodule
