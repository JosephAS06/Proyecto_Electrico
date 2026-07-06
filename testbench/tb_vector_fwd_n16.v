// =============================================================================
// Módulo: tb_vector_fwd_n16
// Archivo: testbench/tb_vector_fwd_n16.v
//
// Descripción:
//   Banco de pruebas vectorial N=16 con forwarding activo.
//   Elimina los 3 NOPs que tb_vector_n16.v requería entre cada "addi x1"
//   y cada "vle32/vse32", gracias a la ruta fwd_vec_base_addr (EX->EX fwd).
//
//   Compara con tb_vector_n16.v (3 NOPs por LSU, 110 ciclos medidos).
//   Con forwarding se eliminan 3 NOPs × 12 instrucciones LSU = 36 NOPs.
//
// Programa optimizado (30 instrucciones útiles, 0 NOPs entre addi y LSU):
//   [0]  addi x20, x0, 0
//   [1]  addi x1, x0, 0      base A[0..3]
//   [2]  vle32 v1, 0(x1)     A[0..3]   (fwd: x1=0)
//   [3]  addi x1, x0, 16     base A[4..7]
//   [4]  vle32 v2, 0(x1)     A[4..7]   (fwd: x1=16)
//   [5]  addi x1, x0, 32     base A[8..11]
//   [6]  vle32 v3, 0(x1)     A[8..11]  (fwd: x1=32)
//   [7]  addi x1, x0, 48     base A[12..15]
//   [8]  vle32 v4, 0(x1)     A[12..15] (fwd: x1=48)
//   [9]  addi x1, x0, 64     base B[0..3]
//   [10] vle32 v5, 0(x1)     B[0..3]   (fwd: x1=64)
//   [11] addi x1, x0, 80     base B[4..7]
//   [12] vle32 v6, 0(x1)     B[4..7]   (fwd: x1=80)
//   [13] addi x1, x0, 96     base B[8..11]
//   [14] vle32 v7, 0(x1)     B[8..11]  (fwd: x1=96)
//   [15] addi x1, x0, 112    base B[12..15]
//   [16] vle32 v8, 0(x1)     B[12..15] (fwd: x1=112)
//   [17] vadd v9,  v1, v5    C[0..3]  = A[0..3] +B[0..3]
//   [18] vadd v10, v2, v6    C[4..7]  = A[4..7] +B[4..7]
//   [19] vadd v11, v3, v7    C[8..11] = A[8..11]+B[8..11]
//   [20] vadd v12, v4, v8    C[12..15]= A[12..15]+B[12..15]
//   [21] addi x1, x0, 128    base C[0..3]
//   [22] vse32 v9,  0(x1)    C[0..3]  (fwd: x1=128)
//   [23] addi x1, x0, 144    base C[4..7]
//   [24] vse32 v10, 0(x1)    C[4..7]  (fwd: x1=144)
//   [25] addi x1, x0, 160    base C[8..11]
//   [26] vse32 v11, 0(x1)    C[8..11] (fwd: x1=160)
//   [27] addi x1, x0, 176    base C[12..15]
//   [28] vse32 v12, 0(x1)    C[12..15](fwd: x1=176)
//   [29] addi x20, x0, 1    DONE
//   [30..127] NOP padding
//
// Layout DCache:
//   pos0..15   (byte  0..60): A[0..15] = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160}
//   pos16..31  (byte 64..124): B[0..15] = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160}
//   pos32..47  (byte 128..188): C[0..15] escrito por vse32
//
// Resultado esperado en VRF:
//   v9  = {80,  60,  40,  20}    (C[3..0])
//   v10 = {160, 140, 120, 100}   (C[7..4])
//   v11 = {240, 220, 200, 180}   (C[11..8])
//   v12 = {320, 300, 280, 260}   (C[15..12])
// =============================================================================

