// ------------------------------------------------------------------------------------------------------------
// -- File Name        : DecodeUnit.v
// -- Module Name      : du
// -- Developer        : Kristhel Quesada, David Rodriguez
// --
// -- Description      : Decode Unit
// --                    [ ] Decode RV32I instructions
// --                    [x] Extract opcode, funct3, funct7, rs1, rs2, rd fields
// --                    [x] Generate and extend immediates
// --                    [x] Operand and immediate multiplexer
// --                    [ ] Read from Register File
// --                    [ ] Generate control signals
// --                    [ ] Operand Fordwarding
// --                    [ ] Hazard Detection
// --                    [ ] Stall insert
// --                    [x] Vector extension interface (VALU-VV: 1010111, VALU-VX: 0001011)  [VEC]
// --
// -- Tested on        :
// -- Last modified on :
// -- Notes            : [VEC] Outputs prefixed o_vec_* connect directly to ve_top.
// --                        VALU-VV (1010111): both operands from vector register file.
// --                        VALU-VX (0001011): operand B is i_rs2_data from integer RF, broadcast
// --                        to all lanes inside the vector issue stage.
// --
// -- Copyright        : Refer to LICENSE.md.
// ------------------------------------------------------------------------------------------------------------

module decode #(
   parameter REGPC_INIT =  32'h0000_0000,    // Init PC on reset
   parameter XLEN = 32,
   parameter ILEN = 32
)(
   // General
   input wire CLK, RST,                      // Clock and Reset
   input wire FLUSH,                         // Inserts a nop
   input wire STALL,                         // Freezes the pipeline

   // ------------ INPUTS ------------
   input wire [ILEN-1:0] i_instr,            // Instruction fetched from ICache
   input wire [XLEN-1:0] i_pc,               // PC of instructions fetched from ICach
   input wire            i_bubble,           // NOP required after Fetch flushed (br/jmp taken)

   // [VEC] Values of integer RS1 and RS2, read combinationally from the integer RF.
   //       RS2 captured as o_vec_scalar for VALU-VX instructions.
   //       RS1 captured as o_vec_base_addr and RS2 as o_vec_stride for VLSU instructions.
   input wire [31:0]     i_rs1_data,         // RS1 value from integer register file
   input wire [31:0]     i_rs2_data,         // RS2 value from integer register file

   // ------------ OUPUTS ------------
   // > Combinational to RF
   output reg [4:0] o_rs1_addr,              // Address of register rs1
   output reg [4:0] o_rs2_addr,              // Address of register rs2

   // > Sequential to BU (EXE)
   output reg        o_rs1_2_pc,             // MUX Selector, for PC to be updated based on rs1 value
   output reg        o_is_branch,            // Flag that enables the BU
   output reg        o_is_type_u,            // Flag that indicates is instruction was type U so ALU
   output reg        o_dual_op,              // Flag to use both ALU and BU adders

   // > Sequential shared ALU/BU
   output reg [31:0] o_pc,                   // Current PC
   output reg [31:0] o_imm,                  // Immediate value depending on instr task
   output reg        o_is_unsigned,          // Flag that indicates whether values are sign or not

   // > Sequential shared BU/MEM
   output reg [1:0]  o_data_size,            // MUX Selector, for LOAD and Store instructions

   // > Sequential intended for ALU logic
   output reg [3:0]  o_alu_op,               // MUX Selector to choose ALU operation
   output reg        o_alu_src_rs2,          // MUX Selector to choose second ALU operand (rs2 or imm)

   // > Sequential to MEM
   output reg        o_dmem_write,           // Write enable flag for DCache
   output reg        o_dmen_read,            // Read enable flag for DCache

   // > Sequential to WB
   output reg [4:0]  o_rd_addr,              // Address of destiny register to update
   output reg        o_write_on_reg,         // Write enable flag for RF

   // [VEC] Sequential to vector extension unit (ve_top) — ALU path
   output reg        o_vec_valid,            // 1 when a vector ALU instruction is decoded (VV or VX)
   output reg [6:0]  o_vec_funct7,           // funct7 field forwarded to ve_top
   output reg [2:0]  o_vec_funct3,           // funct3 field forwarded to ve_top
   output reg [4:0]  o_vec_rs1,             // Source vector register 1 address
   output reg [4:0]  o_vec_rs2,             // Source vector register 2 address (used by VV only)
   output reg [4:0]  o_vec_rd,              // Destination vector register address
   output reg        o_vec_is_vx,           // 1 = VALU-VX (scalar operand), 0 = VALU-VV
   output reg [31:0] o_vec_scalar,           // Scalar operand captured from integer RF (VX only)

   // [VEC] Sequential to vector extension unit (ve_top) — VLSU path
   output reg        o_vec_lsu_valid,        // 1 when a vector load/store instruction is decoded
   output reg        o_vec_is_load,          // opcode == 0000111
   output reg        o_vec_is_store,         // opcode == 0100111
   output reg        o_vec_is_mask_op,       // unit-stride mask variant (lumop == 01011)
   output reg        o_vec_is_strided,       // constant-stride (mop == 10)
   output reg        o_vec_is_indexed,       // indexed-unordered (mop == 01)
   output reg [31:0] o_vec_base_addr,        // RS1 value from integer RF (base address for VLSU)
   output reg [31:0] o_vec_stride            // RS2 value from integer RF (stride for VLSU strided)
);

