// =============================================================================
// Módulo: ve_integrated (Vector Extension Integrated System)
// Archivo: rtl_ve/ve_integrated.v
//
// Descripción:
//   Sistema completo que integra el pipeline escalar RISC-V RV32I de 5 etapas
//   con la extensión vectorial (ve_top). Comparten una única caché de datos
//   (DCache) y están conectados a través del decodificador modificado
//   (Modified_DecodeUnit) que emite instrucciones tanto al pipeline escalar
//   como al vectorial.
//
// ─────────────────────────────────────────────────────────────────────────────
// PIPELINE ESCALAR (5 etapas)
// ─────────────────────────────────────────────────────────────────────────────
//
//   Etapa 1: fetch (FU)    — registra instrucción y PC; maneja branches y stalls.
//   Etapa 2: decode (DU)   — decodifica la instrucción, lee el RF escalar, y
//                             emite señales al pipeline escalar Y al vectorial.
//   Etapa 3: exu (EXU)     — ejecuta la ALU escalar, resuelve branches/jumps.
//   Etapa 4: mem_unit      — accede al DCache con la dirección calculada por EXU.
//   Etapa 5: wb_unit       — selecciona el dato (ALU o DMEM) y escribe al RF.
//
// ─────────────────────────────────────────────────────────────────────────────
// FORWARDING (adelantamiento de datos) EN EL PIPELINE ESCALAR
// ─────────────────────────────────────────────────────────────────────────────
//
//   El pipeline escalar implementa tres rutas de forwarding para eliminar NOPs
//   entre instrucciones con dependencia RAW:
//
//   1. EX->EX (1 instrucción de distancia):
//      El resultado de EXU (exu_result) se reenvía al operando fuente del
//      siguiente ciclo. Solo cubre distancia de ≥1 instrucción (no 0).
//      Condición: exu_write_on_reg && exu_rd_addr == du_rs1/rs2_addr
//
//   2. MEM->EX (forwarding de carga — load-use):
//      Un lw que está en mem_unit puede proporcionar su dato vía fwd_load_data
//      (lectura combinacional de dmem_rdata_a). Esto elimina la necesidad de
//      NOPs después de un lw siempre que el consumidor no sea la instrucción
//      INMEDIATAMENTE siguiente (para ese caso se inserta 1 stall automático).
//      Condición: mem_write_on_reg && mem_wb_sel[0] && mem_rd_addr == du_rs1/rs2_addr
//
//   3. WB->EX (3 instrucciones de distancia):
//      El resultado que está siendo escrito al RF (wb_write_data) se reenvía
//      antes de que el RF complete la escritura física.
//      Condición: wb_wen && wb_rd_addr == du_rs1/rs2_addr
//
//   Prioridad: EX->EX > MEM->EX > WB->EX > RF (lectura normal)
//
//   Los datos seleccionados (fwd_rs1, fwd_rs2) se capturan en registros
//   (du_rs1_data_reg, du_rs2_data_reg) al final de la etapa DU para que
//   EXU los lea en el siguiente ciclo.
//
// ─────────────────────────────────────────────────────────────────────────────
// DETECCIÓN DE HAZARD LOAD-USE
// ─────────────────────────────────────────────────────────────────────────────
//
//   Si la instrucción inmediatamente siguiente a un lw usa el registro cargado,
//   el forwarding MEM->EX no puede resolverlo solo (el dato aún no llegó del
//   DCache cuando el consumidor llega a EXU). Se inserta 1 stall automático:
//
//   scalar_stall = exu_dmem_read && (exu_rd_addr != 0) &&
//                  (exu_rd_addr == du_rs1_addr || exu_rd_addr == du_rs2_addr)
//
//   Cuando scalar_stall=1:
//   - FU y DU se congelan (pipeline_stall = vec_stall || scalar_stall).
//   - EXU recibe una burbuja (exu_i_* signals puestas a cero).
//   - El siguiente ciclo, el lw está en mem_unit y fwd_load_data ya tiene
//     el dato correcto -> forwarding MEM->EX resuelve la dependencia.
//
// ─────────────────────────────────────────────────────────────────────────────
// COMPARTICIÓN DEL DCache
// ─────────────────────────────────────────────────────────────────────────────
//
//   El DCache tiene dos puertos (A y B). El puerto B es exclusivo del pipeline
//   vectorial. El puerto A se comparte entre el pipeline escalar y el vectorial:
//
//   vec_port_a_active = vext_mem_read_en || vext_mem_write_en
//
//   Puerto A:
//     Si vec_port_a_active=1 -> vectorial controla puerto A
//     Si vec_port_a_active=0 -> escalar controla puerto A
//
//   El stall vectorial (vec_stall) congela el pipeline escalar mientras una
//   instrucción vectorial está en ejecución, garantizando que escalar y
//   vectorial no accedan al puerto A simultáneamente.
//
// ─────────────────────────────────────────────────────────────────────────────
// INTERFAZ DE CARGA DE PROGRAMA
// ─────────────────────────────────────────────────────────────────────────────
//
//   Durante el reset (rst=1), el testbench puede escribir el programa en la
//   ICache usando las señales i_imem_wen, i_imem_addr, i_imem_data.
//   La dirección es indexada por palabra (word-indexed).
//   Una vez que rst baja a 0, la ICache entra en modo solo-lectura y el
//   pipeline comienza a ejecutar desde la dirección INITIAL_PC.
//
// ─────────────────────────────────────────────────────────────────────────────
// SEÑAL CENTINELA (sentinel)
// ─────────────────────────────────────────────────────────────────────────────
//
//   Los programas de prueba usan x20 como señal de finalización:
//   - x20 = 0: programa en ejecución.
//   - x20 = 1: programa terminó (última instrucción: addi x20, x0, 1).
//   El testbench monitorea dut.RF.x20 cada ciclo para detectar la terminación.
// =============================================================================

