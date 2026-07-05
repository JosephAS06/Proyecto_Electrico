// ------------------------------------------------------------------------------------------------------------
// -- File Name        : RegisterFile.v
// -- Module Name      : RF
// -- Developer        : David Rodriguez, Kristhel Quesada
// --
// -- Description      : Register File
// --                    [x] Asynchronous read
// --                    [ ] Synchronous write
// --
// -- Tested on        :
// -- Last modified on :
// -- Notes            :
// --
// -- Copyright        : Refer to LICENSE.md.
// ------------------------------------------------------------------------------------------------------------

module regFile #(
   parameter REGPC_INIT =  32'h0000_0000,    // Init PC on reset
   parameter XLEN = 32,
   parameter ILEN = 32
)(
   // General
   input wire        CLK, RST,               // Clock and Reset

   // Interface DU-RU
   input wire [4:0]  i_rs1_addr,             // Address of the rs1 register
   input wire [4:0]  i_rs2_addr,             // Address of the rs2 register

   // Interface RU-EXU
   output reg [31:0] o_rs1_data,             // Data of the rs1 register
   output reg [31:0] o_rs2_data,             // Data of the rs2 register

   // Interface MEM-RU
   input wire        i_we,                   // Flag to enable writing
   input wire [4:0]  i_wb_rf_addr,           // Address of the rd register
   input wire [31:0] i_wb_rf_rslt            // Data to store in the rd register
);

// Cable to conect x0 to GND. To avoid changes on x0.
wire [XLEN-1:0] x0;
assign x0 = 32'h0000_0000;

// Definition of the 31 registers
reg [XLEN-1:0] x1;
reg [XLEN-1:0] x2;
reg [XLEN-1:0] x3;
reg [XLEN-1:0] x4;
reg [XLEN-1:0] x5;
reg [XLEN-1:0] x6;
reg [XLEN-1:0] x7;
reg [XLEN-1:0] x8;
reg [XLEN-1:0] x9;
reg [XLEN-1:0] x10;
reg [XLEN-1:0] x11;
reg [XLEN-1:0] x12;
reg [XLEN-1:0] x13;
reg [XLEN-1:0] x14;
reg [XLEN-1:0] x15;
reg [XLEN-1:0] x16;
reg [XLEN-1:0] x17;
reg [XLEN-1:0] x18;
reg [XLEN-1:0] x19;
reg [XLEN-1:0] x20;
reg [XLEN-1:0] x21;
reg [XLEN-1:0] x22;
reg [XLEN-1:0] x23;
reg [XLEN-1:0] x24;
reg [XLEN-1:0] x25;
reg [XLEN-1:0] x26;
reg [XLEN-1:0] x27;
reg [XLEN-1:0] x28;
reg [XLEN-1:0] x29;
reg [XLEN-1:0] x30;
reg [XLEN-1:0] x31;


// ======================================================================
//  Sequential Logic
// ======================================================================
always @(posedge CLK) begin
   if (RST) begin
      x1  = 32'h0000_0000;    // ra
      x2  = 32'h0000_01FC;    // [address] SP = 0x1FC
      x3  = 32'h0000_0003;    // gp 3
      x4  = 32'h0000_0004;    // tp 4
      x5  = 32'h0000_0005;    // t0 5
      x6  = 32'h0000_0006;    // t1
      x7  = 32'h0000_0007;    // t2
      x8  = 32'h0000_0008;    // [address] s0
      x9  = 32'h0000_0009;    // s1
      x10 = 32'h0000_000a;    // a0
      x11 = 32'h0000_000b;    // a1
      x12 = 32'h0000_000c;    // a2
      x13 = 32'h0000_000d;    // a3
      x14 = 32'h0000_000e;    // a4
      x15 = 32'h0000_000f;    // a5
      x16 = 32'h0000_0010;    // a6
      x17 = 32'h0000_0011;    // a7
      x18 = 32'h0000_0012;    // s2
      x19 = 32'h0000_0013;    // s3
      x20 = 32'h0000_0014;    // s4
      x21 = 32'h0000_0015;    // s5
      x22 = 32'h0000_0016;    // s6
      x23 = 32'h0000_0017;    // s7
      x24 = 32'h0000_0018;    // s8
      x25 = 32'h0000_0019;    // s9
      x26 = 32'h0000_001a;    // s10
      x27 = 32'h0000_001b;    // s11
      x28 = 32'h0000_001c;    // t3
      x29 = 32'h0000_001d;    // t4
      x30 = 32'h0000_001e;    // t5
      x31 = 32'h0000_001f;    // t6
   end else begin             // Cambio
      if (i_we) begin
         case (i_wb_rf_addr)
            5'b00001 : x1  <= i_wb_rf_rslt;
            5'b00010 : x2  <= i_wb_rf_rslt;
            5'b00011 : x3  <= i_wb_rf_rslt;
            5'b00100 : x4  <= i_wb_rf_rslt;
            5'b00101 : x5  <= i_wb_rf_rslt;
            5'b00110 : x6  <= i_wb_rf_rslt;
            5'b00111 : x7  <= i_wb_rf_rslt;
            5'b01000 : x8  <= i_wb_rf_rslt;
            5'b01001 : x9  <= i_wb_rf_rslt;
            5'b01010 : x10 <= i_wb_rf_rslt;
            5'b01011 : x11 <= i_wb_rf_rslt;
            5'b01100 : x12 <= i_wb_rf_rslt;
            5'b01101 : x13 <= i_wb_rf_rslt;
            5'b01110 : x14 <= i_wb_rf_rslt;
            5'b01111 : x15 <= i_wb_rf_rslt;
            5'b10000 : x16 <= i_wb_rf_rslt;
            5'b10001 : x17 <= i_wb_rf_rslt;
            5'b10010 : x18 <= i_wb_rf_rslt;
            5'b10011 : x19 <= i_wb_rf_rslt;
            5'b10100 : x20 <= i_wb_rf_rslt;
            5'b10101 : x21 <= i_wb_rf_rslt;
            5'b10110 : x22 <= i_wb_rf_rslt;
            5'b10111 : x23 <= i_wb_rf_rslt;
            5'b11000 : x24 <= i_wb_rf_rslt;
            5'b11001 : x25 <= i_wb_rf_rslt;
            5'b11010 : x26 <= i_wb_rf_rslt;
            5'b11011 : x27 <= i_wb_rf_rslt;
            5'b11100 : x28 <= i_wb_rf_rslt;
            5'b11101 : x29 <= i_wb_rf_rslt;
            5'b11110 : x30 <= i_wb_rf_rslt;
            5'b11111 : x31 <= i_wb_rf_rslt;
         endcase
      end
   end