`timescale 1ns/1ps
module tb_vector_fwd_n16;

reg        clk;
reg        rst;
reg        i_imem_wen;
reg [31:0] i_imem_addr;
reg [31:0] i_imem_data;

integer    cycle_count;
integer    pass_count;
integer    fail_count;

localparam MAX_CYCLES = 1000;

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
    $dumpfile("tb_vector_fwd_n16.vcd");
    $dumpvars(0, tb_vector_fwd_n16);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // =========================================================================
    // Programa vectorial N=16 con forwarding — 0 NOPs entre addi y vle32/vse32
    // =========================================================================
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;

    // Cargas de A[0..15]: vle32 v1..v4
    // [1]  addi x1, x0, 0     — byte 0 = A[0..3]
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2]  vle32 v1, 0(x1)    {0000001,00000,00001,110,00001,0000111}=0x0200E087
    i_imem_addr =  2; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [3]  addi x1, x0, 16    — byte 16 = A[4..7]
    i_imem_addr =  3; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [4]  vle32 v2, 0(x1)    {0000001,00000,00001,110,00010,0000111}=0x0200E107
    i_imem_addr =  4; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [5]  addi x1, x0, 32    — byte 32 = A[8..11]
    i_imem_addr =  5; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [6]  vle32 v3, 0(x1)    {0000001,00000,00001,110,00011,0000111}=0x0200E187
    i_imem_addr =  6; i_imem_data = 32'h0200E187; @(posedge clk); #1;
    // [7]  addi x1, x0, 48    — byte 48 = A[12..15]
    i_imem_addr =  7; i_imem_data = 32'h03000093; @(posedge clk); #1;
    // [8]  vle32 v4, 0(x1)    {0000001,00000,00001,110,00100,0000111}=0x0200E207
    i_imem_addr =  8; i_imem_data = 32'h0200E207; @(posedge clk); #1;

    // Cargas de B[0..15]: vle32 v5..v8
    // [9]  addi x1, x0, 64    — byte 64 = B[0..3]
    i_imem_addr =  9; i_imem_data = 32'h04000093; @(posedge clk); #1;
    // [10] vle32 v5, 0(x1)    {0000001,00000,00001,110,00101,0000111}=0x0200E287
    i_imem_addr = 10; i_imem_data = 32'h0200E287; @(posedge clk); #1;
    // [11] addi x1, x0, 80    — byte 80 = B[4..7]
    i_imem_addr = 11; i_imem_data = 32'h05000093; @(posedge clk); #1;
    // [12] vle32 v6, 0(x1)    {0000001,00000,00001,110,00110,0000111}=0x0200E307
    i_imem_addr = 12; i_imem_data = 32'h0200E307; @(posedge clk); #1;
    // [13] addi x1, x0, 96    — byte 96 = B[8..11]
    i_imem_addr = 13; i_imem_data = 32'h06000093; @(posedge clk); #1;
    // [14] vle32 v7, 0(x1)    {0000001,00000,00001,110,00111,0000111}=0x0200E387
    i_imem_addr = 14; i_imem_data = 32'h0200E387; @(posedge clk); #1;
    // [15] addi x1, x0, 112   — byte 112 = B[12..15]
    i_imem_addr = 15; i_imem_data = 32'h07000093; @(posedge clk); #1;
    // [16] vle32 v8, 0(x1)    {0000001,00000,00001,110,01000,0000111}=0x0200E407
    i_imem_addr = 16; i_imem_data = 32'h0200E407; @(posedge clk); #1;

    // Sumas vectoriales: vadd v9..v12
    // [17] vadd v9,  v1, v5   {0000000,v5=00101,v1=00001,000,v9=01001,1010111}=0x005084D7
    i_imem_addr = 17; i_imem_data = 32'h005084D7; @(posedge clk); #1;
    // [18] vadd v10, v2, v6   {0000000,v6=00110,v2=00010,000,v10=01010,1010111}=0x00610557
    i_imem_addr = 18; i_imem_data = 32'h00610557; @(posedge clk); #1;
    // [19] vadd v11, v3, v7   {0000000,v7=00111,v3=00011,000,v11=01011,1010111}=0x007185D7
    i_imem_addr = 19; i_imem_data = 32'h007185D7; @(posedge clk); #1;
    // [20] vadd v12, v4, v8   {0000000,v8=01000,v4=00100,000,v12=01100,1010111}=0x00820657
    i_imem_addr = 20; i_imem_data = 32'h00820657; @(posedge clk); #1;

    // Stores de C[0..15]: vse32 v9..v12
    // [21] addi x1, x0, 128   — byte 128 = C[0..3]
    i_imem_addr = 21; i_imem_data = 32'h08000093; @(posedge clk); #1;
    // [22] vse32 v9,  0(x1)   {0000001,00000,00001,110,01001,0100111}=0x0200E4A7
    i_imem_addr = 22; i_imem_data = 32'h0200E4A7; @(posedge clk); #1;
    // [23] addi x1, x0, 144   — byte 144 = C[4..7]
    i_imem_addr = 23; i_imem_data = 32'h09000093; @(posedge clk); #1;
    // [24] vse32 v10, 0(x1)   {0000001,00000,00001,110,01010,0100111}=0x0200E527
    i_imem_addr = 24; i_imem_data = 32'h0200E527; @(posedge clk); #1;
    // [25] addi x1, x0, 160   — byte 160 = C[8..11]
    i_imem_addr = 25; i_imem_data = 32'h0A000093; @(posedge clk); #1;
    // [26] vse32 v11, 0(x1)   {0000001,00000,00001,110,01011,0100111}=0x0200E5A7
    i_imem_addr = 26; i_imem_data = 32'h0200E5A7; @(posedge clk); #1;
    // [27] addi x1, x0, 176   — byte 176 = C[12..15]
    i_imem_addr = 27; i_imem_data = 32'h0B000093; @(posedge clk); #1;
    // [28] vse32 v12, 0(x1)   {0000001,00000,00001,110,01100,0100111}=0x0200E627
    i_imem_addr = 28; i_imem_data = 32'h0200E627; @(posedge clk); #1;
    // [29] addi x20, x0, 1   — DONE
    i_imem_addr = 29; i_imem_data = 32'h00100A13; @(posedge clk); #1;

    // [30..127] NOP padding
    begin : fill
        integer k;
        for (k = 30; k < 128; k = k + 1) begin
            i_imem_addr = k; i_imem_data = 32'h00000013;
            @(posedge clk); #1;
        end
    end

    i_imem_wen = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;

    rst = 0;
    // A[0..15] → pos0..15 (byte 0..60)
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
    // B[0..15] → pos16..31 (byte 64..124)
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

always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== VECTOR FWD N=16: %0d cycles ===", cycle_count);
            $display("");

            // VRF: bits[31:0]=elem0, bits[63:32]=elem1, ..., bits[127:96]=elem3
            check128(dut.vext.vregfile.regs[9],
                     {32'd80,  32'd60,  32'd40,  32'd20},
                     "v9  = {80,60,40,20}   (C[3..0])");
            check128(dut.vext.vregfile.regs[10],
                     {32'd160, 32'd140, 32'd120, 32'd100},
                     "v10 = {160,140,120,100} (C[7..4])");
            check128(dut.vext.vregfile.regs[11],
                     {32'd240, 32'd220, 32'd200, 32'd180},
                     "v11 = {240,220,200,180} (C[11..8])");
            check128(dut.vext.vregfile.regs[12],
                     {32'd320, 32'd300, 32'd280, 32'd260},
                     "v12 = {320,300,280,260} (C[15..12])");
            // DCache pos32..47 = C[0..15]
            check32(dut.dmem.pos32, 32'd20,  "dmem[32] = 20  (C[0])");
            check32(dut.dmem.pos33, 32'd40,  "dmem[33] = 40  (C[1])");
            check32(dut.dmem.pos34, 32'd60,  "dmem[34] = 60  (C[2])");
            check32(dut.dmem.pos35, 32'd80,  "dmem[35] = 80  (C[3])");
            check32(dut.dmem.pos36, 32'd100, "dmem[36] = 100 (C[4])");
            check32(dut.dmem.pos37, 32'd120, "dmem[37] = 120 (C[5])");
            check32(dut.dmem.pos38, 32'd140, "dmem[38] = 140 (C[6])");
            check32(dut.dmem.pos39, 32'd160, "dmem[39] = 160 (C[7])");
            check32(dut.dmem.pos40, 32'd180, "dmem[40] = 180 (C[8])");
            check32(dut.dmem.pos41, 32'd200, "dmem[41] = 200 (C[9])");
            check32(dut.dmem.pos42, 32'd220, "dmem[42] = 220 (C[10])");
            check32(dut.dmem.pos43, 32'd240, "dmem[43] = 240 (C[11])");
            check32(dut.dmem.pos44, 32'd260, "dmem[44] = 260 (C[12])");
            check32(dut.dmem.pos45, 32'd280, "dmem[45] = 280 (C[13])");
            check32(dut.dmem.pos46, 32'd300, "dmem[46] = 300 (C[14])");
            check32(dut.dmem.pos47, 32'd320, "dmem[47] = 320 (C[15])");

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