//===============================================================================================================
// Identifiers of types and instructions
//===============================================================================================================

localparam OPCODE_R         = 7'b0110011;      // add, sub, sll, slt, sltu, xor, srl, sra, or, and (10)
localparam OPCODE_I_JALR    = 7'b1100111;      // jalr (1)
localparam OPCODE_I_LOAD    = 7'b0000011;      // lb, lh, lw, lbu, lhu (5)
localparam OPCODE_I_NORM    = 7'b0010011;      // addi, slti, sltiu, xori, ori, andi, slli, srli, srai (9)
localparam OPCODE_S         = 7'b0100011;      // sb, sh, sw (3)
localparam OPCODE_B         = 7'b1100011;      // beq, bne, blt, bge, bltu, bgeu (6)
localparam OPCODE_U_LUI     = 7'b0110111;      // lui (1)
localparam OPCODE_U_AUIPC   = 7'b0010111;      // auipc (1)
localparam OPCODE_J         = 7'b1101111;      // jal (1)
localparam OPCODE_SPECIAL_1 = 7'b0001111;      // fence, fence.tso, pause (3)
localparam OPCODE_SPECIAL_2 = 7'b1110011;      // ecall, ebreak (2)

// [VEC] Custom opcodes for vector ALU extension
// OPCODE_VALU_VV reuses the opcode reserved for the V standard extension (unused by RV32I).
// OPCODE_VALU_VX uses the custom-0 opcode reserved by RISC-V for non-standard extensions.
localparam OPCODE_VALU_VV   = 7'b1010111;      // Vector-Vector  ALU — both operands from vector RF
localparam OPCODE_VALU_VX   = 7'b0001011;      // Vector-Scalar  ALU — operand B from integer RF
localparam OPCODE_VLSU_ST   = 7'b0100111;      // Vector store opcode
localparam OPCODE_VLSU_LD   = 7'b0000111;      // Vector load opcode

// Logical and arithmetic ID for ALU opcode
localparam ADD  = 4'b0000;
localparam SUB  = 4'b0001;
localparam SLL  = 4'b0011;
localparam SLT  = 4'b0010;
localparam SLTU = 4'b0110;
localparam XOR  = 4'b0111;
localparam SRL  = 4'b0101;
localparam SRA  = 4'b0100;
localparam OR   = 4'b1100;
localparam AND  = 4'b1101;
localparam JMP  = 4'b1110;
localparam BCH  = 4'b1111;

