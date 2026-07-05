// =============================================================================
// Módulo: mem
// Archivo: rtl_ve/pipeline/mem.v
//
// Descripción:
//   Tercera etapa del pipeline vectorial (MEM). Completa el acceso al DCache
//   para los elementos 2 y 3 del vector (ACCESS_23) y ensambla el resultado
//   completo de 128 bits para pasarlo a Writeback.
//
//   La etapa MEM opera un ciclo después de Execute. Mientras Execute hizo
//   ACCESS_01 (elementos 0 y 1), MEM hace ACCESS_23 (elementos 2 y 3)
//   usando el mismo VLSU con i_phase=2'b01.
//
// Flujo de datos — instrucción de CARGA (vle32, vlse32, etc.):
//
//   [Execute → MEM registro]
//    i_asm_lo = {elem_1, elem_0}   (capturado en Execute de i_mem_rdata_b/a)
//    i_base_addr, i_stride, etc.
//        │
//        |
//   [vlsu fase 2'b01] ──→ o_mem_addr/b, o_mem_read_en/b  (combinacional al DCache)
//        │
//   [DCache] ──→ i_mem_rdata (elem_2), i_mem_rdata_b (elem_3)
//        │
//   asm_full = {i_mem_rdata_b, i_mem_rdata, i_asm_lo}
//            = {elem_3, elem_2, elem_1, elem_0}  [127:0]
//        │
//        |
//   [Registro MEM→WB] → o_result = asm_full (o load_data si mask_op)
//
// Flujo de datos — instrucción de STORE (vse32, vsse32, etc.):
//
//   [Execute → MEM registro]
//    i_vs3_data = datos del vector a almacenar
//    i_base_addr, etc.
//        │
//        |
//   [vlsu fase 2'b01] ──→ o_mem_addr/b, o_mem_write_en/b, o_mem_wdata/b
//        │
//   [DCache] ← escribe elem_2 (puerto A) y elem_3 (puerto B)
//        │
//   o_result no se usa (stores no escriben al VRF; writeback lo descarta)
//
// Flujo de datos — instrucción ALU:
//
//   La instrucción ALU no genera ningún acceso al DCache en esta etapa
//   (i_is_lsu=0, vlsu desactivado). Solo pasa i_result (ALU) a o_result.
//
// Caso especial: Operación de Máscara (VLM):
//   Las instrucciones VLM (Vector Load Mask) acceden solo al primer byte
//   del primer elemento. El DCache solo se activa en ACCESS_01 (en Execute).
//   En MEM, el VLSU se desactiva completamente (i_en = i_valid && i_is_lsu
//   && !i_is_mask_op). El resultado se toma como {120'b0, elem_0[7:0]}.
//
//   load_data = i_is_mask_op ? {120'b0, i_asm_lo[7:0]} : asm_full
//
// Selección del resultado final:
//   Si es LSU load:   o_result = load_data (ensamblado de los 4 elementos)
//   Si es ALU:        o_result = i_result  (salida directa del alu_array en Execute)
//   Si es store:      o_result se propaga pero Writeback lo ignorará (o_is_store=1)
// =============================================================================

module mem (
    input         clk,
    input         rst,

    // -------------------------------------------------------------------------
    // Entradas desde Execute (registro Execute->MEM)
    // -------------------------------------------------------------------------
    input         i_valid,
    input         i_is_lsu,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,  // VLM/VSM: solo accede al byte 0 del elem_0
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_offset_buf,
    input  [127:0] i_vs3_data,   // datos para store (elementos 2 y 3 escritos aquí)
    input  [4:0]  i_rd,          // registro destino vd
    input  [127:0] i_result,     // resultado ALU (para instrucciones no-LSU)
    input  [63:0]  i_asm_lo,     // {elem_1, elem_0} capturados en Execute (ACCESS_01)

    // Datos leídos del DCache en este ciclo (ACCESS_23, combinacional)
    input  [31:0]  i_mem_rdata,   // dato del elemento 2 (puerto A)
    input  [31:0]  i_mem_rdata_b, // dato del elemento 3 (puerto B)

    // -------------------------------------------------------------------------
    // Registro de pipeline MEM->Writeback
    // -------------------------------------------------------------------------
    output reg        o_valid,
    output reg        o_is_store,  // Writeback usa este bit para suprimir escritura al VRF
    output reg [4:0]  o_rd,
    output reg [127:0] o_result,   // resultado final (128 bits) para el VRF

    // -------------------------------------------------------------------------
    // Interfaz al DCache para ACCESS_23 (señales combinacionales del VLSU)
    // -------------------------------------------------------------------------
    output wire [31:0] o_mem_addr,
    output wire        o_mem_read_en,
    output wire        o_mem_write_en,
    output wire [31:0] o_mem_wdata,
    output wire [3:0]  o_mem_byte_en,
    output wire [31:0] o_mem_addr_b,
    output wire        o_mem_read_en_b,
    output wire        o_mem_write_en_b,
    output wire [31:0] o_mem_wdata_b,
    output wire [3:0]  o_mem_byte_en_b
);

    // VLSU fase ACCESS_23: genera accesos al DCache para elementos 2 y 3.
    // Se desactiva para instrucciones de máscara (VLM/VSM solo usan ACCESS_01).
    vlsu lsu_access23 (
        .i_phase         (2'b01),                              // fase 1: elem_2 y elem_3
        .i_en            (i_valid && i_is_lsu && !i_is_mask_op), // desactivado para VLM/VSM
        .i_is_load       (i_is_load),
        .i_is_store      (i_is_store),
        .i_is_mask_op    (i_is_mask_op),
        .i_is_strided    (i_is_strided),
        .i_is_indexed    (i_is_indexed),
        .i_base_addr     (i_base_addr),
        .i_stride        (i_stride),
        .i_offset_buf    (i_offset_buf),
        .i_wdata         (i_vs3_data),
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

    // Ensamblado completo de los 4 elementos (ACCESS_01 + ACCESS_23):
    // asm_lo[63:0]  = {elem_1, elem_0}  (capturado en Execute)
    // i_mem_rdata   = elem_2             (leído del DCache en este ciclo)
    // i_mem_rdata_b = elem_3             (leído del DCache en este ciclo)
    // Resultado empaquetado: bits [31:0]=elem_0, [63:32]=elem_1, [95:64]=elem_2, [127:96]=elem_3
    wire [127:0] asm_full  = {i_mem_rdata_b, i_mem_rdata, i_asm_lo};

    // VLM usa solo el byte 0 del primer elemento (i_asm_lo[7:0]);
    // los 120 bits superiores se rellenan con ceros.
    wire [127:0] load_data = i_is_mask_op ? {120'b0, i_asm_lo[7:0]} : asm_full;

    always @(posedge clk) begin
        if (rst) begin
            o_valid    <= 1'b0;
            o_is_store <= 1'b0;
            o_rd       <= 5'b0;
            o_result   <= 128'b0;
        end else begin
            o_valid    <= i_valid;
            o_is_store <= i_is_store;
            o_rd       <= i_rd;
            // Selección del resultado:
            //   LSU load -> load_data (ensamblado de 4 elementos del DCache)
            //   ALU      -> i_result  (salida del alu_array, propagada desde Execute)
            //   LSU store-> irrelevante (Writeback descarta si o_is_store=1)
            o_result   <= (i_is_lsu && i_is_load) ? load_data : i_result;
        end
    end
endmodule
