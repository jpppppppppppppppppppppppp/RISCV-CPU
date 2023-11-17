module mem_ctrl (
    input   wire    clk,
    input   wire    rst,
    input   wire    rdy,
    
    input   wire    rollback, // 1 means Reorder Buffer need rollback
    // to real ram
    input   wire    [7:0]   data_read_in,
    input   reg     [31:0]  addr_to_ram,
    output  reg     [7:0]   data_write_out,
    output  reg             ram_read_or_write,
    // handle ifetch
    



);
    
endmodule //mem_ctrl
