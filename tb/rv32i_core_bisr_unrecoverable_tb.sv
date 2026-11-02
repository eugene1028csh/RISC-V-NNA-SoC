`timescale 1ns/1ps

module rv32i_core_bisr_unrecoverable_tb;

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
    logic [31:0] second_fail_addr;

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
        $dumpfile("core_bisr_unrecoverable_boot.vcd");
        $dumpvars(0, rv32i_core_bisr_unrecoverable_tb);
    end

    // No MMIO peripheral response
    assign bus_read_data = 32'h0000_0000;
    assign bus_hit       = 1'b0;

    //2 FAULTS  
    always @(negedge clk) begin
        if (!reset) begin

            // Fault #1: word 37, bit 7 stuck-at-1
            dut.dmem.mem[37][7] = 1'b1;

            // Fault #2: word 38, bit 5 stuck-at-0
            dut.dmem.mem[38][5] = 1'b0;

        end
    end

    initial begin

    reset            = 1'b1;
    first_fail_addr  = 32'h0;
    second_fail_addr = 32'h0;


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

    // Second MBIST should FAIL because word 38 is also faulty
    wait (
        dut.mbist_done == 1'b1 &&
        mbist_fail_o   == 1'b1
    );

    #1;
    second_fail_addr = dut.mbist_fail_addr;

    repeat (2) @(posedge clk);
    #1;

    $display("--------------------------------");
    $display("Unrecoverable BISR repair test finished");
    $display("FIRST FAIL ADDR  = %h", first_fail_addr);
    $display("SECOND FAIL ADDR = %h", second_fail_addr);
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

    if (second_fail_addr !== 32'h0000_0098)
        $error(
            "Incorrect second failure address. Expected 0x98, got %h",
            second_fail_addr
        );

    if (mbist_pass_o !== 1'b0)
        $error("MBIST incorrectly passed despite second fault");

    if (mbist_fail_o !== 1'b1)
        $error("Second DMEM fault was not detected");

    if (dut.cpu_enable !== 1'b0)
        $error("CPU incorrectly enabled after unrecoverable fault");

    if (dut.cpu_reset !== 1'b1)
        $error("CPU incorrectly released after unrecoverable fault");


    if (
        first_fail_addr       === 32'h0000_0094 &&
        second_fail_addr     === 32'h0000_0098 &&
        dut.repair_valid      === 1'b1 &&
        dut.repair_addr       === 8'd37 &&
        dut.repair_attempted  === 1'b1 &&
        mbist_pass_o          === 1'b0 &&
        mbist_fail_o          === 1'b1 &&
        dut.cpu_enable        === 1'b0 &&
        dut.cpu_reset         === 1'b1
    )
        $display(
        "TEST PASSED: second DMEM fault exceeded BISR repair capacity and CPU boot was blocked"
    );
    $finish;

    end

endmodule