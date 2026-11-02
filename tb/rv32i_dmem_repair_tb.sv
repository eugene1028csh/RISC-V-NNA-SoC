`timescale 1ns/1ps

module rv32i_dmem_repair_tb;
    localparam int DEPTH = 256;
    logic        clk;
    logic        mem_write;
    logic [31:0] addr;
    logic [31:0] write_data;
    logic [31:0] read_data;

    //BISR repair interface
    logic        repair_valid;
    logic [7:0]  repair_addr;

rv32i_dmem #(
    .DEPTH(DEPTH)
) dut (
    .clk    (clk),
    .mem_write  (mem_write),
    .addr   (addr),
    .write_data     (write_data),
    .repair_valid   (repair_valid),
    .repair_addr    (repair_addr),
    .read_data      (read_data)
);

always #5 clk = ~clk;

initial begin
    clk          = 0;
    mem_write    = 0;
    addr         = 0;
    write_data   = 0;
    repair_valid = 0;
    repair_addr  = 0;

    //write to physical word 37
    addr       = 32'h0000_0094;
    write_data = 32'hAAAA_AAAA;
    mem_write  = 1;

    @(posedge clk);
    #1;
    mem_write = 0;

    if(read_data !== 32'hAAAA_AAAA) begin
        $display("FAIL: normal word 37 write/read failed");
        $finish;
    end 

    //enable repair for logical word 37
    repair_addr = 8'd37;
    repair_valid = 1;

    //write to spare_word
    addr       = 32'h0000_0094;
    write_data = 32'h1234_5678;
    mem_write  = 1;

    //notice spare_word and meme(37) share the same logical address, but they have different phyiscla storage
    //mem[37] is an actual element inside RAM array, storage location 37 inside that array
    //but spare_word is a completely separate 32-bit register

    @(posedge clk);
    #1;
    mem_write = 0;

    if (read_data !== 32'h1234_5678) begin
        $display("FAIL: repaired word did not use spare storage");
        $finish;
    end

    //Disable spare_word to ensure mem[37] gives mem[37] physical storage value
    repair_valid = 0;
    #1;
    if (read_data !== 32'hAAAA_AAAA) begin
        $display("FAIL: physical mem[37] was unexpectedly modified");
        $finish;
    end

    // Re-enable repair for word 37
    repair_valid = 1;

    // Word 38 should be using normal RAM
    addr       = 32'h0000_0098;
    write_data = 32'hDEAD_BEEF;
    mem_write  = 1;

    @(posedge clk);
    #1;
    mem_write = 0;

    if (read_data !== 32'hDEAD_BEEF) begin
        $display("FAIL: normal word 38 access failed while repair active");
        $finish;
    end

    $display("-------------------------------");
    $display("DMEM REPAIR TEST PASSED");
    $display("word 37 redirected to spare storage");
    $display("word 38 still uses normal RAM");
    $display("-------------------------------");

    $finish;

end
endmodule