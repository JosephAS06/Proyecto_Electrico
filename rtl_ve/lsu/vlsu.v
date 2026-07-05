// =============================================================================
// Módulo: vlsu (Vector Load/Store Unit)
// Archivo: rtl_ve/lsu/vlsu.v
//
// Descripción:
//   Generador combinacional de accesos LSU (Load/Store Unit) vectorial.
//   Traduce una operación vectorial de memoria en señales de bus para el
//   DCache de doble puerto (puerto A y puerto B).
//
//   Un registro vectorial de 128 bits contiene 4 elementos de 32 bits.
//   El DCache tiene dos puertos independientes, por lo que pueden procesarse
//   2 elementos por ciclo. Para acceder a los 4 elementos se necesitan 2 ciclos:
//
//     i_phase = 2'b00 -> ACCESS_01: elem_0 -> puerto A,  elem_1 -> puerto B
//     i_phase = 2'b01 -> ACCESS_23: elem_2 -> puerto A,  elem_3 -> puerto B
//
//   La fase avanza entre ciclos: Execute instancia este módulo con fase 00,
//   y MEM lo instancia de nuevo con fase 01.
//   Este módulo no tiene estado interno — solo lógica combinacional.
//
// Modos de direccionamiento:
//   Unit-stride (default): accesos consecutivos con paso de 4 bytes.
//     addr_0 = base
//     addr_1 = base + 4
//     addr_2 = base + 8
//     addr_3 = base + 12
//
//   Strided (i_is_strided): el paso es i_stride (puede ser cualquier valor,
//   incluso negativo, incluso mayor que 4).
//     addr_0 = base
//     addr_1 = base + stride
//     addr_2 = base + stride*2
//     addr_3 = base + stride*3
//
//   Indexed (i_is_indexed): cada elemento tiene su propio offset almacenado
//   en el registro vectorial vs2 (i_offset_buf). Permite scatter/gather.
//     addr_0 = base + offset_buf[31:0]    (offset del elemento 0)
//     addr_1 = base + offset_buf[63:32]   (offset del elemento 1)
//     addr_2 = base + offset_buf[95:64]   (offset del elemento 2)
//     addr_3 = base + offset_buf[127:96]  (offset del elemento 3)
//
// Acceso de máscara (i_is_mask_op):
//   VLM y VSM acceden solo al primer byte del primer elemento (byte 0 de elem_0).
//   En ACCESS_01 (fase 00):
//     Puerto A: byte_en = 4'b0001 (solo byte 0)
//     Puerto B: desactivado (read_en_b=0, write_en_b=0)
//   ACCESS_23 se deshabilita completamente desde MEM (i_en=0).
//
// Control de habilitación:
//   i_en=0 desactiva todos los enables (read_en=0, write_en=0) en ambos puertos.
//   Esto se usa cuando hay conflicto de DCache o cuando la instrucción no es LSU.
//
// Flujo de datos — CARGA (i_is_load=1):
//
//   [addr_0, addr_1] --> [DCache puerto A/B] --> [datos leídos → rdata, rdata_b]
//
//   Los datos leídos del DCache se capturan en la etapa que llama a vlsu:
//   - ACCESS_01: Execute captura {i_mem_rdata_b, i_mem_rdata} en o_asm_lo.
//   - ACCESS_23: MEM combina asm_lo con {i_mem_rdata_b, i_mem_rdata} para
//     formar el vector completo de 128 bits.
//
// Flujo de datos — ALMACENAMIENTO (i_is_store=1):
//
//   i_wdata (vs3 empaquetado) se distribuye a los puertos:
//   - ACCESS_01: wdata_A = i_wdata[31:0]  (elem_0), wdata_B = i_wdata[63:32] (elem_1)
//   - ACCESS_23: wdata_A = i_wdata[95:64] (elem_2), wdata_B = i_wdata[127:96] (elem_3)
// =============================================================================

