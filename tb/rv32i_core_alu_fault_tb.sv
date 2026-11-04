`timescale 1ns/1ps

module rv32i_core_alu_fault_tb;

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
    .mbist_fail_o(mbist_fail_o),
    .nna_boot_pass_i(1'b1),
    .core_dft_ready_o()
);

initial begin
    repeat (5) @(negedge clk);
    reset = 0;

    // Force the CPU's actual ALU carry into bit 4 to zero
    force dut.alu.carry_into_bit4 = 1'b0;

    // Stage 1: Memory testing
    wait(dut.mbist_boot_pass == 1'b1);
    $display("MBIST PASSED");

    if (dut.cpu_enable !== 1'b0)
        $fatal(1, "CPU enabled before ALU LBIST");

    wait(dut.alu_lbist_done == 1'b1);
    #1;

    $display("FAULTY ALU SIGNATURE = %h",
            dut.alu_lbist_signature);

    if (dut.alu_lbist_signature === 32'h6A86_A2B4)
        $fatal(1, "ALU fault not detected");

    if (dut.alu_lbist_pass !== 1'b0 ||
        dut.alu_lbist_fail !== 1'b1)
        $fatal(1, "ALU failure not reported");

    repeat (2) @(negedge clk);

    if (dut.cpu_enable !== 1'b0 || dut.pc !== 32'd0)
        $fatal(1, "CPU booted despite ALU failure");

    $display("PASS: FAULTY ALU DETECTED, CPU BOOT BLOCKED");
    release dut.alu.carry_into_bit4;
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Simulation timeout");
end

endmodule