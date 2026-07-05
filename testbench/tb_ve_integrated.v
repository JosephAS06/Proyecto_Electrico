// =============================================================================
// Módulo: tb_ve_integrated
// Archivo: testbench/tb_ve_integrated.v
//
// Descripción:
//   Banco de pruebas de integración completa para el sistema `ve_integrated`.
//   Verifica el funcionamiento conjunto del pipeline RISC-V RV32I y la
//   extensión vectorial, ejecutando un programa mixto que combina instrucciones
//   escalares (ADDI, SW, LW) y vectoriales (VADD, VSUB, VAND, VXOR, VLE32, VSE32).
//
// Interfaz del banco de pruebas con ve_integrated:
//   - clk, rst: señales globales de reloj y reset.
//   - i_imem_wen, i_imem_addr, i_imem_data: interfaz de carga de instrucciones.
//     Mientras rst=1 o en modo escritura, se cargan las instrucciones en la
//     ICache (word-indexed: addr=0..63).
//
// Mecanismo de terminación (sentinel):
//   El programa termina con `addi x20, x0, 1` (instrucción [62]).
//   El bloque `always @(posedge clk)` monitorea `dut.RF.x20`:
//   - Cuando x20 === 1: se imprime el contador de ciclos, se ejecutan las
//     verificaciones y se llama a $finish.
//   - Si cycle_count >= MAX_CYCLES (500): timeout, $finish sin verificaciones.
//
// Contador de ciclos:
//   Se incrementa en cada flanco positivo del reloj cuando rst=0.
//   Mide el tiempo desde la desactivación del reset hasta el sentinel.
//
// Programa cargado en la ICache (64 palabras word-indexed):
//
//   Fase 1 — Tests escalares:
//   [0]  addi x3, x0, 5      -> x3 = 5
//   [1]  addi x4, x0, 10     -> x4 = 10
//   [2]  addi x5, x0, 42     -> x5 = 42
//   [3..7]   NOP×5            -> espera a que x5 llegue a WB antes del SW
//   [8]  sw x5, 0(x0)        -> DCache[0] = 42
//   [9..13]  NOP×5            -> espera a que sw complete antes del LW
//   [14] lw x6, 0(x0)        -> x6 = DCache[0] = 42
//   [15..19] NOP×5            -> espera a que lw complete
//
//   Fase 2 — Tests vectoriales (ALU):
//   [20] vadd v3, v1, v2     -> v3 = {4{300}}  (v1={4{100}}, v2={4{200}})
//   [21..24] NOP×4
//   [25] vsub v4, v2, v1     -> v4 = {4{100}}
//   [26..29] NOP×4
//   [30] vand v5, v1, v2     -> v5 = {4{64}}   (100 AND 200)
//   [31..34] NOP×4
//   [35] vxor v6, v1, v2     -> v6 = {4{172}}  (100 XOR 200)
//   [36..40] NOP×5
//
//   Fase 3 — Tests vectoriales (LSU):
//   [41] addi x1, x0, 16    -> x1 = 16 (base addr para vle32)
//   [42..46] NOP×5           -> espera a que x1 llegue a WB (latencia scalar)
//   [47] vle32 v8, (x1)     -> v8 = {444, 333, 222, 111} (de DCache[4..7])
//   [48..54] NOP×7           -> espera a que vle32 complete (stall vectorial)
//   [55] addi x1, x0, 32    -> x1 = 32 (base addr para vse32)
//   [56..60] NOP×5           -> espera a que x1 llegue a WB
//   [61] vse32 v9, (x1)     -> DCache[8..11] = {666, 777, 888, 999} (v9 pre-cargado)
//   [62] addi x20, x0, 1   -> sentinel = 1 (DONE)
//   [63] NOP padding
//
// Pre-carga de datos (antes del primer posedge tras rst=0):
//   VRF: v1={4{100}}, v2={4{200}}, v9={999, 888, 777, 666}
//   DCache: pos4=111, pos5=222, pos6=333, pos7=444 (para vle32)
//
// Verificaciones al terminar:
//   Pipeline escalar:
//     x3=5, x4=10, x5=42 (addi)
//     dmem.pos0=42 (sw)
//     x6=42 (lw)
//   Pipeline vectorial — ALU:
//     v3={4{300}} (vadd), v4={4{100}} (vsub)
//     v5={4{64}} (vand), v6={4{172}} (vxor)
//   Pipeline vectorial — LSU:
//     v8={444,333,222,111} (vle32)
//     dmem.pos8=666, pos9=777, pos10=888, pos11=999 (vse32)
// =============================================================================

