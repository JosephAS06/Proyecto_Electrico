// =============================================================================
// Módulo: tb_vregisters
// Archivo: testbench/tb_vregfile.v
//
// Descripción:
//   Banco de pruebas unitario para el módulo "vregisters" (Banco de Registros
//   Vectoriales, VRF). Verifica las operaciones de escritura sincrónica y
//   lectura combinacional del VRF de 32 × 128 bits.
//
// Módulo bajo prueba:
//   vregisters — banco de 32 registros vectoriales de 128 bits cada uno,
//   con 2 puertos de lectura (puerto A y B) y 1 puerto de escritura (we/addr_w).
//   Las lecturas son combinacionales (resultado inmediato) y las escrituras
//   ocurren en el flanco positivo del reloj cuando we=1.
//
//
// Metodología:
//   Se genera un reloj de período 10 ns (cambio cada 5 ns). Cada operación
//   de escritura espera un posedge del reloj para capturar el dato en el VRF.
//   Después de cada escritura se espera 1 ns (#1) para que las lecturas
//   combinacionales se propaguen antes de verificarlas.
//
// Casos de prueba:
//
//   1. Reset inicial — verifica que rst=1 no escribe datos espurios.
//
//   2. Escritura en v1 — escribe {4{0xEEEEEEEE}} y verifica que data_a lo lee.
//      Ilustra la escritura básica y la lectura del puerto A.
//
//   3. Sobrescritura de v1 — demuestra que una segunda escritura reemplaza
//      el valor anterior correctamente (no hay acumulación ni bits residuales).
//
//   4. Lectura dual simultánea — escribe en v2 y v3, luego lee ambos al mismo
//      tiempo con addr_a=v2 y addr_b=v3. Confirma que los dos puertos de lectura
//      son independientes.
//
//   5. Escritura inhibida (we=0) — intenta escribir en v2 con we=0 y verifica
//      que el VRF retiene el valor anterior (la escritura no ocurre).
//
//   6. Reset limpia todos los registros — activa rst=1 y verifica que v1 y v3
//      (dos registros previamente escritos) quedan en 0.
//
// Relación con el pipeline vectorial:
//   El VRF no implementa bypass interno; el módulo hazard_unit detecta los
//   peligros RAW antes de que Issue lea del VRF. Por eso estas pruebas validan
//   exclusivamente el comportamiento de escritura/lectura del VRF, sin preocuparse
//   por la interacción con el pipeline.
// =============================================================================

`timescale 1ns/1ps
module tb_vregisters;
    reg        clk, rst, we;
    reg [4:0]  addr_a, addr_b, addr_w;
    reg [127:0] data_in;
    wire [127:0] data_a, data_b;

    // Instancia del módulo bajo prueba: Banco de Registros Vectoriales
    vregisters dut (
        .clk     (clk),
        .rst     (rst),
        .we      (we),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_w  (addr_w),
        .data_in (data_in),
        .data_a  (data_a),
        .data_b  (data_b)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    // -------------------------------------------------------------------------
    // Tarea: check_a
    //   Compara el puerto de lectura A (data_a) con el valor esperado.
    //   Las lecturas son combinacionales: no se necesita esperar un ciclo.
    // -------------------------------------------------------------------------
    task check_a;
        input [127:0] expected;
         begin
            if (data_a === expected) begin
                $display("  PASS data_a: got %h", data_a);
                pass = pass + 1;
            end else begin
                $display("  FAIL data_a: got %h, expected %h", data_a, expected);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: check_b
    //   Compara el puerto de lectura B (data_b) con el valor esperado.
    // -------------------------------------------------------------------------
    task check_b;
        input [127:0] expected;
        begin
            if (data_b === expected) begin
                $display("  PASS data_b: got %h", data_b);
                pass = pass + 1;
            end else begin
                $display("  FAIL data_b: got %h, expected %h", data_b, expected);
                fail = fail + 1;
            end
        end
    endtask

    // Nota: se espera a un posedge del reloj para capturar cada instrucción
    // en el VRF (la escritura es síncrona). Después de @(posedge clk) se
    // espera #1 para que la lectura combinacional se propague.
    initial begin
        $dumpfile("tb_vregfile.vcd");
        $dumpvars(0, tb_vregisters);
        $display("=== vregfile unit tests ===");

        // =====================================================================
        // Prueba 0: Reset
        //   rst=1 mantiene todos los registros en 0. Al bajar rst a 0 los
        //   registros conservan sus valores (el reset no es continuo).
        // =====================================================================
        rst = 1; we = 0;
        addr_a = 0; addr_b = 0; addr_w = 0; data_in = 128'hFFFF;
        @(posedge clk); #1;
        rst = 0;

        // =====================================================================
        // Prueba 1: Escritura básica en v1
        //   Se escribe el patrón {4{0xEEEEEEEE}} en el registro v1 (addr=1).
        //   Después se apunta el puerto A a v1 y se verifica la lectura.
        //   El VRF no tiene bypass interno: la escritura ocurre en el flanco
        //   positivo y la lectura refleja el nuevo valor combinacionalmente.
        // =====================================================================
        $display("Test: write v1 = {4{32'hEEEEEEEE}}");
        we = 1; addr_w = 5'd1; data_in = {4{32'hEEEEEEEE}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd1;
        #1;
        check_a({4{32'hEEEEEEEE}});

        // =====================================================================
        // Prueba 2: Sobrescritura de v1
        //   Una segunda escritura reemplaza el valor previo en v1.
        //   Verifica que no queden bits residuales del valor anterior.
        // =====================================================================
        $display("Test: overwrite v1 = {4{32'hAAAAAAAA}}");
        we = 1; addr_w = 5'd1; data_in = {4{32'hAAAAAAAA}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd1;
        #1;
        check_a({4{32'hAAAAAAAA}});

        // =====================================================================
        // Prueba 3: Lectura dual simultánea (puertos A y B independientes)
        //   Se escriben dos registros distintos (v2 y v3) en ciclos consecutivos.
        //   Luego se leen simultáneamente: addr_a=v2, addr_b=v3.
        //   Confirma que los puertos A y B son completamente independientes.
        // =====================================================================
        $display("Test: dual-port read v2/v3");
        we = 1;
        addr_w = 5'd2; data_in = {4{32'hAAAAAAAA}};
        @(posedge clk); #1;
        addr_w = 5'd3; data_in = {4{32'h55555555}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd2; addr_b = 5'd3;
        #1;
        check_a({4{32'hAAAAAAAA}});
        check_b({4{32'h55555555}});

        // =====================================================================
        // Prueba 4: Escritura inhibida (we=0)
        //   Intenta escribir 0xDDDD en v2 con we=0. El VRF debe ignorar la
        //   escritura y mantener el valor anterior {4{0xAAAAAAAA}}.
        //   Este comportamiento es crítico para las NOPs del pipeline.
        // =====================================================================
        $display("Test: no write when we=0");
        we = 0; addr_w = 5'd2; data_in = 128'hDDDD;
        @(posedge clk); #1;
        addr_a = 5'd2;
        #1;
        check_a({4{32'hAAAAAAAA}}); // debe retener el valor previo

        // =====================================================================
        // Prueba 5: Reset limpia todos los registros
        //   rst=1 pone todos los registros a 0 en el próximo flanco positivo.
        //   Se verifica que v1 (escrito en la prueba 2) y v3 quedan en cero.
        //   Nota: el reset es síncrono, actúa en el flanco del reloj.
        // =====================================================================
        $display("Test: reset clears all registers");
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        addr_a = 5'd1; addr_b = 5'd3;
        #1;
        check_a(128'b0);
        check_b(128'b0);

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
