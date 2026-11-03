`timescale 1ns/1ps

module rv32i_core_crc_fault_tb;

logic clk = 0;
logic reset = 1;

logic [31:0] bus_addr;
logic [31:0] bus_write_data;
logic bus_write_en;

logic mbist_pass_o;
logic mbist_fail_o;

always #5 clk = ~clk;

rv32i_core dut (
    .clk(clk),
    .reset(reset),

    .bus_addr(bus_addr),
    .bus_write_data(bus_write_data),
    .bus_write_en(bus_write_en),

    .bus_read_data(32'd0),
    .bus_hit(1'b0),

    .mbist_pass_o(mbist_pass_o),
    .mbist_fail_o(mbist_fail_o)
);

initial begin
    repeat (5) @(negedge clk);
    reset = 0;
    // Force actual CPU CRCW calculation path to zero
    force dut.xicrc_unit.u_xicrc_exec.crc32_result = 16'h0000;

    // Stage 1: Memory testing
    wait(dut.mbist_boot_pass == 1'b1);
    $display("MBIST PASSED");

    if (dut.cpu_enable !== 1'b0)
        $fatal(1, "CPU enabled before ALU LBIST");

    // Stage 2: ALU testing
    wait(dut.alu_lbist_busy == 1'b1);
    $display("ALU LBIST STARTED");

    if (dut.pc !== 32'd0)
        $fatal(1, "CPU PC changed during LBIST");

    wait(dut.alu_lbist_done == 1'b1);
    #1;

    $display("ALU SIGNATURE = %h",
             dut.alu_lbist_signature);

    if (dut.alu_lbist_pass !== 1'b1 ||
        dut.alu_lbist_fail !== 1'b0 ||
        dut.alu_lbist_signature !== 32'h6A86_A2B4)
        $fatal(1, "CPU ALU LBIST FAILED");

    $display("ALU LBIST PASSED");

   // Stage 3: Faulty XiCRC LBIST
    wait(dut.crc_lbist_busy == 1'b1);
    $display("XiCRC LBIST STARTED");

    wait(dut.crc_lbist_done == 1'b1);
    #1;

    $display("FAULTY XiCRC SIGNATURE = %h",
            dut.crc_lbist_signature);

    if (dut.crc_lbist_signature === 32'h561D52A3)
        $fatal(1, "XiCRC fault NOT detected");

    if (dut.crc_lbist_pass !== 1'b0 ||
        dut.crc_lbist_fail !== 1'b1)
        $fatal(1, "XiCRC failure not reported");

    repeat (2) @(negedge clk);

    if (dut.cpu_enable !== 1'b0 || dut.pc !== 32'd0)
        $fatal(1, "CPU booted despite XiCRC failure");

    $display("PASS: FAULTY XiCRC DETECTED, CPU BOOT BLOCKED");

    release dut.xicrc_unit.u_xicrc_exec.crc32_result;
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Simulation timeout");
end

endmodule