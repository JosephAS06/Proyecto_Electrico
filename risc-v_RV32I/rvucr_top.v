/* --------------------------------------------------------------------------------------
 * TOP MODULE
 * --------------------------------------------------------------------------------------
 * Developers  : David Rodriguez, Kristhel Quesada
 * Notes       :
 * Copyright   : Refer to LICENSE.md.
 * --------------------------------------------------------------------------------------
*/

`include "../../src/core/1_Fetch/FetchUnit.v"
`include "../../src/memory/ICache.v"
`include "../../src/memory/DCache.v"
`include "../../src/core/2_Decode/DecodeUnit.v"
`include "../../src/core/RegisterFile.v"
`include "../../src/core/3_Execute/ExecuteUnit.v"
`include "../../src/core/4_Memory/MemoryUnit.v"
`include "../../src/core/5_Writeback/WriteBack.v"

module rvucr_top#(
   parameter REGPC_INIT =  32'h0000_0000,    // Init PC on reset
   parameter XLEN = 32,
   parameter ILEN = 32
)(   
   // General
   input wire clk, reset,
   input wire i_imem_wen,
   input wire [31:0]i_init_address,
   input wire [31:0] i_init_instructions
);


/*
 * =====================================================
 *                     FETCH STAGE
 * =====================================================
 */

// FU-IMEM INTERFACE
wire [31:0] fu_pc_imem;
wire [31:0] pc_addr;
assign pc_addr = {2'b0, fu_pc_imem[31:2]};

// IMEM-FU INTERFACE
wire [31:0] imem_pc, imem_instr;

// FU-DU
wire [31:0] fu_pc, fu_instr;
wire fu_bubble;

icache imem(
    // General
    .CLK(clk),
    .rst(reset),

    // From Tester
    .i_we(i_imem_wen),
    .i_wdata(i_init_instructions),
    .i_tester_addr(i_init_address),

    // From fetch unit
    .i_pc(fu_pc_imem),
    .i_addr(pc_addr),

    // To fetch unit
    .o_pc(imem_pc),
    .o_instr(imem_instr)
);

fetch #(.INITIAL_PC(REGPC_INIT)) FU(
    // General
    .CLK(clk),
    .RST(reset),

    // From ICache
    .i_pc(imem_pc),
    .i_instruction(imem_instr),
    
    // From Execute
    .i_pc_upd(exu_pc_upd),
    .i_take_br(exu_take_br),
    .i_take_jmp(exu_take_jmp),

    // To ICache
    .o_pc_imem(fu_pc_imem),
    
    // To Decode Unit
    .o_pc(fu_pc),
    .o_bubble(fu_bubble),
    .o_instruction(fu_instr)
);


/*
 * =====================================================
 *                     DECODE STAGE
 * =====================================================
 */

// DU-RF Interface
wire [4:0] du_rs1_addr, du_rs2_addr;

// DU-BU Interface
wire du_rs1_2_pc, du_is_branch, du_is_type_u, du_dual_op;

// DU-BU/ALU Interface
wire [31:0] du_pc, du_imm;
wire        du_is_unsigned;

// DU-BU/MEM Interface
wire [1:0]  du_data_size;

//DU-ALU Interface
wire [3:0]  du_alu_op;
wire        du_alu_src_rs2;

// DU-MEM(Buff) Interface
wire du_dmem_write, du_dmem_read;

// DU-WB(Buff) Interface
wire [4:0]  du_rd_addr;
wire        du_write_on_reg;

