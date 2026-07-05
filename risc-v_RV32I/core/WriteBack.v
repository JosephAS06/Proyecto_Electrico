// ------------------------------------------------------------------------------------------------------------
// -- File Name        : WriteBackUnit.v
// -- Module Name      : wb_unit
// -- Developer        : Kristhel Quesada
// --
// -- Description      : Write Back Unit
// --                    [ ] Write $rd result into RF
// --                    [ ] Multiplexor to choose from source: MEM, EXU or FU (jal)
// --                    [ ] Write management to RF: write_enable but never in x0
// --
// -- Tested on        :
// -- Last modified on :
// -- Notes            :
// --
// -- Copyright        : Refer to LICENSE.md.
// ------------------------------------------------------------------------------------------------------------

module wb_unit #(
   parameter REGPC_INIT =  32'h0000_0000,    // Init PC on reset
   parameter XLEN = 32,
   parameter ILEN = 32
)(
   // General
   input clk, rst,

   // From dcache
   input wire [31:0] i_dmem_data,

   // From mem_unit
   input wire [31:0] i_alu_result,
   input wire [4:0]  i_rd_addr,
   input wire [1:0]  i_wb_sel,
   input wire        i_write_on_reg,

   // Outputs to RF
   output reg [31:0] o_write_data,
   output reg [4:0]  o_rd_addr,
   output reg        o_wen
);


// ====================================================================
//  MAIN LOGIC
// ====================================================================

/*
 * ---------------------------------------------------------
 * Combinational logic
 * ---------------------------------------------------------
*/
always @(*) begin
   if (rst) begin
      o_write_data = 0;
      o_rd_addr    = 0;
      o_wen        = 0;
   end else if (i_write_on_reg) begin
      case (i_wb_sel)
         1'b0:    o_write_data = i_alu_result;
         1'b1:    o_write_data = i_dmem_data;
         default: o_write_data = i_alu_result;
      endcase
      o_rd_addr = i_rd_addr;
      o_wen     = 1'b1;
   end else begin
      o_write_data = 0;
      o_rd_addr    = 0;
      o_wen        = 1'b0;
   end
end

endmodule
