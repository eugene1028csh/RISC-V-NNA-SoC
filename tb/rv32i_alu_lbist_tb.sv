`timescale 1ns/1ps

module rv32i_alu_lbist_tb;

    logic clk;
    logic reset;
    logic start;

    logic busy;
    logic done;
    logic pass;
    logic fail;
    logic [31:0] signature;


    rv32i_alu_lbist dut (
        .clk       (clk),
        .reset     (reset),
        .start     (start),

        .busy      (busy),
        .done      (done),

        .pass (pass),
        .fail (fail),

        .signature (signature)
    );


    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // Waveform
    initial begin
        $dumpfile("alu_lbist.vcd");
        $dumpvars(0, rv32i_alu_lbist_tb);
    end

    initial begin
      #100000;
        $error("TIMEOUT: LBIST did not finish");
        $finish;
    end

    int capture_count = 0;

    always @(posedge clk) begin
        if (reset)
            capture_count <= 0;
        else if (busy)
            capture_count <= capture_count + 1;
    end


    initial begin

        reset = 1'b1;
        start = 1'b0;

        repeat (5) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;


        // Wait until 100-pattern LBIST finishes
        wait (done == 1'b1);

        
        #1;

        $display("-------------------------------");
        $display("ALU LBIST finished");
        $display("CAPTURE COUNT   = %0d", capture_count);
        $display("FINAL SIGNATURE = %h", signature);
        $display("PASS = %b, FAIL = %b", pass, fail);
        $display("-------------------------------");

        if (capture_count != 100)
            $fatal(1, "Incorrect number of LBIST patterns");

        if (signature !== 32'h6A86_A2B4)
            $fatal(1, "LBIST signature mismatch");

        if (pass !== 1'b1 || fail !== 1'b0)
            $fatal(1, "LBIST PASS/FAIL incorrect");

        $display("ALU LBIST TEST PASSED");

        $finish;

    end

endmodule