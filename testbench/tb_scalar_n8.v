// =============================================================================
// Módulo: tb_scalar_n8
// Archivo: testbench/tb_scalar_n8.v
//
// Descripción:
//   Banco de pruebas de rendimiento para el pipeline RISC-V RV32I escalar
//   CON forwarding, ejecutando la suma elemento a elemento de dos arreglos
//   de N=8 elementos: C[i] = A[i] + B[i] para i = 0..7.
//
//   Extiende tb_scalar_fwd.v (N=4) al doble de elementos para evaluar cómo
//   escala el rendimiento del pipeline escalar. Se compara con tb_vector_n8.v
//   que resuelve el mismo problema con instrucciones vectoriales.
//
// Estrategia (misma que tb_scalar_fwd.v, escalada a N=8):
//   - 16 cargas (lw) consecutivas sin NOPs entre ellas (son independientes).
//   - 8 sumas (add) consecutivas sin NOPs (están suficientemente separadas).
//   - 8 almacenamientos (sw) consecutivos sin NOPs.
//   - 0 NOPs en el camino crítico -> el forwarding maneja las dependencias.
//
// Programa (34 instrucciones útiles + padding hasta 64):
//
//   [0]   addi x20, x0, 0    — sentinel init
//
//   Cargas de A[0..7] en x1..x8:
//   [1]  lw x1, 0(x0)       — A[0] = 10
//   [2]  lw x2, 4(x0)       — A[1] = 20
//   [3]  lw x3, 8(x0)       — A[2] = 30
//   [4]  lw x4, 12(x0)      — A[3] = 40
//   [5]  lw x5, 16(x0)      — A[4] = 50
//   [6]  lw x6, 20(x0)      — A[5] = 60
//   [7]  lw x7, 24(x0)      — A[6] = 70
//   [8]  lw x8, 28(x0)      — A[7] = 80
//
//   Cargas de B[0..7] en x9..x16:
//   [9]  lw x9,  32(x0)     — B[0] = 10
//   [10] lw x10, 36(x0)     — B[1] = 20
//   [11] lw x11, 40(x0)     — B[2] = 30
//   [12] lw x12, 44(x0)     — B[3] = 40
//   [13] lw x13, 48(x0)     — B[4] = 50
//   [14] lw x14, 52(x0)     — B[5] = 60
//   [15] lw x15, 56(x0)     — B[6] = 70
//   [16] lw x16, 60(x0)     — B[7] = 80
//
//   Sumas C[0..7]:
//   [17] add x17, x1,  x9   — C[0] = 20
//   [18] add x18, x2,  x10  — C[1] = 40
//   [19] add x19, x3,  x11  — C[2] = 60
//   [20] add x21, x4,  x12  — C[3] = 80   
//   [21] add x22, x5,  x13  — C[4] = 100
//   [22] add x23, x6,  x14  — C[5] = 120
//   [23] add x24, x7,  x15  — C[6] = 140
//   [24] add x25, x8,  x16  — C[7] = 160
//
//   Almacenamientos C[0..7] -> pos16..pos23 (byte addr 64..92):
//   [25] sw x17, 64(x0)     — dmem[16] = 20
//   [26] sw x18, 68(x0)     — dmem[17] = 40
//   [27] sw x19, 72(x0)     — dmem[18] = 60
//   [28] sw x21, 76(x0)     — dmem[19] = 80
//   [29] sw x22, 80(x0)     — dmem[20] = 100
//   [30] sw x23, 84(x0)     — dmem[21] = 120
//   [31] sw x24, 88(x0)     — dmem[22] = 140
//   [32] sw x25, 92(x0)     — dmem[23] = 160
//
//   [33] addi x20, x0, 1   — DONE
//   [34..63] NOP×30          — padding hasta 64 instrucciones
//
// Resultado esperado:
//   tb_scalar_n8.v  (N=8 con fwd): ~39 ciclos
//   tb_vector_n8.v  (N=8 vectorial): ~60 ciclos
//   Nota: la ventaja escalar en N=8 se debe al overhead del pipeline vectorial
//         (múltiples vle32 y vec_stall repetidos). Con N muy grande el vector
//         supera al escalar.
//
// Mecanismo de terminación:
//   x20=1. Timeout si cycle_count >= MAX_CYCLES = 300.
// =============================================================================

