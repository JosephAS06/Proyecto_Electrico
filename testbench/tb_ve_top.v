// =============================================================================
// Módulo: tb_ve_top
// Archivo: testbench/tb_ve_top.v
//
// Descripción:
//   Banco de pruebas de integración para el módulo `ve_top` (tope del pipeline
//   vectorial). Verifica el funcionamiento completo de la extensión vectorial:
//   operaciones ALU, cargas y almacenamientos en todos los modos de
//   direccionamiento, y la detección automática de peligros RAW (hazards).
//
// Componentes instanciados:
//   - "decode" (Modified_DecodeUnit.v): decodificador real que genera las
//     señales de control para el pipeline vectorial. Las salidas escalares
//     no se conectan (outputs vacíos).
//   - "ve_top": módulo bajo prueba — pipeline vectorial completo.
//   - "int_rf[0:31]": arreglo de registros enteros simulados. El decode
//     lee rs1/rs2 de este arreglo combinacionalmente.
//   - "mem[0:127]": DCache simulada con lecturas combinacionales y
//     escrituras síncronas respetando byte_en por byte.
//
// Modelo del DCache simulado:
//   - Lecturas: combinacionales. Cuando read_en=1 el dato de mem[addr[6:0]]
//     aparece inmediatamente en i_mem_rdata/i_mem_rdata_b.
//   - Escrituras: síncronas (@posedge clk). Se respetan los bits de byte_en
//     para escrituras parciales (necesario para VSM que escribe 1 byte).
//   - El índice es la dirección en bytes (bits [6:0] para 128 palabras).
//
// Tareas de envío de instrucciones:
//
//   send_alu(instr):
//     Envía una instrucción ALU vectorial y espera a que complete.
//     Secuencia: decode decodifica (1 ciclo), Issue captura en VRF (1 ciclo),
//     Execute computa (1 ciclo), MEM pasa resultado (1 ciclo), WB escribe (1 ciclo).
//     Total: 5 posedges para que el resultado aparezca en el VRF.
//
//   send_load(instr):
//     Envía una instrucción de carga vectorial y espera que complete.
//     El VLSU genera ACCESS_01 en Execute y ACCESS_23 en MEM.
//     El VRF se actualiza en WB con el vector completo de 128 bits.
//
//   send_store(instr):
//     Envía una instrucción de store vectorial. Los datos se escriben al
//     DCache en Execute (ACCESS_01) y MEM (ACCESS_23). WB no escribe al VRF.
//
//   send_raw_consecutive(instr_a, instr_b):
//     Envía dos instrucciones back-to-back (sin NOPs entre ellas).
//     Si B depende del resultado de A (peligro RAW), la hazard_unit inserta
//     automáticamente 3 burbujas para que A complete antes de que B lea el VRF.
//     Espera 10 ciclos totales para asegurar que ambas completen.
//
// Grupos de pruebas:
//
//   Tests ALU (7 casos):
//     VADD v3=v1+v2, VSUB v4=v2-v1, VAND v9=v5&v6, VOR v10=v7|v8,
//     VXOR v11=v7^v8, VADD v0=v1+v2 (registro v0 sí es escribible),
//     VADD v12=v0+v2 (cadena de resultados)
//
//   Tests LSU — Load (2 casos):
//     VLE32.v con base=0 (mem[0..12]) y base=20 (mem[20..32])
//
//   Tests LSU — Store (2 casos):
//     VSE32.v hacia mem[40..52] y mem[60..72]
//
//   Tests LSU — Strided (2 casos):
//     VLSE32.v y VSSE32.v con step=8, base=80 y base=100/80
//
//   Tests LSU — Indexed (2 casos):
//     vluxei32.v y vsuxei32.v con offsets vs2={0,8,16,24}
//
//   Tests LSU — Mask (2 casos):
//     VLM.v: carga 1 byte → v17={120'b0, byte[7:0]}
//     VSM.v: escribe 1 byte con byte_en=0001
//
//   Tests RAW (2 casos):
//     Instrucciones back-to-back con dependencia de datos en el registro destino.
//     La hazard_unit debe detectar el peligro e insertar las burbujas necesarias.
//
// Pre-carga de datos:
//   VRF: v1={4{0xA}}, v2={4{0x14}}, v5={4{0xFF00FF00}}, v6={4{0x0F0F0F0F}},
//        v7={4{0xAAAAAAAA}}, v8={4{0x55555555}}
//   DCache: bloques en posiciones byte 0, 20, 80, 110, 114
// =============================================================================