decode DU(
    // General
    .CLK(clk),                                  
    .RST(reset),

    // Inputs from FU
    .i_pc(fu_pc),
    .i_instr(fu_instr),
    .i_bubble(fu_bubble),

    // Outputs to RF
    .o_rs1_addr(du_rs1_addr),
    .o_rs2_addr(du_rs2_addr),

    // Outputs to BU
    .o_rs1_2_pc(du_rs1_2_pc),
    .o_is_branch(du_is_branch),
    .o_is_type_u(du_is_type_u),
    .o_dual_op(du_dual_op),

    // Ouput to BU/ALU
    .o_pc(du_pc),
    .o_imm(du_imm),
    .o_is_unsigned(du_is_unsigned),

    // Output to BU/MEM
    .o_data_size(du_data_size),

    // OUtput to ALU
    .o_alu_op(du_alu_op),
    .o_alu_src_rs2(du_alu_src_rs2),

    // Output to MEM
    .o_dmem_write(du_dmem_write),
    .o_dmen_read(du_dmem_read),

    // Output to WB
    .o_rd_addr(du_rd_addr),
    .o_write_on_reg(du_write_on_reg)
);

// RF-EXU Interface
wire [31:0] rf_rs1_data, rf_rs2_data;

regFile RF(
    // General
    .CLK(clk),                                  
    .RST(reset),

    // Used on DU (read)
    .i_rs1_addr(du_rs1_addr),
    .i_rs2_addr(du_rs2_addr),
    .o_rs1_data(rf_rs1_data),
    .o_rs2_data(rf_rs2_data),

    // Used on WB (write)
    .i_we(wb_wen),
    .i_wb_rf_addr(wb_rd_addr),
    .i_wb_rf_rslt(wb_data2write)
);

/*
 * =====================================================
 *                     EXECUTE STAGE
 * =====================================================
 */

// EXU-DU Interface
wire [ILEN-1:0] exu_pc_upd;
wire          exu_take_br, exu_take_jmp;

// EXU-MEM Interface
wire [31:0] exu_rs2_data;
wire [1:0]  exu_data_size;
wire        exu_dmem_write, exu_is_unsigned;

// EXU-MEM/WB Interface
wire [31:0] exu_result;
wire        exu_dmem_read;

// EXU-WB Interface
wire [4:0]  exu_rd_addr;
wire        exu_write_on_reg;

exu EXU (
    // General
    .CLK(clk),                                  
    .RST(reset),

    // ------------ INPUTS ------------
    // From RF
    .i_rs1_data(rf_rs1_data),
    .i_rs2_data(rf_rs2_data),
    
    // From DecodeUnit -> ALU/BU
    .i_pc(du_pc),
    .i_imm(du_imm),
    .i_is_unsigned(du_is_unsigned),

    // From DecodeUnit -> BU
    .i_rs1_2_pc(du_rs1_2_pc),
    .i_is_branch(du_is_branch),
    .i_is_type_u(du_is_type_u),
    .i_dual_op(du_dual_op),

    // From DecodeUnit -> BU/MEM
    .i_data_size(du_data_size),

    // From DecodeUnit -> ALU
    .i_alu_op(du_alu_op),
    .i_alu_src_rs2(du_alu_src_rs2),

    // From DecodeUnit -> MEM
    .i_dmem_write(du_dmem_write),
    .i_dmem_read(du_dmem_read),

    // From DecodeUnit -> WB
    .i_rd_addr(du_rd_addr),
    .i_write_on_reg(du_write_on_reg),

    // ------------ OUPUTS ------------
    // Used on FU
    .o_pc_upd(exu_pc_upd),
    .o_take_br(exu_take_br),
    .o_take_jmp(exu_take_jmp),
    
    // Used on MEM
    .o_rs2_data(exu_rs2_data),
    .o_data_size(exu_data_size),
    .o_dmem_write(exu_dmem_write),
    .o_is_unsigned(exu_is_unsigned),

    // Used on MEM/WB
    .o_result(exu_result),
    .o_dmem_read(exu_dmem_read),

    // Used on WB
    .o_rd_addr(exu_rd_addr),
    .o_write_on_reg(exu_write_on_reg)
);

/*
 * =====================================================
 *                     MEMORY STAGE
 * =====================================================
 */

