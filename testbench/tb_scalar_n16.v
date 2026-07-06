// =============================================================================
// Módulo: tb_scalar_n16
// Archivo: testbench/tb_scalar_n16.v
//
// Descripción:
//   Banco de pruebas de rendimiento para el pipeline RISC-V RV32I escalar
//   CON forwarding, ejecutando la suma elemento a elemento de dos arreglos
//   de N=16 elementos: C[i] = A[i] + B[i] para i = 0..15.
//
// Layout de DCache:
//   pos0..pos15  (byte 0..60):    A = {10,20,...,160}
//   pos16..pos31 (byte 64..124):  B = {10,20,...,160}
//   pos32..pos47 (byte 128..188): C = {20,40,...,320}
//
// Programa (66 instrucciones útiles + padding hasta 128):
//
//   [0]   addi x20, x0, 0    — sentinel init
//   --- Lote 1: A[0..7] + B[0..7] ---
//   [1]   lw x1,  0(x0)      — A[0]=10
//   [2]   lw x2,  4(x0)      — A[1]=20
//   [3]   lw x3,  8(x0)      — A[2]=30
//   [4]   lw x4,  12(x0)     — A[3]=40
//   [5]   lw x5,  16(x0)     — A[4]=50
//   [6]   lw x6,  20(x0)     — A[5]=60
//   [7]   lw x7,  24(x0)     — A[6]=70
//   [8]   lw x8,  28(x0)     — A[7]=80
//   [9]   lw x9,  64(x0)     — B[0]=10
//   [10]  lw x10, 68(x0)     — B[1]=20
//   [11]  lw x11, 72(x0)     — B[2]=30
//   [12]  lw x12, 76(x0)     — B[3]=40
//   [13]  lw x13, 80(x0)     — B[4]=50
//   [14]  lw x14, 84(x0)     — B[5]=60
//   [15]  lw x15, 88(x0)     — B[6]=70
//   [16]  lw x16, 92(x0)     — B[7]=80
//   [17]  add x17, x1,  x9   — C[0]=20
//   [18]  add x18, x2,  x10  — C[1]=40
//   [19]  add x19, x3,  x11  — C[2]=60
//   [20]  add x21, x4,  x12  — C[3]=80   (x20 reservado)
//   [21]  add x22, x5,  x13  — C[4]=100
//   [22]  add x23, x6,  x14  — C[5]=120
//   [23]  add x24, x7,  x15  — C[6]=140
//   [24]  add x25, x8,  x16  — C[7]=160
//   [25]  sw x17, 128(x0)    — dmem[32]=20
//   [26]  sw x18, 132(x0)    — dmem[33]=40
//   [27]  sw x19, 136(x0)    — dmem[34]=60
//   [28]  sw x21, 140(x0)    — dmem[35]=80
//   [29]  sw x22, 144(x0)    — dmem[36]=100
//   [30]  sw x23, 148(x0)    — dmem[37]=120
//   [31]  sw x24, 152(x0)    — dmem[38]=140
//   [32]  sw x25, 156(x0)    — dmem[39]=160
//   --- Lote 2: A[8..15] + B[8..15] ---
//   [33]  lw x1,  32(x0)     — A[8]=90
//   [34]  lw x2,  36(x0)     — A[9]=100
//   [35]  lw x3,  40(x0)     — A[10]=110
//   [36]  lw x4,  44(x0)     — A[11]=120
//   [37]  lw x5,  48(x0)     — A[12]=130
//   [38]  lw x6,  52(x0)     — A[13]=140
//   [39]  lw x7,  56(x0)     — A[14]=150
//   [40]  lw x8,  60(x0)     — A[15]=160
//   [41]  lw x9,  96(x0)     — B[8]=90
//   [42]  lw x10, 100(x0)    — B[9]=100
//   [43]  lw x11, 104(x0)    — B[10]=110
//   [44]  lw x12, 108(x0)    — B[11]=120
//   [45]  lw x13, 112(x0)    — B[12]=130
//   [46]  lw x14, 116(x0)    — B[13]=140
//   [47]  lw x15, 120(x0)    — B[14]=150
//   [48]  lw x16, 124(x0)    — B[15]=160
//   [49]  add x17, x1,  x9   — C[8]=180
//   [50]  add x18, x2,  x10  — C[9]=200
//   [51]  add x19, x3,  x11  — C[10]=220
//   [52]  add x21, x4,  x12  — C[11]=240
//   [53]  add x22, x5,  x13  — C[12]=260
//   [54]  add x23, x6,  x14  — C[13]=280
//   [55]  add x24, x7,  x15  — C[14]=300
//   [56]  add x25, x8,  x16  — C[15]=320
//   [57]  sw x17, 160(x0)    — dmem[40]=180
//   [58]  sw x18, 164(x0)    — dmem[41]=200
//   [59]  sw x19, 168(x0)    — dmem[42]=220
//   [60]  sw x21, 172(x0)    — dmem[43]=240
//   [61]  sw x22, 176(x0)    — dmem[44]=260
//   [62]  sw x23, 180(x0)    — dmem[45]=280
//   [63]  sw x24, 184(x0)    — dmem[46]=300
//   [64]  sw x25, 188(x0)    — dmem[47]=320
//   [65]  addi x20, x0, 1   — DONE sentinel
//   [66..127] NOP×62          — padding
//
// No hay NOPs entre cargas (son independientes) ni entre carga y suma
// (separación mínima de 8 instrucciones → valores en RF).
// El lote 2 reutiliza los mismos registros x1..x25 sin conflicto.
//
// Mecanismo de terminación: sentinel x20=1, timeout = 500 ciclos.
// =============================================================================