module ve_integrated #(
    parameter INITIAL_PC = 32'h0000_0000  // dirección inicial del PC (boot address)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        i_imem_wen,   // habilitación de escritura a la ICache (durante reset)
    input  wire [31:0] i_imem_addr,  // dirección de escritura a la ICache (word-indexed)
    input  wire [31:0] i_imem_data   // dato a escribir en la ICache
);

// ─────────────────────────────────────────────────────────────────────────────
// Señales de interconexión: ICache <-> FU (Fetch Unit)
// ─────────────────────────────────────────────────────────────────────────────
wire [31:0] fu_pc_imem;       // PC que FU envía a la ICache para la próxima lectura
wire [31:0] imem_pc_out;      // PC registrado que sale de la ICache junto con la instrucción
wire [31:0] imem_instr_out;   // instrucción leída de la ICache

// Señales de salida de FU hacia DU
wire [31:0] fu_instr;   // instrucción decodificada por FU (puede ser burbuja)
wire [31:0] fu_pc;      // PC correspondiente a la instrucción en FU
wire        fu_bubble;  // indica que fu_instr es una burbuja (NOP por branch/stall)

// Señales de control de flujo de EXU -> FU (para branches y jumps)
wire [31:0] exu_pc_upd;   // dirección de salto calculada por EXU
wire        exu_take_br;  // EXU indica tomar un branch
wire        exu_take_jmp; // EXU indica tomar un jump (JAL/JALR)

// ─────────────────────────────────────────────────────────────────────────────
// Stall vectorial y combinación con stall escalar
// ─────────────────────────────────────────────────────────────────────────────
wire vec_stall; // generado por ve_top cuando una instrucción vectorial está en ejecución