`timescale 1ns/1ps
module tb_scalar_n8;

reg        clk;
reg        rst;
reg        i_imem_wen;
reg [31:0] i_imem_addr;
reg [31:0] i_imem_data;

integer    cycle_count;
integer    pass_count;
integer    fail_count;

localparam MAX_CYCLES = 300;

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
// Tarea: check — verifica un resultado de 32 bits
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
    $dumpfile("tb_scalar_n8.vcd");
    $dumpvars(0, tb_scalar_n8);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    i_imem_wen = 1;

    // [0]  addi x20, x0, 0     
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;

    // =========================================================================
    // Sección 1: Cargas de A[0..7] en x1..x8
    //   Todas las cargas son independientes -> no hay NOPs entre ellas.
    //   Las direcciones incrementan de 4 en 4 bytes.
    // =========================================================================
    i_imem_addr =  1; i_imem_data = 32'h00002083; @(posedge clk); #1; // lw x1,  0(x0)  A[0]
    i_imem_addr =  2; i_imem_data = 32'h00402103; @(posedge clk); #1; // lw x2,  4(x0)  A[1]
    i_imem_addr =  3; i_imem_data = 32'h00802183; @(posedge clk); #1; // lw x3,  8(x0)  A[2]
    i_imem_addr =  4; i_imem_data = 32'h00C02203; @(posedge clk); #1; // lw x4, 12(x0)  A[3]
    i_imem_addr =  5; i_imem_data = 32'h01002283; @(posedge clk); #1; // lw x5, 16(x0)  A[4]
    i_imem_addr =  6; i_imem_data = 32'h01402303; @(posedge clk); #1; // lw x6, 20(x0)  A[5]
    i_imem_addr =  7; i_imem_data = 32'h01802383; @(posedge clk); #1; // lw x7, 24(x0)  A[6]
    i_imem_addr =  8; i_imem_data = 32'h01C02403; @(posedge clk); #1; // lw x8, 28(x0)  A[7]

    // =========================================================================
    // Sección 2: Cargas de B[0..7] en x9..x16
    //   Byte addr 32..60 -> pos8..pos15 del DCache.
    // =========================================================================
    i_imem_addr =  9; i_imem_data = 32'h02002483; @(posedge clk); #1; // lw x9,  32(x0) B[0]
    i_imem_addr = 10; i_imem_data = 32'h02402503; @(posedge clk); #1; // lw x10, 36(x0) B[1]
    i_imem_addr = 11; i_imem_data = 32'h02802583; @(posedge clk); #1; // lw x11, 40(x0) B[2]
    i_imem_addr = 12; i_imem_data = 32'h02C02603; @(posedge clk); #1; // lw x12, 44(x0) B[3]
    i_imem_addr = 13; i_imem_data = 32'h03002683; @(posedge clk); #1; // lw x13, 48(x0) B[4]
    i_imem_addr = 14; i_imem_data = 32'h03402703; @(posedge clk); #1; // lw x14, 52(x0) B[5]
    i_imem_addr = 15; i_imem_data = 32'h03802783; @(posedge clk); #1; // lw x15, 56(x0) B[6]
    i_imem_addr = 16; i_imem_data = 32'h03C02803; @(posedge clk); #1; // lw x16, 60(x0) B[7]

    // =========================================================================
    // Sección 3: Sumas C[0..7]
    //   x20 está reservado para el sentinel -> C[3] va a x21.
    //   Todos los ADD son independientes entre sí.
    //   Separación mínima de los operandos fuente: add x17=x1+x9 usa x1 (16 atrás)
    //   y x9 (8 atrás) -> ambos pasaron WB, en RF.
    // =========================================================================
    i_imem_addr = 17; i_imem_data = 32'h009088B3; @(posedge clk); #1; // add x17, x1,  x9   C[0]=20
    i_imem_addr = 18; i_imem_data = 32'h00A10933; @(posedge clk); #1; // add x18, x2,  x10  C[1]=40
    i_imem_addr = 19; i_imem_data = 32'h00B189B3; @(posedge clk); #1; // add x19, x3,  x11  C[2]=60
    i_imem_addr = 20; i_imem_data = 32'h00C20AB3; @(posedge clk); #1; // add x21, x4,  x12  C[3]=80
    i_imem_addr = 21; i_imem_data = 32'h00D28B33; @(posedge clk); #1; // add x22, x5,  x13  C[4]=100
    i_imem_addr = 22; i_imem_data = 32'h00E30BB3; @(posedge clk); #1; // add x23, x6,  x14  C[5]=120
    i_imem_addr = 23; i_imem_data = 32'h00F38C33; @(posedge clk); #1; // add x24, x7,  x15  C[6]=140
    i_imem_addr = 24; i_imem_data = 32'h01040CB3; @(posedge clk); #1; // add x25, x8,  x16  C[7]=160

    // =========================================================================
    // Sección 4: Almacenamientos C[0..7] -> pos16..pos23 (byte addr 64..92)
    //   El SW más cercano a su ADD fuente es sw x17 (4 instrucciones después).
    //   x17 ya pasó WB cuando el SW entra a Execute -> no hay stall.
    //   Formato SW: imm[11:5] rs2 rs1 010 imm[4:0] 0100011
    //     sw xN, offset(x0): rs1=x0=00000, rs2=xN
    // =========================================================================
    i_imem_addr = 25; i_imem_data = 32'h05102023; @(posedge clk); #1; // sw x17, 64(x0)  dmem[16]
    i_imem_addr = 26; i_imem_data = 32'h05202223; @(posedge clk); #1; // sw x18, 68(x0)  dmem[17]
    i_imem_addr = 27; i_imem_data = 32'h05302423; @(posedge clk); #1; // sw x19, 72(x0)  dmem[18]
    i_imem_addr = 28; i_imem_data = 32'h05502623; @(posedge clk); #1; // sw x21, 76(x0)  dmem[19]
    i_imem_addr = 29; i_imem_data = 32'h05602823; @(posedge clk); #1; // sw x22, 80(x0)  dmem[20]
    i_imem_addr = 30; i_imem_data = 32'h05702A23; @(posedge clk); #1; // sw x23, 84(x0)  dmem[21]
    i_imem_addr = 31; i_imem_data = 32'h05802C23; @(posedge clk); #1; // sw x24, 88(x0)  dmem[22]
    i_imem_addr = 32; i_imem_data = 32'h05902E23; @(posedge clk); #1; // sw x25, 92(x0)  dmem[23]

    // [33] addi x20, x0, 1    — DONE
    i_imem_addr = 33; i_imem_data = 32'h00100A13; @(posedge clk); #1;

    // [34..63] NOP padding hasta completar 64 instrucciones
    begin : fill
        integer k;
        for (k = 34; k < 64; k = k + 1) begin
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
            $display("=== SCALAR+FWD N=8: %0d cycles ===", cycle_count);
            $display("");

            // Verificar sumas en registros enteros
            check(dut.RF.x17,     32'd20,  "           x17 = 20  (A[0]+B[0])");
            check(dut.RF.x18,     32'd40,  "           x18 = 40  (A[1]+B[1])");
            check(dut.RF.x19,     32'd60,  "           x19 = 60  (A[2]+B[2])");
            check(dut.RF.x21,     32'd80,  "           x21 = 80  (A[3]+B[3])");
            check(dut.RF.x22,     32'd100, "           x22 = 100 (A[4]+B[4])");
            check(dut.RF.x23,     32'd120, "           x23 = 120 (A[5]+B[5])");
            check(dut.RF.x24,     32'd140, "           x24 = 140 (A[6]+B[6])");
            check(dut.RF.x25,     32'd160, "           x25 = 160 (A[7]+B[7])");
            // Verificar que los SW escribieron al DCache
            check(dut.dmem.pos16, 32'd20,  "           dmem[16] = 20  (C[0])");
            check(dut.dmem.pos17, 32'd40,  "           dmem[17] = 40  (C[1])");
            check(dut.dmem.pos18, 32'd60,  "           dmem[18] = 60  (C[2])");
            check(dut.dmem.pos19, 32'd80,  "           dmem[19] = 80  (C[3])");
            check(dut.dmem.pos20, 32'd100, "           dmem[20] = 100 (C[4])");
            check(dut.dmem.pos21, 32'd120, "           dmem[21] = 120 (C[5])");
            check(dut.dmem.pos22, 32'd140, "           dmem[22] = 140 (C[6])");
            check(dut.dmem.pos23, 32'd160, "           dmem[23] = 160 (C[7])");

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
