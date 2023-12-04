module ALU(
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    input   wire            rollback_config,
    // from rs
    input   wire            in_config,
    input   wire    [31:0]  in_a,
    input   wire    [31:0]  in_b,
    input   wire    [31:0]  in_PC,
    input   wire    [6:0]   in_opcode,
    input   wire    [2:0]   in_precise,
    input   wire            in_more_precose,
    input   wire    [31:0]  in_imm,
    input   wire    [3:0]   in_rob_entry,
    
    // end exe
    output  reg     [31:0]  out_val,
    output  reg             out_need_jump,
    output  reg     [31:0]  out_jump_pc,
    output  reg     [3:0]   out_rob_entry,
    output  reg             out_config

);
    // handle add(i) sub sll(i) slt(i) slt(i)u xor(i) srl(i) sra(i) or(i) and(i)
    wire    [31:0]  opt1      = in_a;
    wire    [31:0]  opt2      = (in_opcode == 7'b0010011) ? in_imm : in_b;
    reg     [31:0]  optans;
    always @(*) begin
        case (in_precise)
            3'b000: begin // ADDI ADD SUB
                if((in_opcode == 7'b0110011) && in_more_precose) begin
                    optans  <= opt1 - opt2;
                end
                else begin
                    optans  <= opt1 + opt2;
                end
            end  
            3'b001: begin // SLLI SLL
                optans  <= opt1 << opt2;
            end
            3'b010: begin // SLTI SLT
                optans  <= ($signed(opt1) < $signed(opt2));
            end
            3'b011: begin // SLTIU SLTU
                optans  <= opt1 < opt2;
            end
            3'b100: begin // XORI XOR
                optans  <= opt1 ^ opt2;
            end
            3'b101: begin // SRLI SRAI SRL SRA
                if(in_more_precose) begin
                    optans  <= $signed(opt1) >> opt2[4:0];
                end
                else begin
                    optans  <= opt1 >> opt2[4:0];
                end
            end
            3'b110: begin // ORI OR
                optans  <= opt1 | opt2;
            end
            3'b111: begin // ANDI AND
                optans  <= opt1 & opt2;
            end
        endcase
    end
    // handle all branch
    reg             is_jump;
    always @(*) begin
        case (in_precise)
            3'b000: begin // BEQ
                is_jump <= (opt1 == opt2);
            end
            3'b001: begin // BNE
                is_jump <= (opt1 != opt2);
            end
            3'b100: begin // BLT
                is_jump <= ($signed(opt1) < $signed(opt2));
            end
            3'b101: begin // BGE
                is_jump <= ($signed(opt1) >= $signed(opt2));
            end
            3'b110: begin // BLTU
                is_jump <= (opt1 < opt2);
            end
            3'b111: begin // BGEU
                is_jump <= (opt1 >= opt2);
            end
        endcase
    end

    always @(posedge clk) begin
        if(rst || rollback_config) begin
            out_val <= 32'b0;
            out_need_jump   <= 1'b0;
            out_jump_pc <= 32'b0;
            out_rob_entry   <= 4'b0;
            out_config  <= 1'b0;
        end
        else begin
            if(rdy) begin
                out_config  <= 1'b0;
                if (in_config) begin
                    out_config  <= 1'b1;
                    case (in_opcode)
                    7'b0010111: begin // AUIPC
                        out_val <= in_PC + in_imm;
                    end
                    7'b1101111: begin // JAL
                        out_need_jump   <= 1'b1;
                        out_jump_pc <= in_PC + in_imm;
                        out_val <= in_PC + 4;
                    end
                    7'b1100111: begin // JALR
                        out_need_jump   <= 1'b1;
                        out_jump_pc <= (in_a + in_imm) & 32'b11111111111111111111111111111110;
                        out_val <= in_PC + 4;
                    end
                    7'b1100011: begin // branch
                        if (is_jump) begin
                            out_need_jump   <= 1'b1;
                            out_jump_pc <= in_PC + in_imm;
                        end
                        else begin
                            out_need_jump   <= 1'b0;
                            out_jump_pc <= in_PC + 4;
                        end
                    end
                    7'b0010011, 7'b0110011: begin // OP
                        out_val <= optans;
                    end
                endcase
                end
            end
        end
    end
endmodule //ALU