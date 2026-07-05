`timescale 1ns/1ps
// Vector performance testbench: C[i] = A[i] + B[i] for i = 0..7
// Uses 2×vle32 for A, 2×vle32 for B, 2×vadd, 2×vse32 (VLEN=128, 4 elem/reg).
// Memory layout:
//   pos0..pos7  ( 0..28): A = {10,20,30,40,50,60,70,80}
//   pos8..pos15 (32..60): B = {10,20,30,40,50,60,70,80}
//   pos16..pos23(64..92): C = {20,40,60,80,100,120,140,160}
module tb_vector_n8;

reg        clk;
reg        rst;
reg        i_imem_wen;
reg [31:0] i_imem_addr;
reg [31:0] i_imem_data;

integer    cycle_count;
integer    pass_count;
integer    fail_count;

localparam MAX_CYCLES = 500;

ve_integrated dut (
    .clk        (clk),
    .rst        (rst),
    .i_imem_wen (i_imem_wen),
    .i_imem_addr(i_imem_addr),
    .i_imem_data(i_imem_data)
);

initial clk = 0;
always #5 clk = ~clk;

always @(posedge clk)
    if (rst) cycle_count <= 0;
    else     cycle_count <= cycle_count + 1;

task check32;
    input [31:0]  got;
    input [31:0]  exp;
    input [255:0] name;
    begin
        if (got === exp) begin
            $display("PASS: %s", name);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: %s  got=%0d  exp=%0d", name, got, exp);
            fail_count = fail_count + 1;
        end
    end
endtask

task check128;
    input [127:0] got;
    input [127:0] exp;
    input [255:0] name;
    begin
        if (got === exp) begin
            $display("PASS: %s", name);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: %s  got=%h  exp=%h", name, got, exp);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    $dumpfile("tb_vector_n8.vcd");
    $dumpvars(0, tb_vector_n8);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // ----------------------------------------------------------------
    // Program: 2×vle32 A, 2×vle32 B, 2×vadd, 2×vse32
    // 3 NOPs between addi and vle32/vse32 (RF write latency = 3 cycles)
    // ----------------------------------------------------------------
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base_A1 = 0
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2..4]  NOP×3
    i_imem_addr =  2; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [5]  vle32 v1, 0(x1)    — load A[0..3]
    i_imem_addr =  5; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [6..8]  NOP×3
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  7; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [9]  addi x1, x0, 16    — base_A2 = 16
    i_imem_addr =  9; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [10..12]  NOP×3
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [13] vle32 v2, 0(x1)    — load A[4..7]
    i_imem_addr = 13; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [14..16]  NOP×3
    i_imem_addr = 14; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 15; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [17] addi x1, x0, 32    — base_B1 = 32
    i_imem_addr = 17; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [18..20]  NOP×3
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 20; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [21] vle32 v3, 0(x1)    — load B[0..3]
    i_imem_addr = 21; i_imem_data = 32'h0200E187; @(posedge clk); #1;
    // [22..24]  NOP×3
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [25] addi x1, x0, 48    — base_B2 = 48
    i_imem_addr = 25; i_imem_data = 32'h03000093; @(posedge clk); #1;
    // [26..28]  NOP×3
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [29] vle32 v4, 0(x1)    — load B[4..7]
    i_imem_addr = 29; i_imem_data = 32'h0200E207; @(posedge clk); #1;
    // [30..32]  NOP×3
    i_imem_addr = 30; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [33] vadd v5, v1, v3    — C[0..3] = A[0..3] + B[0..3]
    i_imem_addr = 33; i_imem_data = 32'h003082D7; @(posedge clk); #1;
    // [34] vadd v6, v2, v4    — C[4..7] = A[4..7] + B[4..7]
    i_imem_addr = 34; i_imem_data = 32'h00410357; @(posedge clk); #1;
    // [35..37]  NOP×3
    i_imem_addr = 35; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 37; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [38] addi x1, x0, 64    — base_C1 = 64
    i_imem_addr = 38; i_imem_data = 32'h04000093; @(posedge clk); #1;
    // [39..41]  NOP×3
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 41; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [42] vse32 v5, 0(x1)    — store C[0..3] → dmem pos16..pos19
    i_imem_addr = 42; i_imem_data = 32'h0200E2A7; @(posedge clk); #1;
    // [43..45]  NOP×3
    i_imem_addr = 43; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 44; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 45; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [46] addi x1, x0, 80    — base_C2 = 80
    i_imem_addr = 46; i_imem_data = 32'h05000093; @(posedge clk); #1;
    // [47..49]  NOP×3
    i_imem_addr = 47; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [50] vse32 v6, 0(x1)    — store C[4..7] → dmem pos20..pos23
    i_imem_addr = 50; i_imem_data = 32'h0200E327; @(posedge clk); #1;
    // [51..53]  NOP×3
    i_imem_addr = 51; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 53; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [54] addi x20, x0, 1    — DONE sentinel
    i_imem_addr = 54; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [55..63]  NOP×9 padding
    begin : fill
        integer k;
        for (k = 55; k < 64; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    rst = 0;
    dut.dmem.pos0  = 32'd10;  // A[0]
    dut.dmem.pos1  = 32'd20;  // A[1]
    dut.dmem.pos2  = 32'd30;  // A[2]
    dut.dmem.pos3  = 32'd40;  // A[3]
    dut.dmem.pos4  = 32'd50;  // A[4]
    dut.dmem.pos5  = 32'd60;  // A[5]
    dut.dmem.pos6  = 32'd70;  // A[6]
    dut.dmem.pos7  = 32'd80;  // A[7]
    dut.dmem.pos8  = 32'd10;  // B[0]
    dut.dmem.pos9  = 32'd20;  // B[1]
    dut.dmem.pos10 = 32'd30;  // B[2]
    dut.dmem.pos11 = 32'd40;  // B[3]
    dut.dmem.pos12 = 32'd50;  // B[4]
    dut.dmem.pos13 = 32'd60;  // B[5]
    dut.dmem.pos14 = 32'd70;  // B[6]
    dut.dmem.pos15 = 32'd80;  // B[7]
end

always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR N=8: %0d cycles ===", cycle_count);
            $display("");

            check128(dut.vext.vregfile.regs[5],
                     {32'd80, 32'd60, 32'd40, 32'd20},
                     "v5 = {80,60,40,20} (C[3..0])");
            check128(dut.vext.vregfile.regs[6],
                     {32'd160, 32'd140, 32'd120, 32'd100},
                     "v6 = {160,140,120,100} (C[7..4])");
            check32(dut.dmem.pos16, 32'd20,  "dmem[16] = 20  (C[0])");
            check32(dut.dmem.pos17, 32'd40,  "dmem[17] = 40  (C[1])");
            check32(dut.dmem.pos18, 32'd60,  "dmem[18] = 60  (C[2])");
            check32(dut.dmem.pos19, 32'd80,  "dmem[19] = 80  (C[3])");
            check32(dut.dmem.pos20, 32'd100, "dmem[20] = 100 (C[4])");
            check32(dut.dmem.pos21, 32'd120, "dmem[21] = 120 (C[5])");
            check32(dut.dmem.pos22, 32'd140, "dmem[22] = 140 (C[6])");
            check32(dut.dmem.pos23, 32'd160, "dmem[23] = 160 (C[7])");

            $display("");
            $display("Results: %0d PASS, %0d FAIL", pass_count, fail_count);
            $finish;
        end
        if (cycle_count >= MAX_CYCLES) begin
            $display("TIMEOUT after %0d cycles", MAX_CYCLES);
            $finish;
        end
    end
end

endmodule
