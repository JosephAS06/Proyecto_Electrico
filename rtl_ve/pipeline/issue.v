// =============================================================================
// Módulo: issue
// Archivo: rtl_ve/pipeline/issue.v
//
// Descripción:
//   Primera etapa registrada del pipeline vectorial. Recibe las señales
//   pre-decodificadas de Modified_DecodeUnit y los datos del VRF leídos
//   combinacionalmente, y los captura en registros de pipeline para
//   pasarlos a la etapa Execute en el siguiente ciclo.
//
//   La etapa Issue cumple dos funciones principales:
//   1. Proporcionar las direcciones de lectura al VRF (combinacional).
//   2. Capturar y propagar todos los campos de control y datos al pipeline.
//
// Manejo de stalls:
//   i_stall (dcache_stall):
//     El DCache está ocupado en MEM y Execute simultáneamente. Se congela
//     toda la etapa Issue (mantiene sus salidas sin cambiar) para que la
//     instrucción LSU en Execute pueda terminar su ACCESS_01 antes de que
//     llegue la siguiente instrucción LSU.
//
//   i_raw_stall (RAW hazard detectado por hazard_unit):
//     Se inserta una burbuja en la salida: o_valid=0 y o_is_lsu=0.
//     El productor (instrucción anterior) continúa avanzando por el pipeline
//     normalmente; el consumidor (instrucción actual) simplemente espera
//     un ciclo más antes de ser procesado.
//
// Expansión escalar->vector (modo VX):
//   Cuando i_is_vx=1, el operando escalar (un entero de 32 bits) se replica
//   4 veces para formar el vector de 128 bits:
//     o_vs2_data = {i_scalar, i_scalar, i_scalar, i_scalar}
//   Esto implementa instrucciones del tipo "vadd.vx vd, vs1, rs1" donde
//   rs1 es un registro del banco escalar RISC-V.
//
// Construcción del opcode ALU:
//   La etapa Issue construye el alu_op de 4 bits a partir de los campos
//   funct7 y funct3 de la instrucción RISC-V:
//     o_alu_op = {i_funct7[5], i_funct3}
//   El bit 5 de funct7 diferencia SUB de ADD y SRA de SRL, igual que en
//   el pipeline escalar RISC-V.
//
// Puertos de dirección del VRF (combinacionales, sin registro):
//   o_addr_a = i_rs1  -> lee vs1 (primer operando ALU)
//   o_addr_b = i_rs2  -> lee vs2 (segundo operando ALU / offsets indexed)
//   o_addr_c = i_rd   -> lee vs3 en stores (campo rd codifica vs3 en RVV)
//   o_addr_d = i_rs2  -> segunda lectura de vs2 para el VLSU en modo indexed
// =============================================================================

