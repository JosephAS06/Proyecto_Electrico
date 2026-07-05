// ----------------------------------------------------------------------------------------------------------------------------------------------
// -- File Name        : sram.sv
// -- Module Name      : idmem                                         
// -- Developer        : David Rodriguez, Kristhel Quesada
// --
// -- Description      : This module describes a basic implementation on the data/instruction SRAM
// --
// -- Tested on        : 
// -- Last modified on : October-2024
// -- Notes            : 
// --                  
// -- Copyright        : Refer to LICENSE.md.
// ----------------------------------------------------------------------------------------------------------------------------------------------


// module icache #(                                 // For a default size of 2^32x32
//     parameter ADDR_WIDTH = 32,                   // Default value of address width
//     parameter DATA_WIDTH = 32                    // Default value of data width (word)
// )(
//     input wire clk, i_we,                        // Clock and WriteEnable
//     input wire [ADDR_WIDTH-1:0] i_tester_addr,   // Address to be accessed
//     input wire [ADDR_WIDTH-1:0] i_addr,          // Address to be accessed
//     input wire [DATA_WIDTH-1:0] i_wdata,         // Data to be written
//     output reg [DATA_WIDTH-1:0] o_instr          // Data to be read
// );

//     // Matrix based definition of SRAM memory
//     reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];       // 0 address corresponds to index 0
//     //reg [DATA_WIDTH-1:0] mem [(1 << ADDR_WIDTH)-1: 0];    // 0 address corresponds to index 4096

//     always @(posedge clk) begin
//         if (i_we) mem[i_tester_addr] <= i_wdata;      // Write on memory
//         else o_instr <= mem[i_addr];                  // Read from memory
//     end

// endmodule

module icache #(
     parameter ADDR_WIDTH = 32,                   // Default value of address width
     parameter DATA_WIDTH = 32                    // Default value of data width (word)
    
)(    
    input wire CLK, rst, i_we,                   // Clock and WriteEnable
    input wire [ADDR_WIDTH-1:0] i_tester_addr,   // Address to be accessed
    input wire [ADDR_WIDTH-1:0] i_addr,          // Address to be accessed
    input wire [ADDR_WIDTH-1:0] i_pc,            // PC to buffer coming from the FU
    input wire [DATA_WIDTH-1:0] i_wdata,         // Data to be written
    output reg [DATA_WIDTH-1:0] o_instr,          // Data to be read
    output reg [ADDR_WIDTH-1:0] o_pc             // PC to buffer going back to the FU
);

