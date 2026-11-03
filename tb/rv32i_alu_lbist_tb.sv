`timescale 1ns/1ps

module rv32i_alu_lbist_tb;

    logic clk;
    logic reset;
    logic start;

    logic busy;
    logic done;
    logic pass;
    logic fail;
    logic inject_fault;
    logic [31:0] signature;
    logic [4:0] fault_bit;
    logic fault_stuck_at;


    rv32i_alu_lbist dut (
        .clk       (clk),
        .reset     (reset),
        .start     (start),

        .busy      (busy),
        .done      (done),

        .pass (pass),
        .fail (fail),

        .signature (signature),
        .inject_fault (inject_fault),

        .fault_bit      (fault_bit),
        .fault_stuck_at (fault_stuck_at)
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
    int activation_count = 0;
    

    always @(posedge clk) begin
       if (reset)
            activation_count <= 0;
        else if (busy && inject_fault && dut.alu_result[fault_bit] === ~fault_stuck_at)
            activation_count <= activation_count + 1;
    end

    always @(posedge clk) begin
        if (reset)
            capture_count <= 0;
        else if (busy)
            capture_count <= capture_count + 1;
    end


    initial begin

        reset = 1'b1;
        start = 1'b0;
        inject_fault = 1'b1;
        fault_bit = 5'd0;
        fault_stuck_at = 1'b1;

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
        $display("FAULT ACTIVATIONS = %0d", activation_count);
        $display("-------------------------------");

        if (capture_count != 100)
            $fatal(1, "Incorrect number of LBIST patterns");

        if (signature === 32'h6A86_A2B4)
            $fatal(1, "Injected fault was NOT detected");

        if (pass !== 1'b0 || fail !== 1'b1)
            $fatal(1, "LBIST PASS/FAIL incorrect");

        if (activation_count == 0)
            $fatal(1, "Stuck at fault never activated");

        if ($isunknown(signature)) //checks for unknown/unresolved bits, 0 if none, 1 if yes
            $fatal(1, "MISR signature contains unknown bits");
            

        $display("ALU LBIST FAULT DETECTED");

        $finish;

    end

endmodule