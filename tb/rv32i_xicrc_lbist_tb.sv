`timescale 1ns/1ps

module rv32i_xicrc_lbist_tb;

logic clk = 0;
logic reset = 1;
logic start = 0;

logic busy, done, pass, fail;
logic [31:0] signature;
logic inject_fault = 0;
logic [3:0] fault_bit = 0;
logic fault_stuck_at = 0;

integer capture_count = 0;
integer crcb_count = 0;
integer crch_count = 0;
integer crcw_count = 0;

integer detected_count = 0;


// 100 MHz simulation clock
always #5 clk = ~clk;

rv32i_xicrc_lbist dut (
    .clk       (clk),
    .reset     (reset),
    .start     (start),
    .busy      (busy),
    .done      (done),
    .pass      (pass),
    .fail      (fail),
    .signature (signature),
    .inject_fault    (inject_fault),
    .fault_bit       (fault_bit),
    .fault_stuck_at  (fault_stuck_at),
    .external_crc_result (16'd0)
);

// Count responses captured by MISR
always @(posedge clk) begin
    if (reset || dut.accepted_start) begin
        capture_count <= 0;
        crcb_count    <= 0;
        crch_count    <= 0;
        crcw_count    <= 0;
    end
    else if (busy) begin
        capture_count <= capture_count + 1;

        case (dut.crc_sel)
            2'b00: crcb_count <= crcb_count + 1;
            2'b01: crch_count <= crch_count + 1;
            2'b10: crcw_count <= crcw_count + 1;
        endcase
    end
end

initial begin
    repeat (5) @(negedge clk);
    reset = 0;

    @(negedge clk);
    start = 1;

    @(negedge clk);
    start = 0;

    wait(done);
    #1;

    $display("XiCRC SIGNATURE = %h", signature);
    $display("CAPTURE COUNT = %0d", capture_count);

    if (capture_count != 99)
        $fatal(1, "Expected 99 CRC captures");

    if ($isunknown(signature))
        $fatal(1, "Unknown bits in signature");

    $display("CRCB COUNT = %0d", crcb_count);
    $display("CRCH COUNT = %0d", crch_count);
    $display("CRCW COUNT = %0d", crcw_count);

    if (crcb_count != 33 ||
        crch_count != 33 ||
        crcw_count != 33)
        $fatal(1, "Incorrect CRC operation distribution");

    if (signature !== 32'h561D52A3)
        $fatal(1, "XiCRC signature mismatch");

    $display("PASS = %b, FAIL = %b", pass, fail);

    if (pass !== 1'b1 || fail !== 1'b0)
        $fatal(1, "XiCRC LBIST PASS/FAIL check failed");

    $display("XiCRC LBIST OPERATION COVERAGE PASSED");
    for (int bit_idx = 0; bit_idx < 16; bit_idx++) begin
        for (int sa = 0; sa < 2; sa++) begin

            @(negedge clk);
            inject_fault   = 1'b1;
            fault_bit      = bit_idx;
            fault_stuck_at = sa;
            start          = 1'b1;

            @(negedge clk);
            start = 1'b0;

            wait(done);
            #1;

            if (capture_count != 99)
                $fatal(1, "Incorrect capture count");

            if ($isunknown(signature))
                $fatal(1, "Unknown signature");

            if (signature === 32'h561D52A3)
                $fatal(1, "Bit %0d SA%0d NOT detected", bit_idx, sa);

            if (pass !== 1'b0 || fail !== 1'b1)
                $fatal(1, "Incorrect PASS/FAIL");

            detected_count++;

            $display("Bit %0d SA%0d | Signature=%h | DETECTED",
                    bit_idx, sa, signature);
        end
    end

    $display("-------------------------------");
    $display("FAULTS DETECTED = %0d / 32", detected_count);
    $display("FAULT COVERAGE = %0.2f%%",
         detected_count * 100.0 / 32.0);

    // Disable previous output fault injection
    @(negedge clk);
    inject_fault = 1'b0;

    // Force the internal CRCB calculation result to zero
    force dut.crc_dut.crc8_result = 16'h0000;

    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    wait(done);
    #1;

    $display("INTERNAL CRCB FAULT SIGNATURE = %h", signature);
    $display("PASS = %b, FAIL = %b", pass, fail);

    if (capture_count != 99)
        $fatal(1, "Incorrect capture count");

    if (signature === 32'h561D52A3)
        $fatal(1, "Internal CRCB fault NOT detected");

    if (pass !== 1'b0 || fail !== 1'b1)
        $fatal(1, "Incorrect PASS/FAIL");

    $display("INTERNAL CRCB FAULT DETECTED");

    release dut.crc_dut.crc8_result;

    // Internal CRCH fault
    @(negedge clk);
    force dut.crc_dut.crc16_result = 16'h0000;
    start = 1'b1;

    @(negedge clk);
    start = 1'b0;

    wait(done);
    #1;

    $display("CRCH FAULT SIGNATURE = %h", signature);

    if (signature === 32'h561D52A3 ||
        pass !== 1'b0 || fail !== 1'b1)
        $fatal(1, "Internal CRCH fault NOT detected");

    $display("INTERNAL CRCH FAULT DETECTED");

    release dut.crc_dut.crc16_result;

    // Internal CRCW fault
    @(negedge clk);
    force dut.crc_dut.crc32_result = 16'h0000;
    start = 1'b1;

    @(negedge clk);
    start = 1'b0;

    wait(done);
    #1;

    $display("CRCW FAULT SIGNATURE = %h", signature);
    $display("PASS = %b, FAIL = %b", pass, fail);

    if (capture_count != 99)
        $fatal(1, "Incorrect capture count");

    if (signature === 32'h561D52A3 ||
        pass !== 1'b0 || fail !== 1'b1)
        $fatal(1, "Internal CRCW fault NOT detected");

    $display("INTERNAL CRCW FAULT DETECTED");

    release dut.crc_dut.crc32_result;
    $finish;
end

initial begin
    #50000;
    $fatal(1, "Simulation timeout");
end


endmodule