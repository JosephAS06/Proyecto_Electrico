// =============================================================================
// Módulo: tb_vlsu_integration
// Archivo: testbench/tb_vlsu_integration.v
//
// Descripción:
//   Banco de pruebas combinacional para el módulo `vlsu` (Vector Load/Store
//   Unit). Verifica todos los modos de direccionamiento soportados, la
//   generación correcta de habilitadores de lectura y escritura, y el
//   enrutamiento de datos para los dos puertos del DCache.
//
// Módulo bajo prueba:
//   vlsu — generador puramente combinacional de señales de bus para el DCache.
//   No tiene estado interno (sin registros). Para cada combinación de entradas
//   produce inmediatamente las señales de dirección, habilitación y datos.
//
// Modelo de dos fases:
//   Un registro vectorial de 128 bits contiene 4 elementos de 32 bits.
//   El DCache tiene 2 puertos (A y B), por lo que se procesan 2 elementos
//   por ciclo. Para acceder a los 4 elementos se necesitan 2 ciclos (fases):
//
//     i_phase = 2'b00 -> ACCESS_01: elem_0 -> puerto A,  elem_1 -> puerto B
//     i_phase = 2'b01 -> ACCESS_23: elem_2 -> puerto A,  elem_3 -> puerto B
//
// Modos de direccionamiento verificados:
//
//   Unit-stride: paso fijo de 4 bytes entre elementos consecutivos.
//     addr_N = base + N * 4
//
//   Strided: el paso entre elementos es i_stride (arbitrario, incluso negativo).
//     addr_N = base + N * stride
//
//   Indexed (Scatter/Gather): cada elemento tiene su propio offset de 32 bits
//   almacenado en i_offset_buf, que representa el registro vectorial vs2.
//     addr_N = base + offset_buf[N*32 +: 32]
//
// Operaciones de máscara (VLM/VSM):
//   Con i_is_mask_op=1 solo se accede al primer byte del primer elemento:
//   - Puerto A: byte_en = 4'b0001 (solo byte 0)
//   - Puerto B: desactivado (read_en_b = 0, write_en_b = 0)
//   La fase ACCESS_23 se deshabilita desde la etapa MEM (i_en=0).
//
// Metodología:
//   El módulo es combinacional. Cada caso de prueba aplica los estímulos,
//   espera 1 ns (#1) para la propagación, y luego llama a las tareas chk32
//   y chk1 para comparar las salidas con los valores esperados.
//   La tarea "reset_inputs" pone todas las entradas en estado inactivo entre
//   grupos de pruebas para evitar interferencias.
//
// Pruebas incluidas (11 en total):
//   1.  Unit-stride load, ACCESS_01   -> addr_A=base, addr_B=base+4
//   2.  Unit-stride load, ACCESS_23   -> addr_A=base+8, addr_B=base+12
//   3.  Strided load (stride=8), ACCESS_01 -> addr_A=base, addr_B=base+8
//   4.  Strided load (stride=8), ACCESS_23 -> addr_A=base+16, addr_B=base+24
//   5.  Indexed load, ACCESS_01       -> addr_A=base+off0, addr_B=base+off1
//   6.  Indexed load, ACCESS_23       -> addr_A=base+off2, addr_B=base+off3
//   7.  Unit-stride store, ACCESS_01  -> wdata_A=elem0, wdata_B=elem1
//   8.  Unit-stride store, ACCESS_23  -> wdata_A=elem2, wdata_B=elem3
//   9.  VLM mask load, ACCESS_01      -> read_en_A=1, read_en_B=0
//   10. VSM mask store, ACCESS_01     -> write_en_A=1, byte_en_A=0001, write_en_B=0
//   11. i_en=0                        -> todos los enables desactivados
// =============================================================================

