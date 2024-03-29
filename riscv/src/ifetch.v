`ifndef IF
`define IF
module ifetch (
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,

    output  reg     [31:0]  inst,       // 4 Bytes
    output  reg             inst_rdy,
    output  reg     [31:0]  out_PC,
    output  reg             is_Jump,

    // for missing, connected with mem-ctrl
    output  reg     [31:0]  missing_PC,
    output  reg             missing_config,
    input   wire    [511:0] return_row,
    input   wire            return_config,

    // for Reorder Buffer rollback
    input   wire    [31:0]  rollback_pc,
    input   wire            rollback_config,
    
    // update Predictor
    input   wire    [31:0]  update_pc,
    input   wire            update_jump,
    input   wire            update_config,

    // for pause
    input   wire            rob_is_full,
    input   wire            lsb_is_full,
    // JALR pause
    output  reg             JALR_statu,
    input   wire            JALR_need_pause,
    input   wire            JALR_pause_rej,
    input   wire    [31:0]  JALR_PC
);
    // i-cache
    // Address is [31:0], use [31:10] 22 bits as tag, use [9:6] 4 bits as index, use [5:0] 6 bits as offset
    // Block Num = 2 ^ index_width = 16
    // Each Block Size = 2 ^ offset_width = 64 Byts
    // Each Block Width = Each Block Size = 512 bits
    // Total Size = Block Num * Each Block Size = 1024 Bytes
    // We need [Block Num] Valid, [tag_width * Block Num] Tag, [Each Block Width * Block Num] Data