module vlsu (
    input  wire [1:0]   i_phase,      // 2'b00=ACCESS_01  2'b01=ACCESS_23
    input  wire         i_en,         // habilita cualquier acceso a memoria

    input  wire         i_is_load,
    input  wire         i_is_store,
    input  wire         i_is_mask_op, // solo accede al primer elemento de la fase
    input  wire         i_is_strided,
    input  wire         i_is_indexed,

    input  wire [31:0]  i_base_addr,
    input  wire [31:0]  i_stride,
    input  wire [127:0] i_offset_buf, // vs2: offsets para acceso indexado (un offset de 32b por elemento)

    input  wire [127:0] i_wdata,      // vs3: datos a escribir en stores (4 palabras de 32b empaquetadas)

    // Interfaz con DCache — puerto A (elemento par de cada fase)
    output reg  [31:0]  o_mem_addr,
    output reg          o_mem_read_en,
    output reg          o_mem_write_en,
    output reg  [31:0]  o_mem_wdata,
    output reg  [3:0]   o_mem_byte_en,

    // Interfaz con DCache — puerto B (elemento impar de cada fase)
    output reg  [31:0]  o_mem_addr_b,
    output reg          o_mem_read_en_b,
    output reg          o_mem_write_en_b,
    output reg  [31:0]  o_mem_wdata_b,
    output reg  [3:0]   o_mem_byte_en_b
);

    // -------------------------------------------------------------------------
    // Cálculo de direcciones para los 4 elementos
    //
    // step: salto en bytes entre elementos consecutivos.
    //   - Strided:      usa i_stride (puede ser cualquier valor, incluso negativo)
    //   - Unit-stride e indexed: 4 bytes (un word de 32b)
    //
    // Las cuatro direcciones se calculan siempre; el case del bloque always
    // selecciona cuáles enviar al DCache según la fase activa.
    // -------------------------------------------------------------------------

    wire [31:0] step = i_is_strided ? i_stride : 32'd4;

    wire [31:0] addr_0 = i_is_indexed ? (i_base_addr + i_offset_buf[31:0])   : i_base_addr;
    wire [31:0] addr_1 = i_is_indexed ? (i_base_addr + i_offset_buf[63:32])  : (i_base_addr + step);
    wire [31:0] addr_2 = i_is_indexed ? (i_base_addr + i_offset_buf[95:64])  : (i_base_addr + step * 2);
    wire [31:0] addr_3 = i_is_indexed ? (i_base_addr + i_offset_buf[127:96]) : (i_base_addr + step * 3);

    // -------------------------------------------------------------------------
    // Generación de señales de control según fase
    // -------------------------------------------------------------------------

    always @(*) begin
        // Defaults: ambos puertos desactivados (i_en=0 o fase inválida)
        o_mem_addr       = 32'b0;
        o_mem_read_en    = 1'b0;
        o_mem_write_en   = 1'b0;
        o_mem_wdata      = 32'b0;
        o_mem_byte_en    = 4'b1111;

        o_mem_addr_b     = 32'b0;
        o_mem_read_en_b  = 1'b0;
        o_mem_write_en_b = 1'b0;
        o_mem_wdata_b    = 32'b0;
        o_mem_byte_en_b  = 4'b1111;

        if (i_en) begin
            case (i_phase)

                // -------------------------------------------------------------
                // ACCESS_01: accede a elem_0 (puerto A) y elem_1 (puerto B)
                //
                // Con i_is_mask_op (VLM/VSM) solo se accede a elem_0:
                //   - Puerto B queda desactivado (read/write_en = 0)
                //   - byte_en del puerto A se reduce a 4'b0001 (solo byte 0)
                // -------------------------------------------------------------
                2'b00: begin
                    // Puerto A -> elem_0
                    o_mem_addr        = addr_0;
                    o_mem_read_en     = i_is_load;
                    o_mem_write_en    = i_is_store;
                    o_mem_wdata       = i_wdata[31:0];
                    o_mem_byte_en     = i_is_mask_op ? 4'b0001 : 4'b1111;

                    // Puerto B -> elem_1 (desactivado si mask_op)
                    o_mem_addr_b      = addr_1;
                    o_mem_read_en_b   = i_is_load  && !i_is_mask_op;
                    o_mem_write_en_b  = i_is_store && !i_is_mask_op;
                    o_mem_wdata_b     = i_wdata[63:32];
                    o_mem_byte_en_b   = 4'b1111;
                end

                // -------------------------------------------------------------
                // ACCESS_23: accede a elem_2 (puerto A) y elem_3 (puerto B)
                //
                // Ambos puertos siempre activos; mask_op solo afecta ACCESS_01.
                // -------------------------------------------------------------
                2'b01: begin
                    // Puerto A -> elem_2
                    o_mem_addr        = addr_2;
                    o_mem_read_en     = i_is_load;
                    o_mem_write_en    = i_is_store;
                    o_mem_wdata       = i_wdata[95:64];
                    o_mem_byte_en     = 4'b1111;

                    // Puerto B -> elem_3
                    o_mem_addr_b      = addr_3;
                    o_mem_read_en_b   = i_is_load;
                    o_mem_write_en_b  = i_is_store;
                    o_mem_wdata_b     = i_wdata[127:96];
                    o_mem_byte_en_b   = 4'b1111;
                end

                default: ; // fase inválida con i_en=1 -> puertos desactivados por defaults
            endcase
        end
    end

endmodule
