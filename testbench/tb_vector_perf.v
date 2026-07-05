// =============================================================================
// Módulo: tb_vector_perf
// Archivo: testbench/tb_vector_perf.v
//
// Descripción:
//   Banco de pruebas de rendimiento para el pipeline vectorial, ejecutando
//   la suma elemento a elemento de dos arreglos de N=4 elementos:
//   C[i] = A[i] + B[i] para i = 0..3.
//
//   Este banco de pruebas compara el rendimiento del pipeline vectorial frente
//   al escalar (tb_scalar_perf.v y tb_scalar_fwd.v) con los mismos datos y
//   la misma operación. La diferencia de ciclos cuantifica el costo de la
//   interfaz escalar→vectorial para lotes pequeños (N=4).
//
// Operación vectorial vs. escalar:
//   La extensión vectorial procesa 4 elementos de 32 bits en paralelo por
//   instrucción. Para N=4 se necesita solo 1 instrucción de carga (vle32),
//   1 instrucción de suma (vadd) y 1 instrucción de store (vse32) por arreglo.
//   Sin embargo, las instrucciones vectoriales tienen mayor latencia que las
//   escalares (2 ciclos de DCache en lugar de 1), y el pipeline escalar debe
//   detenerse (vec_stall) durante toda la ejecución de cada instrucción vectorial.
//
// Programa vectorial (52 instrucciones útiles + padding):
//
//   [0]  addi x20, x0, 0    — sentinel init
//   [1]  addi x1,  x0, 0    — base addr A = 0 (byte address)
//   [2..6]  NOP×5            — esperar x1=0 en RF (5 NOPs conservadores)
//   [7]  vle32 v1, (x1)     — carga A[0..3] en v1 (vec_stall se activa)
//   [8..14]  NOP×7           — buffer post-stall
//   [15] addi x1,  x0, 16   — base addr B = 16
//   [16..20] NOP×5           — esperar x1=16 en RF
//   [21] vle32 v2, (x1)     — carga B[0..3] en v2 (vec_stall)
//   [22..28] NOP×7           — buffer post-stall
//   [29] vadd v3, v1, v2    — v3 = A + B elemento a elemento (vec_stall)
//   [30..36] NOP×7           — buffer post-stall
//   [37] addi x1,  x0, 32   — base addr C = 32
//   [38..42] NOP×5           — esperar x1=32 en RF
//   [43] vse32 v3, (x1)     — guarda C[0..3] en dmem[8..11] (vec_stall)
//   [44..50] NOP×7           — buffer post-stall
//   [51] addi x20, x0, 1   — DONE: sentinel x20 = 1
//   [52..63] NOP×12          — padding
//
// Relación entre vec_stall y el pipeline escalar:
//   Cuando ve_top activa vec_stall (o_stall=1), las etapas FU y DU del pipeline
//   escalar se congelan: no avanzan instrucciones y no se actualizan los
//   registros de FU->DU. La instrucción siguiente a una instrucción vectorial
//   solo puede entrar al pipeline escalar cuando vec_stall=0.
//   Durante el stall el PC no avanza -> los NOPs post-stall actúan como
//   buffer hasta que el pipeline vectorial complete su WB.
//
// ¿Por qué 5 NOPs entre addi y vle32?
//   La instrucción vle32 lee el registro entero x1 (base_addr) como parte de
//   su decodificación vectorial. El addi x1 escribe a x1 con latencia de 3
//   ciclos de pipeline escalar (EXU -> MEM -> WB). Con 5 NOPs conservadores
//   se garantiza que x1 tiene el valor correcto antes de que vle32 se decodifique,
//   independientemente de si hay forwarding escalar activo.
//
// Codificación de instrucciones vectoriales:
//   vle32 vd, 0(rs1):
//     {7'b0000001, 5'b00000, rs1[4:0], 3'b110, vd[4:0], 7'b0000111}
//     vle32 v1, (x1)=0x0200E087  vle32 v2, (x1)=0x0200E107
//   vse32 vs3, 0(rs1):
//     {7'b0000001, 5'b00000, rs1[4:0], 3'b110, vs3[4:0], 7'b0100111}
//     vse32 v3, (x1)=0x0200E1A7
//   vadd v3, v1, v2:
//     {7'b0000000, vs2=00010, vs1=00001, 3'b000, vd=00011, 7'b1010111}
//     = 0x002081D7
//
// Resultado esperado (comparación):
//   tb_scalar_perf.v (sin fwd): ~59 ciclos para N=4
//   tb_scalar_fwd.v  (con fwd): ~23 ciclos para N=4
//   tb_vector_perf.v (vectorial):~57 ciclos para N=4
//
//   Conclusión N=4: el pipeline vectorial no supera al escalar con forwarding.
//   La ventaja vectorial se manifiesta para N mayor (ver tb_vector_n8.v).
//   Para N=8: escalar ~39 ciclos, vectorial ~60 ciclos (pero con 2× más datos).
//
// Verificaciones al terminar:
//   v3 en el VRF: {32'd120, 32'd100, 32'd80, 32'd60} (elemento 3 en bits altos)
//   dmem pos8..pos11: 60, 80, 100, 120 (escritos por vse32)
//
// Mecanismo de terminación:
//   Sentinel x20=1 detectado en el bloque always @(posedge clk).
//   Timeout si cycle_count >= MAX_CYCLES = 500.
// =============================================================================

