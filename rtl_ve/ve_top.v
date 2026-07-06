// =============================================================================
// Módulo: ve_top (Vector Extension Top)
// Archivo: rtl_ve/ve_top.v
//
// Descripción:
//   Módulo de nivel superior de la extensión vectorial. Integra todos los
//   componentes del pipeline vectorial de 4 etapas:
//
//     Issue -> Execute -> MEM -> Writeback
//
//   y el banco de registros vectoriales (VRF). Recibe instrucciones
//   pre-decodificadas desde Modified_DecodeUnit y accede al DCache externo
//   a través de una interfaz de doble puerto.
//
//
// Banco de Registros Vectoriales (VRF):
//   32 registros de 128 bits, con 4 puertos de lectura y 1 de escritura.
//   Las lecturas son combinacionales; la escritura es sincrónica (en WB).
//   Los 4 puertos atienden: vs1 (ALU), vs2 (ALU/indexed), vs3 (stores), vs2 offset (indexed).
//
// Lógica de Stall:
//   Hay dos fuentes de stall, combinadas en la señal "stall" que se expone
//   al exterior como o_stall (freezes el pipeline escalar):
//
//   1. dcache_stall (conflicto de DCache):
//      Se activa cuando Execute Y MEM tienen instrucciones LSU al mismo tiempo
//      (s1_is_lsu && s2_is_lsu). Ambas etapas quieren usar el DCache; se
//      congela la entrada de Execute y se inserta burbuja en MEM.
//
//   2. raw_stall (hazard RAW):
//      La hazard_unit detecta que una instrucción entrante necesita leer un
//      registro que todavía está siendo producido en el pipeline. Issue
//      inserta una burbuja; el productor continúa avanzando normalmente.
//
// Multiplexor del DCache:
//   Las salidas del DCache se seleccionan entre Execute (ACCESS_01) y MEM
//   (ACCESS_23) según cuál tenga una instrucción LSU activa. La señal sel_mem
//   determina cuál instancia de VLSU controla el bus:
//
//     sel_mem = s2_is_lsu && !s2_is_mask_op
//
//   MEM tiene prioridad. El stall garantiza que nunca estén activos al mismo
//   tiempo, así que el mux es puramente informativo (nunca hay colisión real).
//
// Interfaz con el DCache (doble puerto):
//   Puerto A: usado por Execute (ACCESS_01, elem_0) y MEM (ACCESS_23, elem_2),
//             también compartido con la unidad escalar cuando no hay acceso vectorial.
//   Puerto B: usado por Execute (ACCESS_01, elem_1) y MEM (ACCESS_23, elem_3).
//             Exclusivo del pipeline vectorial.
//
// Flujo de datos completo (vle32 como ejemplo):
//
//   Ciclo 1 (Issue):
//     - i_rs1 -> o_addr_a al VRF (lectura del registro con base_addr)
//     - Datos propagados al registro Issue→Execute
//
//   Ciclo 2 (Execute):
//     - VLSU fase 00 genera addr_0, addr_1 -> DCache
//     - DCache devuelve rdata[0], rdata[1]
//     - Se captura {rdata[1], rdata[0]} en o_asm_lo -> registro EX->MEM
//
//   Ciclo 3 (MEM):
//     - VLSU fase 01 genera addr_2, addr_3 -> DCache
//     - DCache devuelve rdata[2], rdata[3]
//     - asm_full = {rdata[3], rdata[2], asm_lo} -> registro MEM→WB
//
//   Ciclo 4 (Writeback, combinacional):
//     - o_we=1 -> VRF escribe asm_full en el registro vd
//
// Señal o_stall hacia el procesador escalar:
//   Mientras o_stall=1, el pipeline escalar (FU y DU) queda congelado.
//   Esto da tiempo al pipeline vectorial para completar su instrucción
//   antes de que el decode decodifique la siguiente instrucción.
// =============================================================================

