`timescale 1ns/1ps
// Vector performance testbench: C[i] = A[i] + B[i] for i = 0..3
// Uses vle32/vadd/vse32; the vec_stall signal freezes the scalar pipeline
// automatically during each vector operation.
// Cycle count starts at reset deassertion; terminates when x20 sentinel = 1.
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

    // ----------------------------------------------------------------
    // Load vector program into ICache (word-indexed addresses 0..63)
    //
    // Memory layout (DCache word index → byte address):
    //   pos0..pos3  ( 0..12): A = {10, 20, 30, 40}
    //   pos4..pos7  (16..28): B = {50, 60, 70, 80}
    //   pos8..pos11 (32..44): C = {60, 80, 100, 120} (written by vse32)
    //
    // Program:
    //   [0]         addi x20, x0, 0       — sentinel init
    //   [1]         addi x1,  x0, 0       — base addr A = 0
    //   [2..6]      NOP×5                 — wait x1=0 to reach RF
    //   [7]         vle32 v1, (x1)        — load A[0..3] into v1 (stall)
    //   [8..14]     NOP×7                 — post-stall buffer
    //   [15]        addi x1,  x0, 16      — base addr B = 16
    //   [16..20]    NOP×5                 — wait x1=16 to reach RF
    //   [21]        vle32 v2, (x1)        — load B[0..3] into v2 (stall)
    //   [22..28]    NOP×7                 — post-stall buffer
    //   [29]        vadd v3, v1, v2       — v3 = A + B element-wise (stall)
    //   [30..36]    NOP×7                 — post-stall buffer
    //   [37]        addi x1,  x0, 32      — base addr C = 32
    //   [38..42]    NOP×5                 — wait x1=32 to reach RF
    //   [43]        vse32 v3, (x1)        — store C[0..3] to dmem[8..11] (stall)
    //   [44..50]    NOP×7                 — post-stall buffer
    //   [51]        addi x20, x0, 1       — DONE: sentinel x20 = 1
    //   [52..63]    NOP×12                — padding
    // ----------------------------------------------------------------
    i_imem_wen = 1;

    // [0]  addi x20, x0, 0    — sentinel init
    i_imem_addr =  0; i_imem_data = 32'h00000A13; @(posedge clk); #1;
    // [1]  addi x1, x0, 0     — base addr A = 0
    i_imem_addr =  1; i_imem_data = 32'h00000093; @(posedge clk); #1;
    // [2..6]  NOP×5
    i_imem_addr =  2; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  5; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [7]  vle32 v1, (x1)     — load A[0..3] into v1
    i_imem_addr =  7; i_imem_data = 32'h0200E087; @(posedge clk); #1;
    // [8..14]  NOP×7
    i_imem_addr =  8; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  9; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 13; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 14; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [15]  addi x1, x0, 16   — base addr B = 16
    i_imem_addr = 15; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [16..20]  NOP×5
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 17; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 20; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [21]  vle32 v2, (x1)    — load B[0..3] into v2
    i_imem_addr = 21; i_imem_data = 32'h0200E107; @(posedge clk); #1;
    // [22..28]  NOP×7
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 25; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [29]  vadd v3, v1, v2   — v3 = A + B
    i_imem_addr = 29; i_imem_data = 32'h002081D7; @(posedge clk); #1;
    // [30..36]  NOP×7
    i_imem_addr = 30; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 33; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 34; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 35; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [37]  addi x1, x0, 32   — base addr C = 32
    i_imem_addr = 37; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [38..42]  NOP×5
    i_imem_addr = 38; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 41; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 42; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [43]  vse32 v3, (x1)    — store C[0..3] to dmem[8..11]
    i_imem_addr = 43; i_imem_data = 32'h0200E1A7; @(posedge clk); #1;
    // [44..50]  NOP×7
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

    // Allow ICache to stabilise in read mode
    @(posedge clk); #1;
    @(posedge clk); #1;

    // Release reset and pre-load DCache operands
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
            $display("=== VECTOR PERFORMANCE RESULT: %0d cycles ===", cycle_count);
            $display("");

            check128(dut.vext.vregfile.regs[3],
                     {32'd120, 32'd100, 32'd80, 32'd60},
                     "v3 = {120,100,80,60} (vadd result)");
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
