// ------------------------------------------------------------------------------------------------------------
// -- File Name        : ExecuteUnit.v
// -- Module Name      : exu
// -- Developer        : Kristhel Quesada, David Rodriguez
// --
// -- Description      : Execute Unit
// --                    [ ] Instantiate and design of ALU
// --                    [ ] Calculate memory addresses using ALU
// --                    [ ] Evaluate branch conditions using Branch Unit
// --                    [ ] Data forwarding from posterior stages (EX/MEM/WB)
// --                    [ ] Multiplication and division (future extension)
// --
// -- Tested on        :
// -- Last modified on :
// -- Notes            :
// --
// -- Copyright        : Refer to LICENSE.md.
// ------------------------------------------------------------------------------------------------------------

module exu #(
   parameter REGPC_INIT =  32'h0000_0000,    // Init PC on reset
   parameter XLEN = 32,
   parameter ILEN = 32
)(
   // General
   input wire              CLK, RST,         // Clock and Reset

   // ------------ INPUTS ------------
   // From RF
   input wire [31:0] i_rs1_data,             // Data of the rs1 register
   input wire [31:0] i_rs2_data,             // Data of the rs2 register

   // From DecodeUnit -> ALU/BU
   input wire [31:0] i_pc,
   input wire [31:0] i_imm,
   input wire        i_is_unsigned,

   // From DecodeUnit -> BU
   input wire        i_rs1_2_pc,
   input wire        i_is_branch,
   input wire        i_is_type_u,
   input wire        i_dual_op,

   // From DecodeUnit -> BU/MEM
   input wire [1:0]  i_data_size,

   // From DecodeUnit -> ALU
   input wire [3:0]  i_alu_op,
   input wire        i_alu_src_rs2,

   // From DecodeUnit -> MEM
   input wire        i_dmem_write,
   input wire        i_dmem_read,

   // From DecodeUnit -> WB
   input wire [4:0]  i_rd_addr,
   input wire        i_write_on_reg,

   // ------------ OUPUTS ------------
   // Used on FU
   output reg [31:0] o_pc_upd,
   output reg        o_take_br,
   output reg        o_take_jmp,

   // Used on MEM
   output reg [31:0] o_rs2_data,
   output reg [1:0]  o_data_size,
   output reg        o_dmem_write,
   output reg        o_is_unsigned,

   // Used on MEM/WB
   output reg [31:0] o_result,        // Value calculated in EXU
   output reg [31:0] o_result2,        // Value calculated in EXU
   output reg        o_dmem_read,     // Read enabler and WB-MUX selector

   // Used on WB
   output reg [4:0]  o_rd_addr,
   output reg        o_write_on_reg
);

//===============================================================================================================
// Local Parameters
//===============================================================================================================

 localparam b_equal = 2'b00;
 localparam b_not_equal = 2'b01;
 localparam b_less_than = 2'b10;
 localparam b_greater_equal = 2'b11;

//===============================================================================================================
// Intermidiate Signals
//===============================================================================================================
   reg equal;                                      // Flags resulting from the comparison
   reg less_than;
   reg less_than_unsigned;

   reg [31:0] sum_pc;                              // Input for the sum_pc block

   reg [31:0] pc_upd;                              // Pc updated

   reg takebranch;                                 // Flags to warn that a jump or a branch is going to be taken
   reg takejump;

   reg [31:0] second_operand_alu;                  // Second operand going to the aritmethic-logical blocks

   reg [31:0] first_operand_sll;                   // First operand going to the sll block
   reg [31:0] second_operand_sll;                  // First operand going to the sll block
   reg [31:0] sll_out;                             // SLL output

   reg [31:0] pc_storer;                           // Offset to add to the pc to be stored

   reg branch_taken_reg;                           // Reg to know if a branch is just taken



//===============================================================================================================
// Combinational Logic
//===============================================================================================================

// Combinational logic correspondient to the Branch Unit

always @(*) begin                          // Comparer block
   if (i_is_branch) begin
      equal                            = ($signed(i_rs1_data) == $signed(i_rs2_data));
      less_than                        = ($signed(i_rs1_data) <  $signed(i_rs2_data));
      less_than_unsigned               = (i_rs1_data < i_rs2_data);
   end
end

always @(*) begin                          // sum_pc MUX
   if (i_rs1_2_pc) begin
      sum_pc = i_rs1_data;
   end else begin
      sum_pc = i_pc;
   end
end

always @(*) begin                          // sum_pc
   if (i_dual_op && !i_is_type_u) begin
      pc_upd = $signed(i_imm) + $signed(sum_pc);
   end
end


