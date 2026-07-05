// ----------------------------------------------------------------------------------------------------------------------------------------------
// -- File Name        : sram.sv
// -- Module Name      : idmem
// -- Developer        : David Rodriguez, Kristhel Quesada
// --
// -- Description      : This module describes a basic implementation on the data/instruction SRAM
// --
// -- Tested on        :
// -- Last modified on : October-2024
// -- Notes            : Puerto B agregado para permitir dos accesos por ciclo (VLSU dual-word).
// --
// -- Copyright        : Refer to LICENSE.md.
// ----------------------------------------------------------------------------------------------------------------------------------------------

module dcache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input wire clk, rst,

    // Puerto A
    input wire i_write_en, i_read_en,
    input wire [3:0] i_byte_en,
    input wire [ADDR_WIDTH-1:0] i_addr,
    input wire [DATA_WIDTH-1:0] i_wdata,
    output reg [DATA_WIDTH-1:0] o_rdata,

    // Puerto B
    input wire i_write_en_b, i_read_en_b,
    input wire [3:0] i_byte_en_b,
    input wire [ADDR_WIDTH-1:0] i_addr_b,
    input wire [DATA_WIDTH-1:0] i_wdata_b,
    output reg [DATA_WIDTH-1:0] o_rdata_b
);

//==========================================================
// FUNCTIONS
//==========================================================
function [31:0] write_with_be(
    input [31:0] old_data,
    input [31:0] new_data,
    input [3:0] byte_en
);
    begin
        write_with_be[7:0]   =  byte_en[0] ? new_data[7:0]   : old_data[7:0];
        write_with_be[15:8]  =  byte_en[1] ? new_data[15:8]  : old_data[15:8];
        write_with_be[23:16] =  byte_en[2] ? new_data[23:16] : old_data[23:16];
        write_with_be[31:24] =  byte_en[3] ? new_data[31:24] : old_data[31:24];
    end
endfunction


//==========================================================
// Definition of register to save data
//==========================================================
reg [DATA_WIDTH-1:0] pos0, pos1, pos2, pos3, pos4, pos5, pos6, pos7, pos8, pos9;
reg [DATA_WIDTH-1:0] pos10, pos11, pos12, pos13, pos14, pos15, pos16, pos17, pos18, pos19;
reg [DATA_WIDTH-1:0] pos20, pos21, pos22, pos23, pos24, pos25, pos26, pos27, pos28, pos29;
reg [DATA_WIDTH-1:0] pos30, pos31, pos32, pos33, pos34, pos35, pos36, pos37, pos38, pos39;
reg [DATA_WIDTH-1:0] pos40, pos41, pos42, pos43, pos44, pos45, pos46, pos47, pos48, pos49;
reg [DATA_WIDTH-1:0] pos50, pos51, pos52, pos53, pos54, pos55, pos56, pos57, pos58, pos59;
reg [DATA_WIDTH-1:0] pos60, pos61, pos62, pos63, pos64, pos65, pos66, pos67, pos68, pos69;
reg [DATA_WIDTH-1:0] pos70, pos71, pos72, pos73, pos74, pos75, pos76, pos77, pos78, pos79;
reg [DATA_WIDTH-1:0] pos80, pos81, pos82, pos83, pos84, pos85, pos86, pos87, pos88, pos89;
reg [DATA_WIDTH-1:0] pos90, pos91, pos92, pos93, pos94, pos95, pos96, pos97, pos98, pos99;
reg [DATA_WIDTH-1:0] pos100, pos101, pos102, pos103, pos104, pos105, pos106, pos107, pos108, pos109;
reg [DATA_WIDTH-1:0] pos110, pos111, pos112, pos113, pos114, pos115, pos116, pos117, pos118, pos119;
reg [DATA_WIDTH-1:0] pos120, pos121, pos122, pos123, pos124, pos125, pos126, pos127;

