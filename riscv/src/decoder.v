module decoder (
    input   wire            clk,
    input   wire            rst,
    input   wire            dy,
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

    output  wire    [3:0]   rs2_index,
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
    input   wire    [3:0]   

);
    // 31           25 24         20 19         15 14 12 11          7 6       0
    // +--------------+-------------+-------------+-----+-------------+---------+
    // |                   imm[31:12]                   |     rd      | 0110111 | LUI
    // |                   imm[31:12]                   |     rd      | 0010111 | AUIPC
    // |             imm[20|10:1|11|19:12]              |     rd      | 1101111 | JAL
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 1100111 | JALR 
    // | imm[12|10:5] |     rs2     |     rs1     | 000 | imm[4:1|11] | 1100011 | BEQ
    // | imm[12|10:5] |     rs2     |     rs1     | 001 | imm[4:1|11] | 1100011 | BNE
    // | imm[12|10:5] |     rs2     |     rs1     | 100 | imm[4:1|11] | 1100011 | BLT
    // | imm[12|10:5] |     rs2     |     rs1     | 101 | imm[4:1|11] | 1100011 | BGE
    // | imm[12|10:5] |     rs2     |     rs1     | 110 | imm[4:1|11] | 1100011 | BLTU
    // | imm[12|10:5] |     rs2     |     rs1     | 111 | imm[4:1|11] | 1100011 | BGEU
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 0000011 | LB
    // |         imm[11:0]          |     rs1     | 001 |     rd      | 0000011 | LH
    // |         imm[11:0]          |     rs1     | 010 |     rd      | 0000011 | LW
    // |         imm[11:0]          |     rs1     | 100 |     rd      | 0000011 | LBU
    // |         imm[11:0]          |     rs1     | 101 |     rd      | 0000011 | LHU
    // |  imm[11:5]   |     rs2     |     rs1     | 000 |  imm[4:0]   | 0100011 | SB
    // |  imm[11:5]   |     rs2     |     rs1     | 001 |  imm[4:0]   | 0100011 | SH
    // |  imm[11:5]   |     rs2     |     rs1     | 010 |  imm[4:0]   | 0100011 | SW
    // |         imm[11:0]          |     rs1     | 000 |     rd      | 0010011 | ADDI
    // |         imm[11:0]          |     rs1     | 010 |     rd      | 0010011 | SLTI
    // |         imm[11:0]          |     rs1     | 011 |     rd      | 0010011 | SLTIU
    // |         imm[11:0]          |     rs1     | 100 |     rd      | 0010011 | XORI
    // |         imm[11:0]          |     rs1     | 110 |     rd      | 0010011 | ORI
    // |         imm[11:0]          |     rs1     | 111 |     rd      | 0010011 | ANDI
    // |   0000000    |    shamt    |     rs1     | 001 |     rd      | 0010011 | SLLI
    // |   0000000    |    shamt    |     rs1     | 101 |     rd      | 0010011 | SRLI
    // |   0100000    |    shamt    |     rs1     | 101 |     rd      | 0010011 | SRAI
    // |   0000000    |     rs2     |     rs1     | 000 |     rd      | 0110011 | ADD
    // |   0100000    |     rs2     |     rs1     | 000 |     rd      | 0110011 | SUB
    // |   0000000    |     rs2     |     rs1     | 001 |     rd      | 0110011 | SLL
    // |   0000000    |     rs2     |     rs1     | 010 |     rd      | 0110011 | SLT
    // |   0000000    |     rs2     |     rs1     | 011 |     rd      | 0110011 | SLTU
    // |   0000000    |     rs2     |     rs1     | 100 |     rd      | 0110011 | XOR
    // |   0000000    |     rs2     |     rs1     | 101 |     rd      | 0110011 | SRL
    // |   0100000    |     rs2     |     rs1     | 101 |     rd      | 0110011 | SRA
    // |   0000000    |     rs2     |     rs1     | 110 |     rd      | 0110011 | OR
    // |   0000000    |     rs2     |     rs1     | 111 |     rd      | 0110011 | AND
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
    
    reg     [6:0]   opcode;
    reg     [4:0]   precise;
    reg     [31:0]  rd;
    reg     [31:0]  rs1;
    reg     [31:0]  rs2;
    reg     [31:0]  imm;

    // query for rs1 and rs2
    assign  rs1_index   = inst[19:15];
    assign  rs2_index   = inst[24:20];
    // query for rs1 and rs2 if rely on ROB
    assign  rs1_rob_q_entry = rs1_rob_entry;
    assign  rs2_rob_q_entry = rs2_rob_entry;
    
endmodule //decoder
