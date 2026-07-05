// =============================================================================
// Módulo: vregisters
// Archivo: rtl_ve/vregfile/vregisters.v
//
// Descripción:
//   Banco de 32 registros vectoriales de 128 bits cada uno (VRF — Vector
//   Register File). Soporta un puerto de escritura sincrónico y cuatro
//   puertos de lectura combinacionales, necesarios para atender
//   simultáneamente los operandos de instrucciones ALU vectorial y LSU.
//
// Configuración de puertos de lectura:
//   Puerto A (addr_a / data_a): vs1 — primer operando fuente de instrucciones ALU.
//   Puerto B (addr_b / data_b): vs2 — segundo operando fuente de instrucciones ALU;
//                                     también se usa como registro de offsets en
//                                     accesos indexados (vluxei/vsuxei).
//   Puerto C (addr_c / data_c): vs3 — registro fuente de datos en stores vectoriales
//                                     (el campo rd de la instrucción codifica vs3).
//   Puerto D (addr_d / data_d): vs2 offset — segunda lectura dedicada al VLSU para
//                                     accesos indexados (campo rs2 de la instrucción).
//
// Puerto de escritura:
//   addr_w / data_in: destino de la instrucción (vd); se escribe síncrono en
//   el flanco de subida del reloj cuando we=1.
//
// Organización de memoria:
//   regs[0..31]: array de 32 registros de 128 bits.
//   El registro v0 puede leerse y escribirse libremente (la especificación
//   RVV usa v0 como registro de máscara, pero este diseño no implementa
//   enmascaramiento — v0 es tratado como registro de propósito general).
//
// Flujo de datos (lectura):
//
//   addr_a -> regs[addr_a] -> data_a   (combinacional, latencia 0)
//   addr_b -> regs[addr_b] -> data_b
//   addr_c -> regs[addr_c] -> data_c
//   addr_d -> regs[addr_d] -> data_d
//
// Flujo de datos (escritura):
//
//   posedge clk
//     si rst  -> todos los registros se ponen a 0
//     si we   -> regs[addr_w] <- data_in   (escritura sincrónica)
//
// Nota sobre hazards de lectura-escritura:
//   No hay lógica de bypass interna. Si se lee y escribe el mismo registro
//   en el mismo ciclo, la lectura devuelve el valor ANTERIOR (antes del
//   flanco). El módulo hazard_unit en ve_top.v es quien previene estas
//   situaciones insertando burbujas.
// =============================================================================

module vregisters (
    input         clk,
    input         rst,
    input         we,        // habilitación de escritura (write enable)
    input  [4:0]  addr_a,    // dirección de lectura puerto A (vs1)
    input  [4:0]  addr_b,    // dirección de lectura puerto B (vs2)
    input  [4:0]  addr_c,    // dirección de lectura puerto C (vs3 stores / vd indexed)
    input  [4:0]  addr_d,    // dirección de lectura puerto D (offsets indexed — rs2)
    input  [4:0]  addr_w,    // dirección de escritura (vd)
    input  [127:0] data_in,  // dato a escribir (resultado de la etapa WB)
    output [127:0] data_a,   // dato leído por puerto A
    output [127:0] data_b,   // dato leído por puerto B
    output [127:0] data_c,   // dato leído por puerto C
    output [127:0] data_d    // dato leído por puerto D
);
    // Array de 32 registros vectoriales de 128 bits
    reg [127:0] regs [0:31];

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            // El reset pone todos los registros a cero (estado inicial conocido)
            for (j = 0; j < 32; j = j + 1)
                regs[j] <= 128'b0;
        end else if (we) begin
            // Escritura síncrona: el resultado de WB se captura en el registro destino
            regs[addr_w] <= data_in;
        end
    end

    // v0 es el registro de máscara, puede leerse y escribirse libremente (spec RVV)
    // Todas las lecturas son combinacionales: reflejan el estado actual del arreglo
    assign data_a = regs[addr_a];
    assign data_b = regs[addr_b];
    assign data_c = regs[addr_c];
    assign data_d = regs[addr_d];
endmodule
