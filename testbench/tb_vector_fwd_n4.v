// =============================================================================
// Módulo: tb_vector_fwd_n4
// Archivo: testbench/tb_vector_fwd_n4.v
//
// Descripción:
//   Banco de pruebas vectorial N=4 con forwarding activo.
//   Aprovecha la ruta fwd_vec_base_addr en ve_integrated.v para eliminar
//   los NOPs entre "addi x1" y "vle32/vse32". El forwarding EX->EX
//   entrega la dirección base correcta al pipeline vectorial en el mismo
//   ciclo en que el `addi` está en EXU y el "vle32" está en DU.
//
//   Compara con tb_vector_perf.v (sin forwarding, N=4): 57 ciclos.
//   Con forwarding se espera una reducción significativa.
//
// Programa optimizado (9 instrucciones útiles):
//   [0]  addi x20, x0, 0    — sentinel init
//   [1]  addi x1,  x0, 0    — base A = 0
//   [2]  vle32 v1, 0(x1)    — A[0..3]  (EX->EX fwd: x1=0 desde addi[1] en EXU)
//   [3]  addi x1,  x0, 16   — base B = 16
//   [4]  vle32 v2, 0(x1)    — B[0..3]  (EX->EX fwd: x1=16)
//   [5]  vadd v3, v1, v2    — v3 = A+B
//   [6]  addi x1,  x0, 32   — base C = 32
//   [7]  vse32 v3, 0(x1)    — C[0..3]  (EX->EX fwd: x1=32)
//   [8]  addi x20, x0, 1   — DONE
//   [9..63] NOP padding
//
// Layout DCache:
//   pos0..3  ( 0..12): A = {10, 20, 30, 40}
//   pos4..7  (16..28): B = {50, 60, 70, 80}
//   pos8..11 (32..44): C = {60, 80, 100, 120} (escritos por vse32)
//
// Resultado esperado:
//   v3 = {32'd120, 32'd100, 32'd80, 32'd60}
//   dmem pos8..pos11 = 60, 80, 100, 120
// =============================================================================

`timescale 1ns/1ps
module tb_vector_fwd_n4;

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
    $dumpfile("tb_vector_fwd_n4.vcd");
    $dumpvars(0, tb_vector_fwd_n4);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Carga del programa en ICache — 0 NOPs entre addi y vle32/vse32
    // El forwarding EX->EX (fwd_vec_base_addr) elimina la necesidad de NOPs.
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel init
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base A (byte 0)
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2]  vle32 v1, 0(x1)    — carga A[0..3]: EX→EX fwd da x1=0
    //      {0000001, 00000, x1=00001, 110, v1=00001, 0000111} = 0x0200E087
    i_imem_addr =  2; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [3]  addi x1, x0, 16    — base B (byte 16 = pos4)
    i_imem_addr =  3; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [4]  vle32 v2, 0(x1)    — carga B[0..3]: EX→EX fwd da x1=16
    //      {0000001, 00000, x1=00001, 110, v2=00010, 0000111} = 0x0200E107
    i_imem_addr =  4; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [5]  vadd v3, v1, v2    — v3 = A+B elemento a elemento
    //      {0000000, v2=00010, v1=00001, 000, v3=00011, 1010111} = 0x002081D7
    i_imem_addr =  5; i_imem_data = 32'h002081D7; @(posedge clk); #1;
    // [6]  addi x1, x0, 32    — base C (byte 32 = pos8)
    i_imem_addr =  6; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [7]  vse32 v3, 0(x1)    — guarda C[0..3]: EX→EX fwd da x1=32
    //      {0000001, 00000, x1=00001, 110, v3=00011, 0100111} = 0x0200E1A7
    i_imem_addr =  7; i_imem_data = 32'h0200E1A7; @(posedge clk); #1;
    // [8..12]  NOP — esperar que el vector store complete ACCESS_23
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  9; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [13]  addi x20, x0, 1   — DONE sentinel
    i_imem_addr = 13; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [14..63]  NOP padding
    begin : fill
        integer k;
        for (k = 14; k < 64; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    rst = 0;
    // A[0..3] -> pos0..3 (byte 0..12)
    dut.dmem.pos0 = 32'd10;
    dut.dmem.pos1 = 32'd20;
    dut.dmem.pos2 = 32'd30;
    dut.dmem.pos3 = 32'd40;
    // B[0..3] -> pos4..7 (byte 16..28)
    dut.dmem.pos4 = 32'd50;
    dut.dmem.pos5 = 32'd60;
    dut.dmem.pos6 = 32'd70;
    dut.dmem.pos7 = 32'd80;
end

always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR FWD N=4: %0d cycles ===", cycle_count);
            $display("");

            check128(dut.vext.vregfile.regs[3],
                     {32'd120, 32'd100, 32'd80, 32'd60},
                     "v3 = {120,100,80,60}");
            check32(dut.dmem.pos8,  32'd60,  "dmem[8]  = 60  (C[0])");
            check32(dut.dmem.pos9,  32'd80,  "dmem[9]  = 80  (C[1])");
            check32(dut.dmem.pos10, 32'd100, "dmem[10] = 100 (C[2])");
            check32(dut.dmem.pos11, 32'd120, "dmem[11] = 120 (C[3])");

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
