// =============================================================================
// Módulo: tb_alu
// Archivo: testbench/tb_alu.v
//
// Descripción:
//   Banco de pruebas unitario para el módulo "alu" (Unidad Aritmético-Lógica
//   vectorial). Verifica las 9 operaciones válidas y el caso por defecto,
//   comprobando que la salida "out" coincide con el resultado esperado para
//   distintas combinaciones de operandos.
//
// Módulo bajo prueba:
//   alu #(.SIZE(32)) — versión de 32 bits, idéntica a la que usa alu_array
//   para procesar cada elemento de 32 bits de un registro vectorial de 128 bits.
//
// Metodología de prueba:
//   El módulo alu es combinacional (sin reloj). Cada caso de prueba aplica
//   los estímulos directamente a las entradas y después de 1 ns (#1) lee
//   la salida "out". La tarea "check" compara "out" con el valor esperado y
//   acumula los contadores de PASS/FAIL.
//
// Operaciones verificadas y su codificación (alu_op[3:0]):
//
//   Código  │ Operación │ Descripción
//   ────────┼───────────┼───────────────────────────────────────────────
//   4'b0000 │ VADD      │ Suma aritmética sin signo (desbordamiento truncado)
//   4'b1000 │ VSUB      │ Resta aritmética (complemento a 2)
//   4'b0001 │ VSLL      │ Desplazamiento lógico a la izquierda
//   4'b0010 │ VSLT      │ Comparación con signo  (out=1 si a < b, else 0)
//   4'b0011 │ VSLTU     │ Comparación sin signo  (out=1 si a < b, else 0)
//   4'b0100 │ VXOR      │ XOR bit a bit
//   4'b0101 │ VSRL      │ Desplazamiento lógico a la derecha (rellena con 0)
//   4'b1101 │ VSRA      │ Desplazamiento aritmético a la derecha (extensión de signo)
//   4'b0110 │ VOR       │ OR bit a bit
//   4'b0111 │ VAND      │ AND bit a bit
//   otras   │ default   │ out = 0 (código de operación inválido)
//
// Nota sobre VSUB vs VSLT/VSLTU:
//   El bit 3 de alu_op (alu_op[3]) distingue entre variantes de la misma
//   función:  0100 (VXOR) vs 1100 (no usada), 0101 (VSRL) vs 1101 (VSRA),
//   y 0000 (VADD) vs 1000 (VSUB). Esto replica la codificación funct7[5]
//   del ISA RISC-V, que usa ese mismo bit para distinguir ADD/SUB y SRL/SRA.
//
// Casos de borde importantes:
//   VADD: desbordamiento -> 0xFFFFFFFF + 1 = 0x00000000 (truncado a 32 bits)
//   VSUB: resultado negativo -> 0 - 1 = 0xFFFFFFFF (complemento a 2)
//   VSLL: desplazamiento 31 -> único bit en posición más significativa
//   VSLT: 0xFFFFFFFF (= -1 con signo) < 0, mientras que con VSLTU es > 0
//   VSRA: el bit de signo se propaga hacia la derecha (vs VSRL que rellena con 0)
//
// Flujo de ejecución:
//   1. Se instancia la ALU como "dut" con SIZE=32.
//   2. El bloque "initial" itera sobre todas las operaciones en orden.
//   3. Cada grupo de pruebas llama a `check(expected)` que compara "out".
//   4. Al terminar se imprime el resumen: "N passed, M failed".
//   5. $finish termina la simulación.
// =============================================================================

