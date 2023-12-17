`ifndef RF
`define RF
module registerfile(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,
    // query from decoder
    // input: rs_index, output: rs_is_dirty, rs_rob_entry_id, rs_value
    input   wire    [4:0]   rs1_index,
    output  reg             rs1_dirty,
    output  reg     [3:0]   rs1_rob_entry,
    output  reg     [31:0]  rs1_val,

    input   wire    [4:0]   rs2_index,
    output  reg             rs2_dirty,
    output  reg     [3:0]   rs2_rob_entry,
    output  reg     [31:0]  rs2_val,

    // commit reg write
    input   wire            commit_config,
    input   wire    [4:0]   rs_to_write_id,
    input   wire    [31:0]  rs_to_write_val,
    input   wire    [3:0]   commit_rob_id,

    // add dependency from decoder by opcode
    input   wire            decoder_done,
    input   wire    [4:0]   rd,
    input   wire    [3:0]   rob_need
);
    reg     [31:0]  reg_val     [31:0];
    reg     [3:0]   rob_entry   [31:0];
    reg             dirty       [31:0];
    wire            is_commit   = commit_config && (rs_to_write_id != 5'b0);
    wire            need_change_dirty   = is_commit && dirty[rs_to_write_id] && (rob_entry[rs_to_write_id] == commit_rob_id);
    // handle query
    always @(*) begin
        if(is_commit && (rs1_index == rs_to_write_id) && need_change_dirty) begin
            rs1_dirty   = 1'b0;
            rs1_rob_entry   = 4'b0;
            rs1_val = rs_to_write_val;
        end
        else begin
            rs1_dirty   = dirty[rs1_index];
            rs1_rob_entry   = rob_entry[rs1_index];
            rs1_val = reg_val[rs1_index];
        end

        if(is_commit && (rs2_index == rs_to_write_id) && need_change_dirty) begin
            rs2_dirty   = 1'b0;
            rs2_rob_entry   = 4'b0;
            rs2_val = rs_to_write_val;
        end
        else begin
            rs2_dirty   = dirty[rs2_index];
            rs2_rob_entry   = rob_entry[rs2_index];
            rs2_val = reg_val[rs2_index];
        end        
    end
    
    // hand opcode
    integer i,j;
    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                dirty[i]    <= 1'b0;
                rob_entry[i]    <= 4'b0;
                reg_val[i]  <= 32'b0;
            end
        end
        if(rdy) begin
            if(is_commit) begin
                reg_val[rs_to_write_id] <= rs_to_write_val;
                if (need_change_dirty) begin
                    dirty[rs_to_write_id]   <= 1'b0;
                    rob_entry[rs_to_write_id]   <= 4'b0;
                end
            end

            if(decoder_done && (rd != 0)) begin
                dirty[rd]   <= 1'b1;
                rob_entry[rd]   <= rob_need;
            end

            if(rollback_config) begin
                for (j = 0; j < 32; j = j + 1) begin
                    dirty[j]    <= 1'b0;
                    rob_entry[j]    <= 4'b0;
                end
            end
        end
    end
endmodule //registerfile
`endif