// Testbench combinacional para vlsu (generador de accesos LSU vectorial).
// Verifica: generacion de direcciones, enables y rutas de datos para
// unit-stride, strided, indexed, mask load (VLM) y mask store (VSM).
`timescale 1ns/1ps

module tb_vlsu_integration;

    reg  [1:0]   i_phase;
    reg          i_en;
    reg          i_is_load;
    reg          i_is_store;
    reg          i_is_mask_op;
    reg          i_is_strided;
    reg          i_is_indexed;
    reg  [31:0]  i_base_addr;
    reg  [31:0]  i_stride;
    reg  [127:0] i_offset_buf;
    reg  [127:0] i_wdata;

    wire [31:0]  o_mem_addr,    o_mem_addr_b;
    wire         o_mem_read_en, o_mem_read_en_b;
    wire         o_mem_write_en,o_mem_write_en_b;
    wire [31:0]  o_mem_wdata,   o_mem_wdata_b;
    wire [3:0]   o_mem_byte_en, o_mem_byte_en_b;

    // Instancia del módulo bajo prueba
    vlsu dut (
        .i_phase         (i_phase),
        .i_en            (i_en),
        .i_is_load       (i_is_load),
        .i_is_store      (i_is_store),
        .i_is_mask_op    (i_is_mask_op),
        .i_is_strided    (i_is_strided),
        .i_is_indexed    (i_is_indexed),
        .i_base_addr     (i_base_addr),
        .i_stride        (i_stride),
        .i_offset_buf    (i_offset_buf),
        .i_wdata         (i_wdata),
        .o_mem_addr      (o_mem_addr),
        .o_mem_read_en   (o_mem_read_en),
        .o_mem_write_en  (o_mem_write_en),
        .o_mem_wdata     (o_mem_wdata),
        .o_mem_byte_en   (o_mem_byte_en),
        .o_mem_addr_b    (o_mem_addr_b),
        .o_mem_read_en_b (o_mem_read_en_b),
        .o_mem_write_en_b(o_mem_write_en_b),
        .o_mem_wdata_b   (o_mem_wdata_b),
        .o_mem_byte_en_b (o_mem_byte_en_b)
    );

    integer pass = 0, fail = 0;

    // -------------------------------------------------------------------------
    // Tarea: chk32
    //   Verifica un valor de 32 bits. El parámetro "tag" identifica el caso.
    // -------------------------------------------------------------------------
    task chk32;
        input [31:0] got;
        input [31:0] exp;
        input [63:0] tag;
        begin
            if (got === exp) begin
                $display("    PASS %0d", tag);
                pass = pass + 1;
            end else begin
                $display("    FAIL %0d: got %h  expected %h", tag, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: chk1
    //   Verifica un bit de control (enable). El parámetro "tag" identifica el caso.
    // -------------------------------------------------------------------------
    task chk1;
        input got;
        input exp;
        input [63:0] tag;
        begin
            if (got === exp) begin
                $display("    PASS %0d", tag);
                pass = pass + 1;
            end else begin
                $display("    FAIL %0d: got %b  expected %b", tag, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: reset_inputs
    //   Pone todas las entradas en estado inactivo. Se llama entre grupos de
    //   pruebas para garantizar que los estímulos previos no interfieran.
    // -------------------------------------------------------------------------
    task reset_inputs;
        begin
            i_en = 0; i_phase = 2'b00;
            i_is_load = 0; i_is_store = 0; i_is_mask_op = 0;
            i_is_strided = 0; i_is_indexed = 0;
            i_base_addr = 0; i_stride = 0;
            i_offset_buf = 0; i_wdata = 0;
        end
    endtask

    initial begin
        $display("=== tb_vlsu_integration ===");
        reset_inputs; #2;

        // =====================================================================
        // TEST 1: Unit-stride load, ACCESS_01
        //   Modo: unit-stride -> paso fijo de 4 bytes
        //   base = 0x100, fase 0 (elementos 0 y 1)
        //   addr_A = 0x100 (elem_0)
        //   addr_B = 0x104 (elem_1 = base + 4)
        //   read_en_A = 1 (es load), write_en = 0 (no es store)
        // =====================================================================
        $display("\n[TEST 1] Unit-stride load ACCESS_01");
        i_en = 1; i_is_load = 1; i_base_addr = 32'h100; #1;
        chk32(o_mem_addr,    32'h100, 1);
        chk32(o_mem_addr_b,  32'h104, 2);
        chk1 (o_mem_read_en,   1'b1,  3);
        chk1 (o_mem_read_en_b, 1'b1,  4);
        chk1 (o_mem_write_en,  1'b0,  5);

        // =====================================================================
        // TEST 2: Unit-stride load, ACCESS_23
        //   base = 0x100 (misma), fase 1 (elementos 2 y 3)
        //   addr_A = 0x108 (elem_2 = base + 4*2)
        //   addr_B = 0x10C (elem_3 = base + 4*3)
        // =====================================================================
        $display("\n[TEST 2] Unit-stride load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,    32'h108, 6);
        chk32(o_mem_addr_b,  32'h10C, 7);
        chk1 (o_mem_read_en,   1'b1,  8);

        // =====================================================================
        // TEST 3: Strided load, ACCESS_01 (stride=8)
        //   Modo: strided -> el paso entre elementos es i_stride = 8
        //   base = 0x200, fase 0
        //   addr_A = 0x200 (elem_0)
        //   addr_B = 0x208 (elem_1 = base + 8)
        // =====================================================================
        $display("\n[TEST 3] Strided load ACCESS_01 (stride=8)");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_strided = 1;
        i_base_addr = 32'h200; i_stride = 32'd8; i_phase = 2'b00; #1;
        chk32(o_mem_addr,   32'h200, 9);
        chk32(o_mem_addr_b, 32'h208, 10);

        // =====================================================================
        // TEST 4: Strided load, ACCESS_23 (stride=8)
        //   base = 0x200, fase 1, stride = 8
        //   addr_A = 0x210 (elem_2 = base + 8*2)
        //   addr_B = 0x218 (elem_3 = base + 8*3)
        // =====================================================================
        $display("\n[TEST 4] Strided load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,   32'h210, 11);
        chk32(o_mem_addr_b, 32'h218, 12);

        // =====================================================================
        // TEST 5: Indexed load, ACCESS_01
        //   Modo: indexed -> cada elemento usa su propio offset de i_offset_buf.
        //   base = 0x300
        //   i_offset_buf = {off3=0x40, off2=0x30, off1=0x20, off0=0x10}
        //     -> [127:96]=off3, [95:64]=off2, [63:32]=off1, [31:0]=off0
        //   fase 0:
        //     addr_A = 0x300 + 0x10 = 0x310 (elem_0)
        //     addr_B = 0x300 + 0x20 = 0x320 (elem_1)
        // =====================================================================
        $display("\n[TEST 5] Indexed load ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_indexed = 1;
        i_base_addr  = 32'h300;
        i_offset_buf = {32'h40, 32'h30, 32'h20, 32'h10}; // [127:96]=off3, [31:0]=off0
        i_phase = 2'b00; #1;
        chk32(o_mem_addr,   32'h310, 13);
        chk32(o_mem_addr_b, 32'h320, 14);

        // =====================================================================
        // TEST 6: Indexed load, ACCESS_23
        //   base = 0x300, offsets del buffer, fase 1:
        //     addr_A = 0x300 + 0x30 = 0x330 (elem_2)
        //     addr_B = 0x300 + 0x40 = 0x340 (elem_3)
        // =====================================================================
        $display("\n[TEST 6] Indexed load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,   32'h330, 15);
        chk32(o_mem_addr_b, 32'h340, 16);

        // =====================================================================
        // TEST 7: Unit-stride store, ACCESS_01
        //   i_wdata = {elem3=0xDDDD, elem2=0xCCCC, elem1=0xBBBB, elem0=0xAAAA}
        //   Empaquetado: [127:96]=elem3, [31:0]=elem0
        //   fase 0:
        //     Puerto A: addr=0x100, wdata=i_wdata[31:0]=0xAAAA,  write_en=1
        //     Puerto B: addr=0x104, wdata=i_wdata[63:32]=0xBBBB, write_en=1
        //     read_en = 0 (es store, no load)
        // =====================================================================
        $display("\n[TEST 7] Unit-stride store ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_store = 1; i_base_addr = 32'h100;
        i_wdata = {32'hDDDD, 32'hCCCC, 32'hBBBB, 32'hAAAA};
        i_phase = 2'b00; #1;
        chk32(o_mem_addr,    32'h100,  17);
        chk32(o_mem_addr_b,  32'h104,  18);
        chk1 (o_mem_write_en,   1'b1,  19);
        chk1 (o_mem_write_en_b, 1'b1,  20);
        chk32(o_mem_wdata,   32'hAAAA, 21);
        chk32(o_mem_wdata_b, 32'hBBBB, 22);
        chk1 (o_mem_read_en,    1'b0,  23);

        // =====================================================================
        // TEST 8: Unit-stride store, ACCESS_23
        //   fase 1, mismos i_wdata:
        //     Puerto A: wdata=i_wdata[95:64]=0xCCCC (elem_2)
        //     Puerto B: wdata=i_wdata[127:96]=0xDDDD (elem_3)
        // =====================================================================
        $display("\n[TEST 8] Unit-stride store ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,    32'h108,  24);
        chk32(o_mem_addr_b,  32'h10C,  25);
        chk32(o_mem_wdata,   32'hCCCC, 26);
        chk32(o_mem_wdata_b, 32'hDDDD, 27);

        // =====================================================================
        // TEST 9: VLM — mask load, ACCESS_01
        //   VLM: carga solo el byte 0 del elemento 0.
        //   Puerto A: read_en=1 (carga elem_0)
        //   Puerto B: read_en_b=0 (desactivado porque es mask_op)
        //   byte_en no se verifica en loads (solo importa en writes para
        //   el DCache); la reducción a 1 byte la hace la etapa MEM al
        //   ensamblar load_data = {120'b0, asm_lo[7:0]}.
        // =====================================================================
        $display("\n[TEST 9] VLM mask load ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_mask_op = 1;
        i_base_addr = 32'h400; i_phase = 2'b00; #1;
        chk1(o_mem_read_en,   1'b1, 28);
        chk1(o_mem_read_en_b, 1'b0, 29);

        // =====================================================================
        // TEST 10: VSM — mask store, ACCESS_01
        //   VSM: escribe solo el byte 0 del elemento 0 en el DCache.
        //   Puerto A: write_en=1, byte_en=4'b0001 (solo byte 0), wdata=elem_0
        //   Puerto B: write_en_b=0 (desactivado)
        // =====================================================================
        $display("\n[TEST 10] VSM mask store ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_store = 1; i_is_mask_op = 1;
        i_base_addr = 32'h400;
        i_wdata = {32'hDDDD, 32'hCCCC, 32'hBBBB, 32'hAAAA};
        i_phase = 2'b00; #1;
        chk1 (o_mem_write_en,   1'b1,     30);
        chk1 (o_mem_write_en_b, 1'b0,     31);
        chk32(o_mem_byte_en,    32'h1,    32); // 4'b0001 extendido a 32 bits
        chk32(o_mem_wdata,      32'hAAAA, 33);

        // =====================================================================
        // TEST 11: i_en=0 desactiva todos los enables
        //   Cuando i_en=0 el módulo desactiva todos los puertos del DCache,
        //   independientemente de i_is_load e i_is_store.
        //   Este caso ocurre cuando el pipeline escalar usa el DCache
        //   (prioridad sobre el vector) o cuando no hay instrucción válida.
        // =====================================================================
        $display("\n[TEST 11] i_en=0 desactiva salidas");
        i_en = 0; i_is_load = 1; i_is_store = 1; #1;
        chk1(o_mem_read_en,    1'b0, 34);
        chk1(o_mem_read_en_b,  1'b0, 35);
        chk1(o_mem_write_en,   1'b0, 36);
        chk1(o_mem_write_en_b, 1'b0, 37);

        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
