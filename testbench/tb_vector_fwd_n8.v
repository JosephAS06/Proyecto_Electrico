// =============================================================================
// Módulo: tb_vector_fwd_n8
// Archivo: testbench/tb_vector_fwd_n8.v
//
// Descripción:
//   Banco de pruebas vectorial N=8 con forwarding activo.
//   Elimina completamente los NOPs entre "addi x1" y "vle32/vse32" gracias
//   a la ruta fwd_vec_base_addr en ve_integrated.v (forwarding EX->EX).
//
//   Compara con tb_vector_n8.v (3 NOPs entre addi y vle32): 60 ciclos.
//
// Programa optimizado (16 instrucciones útiles):
//   [0]  addi x20, x0, 0
//   [1]  addi x1,  x0, 0     — base A[0..3]
//   [2]  vle32 v1, 0(x1)    — A[0..3]  (fwd: x1=0)
//   [3]  addi x1,  x0, 16   — base A[4..7]
//   [4]  vle32 v2, 0(x1)    — A[4..7]  (fwd: x1=16)
//   [5]  addi x1,  x0, 32   — base B[0..3]
//   [6]  vle32 v3, 0(x1)    — B[0..3]  (fwd: x1=32)
//   [7]  addi x1,  x0, 48   — base B[4..7]
//   [8]  vle32 v4, 0(x1)    — B[4..7]  (fwd: x1=48)
//   [9]  vadd v5, v1, v3    — C[0..3] = A[0..3]+B[0..3]
//   [10] vadd v6, v2, v4    — C[4..7] = A[4..7]+B[4..7]
//   [11] addi x1,  x0, 64   — base C[0..3]
//   [12] vse32 v5, 0(x1)    — C[0..3]  (fwd: x1=64)
//   [13] addi x1,  x0, 80   — base C[4..7]
//   [14] vse32 v6, 0(x1)    — C[4..7]  (fwd: x1=80)
//   [15] addi x20, x0, 1   — DONE
//   [16..63] NOP padding
//
// Layout DCache:
//   pos0..7   ( 0..28): A = {10,20,30,40,50,60,70,80}
//   pos8..15  (32..60): B = {10,20,30,40,50,60,70,80}
//   pos16..23 (64..92): C = {20,40,60,80,100,120,140,160}
//
// Resultado esperado en VRF:
//   v5 = {32'd80, 32'd60, 32'd40, 32'd20}
//   v6 = {32'd160, 32'd140, 32'd120, 32'd100}
// =============================================================================

`timescale 1ns/1ps
module tb_vector_fwd_n8;

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
    $dumpfile("tb_vector_fwd_n8.vcd");
    $dumpvars(0, tb_vector_fwd_n8);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Programa vectorial N=8 con forwarding — 0 NOPs entre addi y vle32/vse32
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base A[0..3] = byte 0
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2]  vle32 v1, 0(x1)    — A[0..3]  {0000001,00000,00001,110,00001,0000111}
    i_imem_addr =  2; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [3]  addi x1, x0, 16    — base A[4..7] = byte 16
    i_imem_addr =  3; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [4]  vle32 v2, 0(x1)    — A[4..7]  {0000001,00000,00001,110,00010,0000111}
    i_imem_addr =  4; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [5]  addi x1, x0, 32    — base B[0..3] = byte 32
    i_imem_addr =  5; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [6]  vle32 v3, 0(x1)    — B[0..3]  {0000001,00000,00001,110,00011,0000111}
    i_imem_addr =  6; i_imem_data = 32'h0200E187; @(posedge clk); #1;
    // [7]  addi x1, x0, 48    — base B[4..7] = byte 48
    i_imem_addr =  7; i_imem_data = 32'h03000093; @(posedge clk); #1;
    // [8]  vle32 v4, 0(x1)    — B[4..7]  {0000001,00000,00001,110,00100,0000111}
    i_imem_addr =  8; i_imem_data = 32'h0200E207; @(posedge clk); #1;
    // [9]  vadd v5, v1, v3    — C[0..3] = A[0..3]+B[0..3]
    //      {0000000,v3=00011,v1=00001,000,v5=00101,1010111} = 0x003082D7
    i_imem_addr =  9; i_imem_data = 32'h003082D7; @(posedge clk); #1;
    // [10] vadd v6, v2, v4    — C[4..7] = A[4..7]+B[4..7]
    //      {0000000,v4=00100,v2=00010,000,v6=00110,1010111} = 0x00410357
    i_imem_addr = 10; i_imem_data = 32'h00410357; @(posedge clk); #1;
    // [11] addi x1, x0, 64    — base C[0..3] = byte 64
    i_imem_addr = 11; i_imem_data = 32'h04000093; @(posedge clk); #1;
    // [12] vse32 v5, 0(x1)    — C[0..3]  {0000001,00000,00001,110,00101,0100111}
    i_imem_addr = 12; i_imem_data = 32'h0200E2A7; @(posedge clk); #1;
    // [13] addi x1, x0, 80    — base C[4..7] = byte 80
    i_imem_addr = 13; i_imem_data = 32'h05000093; @(posedge clk); #1;
    // [14] vse32 v6, 0(x1)    — C[4..7]  {0000001,00000,00001,110,00110,0100111}
    i_imem_addr = 14; i_imem_data = 32'h0200E327; @(posedge clk); #1;
    // [15] addi x20, x0, 1   — DONE
    i_imem_addr = 15; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [16..63] NOP padding
    begin : fill
        integer k;
        for (k = 16; k < 64; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    rst = 0;
    // A[0..7] → pos0..7 (byte 0..28)
    dut.dmem.pos0  = 32'd10;
    dut.dmem.pos1  = 32'd20;
    dut.dmem.pos2  = 32'd30;
    dut.dmem.pos3  = 32'd40;
    dut.dmem.pos4  = 32'd50;
    dut.dmem.pos5  = 32'd60;
    dut.dmem.pos6  = 32'd70;
    dut.dmem.pos7  = 32'd80;
    // B[0..7] → pos8..15 (byte 32..60)
    dut.dmem.pos8  = 32'd10;
    dut.dmem.pos9  = 32'd20;
    dut.dmem.pos10 = 32'd30;
    dut.dmem.pos11 = 32'd40;
    dut.dmem.pos12 = 32'd50;
    dut.dmem.pos13 = 32'd60;
    dut.dmem.pos14 = 32'd70;
    dut.dmem.pos15 = 32'd80;
end

always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR FWD N=8: %0d cycles ===", cycle_count);
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
