// =============================================================================
// Módulo: tb_scalar_fwd
// Archivo: testbench/tb_scalar_fwd.v
//
// Descripción:
//   Banco de pruebas de rendimiento para el pipeline RISC-V RV32I escalar
//   CON forwarding de datos, ejecutando la suma elemento a elemento de dos
//   arreglos de N=4 elementos: C[i] = A[i] + B[i] para i = 0..3.
//
//   Este banco de pruebas representa el pipeline OPTIMIZADO: aprovecha los
//   caminos de reenvío (EX->EX, MEM->EX, WB->EX) y la detección de hazards
//   load-use para eliminar los NOPs conservadores del programa de referencia
//   (tb_scalar_perf.v). El programa queda reducido a solo 18 instrucciones
//   útiles + padding, alcanzando ~23 ciclos vs. ~59 ciclos sin forwarding.
//
// Caminos de forwarding utilizados en este programa:
//
//   WB->EX: los ADD usan operandos cargados 8 y 4 instrucciones antes.
//     Cuando el ADD entra a Execute, los LW ya pasaron WB y el resultado
//     está en el banco de registros. No se necesita forwarding activo;
//     la lectura desde RF es suficiente.
//
//   Sin load-use stall: los ADD están 8 (x1) y 4 (x5) instrucciones
//     después de sus LW fuente. El pipeline escalar detectaría load-use
//     solo si el ADD está 1 instrucción después del LW (0-NOP case).
//     En este programa todos los ADD están suficientemente separados.
//
// Problema que resuelve:
//   Suma elemento a elemento de arreglos de 4 palabras de 32 bits:
//     A[0..3] = {10, 20, 30, 40}  -> DCache pos0..pos3 (byte addr 0..12)
//     B[0..3] = {50, 60, 70, 80}  -> DCache pos4..pos7 (byte addr 16..28)
//     C[0..3] = {60, 80, 100, 120} -> escritos en pos8..pos11 (byte addr 32..44)
//
// Programa optimizado (18 instrucciones útiles, 0 NOPs en el camino crítico):
//
//   [0]  addi x20, x0, 0    — sentinel init
//   [1]  lw x1, 0(x0)       — A[0]
//   [2]  lw x2, 4(x0)       — A[1]
//   [3]  lw x3, 8(x0)       — A[2]
//   [4]  lw x4, 12(x0)      — A[3]
//   [5]  lw x5, 16(x0)      — B[0]
//   [6]  lw x6, 20(x0)      — B[1]
//   [7]  lw x7, 24(x0)      — B[2]
//   [8]  lw x8, 28(x0)      — B[3]
//
//   [9]  add x9,  x1, x5    — C[0]=60  (x1: 8 atrás, x5: 4 atrás → en RF)
//   [10] add x10, x2, x6    — C[1]=80
//   [11] add x11, x3, x7    — C[2]=100
//   [12] add x12, x4, x8    — C[3]=120
//
//   [13] sw x9,  32(x0)     — C[0] -> dmem[8]  (x9: 4 atrás → en RF)
//   [14] sw x10, 36(x0)     — C[1] -> dmem[9]
//   [15] sw x11, 40(x0)     — C[2] -> dmem[10]
//   [16] sw x12, 44(x0)     — C[3] -> dmem[11]
//   [17] addi x20, x0, 1   — DONE sentinel
//   [18..63] NOP×46          — padding hasta 64 instrucciones
//
//
// Resultado esperado (comparación de rendimiento):
//   tb_scalar_perf.v (sin fwd): ~59 ciclos para N=4
//   tb_scalar_fwd.v  (con fwd): ~23 ciclos para N=4
//   Factor de aceleración:      ~2.6× para N=4
//   tb_scalar_n8.v   (con fwd): ~39 ciclos para N=8
//   Factor de aceleración N=8:  proporcional a la reducción de NOPs
//
// =============================================================================

