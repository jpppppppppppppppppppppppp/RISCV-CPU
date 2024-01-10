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
    output  wire             rs1_dirty,
    output  wire     [3:0]   rs1_rob_entry,
    output  wire     [31:0]  rs1_val,

    input   wire    [4:0]   rs2_index,
    output  wire             rs2_dirty,
    output  wire     [3:0]   rs2_rob_entry,
    output  wire     [31:0]  rs2_val,

    // commit reg write
    input   wire            commit_config,
    input   wire    [4:0]   rs_to_write_id,
    input   wire    [31:0]  rs_to_write_val,
    input   wire    [3:0]   commit_rob_id,

    `ifdef JY
    output  wire    [1023:0]  allregs,
    `endif

    // add dependency from decoder by opcode
    input   wire            decoder_done,
    input   wire    [4:0]   rd,
    input   wire    [3:0]   rob_need
);
`ifdef JY
    genvar y;
    generate
        for (y = 0; y < 32; y = y + 1) begin
            assign allregs[y * 32 + 31: y * 32] = reg_val[y];
        end
    endgenerate
integer log;
initial begin
    log = $fopen("rf.log", "w");
end
`endif
    reg     [31:0]  reg_val     [31:0];
    reg     [3:0]   rob_entry   [31:0];
    reg             dirty       [31:0];
    wire            is_commit   = commit_config && (rs_to_write_id != 5'b0);
    wire            need_change_dirty   = is_commit && dirty[rs_to_write_id] && (rob_entry[rs_to_write_id] == commit_rob_id);
    // handle query
    wire    rs1_hit = is_commit && (rs1_index == rs_to_write_id) && need_change_dirty;
    assign  rs1_dirty   = (rs1_hit) ? (1'b0) : dirty[rs1_index];
    assign  rs1_rob_entry   = (rs1_hit) ? (4'b0) : rob_entry[rs1_index];
    assign  rs1_val = (rs1_hit) ? (rs_to_write_val) : reg_val[rs1_index];
    
    wire    rs2_hit = is_commit && (rs2_index == rs_to_write_id) && need_change_dirty;
    assign  rs2_dirty   = (rs2_hit) ? (1'b0) : dirty[rs2_index];
    assign  rs2_rob_entry   = (rs2_hit) ? (4'b0) : rob_entry[rs2_index];
    assign  rs2_val = (rs2_hit) ? (rs_to_write_val) : reg_val[rs2_index];
    
    // hand opcode
    integer i,j;
    always @(posedge clk) begin
        if(rst) begin
            `ifdef JY
                $fdisplay(log, "%t reset: rst: %B", $realtime, rst);
            `endif
            for (i = 0; i < 32; i = i + 1) begin
                dirty[i]    <= 1'b0;
                rob_entry[i]    <= 4'b0;
                reg_val[i]  <= 32'b0;
            end
        end
        if(rdy) begin
            if(is_commit) begin
                `ifdef JY
                    $fdisplay(log, "#%t commit reg write: id: %D; val: %D; write-rob: %D; dirty-rob: %D; change: %B;", $realtime, rs_to_write_id, rs_to_write_val, commit_rob_id, rob_entry[rs_to_write_id], need_change_dirty);
                `endif
                reg_val[rs_to_write_id] <= rs_to_write_val;
                if (need_change_dirty) begin
                    dirty[rs_to_write_id]   <= 1'b0;
                    rob_entry[rs_to_write_id]   <= 4'b0;
                end
            end

            if(decoder_done && (rd != 0)) begin
                `ifdef JY
                    $fdisplay(log, "#%t add rely: rs: %D; rob: %D;", $realtime, rd, rob_need);
                `endif
                dirty[rd]   <= 1'b1;
                rob_entry[rd]   <= rob_need;
            end

            if(rollback_config) begin
                `ifdef JY
                    $fdisplay(log, "%t reset: rollback_config: %B", $realtime, rollback_config);
                `endif
                for (j = 0; j < 32; j = j + 1) begin
                    dirty[j]    <= 1'b0;
                    rob_entry[j]    <= 4'b0;
                end
            end
        end
    end
endmodule //registerfile
`endif