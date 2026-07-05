// =============================================================================
// Módulo: alu_array
// Archivo: rtl_ve/alu/alu_array.v
//
// Descripción:
//   Arreglo de N instancias de la ALU escalar, conectadas en paralelo.
//   Implementa el procesamiento SIMD (Single Instruction, Multiple Data)
//   de la extensión vectorial: una sola instrucción (alu_op) se aplica
//   simultáneamente a los N elementos del vector de entrada.
//
// Parámetros:
//   SIZE — ancho de cada elemento en bits (default 32 para RV32V).
//   N    — número de elementos por vector (default 4; con VLEN=128 bits
//           y SIZE=32 se tienen exactamente 4 elementos por registro).
//
// Puertos:
//   alu_op  [3:0]       — operación aplicada a TODOS los elementos a la vez.
//   in_a    [N*SIZE-1:0] — vector A empaquetado: elem_0 en bits [SIZE-1:0],
//                          elem_1 en bits [2*SIZE-1:SIZE], etc.
//   in_b    [N*SIZE-1:0] — vector B empaquetado (mismo orden que in_a).
//   out     [N*SIZE-1:0] — resultado empaquetado (mismo orden).
//
// Implementación:
//   Se utiliza la construcción generate/for de Verilog para instanciar
//   automáticamente N copias del módulo alu. La notación [i*SIZE +: SIZE]
//   extrae SIZE bits a partir del bit i*SIZE (slice de ancho fijo).
//
// Ejemplo con N=4, SIZE=32 y alu_op=VADD (0000):
//   Si in_a = {40, 30, 20, 10} y in_b = {80, 70, 60, 50}
//   Entonces out = {120, 100, 80, 60}   (cada suma realizada en paralelo)
// =============================================================================

module alu_array #(
    parameter SIZE = 32,
    parameter N    = 4
) (
    input  [3:0]        alu_op,       // operación (compartida por todos los carriles)
    input  [N*SIZE-1:0] in_a,         // vector fuente A empaquetado
    input  [N*SIZE-1:0] in_b,         // vector fuente B empaquetado
    output [N*SIZE-1:0] out           // resultado empaquetado
);
    genvar i;
    generate
        // Genera N instancias de ALU (un "carril" por elemento del vector)
        for (i = 0; i < N; i = i + 1) begin : lane
            alu #(.SIZE(SIZE)) alu_inst (
                .alu_op (alu_op),
                // Extrae el elemento i del vector empaquetado (SIZE bits a partir de i*SIZE)
                .in_a   (in_a[i*SIZE +: SIZE]),
                .in_b   (in_b[i*SIZE +: SIZE]),
                .out    (out [i*SIZE +: SIZE])
            );
        end
    endgenerate
endmodule
