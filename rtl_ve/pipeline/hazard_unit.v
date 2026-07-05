// =============================================================================
// Módulo: hazard_unit
// Archivo: rtl_ve/pipeline/hazard_unit.v
//
// Descripción:
//   Unidad de detección de hazards RAW (Read After Write) para el pipeline
//   vectorial de 4 etapas: Issue -> Execute -> MEM -> Writeback.
//
//   Un hazard RAW ocurre cuando una instrucción necesita leer un registro
//   que todavía no ha sido escrito por una instrucción anterior que está
//   avanzando por el pipeline. Como el VRF no implementa forwarding, la
//   solución es insertar burbujas (stalls) hasta que el productor complete
//   su etapa WB y escriba el resultado.
//
// Ventana de peligro:
//   La hazard unit observa las 3 instrucciones más recientes en el pipeline
//   (s1, s2, s3 = Issue→Execute, Execute→MEM, MEM→WB respectivamente).
//   Si cualquiera de ellas escribe un registro que la instrucción entrante
//   necesita leer, se activa o_raw_stall.
//
//   Pipeline temporal (cada columna = 1 ciclo):
//
//     ciclo:    T      T+1     T+2     T+3
//     s1_rd:  [instr en Issue]
//     s2_rd:          [en Execute]
//     s3_rd:                  [en MEM]
//     WB:                             [escribe VRF]
//
//   La instrucción entrante (la que se está decodificando) lee VRF en T.
//   Para que la lectura sea correcta, el productor debe haber escrito en WB,
//   es decir, debe estar más atrás de s3. Si está en s1, s2 o s3, hay hazard.
//
// Detección para stores (campo i_rd / i_is_store):
//   En instrucciones store (vse32, vsse32, vsuxei32), el campo "rd" de la
//   instrucción codifica vs3 (el registro que se va a escribir en memoria).
//   Si alguna instrucción en el pipeline escribe ese registro, también se
//   debe esperar — de lo contrario, el store leería un valor obsoleto del VRF.
//
// Señales de entrada:
//   i_valid       — la instrucción entrante es válida (no es una burbuja)
//   i_rs1, i_rs2  — registros fuente de la instrucción entrante
//   i_is_store    — indica que i_rd es realmente vs3 (fuente, no destino)
//   i_rd          — registro destino (o vs3 si i_is_store)
//
//   i_s1_valid, i_s1_rd, i_s1_is_store — instrucción en etapa Issue→Execute
//   i_s2_valid, i_s2_rd, i_s2_is_store — instrucción en etapa Execute→MEM
//   i_s3_valid, i_s3_rd, i_s3_is_store — instrucción en etapa MEM→WB
//
// Señal de salida:
//   o_raw_stall — se activa cuando se detecta un hazard. La etapa Issue
//                 responde insertando una burbuja (poniendo o_valid=0) y
//                 el decode unit espera un ciclo más.
//
// Flujo de detección:
//
//   s1_writes = s1_valid && !s1_is_store  → s1 produce un resultado al VRF
//   s2_writes = s2_valid && !s2_is_store
//   s3_writes = s3_valid && !s3_is_store
//
//   rs1_haz = alguna instrucción en pipeline escribe en i_rs1
//   rs2_haz = alguna instrucción en pipeline escribe en i_rs2
//   rd_haz  = instrucción entrante es store Y alguna instrucción escribe en i_rd(=vs3)
//
//   o_raw_stall = i_valid && (rs1_haz || rs2_haz || rd_haz)
// =============================================================================

module hazard_unit (
    // Instrucción entrante (en decode/issue)
    input         i_valid,      // instrucción válida (no burbuja)
    input  [4:0]  i_rs1,        // registro fuente 1
    input  [4:0]  i_rs2,        // registro fuente 2
    input         i_is_store,   // es instrucción store (i_rd es vs3, no vd)
    input  [4:0]  i_rd,         // registro destino (o vs3 si es store)

    // Estado de la instrucción en etapa Issue->Execute (s1)
    input         i_s1_valid,
    input  [4:0]  i_s1_rd,
    input         i_s1_is_store,

    // Estado de la instrucción en etapa Execute->MEM (s2)
    input         i_s2_valid,
    input  [4:0]  i_s2_rd,
    input         i_s2_is_store,

    // Estado de la instrucción en etapa MEM->WB (s3)
    input         i_s3_valid,
    input  [4:0]  i_s3_rd,
    input         i_s3_is_store,

    output        o_raw_stall   // 1 -> insertar burbuja en Issue
);
    // Una instrucción "escribe" al VRF si es válida y NO es un store
    // (los stores escriben a memoria, no al VRF)
    wire s1_writes = i_s1_valid && !i_s1_is_store;
    wire s2_writes = i_s2_valid && !i_s2_is_store;
    wire s3_writes = i_s3_valid && !i_s3_is_store;

    // Hazard en rs1: alguna instrucción en pipeline escribe el registro que rs1 necesita
    wire rs1_haz = (s1_writes && i_s1_rd == i_rs1) ||
                   (s2_writes && i_s2_rd == i_rs1) ||
                   (s3_writes && i_s3_rd == i_rs1);

    // Hazard en rs2: análogo para el segundo operando fuente
    wire rs2_haz = (s1_writes && i_s1_rd == i_rs2) ||
                   (s2_writes && i_s2_rd == i_rs2) ||
                   (s3_writes && i_s3_rd == i_rs2);

    // Hazard en el dato de un store: si la instrucción entrante es un store,
    // i_rd es vs3 (la fuente de datos). Se necesita que vs3 esté actualizado
    // antes de que el store acceda al VRF.
    wire rd_haz  = i_is_store && (
                   (s1_writes && i_s1_rd == i_rd) ||
                   (s2_writes && i_s2_rd == i_rd) ||
                   (s3_writes && i_s3_rd == i_rd));

    // Activa stall solo si la instrucción entrante es válida y hay al menos un hazard
    assign o_raw_stall = i_valid && (rs1_haz || rs2_haz || rd_haz);
endmodule
