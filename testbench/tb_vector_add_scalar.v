`timescale 1ns/1ps

module tb_vector_add_scalar;

    reg clk;
    reg rst;

    reg        i_imem_wen;
    reg [31:0] i_imem_addr;
    reg [31:0] i_imem_data;

    integer cycle_count;
    integer errors;

    ve_integrated dut (
        .clk(clk),
        .rst(rst),
        .i_imem_wen(i_imem_wen),
        .i_imem_addr(i_imem_addr),
        .i_imem_data(i_imem_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task load_instr;
        input [31:0] addr;
        input [31:0] instr;
        begin
            @(posedge clk);
            i_imem_wen  = 1'b1;
            i_imem_addr = addr;
            i_imem_data = instr;
        end
    endtask

    initial begin
        rst = 1'b1;
        i_imem_wen  = 1'b0;
        i_imem_addr = 32'd0;
        i_imem_data = 32'd0;
        cycle_count = 0;
        errors      = 0;

        // =========================
        // Carga del programa escalar
        // =========================
        load_instr(32'h00000000, 32'h10000513);
        load_instr(32'h00000004, 32'h14000593);
        load_instr(32'h00000008, 32'h18000613);
        load_instr(32'h0000000C, 32'h01000e13);
        load_instr(32'h00000010, 32'h00052283);
        load_instr(32'h00000014, 32'h00000013);
        load_instr(32'h00000018, 32'h00000013);
        load_instr(32'h0000001C, 32'h0005a303);
        load_instr(32'h00000020, 32'h00000013);
        load_instr(32'h00000024, 32'h00000013);
        load_instr(32'h00000028, 32'h006283b3);
        load_instr(32'h0000002C, 32'h00000013);
        load_instr(32'h00000030, 32'h00000013);
        load_instr(32'h00000034, 32'h00762023);
        load_instr(32'h00000038, 32'h00450513);
        load_instr(32'h0000003C, 32'h00458593);
        load_instr(32'h00000040, 32'h00460613);
        load_instr(32'h00000044, 32'hfffe0e13);
        load_instr(32'h00000048, 32'h00000013);
        load_instr(32'h0000004C, 32'h00000013);
        load_instr(32'h00000050, 32'hfc0e10e3);
        load_instr(32'h00000054, 32'h00100293);
        load_instr(32'h00000058, 32'h1fc00313);
        load_instr(32'h0000005C, 32'h00000013);
        load_instr(32'h00000060, 32'h00000013);
        load_instr(32'h00000064, 32'h00532023);
        load_instr(32'h00000068, 32'h00000063);

        @(posedge clk);
        i_imem_wen = 1'b0;

        // Reset adicional para inicializar dcache
        repeat(5) @(posedge clk);

        // =========================
        // Inicialización de datos
        // A[0:15] en pos64-pos79
        // B[0:15] en pos80-pos95
        // C[0:15] en pos96-pos111
        // =========================
        dut.dmem.pos64 = 32'd1;
        dut.dmem.pos65 = 32'd2;
        dut.dmem.pos66 = 32'd3;
        dut.dmem.pos67 = 32'd4;
        dut.dmem.pos68 = 32'd5;
        dut.dmem.pos69 = 32'd6;
        dut.dmem.pos70 = 32'd7;
        dut.dmem.pos71 = 32'd8;
        dut.dmem.pos72 = 32'd9;
        dut.dmem.pos73 = 32'd10;
        dut.dmem.pos74 = 32'd11;
        dut.dmem.pos75 = 32'd12;
        dut.dmem.pos76 = 32'd13;
        dut.dmem.pos77 = 32'd14;
        dut.dmem.pos78 = 32'd15;
        dut.dmem.pos79 = 32'd16;

        dut.dmem.pos80 = 32'd10;
        dut.dmem.pos81 = 32'd20;
        dut.dmem.pos82 = 32'd30;
        dut.dmem.pos83 = 32'd40;
        dut.dmem.pos84 = 32'd50;
        dut.dmem.pos85 = 32'd60;
        dut.dmem.pos86 = 32'd70;
        dut.dmem.pos87 = 32'd80;
        dut.dmem.pos88 = 32'd90;
        dut.dmem.pos89 = 32'd100;
        dut.dmem.pos90 = 32'd110;
        dut.dmem.pos91 = 32'd120;
        dut.dmem.pos92 = 32'd130;
        dut.dmem.pos93 = 32'd140;
        dut.dmem.pos94 = 32'd150;
        dut.dmem.pos95 = 32'd160;

        dut.dmem.pos96  = 32'd0;
        dut.dmem.pos97  = 32'd0;
        dut.dmem.pos98  = 32'd0;
        dut.dmem.pos99  = 32'd0;
        dut.dmem.pos100 = 32'd0;
        dut.dmem.pos101 = 32'd0;
        dut.dmem.pos102 = 32'd0;
        dut.dmem.pos103 = 32'd0;
        dut.dmem.pos104 = 32'd0;
        dut.dmem.pos105 = 32'd0;
        dut.dmem.pos106 = 32'd0;
        dut.dmem.pos107 = 32'd0;
        dut.dmem.pos108 = 32'd0;
        dut.dmem.pos109 = 32'd0;
        dut.dmem.pos110 = 32'd0;
        dut.dmem.pos111 = 32'd0;

        dut.dmem.pos127 = 32'd0;

        @(posedge clk);
        rst = 1'b0;

        // =========================
        // Conteo de ciclos
        // =========================
        while (cycle_count < 2000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (dut.dmem_write_en_a &&
                dut.dmem_addr_a == 32'd127 &&
                dut.dmem_wdata_a == 32'd1) begin

                $display("Benchmark escalar terminado");
                $display("Ciclos totales = %0d", cycle_count);

                if (dut.dmem.pos96  !== 32'd11)  errors = errors + 1;
                if (dut.dmem.pos97  !== 32'd22)  errors = errors + 1;
                if (dut.dmem.pos98  !== 32'd33)  errors = errors + 1;
                if (dut.dmem.pos99  !== 32'd44)  errors = errors + 1;
                if (dut.dmem.pos100 !== 32'd55)  errors = errors + 1;
                if (dut.dmem.pos101 !== 32'd66)  errors = errors + 1;
                if (dut.dmem.pos102 !== 32'd77)  errors = errors + 1;
                if (dut.dmem.pos103 !== 32'd88)  errors = errors + 1;
                if (dut.dmem.pos104 !== 32'd99)  errors = errors + 1;
                if (dut.dmem.pos105 !== 32'd110) errors = errors + 1;
                if (dut.dmem.pos106 !== 32'd121) errors = errors + 1;
                if (dut.dmem.pos107 !== 32'd132) errors = errors + 1;
                if (dut.dmem.pos108 !== 32'd143) errors = errors + 1;
                if (dut.dmem.pos109 !== 32'd154) errors = errors + 1;
                if (dut.dmem.pos110 !== 32'd165) errors = errors + 1;
                if (dut.dmem.pos111 !== 32'd176) errors = errors + 1;

                $display("C[0]  = %0d", dut.dmem.pos96);
                $display("C[1]  = %0d", dut.dmem.pos97);
                $display("C[2]  = %0d", dut.dmem.pos98);
                $display("C[3]  = %0d", dut.dmem.pos99);
                $display("C[4]  = %0d", dut.dmem.pos100);
                $display("C[5]  = %0d", dut.dmem.pos101);
                $display("C[6]  = %0d", dut.dmem.pos102);
                $display("C[7]  = %0d", dut.dmem.pos103);
                $display("C[8]  = %0d", dut.dmem.pos104);
                $display("C[9]  = %0d", dut.dmem.pos105);
                $display("C[10] = %0d", dut.dmem.pos106);
                $display("C[11] = %0d", dut.dmem.pos107);
                $display("C[12] = %0d", dut.dmem.pos108);
                $display("C[13] = %0d", dut.dmem.pos109);
                $display("C[14] = %0d", dut.dmem.pos110);
                $display("C[15] = %0d", dut.dmem.pos111);

                if (errors == 0)
                    $display("Resultado correcto");
                else
                    $display("Resultado incorrecto. Errores = %0d", errors);

                $finish;
            end
        end

        $display("ERROR: timeout");
        $finish;
    end

endmodule