`timescale 1ns/1ps
module tb_scalar_n16;

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
    $dumpfile("tb_scalar_n16.vcd");
    $dumpvars(0, tb_scalar_n16);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Cargar programa en ICache (word-indexed)
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel=0
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;

    // --- Lote 1: A[0..7] → x1..x8 (byte addr 0..28) ---
    i_imem_addr =  1; i_imem_data = 32'h00002083; @(posedge clk); #1; // lw x1,  0(x0)  A[0]
    i_imem_addr =  2; i_imem_data = 32'h00402103; @(posedge clk); #1; // lw x2,  4(x0)  A[1]
    i_imem_addr =  3; i_imem_data = 32'h00802183; @(posedge clk); #1; // lw x3,  8(x0)  A[2]
    i_imem_addr =  4; i_imem_data = 32'h00C02203; @(posedge clk); #1; // lw x4,  12(x0) A[3]
    i_imem_addr =  5; i_imem_data = 32'h01002283; @(posedge clk); #1; // lw x5,  16(x0) A[4]
    i_imem_addr =  6; i_imem_data = 32'h01402303; @(posedge clk); #1; // lw x6,  20(x0) A[5]
    i_imem_addr =  7; i_imem_data = 32'h01802383; @(posedge clk); #1; // lw x7,  24(x0) A[6]
    i_imem_addr =  8; i_imem_data = 32'h01C02403; @(posedge clk); #1; // lw x8,  28(x0) A[7]

    // --- Lote 1: B[0..7] → x9..x16 (byte addr 64..92) ---
    i_imem_addr =  9; i_imem_data = 32'h04002483; @(posedge clk); #1; // lw x9,  64(x0) B[0]
    i_imem_addr = 10; i_imem_data = 32'h04402503; @(posedge clk); #1; // lw x10, 68(x0) B[1]
    i_imem_addr = 11; i_imem_data = 32'h04802583; @(posedge clk); #1; // lw x11, 72(x0) B[2]
    i_imem_addr = 12; i_imem_data = 32'h04C02603; @(posedge clk); #1; // lw x12, 76(x0) B[3]
    i_imem_addr = 13; i_imem_data = 32'h05002683; @(posedge clk); #1; // lw x13, 80(x0) B[4]
    i_imem_addr = 14; i_imem_data = 32'h05402703; @(posedge clk); #1; // lw x14, 84(x0) B[5]
    i_imem_addr = 15; i_imem_data = 32'h05802783; @(posedge clk); #1; // lw x15, 88(x0) B[6]
    i_imem_addr = 16; i_imem_data = 32'h05C02803; @(posedge clk); #1; // lw x16, 92(x0) B[7]

    // --- Lote 1: Sumas C[0..7] → x17,x18,x19,x21..x25 ---
    // x1 (lote [1], 16 instr. antes) y x9 (lote [9], 8 instr. antes) ya están en RF
    i_imem_addr = 17; i_imem_data = 32'h009088B3; @(posedge clk); #1; // add x17, x1,  x9   C[0]=20
    i_imem_addr = 18; i_imem_data = 32'h00A10933; @(posedge clk); #1; // add x18, x2,  x10  C[1]=40
    i_imem_addr = 19; i_imem_data = 32'h00B189B3; @(posedge clk); #1; // add x19, x3,  x11  C[2]=60
    i_imem_addr = 20; i_imem_data = 32'h00C20AB3; @(posedge clk); #1; // add x21, x4,  x12  C[3]=80
    i_imem_addr = 21; i_imem_data = 32'h00D28B33; @(posedge clk); #1; // add x22, x5,  x13  C[4]=100
    i_imem_addr = 22; i_imem_data = 32'h00E30BB3; @(posedge clk); #1; // add x23, x6,  x14  C[5]=120
    i_imem_addr = 23; i_imem_data = 32'h00F38C33; @(posedge clk); #1; // add x24, x7,  x15  C[6]=140
    i_imem_addr = 24; i_imem_data = 32'h01040CB3; @(posedge clk); #1; // add x25, x8,  x16  C[7]=160

    // --- Lote 1: Almacenar C[0..7] → pos32..pos39 (byte addr 128..156) ---
    // imm=128: imm[11:5]=0000100, imm[4:0]=00000
    i_imem_addr = 25; i_imem_data = 32'h09102023; @(posedge clk); #1; // sw x17, 128(x0) dmem[32]
    i_imem_addr = 26; i_imem_data = 32'h09202223; @(posedge clk); #1; // sw x18, 132(x0) dmem[33]
    i_imem_addr = 27; i_imem_data = 32'h09302423; @(posedge clk); #1; // sw x19, 136(x0) dmem[34]
    i_imem_addr = 28; i_imem_data = 32'h09502623; @(posedge clk); #1; // sw x21, 140(x0) dmem[35]
    i_imem_addr = 29; i_imem_data = 32'h09602823; @(posedge clk); #1; // sw x22, 144(x0) dmem[36]
    i_imem_addr = 30; i_imem_data = 32'h09702A23; @(posedge clk); #1; // sw x23, 148(x0) dmem[37]
    i_imem_addr = 31; i_imem_data = 32'h09802C23; @(posedge clk); #1; // sw x24, 152(x0) dmem[38]
    i_imem_addr = 32; i_imem_data = 32'h09902E23; @(posedge clk); #1; // sw x25, 156(x0) dmem[39]

    // --- Lote 2: A[8..15] → x1..x8 (byte addr 32..60) ---
    i_imem_addr = 33; i_imem_data = 32'h02002083; @(posedge clk); #1; // lw x1,  32(x0)  A[8]
    i_imem_addr = 34; i_imem_data = 32'h02402103; @(posedge clk); #1; // lw x2,  36(x0)  A[9]
    i_imem_addr = 35; i_imem_data = 32'h02802183; @(posedge clk); #1; // lw x3,  40(x0)  A[10]
    i_imem_addr = 36; i_imem_data = 32'h02C02203; @(posedge clk); #1; // lw x4,  44(x0)  A[11]
    i_imem_addr = 37; i_imem_data = 32'h03002283; @(posedge clk); #1; // lw x5,  48(x0)  A[12]
    i_imem_addr = 38; i_imem_data = 32'h03402303; @(posedge clk); #1; // lw x6,  52(x0)  A[13]
    i_imem_addr = 39; i_imem_data = 32'h03802383; @(posedge clk); #1; // lw x7,  56(x0)  A[14]
    i_imem_addr = 40; i_imem_data = 32'h03C02403; @(posedge clk); #1; // lw x8,  60(x0)  A[15]

    // --- Lote 2: B[8..15] → x9..x16 (byte addr 96..124) ---
    i_imem_addr = 41; i_imem_data = 32'h06002483; @(posedge clk); #1; // lw x9,  96(x0)  B[8]
    i_imem_addr = 42; i_imem_data = 32'h06402503; @(posedge clk); #1; // lw x10, 100(x0) B[9]
    i_imem_addr = 43; i_imem_data = 32'h06802583; @(posedge clk); #1; // lw x11, 104(x0) B[10]
    i_imem_addr = 44; i_imem_data = 32'h06C02603; @(posedge clk); #1; // lw x12, 108(x0) B[11]
    i_imem_addr = 45; i_imem_data = 32'h07002683; @(posedge clk); #1; // lw x13, 112(x0) B[12]
    i_imem_addr = 46; i_imem_data = 32'h07402703; @(posedge clk); #1; // lw x14, 116(x0) B[13]
    i_imem_addr = 47; i_imem_data = 32'h07802783; @(posedge clk); #1; // lw x15, 120(x0) B[14]
    i_imem_addr = 48; i_imem_data = 32'h07C02803; @(posedge clk); #1; // lw x16, 124(x0) B[15]

    // --- Lote 2: Sumas C[8..15] ---
    // x1 (lote [33], 16 instr. antes) y x9 ([41], 8 instr. antes) ya en RF
    i_imem_addr = 49; i_imem_data = 32'h009088B3; @(posedge clk); #1; // add x17, x1,  x9   C[8]=180
    i_imem_addr = 50; i_imem_data = 32'h00A10933; @(posedge clk); #1; // add x18, x2,  x10  C[9]=200
    i_imem_addr = 51; i_imem_data = 32'h00B189B3; @(posedge clk); #1; // add x19, x3,  x11  C[10]=220
    i_imem_addr = 52; i_imem_data = 32'h00C20AB3; @(posedge clk); #1; // add x21, x4,  x12  C[11]=240
    i_imem_addr = 53; i_imem_data = 32'h00D28B33; @(posedge clk); #1; // add x22, x5,  x13  C[12]=260
    i_imem_addr = 54; i_imem_data = 32'h00E30BB3; @(posedge clk); #1; // add x23, x6,  x14  C[13]=280
    i_imem_addr = 55; i_imem_data = 32'h00F38C33; @(posedge clk); #1; // add x24, x7,  x15  C[14]=300
    i_imem_addr = 56; i_imem_data = 32'h01040CB3; @(posedge clk); #1; // add x25, x8,  x16  C[15]=320

    // --- Lote 2: Almacenar C[8..15] → pos40..pos47 (byte addr 160..188) ---
    // imm=160: imm[11:5]=0000101, imm[4:0]=00000
    i_imem_addr = 57; i_imem_data = 32'h0B102023; @(posedge clk); #1; // sw x17, 160(x0) dmem[40]
    i_imem_addr = 58; i_imem_data = 32'h0B202223; @(posedge clk); #1; // sw x18, 164(x0) dmem[41]
    i_imem_addr = 59; i_imem_data = 32'h0B302423; @(posedge clk); #1; // sw x19, 168(x0) dmem[42]
    i_imem_addr = 60; i_imem_data = 32'h0B502623; @(posedge clk); #1; // sw x21, 172(x0) dmem[43]
    i_imem_addr = 61; i_imem_data = 32'h0B602823; @(posedge clk); #1; // sw x22, 176(x0) dmem[44]
    i_imem_addr = 62; i_imem_data = 32'h0B702A23; @(posedge clk); #1; // sw x23, 180(x0) dmem[45]
    i_imem_addr = 63; i_imem_data = 32'h0B802C23; @(posedge clk); #1; // sw x24, 184(x0) dmem[46]
    i_imem_addr = 64; i_imem_data = 32'h0B902E23; @(posedge clk); #1; // sw x25, 188(x0) dmem[47]

    // [65] addi x20, x0, 1    — DONE sentinel
    i_imem_addr = 65; i_imem_data = 32'h00100A13; @(posedge clk); #1;

    // [66..127] NOP padding
    begin : fill
        integer k;
        for (k = 66; k < 128; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    // Desactivar reset y cargar datos en DCache
    rst = 0;
    // A[0..15] → pos0..pos15 (byte addr 0..60)
    dut.dmem.pos0  = 32'd10;   // A[0]
    dut.dmem.pos1  = 32'd20;   // A[1]
    dut.dmem.pos2  = 32'd30;   // A[2]
    dut.dmem.pos3  = 32'd40;   // A[3]
    dut.dmem.pos4  = 32'd50;   // A[4]
    dut.dmem.pos5  = 32'd60;   // A[5]
    dut.dmem.pos6  = 32'd70;   // A[6]
    dut.dmem.pos7  = 32'd80;   // A[7]
    dut.dmem.pos8  = 32'd90;   // A[8]
    dut.dmem.pos9  = 32'd100;  // A[9]
    dut.dmem.pos10 = 32'd110;  // A[10]
    dut.dmem.pos11 = 32'd120;  // A[11]
    dut.dmem.pos12 = 32'd130;  // A[12]
    dut.dmem.pos13 = 32'd140;  // A[13]
    dut.dmem.pos14 = 32'd150;  // A[14]
    dut.dmem.pos15 = 32'd160;  // A[15]
    // B[0..15] → pos16..pos31 (byte addr 64..124)
    dut.dmem.pos16 = 32'd10;   // B[0]
    dut.dmem.pos17 = 32'd20;   // B[1]
    dut.dmem.pos18 = 32'd30;   // B[2]
    dut.dmem.pos19 = 32'd40;   // B[3]
    dut.dmem.pos20 = 32'd50;   // B[4]
    dut.dmem.pos21 = 32'd60;   // B[5]
    dut.dmem.pos22 = 32'd70;   // B[6]
    dut.dmem.pos23 = 32'd80;   // B[7]
    dut.dmem.pos24 = 32'd90;   // B[8]
    dut.dmem.pos25 = 32'd100;  // B[9]
    dut.dmem.pos26 = 32'd110;  // B[10]
    dut.dmem.pos27 = 32'd120;  // B[11]
    dut.dmem.pos28 = 32'd130;  // B[12]
    dut.dmem.pos29 = 32'd140;  // B[13]
    dut.dmem.pos30 = 32'd150;  // B[14]
    dut.dmem.pos31 = 32'd160;  // B[15]
end

// Monitor: detectar sentinel o timeout
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== SCALAR+FWD N=16: %0d cycles ===", cycle_count);
            $display("");

            // Verificar C[0..7] en DCache (lote 1)
            check(dut.dmem.pos32, 32'd20,  "dmem[32] =  20  (C[0])");
            check(dut.dmem.pos33, 32'd40,  "dmem[33] =  40  (C[1])");
            check(dut.dmem.pos34, 32'd60,  "dmem[34] =  60  (C[2])");
            check(dut.dmem.pos35, 32'd80,  "dmem[35] =  80  (C[3])");
            check(dut.dmem.pos36, 32'd100, "dmem[36] = 100  (C[4])");
            check(dut.dmem.pos37, 32'd120, "dmem[37] = 120  (C[5])");
            check(dut.dmem.pos38, 32'd140, "dmem[38] = 140  (C[6])");
            check(dut.dmem.pos39, 32'd160, "dmem[39] = 160  (C[7])");
            // Verificar C[8..15] en DCache (lote 2)
            check(dut.dmem.pos40, 32'd180, "dmem[40] = 180  (C[8])");
            check(dut.dmem.pos41, 32'd200, "dmem[41] = 200  (C[9])");
            check(dut.dmem.pos42, 32'd220, "dmem[42] = 220  (C[10])");
            check(dut.dmem.pos43, 32'd240, "dmem[43] = 240  (C[11])");
            check(dut.dmem.pos44, 32'd260, "dmem[44] = 260  (C[12])");
            check(dut.dmem.pos45, 32'd280, "dmem[45] = 280  (C[13])");
            check(dut.dmem.pos46, 32'd300, "dmem[46] = 300  (C[14])");
            check(dut.dmem.pos47, 32'd320, "dmem[47] = 320  (C[15])");

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
