`ifndef CTRL
`define CTRL
module mem_ctrl (
    input   wire            clk,
    input   wire            rst,
    input   wire            rdy,
    input   wire            io_buffer_full,
    input   wire            rollback, // 1 means Reorder Buffer need rollback
    // to real ram
    output  reg             ram_read_or_write,
    output  reg     [31:0]  addr_to_ram,
    output  reg     [7:0]   data_write_out,
    input   wire    [7:0]   data_read_in,
    // handle ifetch
    input   wire            inst_config,
    input   wire    [31:0]  inst_PC,
    output  wire    [511:0] inst_row,
    output  reg             inst_out_config,
    // handle lsb
    input   wire            lsb_config,
    input   wire            lsb_ls,
    input   wire    [31:0]  lsb_addr,
    input   wire    [31:0]  lsb_data,
    input   wire    [2:0]   lsb_precise,
    output  reg             lsb_out_config,
    output  reg     [31:0]  lsb_out_data
);
`ifdef JY
integer log;
initial begin
    log = $fopen("memctrl.log", "w");
end
`endif
    reg     [7:0]   buffer  [63:0];
    reg     [1:0]   statu; // 00 - IDLE, 01 - INST, 10 - LSB-S, 11 LSB-L
    reg     [31:0]  buffer_addr;
    reg     [2:0]   len;
    reg     [2:0]   stage;
    reg     [2:0]   precise;
    reg     [5:0]   pos;
    reg     [32:0]  last_pc;
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin
             assign inst_row[(i*8+7):(i*8)] = buffer[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            statu   <= 2'b00;
            inst_out_config <= 1'b0;
            lsb_out_config  <= 1'b0;
            last_pc <= 33'b100000000000000000000000000000000;
        end
        else if (!rdy) begin
            ram_read_or_write   <= 1'b0;
            inst_out_config <= 1'b0;
            lsb_out_config  <= 1'b0;
        end
        else if (rdy) begin
            `ifdef JY
                $fdisplay(logfile, "%t statu: %B", $realtime, statu);
            `endif
            ram_read_or_write   <= 1'b0;
            inst_out_config <= 1'b0;
            lsb_out_config  <= 1'b0;
            if ((statu == 2'b00) && (!rollback)) begin
                if (inst_config && !(last_pc[32] != 1 && last_pc[31:0] == inst_PC)) begin
                    buffer_addr <= {inst_PC[31:6], 6'b000000};
                    last_pc <= {1'b0, inst_PC};
                    statu   <= 2'b01;
                end
                else if (lsb_config) begin
                    buffer_addr <= lsb_addr;
                    statu   <= {1'b1, lsb_ls};
                    precise <= lsb_precise;
                    stage   <= 3'b0;
                    case (lsb_precise)
                        3'b000, 3'b100: begin
                            len <= 3'b001;
                        end 
                        3'b001, 3'b101: begin
                            len <= 3'b010;
                        end
                        3'b010: begin
                            len <= 3'b100;
                        end
                    endcase
                end
            end
            else if (statu == 2'b01) begin
                if (rollback) begin
                    statu   <= 2'b00;
                end
                else begin
                    buffer[pos]    <= data_read_in;
                    `ifdef JY
                        $fdisplay(logfile, "@%t", $realtime);
                        $fdisplay(logfile, "PC:%D", buffer_addr);
                        $fdisplay(logfile, "DATA:%512B", inst_row);
                        $fdisplay(logfile, "DATA:%8B", data_read_in);
                        $fdisplay(logfile, "ID:%6B", pos);
                    `endif
                    if ((buffer_addr[5:0] == 6'b000001) && (buffer_addr[31:6] != inst_PC[31:6])) begin
                        statu   <= 2'b00;
                        inst_out_config <= 1'b1;
                        ram_read_or_write   <= 1'b0;
                    end
                    else begin
                        ram_read_or_write   <= 1'b0;
                        addr_to_ram <= buffer_addr;
                        buffer_addr <= buffer_addr + 1;
                        if (buffer_addr[5:0] == 6'b000001) begin
                            pos <= 6'b0;
                        end
                        else begin
                            pos <= pos + 1;
                        end
                    end
                end
            end
            else if (statu == 2'b10) begin
                if ((buffer_addr[17:16] != 2'b11) || (!io_buffer_full)) begin
                    `ifdef JY
                        $fdisplay(logfile, "%B %B %B", statu, stage, len);
                    `endif
                    if (stage == len) begin
                        statu   <= 2'b00;
                        lsb_out_config  <= 1'b1;
                    end
                    else begin
                        ram_read_or_write   <= 1'b0;
                        case (stage)
                            3'b000: data_write_out  <=  lsb_data[7:0];
                            3'b001: data_write_out  <=  lsb_data[15:8];
                            3'b010: data_write_out  <=  lsb_data[23:16];
                            3'b011: data_write_out  <=  lsb_data[31:24];
                        endcase
                        addr_to_ram <= buffer_addr + stage;
                        stage   <= stage + 1;
                    end
                end
            end
            else if (statu == 2'b11) begin
                if (rollback) begin
                    statu   <= 2'b00;
                end
                else begin
                    `ifdef JY
                        $fdisplay(logfile, "%B %B %B", statu, stage, len);
                    `endif
                    ram_read_or_write   <= 1'b1;
                    case (stage)
                        3'b001: lsb_out_data[7:0]   <= data_read_in;
                        3'b010: lsb_out_data[15:8]  <= data_read_in;
                        3'b011: lsb_out_data[23:16] <= data_read_in;
                        3'b100: lsb_out_data[31:24] <= data_read_in;
                    endcase
                    addr_to_ram <= buffer_addr + stage;
                    stage   <= stage + 1;
                    if (stage == len) begin
                        lsb_out_config  <= 1'b1;
                        statu   <= 2'b00;
                        if (precise == 3'b100) begin
                            lsb_out_data[31:8]  <= {24{data_read_in[7]}};
                        end
                        if (precise == 3'b101) begin
                            lsb_out_data[31:16]  <= {16{data_read_in[7]}};
                        end
                    end
                end
            end
        end
    end
endmodule //mem_ctrl
`endif