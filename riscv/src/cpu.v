// RISCV32I CPU top module
// port modification allowed for debugging purposes
`ifndef CPU
`define CPU

`include "alu.v"
`include "decoder.v"
`include "ifetch.v"
`include "lsb.v"
`include "mem-ctrl.v"
`include "registerfile.v"
`include "reservestation.v"
`include "rob.v"
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			    dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  wire  [31:0]  ALU_out_val;
  wire          ALU_out_need_jump;
  wire  [31:0]  ALU_out_jump_PC;
  wire  [3:0]   ALU_out_rob;
  wire          ALU_out_config;
  wire          mem_ctrl_lsb_config;
  wire  [31:0]  mem_ctrl_lsb_data;
  wire          LSB_out_config;
  wire  [3:0]   LSB_out_rob;
  wire  [31:0]  LSB_out_val;
  wire          LSB_out_to_mem_ctrl_config;
  wire          LSB_out_to_mem_ctrl_ls;
  wire  [31:0]  LSB_out_to_mem_ctrl_addr;
  wire  [31:0]  LSB_out_to_mem_ctrl_data;
  wire  [2:0]   LSB_out_to_mem_ctrl_precise;
  wire  [3:0]   LSB_out_to_mem_ctrl_rob;
  wire  [4:0]   query_rs1;
  wire  [4:0]   query_rs2;
  wire  [3:0]   query_rob1;
  wire  [3:0]   query_rob2;
  wire          decoder_done;
  wire  [1:0]   decoder_rob_type;
  wire  [6:0]   decoder_opcode;
  wire  [2:0]   decoder_precise;
  wire          decoder_more_precise;
  wire  [4:0]   decoder_rd;
  wire  [31:0]  decoder_rs1_value;
  wire          decoder_rs1_need_rob;
  wire  [3:0]   decoder_rs1_rob1;
  wire  [31:0]  decoder_rs2_value;
  wire          decoder_rs2_need_rob;
  wire  [3:0]   decoder_rs2_rob2;
  wire  [31:0]  decoder_imm;
  wire          decoder_lsb_config;
  wire          decoder_lsb_sl;
  wire          decoder_rs_config;
  wire          decoder_rf_config;
  wire  [3:0]   decoder_rob_entry;
  wire          decoder_pred_jump;
  wire  [31:0]  decoder_pc;
  wire  [31:0]  decoder_ans;
  wire          decoder_rob_ready;
  wire          decoder_JALR_need_pause;
  wire          decoder_JALR_pause_rej;
  wire  [31:0]  decoder_JALR_PC;
  wire  [31:0]  inst;
  wire          inst_ready;
  wire  [31:0]  inst_pc;
  wire          inst_jump;
  wire  [31:0]  ms_pc;
  wire          ms_config;
  wire  [511:0] ms_row;
  wire          row_config;
  wire          rs_alu_config;
  wire  [31:0]  rs_alu_value1;
  wire  [31:0]  rs_alu_value2;
  wire  [31:0]  rs_alu_pc;
  wire  [6:0]   rs_alu_opcode;
  wire  [2:0]   rs_alu_precise;
  wire          rs_alu_more_precise;
  wire  [31:0]  rs_alu_imm;
  wire  [3:0]   rs_alu_rob;
  wire          rollback;
  wire  [31:0]  rollback_PC;
  wire  [3:0]   rob_nxt_empty_ROB_id;
  wire  [31:0]  rob_rs1_rob_value;
  wire          rob_rs1_rob_rdy;
  wire  [31:0]  rob_rs2_rob_value;
  wire          rob_rs2_rob_rdy;
  wire          rob_commit_config;
  wire  [3:0]   rob_commit_ROB;
  wire  [31:0]  rob_commit_value;
  wire          rob_full;
  wire          rob_commit_reg_config;
  wire  [4:0]   rob_commit_reg_id;
  wire  [31:0]  rob_commit_reg_value;
  wire  [3:0]   rob_commit_reg_rob;
  wire          rob_commit_lsb_config;
  wire  [3:0]   rob_commit_lsb_rob;
  wire          rob_commit_update_config;
  wire  [31:0]  rob_commit_update_pc;
  wire          rob_commit_update_jump;
  wire          rf_rs1_dirty;
  wire  [3:0]   rf_rs1_rob1;
  wire  [31:0]  rf_rs1_val;
  wire          rf_rs2_dirty;
  wire  [3:0]   rf_rs2_rob2;
  wire  [31:0]  rf_rs2_val;
  wire          lsb_full;
  wire          JALR;

  `ifdef JY
  wire  [1023:0]  debugger;
  `endif
  ALU cpu_ALU(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback_config              (rollback),
    .in_config                    (rs_alu_config),
    .in_a                         (rs_alu_value1),
    .in_b                         (rs_alu_value2),
    .in_PC                        (rs_alu_pc),
    .in_opcode                    (rs_alu_opcode),
    .in_precise                   (rs_alu_precise),
    .in_more_precise              (rs_alu_more_precise),
    .in_imm                       (rs_alu_imm),
    .in_rob_entry                 (rs_alu_rob),
    .out_val                      (ALU_out_val),
    .out_need_jump                (ALU_out_need_jump),
    .out_jump_pc                  (ALU_out_jump_PC),
    .out_rob_entry                (ALU_out_rob),
    .out_config                   (ALU_out_config)
  );

  LSB cpu_LSB(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback_config              (rollback),
    .mem_ctrl_out_config          (LSB_out_to_mem_ctrl_config),
    .mem_ctrl_out_ls              (LSB_out_to_mem_ctrl_ls),
    .mem_ctrl_out_addr            (LSB_out_to_mem_ctrl_addr),
    .mem_ctrl_out_data            (LSB_out_to_mem_ctrl_data),
    .mem_ctrl_out_precise         (LSB_out_to_mem_ctrl_precise),
    .mem_ctrl_out_rob             (LSB_out_to_mem_ctrl_rob),
    .mem_ctrl_in_config           (mem_ctrl_lsb_config),
    .mem_ctrl_in_data             (mem_ctrl_lsb_data),
    .broadcast_config             (LSB_out_config),
    .broadcast_value              (LSB_out_val),
    .broadcast_ROB                (LSB_out_rob),
    .alu_in_config                (ALU_out_config),
    .alu_in_ROB                   (ALU_out_rob),
    .alu_in_value                 (ALU_out_val),
    .lsb_in_config                (LSB_out_config),
    .lsb_in_ROB                   (LSB_out_rob),
    .lsb_in_value                 (LSB_out_val),
    .commit_config                (rob_commit_lsb_config),
    .commit_ROB                   (rob_commit_lsb_rob),
    .inst_config                  (decoder_lsb_config),
    .inst_store_or_load           (decoder_lsb_sl),
    .inst_precise                 (decoder_precise),
    .inst_ROB                     (decoder_rob_entry),
    .inst_rs1_val                 (decoder_rs1_value),
    .inst_rs1_need_ROB            (decoder_rs1_need_rob),
    .inst_rs1_ROB_id              (decoder_rs1_rob1),
    .inst_rs2_val                 (decoder_rs2_value),
    .inst_rs2_need_ROB            (decoder_rs2_need_rob),
    .inst_rs2_ROB_id              (decoder_rs2_rob2),
    .inst_imm                     (decoder_imm),
    .lsb_is_full                  (lsb_full)
  );

  mem_ctrl cpu_mem_ctrl(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .io_buffer_full               (1'b0),
    .rollback                     (rollback),
    .ram_read_or_write            (mem_wr),
    .addr_to_ram                  (mem_a),
    .data_write_out               (mem_dout),
    .data_read_in                 (mem_din),
    .inst_config                  (ms_config),
    .inst_PC                      (ms_pc),
    .inst_row                     (ms_row),
    .inst_out_config              (row_config),
    .lsb_config                   (LSB_out_to_mem_ctrl_config),
    .lsb_ls                       (LSB_out_to_mem_ctrl_ls),
    .lsb_addr                     (LSB_out_to_mem_ctrl_addr),
    .lsb_data                     (LSB_out_to_mem_ctrl_data),
    .lsb_precise                  (LSB_out_to_mem_ctrl_precise),
    .lsb_rob                      (LSB_out_to_mem_ctrl_rob),
    .lsb_out_config               (mem_ctrl_lsb_config),
    .lsb_out_data                 (mem_ctrl_lsb_data)
  );

  decoder cpu_decoder(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback                     (rollback),
    .inst_rdy                     (inst_ready),
    .inst                         (inst),
    .inst_PC                      (inst_pc),
    .pred_jump                    (inst_jump),
    .rs1_index                    (query_rs1),
    .rs1_dirty                    (rf_rs1_dirty),
    .rs1_rob_entry                (rf_rs1_rob1),
    .rs1_value                    (rf_rs1_val),
    .rs2_index                    (query_rs2),
    .rs2_dirty                    (rf_rs2_dirty),
    .rs2_rob_entry                (rf_rs2_rob2),
    .rs2_value                    (rf_rs2_val),
    .rs1_rob_q_entry              (query_rob1),
    .rs1_rob_value                (rob_rs1_rob_value),
    .rs1_rob_rdy                  (rob_rs1_rob_rdy),
    .rs2_rob_q_entry              (query_rob2),
    .rs2_rob_value                (rob_rs2_rob_value),
    .rs2_rob_rdy                  (rob_rs2_rob_rdy),
    .done                         (decoder_done),
    .ROB_type                     (decoder_rob_type),
    .opcode                       (decoder_opcode),
    .precise                      (decoder_precise),
    .moreprecise                  (decoder_more_precise),
    .rd                           (decoder_rd),
    .rs1_val                      (decoder_rs1_value),
    .rs1_need_rob                 (decoder_rs1_need_rob),
    .rs1_rob_id                   (decoder_rs1_rob1),
    .rs2_val                      (decoder_rs2_value),
    .rs2_need_rob                 (decoder_rs2_need_rob),
    .rs2_rob_id                   (decoder_rs2_rob2),
    .imm                          (decoder_imm),
    .lsb_config                   (decoder_lsb_config),
    .lsb_store_or_load            (decoder_lsb_sl),
    .rs_config                    (decoder_rs_config),
    .rf_config                    (decoder_rf_config),
    .rob_need                     (decoder_rob_entry),
    .is_jump                      (decoder_pred_jump),
    .out_pc                       (decoder_pc),
    .rob_ready                    (decoder_rob_ready),
    .rob_ans                      (decoder_ans),
    .next_empty_rob_entry         (rob_nxt_empty_ROB_id),
    .rob_is_full                  (rob_full),
    .lsb_is_full                  (lsb_full),
    .JALR_need_pause              (decoder_JALR_need_pause),
    .JALR_pause_rej               (decoder_JALR_pause_rej),
    .JALR_PC                      (decoder_JALR_PC),
    .alu_rob_config               (ALU_out_config),
    .alu_rob_entry                (ALU_out_rob),
    .alu_value                    (ALU_out_val),
    .lsb_rob_config               (LSB_out_config),
    .lsb_rob_entry                (LSB_out_rob),
    .lsb_value                    (LSB_out_val),
    .JALR_statu                   (JALR)
  );

  ifetch cpu_ifetch(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .inst                         (inst),
    .inst_rdy                     (inst_ready),
    .out_PC                       (inst_pc),
    .is_Jump                      (inst_jump),
    .missing_PC                   (ms_pc),
    .missing_config               (ms_config),
    .return_row                   (ms_row),
    .return_config                (row_config),
    .rollback_pc                  (rollback_PC),
    .rollback_config              (rollback),
    .update_pc                    (rob_commit_update_pc),
    .update_jump                  (rob_commit_update_jump),
    .update_config                (rob_commit_update_config),
    .rob_is_full                  (rob_full),
    .JALR_need_pause              (decoder_JALR_need_pause),
    .JALR_pause_rej               (decoder_JALR_pause_rej),
    .JALR_PC                      (decoder_JALR_PC),
    .lsb_is_full                  (lsb_full),
    .JALR_statu                   (JALR)
  );

  reservestation cpu_reservestation(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback                     (rollback),
    .out_config                   (rs_alu_config),
    .out_value_1                  (rs_alu_value1),
    .out_value_2                  (rs_alu_value2),
    .out_value_pc                 (rs_alu_pc),
    .out_opcode                   (rs_alu_opcode),
    .out_precise                  (rs_alu_precise),
    .out_more_precise             (rs_alu_more_precise),
    .out_imm                      (rs_alu_imm),
    .out_rob_entry                (rs_alu_rob),
    .in_config                    (decoder_rs_config),
    .in_value_1                   (decoder_rs1_value),
    .in_Q1                        (decoder_rs1_rob1),
    .in_Q1_need                   (decoder_rs1_need_rob),
    .in_value_2                   (decoder_rs2_value),
    .in_Q2                        (decoder_rs2_rob2),
    .in_Q2_need                   (decoder_rs2_need_rob),               
    .in_value_pc                  (decoder_pc),
    .in_opcode                    (decoder_opcode),
    .in_precise                   (decoder_precise),
    .in_more_precise              (decoder_more_precise),
    .in_imm                       (decoder_imm),
    .in_rob_entry                 (decoder_rob_entry),
    .alu_config                   (ALU_out_config),
    .alu_val                      (ALU_out_val),
    .alu_rob_entry                (ALU_out_rob),
    .lsb_config                   (LSB_out_config),
    .lsb_val                      (LSB_out_val),
    .lsb_rob_entry                (LSB_out_rob)
  );

  registerfile cpu_registerfile(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback_config              (rollback),
    .rs1_index                    (query_rs1),
    .rs1_dirty                    (rf_rs1_dirty),
    .rs1_rob_entry                (rf_rs1_rob1),
    .rs1_val                      (rf_rs1_val),
    .rs2_index                    (query_rs2),
    .rs2_dirty                    (rf_rs2_dirty),
    .rs2_rob_entry                (rf_rs2_rob2),
    .rs2_val                      (rf_rs2_val),
    .commit_config                (rob_commit_reg_config),
    .rs_to_write_id               (rob_commit_reg_id),
    .rs_to_write_val              (rob_commit_reg_value),
    .commit_rob_id                (rob_commit_reg_rob),
    .decoder_done                 (decoder_rf_config),
    .rd                           (decoder_rd),

    `ifdef JY
    .allregs                      (debugger),
    `endif
    
    .rob_need                     (decoder_rob_entry)
  );

  ROB cpu_ROB(
    .clk                          (clk_in),
    .rst                          (rst_in),
    .rdy                          (rdy_in),
    .rollback                     (rollback),
    .rollback_config              (rollback),
    .rollback_pc                  (rollback_PC),
    .nxt_empty_ROB_id             (rob_nxt_empty_ROB_id),
    .decoder_done                 (decoder_done),
    .ROB_type                     (decoder_rob_type),
    .inst_rd                      (decoder_rd),
    .inst_PC                      (decoder_pc),
    .inst_predict_jump            (decoder_pred_jump),
    .inst_ready                   (decoder_rob_ready),
    .inst_ans                     (decoder_ans),
    .rs1_rob_q_entry              (query_rob1),
    .rs1_rob_value                (rob_rs1_rob_value),
    .rs1_rob_rdy                  (rob_rs1_rob_rdy),
    .rs2_rob_q_entry              (query_rob2),
    .rs2_rob_value                (rob_rs2_rob_value),
    .rs2_rob_rdy                  (rob_rs2_rob_rdy),
    .commit_config                (rob_commit_config),
    .commit_ROB                   (rob_commit_ROB),
    .commit_value                 (rob_commit_value),
    .rob_full                     (rob_full),
    .commit_reg_config            (rob_commit_reg_config),
    .commit_reg_id                (rob_commit_reg_id),
    .commit_reg_value             (rob_commit_reg_value),
    .commit_reg_rob               (rob_commit_reg_rob),
    .commit_lsb_config            (rob_commit_lsb_config),
    .commit_lsb_rob               (rob_commit_lsb_rob),
    .commit_update_config         (rob_commit_update_config),
    .commit_update_pc             (rob_commit_update_pc),
    .commit_update_jump           (rob_commit_update_jump),
    .alu_config                   (ALU_out_config),
    .alu_need_jump                (ALU_out_need_jump),
    .alu_jump_pc                  (ALU_out_jump_PC),
    .alu_val                      (ALU_out_val),
    .alu_rob_entry                (ALU_out_rob),
    .lsb_config                   (LSB_out_config),
    .lsb_rob_entry                (LSB_out_rob),
    `ifdef JY
    .reg_debugger                 (debugger),
    `endif
    .lsb_value                    (LSB_out_val)
  );
endmodule
`endif