`timescale 1ns/1ps
module tb_vector_perf;

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
// Tarea: check128 — verifica un resultado vectorial de 128 bits
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
    $dumpfile("tb_vector_perf.vcd");
    $dumpvars(0, tb_vector_perf);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Carga del programa vectorial en la ICache (word-indexed)
    //
    // Layout de memoria (DCache word index → byte address):
    //   pos0..pos3  ( 0..12): A = {10, 20, 30, 40}
    //   pos4..pos7  (16..28): B = {50, 60, 70, 80}
    //   pos8..pos11 (32..44): C = {60, 80, 100, 120} (escritos por vse32)
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel init
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base addr A = 0 (byte address de pos0)
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2..6]  NOP×5 — esperar que x1=0 llegue al WB antes de que vle32 lo lea
    i_imem_addr =  2; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  5; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [7]  vle32 v1, (x1)     — carga A[0..3] en v1, vec_stall se activa
    //      Encoding: {0000001, 00000, x1=00001, 110, v1=00001, 0000111}
    i_imem_addr =  7; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [8..14]  NOP×7 — buffer post-stall (vec_stall congela el pipeline escalar)
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  9; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 13; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 14; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [15]  addi x1, x0, 16   — base addr B = 16 (byte address de pos4)
    i_imem_addr = 15; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [16..20]  NOP×5 — esperar x1=16 en RF
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 17; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 20; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [21]  vle32 v2, (x1)    — carga B[0..3] en v2
    //       Encoding: {0000001, 00000, x1=00001, 110, v2=00010, 0000111}
    i_imem_addr = 21; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [22..28]  NOP×7 — buffer post-stall
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 25; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [29]  vadd v3, v1, v2   — v3 = A + B elemento a elemento
    //       Encoding: {0000000, v2=00010, v1=00001, 000, v3=00011, 1010111}
    i_imem_addr = 29; i_imem_data = 32'h002081D7; @(posedge clk); #1;
    // [30..36]  NOP×7 — buffer post-stall del vadd
    i_imem_addr = 30; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 33; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 34; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 35; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [37]  addi x1, x0, 32   — base addr C = 32 (byte address de pos8)
    i_imem_addr = 37; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [38..42]  NOP×5 — esperar x1=32 en RF
    i_imem_addr = 38; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 41; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 42; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [43]  vse32 v3, (x1)    — guarda C[0..3] en dmem pos8..pos11
    //       Encoding: {0000001, 00000, x1=00001, 110, v3=00011, 0100111}
    i_imem_addr = 43; i_imem_data = 32'h0200E1A7; @(posedge clk); #1;
    // [44..50]  NOP×7 — buffer post-stall del vse32
    i_imem_addr = 44; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 45; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 46; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 47; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 50; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [51]  addi x20, x0, 1   — DONE: sentinel x20 = 1
    i_imem_addr = 51; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [52..63]  NOP×12 padding
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 53; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 54; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 55; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 56; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 57; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 58; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 59; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 60; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 61; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 62; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 63; i_imem_data = 32'h00000013; @(posedge clk); #1;

    i_imem_wen = 0;

    // Esperar que la ICache pase a modo lectura
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

// Monitor: detectar sentinel o timeout
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR PERFORMANCE RESULT: %0d cycles ===", cycle_count);
            $display("");

            // Verificar el registro vectorial v3 en el VRF
            // Empaquetado: bits[31:0]=C[0], bits[63:32]=C[1], ..., bits[127:96]=C[3]
            check128(dut.vext.vregfile.regs[3],
                     {32'd120, 32'd100, 32'd80, 32'd60},
                     "v3 = {120,100,80,60} (vadd result)");
            // Verificar que vse32 escribió los 4 elementos al DCache
            check32(dut.dmem.pos8,  32'd60,  "dmem[8]  = 60  (C[0])");
            check32(dut.dmem.pos9,  32'd80,  "dmem[9]  = 80  (C[1])");
            check32(dut.dmem.pos10, 32'd100, "dmem[10] = 100 (C[2])");
            check32(dut.dmem.pos11, 32'd120, "dmem[11] = 120 (C[3])");

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
