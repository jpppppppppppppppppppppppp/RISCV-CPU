`ifndef DEC
`define DEC
module decoder (
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,
    input   wire            rollback,

    // handle ifetch
    input   wire            inst_rdy,
    input   wire    [31:0]  inst,
    input   wire    [31:0]  inst_PC,
    input   wire            pred_jump,

    // For immediate effect in the next clock, we use wire not reg
    // Query from Register File.
    output  wire     [4:0]   rs1_index,
    input   wire            rs1_dirty,
    input   wire    [3:0]   rs1_rob_entry,
    input   wire    [31:0]  rs1_value,

    output  wire     [4:0]   rs2_index,
    input   wire            rs2_dirty,
    input   wire    [3:0]   rs2_rob_entry,
    input   wire    [31:0]  rs2_value,

    // Query from ROB
    output  wire    [3:0]   rs1_rob_q_entry,
    input   wire    [31:0]  rs1_rob_value,
    input   wire            rs1_rob_rdy,

    output  wire    [3:0]   rs2_rob_q_entry,
    input   wire    [31:0]  rs2_rob_value,
    input   wire            rs2_rob_rdy,

    // To Register File to update dirty bit and ROB Entry index.
    output  reg             done,
    output  reg     [1:0]   ROB_type,
    output  reg     [6:0]   opcode,
    output  reg     [2:0]   precise,
    output  reg             moreprecise,
    output  reg     [4:0]   rd,
    output  reg     [31:0]  rs1_val,
    output  reg             rs1_need_rob,
    output  reg     [3:0]   rs1_rob_id,
    output  reg     [31:0]  rs2_val,
    output  reg             rs2_need_rob,
    output  reg     [3:0]   rs2_rob_id,
    output  reg     [31:0]  imm,
    output  reg             lsb_config,
    output  reg             lsb_store_or_load,  // 1 means store
    output  reg             rs_config,
    output  reg             rf_config,
    output  reg     [3:0]   rob_need,
    output  reg             is_jump,
    output  reg     [31:0]  out_pc,
    output  reg             rob_ready,
    output  reg     [31:0]  rob_ans,
    input   wire    [3:0]   next_empty_rob_entry,
    input   wire            rob_is_full,
    input   wire            lsb_is_full,
    // JALR pause
    output  reg             JALR_need_pause,
    output  reg             JALR_pause_rej,
    output  reg     [31:0]  JALR_PC,
    input   wire            JALR_statu,

    // broadcast from alu
    input   wire            alu_rob_config,
    input   wire    [3:0]   alu_rob_entry,
    input   wire    [31:0]  alu_value,

    // broadcast from lsb
    input   wire            lsb_rob_config,
    input   wire    [3:0]   lsb_rob_entry,
    input   wire    [31:0]  lsb_value
);
`ifdef JY
integer log;
initial begin
    log = $fopen("decoder.log", "w");
end
`endif
    // 31           25 24         20 19         15 14 12 11          7 6       0
    // +--------------+-------------+-------------+-----+-------------+---------+
    // |                   imm[31:12]                   |     rd      | 0110111 | LUI       √
    // |                   imm[31:12]                   |     rd      | 0010111 | AUIPC     √
    // |             imm[20|10:1|11|19:12]              |     rd      | 1101111 | JAL       √
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 1100111 | JALR      √
    // | imm[12|10:5] |     rs2     |     rs1     | 000 | imm[4:1|11] | 1100011 | BEQ       √
    // | imm[12|10:5] |     rs2     |     rs1     | 001 | imm[4:1|11] | 1100011 | BNE       √
    // | imm[12|10:5] |     rs2     |     rs1     | 100 | imm[4:1|11] | 1100011 | BLT       √
    // | imm[12|10:5] |     rs2     |     rs1     | 101 | imm[4:1|11] | 1100011 | BGE       √
    // | imm[12|10:5] |     rs2     |     rs1     | 110 | imm[4:1|11] | 1100011 | BLTU      √
    // | imm[12|10:5] |     rs2     |     rs1     | 111 | imm[4:1|11] | 1100011 | BGEU      √
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 0000011 | LB        √
    // |         imm[11:0]          |     rs1     | 001 |     rd      | 0000011 | LH        √
    // |         imm[11:0]          |     rs1     | 010 |     rd      | 0000011 | LW        √
    // |         imm[11:0]          |     rs1     | 100 |     rd      | 0000011 | LBU       √
    // |         imm[11:0]          |     rs1     | 101 |     rd      | 0000011 | LHU       √
    // |  imm[11:5]   |     rs2     |     rs1     | 000 |  imm[4:0]   | 0100011 | SB        √
    // |  imm[11:5]   |     rs2     |     rs1     | 001 |  imm[4:0]   | 0100011 | SH        √
    // |  imm[11:5]   |     rs2     |     rs1     | 010 |  imm[4:0]   | 0100011 | SW        √
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 0010011 | ADDI      √
    // |         imm[11:0]          |     rs1     | 010 |     rd      | 0010011 | SLTI      √
    // |         imm[11:0]          |     rs1     | 011 |     rd      | 0010011 | SLTIU     √
    // |         imm[11:0]          |     rs1     | 100 |     rd      | 0010011 | XORI      √
    // |         imm[11:0]          |     rs1     | 110 |     rd      | 0010011 | ORI       √
    // |         imm[11:0]          |     rs1     | 111 |     rd      | 0010011 | ANDI      √
    // |   0000000    |    shamt    |     rs1     | 001 |     rd      | 0010011 | SLLI      √
    // |   0000000    |    shamt    |     rs1     | 101 |     rd      | 0010011 | SRLI      √
    // |   0100000    |    shamt    |     rs1     | 101 |     rd      | 0010011 | SRAI      √
    // |   0000000    |     rs2     |     rs1     | 000 |     rd      | 0110011 | ADD       √
    // |   0100000    |     rs2     |     rs1     | 000 |     rd      | 0110011 | SUB       √
    // |   0000000    |     rs2     |     rs1     | 001 |     rd      | 0110011 | SLL       √
    // |   0000000    |     rs2     |     rs1     | 010 |     rd      | 0110011 | SLT       √
    // |   0000000    |     rs2     |     rs1     | 011 |     rd      | 0110011 | SLTU      √
    // |   0000000    |     rs2     |     rs1     | 100 |     rd      | 0110011 | XOR       √
    // |   0000000    |     rs2     |     rs1     | 101 |     rd      | 0110011 | SRL       √
    // |   0100000    |     rs2     |     rs1     | 101 |     rd      | 0110011 | SRA       √
    // |   0000000    |     rs2     |     rs1     | 110 |     rd      | 0110011 | OR        √
    // |   0000000    |     rs2     |     rs1     | 111 |     rd      | 0110011 | AND       √
    // an instruction can be divided into 9 categories:
    // 1. LUI & AUIPC & JAL
    // 2. JALR
    // 3. BEQ & BNE & BLT & BGE & BLTU & BGEU
    // 4. LB & LH & LW & LBU & LHU
    // 5. SB & SH & SW
    // 6. ADDI & SLTI & SLTIU & XORI & ORI & ANDI & SLLI & SRLI & SRAI
    // 7. ADD & SUB & SLL & SLT & SLTU & XOR & SRL & SRA & OR & AND
    // 8. END
    // [6:0] to note opcode, and each have [4:0];
    // and [31:0] rd, [31:0] rs1, [31:0] rs2, [31:0] imm;
    
    // query for rs1 and rs2
    // query for rs1 and rs2 if rely on ROB
    assign  rs1_rob_q_entry = rs1_rob_entry;
    assign  rs2_rob_q_entry = rs2_rob_entry;
    assign  rs1_index   = inst[19:15];
    assign  rs2_index   = inst[24:20];
    reg             is_wait;
    reg     [3:0]   wait_for_rob;
    reg     [31:0]  offset;


    always @(*) begin
        opcode  = inst[6:0];
        precise = inst[14:12];
        moreprecise = inst[30];
        rd  = inst[11:7];
        imm = 32'b0;
        rs1_val     = 32'b0;
        rs2_val     = 32'b0;
        rs1_rob_id  = 4'b0;
        rs2_rob_id  = 4'b0;
        rs1_need_rob    = 1'b0;
        rs2_need_rob    = 1'b0;
        done    = 1'b0;
        lsb_config  = 1'b0;
        rs_config   = 1'b0;
        rf_config   = 1'b0;
        rob_need    = next_empty_rob_entry;
        is_jump = pred_jump;
        out_pc  = inst_PC;
        if (rst || rollback) begin
            is_wait = 1'b0;
            JALR_need_pause = 1'b0;
            JALR_pause_rej  = 1'b0;
        end
        else if (is_wait) begin
                `ifdef JY
                    $fdisplay(log, "%t wait for rob: %D;", $realtime, wait_for_rob);
                `endif
                if (alu_rob_config && (alu_rob_entry == wait_for_rob)) begin
                    is_wait = 1'b0;
                    JALR_pause_rej  = 1'b1;
                    JALR_need_pause = 1'b0;
                    JALR_PC = (alu_value + offset) & 32'b11111111111111111111111111111110;
                    `ifdef JY
                        $fdisplay(log, "%t alu back from JALR; new PC: %H; VAL: %H; OFF: %H;", $realtime, (alu_value + offset) & 32'b11111111111111111111111111111110, alu_value, offset);
                    `endif
                end
                if (lsb_rob_config && (lsb_rob_entry == wait_for_rob)) begin
                    is_wait = 1'b0;
                    JALR_pause_rej  = 1'b1;
                    JALR_need_pause = 1'b0;
                    JALR_PC = (lsb_value + offset) & 32'b11111111111111111111111111111110;
                    `ifdef JY
                        $fdisplay(log, "%t lsb back from JALR; new PC: %H; VAL: %H; OFF: %H;", $realtime, (lsb_value + offset) & 32'b11111111111111111111111111111110, lsb_value, offset);
                    `endif
                end
        end
        else if (!JALR_statu) begin
            JALR_pause_rej  = 1'b0;
        end
        if (inst_rdy && rdy && (!rollback) && (!rst)) begin
            if (!(rob_is_full || lsb_is_full))begin
                if (!rs1_dirty) begin
                    rs1_val = rs1_value;
                end else if (rs1_rob_rdy) begin
                    rs1_val = rs1_rob_value;
                end else if (alu_rob_config && (alu_rob_entry == rs1_rob_entry)) begin
                    rs1_val = alu_value;
                end else if (lsb_rob_config && (lsb_rob_entry == rs1_rob_entry)) begin
                    rs1_val = lsb_value;
                end else begin
                    rs1_need_rob    = 1'b1;
                    rs1_rob_id  = rs1_rob_entry;
                end

                if (!rs2_dirty) begin
                    rs2_val = rs2_value;
                end else if (rs2_rob_rdy) begin
                    rs2_val = rs2_rob_value;
                end else if (alu_rob_config && (alu_rob_entry == rs2_rob_entry)) begin
                    rs2_val = alu_value;
                end else if (lsb_rob_config && (lsb_rob_entry == rs2_rob_entry)) begin
                    rs2_val = lsb_value;
                end else begin
                    rs2_need_rob    = 1'b1;
                    rs2_rob_id  = rs2_rob_entry;
                end
                case (opcode)
                    7'b0110111: begin   // LUI
                        `ifdef JY
                            $fdisplay(log, "%t LUI;", $realtime);
                        `endif
                        imm = {inst[31:12], 12'b0};
                        rob_ans = {inst[31:12], 12'b0};
                        rs_config   = 1'b0;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b1;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                    end
                    7'b0010111: begin   // AUIPC
                        `ifdef JY
                            $fdisplay(log, "%t AUIPC;", $realtime);
                        `endif
                        imm = {inst[31:12], 12'b0};
                        rob_ans = 32'b0;
                        rs_config   = 1'b1;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b0;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                    end
                    7'b1101111: begin               // JAL
                        `ifdef JY
                            $fdisplay(log, "%t JAL;", $realtime);
                        `endif
                        imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                        rob_ans = 32'b0;
                        rs_config   = 1'b1;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b0;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                        rs1_need_rob    = 1'b0;
                        rs2_need_rob    = 1'b0;
                    end
                    7'b1100111: begin               // JALR
                        `ifdef JY
                            $fdisplay(log, "%t JALR;", $realtime);
                        `endif
                        imm = inst_PC + 4;
                        rob_ans = inst_PC + 4;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b1;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                        if (rs1_need_rob) begin
                            `ifdef JY
                                $fdisplay(log, "%t JALR need pause; rob: %D;", $realtime, rs1_rob_entry);
                            `endif
                            JALR_need_pause = 1'b1;
                            JALR_pause_rej  = 1'b0;
                            is_wait = 1'b1;
                            wait_for_rob    = rs1_rob_entry;
                            offset  = {{21{inst[31]}}, inst[30:20]};
                        end
                        else begin
                            `ifdef JY
                                $fdisplay(log, "%t JALR don't pause; new PC: %8H", $realtime, (rs1_val + {{21{inst[31]}}, inst[30:20]}) & 32'b11111111111111111111111111111110);
                            `endif
                            JALR_need_pause = 1'b0;
                            JALR_pause_rej  = 1'b1;
                            is_wait = 1'b0;
                            JALR_PC = (rs1_val + {{21{inst[31]}}, inst[30:20]}) & 32'b11111111111111111111111111111110;
                        end
                    end
                    7'b1100011: begin               // branch
                        `ifdef JY
                            $fdisplay(log, "%t Branch;", $realtime);
                        `endif
                        imm = {{21{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                        rs_config   = 1'b1;
                        rd  = 5'b0;
                        ROB_type    = 2'b10;
                        rob_ready   = 1'b0;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b0;
                    end
                    7'b0000011: begin               // load
                        `ifdef JY
                            $fdisplay(log, "%t Load;", $realtime);
                        `endif
                        imm = {{21{inst[31]}}, inst[30:20]};
                        lsb_config  = 1'b1;
                        lsb_store_or_load   = 1'b0;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b0;
                        rf_config   = 1'b1;
                    end
                    7'b0100011: begin               // store
                        `ifdef JY
                            $fdisplay(log, "%t Store;", $realtime);
                        `endif
                        imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                        lsb_config  = 1'b1;
                        lsb_store_or_load   = 1'b1;
                        rd  = 5'b0;
                        ROB_type    = 2'b01;
                        rob_ready   = 1'b1;
                        rf_config   = 1'b0;
                    end
                    7'b0010011: begin               // op li
                        `ifdef JY
                            $fdisplay(log, "%t Opli;", $realtime);
                        `endif
                        imm = {{21{inst[31]}}, inst[30:20]};
                        rs_config   = 1'b1;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b0;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                    end
                    7'b0110011:begin                // op
                        `ifdef JY
                            $fdisplay(log, "%t Op;", $realtime);
                        `endif
                        rs_config   = 1'b1;
                        ROB_type    = 2'b00;
                        rob_ready   = 1'b0;
                        lsb_config  = 1'b0;
                        rf_config   = 1'b1;
                    end
                endcase
                done    = 1'b1;
                `ifdef JY
                    $fdisplay(log, "%t PC: %D %8H; inst: %8H; opcode: %7B; Q1: %D %1B %D; Q2: %D %1B %D; rd: %D; rob: %D",$realtime, inst_PC, inst_PC, inst, opcode, rs1_index, rs1_need_rob, rs1_rob_id, rs2_index, rs2_need_rob, rs2_rob_id, rd, rob_need);
                `endif
            end
        end
    end
endmodule //decoder
`endif