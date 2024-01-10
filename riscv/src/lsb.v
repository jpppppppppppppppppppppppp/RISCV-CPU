`ifndef LSB
`define LSB
module LSB(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,

    output  reg             lsb_is_full,

    output  reg             mem_ctrl_out_config,
    output  reg             mem_ctrl_out_ls,
    output  reg     [31:0]  mem_ctrl_out_addr,
    output  reg     [31:0]  mem_ctrl_out_data,
    output  reg     [2:0]   mem_ctrl_out_precise,
    output  reg     [3:0]   mem_ctrl_out_rob,
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
    input   wire    [3:0]   inst_ROB,
    input   wire    [31:0]  inst_rs1_val,
    input   wire            inst_rs1_need_ROB,
    input   wire    [3:0]   inst_rs1_ROB_id,
    input   wire    [31:0]  inst_rs2_val,
    input   wire            inst_rs2_need_ROB,
    input   wire    [3:0]   inst_rs2_ROB_id,
    input   wire    [31:0]  inst_imm
);
`ifdef JY
integer log;
integer qq;
integer test;
initial begin
    log = $fopen("lsb.log", "w");
    qq = $fopen("write.log", "w");
end
`endif
    reg             ls                  [15:0]; // 1 for load, 0 for store
    reg     [2:0]   precise             [15:0];
    reg             destination_need    [15:0];
    reg     [3:0]   destination_ROB     [15:0];
    reg     [31:0]  destination_add     [15:0];
    reg             value_need          [15:0];
    reg     [3:0]   value_ROB           [15:0];
    reg     [31:0]  value               [15:0];
    reg     [31:0]  offset              [15:0];
    reg             ready               [15:0];
    reg     [3:0]   ROB_entry           [15:0];
    reg             used                [15:0];
    reg             is_commit           [15:0];

    reg     [3:0]   head;
    reg     [3:0]   tail;
    reg             is_wait;
    reg     [4:0]   last_commit;
    reg             empty;

    integer i,j,k,l,m,n;
    always @(posedge clk) begin
        if(rst) begin
            `ifdef JY
                $fdisplay(log, "%t reset: rst: %B", $realtime, rst);
            `endif
            is_wait <= 1'b0;
            last_commit <=  5'b10000;
            head    <= 4'b0;
            tail    <= 4'b0;
            mem_ctrl_out_config <= 1'b0;
            broadcast_config    <= 1'b0;
            lsb_is_full <= 1'b0;
            empty   <= 1'b1;
            for (m = 0; m < 16; m = m + 1) begin
                used[m] <= 1'b0;
                is_commit[m]    <= 1'b0;
                ready[m]    <= 1'b0;
            end
        end
        else if (rdy) begin
            if (rollback_config) begin
                `ifdef JY
                    $fdisplay(log, "%t rollback: %B", $realtime, rollback_config);
                `endif
                for (m = 0; m < 16; m = m + 1) begin
                    if(!is_commit[m]) begin
                        used[m] <= 1'b0;
                        ready[m]    <= 1'b0;
                    end
                end
                if (last_commit == 5'b10000) begin
                    `ifdef JY
                        $fdisplay(log, "%t rollback: no new commit", $realtime);
                    `endif
                    is_wait <= 1'b0;
                    head    <= 4'b0;
                    tail    <= 4'b0;
                    empty   <= 1'b1;
                    lsb_is_full <= 1'b0;
                    mem_ctrl_out_config <= 1'b0;
                    for (n = 0; n < 16; n = n + 1) begin
                        is_commit[n]    <= 1'b0;
                        used[n] <= 1'b0;
                        ready[n]    <= 1'b0;
                    end
                end
                else begin
                    `ifdef JY
                        $fdisplay(log, "%t rollback: exist commited new head: %D", $realtime, last_commit + 1);
                    `endif
                    head    <= last_commit + 1;
                    empty   <= 1'b0;
                    lsb_is_full <= ((last_commit + 1'b1) == tail);
                end
                if (is_wait && mem_ctrl_in_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t rollback: have work end", $realtime);
                    `endif
                    is_wait <= 1'b0;
                    tail    <= tail + 1;
                    mem_ctrl_out_config <= 1'b0;
                    used[tail]  <= 1'b0;
                    is_commit[tail] <= 1'b0;
                    ready[tail] <= 1'b0;
                    lsb_is_full <= 1'b0;
                    empty   <= (tail == last_commit);
                    if (last_commit == tail) begin
                        last_commit <=  5'b10000;
                        `ifdef JY
                            $fdisplay(log, "%t rollback: now no new commited;", $realtime);
                        `endif
                        head    <= 4'b0;
                        tail    <= 4'b0;
                        empty   <= 1'b1;
                    end
                    if (last_commit == 5'b10000) begin
                        `ifdef JY
                            $fdisplay(log, "%t rollback: no new commit", $realtime);
                        `endif
                        is_wait <= 1'b0;
                        head    <= 4'b0;
                        tail    <= 4'b0;
                        empty   <= 1'b1;
                        lsb_is_full <= 1'b0;
                        mem_ctrl_out_config <= 1'b0;
                        for (n = 0; n < 16; n = n + 1) begin
                            is_commit[n]    <= 1'b0;
                            used[n] <= 1'b0;
                            ready[n]    <= 1'b0;
                        end
                    end
                    if (ls[tail]) begin
                        broadcast_config    <= 1'b0;
                    end
                    else begin
                        broadcast_config    <= 1'b0;
                    end
                end
            end
            else begin
                broadcast_config    <= 1'b0;
                if (is_wait && mem_ctrl_in_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t have work end", $realtime);
                    `endif
                    is_wait <= 1'b0;
                    tail    <= tail + 1;
                    lsb_is_full <= 1'b0;
                    empty   <= (tail + 1'b1) == head;
                    mem_ctrl_out_config <= 1'b0;
                    used[tail]  <= 1'b0;
                    is_commit[tail] <= 1'b0;
                    ready[tail] <= 1'b0;
                    if (last_commit == tail) begin
                        `ifdef JY
                            $fdisplay(log, "%t now no new commited;", $realtime);
                        `endif
                        last_commit <=  5'b10000;
                    end
                    if (ls[tail]) begin
                        `ifdef JY
                            $fdisplay(log, "%t load broadcast id: %D; rob: %D; value: %D;", $realtime, tail, ROB_entry[tail], mem_ctrl_in_data);
                        `endif
                        broadcast_config    <= 1'b1;
                        broadcast_value <= mem_ctrl_in_data;
                        broadcast_ROB   <= ROB_entry[tail];
                    end
                end
                if (!is_wait && ready[tail] && used[tail]) begin
                    mem_ctrl_out_config <= 1'b1;
                    mem_ctrl_out_rob    <= ROB_entry[tail];
                    is_wait <= 1'b1;
                    if (ls[tail]) begin
                        `ifdef JY
                            $fdisplay(log, "%t push load %B; tail: %D; head: %D; ROB: %D; ADDR:%H %H", $realtime, ls[tail], tail, head, ROB_entry[tail], destination_add[tail] , offset[tail]);
                        `endif
                        mem_ctrl_out_ls <= 1'b1;
                        mem_ctrl_out_addr   <= destination_add[tail] + offset[tail];
                        mem_ctrl_out_precise    <= precise[tail];
                    end
                    else begin
                        `ifdef JY
                            $fdisplay(qq, "ADDR: %H; VAL: %H;", destination_add[tail] + offset[tail], value[tail]);
                            $fdisplay(log, "%t push store %B; tail: %D; head: %D; ROB: %D; ADDR:%H %H VAL:%H", $realtime, ls[tail], tail, head, ROB_entry[tail], destination_add[tail] , offset[tail], value[tail]);
                        `endif
                        mem_ctrl_out_ls <= 1'b0;
                        mem_ctrl_out_addr   <= destination_add[tail] + offset[tail];
                        mem_ctrl_out_precise    <= precise[tail];
                        mem_ctrl_out_data   <= value[tail];
                    end
                end

                if (commit_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t commit tail: %D head: %D ROB: %D", $realtime, tail, head, commit_ROB);
                        for (test = 0; test < 16; test = test + 1) begin
                           $fdisplay(log, "%t %D ROB: %D; ls: %B; ready: %B;", $realtime, test, ROB_entry[test], ls[test], ready[test]);
                        end
                    `endif
                    for (i = 0; i < 16; i = i + 1) begin
                        if (used[i] && (!ls[i]) && (ROB_entry[i] == commit_ROB) && (!is_commit[i])) begin
                            `ifdef JY
                                $fdisplay(log, "%t lscommit %B; index: %D; ROB: %D->%D;", $realtime, ls[i], i, commit_ROB,ROB_entry[i]);
                            `endif
                            ready[i]    <= 1'b1;
                            last_commit <= i;
                            is_commit[i]    <= 1'b1;
                        end
                    end
                end

                if (alu_in_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t alu_config tail: %D; head: %D; ROB: %D;", $realtime, tail, head, alu_in_ROB);
                    `endif
                    for (j = 0; j < 16; j = j + 1) begin
                        if (used[j] && destination_need[j] && (destination_ROB[j] == alu_in_ROB)) begin
                            `ifdef JY
                                $fdisplay(log, "%t alu change destination: index: %D; ROB: %D->%D; value: %D;", $realtime, j, destination_ROB[j], alu_in_ROB, alu_in_value);
                            `endif
                            destination_add[j]  <= alu_in_value;
                            destination_need[j] <= 1'b0;
                        end
                        if (used[j] && value_need[j] && (value_ROB[j] == alu_in_ROB)) begin
                            `ifdef JY
                                $fdisplay(log, "%t alu change value: index: %D; ROB: %D->%D; value: %D;", $realtime, j, value_ROB[j], alu_in_ROB, alu_in_value);
                            `endif
                            value[j]    <= alu_in_value;
                            value_need[j]   <= 1'b0;
                        end
                    end
                end

                if (lsb_in_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t lsb_config tail: %D; head: %D; ROB: %D;", $realtime, tail, head, lsb_in_ROB);
                    `endif
                    for (k = 0; k < 16; k = k + 1) begin
                        if (used[k] && destination_need[k] && (destination_ROB[k] == lsb_in_ROB)) begin
                            `ifdef JY
                                $fdisplay(log, "%t lsb change destination: index: %D; ROB: %D->%D; value: %D;", $realtime, k, destination_ROB[k], lsb_in_ROB, lsb_in_value);
                            `endif
                            destination_add[k]  <= lsb_in_value;
                            destination_need[k] <= 1'b0;
                        end
                        if (used[k] && value_need[k] && (value_ROB[k] == lsb_in_ROB)) begin
                            value[k]    <= lsb_in_value;
                            value_need[k]   <= 1'b0;
                            `ifdef JY
                                $fdisplay(log, "%t lsb change value: index: %D; ROB: %D->%D; value: %D;", $realtime, k, value_ROB[k], lsb_in_ROB, lsb_in_value);
                            `endif                            
                        end
                    end
                end

                if (inst_config) begin
                    `ifdef JY
                        $fdisplay(log, "%t push new task: ls: %B; tail: %D; head: %D; ROB: %D; ADDR:%H; VAL:%H; OFFSET:%H;", $realtime, !inst_store_or_load, tail, head, inst_ROB, inst_rs1_val, inst_rs2_val, inst_imm);
                    `endif
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
                    used[head]  <= 1'b1;
                    empty   <= 1'b0;
                    lsb_is_full <= (head + 1'b1) == tail;
                    ready[head] <= 1'b0;
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

                for (l = 0; l < 16; l = l + 1) begin
                    if (used[l] && ls[l] && (!destination_need[l])) begin
                        `ifdef JY
                            $fdisplay(log, "%t change ready status: id: %D; ls: %B;", $realtime, l, ls[l]);
                        `endif
                        ready[l]    <= 1'b1;
                    end
                end
            end
        end
    end
endmodule //LSB
`endif