`timescale 1ns/1ps
module tb_ve_top;
    reg        clk, rst;

    // Instruccion decodificada: registro de texto plano de instrucción RISC-V
    reg [31:0] du_i_instr;

    // Banco de registros enteros simulado: el decode lee rs1/rs2 combinacionalmente
    reg [31:0] int_rf [0:31];

    // Puerto A del DCache simulado
    wire [31:0] o_mem_addr;
    wire        o_mem_read_en;
    reg  [31:0] i_mem_rdata;
    wire        o_mem_write_en;
    wire [31:0] o_mem_wdata;
    wire [3:0]  o_mem_byte_en;

    // Puerto B del DCache simulado (exclusivo para la extensión vectorial)
    wire [31:0] o_mem_addr_b;
    wire        o_mem_read_en_b;
    reg  [31:0] i_mem_rdata_b;
    wire        o_mem_write_en_b;
    wire [31:0] o_mem_wdata_b;
    wire [3:0]  o_mem_byte_en_b;

    // Señal de stall hacia el pipeline escalar (vec_stall)
    wire stall;

    // Memoria simulada de 128 palabras de 32 bits (DCache)
    reg [31:0] mem [0:127];

    // -------------------------------------------------------------------------
    // Modelo del DCache simulado
    //   Lecturas: combinacionales, indexadas por los 7 bits bajos de la dirección.
    //   Escrituras: síncronas en posedge, con respeto al byte_en bit a bit.
    //   El índice de mem[] usa la dirección en bytes directamente.
    // -------------------------------------------------------------------------
    always @(*) begin
        i_mem_rdata  = o_mem_read_en   ? mem[o_mem_addr[6:0]]   : 32'b0;
        i_mem_rdata_b = o_mem_read_en_b ? mem[o_mem_addr_b[6:0]] : 32'b0;
    end
    always @(posedge clk) begin
        if (o_mem_write_en) begin
            if (o_mem_byte_en[0]) mem[o_mem_addr[6:0]][7:0]   <= o_mem_wdata[7:0];
            if (o_mem_byte_en[1]) mem[o_mem_addr[6:0]][15:8]  <= o_mem_wdata[15:8];
            if (o_mem_byte_en[2]) mem[o_mem_addr[6:0]][23:16] <= o_mem_wdata[23:16];
            if (o_mem_byte_en[3]) mem[o_mem_addr[6:0]][31:24] <= o_mem_wdata[31:24];
        end
        if (o_mem_write_en_b) begin
            if (o_mem_byte_en_b[0]) mem[o_mem_addr_b[6:0]][7:0]   <= o_mem_wdata_b[7:0];
            if (o_mem_byte_en_b[1]) mem[o_mem_addr_b[6:0]][15:8]  <= o_mem_wdata_b[15:8];
            if (o_mem_byte_en_b[2]) mem[o_mem_addr_b[6:0]][23:16] <= o_mem_wdata_b[23:16];
            if (o_mem_byte_en_b[3]) mem[o_mem_addr_b[6:0]][31:24] <= o_mem_wdata_b[31:24];
        end
    end

    // -------------------------------------------------------------------------
    // Instancia del decodificador real (Modified_DecodeUnit.v)
    //   Decodifica la instrucción y genera las señales de control para ve_top.
    //   Las salidas del pipeline escalar (branch, alu_op, etc.) no se conectan.
    // -------------------------------------------------------------------------
    wire [4:0]  du_o_rs1_addr, du_o_rs2_addr;
    wire [31:0] du_i_rs1_data, du_i_rs2_data;

    // El decode lee del banco de registros enteros simulado (combinacional)
    assign du_i_rs1_data = int_rf[du_o_rs1_addr];
    assign du_i_rs2_data = int_rf[du_o_rs2_addr];

    wire        du_o_vec_valid;
    wire [6:0]  du_o_vec_funct7;
    wire [2:0]  du_o_vec_funct3;
    wire [4:0]  du_o_vec_rs1, du_o_vec_rs2, du_o_vec_rd;
    wire        du_o_vec_is_vx;
    wire [31:0] du_o_vec_scalar;
    wire        du_o_vec_lsu_valid;
    wire        du_o_vec_is_load, du_o_vec_is_store;
    wire        du_o_vec_is_mask_op, du_o_vec_is_strided, du_o_vec_is_indexed;
    wire [31:0] du_o_vec_base_addr, du_o_vec_stride;

    decode du (
        .CLK            (clk),
        .RST            (rst),
        .FLUSH          (1'b0),
        .STALL          (stall),
        .i_instr        (du_i_instr),
        .i_pc           (32'b0),
        .i_bubble       (1'b0),
        .i_rs1_data     (du_i_rs1_data),
        .i_rs2_data     (du_i_rs2_data),
        .o_rs1_addr     (du_o_rs1_addr),
        .o_rs2_addr     (du_o_rs2_addr),
        .o_vec_valid    (du_o_vec_valid),
        .o_vec_funct7   (du_o_vec_funct7),
        .o_vec_funct3   (du_o_vec_funct3),
        .o_vec_rs1      (du_o_vec_rs1),
        .o_vec_rs2      (du_o_vec_rs2),
        .o_vec_rd       (du_o_vec_rd),
        .o_vec_is_vx    (du_o_vec_is_vx),
        .o_vec_scalar   (du_o_vec_scalar),
        .o_vec_lsu_valid  (du_o_vec_lsu_valid),
        .o_vec_is_load    (du_o_vec_is_load),
        .o_vec_is_store   (du_o_vec_is_store),
        .o_vec_is_mask_op (du_o_vec_is_mask_op),
        .o_vec_is_strided (du_o_vec_is_strided),
        .o_vec_is_indexed (du_o_vec_is_indexed),
        .o_vec_base_addr  (du_o_vec_base_addr),
        .o_vec_stride     (du_o_vec_stride),
        // Salidas del pipeline escalar no utilizadas en este banco de pruebas
        .o_rs1_2_pc     (),
        .o_is_branch    (),
        .o_is_type_u    (),
        .o_dual_op      (),
        .o_pc           (),
        .o_imm          (),
        .o_is_unsigned  (),
        .o_data_size    (),
        .o_alu_op       (),
        .o_alu_src_rs2  (),
        .o_dmem_write   (),
        .o_dmen_read    (),
        .o_rd_addr      (),
        .o_write_on_reg ()
    );

    // -------------------------------------------------------------------------
    // Instancia del módulo bajo prueba: ve_top (pipeline vectorial completo)
    // -------------------------------------------------------------------------
    ve_top dut (
        .clk          (clk),
        .rst          (rst),
        .i_alu_valid  (du_o_vec_valid),
        .i_funct7     (du_o_vec_funct7),
        .i_funct3     (du_o_vec_funct3),
        .i_rs1        (du_o_vec_rs1),
        .i_rs2        (du_o_vec_rs2),
        .i_rd         (du_o_vec_rd),
        .i_is_vx      (du_o_vec_is_vx),
        .i_scalar     (du_o_vec_scalar),
        .i_lsu_valid  (du_o_vec_lsu_valid),
        .i_is_load    (du_o_vec_is_load),
        .i_is_store   (du_o_vec_is_store),
        .i_is_mask_op (du_o_vec_is_mask_op),
        .i_is_strided (du_o_vec_is_strided),
        .i_is_indexed (du_o_vec_is_indexed),
        .i_base_addr  (du_o_vec_base_addr),
        .i_stride     (du_o_vec_stride),
        .o_stall         (stall),
        .o_mem_addr      (o_mem_addr),
        .o_mem_read_en   (o_mem_read_en),
        .i_mem_rdata     (i_mem_rdata),
        .o_mem_write_en  (o_mem_write_en),
        .o_mem_wdata     (o_mem_wdata),
        .o_mem_byte_en   (o_mem_byte_en),
        .o_mem_addr_b    (o_mem_addr_b),
        .o_mem_read_en_b (o_mem_read_en_b),
        .i_mem_rdata_b   (i_mem_rdata_b),
        .o_mem_write_en_b(o_mem_write_en_b),
        .o_mem_wdata_b   (o_mem_wdata_b),
        .o_mem_byte_en_b (o_mem_byte_en_b)
    );

    // Reloj de 10 ns de período (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    // -------------------------------------------------------------------------
    // Tarea: send_alu
    //   Envía una instrucción ALU vectorial y espera a que su resultado
    //   esté disponible en el VRF.
    //
    //   Latencia total: 1 ciclo de decode + 4 etapas del pipeline = 5 posedges.
    //   Flujo:
    //     T0: decode registra la instrucción
    //     T1: Issue lee operandos del VRF y registra en s1
    //     T2: Execute computa el resultado ALU y registra en s2
    //     T3: MEM pasa el resultado y registra en s3
    //     T4: WB escribe el resultado en el VRF (combinacional)
    // -------------------------------------------------------------------------
    task send_alu;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013; // NOP
            @(posedge clk); #1; // Issue captura operandos del VRF
            @(posedge clk); #1; // Execute computa el resultado
            @(posedge clk); #1; // MEM pasa el resultado
            @(posedge clk); #1; // WB escribe en el VRF
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: send_load
    //   Envía una instrucción de carga vectorial y espera que el VRF tenga
    //   el vector completo de 128 bits.
    //
    //   Latencia: 1 decode + Issue + Execute(ACCESS_01) + MEM(ACCESS_23) + WB
    //   = 5 posedges. La carga de los 4 elementos ocurre en 2 ciclos de DCache:
    //   ACCESS_01 en Execute y ACCESS_23 en MEM.
    // -------------------------------------------------------------------------
    task send_load;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013;
            @(posedge clk); #1; // Issue
            @(posedge clk); #1; // Execute: ACCESS_01 (elementos 0 y 1)
            @(posedge clk); #1; // MEM: ACCESS_23 (elementos 2 y 3)
            @(posedge clk); #1; // WB: escribe el vector completo en el VRF
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: send_store
    //   Envía una instrucción de store vectorial y espera que los datos
    //   estén escritos en el DCache.
    //
    //   Latencia: 1 decode + Issue + Execute(SWRITE_01) + MEM(SWRITE_23) + WB.
    //   WB es un pase (los stores no escriben al VRF: o_is_store=1).
    //   Los datos se escriben al DCache en Execute y MEM (puertos A y B).
    // -------------------------------------------------------------------------
    task send_store;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013;
            @(posedge clk); #1; // Issue
            @(posedge clk); #1; // Execute: escribe elem_0 y elem_1
            @(posedge clk); #1; // MEM: escribe elem_2 y elem_3
            @(posedge clk); #1; // WB: pass-through (stores no escriben VRF)
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: check_reg
    //   Verifica el contenido de un registro vectorial del VRF.
    //   Accede directamente al arreglo interno del VRF mediante referencia
    //   jerárquica (dut.vregfile.regs[addr]).
    // -------------------------------------------------------------------------
    task check_reg;
        input [4:0]   addr;
        input [127:0] expected;
        begin
            if (dut.vregfile.regs[addr] === expected) begin
                $display("  PASS v%0d = %h", addr, dut.vregfile.regs[addr]);
                pass = pass + 1;
            end else begin
                $display("  FAIL v%0d: got %h, expected %h",
                         addr, dut.vregfile.regs[addr], expected);
                fail = fail + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: send_raw_consecutive
    //   Envía dos instrucciones consecutivas con un gap de 1 ciclo entre ellas.
    //   Si B tiene dependencia RAW en A, la hazard_unit detecta el peligro
    //   y suspende Issue durante 3 ciclos (burbujas automáticas).
    //   Espera 10 posedges adicionales para asegurar que B complete su WB.
    // -------------------------------------------------------------------------
    task send_raw_consecutive;
        input [31:0] instr_a;
        input [31:0] instr_b;
        begin
            @(posedge clk); #1;
            du_i_instr = instr_a;
            @(posedge clk); #1;
            du_i_instr = instr_b;
            @(posedge clk); #1;
            du_i_instr = 32'h0000_0013;
            repeat(9) @(posedge clk); #1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: check_mem
    //   Verifica el contenido de una posición del DCache simulado.
    // -------------------------------------------------------------------------
    task check_mem;
        input [6:0]  addr;
        input [31:0] expected;
        begin
            if (mem[addr] === expected) begin
                $display("  PASS mem[%0d] = %h", addr, mem[addr]);
                pass = pass + 1;
            end else begin
                $display("  FAIL mem[%0d]: got %h, expected %h",
                         addr, mem[addr], expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_vext.vcd");
        $dumpvars(0, tb_ve_top);
        $display("=== ve_top integration tests ===");

        // Resetear el pipeline durante 2 ciclos
        rst = 1; du_i_instr = 32'h0000_0013;
        repeat(2) @(posedge clk); #1;
        rst = 0;

        // =====================================================================
        // Pre-carga del VRF con datos para las pruebas ALU
        //   v1 = {4{0xA}}   = {10, 10, 10, 10}
        //   v2 = {4{0x14}}  = {20, 20, 20, 20}
        //   v5 = {4{0xFF00FF00}}  (patrón de bits alternados)
        //   v6 = {4{0x0F0F0F0F}}  (patrón de nibbles)
        //   v7 = {4{0xAAAAAAAA}}  (patrón alternado A)
        //   v8 = {4{0x55555555}}  (patrón alternado B)
        // =====================================================================
        dut.vregfile.regs[1]  = {4{32'hA}};
        dut.vregfile.regs[2]  = {4{32'h14}};
        dut.vregfile.regs[5]  = {4{32'hFF00FF00}};
        dut.vregfile.regs[6]  = {4{32'h0F0F0F0F}};
        dut.vregfile.regs[7]  = {4{32'hAAAAAAAA}};
        dut.vregfile.regs[8]  = {4{32'h55555555}};

        // =====================================================================
        // Pre-carga del DCache con datos para las pruebas de carga
        //   Bloque A (byte 0..12):    unit-stride, datos distintivos
        //   Bloque B (byte 20..32):   segunda carga, datos incrementales
        //   Bloque C (byte 80..104):  strided/indexed con step=8
        //   Bloque D (byte 110, 114): mask load/store (VLM/VSM)
        // =====================================================================
        mem[0]  = 32'hDEAD_BEEF;
        mem[4]  = 32'hCAFE_BABE;
        mem[8]  = 32'h1234_5678;
        mem[12] = 32'h9ABC_DEF0;

        mem[20] = 32'h0000_0001;
        mem[24] = 32'h0000_0002;
        mem[28] = 32'h0000_0003;
        mem[32] = 32'h0000_0004;

        mem[80]  = 32'hA1A1_A1A1;
        mem[88]  = 32'hB2B2_B2B2;
        mem[96]  = 32'hC3C3_C3C3;
        mem[104] = 32'hD4D4_D4D4;

        mem[110] = 32'h1234_5678; // fuente VLM: byte[7:0] = 0x78
        mem[114] = 32'h0000_0000; // destino VSM: pre-inicializado en cero

        // =====================================================================
        // Tests ALU
        // =====================================================================

        // VADD v3 = v1 + v2 → {10+20, 10+20, 10+20, 10+20} = {4{30}} = {4{0x1E}}
        $display("\nTest ALU-1: VADD v3 = v1 + v2");
        send_alu(32'h002081D7);
        check_reg(5'd3, {4{32'h1E}});

        // VSUB v4 = v2 - v1 → {20-10, ...} = {4{10}} = {4{0xA}}
        $display("\nTest ALU-2: VSUB v4 = v2 - v1");
        send_alu(32'h40110257);
        check_reg(5'd4, {4{32'hA}});

        // VAND v9 = v5 & v6 → 0xFF00FF00 AND 0x0F0F0F0F = 0x0F000F00
        $display("\nTest ALU-3: VAND v9 = v5 & v6");
        send_alu(32'h0062F4D7);
        check_reg(5'd9, {4{32'h0F000F00}});

        // VOR v10 = v7 | v8 → 0xAAAAAAAA OR 0x55555555 = 0xFFFFFFFF
        $display("\nTest ALU-4: VOR v10 = v7 | v8");
        send_alu(32'h0083E557);
        check_reg(5'd10, {4{32'hFFFFFFFF}});

        // VXOR v11 = v7 ^ v8 → 0xAAAAAAAA XOR 0x55555555 = 0xFFFFFFFF
        $display("\nTest ALU-5: VXOR v11 = v7 ^ v8");
        send_alu(32'h0083C5D7);
        check_reg(5'd11, {4{32'hFFFFFFFF}});

        // VADD v0 = v1 + v2 → v0 es escribible en esta implementación
        $display("\nTest ALU-6: VADD v0 = v1 + v2");
        send_alu(32'h00208057);
        check_reg(5'd0, {4{32'h1E}});

        // VADD v12 = v0 + v2 → 30 + 20 = 50 = 0x32 (cadena de resultados)
        $display("\nTest ALU-7: VADD v12 = v0 + v2");
        send_alu(32'h00200657);
        check_reg(5'd12, {4{32'h32}});

        // =====================================================================
        // Tests LSU — Cargas vectoriales (VLE32)
        //   Formato: opcode=0000111, funct3=110, mop=00, vm=1 (bit[25]=1)
        //   rs1 = dirección base (registro entero, proporcionado por int_rf[1])
        // =====================================================================

        // VLE32.v v13, (x1=0): carga mem[0..12]
        //   v13 = {mem[12], mem[8], mem[4], mem[0]}
        //       = {0x9ABCDEF0, 0x12345678, 0xCAFEBABE, 0xDEADBEEF}
        $display("\nTest LSU-1: VLE32.v v13, (x1)  base=0");
        int_rf[1] = 32'd0;
        send_load(32'h0200_E687);
        check_reg(5'd13, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // VLE32.v v14, (x1=20): carga mem[20..32]
        //   v14 = {4, 3, 2, 1}
        $display("\nTest LSU-2: VLE32.v v14, (x1)  base=20");
        int_rf[1] = 32'd20;
        send_load(32'h0200_E707);
        check_reg(5'd14, {32'd4, 32'd3, 32'd2, 32'd1});

        // =====================================================================
        // Tests LSU — Almacenamientos vectoriales (VSE32)
        //   Formato: opcode=0100111, funct3=110, mop=00, vm=1
        //   vs3 = registro fuente (codificado en el campo rd[11:7])
        // =====================================================================

        // VSE32.v v13, (x1=40): escribe v13 en mem[40..52]
        //   elem_0 (bits[31:0]) se escribe primero en la dirección base
        $display("\nTest LSU-3: VSE32.v v13, (x1)  base=40");
        int_rf[1] = 32'd40;
        send_store(32'h0200_E6A7);
        check_mem(7'd40, 32'hDEAD_BEEF);  // elem_0
        check_mem(7'd44, 32'hCAFE_BABE);  // elem_1
        check_mem(7'd48, 32'h1234_5678);  // elem_2
        check_mem(7'd52, 32'h9ABC_DEF0);  // elem_3

        // VSE32.v v14, (x1=60): escribe v14={4,3,2,1} en mem[60..72]
        $display("\nTest LSU-4: VSE32.v v14, (x1)  base=60");
        int_rf[1] = 32'd60;
        send_store(32'h0200_E727);
        check_mem(7'd60, 32'd1);
        check_mem(7'd64, 32'd2);
        check_mem(7'd68, 32'd3);
        check_mem(7'd72, 32'd4);

        // =====================================================================
        // Tests LSU — Strided (paso variable entre elementos)
        //   VLSE32.v: mop=10 (bits[27:26]), rs2 = registro de stride escalar
        //   El stride escalar viene del banco de registros int_rf[rs2]
        // =====================================================================

        // VLSE32.v v15, (x1=80), x2=8: step=8, accede a mem[80,88,96,104]
        $display("\nTest LSU-5: VLSE32.v v15, (x1=80), x2=8");
        int_rf[1] = 32'd80;
        int_rf[2] = 32'd8;
        send_load(32'h0A20_E787);
        check_reg(5'd15, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // VSSE32.v v15, (x1=100), x2=8: escribe v15 en mem[100,108,116,124]
        $display("\nTest LSU-6: VSSE32.v v15, (x1=100), x2=8");
        int_rf[1] = 32'd100;
        int_rf[2] = 32'd8;
        send_store(32'h0A20_E7A7);
        check_mem(7'd100, 32'hA1A1_A1A1);
        check_mem(7'd108, 32'hB2B2_B2B2);
        check_mem(7'd116, 32'hC3C3_C3C3);
        check_mem(7'd124, 32'hD4D4_D4D4);

        // =====================================================================
        // Tests LSU — Indexed (scatter/gather con offsets en registro vectorial)
        //   vluxei32.v: mop=01 (bits[27:26]), bits[24:20]=vs2 (reg. vectorial)
        //   vs2 contiene un offset de 32 bits por elemento
        //   v2 se pre-carga con offsets {0, 8, 16, 24} para que las direcciones
        //   coincidan con el bloque C (base=80, step=8)
        // =====================================================================
        dut.vregfile.regs[2] = {32'd24, 32'd16, 32'd8, 32'd0};

        // vluxei32.v v16, (x1=80), v2={0,8,16,24}: accede a mem[80,88,96,104]
        $display("\nTest LSU-7: vluxei32.v v16, (x1=80), v2={0,8,16,24}");
        int_rf[1] = 32'd80;
        send_load(32'h0620_E807);
        check_reg(5'd16, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // vsuxei32.v v16, (x1=100), v2={0,8,16,24}: escribe v16 en mem[100,108,116,124]
        $display("\nTest LSU-8: vsuxei32.v v16, (x1=100), v2={0,8,16,24}");
        int_rf[1] = 32'd100;
        send_store(32'h0620_E827);
        check_mem(7'd100, 32'hA1A1_A1A1);
        check_mem(7'd108, 32'hB2B2_B2B2);
        check_mem(7'd116, 32'hC3C3_C3C3);
        check_mem(7'd124, 32'hD4D4_D4D4);

        // =====================================================================
        // Tests LSU — Operaciones de Máscara (VLM / VSM)
        //   VLM carga 1 byte y lo coloca en los bits [7:0] del vector destino,
        //   con los 120 bits superiores en cero.
        //   VSM escribe solo el byte [7:0] de vs3, usando byte_en=4'b0001.
        // =====================================================================

        // VLM.v v17, (x1=110):
        //   mem[110] = 0x12345678 -> byte[7:0] = 0x78
        //   v17 = {120'b0, 8'h78}
        $display("\nTest LSU-9: VLM.v v17, (x1=110)");
        int_rf[1] = 32'd110;
        send_load(32'h02B0_8887);
        check_reg(5'd17, {120'b0, 8'h78});

        // VSM.v v17, (x1=114):
        //   v17[7:0] = 0x78, byte_en = 4'b0001 → solo escribe el byte 0
        //   mem[114] antes: 0x00000000
        //   mem[114] después: 0x00000078
        $display("\nTest LSU-10: VSM.v v17, (x1=114)");
        int_rf[1] = 32'd114;
        send_store(32'h02B0_88A7);
        check_mem(7'd114, 32'h0000_0078);

        // =====================================================================
        // Tests RAW — Peligros de datos por instrucciones consecutivas
        //   La hazard_unit detecta dependencias RAW (Read After Write) entre
        //   instrucciones vectoriales. Cuando la instrucción B necesita leer
        //   un registro que la instrucción A aún no ha escrito, Issue se pausa
        //   durante 3 ciclos (A tarda 3 ciclos: Execute -> MEM -> WB).
        // =====================================================================

        // TEST RAW-1: VADD v20=v1+v2 seguido inmediatamente de VADD v21=v20+v1
        //   Sin hazard: v21 leería el valor viejo de v20.
        //   Con hazard: Issue espera 3 ciclos hasta que A escribe v20.
        //   v1={4{0xA}}, v2 restaurado a {4{0x14}}
        //   A: v20 = 10 + 20 = 30 = {4{0x1E}}
        //   B: v21 = 30 + 10 = 40 = {4{0x28}}
        $display("\nTest RAW-1: back-to-back VADD con dependencia RAW en v20");
        dut.vregfile.regs[2]  = {4{32'h14}};
        dut.vregfile.regs[20] = 128'hDEAD_BEEF_DEAD_BEEF_DEAD_BEEF_DEAD_BEEF;
        send_raw_consecutive(32'h0020_8A57, 32'h001A_0AD7);
        check_reg(5'd20, {4{32'h1E}});
        check_reg(5'd21, {4{32'h28}});

        // TEST RAW-2: VADD v22=v1+v2 seguido de VSUB v23=v22-v1
        //   A: v22 = 10 + 20 = 30 = {4{0x1E}}
        //   B: v23 = 30 - 10 = 20 = {4{0x14}}
        $display("\nTest RAW-2: back-to-back VADD/VSUB con dependencia RAW en v22");
        dut.vregfile.regs[22] = 128'hDEAD_BEEF_DEAD_BEEF_DEAD_BEEF_DEAD_BEEF;
        send_raw_consecutive(32'h0020_8B57, 32'h401B_0BD7);
        check_reg(5'd22, {4{32'h1E}});
        check_reg(5'd23, {4{32'h14}});

        $display("\n=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