`timescale 1ns/1ps
module tb_alu;
    reg  [3:0]  alu_op;
    reg  [31:0] in_a, in_b;
    wire [31:0] out;

    // Instancia del módulo bajo prueba: ALU de 32 bits
    alu #(.SIZE(32)) dut (
        .alu_op (alu_op),
        .in_a   (in_a),
        .in_b   (in_b),
        .out    (out)
    );

    integer pass = 0, fail = 0;

    // -------------------------------------------------------------------------
    // Tarea: check
    //   Espera 1 ns para que la lógica combinacional se propague, luego compara
    //   "out" con "expected". Imprime el resultado y actualiza los contadores.
    // -------------------------------------------------------------------------
    task check;
        input [31:0] expected;
        begin
            #1;
            if (out === expected) begin
                $display("  PASS: op=%04b  a=%08h  b=%08h -> %08h", alu_op, in_a, in_b, out);
                pass = pass + 1;
            end else begin
                $display("  FAIL: op=%04b  a=%08h  b=%08h -> got %08h, expected %08h",
                         alu_op, in_a, in_b, out, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        $display("=== ALU unit tests ===");

        // =====================================================================
        // VADD (4'b0000): Suma aritmética
        //   Caso normal: 10 + 20 = 30
        //   Desbordamiento: 0xFFFFFFFF + 1 = 0x00000000 (truncado a 32 bits)
        //   Neutro: 0 + 0 = 0
        // =====================================================================
        $display("-- VADD (4'b0000) --");
        alu_op = 4'b0000;
        in_a = 32'd10;       in_b = 32'd20;       check(32'd30);
        in_a = 32'hFFFFFFFF; in_b = 32'd1;         check(32'd0);
        in_a = 32'd0;        in_b = 32'd0;         check(32'd0);

        // =====================================================================
        // VSUB (4'b1000): Resta aritmética (complemento a 2)
        //   Caso normal: 50 - 15 = 35
        //   Resultado negativo: 0 - 1 = 0xFFFFFFFF (= -1 en complemento a 2)
        //   Resultado cero: ABCD - ABCD = 0
        // =====================================================================
        $display("-- VSUB (4'b1000) --");
        alu_op = 4'b1000;
        in_a = 32'd50;       in_b = 32'd15;        check(32'd35);
        in_a = 32'd0;        in_b = 32'd1;         check(32'hFFFFFFFF);
        in_a = 32'hABCD;     in_b = 32'hABCD;      check(32'd0);

        // =====================================================================
        // VSLL (4'b0001): Desplazamiento lógico a la izquierda
        //   1 << 4 = 0x10 (desplazamiento típico)
        //   1 << 31 = 0x80000000 (bit de signo encendido)
        //   Desplazamiento 0: dato inalterado
        //   Overflow de salida: 0x80000000 << 1 = 0 (bit se pierde)
        // =====================================================================
        $display("-- VSLL (4'b0001) --");
        alu_op = 4'b0001;
        in_a = 32'h00000001; in_b = 32'd4;         check(32'h00000010);
        in_a = 32'h00000001; in_b = 32'd31;        check(32'h80000000);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'hFFFFFFFF);
        in_a = 32'h80000000; in_b = 32'd1;         check(32'h00000000);

        // =====================================================================
        // VSLT (4'b0010): Comparación con signo (Signed Less Than)
        //   out = 1 si in_a < in_b (interpretados como enteros con signo), 0 si no.
        //   0xFFFFFFFF = -1 (con signo) < 0 -> resultado 1
        //   1 > -1 (0xFFFFFFFF con signo) -> resultado 0
        // =====================================================================
        $display("-- VSLT (4'b0010) --");
        alu_op = 4'b0010;
        in_a = 32'd5;        in_b = 32'd10;        check(32'd1);
        in_a = 32'd10;       in_b = 32'd5;         check(32'd0);
        in_a = 32'd5;        in_b = 32'd5;         check(32'd0);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'd1); // -1 < 0 con signo
        in_a = 32'd1;        in_b = 32'hFFFFFFFF;  check(32'd0); // 1 > -1 con signo

        // =====================================================================
        // VSLTU (4'b0011): Comparación sin signo (Unsigned Less Than)
        //   0xFFFFFFFF = 4294967295 > 0 sin signo -> resultado 0
        //   0 < 0xFFFFFFFF sin signo -> resultado 1
        // =====================================================================
        $display("-- VSLTU (4'b0011) --");
        alu_op = 4'b0011;
        in_a = 32'd5;        in_b = 32'd10;        check(32'd1);
        in_a = 32'd10;       in_b = 32'd5;         check(32'd0);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'd0); // max_uint > 0
        in_a = 32'd0;        in_b = 32'hFFFFFFFF;  check(32'd1); // 0 < max_uint

        // =====================================================================
        // VXOR (4'b0100): XOR bit a bit
        //   Patrón alternado: 0xAAAA... XOR 0x5555... = 0xFFFF... (todos a 1)
        //   Todos iguales: XOR de igual número = 0
        //   Neutro: cualquier valor XOR 0 = mismo valor
        // =====================================================================
        $display("-- VXOR (4'b0100) --");
        alu_op = 4'b0100;
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555;  check(32'hFFFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF;  check(32'h00000000);
        in_a = 32'hDEADBEEF; in_b = 32'h00000000;  check(32'hDEADBEEF);

        // =====================================================================
        // VSRL (4'b0101): Desplazamiento lógico a la derecha
        //   Rellena con 0 desde la izquierda (sin extensión de signo).
        //   0x80000000 >> 1 = 0x40000000 (el bit de signo se vuelve 0)
        // =====================================================================
        $display("-- VSRL (4'b0101) --");
        alu_op = 4'b0101;
        in_a = 32'h80000000; in_b = 32'd1;         check(32'h40000000);
        in_a = 32'hF0000000; in_b = 32'd4;         check(32'h0F000000);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'hFFFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'd31;        check(32'h00000001);

        // =====================================================================
        // VSRA (4'b1101): Desplazamiento aritmético a la derecha
        //   Extiende el bit de signo hacia la izquierda (para preservar el signo).
        //   0x80000000 >> 1 = 0xC0000000 (bit de signo se propaga)
        //   Número positivo: igual que VSRL
        //   -1 (0xFFFFFFFF) >> 31 = 0xFFFFFFFF (todos los bits son 1 = -1)
        // =====================================================================
        $display("-- VSRA (4'b1101) --");
        alu_op = 4'b1101;
        in_a = 32'h80000000; in_b = 32'd1;         check(32'hC0000000);
        in_a = 32'hF0000000; in_b = 32'd4;         check(32'hFF000000);
        in_a = 32'h7FFFFFFF; in_b = 32'd1;         check(32'h3FFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'd31;        check(32'hFFFFFFFF);

        // =====================================================================
        // VOR (4'b0110): OR bit a bit
        //   Patrón complementario: OR da todos 1s
        //   Neutro: 0 OR 0 = 0
        // =====================================================================
        $display("-- VOR (4'b0110) --");
        alu_op = 4'b0110;
        in_a = 32'hF0F00000; in_b = 32'h00000F0F;  check(32'hF0F00F0F);
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555;  check(32'hFFFFFFFF);
        in_a = 32'h00000000; in_b = 32'h00000000;  check(32'h00000000);

        // =====================================================================
        // VAND (4'b0111): AND bit a bit
        //   Máscara: 0xFF00FF00 AND 0x0F0F0F0F -> solo bits que ambos tienen 1
        //   Neutro: cualquier valor AND 0xFFFFFFFF = mismo valor
        //   Cero: cualquier valor AND 0 = 0
        // =====================================================================
        $display("-- VAND (4'b0111) --");
        alu_op = 4'b0111;
        in_a = 32'hFF00FF00; in_b = 32'h0F0F0F0F;  check(32'h0F000F00);
        in_a = 32'hFFFFFFFF; in_b = 32'h00000000;  check(32'h00000000);
        in_a = 32'hAAAAAAAA; in_b = 32'hFFFFFFFF;  check(32'hAAAAAAAA);

        // =====================================================================
        // Caso por defecto: códigos de operación no definidos -> out = 0
        //   Los códigos 4'b1001 y 4'b1010 no corresponden a ninguna operación.
        //   El caso "default" del case genera out = 0 para cualquier entrada.
        // =====================================================================
        $display("-- Default --");
        alu_op = 4'b1001; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);
        alu_op = 4'b1010; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