end

// ------------------------------------
// Read Logic
// ------------------------------------
always @(*) begin // Cambio
   case (i_rs1_addr)
      5'b00000 : o_rs1_data = x0;  // Cambio
      5'b00001 : o_rs1_data = x1;  // Cambio
      5'b00010 : o_rs1_data = x2;  // Cambio
      5'b00011 : o_rs1_data = x3;  // Cambio
      5'b00100 : o_rs1_data = x4;  // Cambio
      5'b00101 : o_rs1_data = x5;  // Cambio
      5'b00110 : o_rs1_data = x6;  // Cambio
      5'b00111 : o_rs1_data = x7;  // Cambio
      5'b01000 : o_rs1_data = x8;  // Cambio
      5'b01001 : o_rs1_data = x9;  // Cambio
      5'b01010 : o_rs1_data = x10; // Cambio
      5'b01011 : o_rs1_data = x11; // Cambio
      5'b01100 : o_rs1_data = x12; // Cambio
      5'b01101 : o_rs1_data = x13; // Cambio
      5'b01110 : o_rs1_data = x14; // Cambio
      5'b01111 : o_rs1_data = x15; // Cambio
      5'b10000 : o_rs1_data = x16; // Cambio
      5'b10001 : o_rs1_data = x17; // Cambio
      5'b10010 : o_rs1_data = x18; // Cambio
      5'b10011 : o_rs1_data = x19; // Cambio
      5'b10100 : o_rs1_data = x20; // Cambio
      5'b10101 : o_rs1_data = x21; // Cambio
      5'b10110 : o_rs1_data = x22; // Cambio
      5'b10111 : o_rs1_data = x23; // Cambio
      5'b11000 : o_rs1_data = x24; // Cambio
      5'b11001 : o_rs1_data = x25; // Cambio
      5'b11010 : o_rs1_data = x26; // Cambio
      5'b11011 : o_rs1_data = x27; // Cambio
      5'b11100 : o_rs1_data = x28; // Cambio
      5'b11101 : o_rs1_data = x29; // Cambio
      5'b11110 : o_rs1_data = x30; // Cambio
      5'b11111 : o_rs1_data = x31; // Cambio
      default  : o_rs1_data = x0;  // Cambio
   endcase

   case (i_rs2_addr)
      5'b00000 : o_rs2_data = x0;  // Cambio
      5'b00001 : o_rs2_data = x1;  // Cambio
      5'b00010 : o_rs2_data = x2;  // Cambio
      5'b00011 : o_rs2_data = x3;  // Cambio
      5'b00100 : o_rs2_data = x4;  // Cambio
      5'b00101 : o_rs2_data = x5;  // Cambio
      5'b00110 : o_rs2_data = x6;  // Cambio
      5'b00111 : o_rs2_data = x7;  // Cambio
      5'b01000 : o_rs2_data = x8;  // Cambio
      5'b01001 : o_rs2_data = x9;  // Cambio
      5'b01010 : o_rs2_data = x10; // Cambio
      5'b01011 : o_rs2_data = x11; // Cambio
      5'b01100 : o_rs2_data = x12; // Cambio
      5'b01101 : o_rs2_data = x13; // Cambio
      5'b01110 : o_rs2_data = x14; // Cambio
      5'b01111 : o_rs2_data = x15; // Cambio
      5'b10000 : o_rs2_data = x16; // Cambio
      5'b10001 : o_rs2_data = x17; // Cambio
      5'b10010 : o_rs2_data = x18; // Cambio
      5'b10011 : o_rs2_data = x19; // Cambio
      5'b10100 : o_rs2_data = x20; // Cambio
      5'b10101 : o_rs2_data = x21; // Cambio
      5'b10110 : o_rs2_data = x22; // Cambio
      5'b10111 : o_rs2_data = x23; // Cambio
      5'b11000 : o_rs2_data = x24; // Cambio
      5'b11001 : o_rs2_data = x25; // Cambio
      5'b11010 : o_rs2_data = x26; // Cambio
      5'b11011 : o_rs2_data = x27; // Cambio
      5'b11100 : o_rs2_data = x28; // Cambio
      5'b11101 : o_rs2_data = x29; // Cambio
      5'b11110 : o_rs2_data = x30; // Cambio
      5'b11111 : o_rs2_data = x31; // Cambio
      default  : o_rs2_data = x0;  // Cambio
   endcase
end

endmodule
//---------------------------------------------------------------------------------------------------------------
//                                    R E G I S T E R     F I L E
//---------------------------------------------------------------------------------------------------------------