// Logical and arithmetic ID from instruction
localparam INSTR_ADD  = 10'b1000000000;
localparam INSTR_SUB  = 10'b0100000000;
localparam INSTR_SLL  = 10'b0010000000;
localparam INSTR_SLT  = 10'b0001000000;
localparam INSTR_SLTU = 10'b0000100000;
localparam INSTR_XOR  = 10'b0000010000;
localparam INSTR_SRL  = 10'b0000001000;
localparam INSTR_SRA  = 10'b0000000100;
localparam INSTR_OR   = 10'b0000000010;
localparam INSTR_AND  = 10'b0000000001;

// Compare values for data size enconding
localparam isbyte = 3'b000;
localparam ishalf = 3'b001;
localparam isword = 3'b010;

// Output data size encoding
localparam IS_BYTE    = 2'b00;
localparam IS_HALF    = 2'b01;
localparam IS_WORD    = 2'b11;

// Compare values for branch type enconding
localparam isequal = 3'b000;
localparam isnotequal = 3'b001;
localparam islessthan = 3'b100;
localparam isgreaterequal = 3'b101;
localparam islessthanunsigned = 3'b110;
localparam isgreaterequalunsigned = 3'b111;

// Output branch type encoding
localparam IS_EQUAL = 2'b00;
localparam IS_NOT_EQUAL = 2'b01;
localparam IS_LESS_THAN = 2'b10;
localparam IS_GREATER_EQUAL = 2'b11;


//===============================================================================================================
// Functions
//===============================================================================================================

// Function for ALU operation encoding
function [3:0] alu_op;
   input [9:0] alu_instr;

   begin
         if (alu_instr == INSTR_ADD)       alu_op = ADD;   // add
         else if (alu_instr == INSTR_SUB)  alu_op = SUB;   // sub
         else if (alu_instr == INSTR_SLL)  alu_op = SLL;   // sll
         else if (alu_instr == INSTR_SLT)  alu_op = SLT;   // slt
         else if (alu_instr == INSTR_SLTU) alu_op = SLTU;  // sltu
         else if (alu_instr == INSTR_XOR)  alu_op = XOR;   // xor
         else if (alu_instr == INSTR_SRL)  alu_op = SRL;   // srl
         else if (alu_instr == INSTR_SRA)  alu_op = SRA;   // sra
         else if (alu_instr == INSTR_OR)   alu_op = OR;    // or
         else if (alu_instr == INSTR_AND)  alu_op = AND;   // and
   end
endfunction

