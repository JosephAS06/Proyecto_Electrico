// =============================================================================
// Módulo: alu
// Archivo: rtl_ve/alu/alu.v
//
// Descripción:
//   Unidad Aritmético-Lógica (ALU) genérica y parametrizable. Recibe dos
//   operandos de SIZE bits y una señal de control de 4 bits que selecciona
//   la operación a realizar. El resultado es combinacional (sin registros).
//
//   Este módulo es el bloque de procesamiento elemental de la extensión
//   vectorial: se instancia N veces dentro de alu_array para procesar N
//   elementos de un vector en paralelo (arquitectura SIMD).
//
// Parámetro:
//   SIZE  — ancho de los operandos en bits (default 32 para RV32).
//
// Tabla de operaciones (alu_op):
//   4'b0000 -> VADD  : out = in_a + in_b          (suma)
//   4'b1000 -> VSUB  : out = in_a - in_b          (resta)
//   4'b0001 -> VSLL  : out = in_a << in_b[4:0]    (desplazamiento lógico izquierda)
//   4'b0010 -> VSLT  : out = ($signed(in_a) < $signed(in_b)) ? 1 : 0  (menor signed)
//   4'b0011 -> VSLTU : out = (in_a < in_b) ? 1 : 0                    (menor unsigned)
//   4'b0100 -> VXOR  : out = in_a ^ in_b          (XOR bit a bit)
//   4'b0101 -> VSRL  : out = in_a >> in_b[4:0]    (desplazamiento lógico derecha)
//   4'b1101 -> VSRA  : out = $signed(in_a) >>> in_b[4:0]  (desplazamiento aritmético)
//   4'b0110 -> VOR   : out = in_a | in_b          (OR bit a bit)
//   4'b0111 -> VAND  : out = in_a & in_b          (AND bit a bit)
//   default -> out = 0
//
// Nota de codificación del opcode:
//   El bit 3 de alu_op distingue ADD de SUB (0=ADD, 1=SUB) y SRL de SRA
//   (0=SRL, 1=SRA). Los bits [2:0] corresponden al campo funct3 de la
//   instrucción RISC-V. Este esquema permite derivar alu_op directamente
//   desde {funct7[5], funct3} en la etapa Issue.
// =============================================================================

module alu #(parameter SIZE = 32) (
    input      [3:0]      alu_op,   // código de operación (ver tabla arriba)
    input      [SIZE-1:0] in_a,     // operando A (fuente vs1 en contexto vectorial)
    input      [SIZE-1:0] in_b,     // operando B (fuente vs2 o escalar replicado)
    output reg [SIZE-1:0] out       // resultado combinacional
);
    always @(*) begin
        case (alu_op)
            4'b0000: out = in_a + in_b;
            4'b1000: out = in_a - in_b;
            4'b0001: out = in_a << in_b[4:0];
            // VSLT: comparación con signo -> produce 1 ó 0 (cero-extendido a SIZE bits)
            4'b0010: out = ($signed(in_a) < $signed(in_b)) ? {{(SIZE-1){1'b0}}, 1'b1}
                                                            : {SIZE{1'b0}};
            // VSLTU: comparación sin signo -> misma lógica pero operandos como unsigned
            4'b0011: out = (in_a < in_b) ? {{(SIZE-1){1'b0}}, 1'b1}
                                         : {SIZE{1'b0}};
            4'b0100: out = in_a ^ in_b;
            4'b0101: out = in_a >> in_b[4:0];
            // VSRA: desplazamiento aritmético preserva el bit de signo
            4'b1101: out = $signed(in_a) >>> in_b[4:0];
            4'b0110: out = in_a | in_b;
            4'b0111: out = in_a & in_b;
            // Opcode desconocido -> resultado cero
            default: out = {SIZE{1'b0}};
        endcase
    end
endmodule
