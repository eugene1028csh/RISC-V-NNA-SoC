`timescale 1ns/1ps

module rv32i_core_bisr_repair_boot_tb;

    logic clk;
    logic reset;

    logic [31:0] bus_addr;
    logic [31:0] bus_write_data;
    logic        bus_write_en;

    logic [31:0] bus_read_data;
    logic        bus_hit;

    logic mbist_pass_o;
    logic mbist_fail_o;

    logic [31:0] first_fail_addr;

    // ----------------------------
    // DUT
    // ----------------------------

    rv32i_core dut (
        .clk            (clk),
        .reset          (reset),

        .nna_boot_pass_i(1'b1),

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
        $dumpfile("core_bisr_repair_boot.vcd");
        $dumpvars(0, rv32i_core_bisr_repair_boot_tb);
    end

    // No MMIO peripheral response
    assign bus_read_data = 32'h0000_0000;
    assign bus_hit       = 1'b0;


    always @(negedge clk) begin
        if (!reset)
            dut.dmem.mem[37][7] = 1'b0;
    end

    initial begin

    reset = 1'b1;
    first_fail_addr = 32'h0;

    // Simulated physical stuck-at-0 fault:
    // keep bit 7 of physical mem[37] at zero

    repeat (5) @(posedge clk);

    reset = 1'b0;

    // Wait for MBIST to detect the fault
    wait (mbist_fail_o == 1'b1);

    // Let MBIST run all the way to completion
    wait (dut.mbist_done == 1'b1);

    #1;

    first_fail_addr = dut.mbist_fail_addr;

    $display("First MBIST failed at %h", first_fail_addr);


    if (first_fail_addr !== 32'h0000_0094)
        $error("Incorrect initial failure address");

     // BISR should activate
    wait (dut.repair_valid == 1'b1);

        #1;

        if (dut.repair_addr !== 8'd37)
            $error("Wrong repair address");

        if (dut.repair_attempted !== 1'b1)
            $error("Repair attempt was not recorded");

    // wait for 2nd mbist begin
    wait (dut.mbist_done == 1'b0);

    //expecting 2nd mbist to pass
    wait (
            dut.mbist_done == 1'b1 &&
            mbist_pass_o   == 1'b1
    );
   // Controller then releases CPU
    wait (dut.cpu_enable == 1'b1);

    repeat (2) @(posedge clk);
    #1;

    $display("--------------------------------");
    $display("BISR repair test finished");
    $display("FIRST FAIL ADDR  = %h", first_fail_addr);
    $display("REPAIR VALID     = %b", dut.repair_valid);
    $display("REPAIR ADDR      = %0d", dut.repair_addr);
    $display("REPAIR ATTEMPTED = %b", dut.repair_attempted);
    $display("FINAL MBIST PASS = %b", mbist_pass_o);
    $display("FINAL MBIST FAIL = %b", mbist_fail_o);
    $display("CPU ENABLE       = %b", dut.cpu_enable);
    $display("CPU RESET        = %b", dut.cpu_reset);
    $display("--------------------------------");


    if (first_fail_addr !== 32'h0000_0094)
        $error("Initial MBIST did not detect word 37");

    if (dut.repair_valid !== 1'b1)
        $error("Repair mapping not enabled");

    if (dut.repair_addr !== 8'd37)
        $error("Incorrect repaired word");

    if (dut.repair_attempted !== 1'b1)
        $error("Repair attempt flag not set");

    if (mbist_pass_o !== 1'b1)
        $error("Repaired memory failed MBIST retest");

    if (mbist_fail_o !== 1'b0)
        $error("MBIST FAIL remained asserted after successful repair");

    if (dut.cpu_enable !== 1'b1)
        $error("CPU was not released after successful repair");

    if (dut.cpu_reset !== 1'b0)
        $error("CPU remained in reset after successful repair");


    if (
        first_fail_addr       === 32'h0000_0094 &&
        dut.repair_valid      === 1'b1 &&
        dut.repair_addr       === 8'd37 &&
        dut.repair_attempted  === 1'b1 &&
        mbist_pass_o          === 1'b1 &&
        mbist_fail_o          === 1'b0 &&
        dut.cpu_enable        === 1'b1 &&
        dut.cpu_reset         === 1'b0
    )
        $display(
            "TEST PASSED: BISR repaired faulty DMEM word and CPU booted"
        );
    #5000;  // Keep final results visible for another 1 us
    $finish;

    end

endmodule