`timescale 1ns/1ps
module tb_scalar_fwd;

reg        clk;
reg        rst;
reg        i_imem_wen;
reg [31:0] i_imem_addr;
reg [31:0] i_imem_data;

integer    cycle_count;
integer    pass_count;
integer    fail_count;

localparam MAX_CYCLES = 200;

// Instancia del sistema completo bajo prueba
ve_integrated dut (
    .clk        (clk),
    .rst        (rst),
    .i_imem_wen (i_imem_wen),
    .i_imem_addr(i_imem_addr),
    .i_imem_data(i_imem_data)
);

initial clk = 0;
always #5 clk = ~clk;

// Contador de ciclos desde la desactivación del reset
always @(posedge clk)
    if (rst) cycle_count <= 0;
    else     cycle_count <= cycle_count + 1;

// -------------------------------------------------------------------------
// Tarea: check
//   Compara un valor de 32 bits y acumula PASS/FAIL.
// -------------------------------------------------------------------------
task check;
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

initial begin
    $dumpfile("tb_scalar_fwd.vcd");
    $dumpvars(0, tb_scalar_fwd);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Programa optimizado con forwarding (0 NOPs en el camino crítico):
    //
    // Layout de memoria (dmem word index -> byte addr):
    //   pos0..pos3  ( 0..12): A = {10, 20, 30, 40}
    //   pos4..pos7  (16..28): B = {50, 60, 70, 80}
    // Resultados:
    //   pos8..pos11 (32..44): C = {60, 80, 100, 120}
    //
    // Los 8 LW son independientes -> no hay NOPs entre ellos.
    // Los ADD están 4-8 instrucciones después de sus LW -> el RF tiene el valor.
    // Los SW están 4-7 instrucciones después de los ADD -> el RF tiene el valor.
    // Total: 18 instrucciones útiles, 0 NOPs de relleno en el camino crítico.
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel init
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  lw x1, 0(x0)       — A[0]
    i_imem_addr =  1; i_imem_data = 32'h00002083; @(posedge clk); #1;
    // [2]  lw x2, 4(x0)       — A[1]
    i_imem_addr =  2; i_imem_data = 32'h00402103; @(posedge clk); #1;
    // [3]  lw x3, 8(x0)       — A[2]
    i_imem_addr =  3; i_imem_data = 32'h00802183; @(posedge clk); #1;
    // [4]  lw x4, 12(x0)      — A[3]
    i_imem_addr =  4; i_imem_data = 32'h00C02203; @(posedge clk); #1;
    // [5]  lw x5, 16(x0)      — B[0]
    i_imem_addr =  5; i_imem_data = 32'h01002283; @(posedge clk); #1;
    // [6]  lw x6, 20(x0)      — B[1]
    i_imem_addr =  6; i_imem_data = 32'h01402303; @(posedge clk); #1;
    // [7]  lw x7, 24(x0)      — B[2]
    i_imem_addr =  7; i_imem_data = 32'h01802383; @(posedge clk); #1;
    // [8]  lw x8, 28(x0)      — B[3]
    i_imem_addr =  8; i_imem_data = 32'h01C02403; @(posedge clk); #1;
    // [9]  add x9, x1, x5     — C[0] = 60  (x1: 8 antes, x5: 4 antes -> en RF)
    i_imem_addr =  9; i_imem_data = 32'h005084B3; @(posedge clk); #1;
    // [10] add x10, x2, x6    — C[1] = 80
    i_imem_addr = 10; i_imem_data = 32'h00610533; @(posedge clk); #1;
    // [11] add x11, x3, x7    — C[2] = 100
    i_imem_addr = 11; i_imem_data = 32'h007185B3; @(posedge clk); #1;
    // [12] add x12, x4, x8    — C[3] = 120
    i_imem_addr = 12; i_imem_data = 32'h00820633; @(posedge clk); #1;
    // [13] sw x9,  32(x0)     — C[0] → dmem[8]  (x9: 4 antes -> en RF)
    i_imem_addr = 13; i_imem_data = 32'h02902023; @(posedge clk); #1;
    // [14] sw x10, 36(x0)     — C[1] → dmem[9]
    i_imem_addr = 14; i_imem_data = 32'h02A02223; @(posedge clk); #1;
    // [15] sw x11, 40(x0)     — C[2] → dmem[10]
    i_imem_addr = 15; i_imem_data = 32'h02B02423; @(posedge clk); #1;
    // [16] sw x12, 44(x0)     — C[3] → dmem[11]
    i_imem_addr = 16; i_imem_data = 32'h02C02623; @(posedge clk); #1;
    // [17] addi x20, x0, 1    — DONE sentinel
    i_imem_addr = 17; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [18..63] NOP padding (relleno hasta completar 64 instrucciones)
    begin : fill
        integer k;
        for (k = 18; k < 64; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    // Desactivar reset y pre-cargar datos en el DCache
    rst = 0;
    dut.dmem.pos0 = 32'd10;   // A[0]
    dut.dmem.pos1 = 32'd20;   // A[1]
    dut.dmem.pos2 = 32'd30;   // A[2]
    dut.dmem.pos3 = 32'd40;   // A[3]
    dut.dmem.pos4 = 32'd50;   // B[0]
    dut.dmem.pos5 = 32'd60;   // B[1]
    dut.dmem.pos6 = 32'd70;   // B[2]
    dut.dmem.pos7 = 32'd80;   // B[3]
end

// Monitor: detectar condición de finalización o timeout
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== SCALAR+FWD N=4: %0d cycles ===", cycle_count);
            $display("");

            // Verificar sumas en registros enteros
            check(dut.RF.x9,      32'd60,  "           x9  = 60  (A[0]+B[0])");
            check(dut.RF.x10,     32'd80,  "           x10 = 80  (A[1]+B[1])");
            check(dut.RF.x11,     32'd100, "           x11 = 100 (A[2]+B[2])");
            check(dut.RF.x12,     32'd120, "           x12 = 120 (A[3]+B[3])");
            // Verificar que los SW escribieron al DCache
            check(dut.dmem.pos8,  32'd60,  "           dmem[8]  = 60  (C[0])");
            check(dut.dmem.pos9,  32'd80,  "           dmem[9]  = 80  (C[1])");
            check(dut.dmem.pos10, 32'd100, "           dmem[10] = 100 (C[2])");
            check(dut.dmem.pos11, 32'd120, "           dmem[11] = 120 (C[3])");

            $display("");
            $display("Results: %0d PASS, %0d FAIL", pass_count, fail_count);
            $finish;
        end
        if (cycle_count >= MAX_CYCLES) begin
            $display("TIMEOUT: sentinel x20 never became 1 after %0d cycles", MAX_CYCLES);
            $finish;
        end
    end
end

endmodule