always @(*) begin                          // BU combinational (calc the flags to decide the branch)

      if (i_is_branch) begin               // Deleted dual_op with i_is_branch is more than enough?

         takejump = 0;

         if (i_data_size == b_equal && equal == 1) begin                                                       // Case equal
            takebranch = 1;
         end else if (i_data_size == b_equal && equal == 0) begin
            takebranch = 0;
         end

         if (i_data_size == b_not_equal && equal == 0) begin                                                   // Case not equal
            takebranch = 1;
         end else if (i_data_size == b_not_equal && equal == 1) begin
            takebranch = 0;
         end

         if (i_data_size == b_less_than && less_than == 1 && i_is_unsigned == 0) begin                         // Case less than
            takebranch = 1;
         end else if(i_data_size == b_less_than && less_than == 0 && i_is_unsigned == 0) begin
            takebranch = 0;
         end

         if (i_data_size == b_greater_equal && less_than == 0 && i_is_unsigned == 0) begin                     // Case greater equal
            takebranch = 1;
         end else if(i_data_size == b_greater_equal && less_than == 1 && i_is_unsigned == 0) begin
            takebranch = 0;
         end

         if (i_data_size == b_less_than && less_than_unsigned == 1 && i_is_unsigned == 1) begin                // Case less than unsigned
            takebranch = 1;
         end else if (i_data_size == b_less_than && less_than_unsigned == 0 && i_is_unsigned == 1) begin
            takebranch = 0;
         end

         if (i_data_size == b_greater_equal && less_than_unsigned == 0 && i_is_unsigned == 1) begin            // Case greater equal unsigned
            takebranch = 1;
         end else if (i_data_size == b_greater_equal && less_than_unsigned == 1 && i_is_unsigned == 1) begin   // Case greater equal unsigned
            takebranch = 0;
         end

      end else if (i_dual_op && i_is_branch == 0 && i_is_type_u == 0) begin
         takejump   = 1;                        // If the opcode is a Jump, buffer the pc inconditional
         takebranch = 0;

      end else begin
         takebranch = 0;
         takejump   = 0;
      end

end

// Combinational logic correspondient to the ALU

always @(*) begin                          // Second operand ALU MUX
   if (i_alu_src_rs2) begin
      second_operand_alu = i_rs2_data;
   end else begin
      second_operand_alu = i_imm;
   end
end

always @(*) begin                          // First operand SLL MUX
   if (i_is_type_u) begin
      first_operand_sll = i_imm;
   end else begin
      first_operand_sll = i_rs1_data;
   end
end

always @(*) begin                          // Second operand SLL MUX
   if (i_is_type_u) begin
      second_operand_sll = 12;
   end else begin
      second_operand_sll = second_operand_alu;
   end
end

always @(*) begin                          // PC storer MUX
   if (takejump) begin
      pc_storer = 4;
   end else begin
      pc_storer = sll_out;
   end
end

always @(*) begin                          // SLL combinational
   sll_out = first_operand_sll << second_operand_sll;
end


//===============================================================================================================
// Secuential Logic
//===============================================================================================================

// Secuential logic correspondient to the Branch Unit

always @(posedge CLK) begin                          // BU secuential (buffer the pc updated and the flag to the fetch)
   if (RST) begin
      o_pc_upd        <= 0;
      o_take_br       <= 0;
      o_take_jmp      <= 0;

   end else begin

      if (takebranch) begin
         o_pc_upd <= pc_upd;
         o_take_br <= 1;
         o_take_jmp <= 0;

      end else if (takejump) begin
         o_pc_upd <= pc_upd;
         o_take_br <= 0;
         o_take_jmp <= 1;

      end else begin
         o_pc_upd <= 0;
         o_take_br <= 0;
         o_take_jmp <= 0;
      end
   end
end

// Secuential logic correspondient to the ALU

always @(posedge CLK) begin                            // ALU secuential (Resulting data going to the memory and next steps)

   if (RST) begin
      o_result        <= 0;

   end else begin

      if (takebranch || o_take_br) begin              // Makes a flush to the outputs
         o_result     <= 0;

      end else begin

         case (i_alu_op)

         4'b0011: begin                                                                // SLL
            if (i_dual_op) begin
               o_result <= $signed(i_pc) + $signed(pc_storer);         // If dual_op = 1, means that the instruction is an AUIPC
            end else begin
               o_result <= sll_out;               // If dual_op = 0, means that the instruction is a simple SLL or LUI and not an AUIPC
            end
         end

         4'b0001:                                                                      // SUB
            o_result <= i_rs1_data - second_operand_alu;

         4'b0000:                                                                      // ADD
            o_result <= i_rs1_data + second_operand_alu;

         4'b0010:                                                                      // SLT
            o_result <= ($signed(i_rs1_data) < $signed(second_operand_alu))? 1:0;

         4'b0110:                                                                      // SLTU
            o_result <= (i_rs1_data < second_operand_alu)? 1:0;

         4'b0111:                                                                      // XOR
            o_result <= i_rs1_data ^ second_operand_alu;

         4'b0101:                                                                      // SRL
            o_result <= i_rs1_data >> second_operand_alu;

         4'b0100:                                                                      // SRA
            o_result <= $signed(i_rs1_data) >>> second_operand_alu;

         4'b1100:                                                                      // OR
            o_result <= i_rs1_data | second_operand_alu;

         4'b1101:                                                                      // AND
            o_result <= i_rs1_data & second_operand_alu;

         4'b1110:                                                                      // PC + 4
            o_result <= i_pc + 4;

         endcase
      end
   end
end


// General sequential logic for buffed signals
always @(posedge CLK) begin                                                            // Data buffer

   if (RST) begin
      o_rs2_data      <= 0;
      o_data_size     <= 0;
      o_dmem_write    <= 0;
      o_is_unsigned   <= 0;
      o_dmem_read     <= 0;
      o_rd_addr       <= 0;
      o_write_on_reg  <= 0;

   end else begin

      o_rs2_data      <= i_rs2_data;
      o_data_size     <= i_data_size;
      o_dmem_write    <= i_dmem_write;
      o_is_unsigned   <= i_is_unsigned;
      o_dmem_read     <= i_dmem_read;
      o_rd_addr       <= i_rd_addr;
      o_write_on_reg  <= i_write_on_reg;

   end
end

endmodule
//---------------------------------------------------------------------------------------------------------------
//                                         E X E C U T E   U N I T
//---------------------------------------------------------------------------------------------------------------