//==========================================================
// Main logic
//==========================================================
// ----------------------------------------------------
// Sequential logic
// ----------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        pos0  = 32'hA1F3_C942;
        pos1  = 32'h5E7B_00D3;
        pos2  = 32'h9B4A_7F20;
        pos3  = 32'hC3D1_E8A9;
        pos4  = 32'hF02B_4C77;
        pos5  = 32'h38A9_0B5E;
        pos6  = 32'h74CE_92D1;
        pos7  = 32'h21AB_DE6F;
        pos8  = 32'hE4C7_1350;
        pos9  = 32'hB98D_25AA;

        pos10 = 32'h6F3B_4D82;
        pos11 = 32'hC05A_99E7;
        pos12 = 32'h1A2D_0FBC;
        pos13 = 32'h8E9C_67DA;
        pos14 = 32'h4B7F_3210;
        pos15 = 32'hD31A_8E6B;
        pos16 = 32'h7C59_A2FD;
        pos17 = 32'h20BE_31C4;
        pos18 = 32'hAA47_F918;
        pos19 = 32'h95E6_D203;

        pos20 = 32'h13F7_C8B4;
        pos21 = 32'hE9D2_047A;
        pos22 = 32'h4C51_B6E9;
        pos23 = 32'h7B0A_1D25;
        pos24 = 32'h89C3_EF6D;
        pos25 = 32'h56D0_7A12;
        pos26 = 32'hF4B2_39A8;
        pos27 = 32'h2A6E_5CD0;
        pos28 = 32'h67E3_A1BF;
        pos29 = 32'h0C94_F682;

        pos30 = 32'hD873_1BE4;
        pos31 = 32'hA52E_4F19;
        pos32 = 32'h3BF0_C72D;
        pos33 = 32'h19A4_D8E0;
        pos34 = 32'hE702_5B63;
        pos35 = 32'hC4F8_A9B2;
        pos36 = 32'h58B3_E107;
        pos37 = 32'h02DC_A554;
        pos38 = 32'hF93E_608C;
        pos39 = 32'h6D14_B9A3;

        pos40 = 32'h8AF2_D075;
        pos41 = 32'hB73E_1269;
        pos42 = 32'hDC85_1F94;
        pos43 = 32'h9E42_0CB8;
        pos44 = 32'h0147_D2AF;
        pos45 = 32'h5A3C_8E67;
        pos46 = 32'hF1B0_6A3D;
        pos47 = 32'h23E5_B490;
        pos48 = 32'h7C8A_1E2B;
        pos49 = 32'hAA54_F0C8;

        pos50  = 32'hA1F3_C942;
        pos51  = 32'h5E7B_00D3;
        pos52  = 32'h9B4A_7F20;
        pos53  = 32'hC3D1_E8A9;
        pos54  = 32'hF02B_4C77;
        pos55  = 32'h38A9_0B5E;
        pos56  = 32'h74CE_92D1;
        pos57  = 32'h21AB_DE6F;
        pos58  = 32'hE4C7_1350;
        pos59  = 32'hB98D_25AA;

        pos60 = 32'h6F3B_4D82;
        pos61 = 32'hC05A_99E7;
        pos62 = 32'h1A2D_0FBC;
        pos63 = 32'h8E9C_67DA;
        pos64 = 32'h4B7F_3210;
        pos65 = 32'hD31A_8E6B;
        pos66 = 32'h7C59_A2FD;
        pos67 = 32'h20BE_31C4;
        pos68 = 32'hAA47_F918;
        pos69 = 32'h95E6_D203;

        pos70 = 32'h13F7_C8B4;
        pos71 = 32'hE9D2_047A;
        pos72 = 32'h4C51_B6E9;
        pos73 = 32'h7B0A_1D25;
        pos74 = 32'h89C3_EF6D;
        pos75 = 32'h56D0_7A12;
        pos76 = 32'hF4B2_39A8;
        pos77 = 32'h2A6E_5CD0;
        pos78 = 32'h67E3_A1BF;
        pos79 = 32'h0C94_F682;

        pos80 = 32'hD873_1BE4;
        pos81 = 32'hA52E_4F19;
        pos82 = 32'h3BF0_C72D;
        pos83 = 32'h19A4_D8E0;
        pos84 = 32'hE702_5B63;
        pos85 = 32'hC4F8_A9B2;
        pos86 = 32'h58B3_E107;
        pos87 = 32'h02DC_A554;
        pos88 = 32'hF93E_608C;
        pos89 = 32'h6D14_B9A3;

        pos90 = 32'h8AF2_D075;
        pos91 = 32'hB73E_1269;
        pos92 = 32'hDC85_1F94;
        pos93 = 32'h9E42_0CB8;
        pos94 = 32'h0147_D2AF;
        pos95 = 32'h5A3C_8E67;
        pos96 = 32'hF1B0_6A3D;
        pos97 = 32'h23E5_B490;
        pos98 = 32'h7C8A_1E2B;
        pos99 = 32'hAA54_F0C8;

        pos100  = 32'hA1F3_C942;
        pos101  = 32'h5E7B_00D3;
        pos102  = 32'h9B4A_7F20;
        pos103  = 32'hC3D1_E8A9;
        pos104  = 32'hF02B_4C77;
        pos105  = 32'h38A9_0B5E;
        pos106  = 32'h74CE_92D1;
        pos107  = 32'h21AB_DE6F;
        pos108  = 32'hE4C7_1350;
        pos109  = 32'hB98D_25AA;

        pos110 = 32'h6F3B_4D82;
        pos111 = 32'hC05A_99E7;
        pos112 = 32'h1A2D_0FBC;
        pos113 = 32'h8E9C_67DA;
        pos114 = 32'h4B7F_3210;
        pos115 = 32'hD31A_8E6B;
        pos116 = 32'h7C59_A2FD;
        pos117 = 32'h20BE_31C4;
        pos118 = 32'hAA47_F918;
        pos119 = 32'h95E6_D203;

        pos120 = 32'h13F7_C8B4;
        pos121 = 32'hE9D2_047A;
        pos122 = 32'h4C51_B6E9;
        pos123 = 32'h7B0A_1D25;
        pos124 = 32'h89C3_EF6D;
        pos125 = 32'h56D0_7A12;
        pos126 = 32'hF4B2_39A8;
        pos127 = 32'h2A6E_5CD0;

        o_rdata   <= 0;
        o_rdata_b <= 0;

    end else begin
        if (i_write_en) begin
            case (i_addr)
                32'd0 : pos0  <= write_with_be(pos0,  i_wdata, i_byte_en);
                32'd1 : pos1  <= write_with_be(pos1,  i_wdata, i_byte_en);
                32'd2 : pos2  <= write_with_be(pos2,  i_wdata, i_byte_en);
                32'd3 : pos3  <= write_with_be(pos3,  i_wdata, i_byte_en);
                32'd4 : pos4  <= write_with_be(pos4,  i_wdata, i_byte_en);
                32'd5 : pos5  <= write_with_be(pos5,  i_wdata, i_byte_en);
                32'd6 : pos6  <= write_with_be(pos6,  i_wdata, i_byte_en);
                32'd7 : pos7  <= write_with_be(pos7,  i_wdata, i_byte_en);
                32'd8 : pos8  <= write_with_be(pos8,  i_wdata, i_byte_en);
                32'd9 : pos9  <= write_with_be(pos9,  i_wdata, i_byte_en);

                32'd10: pos10 <= write_with_be(pos10, i_wdata, i_byte_en);
                32'd11: pos11 <= write_with_be(pos11, i_wdata, i_byte_en);
                32'd12: pos12 <= write_with_be(pos12, i_wdata, i_byte_en);
                32'd13: pos13 <= write_with_be(pos13, i_wdata, i_byte_en);
                32'd14: pos14 <= write_with_be(pos14, i_wdata, i_byte_en);
                32'd15: pos15 <= write_with_be(pos15, i_wdata, i_byte_en);
                32'd16: pos16 <= write_with_be(pos16, i_wdata, i_byte_en);
                32'd17: pos17 <= write_with_be(pos17, i_wdata, i_byte_en);
                32'd18: pos18 <= write_with_be(pos18, i_wdata, i_byte_en);
                32'd19: pos19 <= write_with_be(pos19, i_wdata, i_byte_en);

                32'd20: pos20 <= write_with_be(pos20, i_wdata, i_byte_en);
                32'd21: pos21 <= write_with_be(pos21, i_wdata, i_byte_en);
                32'd22: pos22 <= write_with_be(pos22, i_wdata, i_byte_en);
                32'd23: pos23 <= write_with_be(pos23, i_wdata, i_byte_en);
                32'd24: pos24 <= write_with_be(pos24, i_wdata, i_byte_en);
                32'd25: pos25 <= write_with_be(pos25, i_wdata, i_byte_en);
                32'd26: pos26 <= write_with_be(pos26, i_wdata, i_byte_en);
                32'd27: pos27 <= write_with_be(pos27, i_wdata, i_byte_en);
                32'd28: pos28 <= write_with_be(pos28, i_wdata, i_byte_en);
                32'd29: pos29 <= write_with_be(pos29, i_wdata, i_byte_en);

                32'd30: pos30 <= write_with_be(pos30, i_wdata, i_byte_en);
                32'd31: pos31 <= write_with_be(pos31, i_wdata, i_byte_en);
                32'd32: pos32 <= write_with_be(pos32, i_wdata, i_byte_en);
                32'd33: pos33 <= write_with_be(pos33, i_wdata, i_byte_en);
                32'd34: pos34 <= write_with_be(pos34, i_wdata, i_byte_en);
                32'd35: pos35 <= write_with_be(pos35, i_wdata, i_byte_en);
                32'd36: pos36 <= write_with_be(pos36, i_wdata, i_byte_en);
                32'd37: pos37 <= write_with_be(pos37, i_wdata, i_byte_en);
                32'd38: pos38 <= write_with_be(pos38, i_wdata, i_byte_en);
                32'd39: pos39 <= write_with_be(pos39, i_wdata, i_byte_en);

                32'd40: pos40 <= write_with_be(pos40, i_wdata, i_byte_en);
                32'd41: pos41 <= write_with_be(pos41, i_wdata, i_byte_en);
                32'd42: pos42 <= write_with_be(pos42, i_wdata, i_byte_en);
                32'd43: pos43 <= write_with_be(pos43, i_wdata, i_byte_en);
                32'd44: pos44 <= write_with_be(pos44, i_wdata, i_byte_en);
                32'd45: pos45 <= write_with_be(pos45, i_wdata, i_byte_en);
                32'd46: pos46 <= write_with_be(pos46, i_wdata, i_byte_en);
                32'd47: pos47 <= write_with_be(pos47, i_wdata, i_byte_en);
                32'd48: pos48 <= write_with_be(pos48, i_wdata, i_byte_en);
                32'd49: pos49 <= write_with_be(pos49, i_wdata, i_byte_en);

                32'd50 : pos50  <= write_with_be(pos50,  i_wdata, i_byte_en);
                32'd51 : pos51  <= write_with_be(pos51,  i_wdata, i_byte_en);
                32'd52 : pos52  <= write_with_be(pos52,  i_wdata, i_byte_en);
                32'd53 : pos53  <= write_with_be(pos53,  i_wdata, i_byte_en);
                32'd54 : pos54  <= write_with_be(pos54,  i_wdata, i_byte_en);
                32'd55 : pos55  <= write_with_be(pos55,  i_wdata, i_byte_en);
                32'd56 : pos56  <= write_with_be(pos56,  i_wdata, i_byte_en);
                32'd57 : pos57  <= write_with_be(pos57,  i_wdata, i_byte_en);
                32'd58 : pos58  <= write_with_be(pos58,  i_wdata, i_byte_en);
                32'd59 : pos59  <= write_with_be(pos59,  i_wdata, i_byte_en);

                32'd60 : pos60  <= write_with_be(pos60,  i_wdata, i_byte_en);
                32'd61 : pos61  <= write_with_be(pos61,  i_wdata, i_byte_en);
                32'd62 : pos62  <= write_with_be(pos62,  i_wdata, i_byte_en);
                32'd63 : pos63  <= write_with_be(pos63,  i_wdata, i_byte_en);
                32'd64 : pos64  <= write_with_be(pos64,  i_wdata, i_byte_en);
                32'd65 : pos65  <= write_with_be(pos65,  i_wdata, i_byte_en);
                32'd66 : pos66  <= write_with_be(pos66,  i_wdata, i_byte_en);
                32'd67 : pos67  <= write_with_be(pos67,  i_wdata, i_byte_en);
                32'd68 : pos68  <= write_with_be(pos68,  i_wdata, i_byte_en);
                32'd69 : pos69  <= write_with_be(pos69,  i_wdata, i_byte_en);

                32'd70 : pos70  <= write_with_be(pos70,  i_wdata, i_byte_en);
                32'd71 : pos71  <= write_with_be(pos71,  i_wdata, i_byte_en);
                32'd72 : pos72  <= write_with_be(pos72,  i_wdata, i_byte_en);
                32'd73 : pos73  <= write_with_be(pos73,  i_wdata, i_byte_en);
                32'd74 : pos74  <= write_with_be(pos74,  i_wdata, i_byte_en);
                32'd75 : pos75  <= write_with_be(pos75,  i_wdata, i_byte_en);
                32'd76 : pos76  <= write_with_be(pos76,  i_wdata, i_byte_en);
                32'd77 : pos77  <= write_with_be(pos77,  i_wdata, i_byte_en);
                32'd78 : pos78  <= write_with_be(pos78,  i_wdata, i_byte_en);
                32'd79 : pos79  <= write_with_be(pos79,  i_wdata, i_byte_en);

                32'd80 : pos80  <= write_with_be(pos80,  i_wdata, i_byte_en);
                32'd81 : pos81  <= write_with_be(pos81,  i_wdata, i_byte_en);
                32'd82 : pos82  <= write_with_be(pos82,  i_wdata, i_byte_en);
                32'd83 : pos83  <= write_with_be(pos83,  i_wdata, i_byte_en);
                32'd84 : pos84  <= write_with_be(pos84,  i_wdata, i_byte_en);
                32'd85 : pos85  <= write_with_be(pos85,  i_wdata, i_byte_en);
                32'd86 : pos86  <= write_with_be(pos86,  i_wdata, i_byte_en);
                32'd87 : pos87  <= write_with_be(pos87,  i_wdata, i_byte_en);
                32'd88 : pos88  <= write_with_be(pos88,  i_wdata, i_byte_en);
                32'd89 : pos89  <= write_with_be(pos89,  i_wdata, i_byte_en);

                32'd90 : pos90  <= write_with_be(pos90,  i_wdata, i_byte_en);
                32'd91 : pos91  <= write_with_be(pos91,  i_wdata, i_byte_en);
                32'd92 : pos92  <= write_with_be(pos92,  i_wdata, i_byte_en);
                32'd93 : pos93  <= write_with_be(pos93,  i_wdata, i_byte_en);
                32'd94 : pos94  <= write_with_be(pos94,  i_wdata, i_byte_en);
                32'd95 : pos95  <= write_with_be(pos95,  i_wdata, i_byte_en);
                32'd96 : pos96  <= write_with_be(pos96,  i_wdata, i_byte_en);
                32'd97 : pos97  <= write_with_be(pos97,  i_wdata, i_byte_en);
                32'd98 : pos98  <= write_with_be(pos98,  i_wdata, i_byte_en);
                32'd99 : pos99  <= write_with_be(pos99,  i_wdata, i_byte_en);

                32'd100 : pos100  <= write_with_be(pos100,  i_wdata, i_byte_en);
                32'd101 : pos101  <= write_with_be(pos101,  i_wdata, i_byte_en);
                32'd102 : pos102  <= write_with_be(pos102,  i_wdata, i_byte_en);
                32'd103 : pos103  <= write_with_be(pos103,  i_wdata, i_byte_en);
                32'd104 : pos104  <= write_with_be(pos104,  i_wdata, i_byte_en);
                32'd105 : pos105  <= write_with_be(pos105,  i_wdata, i_byte_en);
                32'd106 : pos106  <= write_with_be(pos106,  i_wdata, i_byte_en);
                32'd107 : pos107  <= write_with_be(pos107,  i_wdata, i_byte_en);
                32'd108 : pos108  <= write_with_be(pos108,  i_wdata, i_byte_en);
                32'd109 : pos109  <= write_with_be(pos109,  i_wdata, i_byte_en);

                32'd110 : pos110  <= write_with_be(pos110,  i_wdata, i_byte_en);
                32'd111 : pos111  <= write_with_be(pos111,  i_wdata, i_byte_en);
                32'd112 : pos112  <= write_with_be(pos112,  i_wdata, i_byte_en);
                32'd113 : pos113  <= write_with_be(pos113,  i_wdata, i_byte_en);
                32'd114 : pos114  <= write_with_be(pos114,  i_wdata, i_byte_en);
                32'd115 : pos115  <= write_with_be(pos115,  i_wdata, i_byte_en);
                32'd116 : pos116  <= write_with_be(pos116,  i_wdata, i_byte_en);
                32'd117 : pos117  <= write_with_be(pos117,  i_wdata, i_byte_en);
                32'd118 : pos118  <= write_with_be(pos118,  i_wdata, i_byte_en);
                32'd119 : pos119  <= write_with_be(pos119,  i_wdata, i_byte_en);

                32'd120 : pos120  <= write_with_be(pos120,  i_wdata, i_byte_en);
                32'd121 : pos121  <= write_with_be(pos121,  i_wdata, i_byte_en);
                32'd122 : pos122  <= write_with_be(pos122,  i_wdata, i_byte_en);
                32'd123 : pos123  <= write_with_be(pos123,  i_wdata, i_byte_en);
                32'd124 : pos124  <= write_with_be(pos124,  i_wdata, i_byte_en);
                32'd125 : pos125  <= write_with_be(pos125,  i_wdata, i_byte_en);
                32'd126 : pos126  <= write_with_be(pos126,  i_wdata, i_byte_en);
                32'd127 : pos127  <= write_with_be(pos127,  i_wdata, i_byte_en);
            endcase
        end

        if (i_write_en_b) begin
            case (i_addr_b)
                32'd0 : pos0  <= write_with_be(pos0,  i_wdata_b, i_byte_en_b);
                32'd1 : pos1  <= write_with_be(pos1,  i_wdata_b, i_byte_en_b);
                32'd2 : pos2  <= write_with_be(pos2,  i_wdata_b, i_byte_en_b);
                32'd3 : pos3  <= write_with_be(pos3,  i_wdata_b, i_byte_en_b);
                32'd4 : pos4  <= write_with_be(pos4,  i_wdata_b, i_byte_en_b);
                32'd5 : pos5  <= write_with_be(pos5,  i_wdata_b, i_byte_en_b);
                32'd6 : pos6  <= write_with_be(pos6,  i_wdata_b, i_byte_en_b);
                32'd7 : pos7  <= write_with_be(pos7,  i_wdata_b, i_byte_en_b);
                32'd8 : pos8  <= write_with_be(pos8,  i_wdata_b, i_byte_en_b);
                32'd9 : pos9  <= write_with_be(pos9,  i_wdata_b, i_byte_en_b);

                32'd10: pos10 <= write_with_be(pos10, i_wdata_b, i_byte_en_b);
                32'd11: pos11 <= write_with_be(pos11, i_wdata_b, i_byte_en_b);
                32'd12: pos12 <= write_with_be(pos12, i_wdata_b, i_byte_en_b);
                32'd13: pos13 <= write_with_be(pos13, i_wdata_b, i_byte_en_b);
                32'd14: pos14 <= write_with_be(pos14, i_wdata_b, i_byte_en_b);
                32'd15: pos15 <= write_with_be(pos15, i_wdata_b, i_byte_en_b);
                32'd16: pos16 <= write_with_be(pos16, i_wdata_b, i_byte_en_b);
                32'd17: pos17 <= write_with_be(pos17, i_wdata_b, i_byte_en_b);
                32'd18: pos18 <= write_with_be(pos18, i_wdata_b, i_byte_en_b);
                32'd19: pos19 <= write_with_be(pos19, i_wdata_b, i_byte_en_b);

                32'd20: pos20 <= write_with_be(pos20, i_wdata_b, i_byte_en_b);
                32'd21: pos21 <= write_with_be(pos21, i_wdata_b, i_byte_en_b);
                32'd22: pos22 <= write_with_be(pos22, i_wdata_b, i_byte_en_b);
                32'd23: pos23 <= write_with_be(pos23, i_wdata_b, i_byte_en_b);
                32'd24: pos24 <= write_with_be(pos24, i_wdata_b, i_byte_en_b);
                32'd25: pos25 <= write_with_be(pos25, i_wdata_b, i_byte_en_b);
                32'd26: pos26 <= write_with_be(pos26, i_wdata_b, i_byte_en_b);
                32'd27: pos27 <= write_with_be(pos27, i_wdata_b, i_byte_en_b);
                32'd28: pos28 <= write_with_be(pos28, i_wdata_b, i_byte_en_b);
                32'd29: pos29 <= write_with_be(pos29, i_wdata_b, i_byte_en_b);

                32'd30: pos30 <= write_with_be(pos30, i_wdata_b, i_byte_en_b);
                32'd31: pos31 <= write_with_be(pos31, i_wdata_b, i_byte_en_b);
                32'd32: pos32 <= write_with_be(pos32, i_wdata_b, i_byte_en_b);
                32'd33: pos33 <= write_with_be(pos33, i_wdata_b, i_byte_en_b);
                32'd34: pos34 <= write_with_be(pos34, i_wdata_b, i_byte_en_b);
                32'd35: pos35 <= write_with_be(pos35, i_wdata_b, i_byte_en_b);
                32'd36: pos36 <= write_with_be(pos36, i_wdata_b, i_byte_en_b);
                32'd37: pos37 <= write_with_be(pos37, i_wdata_b, i_byte_en_b);
                32'd38: pos38 <= write_with_be(pos38, i_wdata_b, i_byte_en_b);
                32'd39: pos39 <= write_with_be(pos39, i_wdata_b, i_byte_en_b);

                32'd40: pos40 <= write_with_be(pos40, i_wdata_b, i_byte_en_b);
                32'd41: pos41 <= write_with_be(pos41, i_wdata_b, i_byte_en_b);
                32'd42: pos42 <= write_with_be(pos42, i_wdata_b, i_byte_en_b);
                32'd43: pos43 <= write_with_be(pos43, i_wdata_b, i_byte_en_b);
                32'd44: pos44 <= write_with_be(pos44, i_wdata_b, i_byte_en_b);
                32'd45: pos45 <= write_with_be(pos45, i_wdata_b, i_byte_en_b);
                32'd46: pos46 <= write_with_be(pos46, i_wdata_b, i_byte_en_b);
                32'd47: pos47 <= write_with_be(pos47, i_wdata_b, i_byte_en_b);
                32'd48: pos48 <= write_with_be(pos48, i_wdata_b, i_byte_en_b);
                32'd49: pos49 <= write_with_be(pos49, i_wdata_b, i_byte_en_b);

                32'd50 : pos50  <= write_with_be(pos50,  i_wdata_b, i_byte_en_b);
                32'd51 : pos51  <= write_with_be(pos51,  i_wdata_b, i_byte_en_b);
                32'd52 : pos52  <= write_with_be(pos52,  i_wdata_b, i_byte_en_b);
                32'd53 : pos53  <= write_with_be(pos53,  i_wdata_b, i_byte_en_b);
                32'd54 : pos54  <= write_with_be(pos54,  i_wdata_b, i_byte_en_b);
                32'd55 : pos55  <= write_with_be(pos55,  i_wdata_b, i_byte_en_b);
                32'd56 : pos56  <= write_with_be(pos56,  i_wdata_b, i_byte_en_b);
                32'd57 : pos57  <= write_with_be(pos57,  i_wdata_b, i_byte_en_b);
                32'd58 : pos58  <= write_with_be(pos58,  i_wdata_b, i_byte_en_b);
                32'd59 : pos59  <= write_with_be(pos59,  i_wdata_b, i_byte_en_b);

                32'd60 : pos60  <= write_with_be(pos60,  i_wdata_b, i_byte_en_b);
                32'd61 : pos61  <= write_with_be(pos61,  i_wdata_b, i_byte_en_b);
                32'd62 : pos62  <= write_with_be(pos62,  i_wdata_b, i_byte_en_b);
                32'd63 : pos63  <= write_with_be(pos63,  i_wdata_b, i_byte_en_b);
                32'd64 : pos64  <= write_with_be(pos64,  i_wdata_b, i_byte_en_b);
                32'd65 : pos65  <= write_with_be(pos65,  i_wdata_b, i_byte_en_b);
                32'd66 : pos66  <= write_with_be(pos66,  i_wdata_b, i_byte_en_b);
                32'd67 : pos67  <= write_with_be(pos67,  i_wdata_b, i_byte_en_b);
                32'd68 : pos68  <= write_with_be(pos68,  i_wdata_b, i_byte_en_b);
                32'd69 : pos69  <= write_with_be(pos69,  i_wdata_b, i_byte_en_b);

                32'd70 : pos70  <= write_with_be(pos70,  i_wdata_b, i_byte_en_b);
                32'd71 : pos71  <= write_with_be(pos71,  i_wdata_b, i_byte_en_b);
                32'd72 : pos72  <= write_with_be(pos72,  i_wdata_b, i_byte_en_b);
                32'd73 : pos73  <= write_with_be(pos73,  i_wdata_b, i_byte_en_b);
                32'd74 : pos74  <= write_with_be(pos74,  i_wdata_b, i_byte_en_b);
                32'd75 : pos75  <= write_with_be(pos75,  i_wdata_b, i_byte_en_b);
                32'd76 : pos76  <= write_with_be(pos76,  i_wdata_b, i_byte_en_b);
                32'd77 : pos77  <= write_with_be(pos77,  i_wdata_b, i_byte_en_b);
                32'd78 : pos78  <= write_with_be(pos78,  i_wdata_b, i_byte_en_b);
                32'd79 : pos79  <= write_with_be(pos79,  i_wdata_b, i_byte_en_b);

                32'd80 : pos80  <= write_with_be(pos80,  i_wdata_b, i_byte_en_b);
                32'd81 : pos81  <= write_with_be(pos81,  i_wdata_b, i_byte_en_b);
                32'd82 : pos82  <= write_with_be(pos82,  i_wdata_b, i_byte_en_b);
                32'd83 : pos83  <= write_with_be(pos83,  i_wdata_b, i_byte_en_b);
                32'd84 : pos84  <= write_with_be(pos84,  i_wdata_b, i_byte_en_b);
                32'd85 : pos85  <= write_with_be(pos85,  i_wdata_b, i_byte_en_b);
                32'd86 : pos86  <= write_with_be(pos86,  i_wdata_b, i_byte_en_b);
                32'd87 : pos87  <= write_with_be(pos87,  i_wdata_b, i_byte_en_b);
                32'd88 : pos88  <= write_with_be(pos88,  i_wdata_b, i_byte_en_b);
                32'd89 : pos89  <= write_with_be(pos89,  i_wdata_b, i_byte_en_b);

                32'd90 : pos90  <= write_with_be(pos90,  i_wdata_b, i_byte_en_b);
                32'd91 : pos91  <= write_with_be(pos91,  i_wdata_b, i_byte_en_b);
                32'd92 : pos92  <= write_with_be(pos92,  i_wdata_b, i_byte_en_b);
                32'd93 : pos93  <= write_with_be(pos93,  i_wdata_b, i_byte_en_b);
                32'd94 : pos94  <= write_with_be(pos94,  i_wdata_b, i_byte_en_b);
                32'd95 : pos95  <= write_with_be(pos95,  i_wdata_b, i_byte_en_b);
                32'd96 : pos96  <= write_with_be(pos96,  i_wdata_b, i_byte_en_b);
                32'd97 : pos97  <= write_with_be(pos97,  i_wdata_b, i_byte_en_b);
                32'd98 : pos98  <= write_with_be(pos98,  i_wdata_b, i_byte_en_b);
                32'd99 : pos99  <= write_with_be(pos99,  i_wdata_b, i_byte_en_b);

                32'd100 : pos100  <= write_with_be(pos100,  i_wdata_b, i_byte_en_b);
                32'd101 : pos101  <= write_with_be(pos101,  i_wdata_b, i_byte_en_b);
                32'd102 : pos102  <= write_with_be(pos102,  i_wdata_b, i_byte_en_b);
                32'd103 : pos103  <= write_with_be(pos103,  i_wdata_b, i_byte_en_b);
                32'd104 : pos104  <= write_with_be(pos104,  i_wdata_b, i_byte_en_b);
                32'd105 : pos105  <= write_with_be(pos105,  i_wdata_b, i_byte_en_b);
                32'd106 : pos106  <= write_with_be(pos106,  i_wdata_b, i_byte_en_b);
                32'd107 : pos107  <= write_with_be(pos107,  i_wdata_b, i_byte_en_b);
                32'd108 : pos108  <= write_with_be(pos108,  i_wdata_b, i_byte_en_b);
                32'd109 : pos109  <= write_with_be(pos109,  i_wdata_b, i_byte_en_b);

                32'd110 : pos110  <= write_with_be(pos110,  i_wdata_b, i_byte_en_b);
                32'd111 : pos111  <= write_with_be(pos111,  i_wdata_b, i_byte_en_b);
                32'd112 : pos112  <= write_with_be(pos112,  i_wdata_b, i_byte_en_b);
                32'd113 : pos113  <= write_with_be(pos113,  i_wdata_b, i_byte_en_b);
                32'd114 : pos114  <= write_with_be(pos114,  i_wdata_b, i_byte_en_b);
                32'd115 : pos115  <= write_with_be(pos115,  i_wdata_b, i_byte_en_b);
                32'd116 : pos116  <= write_with_be(pos116,  i_wdata_b, i_byte_en_b);
                32'd117 : pos117  <= write_with_be(pos117,  i_wdata_b, i_byte_en_b);
                32'd118 : pos118  <= write_with_be(pos118,  i_wdata_b, i_byte_en_b);
                32'd119 : pos119  <= write_with_be(pos119,  i_wdata_b, i_byte_en_b);

                32'd120 : pos120  <= write_with_be(pos120,  i_wdata_b, i_byte_en_b);
                32'd121 : pos121  <= write_with_be(pos121,  i_wdata_b, i_byte_en_b);
                32'd122 : pos122  <= write_with_be(pos122,  i_wdata_b, i_byte_en_b);
                32'd123 : pos123  <= write_with_be(pos123,  i_wdata_b, i_byte_en_b);
                32'd124 : pos124  <= write_with_be(pos124,  i_wdata_b, i_byte_en_b);
                32'd125 : pos125  <= write_with_be(pos125,  i_wdata_b, i_byte_en_b);
                32'd126 : pos126  <= write_with_be(pos126,  i_wdata_b, i_byte_en_b);
                32'd127 : pos127  <= write_with_be(pos127,  i_wdata_b, i_byte_en_b);
            endcase
        end
    end
