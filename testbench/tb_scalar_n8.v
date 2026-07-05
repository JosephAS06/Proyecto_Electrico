`timescale 1ns/1ps
// Scalar performance testbench with forwarding: C[i] = A[i] + B[i] for i = 0..7
// 16 independent loads, 8 independent adds, 8 stores — no NOPs in critical path.
// Memory layout:
//   pos0..pos7  ( 0..28): A = {10,20,30,40,50,60,70,80}
//   pos8..pos15 (32..60): B = {10,20,30,40,50,60,70,80}
//   pos16..pos23(64..92): C = {20,40,60,80,100,120,140,160}
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

    // [0]  addi x20, x0, 0     sentinel = 0
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1..8]  lw A[0..7] → x1..x8
    i_imem_addr =  1; i_imem_data = 32'h00002083; @(posedge clk); #1; // lw x1,  0(x0)
    i_imem_addr =  2; i_imem_data = 32'h00402103; @(posedge clk); #1; // lw x2,  4(x0)
    i_imem_addr =  3; i_imem_data = 32'h00802183; @(posedge clk); #1; // lw x3,  8(x0)
    i_imem_addr =  4; i_imem_data = 32'h00C02203; @(posedge clk); #1; // lw x4, 12(x0)
    i_imem_addr =  5; i_imem_data = 32'h01002283; @(posedge clk); #1; // lw x5, 16(x0)
    i_imem_addr =  6; i_imem_data = 32'h01402303; @(posedge clk); #1; // lw x6, 20(x0)
    i_imem_addr =  7; i_imem_data = 32'h01802383; @(posedge clk); #1; // lw x7, 24(x0)
    i_imem_addr =  8; i_imem_data = 32'h01C02403; @(posedge clk); #1; // lw x8, 28(x0)
    // [9..16]  lw B[0..7] → x9..x16
    i_imem_addr =  9; i_imem_data = 32'h02002483; @(posedge clk); #1; // lw x9,  32(x0)
    i_imem_addr = 10; i_imem_data = 32'h02402503; @(posedge clk); #1; // lw x10, 36(x0)
    i_imem_addr = 11; i_imem_data = 32'h02802583; @(posedge clk); #1; // lw x11, 40(x0)
    i_imem_addr = 12; i_imem_data = 32'h02C02603; @(posedge clk); #1; // lw x12, 44(x0)
    i_imem_addr = 13; i_imem_data = 32'h03002683; @(posedge clk); #1; // lw x13, 48(x0)
    i_imem_addr = 14; i_imem_data = 32'h03402703; @(posedge clk); #1; // lw x14, 52(x0)
    i_imem_addr = 15; i_imem_data = 32'h03802783; @(posedge clk); #1; // lw x15, 56(x0)
    i_imem_addr = 16; i_imem_data = 32'h03C02803; @(posedge clk); #1; // lw x16, 60(x0)
    // [17..24]  add C[0..7] → x17..x25 (x20 reserved for sentinel, use x21 for C[3])
    i_imem_addr = 17; i_imem_data = 32'h009088B3; @(posedge clk); #1; // add x17, x1,  x9
    i_imem_addr = 18; i_imem_data = 32'h00A10933; @(posedge clk); #1; // add x18, x2,  x10
    i_imem_addr = 19; i_imem_data = 32'h00B189B3; @(posedge clk); #1; // add x19, x3,  x11
    i_imem_addr = 20; i_imem_data = 32'h00C20AB3; @(posedge clk); #1; // add x21, x4,  x12
    i_imem_addr = 21; i_imem_data = 32'h00D28B33; @(posedge clk); #1; // add x22, x5,  x13
    i_imem_addr = 22; i_imem_data = 32'h00E30BB3; @(posedge clk); #1; // add x23, x6,  x14
    i_imem_addr = 23; i_imem_data = 32'h00F38C33; @(posedge clk); #1; // add x24, x7,  x15
    i_imem_addr = 24; i_imem_data = 32'h01040CB3; @(posedge clk); #1; // add x25, x8,  x16
    // [25..32]  sw C[0..7] → dmem pos16..pos23 (byte 64..92)
    i_imem_addr = 25; i_imem_data = 32'h05102023; @(posedge clk); #1; // sw x17, 64(x0)
    i_imem_addr = 26; i_imem_data = 32'h05202223; @(posedge clk); #1; // sw x18, 68(x0)
    i_imem_addr = 27; i_imem_data = 32'h05302423; @(posedge clk); #1; // sw x19, 72(x0)
    i_imem_addr = 28; i_imem_data = 32'h05502623; @(posedge clk); #1; // sw x21, 76(x0)
    i_imem_addr = 29; i_imem_data = 32'h05602823; @(posedge clk); #1; // sw x22, 80(x0)
    i_imem_addr = 30; i_imem_data = 32'h05702A23; @(posedge clk); #1; // sw x23, 84(x0)
    i_imem_addr = 31; i_imem_data = 32'h05802C23; @(posedge clk); #1; // sw x24, 88(x0)
    i_imem_addr = 32; i_imem_data = 32'h05902E23; @(posedge clk); #1; // sw x25, 92(x0)
    // [33]  addi x20, x0, 1    sentinel DONE
    i_imem_addr = 33; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [34..63] NOP padding
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
            $display("=== SCALAR+FWD N=8: %0d cycles ===", cycle_count);
            $display("");

            check(dut.RF.x17,     32'd20,  "           x17 = 20  (A[0]+B[0])");
            check(dut.RF.x18,     32'd40,  "           x18 = 40  (A[1]+B[1])");
            check(dut.RF.x19,     32'd60,  "           x19 = 60  (A[2]+B[2])");
            check(dut.RF.x21,     32'd80,  "           x21 = 80  (A[3]+B[3])");
            check(dut.RF.x22,     32'd100, "           x22 = 100 (A[4]+B[4])");
            check(dut.RF.x23,     32'd120, "           x23 = 120 (A[5]+B[5])");
            check(dut.RF.x24,     32'd140, "           x24 = 140 (A[6]+B[6])");
            check(dut.RF.x25,     32'd160, "           x25 = 160 (A[7]+B[7])");
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
