module decoder (
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,
    input   wire            rollback,

    // handle ifetch
    input   wire            inst_rdy,
    input   wire    [31:0]  inst,
    input   wire    [31:0]  inst_PC,
    input   wire            inst_is_Jump,

    // For immediate effect in the next clock, we use wire not reg
    // Query from Register File.
    output  wire    [3:0]   rs1_index,
    input   wire            rs1_dirty,
    input   wire    [3:0]   rs1_rob_entry,
    input   wire    [31:0]  rs1_value,
    input   wire            rs1_valid,

    output  wire    [3:0]   rs2_index,
    input   wire            rs2_dirty,
    input   wire    [3:0]   rs2_rob_entry,
    input   wire    [31:0]  rs2_value,
    input   wire            rs2_valid,
    // Query from ROB
    output  wire    [3:0]   rs1_rob_q_entry,
    input   wire    [31:0]  rs1_rob_value,
    input   wire            rs1_rob_rdy,

    output  wire    [3:0]   rs2_rob_q_entry,
    input   wire    [31:0]  rs2_rob_value,
    input   wire            rs2_rob_rdy,

    // To Register File to update dirty bit and ROB Entry index.
    output  reg             done,
    output  reg     [6:0]   opcode,
    output  reg     [2:0]   precise,
    output  reg             moreprecise,
    output  reg     [3:0]   rd,
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
    output  reg     [3:0]   rob_need,
    output  reg     [31:0]  pc, // For JALR
    input   wire    [3:0]   next_empty_rob_entry
);
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
    // | imm[12|10:5] |     rs2     |     rs1     | 110 | imm[4:1|11] | 1100011 | BLT       √
    // | imm[12|10:5] |     rs2     |     rs1     | 111 | imm[4:1|11] | 1100011 | BGE       √
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 0000011 | LB        √
    // |         imm[11:0]          |     rs1     | 001 |     rd      | 0000011 | LH        √
    // |         imm[11:0]          |     rs1     | 010 |     rd      | 0000011 | LW        √
    // |         imm[11:0]          |     rs1     | 100 |     rd      | 0000011 | LB        √
    // |         imm[11:0]          |     rs1     | 101 |     rd      | 0000011 | LH        √
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
    assign  rs1_index   = inst[19:15];
    assign  rs2_index   = inst[24:20];
    // query for rs1 and rs2 if rely on ROB
    assign  rs1_rob_q_entry = rs1_rob_entry;
    assign  rs2_rob_q_entry = rs2_rob_entry;

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
        rob_need    = next_empty_rob_entry;
        pc  = inst_PC;
        if (inst_rdy && rdy && !rst && !rollback) begin
            if(rs1_valid) begin
                if(!rs1_dirty) begin
                    rs1_val = rs1_value;
                end else if(rs1_rob_rdy) begin
                    rs1_val = rs1_rob_value;
                end else begin
                    rs1_need_rob    = 1'b1;
                    rs1_rob_id  = rs1_rob_entry;
                end
            end

            if(rs2_valid) begin
                if(!rs2_dirty) begin
                    rs2_val = rs2_value;
                end else if(rs2_rob_rdy) begin
                    rs2_val = rs2_rob_value;
                end else begin
                    rs2_need_rob    = 1'b1;
                    rs2_rob_id  = rs2_rob_entry;
                end
            end

            case (opcode)
                7'b0110111, 7'b0010111: begin   // LUI && AUIPC
                    imm = {inst[31:12], 12'b0};
                    rs_config   = 1'b1;
                end
                7'b1101111: begin               // JAL
                    imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                    rs_config   = 1'b1;
                end
                7'b1100111: begin               // JALR
                    imm = {{21{inst[31]}}, inst[30:20]}; 
                    rs_config   = 1'b1;
                end
                7'b1100011: begin               // branch
                    imm = {{21{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                    rs_config   = 1'b1;
                end
                7'b0000011: begin               // load
                    imm = {{21{inst[31]}}, inst[30:20]};
                    lsb_config  = 1'b1;
                    lsb_store_or_load   = 1'b0;
                end
                7'b0100011: begin               // store
                    imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                    lsb_config  = 1'b1;
                    lsb_store_or_load   = 1'b1;
                end
                7'b0010011: begin               // op li
                    imm = {{21{inst[31]}}, inst[30:20]};
                    rs_config   = 1'b1;
                end
                7'b0110011:begin                // op
                    rs_config   = 1'b1;
                end
            endcase
        end
    end
endmodule //decoder