// MEM-WB Interface
wire [31:0] mem_alu_result;
wire [4:0]  mem_rd_addr;
wire [1:0]  mem_wb_sel;
wire [1:0]  mem_data_size;
wire        mem_write_on_reg;
wire        mem_is_unsigned;

// MEM-DCACHE Interface
wire [31:0] mem_write_data;
wire [31:0] mem_dmem_address;
wire [3:0]  mem_byte_en;
wire        mem_dmem_read;
wire        mem_dmem_write;


mem_unit mem0 (
    // General
    .clk(clk),
    .reset(reset),

    // Inputs
    .i_alu_result(exu_result),
    .i_rs2_data(exu_rs2_data),
    .i_rd_addr(exu_rd_addr),
    .i_data_size(exu_data_size),
    .i_is_unsigned(exu_is_unsigned),
    .i_dmem_write(exu_dmem_write),
    .i_dmem_read(exu_dmem_read),
    .i_write_on_reg(exu_write_on_reg),

    // Outputs to WB
    .o_alu_result(mem_alu_result),
    .o_rd_addr(mem_rd_addr),
    .o_wb_sel(mem_wb_sel),
    .o_data_size(mem_data_size),
    .o_write_on_reg(mem_write_on_reg),
    .o_is_unsigned(mem_is_unsigned),

    // Outputs to DCache
    .o_write_data(mem_write_data),
    .o_dmem_address(mem_dmem_address),
    .o_byte_en(mem_byte_en),
    .o_dmem_read(mem_dmem_read),
    .o_dmem_write(mem_dmem_write)
);

wire [31:0] dcache_data;
wire [31:0] dcache_addr;
assign dcache_addr = {2'b0, mem_dmem_address[31:2]};
dcache dcache0  (
    // General
    .clk(clk),
    .rst(reset),

    // Inputs from mem_unit
    .i_wdata(mem_write_data),
    .i_write_en(mem_dmem_write),
    .i_read_en(mem_dmem_read),
    .i_byte_en(mem_byte_en),
    .i_addr(dcache_addr),

    // Outputs to WB
    .o_rdata(dcache_data)
);

// ------------ Local Parameters ------------
localparam BYTE = 2'b00;
localparam HALF = 2'b01;
localparam WORD = 2'b11;

// ---------- Intermediate Signals ----------
wire [7:0]  byte_val;
wire [15:0] half_val;
assign byte_val  = dcache_data[7:0];
assign half_val  = dcache_data[15:0];

reg  [31:0] o_loaded_data;

always @(posedge clk) begin
    if (reset) begin
        o_loaded_data <= 0;
    end else begin
        case (mem_data_size)
           BYTE:    
              o_loaded_data <= mem_is_unsigned ? {24'b0, byte_val}
                                        : {{24{byte_val[7]}}, byte_val};
           HALF:    
              o_loaded_data <= mem_is_unsigned ? {16'b0, half_val}
                                        : {{16{half_val[15]}}, half_val};
           WORD:    
              o_loaded_data <= dcache_data;
           default: 
              o_loaded_data <= o_loaded_data;
        endcase
    end
end


/*
 * =====================================================
 *                   WRITE-BACK STAGE
 * =====================================================
 */
wire [31:0] wb_data2write;
wire [4:0]  wb_rd_addr;
wire        wb_wen;

wb_unit wb0 (
    // General
    .clk(clk),
    .rst(reset),

    // Inputs from dcache
    .i_dmem_data(o_loaded_data),

    // Inputs from mem_unit
    .i_alu_result(mem_alu_result),
    .i_rd_addr(mem_rd_addr),
    .i_wb_sel(mem_wb_sel),
    .i_write_on_reg(mem_write_on_reg),

    // Outputs to RF
    .o_write_data(wb_data2write),
    .o_rd_addr(wb_rd_addr),
    .o_wen(wb_wen)
);

endmodule