module reservestation(
    input   wire                clk,
    input   wire                rst,
    input   wire                rdy,
    
    input   wire                rollback,

    // to ALU
    output  reg                 out_config,
    output  reg     [31:0]      out_value_1,
    output  reg     [31:0]      out_value_2,
    output  reg     [31:0]      out_value_pc,
    output  reg     [6:0]       out_opcode,
    output  reg     [2:0]       out_precise,
    output  reg                 out_more_precise,
    output  reg     [31:0]      out_imm,
    output  reg     [3:0]       out_rob_entry,

    // to handle ins
    input   wire                in_config,
    input   wire    [31:0]      in_value_1,
    input   wire    [3:0]       in_Q1,
    input   wire                in_Q1_need,
    input   wire    [31:0]      in_value_2,
    input   wire    [3:0]       in_Q2,
    input   wire                in_Q2_need,    
    input   wire    [31:0]      in_value_pc,
    input   wire    [6:0]       in_opcode,
    input   wire    [2:0]       in_precise,
    input   wire                in_more_precise,
    input   wire    [31:0]      in_imm,
    input   wire    [3:0]       in_rob_entry,

    // broadcast from alu
    input   wire                alu_config,
    input   wire    [31:0]      alu_val,
    input   wire    [3:0]       alu_rob_entry

    input   wire                lsb_config,
    input   wire    [31:0]      lsb_val,
    input   wire    [3:0]       lsb_rob_entry
);

    reg     [15:0]  ready;
    reg     [15:0]  used;
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
    integer j,k,l;
    always @(posedge clk) begin
        if (rst || rollback) begin
            for (j = 0; j < 16; j = j + 1) begin
                used[j] <= 1'b0;
            end
            out_config  <= 1'b0;
        end
        else begin
            if (rdy) begin
                out_config  <= 1'b0;
                if (ready_entry != 5'b10000) begin
                    out_config  <= 1'b1;
                    out_value_1 <= value1[ready_entry];
                    out_value_2 <= value2[ready_entry];
                    out_value_pc    <= PC[ready_entry];
                    out_opcode  <= opcode[ready_entry];
                    out_precise <= precise[ready_entry];
                    out_more_precise    <= more_precise[ready_entry];
                    out_imm <= imm[ready_entry];
                    out_rob_entry   <= ROB_entry[ready_entry];
                    used[ready_entry]   <= 1'b0;
                end
                if (in_config) begin
                    used[empty_entry]   <= 1'b1;
                    value1[empty_entry] <=  in_value_1;
                    if (in_Q1_need) begin
                        Q1_need[empty_entry]    <= 1'b1;
                        Q1[empty_entry] <= in_Q1;
                        if (alu_config && (in_Q1 == alu_rob_entry)) begin
                            Q1_need[empty_entry]    <= 1'b0;
                            value1[empty_entry] <= alu_val;
                        end
                        else if (lsb_config && (in_Q1 == lsb_rob_entry)) begin
                            Q1_need[empty_entry]    <= 1'b0;
                            value1[empty_entry] <= lsb_val;
                        end
                    end
                    else Q1_need[empty_entry]   <= 1'b0;
                    value2[empty_entry] <=  in_value_2;
                    if (in_Q2_need) begin
                        Q2_need[empty_entry]    <= 1'b1;
                        Q2[empty_entry] <= in_Q2;
                        if (alu_config && (in_Q2 == alu_rob_entry)) begin
                            Q2_need[empty_entry]    <= 1'b0;
                            value2[empty_entry] <= alu_val;
                        end
                        else if (lsb_config && (in_Q2 == lsb_rob_entry)) begin
                            Q2_need[empty_entry]    <= 1'b0;
                            value2[empty_entry] <= lsb_val;
                        end
                    end
                    else Q2_need[empty_entry]   <= 1'b0;
                    PC[empty_entry] <= in_value_pc;
                    opcode[empty_entry] <= in_opcode;
                    precise[empty_entry]    <= in_precise;
                    more_precise[empty_entry]   <= in_more_precise;
                    imm[empty_entry]    <= in_imm;
                    ROB_entry[empty_entry]  <= in_rob_entry;
                end
                if (alu_config) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        if (Q1_need[k] && (Q1[k] == alu_rob_entry)) begin
                            value1[k]   <= alu_val;
                            Q1_need[k]  <= 1'b0;
                        end
                        if (Q2_need[k] && (Q2[k] == alu_rob_entry)) begin
                            value2[k]   <= alu_val;
                            Q2_need[k]  <= 1'b0;
                        end
                    end
                end
                if (lsb_config) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        if (Q1_need[k] && (Q1[k] == lsb_rob_entry)) begin
                            value1[k]   <= lsb_val;
                            Q1_need[k]  <= 1'b0;
                        end
                        if (Q2_need[k] && (Q2[k] == lsb_rob_entry)) begin
                            value2[k]   <= lsb_val;
                            Q2_need[k]  <= 1'b0;
                        end
                    end
                end
            end
        end
    end
endmodule // reservestation