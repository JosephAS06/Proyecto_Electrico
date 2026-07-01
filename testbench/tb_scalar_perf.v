`timescale 1ns/1ps
// Scalar performance testbench: C[i] = A[i] + B[i] for i = 0..3
// Measures clock cycles from reset deassertion until the done sentinel (x20 = 1).
// No hazard unit in the scalar pipeline, so NOPs guard every RAW dependency,
// including 3 NOPs between consecutive lw instructions to avoid DCache address
// overlap through the mem_unit combinational path.
module tb_scalar_perf;

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

// Count cycles from reset deassertion
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
    $dumpfile("tb_scalar_perf.vcd");
    $dumpvars(0, tb_scalar_perf);

    pass_count  = 0;
    fail_count  = 0;
    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // ----------------------------------------------------------------
    // Load scalar program into ICache (addresses are word-indexed)
    // Program: element-wise addition of A[0..3] and B[0..3]
    //   Memory layout  (dmem word index -> byte addr):
    //     pos0..pos3  ( 0..12): A = {10, 20, 30, 40}
    //     pos4..pos7  (16..28): B = {50, 60, 70, 80}
    //   Results written by sw to:
    //     pos8..pos11 (32..44): C = {60, 80, 100, 120}
    //
    // 3 NOPs between each consecutive lw to allow the DCache address
    // to settle through the mem_unit combinational path before the
    // next load drives o_loaded_data.
    // ----------------------------------------------------------------
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel init (x20=0 while running)
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  lw x1, 0(x0)       — x1 = A[0] = 10
    i_imem_addr =  1; i_imem_data = 32'h00002083; @(posedge clk); #1;
    // [2..4]  NOP x3
    i_imem_addr =  2; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [5]  lw x2, 4(x0)       — x2 = A[1] = 20
    i_imem_addr =  5; i_imem_data = 32'h00402103; @(posedge clk); #1;
    // [6..8]  NOP x3
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  7; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [9]  lw x3, 8(x0)       — x3 = A[2] = 30
    i_imem_addr =  9; i_imem_data = 32'h00802183; @(posedge clk); #1;
    // [10..12] NOP x3
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [13] lw x4, 12(x0)      — x4 = A[3] = 40
    i_imem_addr = 13; i_imem_data = 32'h00C02203; @(posedge clk); #1;
    // [14..16] NOP x3
    i_imem_addr = 14; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 15; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [17] lw x5, 16(x0)      — x5 = B[0] = 50
    i_imem_addr = 17; i_imem_data = 32'h01002283; @(posedge clk); #1;
    // [18..20] NOP x3
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 20; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [21] lw x6, 20(x0)      — x6 = B[1] = 60
    i_imem_addr = 21; i_imem_data = 32'h01402303; @(posedge clk); #1;
    // [22..24] NOP x3
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [25] lw x7, 24(x0)      — x7 = B[2] = 70
    i_imem_addr = 25; i_imem_data = 32'h01802383; @(posedge clk); #1;
    // [26..28] NOP x3
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [29] lw x8, 28(x0)      — x8 = B[3] = 80
    i_imem_addr = 29; i_imem_data = 32'h01C02403; @(posedge clk); #1;
    // [30..34] NOP x5 — wait for lw x8 to reach WB before first add
    i_imem_addr = 30; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 33; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 34; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [35] add x9,  x1, x5    — C[0] = 10 + 50 = 60
    i_imem_addr = 35; i_imem_data = 32'h005084B3; @(posedge clk); #1;
    // [36] add x10, x2, x6    — C[1] = 20 + 60 = 80  (independent of x9)
    i_imem_addr = 36; i_imem_data = 32'h00610533; @(posedge clk); #1;
    // [37] add x11, x3, x7    — C[2] = 30 + 70 = 100 (independent of x10)
    i_imem_addr = 37; i_imem_data = 32'h007185B3; @(posedge clk); #1;
    // [38] add x12, x4, x8    — C[3] = 40 + 80 = 120 (independent of x11)
    i_imem_addr = 38; i_imem_data = 32'h00820633; @(posedge clk); #1;
    // [39..43] NOP x5 — wait for all adds to reach WB before stores
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 41; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 42; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 43; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [44] sw x9,  32(x0)     — dmem[8]  = 60
    i_imem_addr = 44; i_imem_data = 32'h02902023; @(posedge clk); #1;
    // [45] sw x10, 36(x0)     — dmem[9]  = 80
    i_imem_addr = 45; i_imem_data = 32'h02A02223; @(posedge clk); #1;
    // [46] sw x11, 40(x0)     — dmem[10] = 100
    i_imem_addr = 46; i_imem_data = 32'h02B02423; @(posedge clk); #1;
    // [47] sw x12, 44(x0)     — dmem[11] = 120
    i_imem_addr = 47; i_imem_data = 32'h02C02623; @(posedge clk); #1;
    // [48..52] NOP x5 — let stores retire through MEM/WB stages
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 50; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 51; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [53] addi x20, x0, 1    — DONE: sentinel x20 = 1
    i_imem_addr = 53; i_imem_data = 32'h00100A13; @(posedge clk); #1;
    // [54..63] NOP padding
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

    // Allow ICache to stabilise in read mode
    @(posedge clk); #1;
    @(posedge clk); #1;

    // Release reset and pre-load DCache operands before first execution edge
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

// Monitor: detect done sentinel each cycle
always @(posedge clk) begin
    if (!rst) begin
        if (dut.RF.x20 === 32'd1) begin
            $display("");
            $display("=== SCALAR PERFORMANCE RESULT: %0d cycles ===", cycle_count);
            $display("");

            check(dut.RF.x9,      32'd60,  "x9  = 60  (A[0]+B[0])");
            check(dut.RF.x10,     32'd80,  "x10 = 80  (A[1]+B[1])");
            check(dut.RF.x11,     32'd100, "x11 = 100 (A[2]+B[2])");
            check(dut.RF.x12,     32'd120, "x12 = 120 (A[3]+B[3])");
            check(dut.dmem.pos8,  32'd60,  "dmem[8]  = 60  (C[0])");
            check(dut.dmem.pos9,  32'd80,  "dmem[9]  = 80  (C[1])");
            check(dut.dmem.pos10, 32'd100, "dmem[10] = 100 (C[2])");
            check(dut.dmem.pos11, 32'd120, "dmem[11] = 120 (C[3])");

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