`ifdef JY
integer log;
initial begin
    log = $fopen("IF.log", "w");
end
`endif
    reg             Valid   [15:0];
    reg     [21:0]  Tag     [15:0];
    reg     [511:0] Data    [15:0];

    //if hit
    wire    [21:0]  tag     = PC[31:10];
    wire    [3:0]   index   = PC[9:6];
    wire    [3:0]   offset  = PC[5:2];
    wire            is_hit  = Valid[index] && (Tag[index] == tag);
    // if missed
    reg     [31:0]  missed_PC;
    wire    [3:0]   missed_pc_index = missed_PC[9:6];
    wire    [21:0]  missed_pc_tag   = missed_PC[31:10];

    wire    [511:0] cur_row = Data[index];
    wire    [31:0]  cur_block   [15:0];
    genvar temp;
    generate
        for (temp = 0; temp < 16; temp = temp + 1) begin
            assign  cur_block[temp] = cur_row[temp * 32 + 31:temp * 32];
        end
    endgenerate
    wire    [31:0]  inst_get = cur_block[offset];

    reg     [31:0]  PC;
    reg     status; // 0 for working while 1 for waiting

    // full-adder branch predictor
    // Address is [31:0], use [16:7] 10 bits as index
    reg     [1:0]   Predictor   [1023:0];
    reg     [31:0]  Pred_PC;
    wire    [9:0]   Pred_index  = PC[16:7];
    wire    [9:0]   Upd_index   = update_pc[16:7];
    reg             Pred_Jump; // by Predictor[Pred_index][1]


    // for update
    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 1024; j = j + 1) begin
                Predictor[j]    <= 2'b0;
            end
        end
        else if (rdy) begin
            if (update_config) begin
                if (update_jump) begin
                    if (Predictor[Upd_index] < 2'b11) Predictor[Upd_index]  <= Predictor[Upd_index] + 1;
                end
                else begin
                    if (Predictor[Upd_index] > 2'b00) Predictor[Upd_index]  <= Predictor[Upd_index] - 1;
                end
            end
        end
    end

    // for predictor
    always @(*) begin
        Pred_PC = PC + 4;
        Pred_Jump = 0;
        case (inst_get[6:0])
            7'b1101111: begin   // JAL
                Pred_PC = PC + {{12{inst_get[31]}}, inst_get[19:12], inst_get[20], inst_get[30:21], 1'b0};
                Pred_Jump = 1'b1;
            end
            7'b1100011:begin    // All Branch
                if (Predictor[Pred_index][1]) begin
                    Pred_PC   = PC + {{20{inst_get[31]}}, inst_get[7], inst_get[30:25], inst_get[11:8], 1'b0};
                    Pred_Jump = 1'b1;
                end
            end
        endcase
    end

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            `ifdef JY
                $fdisplay(log, "%t rst: %B;", $realtime, rst);
            `endif
            PC  <= 32'b0;
            missing_PC  <= 32'b0;
            missing_config  <= 1'b0;
            // clear i-cache
            for (i = 0; i < 16; i = i + 1) begin
                Valid[i]    <= 1'b0;
            end
            inst_rdy    <= 1'b0;
            inst    <= 32'b0;
            status  <= 1'b0;
            JALR_statu  <= 1'b0;
        end
        else if (rdy) begin
            JALR_statu  <= JALR_need_pause;
            if (rollback_config) begin
                JALR_statu  <= 1'b0;
                inst_rdy    <= 1'b0;
                PC  <= rollback_pc;
                `ifdef JY
                    $fdisplay(log, "%t rollback: PC: %8H;", $realtime, rollback_pc);
                `endif
            end
            else if(JALR_pause_rej) begin
                `ifdef JY
                    $fdisplay(log, "%t return from JALR; new PC: %8H;", $realtime, JALR_PC);
                `endif
                PC  <= JALR_PC;
                inst_rdy    <= 1'b0;
            end
            else if (JALR_need_pause) begin
                inst_rdy    <= 1'b0;
            end
            else if (!JALR_need_pause) begin
                `ifdef JY
                    $fdisplay(log, "%t not wait for JALR; now status: %B;", $realtime, status);
                `endif
                if  (status == 1'b0) begin
                    if (is_hit && (!rob_is_full) && (!lsb_is_full)) begin
                        inst_rdy    <= 1'b1;
                        inst    <= inst_get;
                        out_PC  <= PC;
                        PC  <= Pred_PC;
                        is_Jump <= Pred_Jump;
                        `ifdef JY
                            $fdisplay(log, "%t hit: PC:%D(%8H) -> %D(%8H); inst: %32B; index: %B; offset: %B; tag: %B;", $realtime, PC, PC, Pred_PC, Pred_PC, inst_get, index, offset, tag);
                        `endif
                    end
                    else if((rob_is_full) || (lsb_is_full)) begin
                        ;
                    end
                    else if (!is_hit)begin
                        `ifdef JY
                            $fdisplay(log, "%t hit: %B; rob_full: %B;", $realtime, is_hit, rob_is_full, lsb_is_full);
                        `endif
                        inst_rdy    <= 1'b0;
                    end
                    if (!is_hit) begin
                        status  <= 1'b1;
                        missing_PC  <= PC;
                        missed_PC   <= PC;
                        missing_config  <= 1'b1;
                        `ifdef JY
                            $fdisplay(log, "%t mspc send to ctrl: %8H;", $realtime, PC);
                        `endif
                        if ((!rob_is_full) && (!lsb_is_full)) begin
                            inst_rdy    <= 1'b0;
                        end
                    end
                end
                else begin
                    if((!rob_is_full) && (!lsb_is_full)) begin
                        inst_rdy    <= 1'b0;
                    end
                    if (return_config) begin
                        Valid[missed_pc_index]  <= 1'b1;
                        Tag[missed_pc_index]    <= missed_pc_tag;
                        Data[missed_pc_index]   <= return_row;
                        missing_config  <= 1'b0;
                        missing_PC  <= 32'b0;
                        status  <= 1'b0;
                        `ifdef JY
                            $fdisplay(log, "%t missing return: PC: %D; GET: %X;", $realtime, missing_PC, return_row);
                        `endif
                    end
                end
            end
        end
    end
endmodule //ifetch
`endif