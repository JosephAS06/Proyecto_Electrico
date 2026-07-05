// ----------------------------------------------------------------------------------------
// -- File Name        : MemoryUnit.v
// -- Module Name      : mem_unit
// -- Developer        : Kristhel Quesada, David Rodriguez
// --
// -- Description      : Memory Unit
// --                    [ ] Memory Access through interface using control signals
// --                    [ ] Queue logic when writing with priorization logic
// --                    [ ] Support diffenrent sizes word, half and byte
// --                    [ ] Sign extension when needed
// --
// -- Tested on        :
// -- Last modified on :
// -- Notes            :
// --
// -- Copyright        : Refer to LICENSE.md.
// ----------------------------------------------------------------------------------------

module mem_unit (
   input wire        clk,
   input wire        reset,

   // Inputs from EXECUTE
   input wire [31:0] i_alu_result,      // Address or simple value
   input wire [31:0] i_rs2_data,        // Data of rs2 for SB, SH or SW
   input wire [4:0]  i_rd_addr,         // Address of rd register
   input wire [1:0]  i_data_size,       // MUX Selector to interpret byte, half or word
   input wire        i_is_unsigned,     // Flag for signed interpretation
   input wire        i_dmem_write,      // Enables SB, SH, SW
   input wire        i_dmem_read,       // Enables LB, LH, LW (un)signed
   input wire        i_write_on_reg,    // Enables writing to RF

   // Outputs to WriteBack
   output reg [31:0] o_alu_result,      // ALU result to write on WB
   output reg [4:0]  o_rd_addr,         // Address of rd register
   output reg [1:0]  o_wb_sel,          // MUX Selector (alu/mem/pc+something)
   output reg [1:0]  o_data_size,       // MUX Selector to interpret byte, half or word
   output reg        o_write_on_reg,    // Enables writing to RF
   output reg        o_is_unsigned,     // Flags to interpret the loaded data

   // Outputs to DCache
   output reg [31:0] o_write_data,      // Data to write on mem
   output reg [31:0] o_dmem_address,    // Address to write in mem
   output reg [3:0]  o_byte_en,         // Flags to enable byte write
   output reg        o_dmem_read,       // Flag to read from mem
   output reg        o_dmem_write       // Flag to write on mem
);

//==========================================================
// LOCAL PARAMETERS
//==========================================================
localparam BYTE = 2'b00;
localparam HALF = 2'b01;
localparam WORD = 2'b11;


//==========================================================
// FUNCTIONS
//==========================================================
function [3:0] byte_en_cod;
   input [1:0] data_size;

   begin
      if (data_size == BYTE) byte_en_cod = 4'b0001;
      else if (data_size == HALF) byte_en_cod = 4'b0011;
      else if (data_size == WORD) byte_en_cod = 4'b1111;
   end
endfunction



// ====================================================================
//  MAIN LOGIC
// ====================================================================

/*
 * ---------------------------------------------------------
 * Sequential logic
 * ---------------------------------------------------------
*/
always @(posedge clk or posedge reset) begin
   if (reset) begin
      o_wb_sel        <= 0;
      o_rd_addr       <= 0;
      o_alu_result    <= 0;
      o_write_on_reg  <= 0;

   end else begin
      // Buff signals to WB
      o_wb_sel        <= i_dmem_read;
      o_rd_addr       <= i_rd_addr;
      o_alu_result    <= i_alu_result;
      o_write_on_reg  <= i_write_on_reg;
   end
end

/*
 * ---------------------------------------------------------
 * Combinational logic
 * ---------------------------------------------------------
*/
always @(*) begin
   if (reset) begin
      o_write_data   = 0;
      o_dmem_address = 0;
      o_dmem_write   = 0;
      o_dmem_read    = 0;
      o_byte_en      = 0;
      o_data_size    = 0;
      o_is_unsigned  = 0;
   end else begin
      o_data_size    = i_data_size;
      o_is_unsigned  = i_is_unsigned;
      o_dmem_write   = i_dmem_write;
      o_dmem_read    = i_dmem_read;
      o_write_data   = i_rs2_data;
      o_dmem_address = i_alu_result;
      o_byte_en      = byte_en_cod(i_data_size);
   end
end


endmodule
//-----------------------------------------------------------------------------------------
//                              M E M O R Y   U N I T
//-----------------------------------------------------------------------------------------
