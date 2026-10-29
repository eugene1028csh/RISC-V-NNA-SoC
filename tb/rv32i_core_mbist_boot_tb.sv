`timescale 1ns/1ps

module rv32i_core_mbist_boot_tb;

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


    // ----------------------------
    // No MMIO peripheral response
    // ----------------------------

    assign bus_read_data = 32'h0000_0000;
    assign bus_hit       = 1'b0;


    // ----------------------------
    // Test
    // ----------------------------

    initial begin

        reset = 1'b1;

        repeat (5) @(posedge clk);

        reset = 1'b0;


        // Wait for MBIST result
        wait (mbist_pass_o == 1'b1 ||
            mbist_fail_o == 1'b1);

        // If MBIST passed, wait for the core boot controller
        // to actually release the CPU
        if (mbist_pass_o == 1'b1)
            wait (dut.cpu_enable == 1'b1);

        #1;

        $display("-------------------------------");
        $display("Core boot MBIST finished");
        $display("MBIST PASS = %b", mbist_pass_o);
        $display("MBIST FAIL = %b", mbist_fail_o);

        // Internal core boot-control signals
        $display("CPU ENABLE = %b", dut.cpu_enable);
        $display("CPU RESET  = %b", dut.cpu_reset);
        $display("-------------------------------");


        if (mbist_pass_o !== 1'b1)
            $error("Boot MBIST did not pass");

        if (mbist_fail_o !== 1'b0)
            $error("Boot MBIST incorrectly failed");

        if (dut.cpu_enable !== 1'b1)
            $error("CPU was not enabled after MBIST PASS");

        if (dut.cpu_reset !== 1'b0)
            $error("CPU remained in reset after MBIST PASS");


        if (
            mbist_pass_o   === 1'b1 &&
            mbist_fail_o   === 1'b0 &&
            dut.cpu_enable === 1'b1 &&
            dut.cpu_reset  === 1'b0
        )
            $display(
                "TEST PASSED: CPU released after clean MBIST"
            );

        $finish;

    end

endmodule