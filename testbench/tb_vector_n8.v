// =============================================================================
// Módulo: tb_vector_n8
// Archivo: testbench/tb_vector_n8.v
//
// Descripción:
//   Banco de pruebas de rendimiento para el pipeline vectorial ejecutando
//   la suma elemento a elemento de dos arreglos de N=8 elementos:
//   C[i] = A[i] + B[i] para i = 0..7.
//
//   Dado que VLEN=128 bits y cada elemento es de 32 bits, un registro vectorial
//   contiene 4 elementos. Para N=8 se necesitan 2 registros vectoriales por
//   arreglo, y por lo tanto el programa requiere:
//     - 2 × vle32: para A[0..3] en v1 y A[4..7] en v2
//     - 2 × vle32: para B[0..3] en v3 y B[4..7] en v4
//     - 2 × vadd:  v5 = v1 + v3 (C[0..3]), v6 = v2 + v4 (C[4..7])
//     - 2 × vse32: v5 → dmem pos16..pos19, v6 → dmem pos20..pos23
//
// Patrón del programa (repetición del patrón N=4 dos veces):
//   Para cada bloque de 4 elementos:
//     addi x1, x0, <base>  — establecer dirección base
//     NOP×3                — esperar que x1 llegue al WB (latencia escalar 3 ciclos)
//     vle32 vN, (x1)       — cargar 4 elementos vectoriales (vec_stall)
//     NOP×3                — buffer post-stall
//   Las dos vadd son consecutivas (v5=v1+v3, v6=v2+v4) sin NOPs entre ellas
//   porque son independientes entre sí.
//
// Por qué solo 3 NOPs entre addi y vle32 (a diferencia del N=4 con 5 NOPs):
//   El addi escribe x1 con latencia de 3 ciclos de pipeline escalar:
//     T0: addi en FU/DU
//     T1: addi en EXU (calcula el resultado)
//     T2: addi en MEM (pasa el resultado)
//     T3: addi en WB (escribe x1 en RF)
//   Con 3 NOPs entre addi y vle32, el vle32 entra a FU/DU en T4, cuando
//   addi ya escribió x1. El decodificador lee x1 del RF y lo pasa como
//   base_addr al pipeline vectorial. Esto es correcto.
//   Los 5 NOPs conservadores del N=4 son redundantes aquí porque el
//   forwarding escalar en el pipeline cubre el gap de 3 ciclos.
//
// Dos vadd consecutivas (v5=v1+v3, v6=v2+v4):
//   v5 y v6 no tienen dependencias entre sí (usan registros distintos).
//   Ninguna de las dos tiene hazard RAW con las cargas anteriores porque
//   hay suficientes instrucciones de por medio (al menos 8 ciclos desde
//   que v1, v2, v3, v4 se escribieron en el VRF).
//   La hazard_unit permite emitir ambas vadd consecutivamente.
//
// Programa (55 instrucciones útiles + 9 NOPs de padding = 64 total):
//
//   [0]  addi x20, x0, 0    — sentinel init
//   [1]  addi x1, x0, 0     — base_A1 = 0
//   [2..4]  NOP×3            — esperar x1=0 en RF
//   [5]  vle32 v1, (x1)     — A[0..3] en v1
//   [6..8]  NOP×3            — buffer post-stall
//   [9]  addi x1, x0, 16    — base_A2 = 16
//   [10..12] NOP×3           — esperar x1=16 en RF
//   [13] vle32 v2, (x1)     — A[4..7] en v2
//   [14..16] NOP×3           — buffer post-stall
//   [17] addi x1, x0, 32    — base_B1 = 32
//   [18..20] NOP×3           — esperar x1=32 en RF
//   [21] vle32 v3, (x1)     — B[0..3] en v3
//   [22..24] NOP×3           — buffer post-stall
//   [25] addi x1, x0, 48    — base_B2 = 48
//   [26..28] NOP×3           — esperar x1=48 en RF
//   [29] vle32 v4, (x1)     — B[4..7] en v4
//   [30..32] NOP×3           — buffer post-stall
//   [33] vadd v5, v1, v3    — C[0..3] = A[0..3] + B[0..3]
//   [34] vadd v6, v2, v4    — C[4..7] = A[4..7] + B[4..7] (independiente de v5)
//   [35..37] NOP×3           — buffer post-stall vadd
//   [38] addi x1, x0, 64    — base_C1 = 64
//   [39..41] NOP×3           — esperar x1=64 en RF
//   [42] vse32 v5, (x1)     — C[0..3] -> pos16..pos19
//   [43..45] NOP×3           — buffer post-stall
//   [46] addi x1, x0, 80    — base_C2 = 80
//   [47..49] NOP×3           — esperar x1=80 en RF
//   [50] vse32 v6, (x1)     — C[4..7] -> pos20..pos23
//   [51..53] NOP×3           — buffer post-stall
//   [54] addi x20, x0, 1   — DONE sentinel
//   [55..63] NOP×9           — padding hasta 64 instrucciones
//
// Resultado esperado (comparación de rendimiento):
//   tb_scalar_n8.v  (N=8 con fwd): ~39 ciclos
//   tb_vector_n8.v  (N=8 vectorial): ~60 ciclos
//
//   Para N=8 el escalar con forwarding sigue siendo más rápido porque:
//   - El overhead del pipeline vectorial (vec_stall + NOPs) es grande para N pequeño.
//   - La ventaja vectorial se manifiesta para N>>8, donde el overhead se amortiza.
//
// Verificaciones al terminar:
//   VRF:  v5={80,60,40,20} (bits[127:96]=C[3]), v6={160,140,120,100}
//   DCache: pos16..pos23 = {20,40,60,80,100,120,140,160}
//
// Mecanismo de terminación:
//   Sentinel x20=1. Timeout si cycle_count >= MAX_CYCLES = 500.
// =============================================================================