module issue (
    input         clk,
    input         rst,
    input         i_stall,      // DCache conflict — congela todos los registros de salida
    input         i_raw_stall,  // RAW hazard — inserta burbuja (o_valid=0)

    // -------------------------------------------------------------------------
    // Entradas desde Modified_DecodeUnit — camino ALU
    // -------------------------------------------------------------------------
    input         i_alu_valid,   // instrucción es una operación vectorial ALU
    input  [6:0]  i_funct7,      // campo funct7 de la instrucción (bit [5] → add/sub, srl/sra)
    input  [2:0]  i_funct3,      // campo funct3 de la instrucción (selecciona operación)
    input  [4:0]  i_rs1,         // dirección del registro fuente vs1
    input  [4:0]  i_rs2,         // dirección del registro fuente vs2
    input  [4:0]  i_rd,          // dirección del registro destino vd
    input         i_is_vx,       // modo vector-escalar: replica i_scalar en vs2
    input  [31:0] i_scalar,      // valor escalar (de un registro entero) para modo VX
    input  [127:0] i_vs1_data,   // datos leídos del VRF puerto A (vs1)
    input  [127:0] i_vs2_data,   // datos leídos del VRF puerto B (vs2)

    // -------------------------------------------------------------------------
    // Entradas desde Modified_DecodeUnit — camino LSU
    // -------------------------------------------------------------------------
    input         i_lsu_valid,   // instrucción es una operación de carga/almacenamiento
    input         i_is_load,     // es carga (vle32, vlse32, vluxei32, vlm)
    input         i_is_store,    // es almacenamiento (vse32, vsse32, vsuxei32, vsm)
    input         i_is_mask_op,  // es operación de máscara (vlm/vsm)
    input         i_is_strided,  // acceso con stride arbitrario (vlse32/vsse32)
    input         i_is_indexed,  // acceso indexado por vector (vluxei32/vsuxei32)
    input  [31:0] i_base_addr,   // dirección base leída del banco escalar (rs1)
    input  [31:0] i_stride,      // stride leído del banco escalar (rs2 en strided)
    input  [127:0] i_vs3_data,   // datos del registro fuente del store (VRF puerto C)
    input  [127:0] i_offset_data,// offsets para acceso indexado (VRF puerto D)

    // -------------------------------------------------------------------------
    // Puertos de dirección al VRF (combinacionales — no registrados)
    // -------------------------------------------------------------------------
    output [4:0]  o_addr_a,  // → vs1 (ALU fuente A)
    output [4:0]  o_addr_b,  // → vs2 (ALU fuente B / offsets)
    output [4:0]  o_addr_c,  // → vs3 stores (campo rd codifica vs3 en RVV)
    output [4:0]  o_addr_d,  // → vs2 offsets (segunda lectura para VLSU indexed)

    // -------------------------------------------------------------------------
    // Registro de pipeline Issue->Execute
    // -------------------------------------------------------------------------
    output reg        o_valid,      // hay una instrucción válida avanzando
    output reg        o_is_lsu,     // la instrucción es LSU (no ALU)
    output reg [3:0]  o_alu_op,     // opcode de la ALU = {funct7[5], funct3}
    output reg [4:0]  o_rd,         // registro destino vd
    output reg [127:0] o_vs1_data,  // datos de vs1 para la ALU
    output reg [127:0] o_vs2_data,  // datos de vs2 para la ALU (o escalar replicado)
    // Campos de control LSU propagados a Execute y MEM
    output reg        o_is_load,
    output reg        o_is_store,
    output reg        o_is_mask_op,
    output reg        o_is_strided,
    output reg        o_is_indexed,
    output reg [31:0] o_base_addr,
    output reg [31:0] o_stride,
    output reg [127:0] o_vs3_data,   // datos de vs3 para almacenamiento
    output reg [127:0] o_offset_buf  // offsets de vs2 para acceso indexado
);

    // Direcciones de lectura al VRF: combinacionales (no dependen del reloj)
    assign o_addr_a = i_rs1;
    assign o_addr_b = i_rs2;
    assign o_addr_c = i_rd;   // en stores, el campo "rd" de la instrucción codifica vs3
    assign o_addr_d = i_rs2;  // segunda lectura de rs2 para offsets en modo indexed

    always @(posedge clk) begin
        if (rst) begin
            o_valid      <= 1'b0;
            o_is_lsu     <= 1'b0;
            o_alu_op     <= 4'b0;
            o_rd         <= 5'b0;
            o_vs1_data   <= 128'b0;
            o_vs2_data   <= 128'b0;
            o_is_load    <= 1'b0;
            o_is_store   <= 1'b0;
            o_is_mask_op <= 1'b0;
            o_is_strided <= 1'b0;
            o_is_indexed <= 1'b0;
            o_base_addr  <= 32'b0;
            o_stride     <= 32'b0;
            o_vs3_data   <= 128'b0;
            o_offset_buf <= 128'b0;
        end else if (i_stall) begin
            // DCache freeze: mantiene todos los registros de salida sin cambios.
            // Ninguna instrucción nueva entra; la instrucción en Execute termina
            // su ACCESS_01 con el DCache libre.
        end else if (i_raw_stall) begin
            // RAW hazard: inserta burbuja para que el productor avance sin que
            // el consumidor entre al pipeline con datos incorrectos del VRF.
            o_valid  <= 1'b0;
            o_is_lsu <= 1'b0;
        end else begin
            // Operación normal: captura todos los campos de la instrucción actual
            o_valid      <= i_alu_valid || i_lsu_valid;
            o_is_lsu     <= i_lsu_valid;
            // Opcode ALU: bit de signo de funct7 más los 3 bits de funct3
            o_alu_op     <= {i_funct7[5], i_funct3};
            o_rd         <= i_rd;
            o_vs1_data   <= i_vs1_data;
            // Modo VX: si i_is_vx, replica el escalar de 32 bits en los 4 carriles
            o_vs2_data   <= i_is_vx ? {i_scalar, i_scalar, i_scalar, i_scalar}
                                    : i_vs2_data;
            o_is_load    <= i_is_load;
            o_is_store   <= i_is_store;
            o_is_mask_op <= i_is_mask_op;
            o_is_strided <= i_is_strided;
            o_is_indexed <= i_is_indexed;
            o_base_addr  <= i_base_addr;
            o_stride     <= i_stride;
            o_vs3_data   <= i_vs3_data;
            o_offset_buf <= i_offset_data;
        end
    end
endmodule