// Definition of registers to save the instructions
    reg [DATA_WIDTH-1:0] pos0;
    reg [DATA_WIDTH-1:0] pos1;
    reg [DATA_WIDTH-1:0] pos2;
    reg [DATA_WIDTH-1:0] pos3;
    reg [DATA_WIDTH-1:0] pos4;
    reg [DATA_WIDTH-1:0] pos5;
    reg [DATA_WIDTH-1:0] pos6;
    reg [DATA_WIDTH-1:0] pos7;
    reg [DATA_WIDTH-1:0] pos8;
    reg [DATA_WIDTH-1:0] pos9;

    reg [DATA_WIDTH-1:0] pos10;
    reg [DATA_WIDTH-1:0] pos11;
    reg [DATA_WIDTH-1:0] pos12;
    reg [DATA_WIDTH-1:0] pos13;
    reg [DATA_WIDTH-1:0] pos14;
    reg [DATA_WIDTH-1:0] pos15;
    reg [DATA_WIDTH-1:0] pos16;
    reg [DATA_WIDTH-1:0] pos17;
    reg [DATA_WIDTH-1:0] pos18;
    reg [DATA_WIDTH-1:0] pos19;

    reg [DATA_WIDTH-1:0] pos20;
    reg [DATA_WIDTH-1:0] pos21;
    reg [DATA_WIDTH-1:0] pos22;
    reg [DATA_WIDTH-1:0] pos23;
    reg [DATA_WIDTH-1:0] pos24;
    reg [DATA_WIDTH-1:0] pos25;
    reg [DATA_WIDTH-1:0] pos26;
    reg [DATA_WIDTH-1:0] pos27;
    reg [DATA_WIDTH-1:0] pos28;
    reg [DATA_WIDTH-1:0] pos29;

    reg [DATA_WIDTH-1:0] pos30;
    reg [DATA_WIDTH-1:0] pos31;
    reg [DATA_WIDTH-1:0] pos32;
    reg [DATA_WIDTH-1:0] pos33;
    reg [DATA_WIDTH-1:0] pos34;
    reg [DATA_WIDTH-1:0] pos35;
    reg [DATA_WIDTH-1:0] pos36;
    reg [DATA_WIDTH-1:0] pos37;
    reg [DATA_WIDTH-1:0] pos38;
    reg [DATA_WIDTH-1:0] pos39;

    reg [DATA_WIDTH-1:0] pos40;
    reg [DATA_WIDTH-1:0] pos41;
    reg [DATA_WIDTH-1:0] pos42;
    reg [DATA_WIDTH-1:0] pos43;
    reg [DATA_WIDTH-1:0] pos44;
    reg [DATA_WIDTH-1:0] pos45;
    reg [DATA_WIDTH-1:0] pos46;
    reg [DATA_WIDTH-1:0] pos47;
    reg [DATA_WIDTH-1:0] pos48;
    reg [DATA_WIDTH-1:0] pos49;

    reg [DATA_WIDTH-1:0] pos50;
    reg [DATA_WIDTH-1:0] pos51;
    reg [DATA_WIDTH-1:0] pos52;
    reg [DATA_WIDTH-1:0] pos53;
    reg [DATA_WIDTH-1:0] pos54;
    reg [DATA_WIDTH-1:0] pos55;
    reg [DATA_WIDTH-1:0] pos56;
    reg [DATA_WIDTH-1:0] pos57;
    reg [DATA_WIDTH-1:0] pos58;
    reg [DATA_WIDTH-1:0] pos59;

    reg [DATA_WIDTH-1:0] pos60;
    reg [DATA_WIDTH-1:0] pos61;
    reg [DATA_WIDTH-1:0] pos62;
    reg [DATA_WIDTH-1:0] pos63;
    reg [DATA_WIDTH-1:0] pos64;
    reg [DATA_WIDTH-1:0] pos65;
    reg [DATA_WIDTH-1:0] pos66;
    reg [DATA_WIDTH-1:0] pos67;
    reg [DATA_WIDTH-1:0] pos68;
    reg [DATA_WIDTH-1:0] pos69;

    reg [DATA_WIDTH-1:0] pos70;
    reg [DATA_WIDTH-1:0] pos71;
    reg [DATA_WIDTH-1:0] pos72;
    reg [DATA_WIDTH-1:0] pos73;
    reg [DATA_WIDTH-1:0] pos74;
    reg [DATA_WIDTH-1:0] pos75;
    reg [DATA_WIDTH-1:0] pos76;
    reg [DATA_WIDTH-1:0] pos77;
    reg [DATA_WIDTH-1:0] pos78;
    reg [DATA_WIDTH-1:0] pos79;

    reg [DATA_WIDTH-1:0] pos80;
    reg [DATA_WIDTH-1:0] pos81;
    reg [DATA_WIDTH-1:0] pos82;
    reg [DATA_WIDTH-1:0] pos83;
    reg [DATA_WIDTH-1:0] pos84;
    reg [DATA_WIDTH-1:0] pos85;
    reg [DATA_WIDTH-1:0] pos86;
    reg [DATA_WIDTH-1:0] pos87;
    reg [DATA_WIDTH-1:0] pos88;
    reg [DATA_WIDTH-1:0] pos89;

    reg [DATA_WIDTH-1:0] pos90;
    reg [DATA_WIDTH-1:0] pos91;
    reg [DATA_WIDTH-1:0] pos92;
    reg [DATA_WIDTH-1:0] pos93;
    reg [DATA_WIDTH-1:0] pos94;
    reg [DATA_WIDTH-1:0] pos95;
    reg [DATA_WIDTH-1:0] pos96;
    reg [DATA_WIDTH-1:0] pos97;
    reg [DATA_WIDTH-1:0] pos98;
    reg [DATA_WIDTH-1:0] pos99;

    reg [DATA_WIDTH-1:0] pos100;
    reg [DATA_WIDTH-1:0] pos101;
    reg [DATA_WIDTH-1:0] pos102;
    reg [DATA_WIDTH-1:0] pos103;
    reg [DATA_WIDTH-1:0] pos104;
    reg [DATA_WIDTH-1:0] pos105;
    reg [DATA_WIDTH-1:0] pos106;
    reg [DATA_WIDTH-1:0] pos107;
    reg [DATA_WIDTH-1:0] pos108;
    reg [DATA_WIDTH-1:0] pos109;

    reg [DATA_WIDTH-1:0] pos110;
    reg [DATA_WIDTH-1:0] pos111;
    reg [DATA_WIDTH-1:0] pos112;
    reg [DATA_WIDTH-1:0] pos113;
    reg [DATA_WIDTH-1:0] pos114;
    reg [DATA_WIDTH-1:0] pos115;
    reg [DATA_WIDTH-1:0] pos116;
    reg [DATA_WIDTH-1:0] pos117;
    reg [DATA_WIDTH-1:0] pos118;
    reg [DATA_WIDTH-1:0] pos119;

    reg [DATA_WIDTH-1:0] pos120;
    reg [DATA_WIDTH-1:0] pos121;
    reg [DATA_WIDTH-1:0] pos122;
    reg [DATA_WIDTH-1:0] pos123;
    reg [DATA_WIDTH-1:0] pos124;
    reg [DATA_WIDTH-1:0] pos125;
    reg [DATA_WIDTH-1:0] pos126;
    reg [DATA_WIDTH-1:0] pos127;
    reg [DATA_WIDTH-1:0] pos128;
    reg [DATA_WIDTH-1:0] pos129;

    reg [DATA_WIDTH-1:0] pos130;
    reg [DATA_WIDTH-1:0] pos131;
    reg [DATA_WIDTH-1:0] pos132;
    reg [DATA_WIDTH-1:0] pos133;
    reg [DATA_WIDTH-1:0] pos134;
    reg [DATA_WIDTH-1:0] pos135;
    reg [DATA_WIDTH-1:0] pos136;
    reg [DATA_WIDTH-1:0] pos137;
    reg [DATA_WIDTH-1:0] pos138;
    reg [DATA_WIDTH-1:0] pos139;

    reg [DATA_WIDTH-1:0] pos140;
    reg [DATA_WIDTH-1:0] pos141;
    reg [DATA_WIDTH-1:0] pos142;
    reg [DATA_WIDTH-1:0] pos143;
    reg [DATA_WIDTH-1:0] pos144;
    reg [DATA_WIDTH-1:0] pos145;
    reg [DATA_WIDTH-1:0] pos146;
    reg [DATA_WIDTH-1:0] pos147;
    reg [DATA_WIDTH-1:0] pos148;
    reg [DATA_WIDTH-1:0] pos149;

    reg [DATA_WIDTH-1:0] pos150;
    reg [DATA_WIDTH-1:0] pos151;
    reg [DATA_WIDTH-1:0] pos152;
    reg [DATA_WIDTH-1:0] pos153;
    reg [DATA_WIDTH-1:0] pos154;
    reg [DATA_WIDTH-1:0] pos155;
    reg [DATA_WIDTH-1:0] pos156;
    reg [DATA_WIDTH-1:0] pos157;
    reg [DATA_WIDTH-1:0] pos158;
    reg [DATA_WIDTH-1:0] pos159;

    reg [DATA_WIDTH-1:0] pos160;
    reg [DATA_WIDTH-1:0] pos161;
    reg [DATA_WIDTH-1:0] pos162;
    reg [DATA_WIDTH-1:0] pos163;
    reg [DATA_WIDTH-1:0] pos164;
    reg [DATA_WIDTH-1:0] pos165;
    reg [DATA_WIDTH-1:0] pos166;
    reg [DATA_WIDTH-1:0] pos167;
    reg [DATA_WIDTH-1:0] pos168;
    reg [DATA_WIDTH-1:0] pos169;

    reg [DATA_WIDTH-1:0] pos170;
    reg [DATA_WIDTH-1:0] pos171;
    reg [DATA_WIDTH-1:0] pos172;
    reg [DATA_WIDTH-1:0] pos173;
    reg [DATA_WIDTH-1:0] pos174;
    reg [DATA_WIDTH-1:0] pos175;
    reg [DATA_WIDTH-1:0] pos176;
    reg [DATA_WIDTH-1:0] pos177;
    reg [DATA_WIDTH-1:0] pos178;
    reg [DATA_WIDTH-1:0] pos179;

    reg [DATA_WIDTH-1:0] pos180;
    reg [DATA_WIDTH-1:0] pos181;
    reg [DATA_WIDTH-1:0] pos182;
    reg [DATA_WIDTH-1:0] pos183;
    reg [DATA_WIDTH-1:0] pos184;
    reg [DATA_WIDTH-1:0] pos185;
    reg [DATA_WIDTH-1:0] pos186;
    reg [DATA_WIDTH-1:0] pos187;
    reg [DATA_WIDTH-1:0] pos188;
    reg [DATA_WIDTH-1:0] pos189;

    reg [DATA_WIDTH-1:0] pos190;
    reg [DATA_WIDTH-1:0] pos191;
    reg [DATA_WIDTH-1:0] pos192;
    reg [DATA_WIDTH-1:0] pos193;
    reg [DATA_WIDTH-1:0] pos194;
    reg [DATA_WIDTH-1:0] pos195;
    reg [DATA_WIDTH-1:0] pos196;
    reg [DATA_WIDTH-1:0] pos197;
    reg [DATA_WIDTH-1:0] pos198;
    reg [DATA_WIDTH-1:0] pos199;

    reg [DATA_WIDTH-1:0] pos200;
    reg [DATA_WIDTH-1:0] pos201;
    reg [DATA_WIDTH-1:0] pos202;
    reg [DATA_WIDTH-1:0] pos203;
    reg [DATA_WIDTH-1:0] pos204;
    reg [DATA_WIDTH-1:0] pos205;
    reg [DATA_WIDTH-1:0] pos206;
    reg [DATA_WIDTH-1:0] pos207;
    reg [DATA_WIDTH-1:0] pos208;
    reg [DATA_WIDTH-1:0] pos209;

    reg [DATA_WIDTH-1:0] pos210;
    reg [DATA_WIDTH-1:0] pos211;
    reg [DATA_WIDTH-1:0] pos212;
    reg [DATA_WIDTH-1:0] pos213;
    reg [DATA_WIDTH-1:0] pos214;
    reg [DATA_WIDTH-1:0] pos215;
    reg [DATA_WIDTH-1:0] pos216;
    reg [DATA_WIDTH-1:0] pos217;
    reg [DATA_WIDTH-1:0] pos218;
    reg [DATA_WIDTH-1:0] pos219;

    reg [DATA_WIDTH-1:0] pos220;
    reg [DATA_WIDTH-1:0] pos221;
    reg [DATA_WIDTH-1:0] pos222;
    reg [DATA_WIDTH-1:0] pos223;
    reg [DATA_WIDTH-1:0] pos224;
    reg [DATA_WIDTH-1:0] pos225;
    reg [DATA_WIDTH-1:0] pos226;
    reg [DATA_WIDTH-1:0] pos227;
    reg [DATA_WIDTH-1:0] pos228;
    reg [DATA_WIDTH-1:0] pos229;

    reg [DATA_WIDTH-1:0] pos230;
    reg [DATA_WIDTH-1:0] pos231;
    reg [DATA_WIDTH-1:0] pos232;
    reg [DATA_WIDTH-1:0] pos233;
    reg [DATA_WIDTH-1:0] pos234;
    reg [DATA_WIDTH-1:0] pos235;
    reg [DATA_WIDTH-1:0] pos236;
    reg [DATA_WIDTH-1:0] pos237;
    reg [DATA_WIDTH-1:0] pos238;
    reg [DATA_WIDTH-1:0] pos239;

    reg [DATA_WIDTH-1:0] pos240;
    reg [DATA_WIDTH-1:0] pos241;
    reg [DATA_WIDTH-1:0] pos242;
    reg [DATA_WIDTH-1:0] pos243;
    reg [DATA_WIDTH-1:0] pos244;
    reg [DATA_WIDTH-1:0] pos245;
    reg [DATA_WIDTH-1:0] pos246;
    reg [DATA_WIDTH-1:0] pos247;
    reg [DATA_WIDTH-1:0] pos248;
    reg [DATA_WIDTH-1:0] pos249;

    reg [DATA_WIDTH-1:0] pos250;
    reg [DATA_WIDTH-1:0] pos251;
    reg [DATA_WIDTH-1:0] pos252;
    reg [DATA_WIDTH-1:0] pos253;
    reg [DATA_WIDTH-1:0] pos254;
    reg [DATA_WIDTH-1:0] pos255;
    reg [DATA_WIDTH-1:0] pos256;
    reg [DATA_WIDTH-1:0] pos257;
    reg [DATA_WIDTH-1:0] pos258;
    reg [DATA_WIDTH-1:0] pos259;

    reg [DATA_WIDTH-1:0] pos260;
    reg [DATA_WIDTH-1:0] pos261;
    reg [DATA_WIDTH-1:0] pos262;
    reg [DATA_WIDTH-1:0] pos263;
    reg [DATA_WIDTH-1:0] pos264;
    reg [DATA_WIDTH-1:0] pos265;
    reg [DATA_WIDTH-1:0] pos266;
    reg [DATA_WIDTH-1:0] pos267;
    reg [DATA_WIDTH-1:0] pos268;
    reg [DATA_WIDTH-1:0] pos269;

    reg [DATA_WIDTH-1:0] pos270;
    reg [DATA_WIDTH-1:0] pos271;
    reg [DATA_WIDTH-1:0] pos272;
    reg [DATA_WIDTH-1:0] pos273;
    reg [DATA_WIDTH-1:0] pos274;
    reg [DATA_WIDTH-1:0] pos275;
    reg [DATA_WIDTH-1:0] pos276;
    reg [DATA_WIDTH-1:0] pos277;
    reg [DATA_WIDTH-1:0] pos278;
    reg [DATA_WIDTH-1:0] pos279;

    reg [DATA_WIDTH-1:0] pos280;
    reg [DATA_WIDTH-1:0] pos281;
    reg [DATA_WIDTH-1:0] pos282;
    reg [DATA_WIDTH-1:0] pos283;
    reg [DATA_WIDTH-1:0] pos284;
    reg [DATA_WIDTH-1:0] pos285;
    reg [DATA_WIDTH-1:0] pos286;
    reg [DATA_WIDTH-1:0] pos287;
    reg [DATA_WIDTH-1:0] pos288;
    reg [DATA_WIDTH-1:0] pos289;

    reg [DATA_WIDTH-1:0] pos290;
    reg [DATA_WIDTH-1:0] pos291;
    reg [DATA_WIDTH-1:0] pos292;
    reg [DATA_WIDTH-1:0] pos293;
    reg [DATA_WIDTH-1:0] pos294;
    reg [DATA_WIDTH-1:0] pos295;
    reg [DATA_WIDTH-1:0] pos296;
    reg [DATA_WIDTH-1:0] pos297;
    reg [DATA_WIDTH-1:0] pos298;
    reg [DATA_WIDTH-1:0] pos299;

    reg [DATA_WIDTH-1:0] pos300;
    reg [DATA_WIDTH-1:0] pos301;
    reg [DATA_WIDTH-1:0] pos302;
    reg [DATA_WIDTH-1:0] pos303;
    reg [DATA_WIDTH-1:0] pos304;
    reg [DATA_WIDTH-1:0] pos305;
    reg [DATA_WIDTH-1:0] pos306;
    reg [DATA_WIDTH-1:0] pos307;
    reg [DATA_WIDTH-1:0] pos308;
    reg [DATA_WIDTH-1:0] pos309;

    always @(posedge CLK) begin
        
        if (rst) begin
            o_pc <= 0;    
        end else begin
            o_pc <= i_pc;
        end

        if (i_we) begin
            
            case (i_tester_addr)
                32'd0   :  pos0  <= i_wdata;
                32'd1   :  pos1  <= i_wdata;
                32'd2   :  pos2  <= i_wdata;
                32'd3   :  pos3  <= i_wdata;
                32'd4   :  pos4  <= i_wdata;
                32'd5   :  pos5  <= i_wdata;
                32'd6   :  pos6  <= i_wdata;
                32'd7   :  pos7  <= i_wdata;
                32'd8   :  pos8  <= i_wdata;
                32'd9   :  pos9  <= i_wdata;

                32'd10  :  pos10 <= i_wdata;
                32'd11  :  pos11  <= i_wdata;
                32'd12  :  pos12  <= i_wdata;
                32'd13  :  pos13  <= i_wdata;
                32'd14  :  pos14  <= i_wdata;
                32'd15  :  pos15  <= i_wdata;
                32'd16  :  pos16  <= i_wdata;
                32'd17  :  pos17  <= i_wdata;
                32'd18  :  pos18  <= i_wdata;
                32'd19  :  pos19  <= i_wdata;

                32'd20  :  pos20  <= i_wdata;
                32'd21  :  pos21  <= i_wdata;
                32'd22  :  pos22  <= i_wdata;
                32'd23  :  pos23  <= i_wdata;
                32'd24  :  pos24  <= i_wdata;
                32'd25  :  pos25  <= i_wdata;
                32'd26  :  pos26  <= i_wdata;
                32'd27  :  pos27  <= i_wdata;
                32'd28  :  pos28  <= i_wdata;
                32'd29  :  pos29  <= i_wdata;

                32'd30  :  pos30  <= i_wdata;
                32'd31  :  pos31  <= i_wdata;
                32'd32  :  pos32  <= i_wdata;
                32'd33  :  pos33  <= i_wdata;
                32'd34  :  pos34  <= i_wdata;
                32'd35  :  pos35  <= i_wdata;
                32'd36  :  pos36  <= i_wdata;
                32'd37  :  pos37  <= i_wdata;
                32'd38  :  pos38  <= i_wdata;
                32'd39  :  pos39  <= i_wdata;

                32'd40  :  pos40  <= i_wdata;
                32'd41  :  pos41  <= i_wdata;
                32'd42  :  pos42  <= i_wdata;
                32'd43  :  pos43  <= i_wdata;
                32'd44  :  pos44  <= i_wdata;
                32'd45  :  pos45  <= i_wdata;
                32'd46  :  pos46  <= i_wdata;
                32'd47  :  pos47  <= i_wdata;
                32'd48  :  pos48  <= i_wdata;
                32'd49  :  pos49  <= i_wdata;

                32'd50  :  pos50  <= i_wdata;
                32'd51  :  pos51  <= i_wdata;
                32'd52  :  pos52  <= i_wdata;
                32'd53  :  pos53  <= i_wdata;
                32'd54  :  pos54  <= i_wdata;
                32'd55  :  pos55  <= i_wdata;
                32'd56  :  pos56  <= i_wdata;
                32'd57  :  pos57  <= i_wdata;
                32'd58  :  pos58  <= i_wdata;
                32'd59  :  pos59  <= i_wdata;

                32'd60  :  pos60  <= i_wdata;
                32'd61  :  pos61  <= i_wdata;
                32'd62  :  pos62  <= i_wdata;
                32'd63  :  pos63  <= i_wdata;
                32'd64  :  pos64  <= i_wdata;
                32'd65  :  pos65  <= i_wdata;
                32'd66  :  pos66  <= i_wdata;
                32'd67  :  pos67  <= i_wdata;
                32'd68  :  pos68  <= i_wdata;
                32'd69  :  pos69  <= i_wdata;

                32'd70  :  pos70  <= i_wdata;
                32'd71  :  pos71  <= i_wdata;
                32'd72  :  pos72  <= i_wdata;
                32'd73  :  pos73  <= i_wdata;
                32'd74  :  pos74  <= i_wdata;
                32'd75  :  pos75  <= i_wdata;
                32'd76  :  pos76  <= i_wdata;
                32'd77  :  pos77  <= i_wdata;
                32'd78  :  pos78  <= i_wdata;
                32'd79  :  pos79  <= i_wdata;

                32'd80  :  pos80  <= i_wdata;
                32'd81  :  pos81  <= i_wdata;
                32'd82  :  pos82  <= i_wdata;
                32'd83  :  pos83  <= i_wdata;
                32'd84  :  pos84  <= i_wdata;
                32'd85  :  pos85  <= i_wdata;
                32'd86  :  pos86  <= i_wdata;
                32'd87  :  pos87  <= i_wdata;
                32'd88  :  pos88  <= i_wdata;
                32'd89  :  pos89  <= i_wdata;

                32'd90  :  pos90  <= i_wdata;
                32'd91  :  pos91  <= i_wdata;
                32'd92  :  pos92  <= i_wdata;
                32'd93  :  pos93  <= i_wdata;
                32'd94  :  pos94  <= i_wdata;
                32'd95  :  pos95  <= i_wdata;
                32'd96  :  pos96  <= i_wdata;
                32'd97  :  pos97  <= i_wdata;
                32'd98  :  pos98  <= i_wdata;
                32'd99  :  pos99  <= i_wdata;

                32'd100  :  pos100  <= i_wdata;
                32'd101  :  pos101  <= i_wdata;
                32'd102  :  pos102  <= i_wdata;
                32'd103  :  pos103  <= i_wdata;
                32'd104  :  pos104  <= i_wdata;
                32'd105  :  pos105  <= i_wdata;
                32'd106  :  pos106  <= i_wdata;
                32'd107  :  pos107  <= i_wdata;
                32'd108  :  pos108  <= i_wdata;
                32'd109  :  pos109  <= i_wdata;

                32'd110  :  pos110 <= i_wdata;
                32'd111  :  pos111  <= i_wdata;
                32'd112  :  pos112  <= i_wdata;
                32'd113  :  pos113  <= i_wdata;
                32'd114  :  pos114  <= i_wdata;
                32'd115  :  pos115  <= i_wdata;
                32'd116  :  pos116  <= i_wdata;
                32'd117  :  pos117  <= i_wdata;
                32'd118  :  pos118  <= i_wdata;
                32'd119  :  pos119  <= i_wdata;

                32'd120  :  pos120  <= i_wdata;
                32'd121  :  pos121  <= i_wdata;
                32'd122  :  pos122  <= i_wdata;
                32'd123  :  pos123  <= i_wdata;
                32'd124  :  pos124  <= i_wdata;
                32'd125  :  pos125  <= i_wdata;
                32'd126  :  pos126  <= i_wdata;
                32'd127  :  pos127  <= i_wdata;
                32'd128  :  pos128  <= i_wdata;
                32'd129  :  pos129  <= i_wdata;

                32'd130  :  pos130  <= i_wdata;
                32'd131  :  pos131  <= i_wdata;
                32'd132  :  pos132  <= i_wdata;
                32'd133  :  pos133  <= i_wdata;
                32'd134  :  pos134  <= i_wdata;
                32'd135  :  pos135  <= i_wdata;
                32'd136  :  pos136  <= i_wdata;
                32'd137  :  pos137  <= i_wdata;
                32'd138  :  pos138  <= i_wdata;
                32'd139  :  pos139  <= i_wdata;

                32'd140  :  pos140  <= i_wdata;
                32'd141  :  pos141  <= i_wdata;
                32'd142  :  pos142  <= i_wdata;
                32'd143  :  pos143  <= i_wdata;
                32'd144  :  pos144  <= i_wdata;
                32'd145  :  pos145  <= i_wdata;
                32'd146  :  pos146  <= i_wdata;
                32'd147  :  pos147  <= i_wdata;
                32'd148  :  pos148  <= i_wdata;
                32'd149  :  pos149  <= i_wdata;

                32'd150  :  pos150  <= i_wdata;
                32'd151  :  pos151  <= i_wdata;
                32'd152  :  pos152  <= i_wdata;
                32'd153  :  pos153  <= i_wdata;
                32'd154  :  pos154  <= i_wdata;
                32'd155  :  pos155  <= i_wdata;
                32'd156  :  pos156  <= i_wdata;
                32'd157  :  pos157  <= i_wdata;
                32'd158  :  pos158  <= i_wdata;
                32'd159  :  pos159  <= i_wdata;

                32'd160  :  pos160  <= i_wdata;
                32'd161  :  pos161  <= i_wdata;
                32'd162  :  pos162  <= i_wdata;
                32'd163  :  pos163  <= i_wdata;
                32'd164  :  pos164  <= i_wdata;
                32'd165  :  pos165  <= i_wdata;
                32'd166  :  pos166  <= i_wdata;
                32'd167  :  pos167  <= i_wdata;
                32'd168  :  pos168  <= i_wdata;
                32'd169  :  pos169  <= i_wdata;

                32'd170  :  pos170  <= i_wdata;
                32'd171  :  pos171  <= i_wdata;
                32'd172  :  pos172  <= i_wdata;
                32'd173  :  pos173  <= i_wdata;
                32'd174  :  pos174  <= i_wdata;
                32'd175  :  pos175  <= i_wdata;
                32'd176  :  pos176  <= i_wdata;
                32'd177  :  pos177  <= i_wdata;
                32'd178  :  pos178  <= i_wdata;
                32'd179  :  pos179  <= i_wdata;

                32'd180  :  pos180  <= i_wdata;
                32'd181  :  pos181  <= i_wdata;
                32'd182  :  pos182  <= i_wdata;
                32'd183  :  pos183  <= i_wdata;
                32'd184  :  pos184  <= i_wdata;
                32'd185  :  pos185  <= i_wdata;
                32'd186  :  pos186  <= i_wdata;
                32'd187  :  pos187  <= i_wdata;
                32'd188  :  pos188  <= i_wdata;
                32'd189  :  pos189  <= i_wdata;

                32'd190  :  pos190  <= i_wdata;
                32'd191  :  pos191  <= i_wdata;
                32'd192  :  pos192  <= i_wdata;
                32'd193  :  pos193  <= i_wdata;
                32'd194  :  pos194  <= i_wdata;
                32'd195  :  pos195  <= i_wdata;
                32'd196  :  pos196  <= i_wdata;
                32'd197  :  pos197  <= i_wdata;
                32'd198  :  pos198  <= i_wdata;
                32'd199  :  pos199  <= i_wdata;

                32'd200  :  pos200  <= i_wdata;
                32'd201  :  pos201  <= i_wdata;
                32'd202  :  pos202  <= i_wdata;
                32'd203  :  pos203  <= i_wdata;
                32'd204  :  pos204  <= i_wdata;
                32'd205  :  pos205  <= i_wdata;
                32'd206  :  pos206  <= i_wdata;
                32'd207  :  pos207  <= i_wdata;
                32'd208  :  pos208  <= i_wdata;
                32'd209  :  pos209  <= i_wdata;

                32'd210  :  pos210 <= i_wdata;
                32'd211  :  pos211  <= i_wdata;
                32'd212  :  pos212  <= i_wdata;
                32'd213  :  pos213  <= i_wdata;
                32'd214  :  pos214  <= i_wdata;
                32'd215  :  pos215  <= i_wdata;
                32'd216  :  pos216  <= i_wdata;
                32'd217  :  pos217  <= i_wdata;
                32'd218  :  pos218  <= i_wdata;
                32'd219  :  pos219  <= i_wdata;

                32'd220  :  pos220  <= i_wdata;
                32'd221  :  pos221  <= i_wdata;
                32'd222  :  pos222  <= i_wdata;
                32'd223  :  pos223  <= i_wdata;
                32'd224  :  pos224  <= i_wdata;
                32'd225  :  pos225  <= i_wdata;
                32'd226  :  pos226  <= i_wdata;
                32'd227  :  pos227  <= i_wdata;
                32'd228  :  pos228  <= i_wdata;
                32'd229  :  pos229  <= i_wdata;

                32'd230  :  pos230  <= i_wdata;
                32'd231  :  pos231  <= i_wdata;
                32'd232  :  pos232  <= i_wdata;
                32'd233  :  pos233  <= i_wdata;
                32'd234  :  pos234  <= i_wdata;
                32'd235  :  pos235  <= i_wdata;
                32'd236  :  pos236  <= i_wdata;
                32'd237  :  pos237  <= i_wdata;
                32'd238  :  pos238  <= i_wdata;
                32'd239  :  pos239  <= i_wdata;

                32'd240  :  pos240  <= i_wdata;
                32'd241  :  pos241  <= i_wdata;
                32'd242  :  pos242  <= i_wdata;
                32'd243  :  pos243  <= i_wdata;
                32'd244  :  pos244  <= i_wdata;
                32'd245  :  pos245  <= i_wdata;
                32'd246  :  pos246  <= i_wdata;
                32'd247  :  pos247  <= i_wdata;
                32'd248  :  pos248  <= i_wdata;
                32'd249  :  pos249  <= i_wdata;

                32'd250  :  pos250  <= i_wdata;
                32'd251  :  pos251  <= i_wdata;
                32'd252  :  pos252  <= i_wdata;
                32'd253  :  pos253  <= i_wdata;
                32'd254  :  pos254  <= i_wdata;
                32'd255  :  pos255  <= i_wdata;
                32'd256  :  pos256  <= i_wdata;
                32'd257  :  pos257  <= i_wdata;
                32'd258  :  pos258  <= i_wdata;
                32'd259  :  pos259  <= i_wdata;

                32'd260  :  pos260  <= i_wdata;
                32'd261  :  pos261  <= i_wdata;
                32'd262  :  pos262  <= i_wdata;
                32'd263  :  pos263  <= i_wdata;
                32'd264  :  pos264  <= i_wdata;
                32'd265  :  pos265  <= i_wdata;
                32'd266  :  pos266  <= i_wdata;
                32'd267  :  pos267  <= i_wdata;
                32'd268  :  pos268  <= i_wdata;
                32'd269  :  pos269  <= i_wdata;

                32'd270  :  pos270  <= i_wdata;
                32'd271  :  pos271  <= i_wdata;
                32'd272  :  pos272  <= i_wdata;
                32'd273  :  pos273  <= i_wdata;
                32'd274  :  pos274  <= i_wdata;
                32'd275  :  pos275  <= i_wdata;
                32'd276  :  pos276  <= i_wdata;
                32'd277  :  pos277  <= i_wdata;
                32'd278  :  pos278  <= i_wdata;
                32'd279  :  pos279  <= i_wdata;

                32'd280  :  pos280  <= i_wdata;
                32'd281  :  pos281  <= i_wdata;
                32'd282  :  pos282  <= i_wdata;
                32'd283  :  pos283  <= i_wdata;
                32'd284  :  pos284  <= i_wdata;
                32'd285  :  pos285  <= i_wdata;
                32'd286  :  pos286  <= i_wdata;
                32'd287  :  pos287  <= i_wdata;
                32'd288  :  pos288  <= i_wdata;
                32'd289  :  pos289  <= i_wdata;

                32'd290  :  pos290  <= i_wdata;
                32'd291  :  pos291  <= i_wdata;
                32'd292  :  pos292  <= i_wdata;
                32'd293  :  pos293  <= i_wdata;
                32'd294  :  pos294  <= i_wdata;
                32'd295  :  pos295  <= i_wdata;
                32'd296  :  pos296  <= i_wdata;
                32'd297  :  pos297  <= i_wdata;
                32'd298  :  pos298  <= i_wdata;
                32'd299  :  pos299  <= i_wdata;
                
                32'd300  :  pos300  <= i_wdata;
                32'd301  :  pos301  <= i_wdata;
                32'd302  :  pos302  <= i_wdata;
                32'd303  :  pos303  <= i_wdata;
                32'd304  :  pos304  <= i_wdata;
                32'd305  :  pos305  <= i_wdata;
                32'd306  :  pos306  <= i_wdata;
                32'd307  :  pos307  <= i_wdata;
                32'd308  :  pos308  <= i_wdata;
                32'd309  :  pos309  <= i_wdata;
            
                default : o_instr <= 0;
            endcase

        end else begin
            
            case (i_addr)
                32'd0   :  o_instr <= pos0;
                32'd1   :  o_instr <= pos1;
                32'd2   :  o_instr <= pos2;
                32'd3   :  o_instr <= pos3;
                32'd4   :  o_instr <= pos4;
                32'd5   :  o_instr <= pos5;
                32'd6   :  o_instr <= pos6;
                32'd7   :  o_instr <= pos7;
                32'd8   :  o_instr <= pos8;
                32'd9   :  o_instr <= pos9;
                
                32'd10  :  o_instr  <= pos10;
                32'd11  :  o_instr  <= pos11;
                32'd12  :  o_instr  <= pos12;
                32'd13  :  o_instr  <= pos13;
                32'd14  :  o_instr  <= pos14;
                32'd15  :  o_instr  <= pos15;
                32'd16  :  o_instr  <= pos16;
                32'd17  :  o_instr  <= pos17;
                32'd18  :  o_instr  <= pos18;
                32'd19  :  o_instr  <= pos19;
                
                32'd20  :  o_instr  <= pos20;
                32'd21  :  o_instr  <= pos21;
                32'd22  :  o_instr  <= pos22;
                32'd23  :  o_instr  <= pos23;
                32'd24  :  o_instr  <= pos24;
                32'd25  :  o_instr  <= pos25;
                32'd26  :  o_instr  <= pos26;
                32'd27  :  o_instr  <= pos27;
                32'd28  :  o_instr  <= pos28;
                32'd29  :  o_instr  <= pos29;
                
                32'd30  :  o_instr  <= pos30;
                32'd31  :  o_instr  <= pos31;
                32'd32  :  o_instr  <= pos32;
                32'd33  :  o_instr  <= pos33;
                32'd34  :  o_instr  <= pos34;
                32'd35  :  o_instr  <= pos35;
                32'd36  :  o_instr  <= pos36;
                32'd37  :  o_instr  <= pos37;
                32'd38  :  o_instr  <= pos38;
                32'd39  :  o_instr  <= pos39;
                 
                32'd40  :  o_instr  <= pos40;
                32'd41  :  o_instr  <= pos41;
                32'd42  :  o_instr  <= pos42;
                32'd43  :  o_instr  <= pos43;
                32'd44  :  o_instr  <= pos44;
                32'd45  :  o_instr  <= pos45;
                32'd46  :  o_instr  <= pos46;
                32'd47  :  o_instr  <= pos47;
                32'd48  :  o_instr  <= pos48;
                32'd49  :  o_instr  <= pos49;
                
                32'd50  :  o_instr  <= pos50;
                32'd51  :  o_instr  <= pos51;
                32'd52  :  o_instr  <= pos52;
                32'd53  :  o_instr  <= pos53;
                32'd54  :  o_instr  <= pos54;
                32'd55  :  o_instr  <= pos55;
                32'd56  :  o_instr  <= pos56;
                32'd57  :  o_instr  <= pos57;
                32'd58  :  o_instr  <= pos58;
                32'd59  :  o_instr  <= pos59;
                
                32'd60  :  o_instr  <= pos60;
                32'd61  :  o_instr  <= pos61;
                32'd62  :  o_instr  <= pos62;
                32'd63  :  o_instr  <= pos63;
                32'd64  :  o_instr  <= pos64;
                32'd65  :  o_instr  <= pos65;
                32'd66  :  o_instr  <= pos66;
                32'd67  :  o_instr  <= pos67;
                32'd68  :  o_instr  <= pos68;
                32'd69  :  o_instr  <= pos69;
                
                32'd70  :  o_instr  <= pos70;
                32'd71  :  o_instr  <= pos71;
                32'd72  :  o_instr  <= pos72;
                32'd73  :  o_instr  <= pos73;
                32'd74  :  o_instr  <= pos74;
                32'd75  :  o_instr  <= pos75;
                32'd76  :  o_instr  <= pos76;
                32'd77  :  o_instr  <= pos77;
                32'd78  :  o_instr  <= pos78;
                32'd79  :  o_instr  <= pos79;
                
                32'd80  :  o_instr  <= pos80;
                32'd81  :  o_instr  <= pos81;
                32'd82  :  o_instr  <= pos82;
                32'd83  :  o_instr  <= pos83;
                32'd84  :  o_instr  <= pos84;
                32'd85  :  o_instr  <= pos85;
                32'd86  :  o_instr  <= pos86;
                32'd87  :  o_instr  <= pos87;
                32'd88  :  o_instr  <= pos88;
                32'd89  :  o_instr  <= pos89;
                
                32'd90  :  o_instr  <= pos90;
                32'd91  :  o_instr  <= pos91;
                32'd92  :  o_instr  <= pos92;
                32'd93  :  o_instr  <= pos93;
                32'd94  :  o_instr  <= pos94;
                32'd95  :  o_instr  <= pos95;
                32'd96  :  o_instr  <= pos96;
                32'd97  :  o_instr  <= pos97;
                32'd98  :  o_instr  <= pos98;
                32'd99  :  o_instr  <= pos99;
                
                32'd100  :  o_instr  <= pos100;
                32'd101  :  o_instr  <= pos101;
                32'd102  :  o_instr  <= pos102;
                32'd103  :  o_instr  <= pos103;
                32'd104  :  o_instr  <= pos104;
                32'd105  :  o_instr  <= pos105;
                32'd106  :  o_instr  <= pos106;
                32'd107  :  o_instr  <= pos107;
                32'd108  :  o_instr  <= pos108;
                32'd109  :  o_instr  <= pos109;

                32'd110  :  o_instr  <= pos110;
                32'd111  :  o_instr  <= pos111;
                32'd112  :  o_instr  <= pos112;
                32'd113  :  o_instr  <= pos113;
                32'd114  :  o_instr  <= pos114;
                32'd115  :  o_instr  <= pos115;
                32'd116  :  o_instr  <= pos116;
                32'd117  :  o_instr  <= pos117;
                32'd118  :  o_instr  <= pos118;
                32'd119  :  o_instr  <= pos119;
                
                32'd120  :  o_instr  <= pos120;
                32'd121  :  o_instr  <= pos121;
                32'd122  :  o_instr  <= pos122;
                32'd123  :  o_instr  <= pos123;
                32'd124  :  o_instr  <= pos124;
                32'd125  :  o_instr  <= pos125;
                32'd126  :  o_instr  <= pos126;
                32'd127  :  o_instr  <= pos127;
                32'd128  :  o_instr  <= pos128;
                32'd129  :  o_instr  <= pos129;
                
                32'd130  :  o_instr  <= pos130;
                32'd131  :  o_instr  <= pos131;
                32'd132  :  o_instr  <= pos132;
                32'd133  :  o_instr  <= pos133;
                32'd134  :  o_instr  <= pos134;
                32'd135  :  o_instr  <= pos135;
                32'd136  :  o_instr  <= pos136;
                32'd137  :  o_instr  <= pos137;
                32'd138  :  o_instr  <= pos138;
                32'd139  :  o_instr  <= pos139;
                 
                32'd140  :  o_instr  <= pos140;
                32'd141  :  o_instr  <= pos141;
                32'd142  :  o_instr  <= pos142;
                32'd143  :  o_instr  <= pos143;
                32'd144  :  o_instr  <= pos144;
                32'd145  :  o_instr  <= pos145;
                32'd146  :  o_instr  <= pos146;
                32'd147  :  o_instr  <= pos147;
                32'd148  :  o_instr  <= pos148;
                32'd149  :  o_instr  <= pos149;
                
                32'd150  :  o_instr  <= pos150;
                32'd151  :  o_instr  <= pos151;
                32'd152  :  o_instr  <= pos152;
                32'd153  :  o_instr  <= pos153;
                32'd154  :  o_instr  <= pos154;
                32'd155  :  o_instr  <= pos155;
                32'd156  :  o_instr  <= pos156;
                32'd157  :  o_instr  <= pos157;
                32'd158  :  o_instr  <= pos158;
                32'd159  :  o_instr  <= pos159;
                
                32'd160  :  o_instr  <= pos160;
                32'd161  :  o_instr  <= pos161;
                32'd162  :  o_instr  <= pos162;
                32'd163  :  o_instr  <= pos163;
                32'd164  :  o_instr  <= pos164;
                32'd165  :  o_instr  <= pos165;
                32'd166  :  o_instr  <= pos166;
                32'd167  :  o_instr  <= pos167;
                32'd168  :  o_instr  <= pos168;
                32'd169  :  o_instr  <= pos169;
                
                32'd170  :  o_instr  <= pos170;
                32'd171  :  o_instr  <= pos171;
                32'd172  :  o_instr  <= pos172;
                32'd173  :  o_instr  <= pos173;
                32'd174  :  o_instr  <= pos174;
                32'd175  :  o_instr  <= pos175;
                32'd176  :  o_instr  <= pos176;
                32'd177  :  o_instr  <= pos177;
                32'd178  :  o_instr  <= pos178;
                32'd179  :  o_instr  <= pos179;
                
                32'd180  :  o_instr  <= pos180;
                32'd181  :  o_instr  <= pos181;
                32'd182  :  o_instr  <= pos182;
                32'd183  :  o_instr  <= pos183;
                32'd184  :  o_instr  <= pos184;
                32'd185  :  o_instr  <= pos185;
                32'd186  :  o_instr  <= pos186;
                32'd187  :  o_instr  <= pos187;
                32'd188  :  o_instr  <= pos188;
                32'd189  :  o_instr  <= pos189;
                
                32'd190  :  o_instr  <= pos190;
                32'd191  :  o_instr  <= pos191;
                32'd192  :  o_instr  <= pos192;
                32'd193  :  o_instr  <= pos193;
                32'd194  :  o_instr  <= pos194;
                32'd195  :  o_instr  <= pos195;
                32'd196  :  o_instr  <= pos196;
                32'd197  :  o_instr  <= pos197;
                32'd198  :  o_instr  <= pos198;
                32'd199  :  o_instr  <= pos199;

                32'd200  :  o_instr  <= pos200;
                32'd201  :  o_instr  <= pos201;
                32'd202  :  o_instr  <= pos202;
                32'd203  :  o_instr  <= pos203;
                32'd204  :  o_instr  <= pos204;
                32'd205  :  o_instr  <= pos205;
                32'd206  :  o_instr  <= pos206;
                32'd207  :  o_instr  <= pos207;
                32'd208  :  o_instr  <= pos208;
                32'd209  :  o_instr  <= pos209;

                32'd210  :  o_instr  <= pos210;
                32'd211  :  o_instr  <= pos211;
                32'd212  :  o_instr  <= pos212;
                32'd213  :  o_instr  <= pos213;
                32'd214  :  o_instr  <= pos214;
                32'd215  :  o_instr  <= pos215;
                32'd216  :  o_instr  <= pos216;
                32'd217  :  o_instr  <= pos217;
                32'd218  :  o_instr  <= pos218;
                32'd219  :  o_instr  <= pos219;
                
                32'd220  :  o_instr  <= pos220;
                32'd221  :  o_instr  <= pos221;
                32'd222  :  o_instr  <= pos222;
                32'd223  :  o_instr  <= pos223;
                32'd224  :  o_instr  <= pos224;
                32'd225  :  o_instr  <= pos225;
                32'd226  :  o_instr  <= pos226;
                32'd227  :  o_instr  <= pos227;
                32'd228  :  o_instr  <= pos228;
                32'd229  :  o_instr  <= pos229;
                
                32'd230  :  o_instr  <= pos230;
                32'd231  :  o_instr  <= pos231;
                32'd232  :  o_instr  <= pos232;
                32'd233  :  o_instr  <= pos233;
                32'd234  :  o_instr  <= pos234;
                32'd235  :  o_instr  <= pos235;
                32'd236  :  o_instr  <= pos236;
                32'd237  :  o_instr  <= pos237;
                32'd238  :  o_instr  <= pos238;
                32'd239  :  o_instr  <= pos239;
                 
                32'd240  :  o_instr  <= pos240;
                32'd241  :  o_instr  <= pos241;
                32'd242  :  o_instr  <= pos242;
                32'd243  :  o_instr  <= pos243;
                32'd244  :  o_instr  <= pos244;
                32'd245  :  o_instr  <= pos245;
                32'd246  :  o_instr  <= pos246;
                32'd247  :  o_instr  <= pos247;
                32'd248  :  o_instr  <= pos248;
                32'd249  :  o_instr  <= pos249;
                
                32'd250  :  o_instr  <= pos250;
                32'd251  :  o_instr  <= pos251;
                32'd252  :  o_instr  <= pos252;
                32'd253  :  o_instr  <= pos253;
                32'd254  :  o_instr  <= pos254;
                32'd255  :  o_instr  <= pos255;
                32'd256  :  o_instr  <= pos256;
                32'd257  :  o_instr  <= pos257;
                32'd258  :  o_instr  <= pos258;
                32'd259  :  o_instr  <= pos259;
                
                32'd260  :  o_instr  <= pos260;
                32'd261  :  o_instr  <= pos261;
                32'd262  :  o_instr  <= pos262;
                32'd263  :  o_instr  <= pos263;
                32'd264  :  o_instr  <= pos264;
                32'd265  :  o_instr  <= pos265;
                32'd266  :  o_instr  <= pos266;
                32'd267  :  o_instr  <= pos267;
                32'd268  :  o_instr  <= pos268;
                32'd269  :  o_instr  <= pos269;
                
                32'd270  :  o_instr  <= pos270;
                32'd271  :  o_instr  <= pos271;
                32'd272  :  o_instr  <= pos272;
                32'd273  :  o_instr  <= pos273;
                32'd274  :  o_instr  <= pos274;
                32'd275  :  o_instr  <= pos275;
                32'd276  :  o_instr  <= pos276;
                32'd277  :  o_instr  <= pos277;
                32'd278  :  o_instr  <= pos278;
                32'd279  :  o_instr  <= pos279;
                
                32'd280  :  o_instr  <= pos280;
                32'd281  :  o_instr  <= pos281;
                32'd282  :  o_instr  <= pos282;
                32'd283  :  o_instr  <= pos283;
                32'd284  :  o_instr  <= pos284;
                32'd285  :  o_instr  <= pos285;
                32'd286  :  o_instr  <= pos286;
                32'd287  :  o_instr  <= pos287;
                32'd288  :  o_instr  <= pos288;
                32'd289  :  o_instr  <= pos289;
                
                32'd290  :  o_instr  <= pos290;
                32'd291  :  o_instr  <= pos291;
                32'd292  :  o_instr  <= pos292;
                32'd293  :  o_instr  <= pos293;
                32'd294  :  o_instr  <= pos294;
                32'd295  :  o_instr  <= pos295;
                32'd296  :  o_instr  <= pos296;
                32'd297  :  o_instr  <= pos297;
                32'd298  :  o_instr  <= pos298;
                32'd299  :  o_instr  <= pos299;
                
                32'd300  :  o_instr  <= pos300;
                32'd301  :  o_instr  <= pos301;
                32'd302  :  o_instr  <= pos302;
                32'd303  :  o_instr  <= pos303;
                32'd304  :  o_instr  <= pos304;
                32'd305  :  o_instr  <= pos305;
                32'd306  :  o_instr  <= pos306;
                32'd307  :  o_instr  <= pos307;
                32'd308  :  o_instr  <= pos308;
                32'd309  :  o_instr  <= pos309;

                default : o_instr  <= 0;
            endcase

        end

    end
  
endmodule

//----------------------------------------------------------------------------------------------------------------------------------------------
//                                                                      S R A M                                               
//----------------------------------------------------------------------------------------------------------------------------------------------
