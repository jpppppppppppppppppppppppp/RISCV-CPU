module reservestation(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,
    
    input   wire            rollback,

    // to ALU
    output  reg             out_config,
    output  reg     [31:0]  out_value_1,
    output  reg     [31:0]  out_value_2,
    output  reg     [31:0]  out_value_pc,
    output  reg     [6:0]   out_opcode,
    output  reg     [2:0]   out_precise,
    output  reg             out_more_precose,
    output  reg     [31:0]  out_imm,
    output  reg     [3:0]   out_rob_entry,

    // to handle ins
    input   wire                in_config,
    input   wire     [31:0]     in_value_1,
    input   wire     [3:0]      in_Q1,
    input   wire                in_Q1_need,
    input   wire     [31:0]     in_value_2,
    input   wire     [3:0]      in_Q2,
    input   wire                in_Q2_need,    
    input   wire     [31:0]     in_value_pc,
    input   wire     [6:0]      in_opcode,
    input   wire     [2:0]      in_precise,
    input   wire                in_more_preco
    input   wire     [31:0]     in_imm,
    input   wire     [3:0]      in_rob_entry
);

    reg     [15:0]  ready;
    reg     [15:0]  used;
    reg     [15:0]  exe;
    reg     [15:0]  value1      [31:0];
    reg     [15:0]  value2      [31:0];
    reg     [15:0]  Q1          [3:0];
    reg     [15:0]  Q1_need;
    reg     [15:0]  Q2          [3:0];
    reg     [15:0]  Q2_need;
    reg     [15:0]  ROB_entry   [3:0];
    reg     [15:0]  PC          [31:0];
    reg     [15:0]  imm         [31:0];
    reg     [15:0]  opcode      [6:0];
    reg     [15:0]  precise     [2:0];
    reg     [15:0]  more_precise;

    // find next ready entry and empty entry;
    reg     [4:0]   ready_entry;
    reg     [4:0]   empty_entry;

    integer i;
    always @(*) begin
        ready_entry = 5'b10000;
        empty_entry = 5'b10000;
        for (i = 0; i < 16; i = i + 1) begin
            if(!used[i]) begin
                empty_entry = i;
            end
            else begin
                if ((!Q1_need[i]) && (!Q2_need)) begin
                    ready[i]    = 1'b1;
                    ready_entry = i;
                end
            end
        end
    end
    integer j;
    always @(posedge clk) begin
        if (rst || rollback) begin
            for (j = 0; j < 16; j = j + 1) begin
                used[j] <= 1'b0;
            end
            out_config  <= 1'b0;
        end
        
    end

endmodule // reservestation