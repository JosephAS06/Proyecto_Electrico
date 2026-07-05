module ve_integrated #(
    parameter INITIAL_PC = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        i_imem_wen,
    input  wire [31:0] i_imem_addr,
    input  wire [31:0] i_imem_data
);

wire [31:0] fu_pc_imem;
wire [31:0] imem_pc_out;
wire [31:0] imem_instr_out;

wire [31:0] fu_instr;
wire [31:0] fu_pc;
wire        fu_bubble;

wire [31:0] exu_pc_upd;
wire        exu_take_br;
wire        exu_take_jmp;

wire        vec_stall;

// Load-use hazard stall: fire when a load in EXU matches a source reg in the next instruction (in FU)
wire scalar_stall = exu_dmem_read && (exu_rd_addr != 5'b0) &&
    ((exu_rd_addr == du_rs1_addr) || (exu_rd_addr == du_rs2_addr));
// Combined stall for FU and DU
wire pipeline_stall = vec_stall || scalar_stall;

icache imem (
    .CLK          (clk),
    .rst          (rst),
    .i_we         (i_imem_wen),
    .i_tester_addr(i_imem_addr),
    .i_addr       ({2'b0, fu_pc_imem[31:2]}),
    .i_pc         (fu_pc_imem),
    .i_wdata      (i_imem_data),
    .o_instr      (imem_instr_out),
    .o_pc         (imem_pc_out)
);

fetch FU (
    .CLK          (clk),
    .RST          (rst),
    .STALL        (pipeline_stall),
    .i_instruction(imem_instr_out),
    .i_pc         (imem_pc_out),
    .o_pc_imem    (fu_pc_imem),
    .i_pc_upd     (exu_pc_upd),
    .i_take_br    (exu_take_br),
    .i_take_jmp   (exu_take_jmp),
    .o_instruction(fu_instr),
    .o_pc         (fu_pc),
    .o_bubble     (fu_bubble)
);

wire [4:0]  du_rs1_addr;
wire [4:0]  du_rs2_addr;

wire        du_rs1_2_pc;
wire        du_is_branch;
wire        du_is_type_u;
wire        du_dual_op;
wire [31:0] du_pc;
wire [31:0] du_imm;
wire        du_is_unsigned;
wire [1:0]  du_data_size;
wire [3:0]  du_alu_op;
wire        du_alu_src_rs2;
wire        du_dmem_write;
wire        du_dmem_read;
wire [4:0]  du_rd_addr;
wire        du_write_on_reg;

wire        du_vec_valid;
wire [6:0]  du_vec_funct7;
wire [2:0]  du_vec_funct3;
wire [4:0]  du_vec_rs1;
wire [4:0]  du_vec_rs2;
wire [4:0]  du_vec_rd;
wire        du_vec_is_vx;
wire [31:0] du_vec_scalar;
wire        du_vec_lsu_valid;
wire        du_vec_is_load;
wire        du_vec_is_store;
wire        du_vec_is_mask_op;
wire        du_vec_is_strided;
wire        du_vec_is_indexed;
wire [31:0] du_vec_base_addr;
wire [31:0] du_vec_stride;

wire [31:0] rf_rs1_data;
wire [31:0] rf_rs2_data;

decode DU (
    .CLK          (clk),
    .RST          (rst),
    .FLUSH        (1'b0),
    .STALL        (pipeline_stall),
    .i_instr      (fu_instr),
    .i_pc         (fu_pc),
    .i_bubble     (fu_bubble),
    .i_rs1_data   (rf_rs1_data),
    .i_rs2_data   (rf_rs2_data),
    .o_rs1_addr   (du_rs1_addr),
    .o_rs2_addr   (du_rs2_addr),
    .o_rs1_2_pc   (du_rs1_2_pc),
    .o_is_branch  (du_is_branch),
    .o_is_type_u  (du_is_type_u),
    .o_dual_op    (du_dual_op),
    .o_pc         (du_pc),
    .o_imm        (du_imm),
    .o_is_unsigned(du_is_unsigned),
    .o_data_size  (du_data_size),
    .o_alu_op     (du_alu_op),
    .o_alu_src_rs2(du_alu_src_rs2),
    .o_dmem_write (du_dmem_write),
    .o_dmen_read  (du_dmem_read),
    .o_rd_addr    (du_rd_addr),
    .o_write_on_reg(du_write_on_reg),
    .o_vec_valid  (du_vec_valid),
    .o_vec_funct7 (du_vec_funct7),
    .o_vec_funct3 (du_vec_funct3),
    .o_vec_rs1    (du_vec_rs1),
    .o_vec_rs2    (du_vec_rs2),
    .o_vec_rd     (du_vec_rd),
    .o_vec_is_vx  (du_vec_is_vx),
    .o_vec_scalar (du_vec_scalar),
    .o_vec_lsu_valid  (du_vec_lsu_valid),
    .o_vec_is_load    (du_vec_is_load),
    .o_vec_is_store   (du_vec_is_store),
    .o_vec_is_mask_op (du_vec_is_mask_op),
    .o_vec_is_strided (du_vec_is_strided),
    .o_vec_is_indexed (du_vec_is_indexed),
    .o_vec_base_addr  (du_vec_base_addr),
    .o_vec_stride     (du_vec_stride)
);

wire [31:0] wb_write_data;
wire [4:0]  wb_rd_addr;
wire        wb_wen;

regFile RF (
    .CLK        (clk),
    .RST        (rst),
    .i_rs1_addr (du_rs1_addr),
    .i_rs2_addr (du_rs2_addr),
    .o_rs1_data (rf_rs1_data),
    .o_rs2_data (rf_rs2_data),
    .i_we       (wb_wen),
    .i_wb_rf_addr(wb_rd_addr),
    .i_wb_rf_rslt(wb_write_data)
);

// Sign-extended forwarding path for load instructions in the MEM stage
reg  [31:0] fwd_load_data;
always @(*) begin
    case (mem_data_size)
        BYTE: fwd_load_data = mem_is_unsigned ? {24'b0, scalar_rdata[7:0]}  : {{24{scalar_rdata[7]}},  scalar_rdata[7:0]};
        HALF: fwd_load_data = mem_is_unsigned ? {16'b0, scalar_rdata[15:0]} : {{16{scalar_rdata[15]}}, scalar_rdata[15:0]};
        default: fwd_load_data = scalar_rdata;
    endcase
end

// Data forwarding: select the most recently computed value for each source register
wire [31:0] fwd_rs1 =
    (exu_write_on_reg && exu_rd_addr != 5'b0 && exu_rd_addr == du_rs1_addr) ? exu_result :
    (mem_write_on_reg && mem_rd_addr != 5'b0 && mem_rd_addr == du_rs1_addr) ?
        (mem_wb_sel[0] ? fwd_load_data : mem_alu_result) :
    (wb_wen && wb_rd_addr != 5'b0 && wb_rd_addr == du_rs1_addr) ? wb_write_data :
    rf_rs1_data;

wire [31:0] fwd_rs2 =
    (exu_write_on_reg && exu_rd_addr != 5'b0 && exu_rd_addr == du_rs2_addr) ? exu_result :
    (mem_write_on_reg && mem_rd_addr != 5'b0 && mem_rd_addr == du_rs2_addr) ?
        (mem_wb_sel[0] ? fwd_load_data : mem_alu_result) :
    (wb_wen && wb_rd_addr != 5'b0 && wb_rd_addr == du_rs2_addr) ? wb_write_data :
    rf_rs2_data;

// Pipeline registers: capture forwarded data while current instruction is at DU stage
reg [31:0] du_rs1_data_reg;
reg [31:0] du_rs2_data_reg;
always @(posedge clk) begin
    if (rst) begin
        du_rs1_data_reg <= 0;
        du_rs2_data_reg <= 0;
    end else if (!pipeline_stall) begin
        du_rs1_data_reg <= fwd_rs1;
        du_rs2_data_reg <= fwd_rs2;
    end
end

wire [31:0] exu_rs2_data;
wire [1:0]  exu_data_size;
wire        exu_dmem_write;
wire        exu_is_unsigned;
wire [31:0] exu_result;
wire [31:0] exu_result2;
wire        exu_dmem_read;
wire [4:0]  exu_rd_addr;
wire        exu_write_on_reg;

// Bubble injection: zero control signals when stalling for a load-use hazard
wire        exu_i_is_branch    = scalar_stall ? 1'b0  : du_is_branch;
wire        exu_i_dual_op      = scalar_stall ? 1'b0  : du_dual_op;
wire        exu_i_dmem_write   = scalar_stall ? 1'b0  : du_dmem_write;
wire        exu_i_dmem_read    = scalar_stall ? 1'b0  : du_dmem_read;
wire [4:0]  exu_i_rd_addr      = scalar_stall ? 5'b0  : du_rd_addr;
wire        exu_i_write_on_reg = scalar_stall ? 1'b0  : du_write_on_reg;

exu EXU (
    .CLK          (clk),
    .RST          (rst),
    .i_rs1_data   (du_rs1_data_reg),
    .i_rs2_data   (du_rs2_data_reg),
    .i_pc         (du_pc),
    .i_imm        (du_imm),
    .i_is_unsigned(du_is_unsigned),
    .i_rs1_2_pc   (du_rs1_2_pc),
    .i_is_branch  (exu_i_is_branch),
    .i_is_type_u  (du_is_type_u),
    .i_dual_op    (exu_i_dual_op),
    .i_data_size  (du_data_size),
    .i_alu_op     (du_alu_op),
    .i_alu_src_rs2(du_alu_src_rs2),
    .i_dmem_write (exu_i_dmem_write),
    .i_dmem_read  (exu_i_dmem_read),
    .i_rd_addr    (exu_i_rd_addr),
    .i_write_on_reg(exu_i_write_on_reg),
    .o_pc_upd     (exu_pc_upd),
    .o_take_br    (exu_take_br),
    .o_take_jmp   (exu_take_jmp),
    .o_rs2_data   (exu_rs2_data),
    .o_data_size  (exu_data_size),
    .o_dmem_write (exu_dmem_write),
    .o_is_unsigned(exu_is_unsigned),
    .o_result     (exu_result),
    .o_result2    (exu_result2),
    .o_dmem_read  (exu_dmem_read),
    .o_rd_addr    (exu_rd_addr),
    .o_write_on_reg(exu_write_on_reg)
);

wire [31:0] mem_dmem_address;
wire        mem_dmem_write;
wire        mem_dmem_read;
wire [31:0] mem_write_data;
wire [3:0]  mem_byte_en;
wire [1:0]  mem_data_size;
wire        mem_is_unsigned;

wire [31:0] mem_alu_result;
wire [4:0]  mem_rd_addr;
wire [1:0]  mem_wb_sel;
wire        mem_write_on_reg;

mem_unit mem0 (
    .clk          (clk),
    .reset        (rst),
    .i_alu_result (exu_result),
    .i_rs2_data   (exu_rs2_data),
    .i_rd_addr    (exu_rd_addr),
    .i_data_size  (exu_data_size),
    .i_is_unsigned(exu_is_unsigned),
    .i_dmem_write (exu_dmem_write),
    .i_dmem_read  (exu_dmem_read),
    .i_write_on_reg(exu_write_on_reg),
    .o_alu_result (mem_alu_result),
    .o_rd_addr    (mem_rd_addr),
    .o_wb_sel     (mem_wb_sel),
    .o_data_size  (mem_data_size),
    .o_write_on_reg(mem_write_on_reg),
    .o_is_unsigned(mem_is_unsigned),
    .o_write_data (mem_write_data),
    .o_dmem_address(mem_dmem_address),
    .o_byte_en    (mem_byte_en),
    .o_dmem_read  (mem_dmem_read),
    .o_dmem_write (mem_dmem_write)
);

wire [31:0] vext_mem_addr;
wire        vext_mem_read_en;
wire        vext_mem_write_en;
wire [31:0] vext_mem_wdata;
wire [3:0]  vext_mem_byte_en;

wire [31:0] vext_mem_addr_b;
wire        vext_mem_read_en_b;
wire        vext_mem_write_en_b;
wire [31:0] vext_mem_wdata_b;
wire [3:0]  vext_mem_byte_en_b;

// Port A mux: vector takes priority whenever its read/write enable is asserted;
// scalar takes over when the vector pipeline has no active Port A operation.
wire vec_port_a_active = vext_mem_read_en || vext_mem_write_en;
wire [31:0] dmem_addr_a     = vec_port_a_active ? {25'b0, vext_mem_addr[8:2]}   : {25'b0, mem_dmem_address[8:2]};
wire        dmem_write_en_a = vec_port_a_active ? vext_mem_write_en              : mem_dmem_write;
wire        dmem_read_en_a  = vec_port_a_active ? vext_mem_read_en               : mem_dmem_read;
wire [3:0]  dmem_byte_en_a  = vec_port_a_active ? vext_mem_byte_en               : mem_byte_en;
wire [31:0] dmem_wdata_a    = vec_port_a_active ? vext_mem_wdata                 : mem_write_data;
wire [31:0] dmem_rdata_a;
wire [31:0] dmem_rdata_b;

dcache dmem (
    .clk          (clk),
    .rst          (rst),
    .i_write_en   (dmem_write_en_a),
    .i_read_en    (dmem_read_en_a),
    .i_byte_en    (dmem_byte_en_a),
    .i_addr       (dmem_addr_a),
    .i_wdata      (dmem_wdata_a),
    .o_rdata      (dmem_rdata_a),
    .i_write_en_b (vext_mem_write_en_b),
    .i_read_en_b  (vext_mem_read_en_b),
    .i_byte_en_b  (vext_mem_byte_en_b),
    .i_addr_b     ({25'b0, vext_mem_addr_b[8:2]}),
    .i_wdata_b    (vext_mem_wdata_b),
    .o_rdata_b    (dmem_rdata_b)
);

wire [31:0] scalar_rdata = dmem_rdata_a;
wire [31:0] vec_rdata_a  = dmem_rdata_a;
wire [31:0] vec_rdata_b  = dmem_rdata_b;

localparam BYTE = 2'b00;
localparam HALF = 2'b01;
localparam WORD = 2'b11;

wire [7:0]  byte_val = scalar_rdata[7:0];
wire [15:0] half_val = scalar_rdata[15:0];

reg [31:0] o_loaded_data;
always @(posedge clk) begin
    if (rst) begin
        o_loaded_data <= 0;
    end else begin
        case (mem_data_size)
            BYTE: o_loaded_data <= mem_is_unsigned ? {24'b0, byte_val} : {{24{byte_val[7]}}, byte_val};
            HALF: o_loaded_data <= mem_is_unsigned ? {16'b0, half_val} : {{16{half_val[15]}}, half_val};
            WORD: o_loaded_data <= scalar_rdata;
            default: o_loaded_data <= o_loaded_data;
        endcase
    end
end

wb_unit wb0 (
    .clk          (clk),
    .rst          (rst),
    .i_dmem_data  (o_loaded_data),
    .i_alu_result (mem_alu_result),
    .i_rd_addr    (mem_rd_addr),
    .i_wb_sel     (mem_wb_sel),
    .i_write_on_reg(mem_write_on_reg),
    .o_write_data (wb_write_data),
    .o_rd_addr    (wb_rd_addr),
    .o_wen        (wb_wen)
);

ve_top vext (
    .clk              (clk),
    .rst              (rst),
    .i_alu_valid      (du_vec_valid),
    .i_funct7         (du_vec_funct7),
    .i_funct3         (du_vec_funct3),
    .i_rs1            (du_vec_rs1),
    .i_rs2            (du_vec_rs2),
    .i_rd             (du_vec_rd),
    .i_is_vx          (du_vec_is_vx),
    .i_scalar         (du_vec_scalar),
    .i_lsu_valid      (du_vec_lsu_valid),
    .i_is_load        (du_vec_is_load),
    .i_is_store       (du_vec_is_store),
    .i_is_mask_op     (du_vec_is_mask_op),
    .i_is_strided     (du_vec_is_strided),
    .i_is_indexed     (du_vec_is_indexed),
    .i_base_addr      (du_vec_base_addr),
    .i_stride         (du_vec_stride),
    .o_stall          (vec_stall),
    .o_mem_addr       (vext_mem_addr),
    .o_mem_read_en    (vext_mem_read_en),
    .i_mem_rdata      (vec_rdata_a),
    .o_mem_write_en   (vext_mem_write_en),
    .o_mem_wdata      (vext_mem_wdata),
    .o_mem_byte_en    (vext_mem_byte_en),
    .o_mem_addr_b     (vext_mem_addr_b),
    .o_mem_read_en_b  (vext_mem_read_en_b),
    .i_mem_rdata_b    (vec_rdata_b),
    .o_mem_write_en_b (vext_mem_write_en_b),
    .o_mem_wdata_b    (vext_mem_wdata_b),
    .o_mem_byte_en_b  (vext_mem_byte_en_b)
);

endmodule
