module lsb(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,

    output  reg             mem_ctrl_out_config,
    output  reg             mem_ctrl_out_ls,
    output  reg     [31:0]  mem_ctrl_out_addr,
    output  reg     [31:0]  mem_ctrl_out_data,
    output  reg     [2:0]   mem_ctrl_out_precise,
    input   wire            mem_ctrl_in_config,
    input   wire    [31:0]  mem_ctrl_in_data,

    output  reg             broadcast_config,
    output  reg     [31:0]  broadcast_value,
    output  reg     [3:0]   broadcast_ROB,

    input   wire            alu_in_config,
    input   wire    [3:0]   alu_in_ROB,
    input   wire    [31:0]  alu_in_value,

    input   wire            lsb_in_config,
    input   wire    [3:0]   lsb_in_ROB,
    input   wire    [31:0]  lsb_in_value,

    input   wire            commit_config,
    input   wire    [3:0]   commit_ROB,

    input   wire            inst_config,
    input   wire            inst_store_or_load, // 1 means store
    input   wire    [2:0]   inst_precise,
    input   wire    [4:0]   inst_ROB,
    input   wire    [31:0]  inst_rs1_val,
    input   wire            inst_rs1_need_ROB,
    input   wire    [3:0]   inst_rs1_ROB_id,
    input   wire    [31:0]  inst_rs2_val,
    input   wire            inst_rs2_need_ROB,
    input   wire    [3:0]   inst_rs2_ROB_id,
    input   wire    [31:0]  inst_imm
);
    reg     [15:0]  ls; // 1 for load, 0 for store
    reg     [15:0]  precise [2:0];
    reg     [15:0]  destination_need;
    reg     [15:0]  destination_ROB [3:0];
    reg     [15:0]  destination_add [31:0];
    reg     [15:0]  value_need;
    reg     [15:0]  value_ROB   [3:0];
    reg     [15:0]  value   [31:0];
    reg     [15:0]  offset  [31:0];
    reg     [15:0]  ready;
    reg     [15:0]  ROB_entry;

    reg     [3:0]   head;
    reg     [3:0]   tail;
    reg     is_wait;
    reg     [4:0]   last_commit;

    integer i,j,k,l;
    always @(posedge clk) begin
        if(rst) begin
            is_wait <= 1'b0;
            last_commit <=  5'b10000;
            head    <= 4'b0;
            tail    <= 4'b0;
            mem_ctrl_out_config <= 1'b0;
        end
        else if (rdy) begin
            if (rollback_config) begin
                if (last_commit == 5'b10000) begin
                    is_wait <= 1'b0;
                    head    <= 4'b0;
                    tail    <= 4'b0;
                    mem_ctrl_out_config <= 1'b0;
                end
                else begin
                    tail    <= last_commit + 1;
                end
                if (is_wait && mem_ctrl_in_config) begin
                    is_wait <= 1'b0;
                    head    <= head - 1;
                    mem_ctrl_out_config <= 1'b0;
                    if (last_commit == head) begin
                        last_commit <=  5'b10000;
                    end
                    if (ls[head]) begin
                        broadcast_config    <= 1'b1;
                        broadcast_value <= mem_ctrl_in_data;
                        broadcast_ROB   <= ROB_entry[head];
                    end
                end
            end
            else begin
                if (is_wait && mem_ctrl_in_config) begin
                    is_wait <= 1'b0;
                    head    <= head - 1;
                    mem_ctrl_out_config <= 1'b0;
                    if (last_commit == head) begin
                        last_commit <=  5'b10000;
                    end
                    if (ls[head]) begin
                        broadcast_config    <= 1'b1;
                        broadcast_value <= mem_ctrl_in_data;
                        broadcast_ROB   <= ROB_entry[head];
                    end
                end
                if (!is_wait && ready[head]) begin
                    mem_ctrl_out_config <= 1'b1;
                    is_wait <= 1'b1;
                    if (ls[head]) begin
                        mem_ctrl_out_ls <= 1'b1;
                        mem_ctrl_out_addr   <= destination_add[head] + offset[head];
                        mem_ctrl_out_precise    <= precise[head];
                    end
                    else begin
                        mem_ctrl_out_ls <= 1'b1;
                        mem_ctrl_out_addr   <= destination_add[head] + offset[head];
                        mem_ctrl_out_precise    <= precise[head];
                        mem_ctrl_out_data   <= value[head];
                    end
                end

                if (commit_config) begin
                    for (i = tail; i != head; i = i + 1) begin
                        if ((!ls[i]) && (ROB_entry[i] == commit_ROB)) begin
                            ready[i]    <= 1'b1;
                        end
                    end
                end

                if (alu_in_config) begin
                    for (j = tail; j != head; j = j + 1) begin
                        if (destination_need[j] && (destination_ROB[j] == alu_in_ROB)) begin
                            destination_add[j]  <= alu_in_value;
                        end
                        if (value_need[j] && (value_ROB[j] == alu_in_ROB)) begin
                            value[j]    <= alu_in_value;
                        end
                    end
                end

                if (lsb_in_config) begin
                    for (k = tail; k != head; k = k + 1) begin
                        if (destination_need[k] && (destination_ROB[k] == lsb_in_ROB)) begin
                            destination_add[k]  <= lsb_in_value;
                        end
                        if (value_need[k] && (value_ROB[k] == lsb_in_ROB)) begin
                            value[k]    <= lsb_in_value;
                        end
                    end
                end

                if (inst_config) begin
                    ls[head]    <= !inst_store_or_load;
                    precise[head]   <= inst_precise;
                    ROB_entry[head] <= inst_ROB;
                    destination_need[head]  <= inst_rs1_need_ROB;
                    destination_ROB[head]   <= inst_rs1_ROB_id;                    
                    destination_add[head]   <= inst_rs1_val;
                    value_need[head]    <= inst_rs2_need_ROB;
                    value_ROB[head] <= inst_rs2_ROB_id;
                    value[head] <= inst_rs2_val;
                    offset[head]    <= inst_imm;
                    if (inst_store_or_load) begin
                        ready[head] <= 1'b0;
                    end
                    else begin
                        value_need[head]    <= 1'b0;
                        if ((!inst_rs1_need_ROB) ) begin
                            ready[head] <= 1'b1;
                        end
                    end
                    head    <= head + 1;
                end

                for (l = tail; l != head; l = l + 1) begin
                    if (ls[l] && (!destination_need[l])) begin
                        ready[l]    <= 1'b1;
                    end
                end
            end
        end
    end
endmodule //lsb