module ALU(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,
    // from rs
    input   wire            in_config,
    input   wire    [31:0]  in_a,
    input   wire    [31:0]  in_b,
    input   wire    [31:0]  in_PC,
    input   wire    [6:0]   in_opcode,
    input   wire    [2:0]   in_precise,
    input   wire    [31:0]  in_imm,
    input   wire    [3:0]   in_rob_entry,
    
    // end exe
    output  reg     [31:0]  out_val,
    output  reg             out_need_jump,
    output  reg     [31:0]  out_jump_pc,
    output  reg     [3:0]   out_rob_entry,
    output  reg             out_config

);
    always @(*) begin
        
    end
endmodule //ALU