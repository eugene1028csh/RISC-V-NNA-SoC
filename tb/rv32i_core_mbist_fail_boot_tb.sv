`timescale 1ns/1ps

module rv32i_core_mbist_fail_boot_tb;

    logic clk;
    logic reset;

    logic [31:0] bus_addr;
    logic [31:0] bus_write_data;
    logic        bus_write_en;

    logic [31:0] bus_read_data;
    logic        bus_hit;

    logic mbist_pass_o;
    logic mbist_fail_o;


    // ----------------------------
    // DUT
    // ----------------------------

    rv32i_core dut (
        .clk            (clk),
        .reset          (reset),

        .bus_addr       (bus_addr),
        .bus_write_data (bus_write_data),
        .bus_write_en   (bus_write_en),

        .bus_read_data  (bus_read_data),
        .bus_hit        (bus_hit),

        .mbist_pass_o   (mbist_pass_o),
        .mbist_fail_o   (mbist_fail_o)
    );


    // ----------------------------
    // Clock
    // ----------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("core_fail_boot.vcd");
        $dumpvars(0, rv32i_core_mbist_fail_boot_tb);
    end


    // ----------------------------
    // No MMIO peripheral response
    // ----------------------------

    assign bus_read_data = 32'h0000_0000;
    assign bus_hit       = 1'b0;


    // ----------------------------
    // Test
    // ----------------------------

    // Simulated stuck-at-0 fault:
    // force word 37, bit 7 back to 0 after every memory write edge
    always @(negedge clk) begin
        if (!reset)
            dut.dmem.mem[37][7] = 1'b0;
    end
    
    initial begin

    reset = 1'b1;

    // Inject stuck-at-0 fault into the actual DMEM
    

    repeat (5) @(posedge clk);

    reset = 1'b0;

    // Wait for MBIST to detect the fault
    wait (mbist_fail_o == 1'b1);

    // Let MBIST run all the way to completion
    wait (dut.mbist_done == 1'b1);

    repeat (6) @(posedge clk);

    #1;

    $display("-------------------------------");
    $display("Faulted core boot MBIST finished");
    $display("MBIST PASS = %b", mbist_pass_o);
    $display("MBIST FAIL = %b", mbist_fail_o);
    $display("FAIL ADDR  = %h", dut.mbist_fail_addr);
    $display("CPU ENABLE = %b", dut.cpu_enable);
    $display("CPU RESET  = %b", dut.cpu_reset);
    $display("PC         = %h", dut.pc);
    $display("-------------------------------");

    if (mbist_fail_o !== 1'b1)
        $error("Injected DMEM fault was not detected");

    if (mbist_pass_o !== 1'b0)
        $error("MBIST PASS incorrectly asserted");

    if (dut.mbist_fail_addr !== 32'h0000_0094)
        $error("Incorrect failure address");

    if (dut.cpu_enable !== 1'b0)
        $error("CPU incorrectly enabled after MBIST FAIL");

    if (dut.cpu_reset !== 1'b1)
        $error("CPU incorrectly released from reset");

    if (dut.pc !== 32'h0000_0000)
        $error("PC advanced even though CPU should remain reset");


    if (
        mbist_fail_o            === 1'b1 &&
        mbist_pass_o            === 1'b0 &&
        dut.mbist_fail_addr     === 32'h0000_0094 &&
        dut.cpu_enable          === 1'b0 &&
        dut.cpu_reset           === 1'b1 &&
        dut.pc                  === 32'h0000_0000
    )
        $display(
            "TEST PASSED: MBIST failure correctly inhibits CPU boot"
        );

    $finish;

    end

endmodule