module ve_top (
    input         clk,
    input         rst,

    // -------------------------------------------------------------------------
    // Camino ALU — señales pre-decodificadas desde Modified_DecodeUnit
    // -------------------------------------------------------------------------
    input         i_alu_valid,   // instrucción vectorial ALU válida
    input  [6:0]  i_funct7,      // campo funct7 de la instrucción
    input  [2:0]  i_funct3,      // campo funct3 de la instrucción
    input  [4:0]  i_rs1,         // dirección fuente vs1
    input  [4:0]  i_rs2,         // dirección fuente vs2
    input  [4:0]  i_rd,          // dirección destino vd
    input         i_is_vx,       // modo vector-escalar (replica i_scalar)
    input  [31:0] i_scalar,      // valor escalar (registro entero del pipeline escalar)

    // -------------------------------------------------------------------------
    // Camino LSU — señales pre-decodificadas desde Modified_DecodeUnit
    // -------------------------------------------------------------------------
    input         i_lsu_valid,   // instrucción vectorial LSU válida
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,   // dirección base (de un registro escalar)
    input  [31:0] i_stride,      // stride (de un registro escalar)

    // Señal de stall hacia el decodificador del pipeline escalar
    output        o_stall,

    // -------------------------------------------------------------------------
    // Interfaz con DCache externo — Puerto A
    // -------------------------------------------------------------------------
    output [31:0] o_mem_addr,
    output        o_mem_read_en,
    input  [31:0] i_mem_rdata,
    output        o_mem_write_en,
    output [31:0] o_mem_wdata,
    output [3:0]  o_mem_byte_en,

    // -------------------------------------------------------------------------
    // Interfaz con DCache externo — Puerto B
    // -------------------------------------------------------------------------
    output [31:0] o_mem_addr_b,
    output        o_mem_read_en_b,
    input  [31:0] i_mem_rdata_b,
    output        o_mem_write_en_b,
    output [31:0] o_mem_wdata_b,
    output [3:0]  o_mem_byte_en_b
);

    // =========================================================================
    // Banco de registros vectoriales (VRF)
    // =========================================================================
    wire [4:0]   addr_a, addr_b, addr_c, addr_d;
    wire [127:0] data_a, data_b, data_c, data_d;

    wire        wb_we;
    wire [4:0]  wb_addr_w;
    wire [127:0] wb_data_in;

    vregisters vregfile (
        .clk     (clk),
        .rst     (rst),
        .we      (wb_we),
        .addr_w  (wb_addr_w),
        .data_in (wb_data_in),
        .addr_a  (addr_a),   // lectura vs1 (etapa Issue)
        .addr_b  (addr_b),   // lectura vs2 (etapa Issue)
        .addr_c  (addr_c),   // lectura vs3 para stores (etapa Issue)
        .addr_d  (addr_d),   // lectura offsets indexed (etapa Issue)
        .data_a  (data_a),
        .data_b  (data_b),
        .data_c  (data_c),
        .data_d  (data_d)
    );

    // =========================================================================
    // Señales de interconexión entre etapas del pipeline
    // Convención: s1_* = salidas de Issue (Issue->Execute)
    //             s2_* = salidas de Execute (Execute->MEM)
    //             s3_* = salidas de MEM (MEM->WB)
    // =========================================================================
    wire        s1_valid,   s2_valid;
    wire        s1_is_lsu,  s2_is_lsu;
    wire [3:0]  s1_alu_op;
    wire [4:0]  s1_rd,      s2_rd;
    wire [127:0] s1_vs1_data, s1_vs2_data;
    wire [127:0] s1_result,   s2_result;
    // Campos LSU de la etapa s1 (Issue->Execute)
    wire        s1_is_load,    s1_is_store,    s1_is_mask_op;
    wire        s1_is_strided, s1_is_indexed;
    wire [31:0] s1_base_addr,  s1_stride;
    wire [127:0] s1_vs3_data,  s1_offset_buf;
    // Campos LSU de la etapa s2 (Execute->MEM)
    wire        s2_is_load,    s2_is_store,    s2_is_mask_op;
    wire        s2_is_strided, s2_is_indexed;
    wire [31:0] s2_base_addr,  s2_stride;
    wire [127:0] s2_vs3_data,  s2_offset_buf;
    wire [63:0]  s2_asm_lo;    // {elem_1, elem_0} capturados en Execute (ACCESS_01)
    // Señales de la etapa s3 (MEM→WB)
    wire        s3_valid, s3_is_store;
    wire [4:0]  s3_rd;
    wire [127:0] s3_result;

    // =========================================================================
    // Lógica de stall
    //
    // dcache_stall: Execute y MEM tienen instrucciones LSU simultáneamente ->
    //   el DCache tiene un único bus compartido; se congela Issue para que
    //   la instrucción en Execute pueda completar su ACCESS_01 sin competencia.
    //
    // raw_stall: instrucción entrante lee un registro que está siendo producido
    //   en el pipeline -> Issue inserta burbuja, el productor avanza normalmente.
    // =========================================================================
    wire dcache_stall = s1_is_lsu && s2_is_lsu;
    wire raw_stall;
    wire stall = dcache_stall || raw_stall;
    assign o_stall = stall;  // expone el stall al pipeline escalar para freezearlo

    hazard_unit hu (
        .i_valid      (i_alu_valid || i_lsu_valid),
        // Para instrucciones LSU, i_rs1 es un registro escalar (base addr), no vectorial.
        // Pasar 5'b0 evita falsos hazards contra registros vectoriales en el pipeline.
        .i_rs1        (i_lsu_valid ? 5'b0 : i_rs1),
        .i_rs2        (i_rs2),
        .i_is_store   (i_is_store),
        .i_rd         (i_rd),
        // Observa el estado de las 3 instrucciones más recientes en el pipeline
        .i_s1_valid   (s1_valid),
        .i_s1_rd      (s1_rd),
        .i_s1_is_store(s1_is_store),
        .i_s2_valid   (s2_valid),
        .i_s2_rd      (s2_rd),
        .i_s2_is_store(s2_is_store),
        .i_s2_is_load (s2_is_load),
        .i_s3_valid   (s3_valid),
        .i_s3_rd      (s3_rd),
        .i_s3_is_store(s3_is_store),
        .o_raw_stall  (raw_stall)
    );

    // =========================================================================
    // Mux de salidas del DCache: Execute (ACCESS_01) o MEM (ACCESS_23)
    //
    // sel_mem=1: MEM tiene una instrucción LSU no-mask -> MEM controla el DCache
    // sel_mem=0: Execute controla el DCache (ACCESS_01 activo)
    //
    // El dcache_stall garantiza que estas dos condiciones sean mutuamente
    // exclusivas: nunca habrá ACCESS_01 y ACCESS_23 al mismo ciclo.
    // =========================================================================
    wire [31:0] exe_mem_addr,       mem_mem_addr;
    wire        exe_mem_read_en,    mem_mem_read_en;
    wire        exe_mem_write_en,   mem_mem_write_en;
    wire [31:0] exe_mem_wdata,      mem_mem_wdata;
    wire [3:0]  exe_mem_byte_en,    mem_mem_byte_en;
    wire [31:0] exe_mem_addr_b,     mem_mem_addr_b;
    wire        exe_mem_read_en_b,  mem_mem_read_en_b;
    wire        exe_mem_write_en_b, mem_mem_write_en_b;
    wire [31:0] exe_mem_wdata_b,    mem_mem_wdata_b;
    wire [3:0]  exe_mem_byte_en_b,  mem_mem_byte_en_b;

    // MEM tiene prioridad cuando tiene una instrucción LSU no-mask activa
    wire sel_mem = s2_is_lsu && !s2_is_mask_op;

    assign o_mem_addr       = sel_mem ? mem_mem_addr       : exe_mem_addr;
    assign o_mem_read_en    = sel_mem ? mem_mem_read_en    : exe_mem_read_en;
    assign o_mem_write_en   = sel_mem ? mem_mem_write_en   : exe_mem_write_en;
    assign o_mem_wdata      = sel_mem ? mem_mem_wdata      : exe_mem_wdata;
    assign o_mem_byte_en    = sel_mem ? mem_mem_byte_en    : exe_mem_byte_en;
    assign o_mem_addr_b     = sel_mem ? mem_mem_addr_b     : exe_mem_addr_b;
    assign o_mem_read_en_b  = sel_mem ? mem_mem_read_en_b  : exe_mem_read_en_b;
    assign o_mem_write_en_b = sel_mem ? mem_mem_write_en_b : exe_mem_write_en_b;
    assign o_mem_wdata_b    = sel_mem ? mem_mem_wdata_b    : exe_mem_wdata_b;
    assign o_mem_byte_en_b  = sel_mem ? mem_mem_byte_en_b  : exe_mem_byte_en_b;

    // =========================================================================
    // Pipeline vectorial: Issue -> Execute -> MEM -> Writeback
    // =========================================================================

    // -------------------------------------------------------------------------
    // Forwarding vectorial: s2 (ALU no-load) y s3 -> entrada de Issue
    //
    // Reglas:
    //  - s2 ALU (no-load, no-store): resultado completo disponible -> forward
    //  - s2 load: solo ACCESS_01 completo en s2; ACCESS_23 llega en s3 -> no forward
    //  - s3 cualquier resultado: completo -> forward
    //  - Las instrucciones LSU usan i_rs1 como dirección escalar, no vectorial;
    //    el guard !i_lsu_valid evita falsas coincidencias con registros vectoriales.
    // -------------------------------------------------------------------------
    wire [127:0] fwd_vs1 =
        (!i_lsu_valid && s2_valid && !s2_is_store && !s2_is_load && s2_rd != 5'b0 && s2_rd == i_rs1) ? s2_result :
        (!i_lsu_valid && s3_valid && !s3_is_store && s3_rd != 5'b0 && s3_rd == i_rs1) ? s3_result :
        data_a;

    wire [127:0] fwd_vs2 =
        (!i_lsu_valid && s2_valid && !s2_is_store && !s2_is_load && s2_rd != 5'b0 && s2_rd == i_rs2) ? s2_result :
        (!i_lsu_valid && s3_valid && !s3_is_store && s3_rd != 5'b0 && s3_rd == i_rs2) ? s3_result :
        data_b;

    // vs3 es siempre un registro vectorial (presente solo en stores vectoriales)
    wire [127:0] fwd_vs3 =
        (i_is_store && s2_valid && !s2_is_store && !s2_is_load && s2_rd != 5'b0 && s2_rd == i_rd) ? s2_result :
        (i_is_store && s3_valid && !s3_is_store && s3_rd != 5'b0 && s3_rd == i_rd) ? s3_result :
        data_c;

    // Etapa 1: Issue — captura la instrucción y lee el VRF
    issue stage1 (
        .clk          (clk),
        .rst          (rst),
        .i_stall      (dcache_stall), // congela solo por conflicto de DCache
        .i_raw_stall  (raw_stall),    // inserta burbuja por hazard RAW
        .i_alu_valid  (i_alu_valid),
        .i_funct7     (i_funct7),
        .i_funct3     (i_funct3),
        .i_rs1        (i_rs1),
        .i_rs2        (i_rs2),
        .i_rd         (i_rd),
        .i_is_vx      (i_is_vx),
        .i_scalar     (i_scalar),
        .i_vs1_data   (fwd_vs1),      // vs1 con forwarding desde s2/s3
        .i_vs2_data   (fwd_vs2),      // vs2 con forwarding desde s2/s3
        .i_lsu_valid  (i_lsu_valid),
        .i_is_load    (i_is_load),
        .i_is_store   (i_is_store),
        .i_is_mask_op (i_is_mask_op),
        .i_is_strided (i_is_strided),
        .i_is_indexed (i_is_indexed),
        .i_base_addr  (i_base_addr),
        .i_stride     (i_stride),
        .i_vs3_data   (fwd_vs3),      // vs3 con forwarding desde s2/s3 (para stores)
        .i_offset_data(data_d),       // offsets indexed (VRF puerto D)
        // Direcciones de lectura al VRF (combinacionales)
        .o_addr_a     (addr_a),
        .o_addr_b     (addr_b),
        .o_addr_c     (addr_c),
        .o_addr_d     (addr_d),
        // Registro Issue→Execute
        .o_valid      (s1_valid),
        .o_is_lsu     (s1_is_lsu),
        .o_alu_op     (s1_alu_op),
        .o_rd         (s1_rd),
        .o_vs1_data   (s1_vs1_data),
        .o_vs2_data   (s1_vs2_data),
        .o_is_load    (s1_is_load),
        .o_is_store   (s1_is_store),
        .o_is_mask_op (s1_is_mask_op),
        .o_is_strided (s1_is_strided),
        .o_is_indexed (s1_is_indexed),
        .o_base_addr  (s1_base_addr),
        .o_stride     (s1_stride),
        .o_vs3_data   (s1_vs3_data),
        .o_offset_buf (s1_offset_buf)
    );

    // Etapa 2: Execute — opera la ALU y realiza ACCESS_01 del DCache
    execute stage2 (
        .clk          (clk),
        .rst          (rst),
        .i_stall      (dcache_stall), // congela si MEM también tiene LSU
        .i_valid      (s1_valid),
        .i_is_lsu     (s1_is_lsu),
        .i_alu_op     (s1_alu_op),
        .i_rd         (s1_rd),
        .i_vs1_data   (s1_vs1_data),
        .i_vs2_data   (s1_vs2_data),
        .i_is_load    (s1_is_load),
        .i_is_store   (s1_is_store),
        .i_is_mask_op (s1_is_mask_op),
        .i_is_strided (s1_is_strided),
        .i_is_indexed (s1_is_indexed),
        .i_base_addr  (s1_base_addr),
        .i_stride     (s1_stride),
        .i_vs3_data   (s1_vs3_data),
        .i_offset_buf (s1_offset_buf),
        .i_mem_rdata      (i_mem_rdata),    // rdata elem_0 del DCache (ACCESS_01)
        .i_mem_rdata_b    (i_mem_rdata_b),  // rdata elem_1 del DCache (ACCESS_01)
        // Señales de bus al DCache (ACCESS_01)
        .o_mem_addr       (exe_mem_addr),
        .o_mem_read_en    (exe_mem_read_en),
        .o_mem_write_en   (exe_mem_write_en),
        .o_mem_wdata      (exe_mem_wdata),
        .o_mem_byte_en    (exe_mem_byte_en),
        .o_mem_addr_b     (exe_mem_addr_b),
        .o_mem_read_en_b  (exe_mem_read_en_b),
        .o_mem_write_en_b (exe_mem_write_en_b),
        .o_mem_wdata_b    (exe_mem_wdata_b),
        .o_mem_byte_en_b  (exe_mem_byte_en_b),
        // Registro Execute->MEM
        .o_valid          (s2_valid),
        .o_is_lsu     (s2_is_lsu),
        .o_rd         (s2_rd),
        .o_result     (s2_result),
        .o_is_load    (s2_is_load),
        .o_is_store   (s2_is_store),
        .o_is_mask_op (s2_is_mask_op),
        .o_is_strided (s2_is_strided),
        .o_is_indexed (s2_is_indexed),
        .o_base_addr  (s2_base_addr),
        .o_stride     (s2_stride),
        .o_vs3_data   (s2_vs3_data),
        .o_offset_buf (s2_offset_buf),
        .o_asm_lo     (s2_asm_lo)           // {elem_1, elem_0} capturados de ACCESS_01
    );

    // Etapa 3: MEM — completa ACCESS_23 del DCache y ensambla el vector completo
    mem stage3 (
        .clk              (clk),
        .rst              (rst),
        .i_valid          (s2_valid),
        .i_is_lsu         (s2_is_lsu),
        .i_is_load        (s2_is_load),
        .i_is_store       (s2_is_store),
        .i_is_mask_op     (s2_is_mask_op),
        .i_is_strided     (s2_is_strided),
        .i_is_indexed     (s2_is_indexed),
        .i_base_addr      (s2_base_addr),
        .i_stride         (s2_stride),
        .i_offset_buf     (s2_offset_buf),
        .i_vs3_data       (s2_vs3_data),
        .i_rd             (s2_rd),
        .i_result         (s2_result),
        .i_asm_lo         (s2_asm_lo),       // {elem_1, elem_0} de Execute
        .i_mem_rdata      (i_mem_rdata),     // rdata elem_2 del DCache (ACCESS_23)
        .i_mem_rdata_b    (i_mem_rdata_b),   // rdata elem_3 del DCache (ACCESS_23)
        // Registro MEM->WB
        .o_valid          (s3_valid),
        .o_is_store       (s3_is_store),
        .o_rd             (s3_rd),
        .o_result         (s3_result),
        // Señales de bus al DCache (ACCESS_23)
        .o_mem_addr       (mem_mem_addr),
        .o_mem_read_en    (mem_mem_read_en),
        .o_mem_write_en   (mem_mem_write_en),
        .o_mem_wdata      (mem_mem_wdata),
        .o_mem_byte_en    (mem_mem_byte_en),
        .o_mem_addr_b     (mem_mem_addr_b),
        .o_mem_read_en_b  (mem_mem_read_en_b),
        .o_mem_write_en_b (mem_mem_write_en_b),
        .o_mem_wdata_b    (mem_mem_wdata_b),
        .o_mem_byte_en_b  (mem_mem_byte_en_b)
    );

    // Etapa 4: Writeback — escribe el resultado al VRF (combinacional)
    writeback stage4 (
        .i_valid    (s3_valid),
        .i_is_store (s3_is_store),
        .i_rd       (s3_rd),
        .i_result   (s3_result),
        .o_we       (wb_we),       // habilitación de escritura al VRF
        .o_addr_w   (wb_addr_w),   // dirección de escritura
        .o_data_in  (wb_data_in)   // dato a escribir
    );

endmodule
