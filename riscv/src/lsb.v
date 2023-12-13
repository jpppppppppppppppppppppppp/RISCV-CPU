module lsb(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,

    output  reg             mem_ctrl_out_config,
    output  reg             mem_ctrl_out_ls,
    output  reg     [31:0]  mem_ctrl_out_addr,
    output  reg     [31:0]  mem_ctrl_out_data,
    input   wire            mem_ctrl_in_config,
    input   wire    [31:0]  mem_ctrl_in_data,

    output  reg             broadcast_config,
    output  reg     [31:0]  broadcast_value,
    output  reg     [3:0]   broadcast_ROB,
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
    integer i;
    reg     [4:0]   last_commit;
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
                
            end
        end
    end
endmodule //lsb