`timescale 1ns/1ps
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
// Tarea: check32 — verifica un resultado escalar de 32 bits
// -------------------------------------------------------------------------
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

// -------------------------------------------------------------------------
// Tarea: check128 — verifica un registro vectorial de 128 bits
// -------------------------------------------------------------------------
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

    // =========================================================================
    // Programa vectorial para N=8: 2×vle32 A, 2×vle32 B, 2×vadd, 2×vse32
    // 3 NOPs entre addi y vle32/vse32 (latencia de escritura del RF = 3 ciclos)
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base_A1 = 0 (byte addr de pos0)
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2..4]  NOP×3 — latencia de escritura de x1 (addi tarda 3 ciclos en WB)
    i_imem_addr =  2; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [5]  vle32 v1, 0(x1)    — cargar A[0..3] en v1
    //      Encoding: {0000001, 00000, x1=00001, 110, v1=00001, 0000111} = 0x0200E087
    i_imem_addr =  5; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [6..8]  NOP×3 — buffer post-stall de vle32 v1
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  7; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [9]  addi x1, x0, 16    — base_A2 = 16 (byte addr de pos4)
    i_imem_addr =  9; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [10..12]  NOP×3
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [13] vle32 v2, 0(x1)    — cargar A[4..7] en v2
    //      Encoding: {0000001, 00000, x1=00001, 110, v2=00010, 0000111} = 0x0200E107
    i_imem_addr = 13; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [14..16]  NOP×3
    i_imem_addr = 14; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 15; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [17] addi x1, x0, 32    — base_B1 = 32 (byte addr de pos8)
    i_imem_addr = 17; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [18..20]  NOP×3
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 20; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [21] vle32 v3, 0(x1)    — cargar B[0..3] en v3
    //      Encoding: {0000001, 00000, x1=00001, 110, v3=00011, 0000111} = 0x0200E187
    i_imem_addr = 21; i_imem_data = 32'h0200E187; @(posedge clk); #1;
    // [22..24]  NOP×3
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [25] addi x1, x0, 48    — base_B2 = 48 (byte addr de pos12)
    i_imem_addr = 25; i_imem_data = 32'h03000093; @(posedge clk); #1;
    // [26..28]  NOP×3
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [29] vle32 v4, 0(x1)    — cargar B[4..7] en v4
    //      Encoding: {0000001, 00000, x1=00001, 110, v4=00100, 0000111} = 0x0200E207
    i_imem_addr = 29; i_imem_data = 32'h0200E207; @(posedge clk); #1;
    // [30..32]  NOP×3 — buffer post-stall de vle32 v4
    i_imem_addr = 30; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [33] vadd v5, v1, v3    — C[0..3] = A[0..3] + B[0..3]
    //      Encoding: {0000000, v3=00011, v1=00001, 000, v5=00101, 1010111} = 0x003082D7
    i_imem_addr = 33; i_imem_data = 32'h003082D7; @(posedge clk); #1;
    // [34] vadd v6, v2, v4    — C[4..7] = A[4..7] + B[4..7] (independiente de v5)
    //      Encoding: {0000000, v4=00100, v2=00010, 000, v6=00110, 1010111} = 0x00410357
    i_imem_addr = 34; i_imem_data = 32'h00410357; @(posedge clk); #1;
    // [35..37]  NOP×3 — buffer post-stall del vadd v6
    i_imem_addr = 35; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 37; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [38] addi x1, x0, 64    — base_C1 = 64 (byte addr de pos16)
    i_imem_addr = 38; i_imem_data = 32'h04000093; @(posedge clk); #1;
    // [39..41]  NOP×3
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 41; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [42] vse32 v5, 0(x1)    — guardar C[0..3] -> pos16..pos19
    //      Encoding: {0000001, 00000, x1=00001, 110, v5=00101, 0100111} = 0x0200E2A7
    i_imem_addr = 42; i_imem_data = 32'h0200E2A7; @(posedge clk); #1;
    // [43..45]  NOP×3 — buffer post-stall del vse32 v5
    i_imem_addr = 43; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 44; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 45; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [46] addi x1, x0, 80    — base_C2 = 80 (byte addr de pos20)
    i_imem_addr = 46; i_imem_data = 32'h05000093; @(posedge clk); #1;
    // [47..49]  NOP×3
    i_imem_addr = 47; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [50] vse32 v6, 0(x1)    — guardar C[4..7] -> pos20..pos23
    //      Encoding: {0000001, 00000, x1=00001, 110, v6=00110, 0100111} = 0x0200E327
    i_imem_addr = 50; i_imem_data = 32'h0200E327; @(posedge clk); #1;
    // [51..53]  NOP×3 — buffer post-stall del vse32 v6
    i_imem_addr = 51; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 53; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [54] addi x20, x0, 1    — DONE sentinel
    i_imem_addr = 54; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [55..63]  NOP×9 padding hasta 64 instrucciones
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

    // Desactivar reset y pre-cargar datos en el DCache
    rst = 0;
    // A[0..7] -> pos0..pos7 (byte addr 0..28)
    dut.dmem.pos0  = 32'd10;  // A[0]
    dut.dmem.pos1  = 32'd20;  // A[1]
    dut.dmem.pos2  = 32'd30;  // A[2]
    dut.dmem.pos3  = 32'd40;  // A[3]
    dut.dmem.pos4  = 32'd50;  // A[4]
    dut.dmem.pos5  = 32'd60;  // A[5]
    dut.dmem.pos6  = 32'd70;  // A[6]
    dut.dmem.pos7  = 32'd80;  // A[7]
    // B[0..7] -> pos8..pos15 (byte addr 32..60)
    dut.dmem.pos8  = 32'd10;  // B[0]
    dut.dmem.pos9  = 32'd20;  // B[1]
    dut.dmem.pos10 = 32'd30;  // B[2]
    dut.dmem.pos11 = 32'd40;  // B[3]
    dut.dmem.pos12 = 32'd50;  // B[4]
    dut.dmem.pos13 = 32'd60;  // B[5]
    dut.dmem.pos14 = 32'd70;  // B[6]
    dut.dmem.pos15 = 32'd80;  // B[7]
end

// Monitor: detectar sentinel o timeout
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR N=8: %0d cycles ===", cycle_count);
            $display("");

            // Verificar registros vectoriales en el VRF
            // v5 = C[0..3]: bits[31:0]=C[0], ..., bits[127:96]=C[3]
            check128(dut.vext.vregfile.regs[5],
                     {32'd80, 32'd60, 32'd40, 32'd20},
                     "v5 = {80,60,40,20} (C[3..0])");
            // v6 = C[4..7]
            check128(dut.vext.vregfile.regs[6],
                     {32'd160, 32'd140, 32'd120, 32'd100},
                     "v6 = {160,140,120,100} (C[7..4])");
            // Verificar que vse32 escribió los 8 elementos al DCache
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