// Stall por hazard load-use: se activa cuando el lw en EXU coincide con
// las fuentes de la instrucción que está llegando a EXU (en DU actualmente)
wire scalar_stall = exu_dmem_read && (exu_rd_addr != 5'b0) &&
    ((exu_rd_addr == du_rs1_addr) || (exu_rd_addr == du_rs2_addr));

// Stall combinado: FU y DU se congelan por cualquiera de las dos causas
wire pipeline_stall = vec_stall || scalar_stall;

// ─────────────────────────────────────────────────────────────────────────────
// ICache (Instruction Memory)
// ─────────────────────────────────────────────────────────────────────────────
icache imem (
    .CLK          (clk),
    .rst          (rst),
    .i_we         (i_imem_wen),             // escritura del testbench durante reset
    .i_tester_addr(i_imem_addr),            // dirección de escritura (word-indexed)
    .i_addr       ({2'b0, fu_pc_imem[31:2]}), // dirección de lectura (de FU, word-indexed)
    .i_pc         (fu_pc_imem),
    .i_wdata      (i_imem_data),
    .o_instr      (imem_instr_out),         // instrucción leída
    .o_pc         (imem_pc_out)             // PC registrado con la instrucción
);

// ─────────────────────────────────────────────────────────────────────────────
// Fetch Unit (FU) — Etapa 1 del pipeline escalar
// Mantiene el PC, gestiona branches/jumps y el stall por pipeline_stall.
// ─────────────────────────────────────────────────────────────────────────────
fetch FU (
    .CLK          (clk),
    .RST          (rst),
    .STALL        (pipeline_stall),   // se congela si hay stall vectorial o load-use
    .i_instruction(imem_instr_out),
    .i_pc         (imem_pc_out),
    .o_pc_imem    (fu_pc_imem),       // PC enviado a la ICache para el próximo ciclo
    .i_pc_upd     (exu_pc_upd),       // destino del salto (de EXU)
    .i_take_br    (exu_take_br),
    .i_take_jmp   (exu_take_jmp),
    .o_instruction(fu_instr),
    .o_pc         (fu_pc),
    .o_bubble     (fu_bubble)         // 1 si la instrucción es una burbuja
);

// ─────────────────────────────────────────────────────────────────────────────
// Señales de salida del Decode Unit (DU) — Etapa 2 del pipeline escalar
// ─────────────────────────────────────────────────────────────────────────────

// Direcciones de los registros fuente (para forwarding y hazard detection)
wire [4:0]  du_rs1_addr;
wire [4:0]  du_rs2_addr;

// Señales de control para el pipeline escalar
wire        du_rs1_2_pc;      // usar PC como operando A (instrucciones auipc/jal)
wire        du_is_branch;     // instrucción es un branch condicional
wire        du_is_type_u;     // instrucción tipo U (lui/auipc)
wire        du_dual_op;       // operación dual (e.g., branch que compara y salta)
wire [31:0] du_pc;            // PC de la instrucción en decode
wire [31:0] du_imm;           // inmediato extendido en signo
wire        du_is_unsigned;   // operación de memoria sin signo (lbu, lhu)
wire [1:0]  du_data_size;     // tamaño del acceso a memoria (byte/half/word)
wire [3:0]  du_alu_op;        // operación ALU escalar
wire        du_alu_src_rs2;   // fuente B de la ALU: 1=inmediato, 0=rs2
wire        du_dmem_write;    // instrucción escribe en DCache (sw, sh, sb)
wire        du_dmem_read;     // instrucción lee del DCache (lw, lh, lb, lbu, lhu)
wire [4:0]  du_rd_addr;       // dirección del registro destino
wire        du_write_on_reg;  // la instrucción escribe al RF escalar

// Señales de decodificación vectorial que el DU emite a ve_top
wire        du_vec_valid;      // hay instrucción vectorial ALU válida
wire [6:0]  du_vec_funct7;
wire [2:0]  du_vec_funct3;
wire [4:0]  du_vec_rs1;
wire [4:0]  du_vec_rs2;
wire [4:0]  du_vec_rd;
wire        du_vec_is_vx;      // modo vector-escalar
wire [31:0] du_vec_scalar;     // valor escalar leído del RF para modo VX
wire        du_vec_lsu_valid;  // hay instrucción vectorial LSU válida
wire        du_vec_is_load;
wire        du_vec_is_store;
wire        du_vec_is_mask_op;
wire        du_vec_is_strided;
wire        du_vec_is_indexed;
wire [31:0] du_vec_base_addr;  // dirección base leída del RF escalar (sin forwarding)
wire [31:0] du_vec_stride;     // stride leído del RF escalar

// Datos leídos del RF escalar (lectura combinacional)
wire [31:0] rf_rs1_data;
wire [31:0] rf_rs2_data;

// ─────────────────────────────────────────────────────────────────────────────
// Decode Unit (DU) — Etapa 2 del pipeline escalar
// ─────────────────────────────────────────────────────────────────────────────
decode DU (
    .CLK          (clk),
    .RST          (rst),
    .FLUSH        (1'b0),           // no hay flush explícito en este diseño
    .STALL        (pipeline_stall), // se congela durante stall vectorial o load-use
    .i_instr      (fu_instr),
    .i_pc         (fu_pc),
    .i_bubble     (fu_bubble),
    .i_rs1_data   (rf_rs1_data),   // datos del RF escalar (antes de forwarding)
    .i_rs2_data   (rf_rs2_data),
    .o_rs1_addr   (du_rs1_addr),
    .o_rs2_addr   (du_rs2_addr),
    .o_rs1_2_pc   (du_rs1_2_pc),
    .o_is_branch  (du_is_branch),
    .o_is_type_u  (du_is_type_u),
    .o_dual_op    (du_dual_op),
    .o_pc         (du_pc),
    .o_imm        (du_imm),
    .o_is_unsigned(du_is_unsigned),
    .o_data_size  (du_data_size),
    .o_alu_op     (du_alu_op),
    .o_alu_src_rs2(du_alu_src_rs2),
    .o_dmem_write (du_dmem_write),
    .o_dmen_read  (du_dmem_read),
    .o_rd_addr    (du_rd_addr),
    .o_write_on_reg(du_write_on_reg),
    // Señales vectoriales decodificadas
    .o_vec_valid  (du_vec_valid),
    .o_vec_funct7 (du_vec_funct7),
    .o_vec_funct3 (du_vec_funct3),
    .o_vec_rs1    (du_vec_rs1),
    .o_vec_rs2    (du_vec_rs2),
    .o_vec_rd     (du_vec_rd),
    .o_vec_is_vx  (du_vec_is_vx),
    .o_vec_scalar (du_vec_scalar),
    .o_vec_lsu_valid  (du_vec_lsu_valid),
    .o_vec_is_load    (du_vec_is_load),
    .o_vec_is_store   (du_vec_is_store),
    .o_vec_is_mask_op (du_vec_is_mask_op),
    .o_vec_is_strided (du_vec_is_strided),
    .o_vec_is_indexed (du_vec_is_indexed),
    .o_vec_base_addr  (du_vec_base_addr),
    .o_vec_stride     (du_vec_stride)
);

// ─────────────────────────────────────────────────────────────────────────────
// Registro de Archivo Escalar (RF)
// Lectura combinacional; escritura sincrónica desde WB.
// ─────────────────────────────────────────────────────────────────────────────
wire [31:0] wb_write_data;  // dato que WB escribe al RF
wire [4:0]  wb_rd_addr;     // dirección del registro destino en WB
wire        wb_wen;         // habilitación de escritura al RF

regFile RF (
    .CLK        (clk),
    .RST        (rst),
    .i_rs1_addr (du_rs1_addr),    // dirección rs1 (de DU)
    .i_rs2_addr (du_rs2_addr),    // dirección rs2 (de DU)
    .o_rs1_data (rf_rs1_data),    // dato leído combinacionalmente
    .o_rs2_data (rf_rs2_data),
    .i_we       (wb_wen),
    .i_wb_rf_addr(wb_rd_addr),
    .i_wb_rf_rslt(wb_write_data)
);

// ─────────────────────────────────────────────────────────────────────────────
// FORWARDING — Selección del operando más reciente
//
// fwd_load_data: extiende en signo el dato leído del DCache (combinacional)
// cuando la instrucción en mem_unit es un lw/lh/lb. Se usa en la ruta
// MEM→EX del forwarding.
//
// fwd_rs1, fwd_rs2: mux de 4 entradas que selecciona el valor más reciente
// disponible para cada registro fuente.
//   Prioridad: EX->EX > MEM->EX > WB->EX > RF
//
// du_rs1_data_reg, du_rs2_data_reg: registros de pipeline que capturan el
// valor seleccionado por el mux al final de la etapa DU, para que EXU lo lea
// en el siguiente ciclo de forma sincrónica.
// ─────────────────────────────────────────────────────────────────────────────

// Extensión en signo del dato del DCache para el forwarding MEM->EX
reg  [31:0] fwd_load_data;
always @(*) begin
    case (mem_data_size)
        BYTE: fwd_load_data = mem_is_unsigned ? {24'b0, scalar_rdata[7:0]}  : {{24{scalar_rdata[7]}},  scalar_rdata[7:0]};
        HALF: fwd_load_data = mem_is_unsigned ? {16'b0, scalar_rdata[15:0]} : {{16{scalar_rdata[15]}}, scalar_rdata[15:0]};
        default: fwd_load_data = scalar_rdata;  // WORD: sin extensión
    endcase
end

// Mux de forwarding para rs1: selecciona el valor más reciente disponible
wire [31:0] fwd_rs1 =
    // EX->EX: el resultado de EXU (instrucción que está en MEM en el siguiente ciclo)
    (exu_write_on_reg && exu_rd_addr != 5'b0 && exu_rd_addr == du_rs1_addr) ? exu_result :
    // MEM->EX: el resultado de mem_unit (puede ser de ALU o de carga del DCache)
    (mem_write_on_reg && mem_rd_addr != 5'b0 && mem_rd_addr == du_rs1_addr) ?
        (mem_wb_sel[0] ? fwd_load_data : mem_alu_result) :
    // WB->EX: el dato que WB está por escribir al RF
    (wb_wen && wb_rd_addr != 5'b0 && wb_rd_addr == du_rs1_addr) ? wb_write_data :
    // Sin forwarding: lectura normal del RF
    rf_rs1_data;

// Mux de forwarding para rs2 (misma lógica que fwd_rs1)
wire [31:0] fwd_rs2 =
    (exu_write_on_reg && exu_rd_addr != 5'b0 && exu_rd_addr == du_rs2_addr) ? exu_result :
    (mem_write_on_reg && mem_rd_addr != 5'b0 && mem_rd_addr == du_rs2_addr) ?
        (mem_wb_sel[0] ? fwd_load_data : mem_alu_result) :
    (wb_wen && wb_rd_addr != 5'b0 && wb_rd_addr == du_rs2_addr) ? wb_write_data :
    rf_rs2_data;

// Registros de pipeline: capturan el operando seleccionado al final de DU
// Se congelan durante stalls (scalar_stall o vec_stall) para preservar el
// estado de la instrucción que espera ser procesada por EXU.
reg [31:0] du_rs1_data_reg;
reg [31:0] du_rs2_data_reg;
always @(posedge clk) begin
    if (rst) begin
        du_rs1_data_reg <= 0;
        du_rs2_data_reg <= 0;
    end else if (!pipeline_stall) begin
        du_rs1_data_reg <= fwd_rs1;
        du_rs2_data_reg <= fwd_rs2;
    end
end

// ─────────────────────────────────────────────────────────────────────────────
// Señales de salida del Execute Unit (EXU) — Etapa 3 del pipeline escalar
// ─────────────────────────────────────────────────────────────────────────────
wire [31:0] exu_rs2_data;      // rs2 procesado por EXU (para stores)
wire [1:0]  exu_data_size;     // tamaño del acceso de memoria
wire        exu_dmem_write;    // EXU quiere escribir al DCache
wire        exu_is_unsigned;   // carga sin signo
wire [31:0] exu_result;        // resultado de la ALU (también usado en forwarding EX→EX)
wire [31:0] exu_result2;       // resultado secundario (para instrucciones con dos salidas)
wire        exu_dmem_read;     // EXU quiere leer del DCache (se usa en detección load-use)
wire [4:0]  exu_rd_addr;       // registro destino (se usa en forwarding y load-use)
wire        exu_write_on_reg;  // EXU produce un resultado que va al RF

// ─────────────────────────────────────────────────────────────────────────────
// Inyección de burbuja para hazard load-use
//
// Cuando scalar_stall=1 (hazard load-use detectado), se inyectan ceros en
// las señales de control que entran a EXU. Esto convierte la instrucción
// que está en DU en una burbuja (NOP efectivo): no escribe al DCache,
// no hace branches, no escribe al RF.
//
// La instrucción en DU se queda "quieta" (FU y DU se congelan) mientras
// el lw avanza de EXU a mem_unit. En el siguiente ciclo, fwd_load_data
// ya tiene el dato correcto y el forwarding MEM->EX resuelve la dependencia.
// ─────────────────────────────────────────────────────────────────────────────
wire        exu_i_is_branch    = scalar_stall ? 1'b0  : du_is_branch;
wire        exu_i_dual_op      = scalar_stall ? 1'b0  : du_dual_op;
wire        exu_i_dmem_write   = scalar_stall ? 1'b0  : du_dmem_write;
wire        exu_i_dmem_read    = scalar_stall ? 1'b0  : du_dmem_read;
wire [4:0]  exu_i_rd_addr      = scalar_stall ? 5'b0  : du_rd_addr;
wire        exu_i_write_on_reg = scalar_stall ? 1'b0  : du_write_on_reg;

// ─────────────────────────────────────────────────────────────────────────────
// Execute Unit (EXU) — Etapa 3 del pipeline escalar
// ─────────────────────────────────────────────────────────────────────────────
exu EXU (
    .CLK          (clk),
    .RST          (rst),
    .i_rs1_data   (du_rs1_data_reg),  // operando A con forwarding aplicado
    .i_rs2_data   (du_rs2_data_reg),  // operando B con forwarding aplicado
    .i_pc         (du_pc),
    .i_imm        (du_imm),
    .i_is_unsigned(du_is_unsigned),
    .i_rs1_2_pc   (du_rs1_2_pc),
    .i_is_branch  (exu_i_is_branch),  // cero si hay stall load-use (burbuja)
    .i_is_type_u  (du_is_type_u),
    .i_dual_op    (exu_i_dual_op),
    .i_data_size  (du_data_size),
    .i_alu_op     (du_alu_op),
    .i_alu_src_rs2(du_alu_src_rs2),
    .i_dmem_write (exu_i_dmem_write), // cero si hay stall load-use
    .i_dmem_read  (exu_i_dmem_read),  // cero si hay stall load-use
    .i_rd_addr    (exu_i_rd_addr),    // cero si hay stall load-use
    .i_write_on_reg(exu_i_write_on_reg),
    .o_pc_upd     (exu_pc_upd),
    .o_take_br    (exu_take_br),
    .o_take_jmp   (exu_take_jmp),
    .o_rs2_data   (exu_rs2_data),
    .o_data_size  (exu_data_size),
    .o_dmem_write (exu_dmem_write),
    .o_is_unsigned(exu_is_unsigned),
    .o_result     (exu_result),       // resultado ALU (usado en forwarding EX→EX)
    .o_result2    (exu_result2),
    .o_dmem_read  (exu_dmem_read),   // indica que es un load (para detección load-use)
    .o_rd_addr    (exu_rd_addr),     // registro destino (para forwarding y load-use)
    .o_write_on_reg(exu_write_on_reg)
);

// ─────────────────────────────────────────────────────────────────────────────
// Señales de salida de mem_unit — Etapa 4 del pipeline escalar
// ─────────────────────────────────────────────────────────────────────────────
wire [31:0] mem_dmem_address;  // dirección calculada por EXU para el acceso
wire        mem_dmem_write;
wire        mem_dmem_read;
wire [31:0] mem_write_data;
wire [3:0]  mem_byte_en;
wire [1:0]  mem_data_size;    // tamaño del acceso (para extensión en signo en WB)
wire        mem_is_unsigned;

wire [31:0] mem_alu_result;   // resultado ALU propagado de EXU (para forwarding MEM->EX)
wire [4:0]  mem_rd_addr;
wire [1:0]  mem_wb_sel;       // selección de fuente en WB: 00=ALU, 01=DCache
wire        mem_write_on_reg;

// ─────────────────────────────────────────────────────────────────────────────
// Memory Unit (mem_unit) — Etapa 4 del pipeline escalar
// Genera las señales de acceso al DCache para instrucciones lw/sw escalares.
// ─────────────────────────────────────────────────────────────────────────────
mem_unit mem0 (
    .clk          (clk),
    .reset        (rst),
    .i_alu_result (exu_result),
    .i_rs2_data   (exu_rs2_data),
    .i_rd_addr    (exu_rd_addr),
    .i_data_size  (exu_data_size),
    .i_is_unsigned(exu_is_unsigned),
    .i_dmem_write (exu_dmem_write),
    .i_dmem_read  (exu_dmem_read),
    .i_write_on_reg(exu_write_on_reg),
    .o_alu_result (mem_alu_result),   // propagado para forwarding MEM->EX
    .o_rd_addr    (mem_rd_addr),
    .o_wb_sel     (mem_wb_sel),
    .o_data_size  (mem_data_size),
    .o_write_on_reg(mem_write_on_reg),
    .o_is_unsigned(mem_is_unsigned),
    .o_write_data (mem_write_data),
    .o_dmem_address(mem_dmem_address),
    .o_byte_en    (mem_byte_en),
    .o_dmem_read  (mem_dmem_read),
    .o_dmem_write (mem_dmem_write)
);

// ─────────────────────────────────────────────────────────────────────────────
// Señales de interfaz entre ve_top y el DCache
// ─────────────────────────────────────────────────────────────────────────────
wire [31:0] vext_mem_addr;
wire        vext_mem_read_en;
wire        vext_mem_write_en;
wire [31:0] vext_mem_wdata;
wire [3:0]  vext_mem_byte_en;

wire [31:0] vext_mem_addr_b;
wire        vext_mem_read_en_b;
wire        vext_mem_write_en_b;
wire [31:0] vext_mem_wdata_b;
wire [3:0]  vext_mem_byte_en_b;

// ─────────────────────────────────────────────────────────────────────────────
// Multiplexor del Puerto A del DCache: vectorial vs escalar
//
// El vectorial tiene prioridad cuando tiene un acceso activo (read_en o
// write_en). El stall vectorial (vec_stall) garantiza que el pipeline escalar
// esté congelado mientras esto ocurre, por lo que no hay conflicto real.
// ─────────────────────────────────────────────────────────────────────────────
wire vec_port_a_active = vext_mem_read_en || vext_mem_write_en;

// Dirección del DCache puerto A: vectorial usa la dirección vectorial (word-indexed),
// escalar usa la dirección calculada por mem_unit (también word-indexed, bits [8:2])
wire [31:0] dmem_addr_a     = vec_port_a_active ? {25'b0, vext_mem_addr[8:2]}   : {25'b0, mem_dmem_address[8:2]};
wire        dmem_write_en_a = vec_port_a_active ? vext_mem_write_en              : mem_dmem_write;
wire        dmem_read_en_a  = vec_port_a_active ? vext_mem_read_en               : mem_dmem_read;
wire [3:0]  dmem_byte_en_a  = vec_port_a_active ? vext_mem_byte_en               : mem_byte_en;
wire [31:0] dmem_wdata_a    = vec_port_a_active ? vext_mem_wdata                 : mem_write_data;
wire [31:0] dmem_rdata_a;   // dato leído del DCache por puerto A (compartido)
wire [31:0] dmem_rdata_b;   // dato leído del DCache por puerto B (exclusivo vectorial)

// ─────────────────────────────────────────────────────────────────────────────
// DCache (Data Cache)
// Doble puerto: A (compartido escalar/vectorial) y B (exclusivo vectorial).
// Lecturas combinacionales; escrituras sincrónicas en posedge clk.
// ─────────────────────────────────────────────────────────────────────────────
dcache dmem (
    .clk          (clk),
    .rst          (rst),
    // Puerto A (compartido)
    .i_write_en   (dmem_write_en_a),
    .i_read_en    (dmem_read_en_a),
    .i_byte_en    (dmem_byte_en_a),
    .i_addr       (dmem_addr_a),
    .i_wdata      (dmem_wdata_a),
    .o_rdata      (dmem_rdata_a),
    // Puerto B (exclusivo vectorial)
    .i_write_en_b (vext_mem_write_en_b),
    .i_read_en_b  (vext_mem_read_en_b),
    .i_byte_en_b  (vext_mem_byte_en_b),
    .i_addr_b     ({25'b0, vext_mem_addr_b[8:2]}),
    .i_wdata_b    (vext_mem_wdata_b),
    .o_rdata_b    (dmem_rdata_b)
);

// Rutas de lectura del DCache hacia cada subsistema
wire [31:0] scalar_rdata = dmem_rdata_a;  // dato leído por el pipeline escalar
wire [31:0] vec_rdata_a  = dmem_rdata_a;  // dato leído por el vectorial (puerto A)
wire [31:0] vec_rdata_b  = dmem_rdata_b;  // dato leído por el vectorial (puerto B)

// ─────────────────────────────────────────────────────────────────────────────
// Constantes para el tamaño del acceso de memoria (extensión en signo)
// ─────────────────────────────────────────────────────────────────────────────
localparam BYTE = 2'b00;
localparam HALF = 2'b01;
localparam WORD = 2'b11;

// ─────────────────────────────────────────────────────────────────────────────
// Extensión en signo del dato leído del DCache (pipeline escalar)
// El resultado extendido se captura en o_loaded_data sincrónico para que
// WB lo tenga disponible en el ciclo siguiente.
// ─────────────────────────────────────────────────────────────────────────────
wire [7:0]  byte_val = scalar_rdata[7:0];
wire [15:0] half_val = scalar_rdata[15:0];

reg [31:0] o_loaded_data;
always @(posedge clk) begin
    if (rst) begin
        o_loaded_data <= 0;
    end else begin
        case (mem_data_size)
            BYTE: o_loaded_data <= mem_is_unsigned ? {24'b0, byte_val} : {{24{byte_val[7]}}, byte_val};
            HALF: o_loaded_data <= mem_is_unsigned ? {16'b0, half_val} : {{16{half_val[15]}}, half_val};
            WORD: o_loaded_data <= scalar_rdata;
            default: o_loaded_data <= o_loaded_data;
        endcase
    end
end

// ─────────────────────────────────────────────────────────────────────────────
// Writeback Unit (WB) — última etapa del pipeline escalar
// Selecciona el dato a escribir al RF: ALU (mem_alu_result) o DCache (o_loaded_data).
// ─────────────────────────────────────────────────────────────────────────────
wb_unit wb0 (
    .clk          (clk),
    .rst          (rst),
    .i_dmem_data  (o_loaded_data),     // dato cargado del DCache (lw/lh/lb)
    .i_alu_result (mem_alu_result),    // resultado de la ALU (add, xor, etc.)
    .i_rd_addr    (mem_rd_addr),
    .i_wb_sel     (mem_wb_sel),        // 01=usar DCache, 00=usar ALU
    .i_write_on_reg(mem_write_on_reg),
    .o_write_data (wb_write_data),     // dato final que va al RF
    .o_rd_addr    (wb_rd_addr),
    .o_wen        (wb_wen)
);

// ─────────────────────────────────────────────────────────────────────────────
// Extensión Vectorial (ve_top)
// Recibe señales pre-decodificadas del DU y accede al DCache compartido.
// El stall vectorial (vec_stall) que genera se propaga como pipeline_stall
// para congelar FU y DU mientras la instrucción vectorial está en ejecución.
// ─────────────────────────────────────────────────────────────────────────────
ve_top vext (
    .clk              (clk),
    .rst              (rst),
    .i_alu_valid      (du_vec_valid),
    .i_funct7         (du_vec_funct7),
    .i_funct3         (du_vec_funct3),
    .i_rs1            (du_vec_rs1),
    .i_rs2            (du_vec_rs2),
    .i_rd             (du_vec_rd),
    .i_is_vx          (du_vec_is_vx),
    .i_scalar         (du_vec_scalar),
    .i_lsu_valid      (du_vec_lsu_valid),
    .i_is_load        (du_vec_is_load),
    .i_is_store       (du_vec_is_store),
    .i_is_mask_op     (du_vec_is_mask_op),
    .i_is_strided     (du_vec_is_strided),
    .i_is_indexed     (du_vec_is_indexed),
    .i_base_addr      (du_vec_base_addr),  // nota: sin forwarding desde RF escalar
    .i_stride         (du_vec_stride),
    .o_stall          (vec_stall),         // congela FU+DU mientras opera
    // Puerto A del DCache (compartido, controlado por mux arriba)
    .o_mem_addr       (vext_mem_addr),
    .o_mem_read_en    (vext_mem_read_en),
    .i_mem_rdata      (vec_rdata_a),
    .o_mem_write_en   (vext_mem_write_en),
    .o_mem_wdata      (vext_mem_wdata),
    .o_mem_byte_en    (vext_mem_byte_en),
    // Puerto B del DCache (exclusivo vectorial)
    .o_mem_addr_b     (vext_mem_addr_b),
    .o_mem_read_en_b  (vext_mem_read_en_b),
    .i_mem_rdata_b    (vec_rdata_b),
    .o_mem_write_en_b (vext_mem_write_en_b),
    .o_mem_wdata_b    (vext_mem_wdata_b),
    .o_mem_byte_en_b  (vext_mem_byte_en_b)
);

endmodule
