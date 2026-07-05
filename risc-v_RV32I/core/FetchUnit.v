// --------------------------------------------------------------------------------------------------------------
// -- File Name        : FetchUnit.v
// -- Module Name      : fetch
// -- Developers       : Kristhel Quesada, David Rodriguez
// --
// -- Description      : Instruction Fetch Unit
// --                      [x] Create the PC and PC+4
// --                      [x] Read instructions from memory (32 bits)
// --                      [x] Redirect PC if there's a jump or branch instruction
// --                      [ ] Branch Predictor
// --                      [x] Stall management // Cambio
// --
// -- Tested on        :
// -- Last modified on : March-2025
// -- Notes            :
// --
// -- Copyright        : Refer to LICENSE.md.
// --------------------------------------------------------------------------------------------------------------

module fetch #(
    parameter INITIAL_PC = 32'h0000_0000,
    parameter XLEN       = 32,
    parameter ILEN       = 32,
    parameter BR_OFFSET  = 12
)(
    // General Connections
    input wire CLK, RST,
    input wire STALL,                       // Cambio

    // Fetch-ICache Connections
    input wire [ILEN-1:0] i_instruction,    // Instruction fetched from ICache
    input wire [XLEN-1:0] i_pc,             // PC of instructions fetched from ICache
    output reg [XLEN-1:0] o_pc_imem,        // PC's instruction that will be fetched from ICache

    // Execute-Fetch Connections
    input wire [XLEN-1:0] i_pc_upd,         // Next PC when jump or branch conditions comes up.
    input wire          i_take_br,          // Flag that triggers bubbles and PC updates
    input wire          i_take_jmp,         // Flag that triggers bubbles and PC updates

    // Fetch-Decode Connections
    output reg [ILEN-1:0]  o_instruction,   // Instruction that'll be decode
    output reg [XLEN-1:0]  o_pc,            // PC's instruction that'll be decode
    output reg             o_bubble         // Outputs a NOP after flushing (br/jmp taken)
);

//===============================================================================================================
// Registers
//===============================================================================================================
wire [XLEN-1:0] next_pc;                      // Register to the next pc.
wire [XLEN-1:0] curr_pc;                      // Register to the actual pc.


//===============================================================================================================
// State and output memory
//===============================================================================================================
always @(posedge CLK) begin
    if (RST) begin
        o_pc          <= 0;
        o_pc_imem     <= INITIAL_PC;
        o_instruction <= 0;
        o_bubble      <= 0;                  // Cambio
    end else if (STALL) begin                // Cambio
    end else begin

        if (i_take_br | i_take_jmp) begin
            o_pc_imem     <= i_pc_upd;           // Updates a whole new PC
            o_pc          <= 0;                  // NOP
            o_instruction <= 0;                  // NOP
            o_bubble      <= 1;                  // Signal to say to de DU to make a NOT

        end else begin

            if (o_bubble) begin
                o_instruction <= 0;              // NOP if bubble still on
                o_pc          <= 0;              // NOP if bubble still on

            end else begin
                o_instruction <= i_instruction;  // Sends PC's instruction fetched
                o_pc          <= i_pc;           // Sends PC fetched
            end

            // Once memory received the correct PC or under normal conditions
            o_pc_imem     <= next_pc;            // Now sends PC+4
            o_bubble      <= 0;                  // Turns off bubble if enabled

        end
    end
end

//===============================================================================================================
// Middle Assignments
//===============================================================================================================

assign curr_pc = o_pc_imem;
assign next_pc = curr_pc + 32'h0000_0004;

endmodule
