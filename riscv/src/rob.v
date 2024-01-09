`ifndef ROB
`define ROB
module ROB(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback,

    output  reg             rollback_config,
    output  reg     [31:0]  rollback_pc,
    output  reg     [3:0]   nxt_empty_ROB_id,
    
    input   wire            decoder_done,
    input   wire    [1:0]   ROB_type,
    input   wire    [4:0]   inst_rd,
    input   wire    [31:0]  inst_PC, // for update
    input   wire            inst_predict_jump,
    input   wire            inst_ready,
    input   wire    [31:0]  inst_ans,

    // handle query from decoder
    input   wire    [3:0]   rs1_rob_q_entry,
    output  reg     [31:0]  rs1_rob_value,
    output  reg             rs1_rob_rdy,
    input   wire    [3:0]   rs2_rob_q_entry,
    output  reg     [31:0]  rs2_rob_value,
    output  reg             rs2_rob_rdy,   

    output  reg             commit_config,
    output  reg     [3:0]   commit_ROB,
    output  reg     [31:0]  commit_value,

    output  reg             rob_full,

    output  reg             commit_reg_config,
    output  reg     [4:0]   commit_reg_id,
    output  reg     [31:0]  commit_reg_value,
    output  reg     [3:0]   commit_reg_rob,

    output  reg             commit_lsb_config,
    output  reg     [3:0]   commit_lsb_rob,

    output  reg             commit_update_config,
    output  reg     [31:0]  commit_update_pc,
    output  reg             commit_update_jump,

    `ifdef JY
    input   wire    [1023:0]    reg_debugger,
    `endif

    input   wire            alu_config,
    input   wire            alu_need_jump,
    input   wire    [31:0]  alu_jump_pc,
    input   wire    [31:0]  alu_val,
    input   wire    [3:0]   alu_rob_entry,

    input   wire            lsb_config,
    input   wire    [3:0]   lsb_rob_entry,
    input   wire    [31:0]  lsb_value
);
`ifdef JY
integer log;
integer co;
integer pai;
initial begin
    log = $fopen("rob.log", "w");
    co = $fopen("commit.log", "w");
    pai = $fopen("pai.log", "w");
end
`endif
    reg     [1:0]   type    [15:0]; // 00 for RegisterWrite, 01 for MemoryWrite, 10 for Branch
    reg             ready   [15:0];
    reg             predict [15:0];
    reg             jump    [15:0];
    reg     [31:0]  PC      [15:0];
    reg     [4:0]   rd      [15:0];
    reg     [31:0]  value   [15:0];

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
        if (rst || rollback) begin
            `ifdef JY
                $fdisplay(log, "%t ROB reset: rst: %B rollback: %B", $realtime, rst, rollback);
            `endif
            head    <= 4'b0;
            tail    <= 4'b0;
            empty   <= 1'b1;
            commit_config   <= 1'b0;
            commit_ROB  <= 4'b0;
            commit_value    <= 32'b0;
            nxt_empty_ROB_id    <= 4'b0;
            rob_full    <= 1'b0;
            rollback_config <= 1'b0;
            commit_reg_config   <= 1'b0;
            commit_reg_id   <= 5'b0;
            commit_reg_value    <= 32'b0;
            commit_reg_rob  <= 4'b0;
            commit_lsb_config   <= 1'b0;
            commit_lsb_rob  <= 4'b0;
            commit_update_config    <= 1'b0;
            commit_update_pc    <= 32'b0;
            commit_update_jump  <= 1'b0;
        end
        else if (rdy) begin
            nxt_empty_ROB_id    <= head;
            rob_full    <= (!empty) && (head == tail);
            commit_reg_config   <= 1'b0;
            commit_reg_id   <= 5'b0;
            commit_reg_value    <= 32'b0;
            commit_reg_rob  <= 4'b0;
            commit_lsb_config   <= 1'b0;
            commit_lsb_rob  <= 4'b0;
            commit_update_config    <= 1'b0;
            commit_update_pc    <= 32'b0;
            commit_update_jump  <= 1'b0;
            if ((!empty) && ready[tail]) begin
                $fdisplay(pai, "%8H %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D %D", PC[tail], reg_debugger[31:0], reg_debugger[63:32], reg_debugger[95:64], reg_debugger[127:96], reg_debugger[159:128], reg_debugger[191:160], reg_debugger[223:192], reg_debugger[255:224], reg_debugger[287:256], reg_debugger[319:288], reg_debugger[351:320], reg_debugger[383:352], reg_debugger[415:384], reg_debugger[447:416], reg_debugger[479:448], reg_debugger[511:480], reg_debugger[543:512], reg_debugger[575:544], reg_debugger[607:576], reg_debugger[639:608], reg_debugger[671:640], reg_debugger[703:672], reg_debugger[735:704], reg_debugger[767:736], reg_debugger[799:768], reg_debugger[831:800], reg_debugger[863:832], reg_debugger[895:864], reg_debugger[927:896], reg_debugger[959:928], reg_debugger[991:960], reg_debugger[1023:992]);
                commit_config   <= 1'b1;
                commit_ROB  <= tail;
                commit_value    <= value[tail];
                tail    <= tail + 1;
                empty   <= (head == (tail + 1)) && (!decoder_done);
                rob_full    <= (head == tail) && decoder_done;
                if (type[tail] == 2'b00) begin
                    commit_reg_config   <= 1'b1;
                    commit_reg_id   <= rd[tail];
                    commit_reg_value    <= value[tail];
                    commit_reg_rob  <= tail;
                    `ifdef JY
                        //$fdisplay(logfile, "@%t", $realtime);
                        $fdisplay(co, "%8H %t ROB commit reg write rob-id: %D; reg-id:%D; reg-value: %D", PC[tail], $realtime, tail, rd[tail], value[tail]);
                        $fdisplay(log, "%t ROB commit reg write rob-id: %D; inst_PC: %8H; reg-id:%D; reg-value: %D", $realtime, tail, PC[tail], rd[tail], value[tail]);
                    `endif
                end
                else if (type[tail] == 2'b01) begin
                    commit_lsb_config   <= 1'b1;
                    commit_lsb_rob  <= tail;
                    `ifdef JY
                        //$fdisplay(logfile, "@%t", $realtime);
                        $fdisplay(co, "%8H %t ROB commit mem write rob-id: %D;", PC[tail], $realtime, tail);
                        $fdisplay(log, "%t ROB commit mem write rob-id: %D; inst_PC: %8H;", $realtime, tail, PC[tail]);
                    `endif
                end
                else if (type[tail] == 2'b10) begin
                    `ifdef JY
                        //$fdisplay(logfile, "@%t", $realtime);
                        $fdisplay(co, "%8H %t ROB commit branch rob-id: %D;", PC[tail], $realtime, tail);
                        $fdisplay(log, "%t ROB commit branch rob-id: %D; inst_PC: %8H;", $realtime, tail, PC[tail]);
                    `endif
                    commit_update_config    <= 1'b1;
                    commit_update_pc    <= PC[tail];
                    commit_update_jump  <= jump[tail];
                    if (predict[tail] != jump[tail]) begin
                        rollback_config <= 1'b1;
                        rollback_pc <= value[tail];
                        `ifdef JY
                            $fdisplay(co, "%t ROB need rollback: new-PC: %8H", $realtime, value[tail]);
                            $fdisplay(log, "%t ROB need rollback: new-PC: %8H", $realtime, value[tail]);
                        `endif
                    end
                end
            end
            else begin
                `ifdef JY
                    //$fdisplay(logfile, "@%t", $realtime);
                    $fdisplay(log, "%t ROB don't commit: now: tail: %D; head: %D; empty: %B;", $realtime, tail, head, empty);
                `endif
            end
            if (decoder_done && (!rob_full)) begin
                head    <= head + 1;
                nxt_empty_ROB_id    <= head + 1;
                rob_full    <= (!empty) && (!ready[tail]) && ((head + 1) == tail);
                empty <= 1'b0;
                type[head]  <= ROB_type;
                PC[head]    <= inst_PC;
                rd[head]    <= inst_rd;
                predict[head]   <= inst_predict_jump;
                ready[head] <= inst_ready;
                value[head] <= inst_ans;
                `ifdef JY
                    $fdisplay(log, "%t ROB push new inst: rob-id: %D; value: %D; inst-PC: %8H; inst-type: %2B; rd: %D; ready: %B; full: %B", $realtime, head, inst_ans, inst_PC, ROB_type, inst_rd, inst_ready, (!empty) && (!ready[tail]) && ((head + 1) == tail));
                `endif
            end
            if (alu_config) begin
                `ifdef JY
                    $fdisplay(log, "%t ROB: alu_config: rob-id: %D; need_jump: %B; jump_where: %8H; alu_val: %D;", $realtime, alu_rob_entry, alu_need_jump, alu_jump_pc, alu_val);
                `endif
                if (type[alu_rob_entry] == 2'b00) begin
                    ready[alu_rob_entry]    <= 1'b1;
                    value[alu_rob_entry]    <= alu_val;
                    `ifdef JY
                        $fdisplay(log, "%t ROB change reg write ready: rob-id: %D", $realtime, alu_rob_entry);
                    `endif
                end
                else if (type[alu_rob_entry] == 2'b10) begin
                    ready[alu_rob_entry]    <= 1'b1;
                    jump[alu_rob_entry] <= alu_need_jump;
                    value[alu_rob_entry]    <= alu_jump_pc;
                    `ifdef JY
                        $fdisplay(log, "%t ROB change branch ready: rob-id: %D; need_jump: %B; predict: %B; jump_PC: %8H; PC: %8H;", $realtime, alu_rob_entry, alu_need_jump, predict[alu_rob_entry], alu_jump_pc, PC[alu_rob_entry]);
                    `endif
                end
            end
            if (lsb_config) begin
                `ifdef JY
                    $fdisplay(log, "%t ROB: lsb_config: rob-id: %D; lsb_value: %D; rob_type: %2B", $realtime, lsb_rob_entry, lsb_value, type[lsb_rob_entry]);
                `endif
                ready[lsb_rob_entry]    <= 1'b1;
                value[lsb_rob_entry]    <= lsb_value;
            end
        end
    end
endmodule //ROB
`endif