`timescale 1ns/1ps
module tb_ve_integrated;

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

// -------------------------------------------------------------------------
// Contador de ciclos
//   Se reinicia a 0 cuando rst=1 y avanza 1 cada ciclo cuando rst=0.
//   Mide la cantidad de ciclos de reloj que tarda el programa en completar.
// -------------------------------------------------------------------------
always @(posedge clk)
    if (rst) cycle_count <= 0;
    else     cycle_count <= cycle_count + 1;

// -------------------------------------------------------------------------
// Tarea: check32
//   Compara un valor de 32 bits con el esperado e imprime PASS/FAIL.
//   "name" es una cadena descriptiva del punto de verificación.
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
// Tarea: check128
//   Compara un valor vectorial de 128 bits con el esperado.
//   Los vectores se imprimen en hexadecimal (32 dígitos).
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
    $dumpfile("tb_ve_integrated.vcd");
    $dumpvars(0, tb_ve_integrated);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Carga del programa en la ICache (64 instrucciones word-indexed)
    //
    // La ICache se carga en modo escritura (i_imem_wen=1) mientras rst=1.
    // Cada ciclo avanza la dirección y carga una instrucción de 32 bits.
    // La dirección es word-indexed: addr=N carga la instrucción N.
    //
    // Pruebas escalares:
    //   addi x3,x0,5 / addi x4,x0,10 / addi x5,x0,42
    //   sw x5, 0(x0)   -> DCache[0] = 42
    //   lw x6, 0(x0)   -> x6 = 42
    //
    // Pruebas vectoriales (v1={100×4}, v2={200×4}, v9={999,888,777,666}):
    //   vadd v3,v1,v2  -> {300×4}
    //   vsub v4,v2,v1  -> {100×4}
    //   vand v5,v1,v2  -> {64×4}   (100 AND 200 = 0x64 AND 0xC8 = 0x40 = 64)
    //   vxor v6,v1,v2  -> {172×4}  (100 XOR 200 = 0x64 XOR 0xC8 = 0xAC = 172)
    //   vle32 v8,(x1)  -> {444,333,222,111} de DCache[4..7]
    //   vse32 v9,(x1)  -> DCache[8..11] = {666,777,888,999}
    //
    // [62] addi x20, x0, 1  — sentinel DONE
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x3, x0, 5
    i_imem_addr =  0; i_imem_data = 32'h00500193; @(posedge clk); #1;
    // [1]  addi x4, x0, 10
    i_imem_addr =  1; i_imem_data = 32'h00A00213; @(posedge clk); #1;
    // [2]  addi x5, x0, 42
    i_imem_addr =  2; i_imem_data = 32'h02A00293; @(posedge clk); #1;
    // [3..7]  NOP×5 — esperar que x5 llegue al WB antes del SW
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  5; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  7; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [8]  sw x5, 0(x0) -> DCache[0] = 42
    i_imem_addr =  8; i_imem_data = 32'h00502023; @(posedge clk); #1;
    // [9..13]  NOP×5 — esperar que el SW complete antes del LW
    i_imem_addr =  9; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 13; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [14]  lw x6, 0(x0) -> x6 = DCache[0] = 42
    i_imem_addr = 14; i_imem_data = 32'h00002303; @(posedge clk); #1;
    // [15..19]  NOP×5
    i_imem_addr = 15; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 17; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [20]  vadd v3, v1, v2 → v3 = {4{300}}
    i_imem_addr = 20; i_imem_data = 32'h002081D7; @(posedge clk); #1;
    // [21..24]  NOP×4 — esperar stall vectorial y que vadd complete
    i_imem_addr = 21; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [25]  vsub v4, v2, v1 -> v4 = {4{100}}
    i_imem_addr = 25; i_imem_data = 32'h40110257; @(posedge clk); #1;
    // [26..29]  NOP×4
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 29; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [30]  vand v5, v1, v2 -> v5 = {4{64}}
    i_imem_addr = 30; i_imem_data = 32'h0020F2D7; @(posedge clk); #1;
    // [31..34]  NOP×4
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 33; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 34; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [35]  vxor v6, v1, v2 -> v6 = {4{172}}
    i_imem_addr = 35; i_imem_data = 32'h0020C357; @(posedge clk); #1;
    // [36..40]  NOP×5
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 37; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 38; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [41]  addi x1, x0, 16 — base addr = 16 (byte addr del pos4)
    i_imem_addr = 41; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [42..46]  NOP×5 — esperar que x1=16 llegue al WB antes de vle32
    i_imem_addr = 42; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 43; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 44; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 45; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 46; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [47]  vle32 v8, (x1) -> v8 = {444, 333, 222, 111}
    i_imem_addr = 47; i_imem_data = 32'h0200E407; @(posedge clk); #1;
    // [48..54]  NOP×7 — esperar que vle32 complete (stall + pipeline)
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 50; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 51; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 53; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 54; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [55]  addi x1, x0, 32 — base addr = 32 (byte addr del pos8)
    i_imem_addr = 55; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [56..60]  NOP×5 — esperar que x1=32 llegue al WB antes de vse32
    i_imem_addr = 56; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 57; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 58; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 59; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 60; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [61]  vse32 v9, (x1) -> DCache[8..11] = {666, 777, 888, 999}
    i_imem_addr = 61; i_imem_data = 32'h0200E4A7; @(posedge clk); #1;
    // [62]  addi x20, x0, 1 — sentinel DONE
    i_imem_addr = 62; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [63]  NOP padding
    i_imem_addr = 63; i_imem_data = 32'h00000013; @(posedge clk); #1;

    i_imem_wen = 0;

    // Esperar que la ICache pase a modo lectura
    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Desactivar reset y pre-cargar datos
    //   Las asignaciones directas a registros del VRF y DCache son válidas
    //   en simulación mediante referencias jerárquicas.
    // =========================================================================
    rst = 0;

    // VRF: datos para las operaciones ALU vectoriales
    dut.vext.vregfile.regs[1] = {4{32'd100}}; // v1 = {100, 100, 100, 100}
    dut.vext.vregfile.regs[2] = {4{32'd200}}; // v2 = {200, 200, 200, 200}
    // v9 = dato fuente para vse32 (empaquetado: bits[31:0]=elem0)
    dut.vext.vregfile.regs[9] = {32'd999, 32'd888, 32'd777, 32'd666};

    // DCache: datos para vle32 en posiciones pos4..pos7 (byte addr 16..28)
    dut.dmem.pos4 = 32'd111;  // elemento 0 del vector (addr base = x1 = 16)
    dut.dmem.pos5 = 32'd222;  // elemento 1
    dut.dmem.pos6 = 32'd333;  // elemento 2
    dut.dmem.pos7 = 32'd444;  // elemento 3
end

// =========================================================================
// Monitor de terminación
//   En cada flanco positivo del reloj (cuando rst=0) se verifica:
//   1. Si x20 = 1 -> programa completado, ejecutar verificaciones.
//   2. Si cycle_count >= MAX_CYCLES -> timeout, terminar con error.
// =========================================================================
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== INTEGRATION TEST DONE: %0d cycles ===", cycle_count);
            $display("");

            // --- Pipeline escalar ---
            check32(dut.RF.x3,     32'd5,  "x3 = 5          (addi)");
            check32(dut.RF.x4,     32'd10, "x4 = 10         (addi)");
            check32(dut.RF.x5,     32'd42, "x5 = 42         (addi)");
            check32(dut.dmem.pos0, 32'd42, "dmem[0] = 42    (scalar sw)");
            check32(dut.RF.x6,     32'd42, "x6 = 42         (scalar lw)");

            // --- Operaciones ALU vectoriales ---
            check128(dut.vext.vregfile.regs[3], {4{32'd300}},
                     "v3 = {300x4}              (vadd)");
            check128(dut.vext.vregfile.regs[4], {4{32'd100}},
                     "v4 = {100x4}              (vsub)");
            check128(dut.vext.vregfile.regs[5], {4{32'd64}},
                     "v5 = {64x4}               (vand)");
            check128(dut.vext.vregfile.regs[6], {4{32'd172}},
                     "v6 = {172x4}              (vxor)");

            // --- Carga y almacenamiento vectorial ---
            check128(dut.vext.vregfile.regs[8],
                     {32'd444, 32'd333, 32'd222, 32'd111},
                     "v8 = {444,333,222,111}    (vle32)");
            check32(dut.dmem.pos8,  32'd666, "dmem[8]  = 666  (vse32 e0)");
            check32(dut.dmem.pos9,  32'd777, "dmem[9]  = 777  (vse32 e1)");
            check32(dut.dmem.pos10, 32'd888, "dmem[10] = 888  (vse32 e2)");
            check32(dut.dmem.pos11, 32'd999, "dmem[11] = 999  (vse32 e3)");

            $display("");
            $display("Results: %0d PASS, %0d FAIL", pass_count, fail_count);
            $finish;
        end
        if (cycle_count >= MAX_CYCLES) begin
            $display("TIMEOUT: sentinel x20 never became 1 after %0d cycles",
                     MAX_CYCLES);
            $finish;
        end
    end
end

endmodule