// Function for data size enconding
function [1:0] data_size;
   input [2:0] function3;

   begin
         if (function3 == isbyte || function3 == 3'b100)      data_size = IS_BYTE;   // 00
         else if (function3 == ishalf || function3 == 3'b101) data_size = IS_HALF;   // 01
         else if (function3 == isword) data_size = IS_WORD;                          // 11
         else data_size = data_size;
   end
endfunction

// Function for branch type enconding
function [2:0] branch_type;
   input [2:0] function3;

   begin
         if (function3 == isequal)                                                      branch_type = IS_EQUAL;
         else if (function3 == isnotequal)                                              branch_type = IS_NOT_EQUAL;
         else if (function3 == islessthan || function3 == islessthanunsigned)           branch_type = IS_LESS_THAN;
         else if (function3 == isgreaterequal || function3 == isgreaterequalunsigned)   branch_type = IS_GREATER_EQUAL;
   end
endfunction



//===============================================================================================================
// Intermidiate Signals
//===============================================================================================================

/*
 * --------------------------------------------------------------------
 * Extraction of main components of instruction
 * --------------------------------------------------------------------
*/
wire [6:0] opcode, funct7;
wire [4:0] rs1, rs2, rd;
wire [2:0] funct3;

assign opcode = i_instr[6:0];
assign rs1    = i_instr[19:15];
assign rs2    = i_instr[24:20];
assign rd     = i_instr[11:7];
assign funct3 = i_instr[14:12];
assign funct7 = i_instr[31:25];

/*
 * --------------------------------------------------------------------
 * Extraction of type of instruction (flags)
 * --------------------------------------------------------------------
*/
wire is_typeR, is_typeI_JALR, is_typeI_LOAD, is_typeI_NORM, is_typeS, is_typeB, is_typeU, is_typeJ;
wire is_Special1, is_Special2;

assign is_typeR        = (opcode == OPCODE_R);
assign is_typeI_JALR   = (opcode == OPCODE_I_JALR);
assign is_typeI_LOAD   = (opcode == OPCODE_I_LOAD);
assign is_typeI_NORM   = (opcode == OPCODE_I_NORM);
assign is_typeS        = (opcode == OPCODE_S);
assign is_typeB        = (opcode == OPCODE_B);
assign is_typeU        = (opcode == OPCODE_U_LUI) || (opcode == OPCODE_U_AUIPC);
assign is_typeJ        = (opcode == OPCODE_J);
assign is_typeSP1      = (opcode == OPCODE_SPECIAL_1);
assign is_typeSP2      = (opcode == OPCODE_SPECIAL_2);

// [VEC] Vector instruction type flags
assign is_valu_vv      = (opcode == OPCODE_VALU_VV);   // vector-vector ALU
assign is_valu_vx      = (opcode == OPCODE_VALU_VX);   // vector-scalar ALU
assign is_vlsu_ld      = (opcode == OPCODE_VLSU_LD);   // vector load
assign is_vlsu_st      = (opcode == OPCODE_VLSU_ST);   // vector store

// [VEC] VLSU addressing sub-fields (shared bit positions with rs2/funct7)
wire [1:0] mop;
wire [4:0] lumop;
assign mop   = i_instr[27:26];   // addressing mode: 00=unit-stride, 01=indexed, 10=strided
assign lumop = i_instr[24:20];   // lumop/sumop (same bits as rs2, valid when mop==00)


/*
 * --------------------------------------------------------------------
 * Extraction and sign extension of immediate values
 * --------------------------------------------------------------------
*/
wire [31:0] b_imm, s_imm, i_imm, i_imm_shamt, u_imm, j_imm;

assign j_imm       = {{12{i_instr[31]}}, i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
assign b_imm       = {{20{i_instr[31]}}, i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0 };
assign s_imm       = {{21{i_instr[31]}}, i_instr[30:25], i_instr[11:7]};
assign i_imm       = {{21{i_instr[31]}}, i_instr[30:20]};
assign u_imm       = {{12{1'b0}}, i_instr[31:12]};
assign i_imm_shamt = {{27{1'b0}}, i_instr[24:20]}; // slli, srli, srai


/*
 * --------------------------------------------------------------------
 * Extraction of arithmetic and logical operations for ALU
 * --------------------------------------------------------------------
*/
wire [9:0] alu_instr;
wire is_add, is_sub, is_sll, is_slt, is_sltu, is_xor, is_srl, is_sra, is_or, is_and;

assign is_sub  = (funct7 == 7'h20 && funct3 == 3'b000 && is_typeR);
assign is_add  = (funct7 == 7'h00 && funct3 == 3'b000 && is_typeR) || (funct3 == 3'b000 && is_typeI_NORM);
assign is_or   = (funct7 == 7'h00 && funct3 == 3'b110 && is_typeR) || (funct3 == 3'b110 && is_typeI_NORM);
assign is_and  = (funct7 == 7'h00 && funct3 == 3'b111 && is_typeR) || (funct3 == 3'b111 && is_typeI_NORM);
assign is_xor  = (funct7 == 7'h00 && funct3 == 3'b100 && is_typeR) || (funct3 == 3'b100 && is_typeI_NORM);
assign is_slt  = (funct7 == 7'h00 && funct3 == 3'b010 && is_typeR) || (funct3 == 3'b010 && is_typeI_NORM);
assign is_sltu = (funct7 == 7'h00 && funct3 == 3'b011 && is_typeR) || (funct3 == 3'b011 && is_typeI_NORM);
assign is_sll  = (funct7 == 7'h00 && funct3 == 3'b001 && is_typeR) || (funct7 == 7'h00 && funct3 == 3'b001 && is_typeI_NORM);
assign is_srl  = (funct7 == 7'h00 && funct3 == 3'b101 && is_typeR) || (funct7 == 7'h00 && funct3 == 3'b101 && is_typeI_NORM);
assign is_sra  = (funct7 == 7'h20 && funct3 == 3'b101 && is_typeR) || (funct7 == 7'h20 && funct3 == 3'b101 && is_typeI_NORM);
assign alu_instr = {is_add, is_sub, is_sll, is_slt, is_sltu, is_xor, is_srl, is_sra, is_or, is_and};

/*
 * --------------------------------------------------------------------
 * Unsigned flags
 * --------------------------------------------------------------------
*/
wire is_normunsigned, is_loadunsigned, is_branchunsigned;
assign is_normunsigned = (funct3 == 3'b011);
assign is_loadunsigned = (funct3 == 3'b100) || (funct3 == 3'b101);
assign is_branchunsigned = (funct3 == 3'b110) || (funct3 == 3'b111);



//===============================================================================================================
// State and output memory
//===============================================================================================================
always @(posedge CLK) begin
   if (RST | FLUSH | i_bubble) begin
      o_rs1_2_pc      <= 0;
      o_is_branch     <= 0;
      o_is_type_u     <= 0;
      o_dual_op       <= 0;
      o_pc            <= 0;
      o_imm           <= 0;
      o_is_unsigned   <= 0;
      o_data_size     <= 0;
      o_alu_op        <= 0;
      o_alu_src_rs2   <= 0;
      o_dmem_write    <= 0;
      o_dmen_read     <= 0;
      o_rd_addr       <= 0;
      o_write_on_reg  <= 0;
      // [VEC] Clear vector outputs on reset / flush / bubble
      o_vec_valid      <= 0;
      o_vec_funct7     <= 0;
      o_vec_funct3     <= 0;
      o_vec_rs1        <= 0;
      o_vec_rs2        <= 0;
      o_vec_rd         <= 0;
      o_vec_is_vx      <= 0;
      o_vec_scalar     <= 0;
      o_vec_lsu_valid  <= 0;
      o_vec_is_load    <= 0;
      o_vec_is_store   <= 0;
      o_vec_is_mask_op <= 0;
      o_vec_is_strided <= 0;
      o_vec_is_indexed <= 0;
      o_vec_base_addr  <= 0;
      o_vec_stride     <= 0;

   end else if (STALL) begin
      o_rs1_2_pc      <= o_rs1_2_pc;
      o_is_branch     <= o_is_branch;
      o_is_type_u     <= o_is_type_u;
      o_dual_op       <= o_dual_op;
      o_pc            <= o_pc;
      o_imm           <= o_imm;
      o_is_unsigned   <= o_is_unsigned;
      o_data_size     <= o_data_size;
      o_alu_op        <= o_alu_op;
      o_alu_src_rs2   <= o_alu_src_rs2;
      o_dmem_write    <= o_dmem_write;
      o_dmen_read     <= o_dmen_read;
      o_rd_addr       <= o_rd_addr;
      o_write_on_reg  <= o_write_on_reg;
      // [VEC] Freeze vector outputs on stall
      o_vec_valid      <= o_vec_valid;
      o_vec_funct7     <= o_vec_funct7;
      o_vec_funct3     <= o_vec_funct3;
      o_vec_rs1        <= o_vec_rs1;
      o_vec_rs2        <= o_vec_rs2;
      o_vec_rd         <= o_vec_rd;
      o_vec_is_vx      <= o_vec_is_vx;
      o_vec_scalar     <= o_vec_scalar;
      o_vec_lsu_valid  <= o_vec_lsu_valid;
      o_vec_is_load    <= o_vec_is_load;
      o_vec_is_store   <= o_vec_is_store;
      o_vec_is_mask_op <= o_vec_is_mask_op;
      o_vec_is_strided <= o_vec_is_strided;
      o_vec_is_indexed <= o_vec_is_indexed;
      o_vec_base_addr  <= o_vec_base_addr;
      o_vec_stride     <= o_vec_stride;

   end else begin

      // For every posedge the clock, send the program counter
      o_pc <= i_pc;

      // Update rd address only if instruction is not branch or store
      if (!is_typeB | !is_typeS) begin
         o_rd_addr <= rd;
      end

      // Control of the immediate values
      if (is_typeJ) o_imm <= j_imm;
      else if (is_typeB) o_imm <= b_imm;
      else if (is_typeS) o_imm <= s_imm;
      else if (is_typeU) o_imm <= u_imm;
      else if (is_typeI_JALR || is_typeI_LOAD || is_typeI_NORM) begin
         if (is_sll || is_srl || is_sra) o_imm <= i_imm_shamt;   // Type I immediate with shamt
         else o_imm <= i_imm;                                    // General type I immeadiate
      end

      // [VEC] Default: no vector instruction active this cycle; clear LSU flags to prevent stale state
      o_vec_valid      <= 1'b0;
      o_vec_lsu_valid  <= 1'b0;
      o_vec_is_load    <= 1'b0;
      o_vec_is_store   <= 1'b0;
      o_vec_is_mask_op <= 1'b0;
      o_vec_is_strided <= 1'b0;
      o_vec_is_indexed <= 1'b0;

      // For each instruction
      if (is_typeR) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= is_normunsigned ? 1 : 0;
         //o_data_size
         o_alu_op        <= alu_op(alu_instr);
         o_alu_src_rs2   <= 1;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 1;

      end else if (is_typeI_NORM) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= is_normunsigned ? 1 : 0;
         //o_data_size
         o_alu_op        <= alu_op(alu_instr);
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 1;

      end else if (is_typeI_LOAD) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= is_loadunsigned ? 1 : 0;
         o_data_size     <= data_size(funct3);
         o_alu_op        <= ADD;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 1;
         o_write_on_reg  <= 1;

      end else if (is_typeI_JALR) begin
         // Does: rd = pc+4; pc = rs1+imm
         o_rs1_2_pc      <= 1;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 1;
         o_is_unsigned   <= 0;
         //o_data_size
         o_alu_op        <= JMP; // PC+4
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 1;

      end else if (is_typeS) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= 0;
         o_data_size     <= data_size(funct3);
         o_alu_op        <= ADD;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 1;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 0;

      end else if (is_typeU) begin
         // lui --> rd = imm << 12
         // auipc --< rd = pc + (imm << 12)
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 1;
         if (opcode == OPCODE_U_LUI) begin
            o_dual_op      <= 0;
         end else if (opcode == OPCODE_U_AUIPC) begin
            o_dual_op      <= 1;
         end
         o_is_unsigned   <= 0;
         //o_data_size
         o_alu_op        <= SLL;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 1;

      end else if (is_typeJ) begin
         // JAL : rd = pc+4; pc += imm
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 1;
         o_is_unsigned   <= 0;
         //o_data_size
         o_alu_op        <= JMP; // PC+4
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 1;

      end else if (is_typeB) begin
         // beq, bne, blt, bge, bltu, bgeu (6)
         // beq rs1, rs2, imm	-> if(rs1 == rs2) pc += imm
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 1;
         o_is_type_u     <= 0;
         o_dual_op       <= 1;
         o_is_unsigned   <= is_branchunsigned ? 1 : 0;;
         o_data_size     <= branch_type(funct3);
         o_alu_op        <= BCH;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 0;

      end else if (is_typeSP1) begin
         // Pending at all: Investigate purpose

      end else if (is_typeSP2) begin
         // Pending at all: Investigate purpose

      // [VEC] Vector-Vector ALU instruction (opcode 1010111)
      // Both source operands are vector register addresses; the integer RF is not involved.
      // o_write_on_reg=0: the result goes to the vector RF, not the integer RF.
      end else if (is_valu_vv) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= 0;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 0;
         o_vec_valid     <= 1;
         o_vec_funct7    <= funct7;
         o_vec_funct3    <= funct3;
         o_vec_rs1       <= rs1;
         o_vec_rs2       <= rs2;
         o_vec_rd        <= rd;
         o_vec_is_vx     <= 0;
         o_vec_scalar    <= 0;

      // [VEC] Vector-Scalar ALU instruction (opcode 0001011)
      // Operand A is a vector register; operand B is the integer RF value at rs2 (i_rs2_data),
      // broadcast to all 4 lanes inside the vector issue stage.
      // o_write_on_reg=0: the result goes to the vector RF, not the integer RF.
      end else if (is_valu_vx) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= 0;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 0;
         o_vec_valid     <= 1;
         o_vec_funct7    <= funct7;
         o_vec_funct3    <= funct3;
         o_vec_rs1       <= rs1;
         o_vec_rs2       <= 0;            // rs2 field unused as vector address in VX mode
         o_vec_rd        <= rd;
         o_vec_is_vx     <= 1;
         o_vec_scalar    <= i_rs2_data;   // scalar captured from integer RF at rs2 address

      // [VEC] Vector load/store instruction (opcodes 0000111 / 0100111)
      // Dispatch to VLSU. Register fields share bit positions with R-type:
      //   vd/vs3 = rd = i_instr[11:7], rs1 (base) = i_instr[19:15], rs2/vs2 = i_instr[24:20]
      // o_write_on_reg=0: result goes to vector RF, not integer RF.
      end else if (is_vlsu_ld || is_vlsu_st) begin
         o_rs1_2_pc      <= 0;
         o_is_branch     <= 0;
         o_is_type_u     <= 0;
         o_dual_op       <= 0;
         o_is_unsigned   <= 0;
         o_alu_src_rs2   <= 0;
         o_dmem_write    <= 0;
         o_dmen_read     <= 0;
         o_write_on_reg  <= 0;
         o_vec_lsu_valid  <= 1;
         o_vec_is_load    <= is_vlsu_ld;
         o_vec_is_store   <= is_vlsu_st;
         o_vec_rs1        <= rs1;
         o_vec_rs2        <= rs2;
         o_vec_rd         <= rd;
         o_vec_is_mask_op <= (mop == 2'b00) && (lumop == 5'b01011);
         o_vec_is_strided <= (mop == 2'b10);
         o_vec_is_indexed <= (mop == 2'b01);
         o_vec_base_addr  <= i_rs1_data;   // base address captured from integer RF
         o_vec_stride     <= i_rs2_data;   // stride captured from integer RF (strided mode)

      end
   end
end

//===============================================================================================================
// OUTPUT TO THE RF (COMBINATIONAL)
//===============================================================================================================
always @(*) begin

   if (RST | FLUSH | i_bubble) begin
      o_rs1_addr      <= 0;
      o_rs2_addr      <= 0;
   end else begin

      // Control of RS1
      if (is_typeR || is_typeI_NORM || is_typeI_JALR || is_typeI_LOAD || is_typeS || is_typeB) begin
         o_rs1_addr    <= rs1;
      end

      // Control of RS2
      if (is_typeR || is_typeB || is_typeS) begin
         o_rs2_addr    <= rs2;
      end

      // [VEC] For VX instructions, rs2 must be driven so the integer RF outputs the scalar value
      //       that will be captured as o_vec_scalar on the next clock edge.
      //       VV instructions do not read from the integer RF.
      if (is_valu_vx) begin
         o_rs2_addr    <= rs2;
      end

      // [VEC] For VLSU instructions, rs1 (base address) and rs2 (stride) must be driven so the
      //       integer RF outputs both values, captured as o_vec_base_addr and o_vec_stride.
      if (is_vlsu_ld || is_vlsu_st) begin
         o_rs1_addr    <= rs1;
         o_rs2_addr    <= rs2;
      end
   end
end

endmodule
//---------------------------------------------------------------------------------------------------------------
//                                           D E C O D E   U N I T
//---------------------------------------------------------------------------------------------------------------
