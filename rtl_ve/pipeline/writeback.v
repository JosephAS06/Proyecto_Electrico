// =============================================================================
// Módulo: writeback
// Archivo: rtl_ve/pipeline/writeback.v
//
// Descripción:
//   Cuarta y última etapa del pipeline vectorial (Writeback). Recibe el
//   resultado de la etapa MEM y genera las señales de escritura al VRF
//   (Banco de Registros Vectoriales).
//
//   El módulo es completamente combinacional — no tiene registros propios.
//   Actúa como un puente de control: decide si el resultado debe escribirse
//   al VRF y genera los puertos de escritura del vregisters.
//
// Regla de escritura:
//   o_we = i_valid && !i_is_store
//
//   Solo se escribe al VRF cuando la instrucción es válida Y no es un store.
//   Las instrucciones store (vse32, vsse32, vsuxei32, vsm) escriben datos
//   a la memoria, no al banco de registros vectoriales.
//
// Latencia total del pipeline vectorial desde decode hasta escritura:
//   Issue (1 ciclo) + Execute (1 ciclo) + MEM (1 ciclo) + WB (combinacional)
//   = 3 ciclos de latencia desde que la instrucción sale del decoder
//     hasta que el resultado aparece en el VRF.
//
//   Por eso la hazard_unit monitorea 3 etapas (s1, s2, s3): cualquier
//   instrucción en esas etapas todavía no ha escrito al VRF.
// =============================================================================

module writeback (
    input         i_valid,      // instrucción válida en esta etapa
    input         i_is_store,   // stores no escriben al VRF (escriben a memoria)
    input  [4:0]  i_rd,         // dirección del registro vectorial destino (vd)
    input  [127:0] i_result,    // resultado de 128 bits (de MEM)

    output        o_we,         // habilitación de escritura al VRF
    output [4:0]  o_addr_w,     // dirección de escritura en el VRF
    output [127:0] o_data_in    // dato a escribir en el VRF
);
    // Habilita escritura solo si la instrucción es válida y no es un store
    assign o_we      = i_valid && !i_is_store;
    assign o_addr_w  = i_rd;
    assign o_data_in = i_result;
endmodule
