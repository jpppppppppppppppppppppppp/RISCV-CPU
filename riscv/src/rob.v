module ROB(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    output  reg             rollback_config,
    output  reg     [3:0]   nxt_empty_ROB_id,
    
    input   wire            decoder_done,
    input   wire    [1:0]   ROB_type,
    input   wire    [4:0]   inst_rd,
    input   wire    [31:0]  inst_PC, // for update
    input   wire            inst_predict_jump,

    // handle query from decoder
    input   wire    [3:0]   rs1_rob_q_entry,
    output  reg     [31:0]  rs1_rob_value,
    output  reg             rs1_rob_rdy,
    input   wire    [3:0]   rs2_rob_q_entry,
    output  reg     [31:0]  rs2_rob_value,
    output  reg             rs2_rob_rdy,   

    output  reg             commit_config,
    output  reg             rob_full,
);
    reg     [15:0]  type    [1:0]; // 00 for RegisterWrite, 01 for MemoryWrite, 10 for Branch, 11 for END
    reg     [15:0]  ready;
    reg     [15:0]  predict;
    reg     [15:0]  PC      [31:0];
    reg     [15:0]  rd      [4:0];
    reg     [15:0]  value   [31:0];

    reg     [3:0]   head;
    reg     [3:0]   tail;
    reg             empty;
    always @(*) begin
        rs1_rob_value   = value[rs1_rob_q_entry];
        rs1_rob_rdy = ready[rs1_rob_q_entry];
        rs2_rob_value   = value[rs2_rob_q_entry];
        rs2_rob_rdy = ready[rs2_rob_q_entry];
    end
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            head    <= 4'b0;
            tail    <= 4'b0;
            empty   <= 1'b1;
            commit_config   <= 1'b0;
            nxt_empty_ROB_id    <= 4'b0;
            rob_full    <= 1'b0;
            rollback_config <= 1'b0;
        end
        else if (rdy) begin
            
        end
    end
endmodule //ROB
