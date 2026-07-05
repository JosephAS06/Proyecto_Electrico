// =============================================================================
// Módulo: execute
// Archivo: rtl_ve/pipeline/execute.v
//
// Descripción:
//   Segunda etapa del pipeline vectorial (Execute). Es la etapa más compleja
//   porque realiza dos cosas simultáneamente en el mismo ciclo:
//
//   1. CÁLCULO ALU: instancia alu_array para operar sobre los vectores vs1 y
//      vs2. El resultado de 128 bits se captura al final del ciclo.
//
//   2. ACCESS_01: para instrucciones LSU, instancia vlsu con i_phase=2'b00
//      para generar las señales del DCache para los elementos 0 y 1 del
//      vector (ACCESS_01). Los datos leídos (i_mem_rdata, i_mem_rdata_b)
//      llegan combinacionalmente desde el DCache en el mismo ciclo y se
//      capturan en o_asm_lo al final del ciclo.
//
// Manejo del stall (i_stall = dcache_stall):
//   Ocurre cuando hay una instrucción LSU en Execute Y otra en MEM al mismo
//   tiempo — ambas quieren usar el DCache. En este caso:
//   - El VLSU de Access_01 se desactiva (i_en = i_is_lsu && !i_stall).
//   - La instrucción que entró a Execute espera un ciclo (burbuja en MEM).
//   - El registro de salida pone o_valid=0 para que MEM no procese basura.
//
// Nota sobre rdata y timing:
//   Las lecturas del DCache son combinacionales: i_mem_rdata refleja el dato
//   en el mismo ciclo en que se aplica la dirección. Por eso alu_out y
//   {i_mem_rdata_b, i_mem_rdata} se capturan al mismo tiempo en el flanco.
// =============================================================================

module execute (
    input         clk,
    input         rst,
    // i_stall=1 indica conflicto de DCache: Execute debe insertar burbuja en MEM
    // y no activar su propio acceso al DCache este ciclo
    input         i_stall,

    // -------------------------------------------------------------------------
    // Entradas desde Issue (pipeline Issue→Execute)
    // -------------------------------------------------------------------------
    input         i_valid,       // hay instrucción válida
    input         i_is_lsu,      // es instrucción LSU
    input  [3:0]  i_alu_op,      // código de operación para alu_array
    input  [4:0]  i_rd,          // registro destino vd
    input  [127:0] i_vs1_data,   // primer operando vectorial (fuente ALU A)
    input  [127:0] i_vs2_data,   // segundo operando vectorial (fuente ALU B)
    // Campos LSU propagados desde Issue
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_vs3_data,   // datos a escribir en stores
    input  [127:0] i_offset_buf, // offsets para acceso indexado
    // Datos leídos del DCache en este mismo ciclo (ACCESS_01, combinacional)
    input  [31:0] i_mem_rdata,   // dato del elemento 0 (puerto A del DCache)
    input  [31:0] i_mem_rdata_b, // dato del elemento 1 (puerto B del DCache)

    // -------------------------------------------------------------------------
    // Registro de pipeline Execute->MEM
    // -------------------------------------------------------------------------
    output reg        o_valid,
    output reg        o_is_lsu,
    output reg [4:0]  o_rd,
    output reg [127:0] o_result,    // resultado de la ALU (si ALU) o no usado (si LSU)
    // Campos LSU propagados a MEM
    output reg        o_is_load,
    output reg        o_is_store,
    output reg        o_is_mask_op,
    output reg        o_is_strided,
    output reg        o_is_indexed,
    output reg [31:0] o_base_addr,
    output reg [31:0] o_stride,
    output reg [127:0] o_vs3_data,
    output reg [127:0] o_offset_buf,
    output reg [63:0]  o_asm_lo,   // {elem_1, elem_0} capturados del DCache en ACCESS_01

    // -------------------------------------------------------------------------
    // Interfaz al DCache para ACCESS_01 (señales combinacionales del VLSU)
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

    // Resultado de la ALU en paralelo para los 4 elementos del vector
    wire [127:0] alu_out;

    alu_array #(.SIZE(32), .N(4)) alu (
        .alu_op (i_alu_op),
        .in_a   (i_vs1_data),
        .in_b   (i_vs2_data),
        .out    (alu_out)
    );

    // VLSU fase ACCESS_01: genera señales del DCache para elementos 0 y 1.
    // Se desactiva (i_en=0) cuando hay conflicto de DCache (i_stall=1), ya que
    // en ese caso MEM ya está usando el bus DCache en ese ciclo.
    vlsu lsu_access01 (
        .i_phase         (2'b00),               // fase 0: accede a elem_0 y elem_1
        .i_en            (i_is_lsu && !i_stall), // desactivado durante stall
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

    always @(posedge clk) begin
        if (rst) begin
            o_valid      <= 1'b0;
            o_is_lsu     <= 1'b0;
            o_rd         <= 5'b0;
            o_result     <= 128'b0;
            o_is_load    <= 1'b0;
            o_is_store   <= 1'b0;
            o_is_mask_op <= 1'b0;
            o_is_strided <= 1'b0;
            o_is_indexed <= 1'b0;
            o_base_addr  <= 32'b0;
            o_stride     <= 32'b0;
            o_vs3_data   <= 128'b0;
            o_offset_buf <= 128'b0;
            o_asm_lo     <= 64'b0;
        end else if (i_stall) begin
            // Conflicto de DCache: insertar burbuja en MEM.
            // La instrucción LSU esperará otro ciclo antes de activar ACCESS_01.
            o_valid  <= 1'b0;
            o_is_lsu <= 1'b0;
        end else begin
            o_valid      <= i_valid;
            o_is_lsu     <= i_is_lsu;
            o_rd         <= i_rd;
            // Para instrucciones ALU: o_result lleva la salida del alu_array.
            // Para instrucciones LSU: o_result no se usa (MEM usará o_asm_lo + rdata propio).
            o_result     <= alu_out;
            o_is_load    <= i_is_load;
            o_is_store   <= i_is_store;
            o_is_mask_op <= i_is_mask_op;
            o_is_strided <= i_is_strided;
            o_is_indexed <= i_is_indexed;
            o_base_addr  <= i_base_addr;
            o_stride     <= i_stride;
            o_vs3_data   <= i_vs3_data;
            o_offset_buf <= i_offset_buf;
            // Captura los dos elementos leídos en ACCESS_01 en un campo de 64 bits.
            // MEM combinará estos 64 bits con los otros 64 de su propio ACCESS_23.
            o_asm_lo     <= {i_mem_rdata_b, i_mem_rdata};
        end
    end
endmodule