end

// ----------------------------------------------------
// Combinational logic
// ----------------------------------------------------
always @(*) begin
    if (i_read_en) begin
        case (i_addr)
            32'd0 : o_rdata = pos0;
            32'd1 : o_rdata = pos1;
            32'd2 : o_rdata = pos2;
            32'd3 : o_rdata = pos3;
            32'd4 : o_rdata = pos4;
            32'd5 : o_rdata = pos5;
            32'd6 : o_rdata = pos6;
            32'd7 : o_rdata = pos7;
            32'd8 : o_rdata = pos8;
            32'd9 : o_rdata = pos9;

            32'd10: o_rdata = pos10;
            32'd11: o_rdata = pos11;
            32'd12: o_rdata = pos12;
            32'd13: o_rdata = pos13;
            32'd14: o_rdata = pos14;
            32'd15: o_rdata = pos15;
            32'd16: o_rdata = pos16;
            32'd17: o_rdata = pos17;
            32'd18: o_rdata = pos18;
            32'd19: o_rdata = pos19;

            32'd20: o_rdata = pos20;
            32'd21: o_rdata = pos21;
            32'd22: o_rdata = pos22;
            32'd23: o_rdata = pos23;
            32'd24: o_rdata = pos24;
            32'd25: o_rdata = pos25;
            32'd26: o_rdata = pos26;
            32'd27: o_rdata = pos27;
            32'd28: o_rdata = pos28;
            32'd29: o_rdata = pos29;

            32'd30: o_rdata = pos30;
            32'd31: o_rdata = pos31;
            32'd32: o_rdata = pos32;
            32'd33: o_rdata = pos33;
            32'd34: o_rdata = pos34;
            32'd35: o_rdata = pos35;
            32'd36: o_rdata = pos36;
            32'd37: o_rdata = pos37;
            32'd38: o_rdata = pos38;
            32'd39: o_rdata = pos39;

            32'd40: o_rdata = pos40;
            32'd41: o_rdata = pos41;
            32'd42: o_rdata = pos42;
            32'd43: o_rdata = pos43;
            32'd44: o_rdata = pos44;
            32'd45: o_rdata = pos45;
            32'd46: o_rdata = pos46;
            32'd47: o_rdata = pos47;
            32'd48: o_rdata = pos48;
            32'd49: o_rdata = pos49;

            32'd50 : o_rdata = pos50;
            32'd51 : o_rdata = pos51;
            32'd52 : o_rdata = pos52;
            32'd53 : o_rdata = pos53;
            32'd54 : o_rdata = pos54;
            32'd55 : o_rdata = pos55;
            32'd56 : o_rdata = pos56;
            32'd57 : o_rdata = pos57;
            32'd58 : o_rdata = pos58;
            32'd59 : o_rdata = pos59;

            32'd60 : o_rdata = pos60;
            32'd61 : o_rdata = pos61;
            32'd62 : o_rdata = pos62;
            32'd63 : o_rdata = pos63;
            32'd64 : o_rdata = pos64;
            32'd65 : o_rdata = pos65;
            32'd66 : o_rdata = pos66;
            32'd67 : o_rdata = pos67;
            32'd68 : o_rdata = pos68;
            32'd69 : o_rdata = pos69;

            32'd70 : o_rdata = pos70;
            32'd71 : o_rdata = pos71;
            32'd72 : o_rdata = pos72;
            32'd73 : o_rdata = pos73;
            32'd74 : o_rdata = pos74;
            32'd75 : o_rdata = pos75;
            32'd76 : o_rdata = pos76;
            32'd77 : o_rdata = pos77;
            32'd78 : o_rdata = pos78;
            32'd79 : o_rdata = pos79;

            32'd80 : o_rdata = pos80;
            32'd81 : o_rdata = pos81;
            32'd82 : o_rdata = pos82;
            32'd83 : o_rdata = pos83;
            32'd84 : o_rdata = pos84;
            32'd85 : o_rdata = pos85;
            32'd86 : o_rdata = pos86;
            32'd87 : o_rdata = pos87;
            32'd88 : o_rdata = pos88;
            32'd89 : o_rdata = pos89;

            32'd90 : o_rdata = pos90;
            32'd91 : o_rdata = pos91;
            32'd92 : o_rdata = pos92;
            32'd93 : o_rdata = pos93;
            32'd94 : o_rdata = pos94;
            32'd95 : o_rdata = pos95;
            32'd96 : o_rdata = pos96;
            32'd97 : o_rdata = pos97;
            32'd98 : o_rdata = pos98;
            32'd99 : o_rdata = pos99;

            32'd100 : o_rdata = pos100;
            32'd101 : o_rdata = pos101;
            32'd102 : o_rdata = pos102;
            32'd103 : o_rdata = pos103;
            32'd104 : o_rdata = pos104;
            32'd105 : o_rdata = pos105;
            32'd106 : o_rdata = pos106;
            32'd107 : o_rdata = pos107;
            32'd108 : o_rdata = pos108;
            32'd109 : o_rdata = pos109;

            32'd110 : o_rdata = pos110;
            32'd111 : o_rdata = pos111;
            32'd112 : o_rdata = pos112;
            32'd113 : o_rdata = pos113;
            32'd114 : o_rdata = pos114;
            32'd115 : o_rdata = pos115;
            32'd116 : o_rdata = pos116;
            32'd117 : o_rdata = pos117;
            32'd118 : o_rdata = pos118;
            32'd119 : o_rdata = pos119;

            32'd120 : o_rdata = pos120;
            32'd121 : o_rdata = pos121;
            32'd122 : o_rdata = pos122;
            32'd123 : o_rdata = pos123;
            32'd124 : o_rdata = pos124;
            32'd125 : o_rdata = pos125;
            32'd126 : o_rdata = pos126;
            32'd127 : o_rdata = pos127;

            default: o_rdata = 32'b0;
        endcase
    end

    if (i_read_en_b) begin
        case (i_addr_b)
            32'd0 : o_rdata_b = pos0;
            32'd1 : o_rdata_b = pos1;
            32'd2 : o_rdata_b = pos2;
            32'd3 : o_rdata_b = pos3;
            32'd4 : o_rdata_b = pos4;
            32'd5 : o_rdata_b = pos5;
            32'd6 : o_rdata_b = pos6;
            32'd7 : o_rdata_b = pos7;
            32'd8 : o_rdata_b = pos8;
            32'd9 : o_rdata_b = pos9;

            32'd10: o_rdata_b = pos10;
            32'd11: o_rdata_b = pos11;
            32'd12: o_rdata_b = pos12;
            32'd13: o_rdata_b = pos13;
            32'd14: o_rdata_b = pos14;
            32'd15: o_rdata_b = pos15;
            32'd16: o_rdata_b = pos16;
            32'd17: o_rdata_b = pos17;
            32'd18: o_rdata_b = pos18;
            32'd19: o_rdata_b = pos19;

            32'd20: o_rdata_b = pos20;
            32'd21: o_rdata_b = pos21;
            32'd22: o_rdata_b = pos22;
            32'd23: o_rdata_b = pos23;
            32'd24: o_rdata_b = pos24;
            32'd25: o_rdata_b = pos25;
            32'd26: o_rdata_b = pos26;
            32'd27: o_rdata_b = pos27;
            32'd28: o_rdata_b = pos28;
            32'd29: o_rdata_b = pos29;

            32'd30: o_rdata_b = pos30;
            32'd31: o_rdata_b = pos31;
            32'd32: o_rdata_b = pos32;
            32'd33: o_rdata_b = pos33;
            32'd34: o_rdata_b = pos34;
            32'd35: o_rdata_b = pos35;
            32'd36: o_rdata_b = pos36;
            32'd37: o_rdata_b = pos37;
            32'd38: o_rdata_b = pos38;
            32'd39: o_rdata_b = pos39;

            32'd40: o_rdata_b = pos40;
            32'd41: o_rdata_b = pos41;
            32'd42: o_rdata_b = pos42;
            32'd43: o_rdata_b = pos43;
            32'd44: o_rdata_b = pos44;
            32'd45: o_rdata_b = pos45;
            32'd46: o_rdata_b = pos46;
            32'd47: o_rdata_b = pos47;
            32'd48: o_rdata_b = pos48;
            32'd49: o_rdata_b = pos49;

            32'd50 : o_rdata_b = pos50;
            32'd51 : o_rdata_b = pos51;
            32'd52 : o_rdata_b = pos52;
            32'd53 : o_rdata_b = pos53;
            32'd54 : o_rdata_b = pos54;
            32'd55 : o_rdata_b = pos55;
            32'd56 : o_rdata_b = pos56;
            32'd57 : o_rdata_b = pos57;
            32'd58 : o_rdata_b = pos58;
            32'd59 : o_rdata_b = pos59;

            32'd60 : o_rdata_b = pos60;
            32'd61 : o_rdata_b = pos61;
            32'd62 : o_rdata_b = pos62;
            32'd63 : o_rdata_b = pos63;
            32'd64 : o_rdata_b = pos64;
            32'd65 : o_rdata_b = pos65;
            32'd66 : o_rdata_b = pos66;
            32'd67 : o_rdata_b = pos67;
            32'd68 : o_rdata_b = pos68;
            32'd69 : o_rdata_b = pos69;

            32'd70 : o_rdata_b = pos70;
            32'd71 : o_rdata_b = pos71;
            32'd72 : o_rdata_b = pos72;
            32'd73 : o_rdata_b = pos73;
            32'd74 : o_rdata_b = pos74;
            32'd75 : o_rdata_b = pos75;
            32'd76 : o_rdata_b = pos76;
            32'd77 : o_rdata_b = pos77;
            32'd78 : o_rdata_b = pos78;
            32'd79 : o_rdata_b = pos79;

            32'd80 : o_rdata_b = pos80;
            32'd81 : o_rdata_b = pos81;
            32'd82 : o_rdata_b = pos82;
            32'd83 : o_rdata_b = pos83;
            32'd84 : o_rdata_b = pos84;
            32'd85 : o_rdata_b = pos85;
            32'd86 : o_rdata_b = pos86;
            32'd87 : o_rdata_b = pos87;
            32'd88 : o_rdata_b = pos88;
            32'd89 : o_rdata_b = pos89;

            32'd90 : o_rdata_b = pos90;
            32'd91 : o_rdata_b = pos91;
            32'd92 : o_rdata_b = pos92;
            32'd93 : o_rdata_b = pos93;
            32'd94 : o_rdata_b = pos94;
            32'd95 : o_rdata_b = pos95;
            32'd96 : o_rdata_b = pos96;
            32'd97 : o_rdata_b = pos97;
            32'd98 : o_rdata_b = pos98;
            32'd99 : o_rdata_b = pos99;

            32'd100 : o_rdata_b = pos100;
            32'd101 : o_rdata_b = pos101;
            32'd102 : o_rdata_b = pos102;
            32'd103 : o_rdata_b = pos103;
            32'd104 : o_rdata_b = pos104;
            32'd105 : o_rdata_b = pos105;
            32'd106 : o_rdata_b = pos106;
            32'd107 : o_rdata_b = pos107;
            32'd108 : o_rdata_b = pos108;
            32'd109 : o_rdata_b = pos109;

            32'd110 : o_rdata_b = pos110;
            32'd111 : o_rdata_b = pos111;
            32'd112 : o_rdata_b = pos112;
            32'd113 : o_rdata_b = pos113;
            32'd114 : o_rdata_b = pos114;
            32'd115 : o_rdata_b = pos115;
            32'd116 : o_rdata_b = pos116;
            32'd117 : o_rdata_b = pos117;
            32'd118 : o_rdata_b = pos118;
            32'd119 : o_rdata_b = pos119;

            32'd120 : o_rdata_b = pos120;
            32'd121 : o_rdata_b = pos121;
            32'd122 : o_rdata_b = pos122;
            32'd123 : o_rdata_b = pos123;
            32'd124 : o_rdata_b = pos124;
            32'd125 : o_rdata_b = pos125;
            32'd126 : o_rdata_b = pos126;
            32'd127 : o_rdata_b = pos127;

            default: o_rdata_b = 32'b0;
        endcase
    end
end
endmodule

//-------------------------------------------------------------------
//                            D C A C H E
//-------------------------------------------------------------------
