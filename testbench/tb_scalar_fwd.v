`timescale 1ns/1ps
// Scalar performance testbench with forwarding: C[i] = A[i] + B[i] for i = 0..3
// Uses the EX/MEM/WB forwarding paths to eliminate NOPs between
// consecutive independent loads, and between load/add/store groups.
// Same data and expected results as tb_scalar_perf.v, shorter program.
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

    // ----------------------------------------------------------------
    // Optimised program exploiting forwarding (0 NOPs):
    //   Memory layout (dmem word index → byte addr):
    //     pos0..pos3  ( 0..12): A = {10, 20, 30, 40}
    //     pos4..pos7  (16..28): B = {50, 60, 70, 80}
    //   Results:
    //     pos8..pos11 (32..44): C = {60, 80, 100, 120}
    //
    // All 8 loads are independent — no NOPs between them.
    // Adds are 4-8 instructions after their load sources — RF has the
    // value; no forwarding or stall needed.
    // Stores are 4-7 instructions after the adds — RF has the value.
    // Total: 18 instructions, 0 padding NOPs in the critical path.
    // ----------------------------------------------------------------
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
    // [9]  add x9, x1, x5     — C[0] = 60  (x1 8-back, x5 4-back: both in RF)
    i_imem_addr =  9; i_imem_data = 32'h005084B3; @(posedge clk); #1;
    // [10] add x10, x2, x6    — C[1] = 80
    i_imem_addr = 10; i_imem_data = 32'h00610533; @(posedge clk); #1;
    // [11] add x11, x3, x7    — C[2] = 100
    i_imem_addr = 11; i_imem_data = 32'h007185B3; @(posedge clk); #1;
    // [12] add x12, x4, x8    — C[3] = 120
    i_imem_addr = 12; i_imem_data = 32'h00820633; @(posedge clk); #1;
    // [13] sw x9,  32(x0)     — C[0] → dmem[8]  (x9 4-back: in RF)
    i_imem_addr = 13; i_imem_data = 32'h02902023; @(posedge clk); #1;
    // [14] sw x10, 36(x0)     — C[1] → dmem[9]
    i_imem_addr = 14; i_imem_data = 32'h02A02223; @(posedge clk); #1;
    // [15] sw x11, 40(x0)     — C[2] → dmem[10]
    i_imem_addr = 15; i_imem_data = 32'h02B02423; @(posedge clk); #1;
    // [16] sw x12, 44(x0)     — C[3] → dmem[11]
    i_imem_addr = 16; i_imem_data = 32'h02C02623; @(posedge clk); #1;
    // [17] addi x20, x0, 1    — DONE sentinel
    i_imem_addr = 17; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [18..63] NOP padding
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

always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== SCALAR+FWD N=4: %0d cycles ===", cycle_count);
            $display("");

            check(dut.RF.x9,      32'd60,  "           x9  = 60  (A[0]+B[0])");
            check(dut.RF.x10,     32'd80,  "           x10 = 80  (A[1]+B[1])");
            check(dut.RF.x11,     32'd100, "           x11 = 100 (A[2]+B[2])");
            check(dut.RF.x12,     32'd120, "           x12 = 120 (A[3]+B[3])");
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
