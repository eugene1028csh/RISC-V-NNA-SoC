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
    int activation_count = 0; //counts patterns activating a particular fault
    int detected_count = 0; //counts distinct fault cases detected
    int carry_activation_count = 0;

    always @(posedge clk) begin
        if (reset || dut.accepted_start)
            carry_activation_count <= 0;
        else if (busy &&
                dut.op_counter == 4'd0 &&
                dut.alu_dut.add_low[4] === 1'b1)
            carry_activation_count <= carry_activation_count + 1;
    end
        

    always @(posedge clk) begin
       if (reset || dut.accepted_start)
            activation_count <= 0;
        else if (busy && inject_fault && dut.alu_result[fault_bit] === ~fault_stuck_at)
            activation_count <= activation_count + 1;
    end

    always @(posedge clk) begin
        if (reset || dut.accepted_start)
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
        //releases reset before the 64-test campaign begins.

        // Verify fault-free split adder
        inject_fault = 1'b0;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        #1;

        if (signature !== 32'h6A86_A2B4)
            $fatal(1, "Split adder changed golden signature");

        if (pass !== 1'b1 || fail !== 1'b0)
            $fatal(1, "Fault-free LBIST failed");

        $display("FAULT-FREE SPLIT ADDER VERIFIED");

        // Internal carry stuck-at-0 fault test
        @(negedge clk);
        inject_fault = 1'b0;
        force dut.alu_dut.carry_into_bit4 = 1'b0;
        //This tells the simulator to override the carry signal and hold it at zero, 
        //regardless of what the lower adder calculates.

        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        #1;

        $display("CARRY SA0 SIGNATURE = %h", signature);
        $display("PASS = %b, FAIL = %b", pass, fail);

        $display("CARRY ACTIVATIONS = %0d", carry_activation_count);

        if (capture_count != 100)
            $fatal(1, "Carry test captured incorrect number of patterns");

        if (carry_activation_count == 0)
            $fatal(1, "Carry fault was never activated");

        if ($isunknown(signature))
            $fatal(1, "Carry test produced unknown MISR signature");
            
        if (signature === 32'h6A86_A2B4)
            $fatal(1, "Carry fault not detected");

        if (pass !== 1'b0 || fail !== 1'b1)
            $fatal(1, "Incorrect LBIST flags");

        release dut.alu_dut.carry_into_bit4;//This removes the override and restores normal signal behaviour.


        // Restore fault injection for 64-case campaign
        inject_fault = 1'b1;

        for (int bit_idx = 0; bit_idx <32;  bit_idx++) begin
            for (int sa = 0; sa < 2 ; sa++) begin
                //use negedge cuz contorller acts on rising edge, negedge for tb allows us to change inputs safely between posedges
                @(negedge clk);
                fault_bit = bit_idx;
                fault_stuck_at = sa;
                start = 1'b1;
                
                @(negedge clk);
                start = 1'b0;

                // Wait until 100-pattern LBIST finishes
                wait (done == 1'b1);
                #1;

                if (capture_count != 100) //checks captured patterns
                    $fatal(1, "Incorrect number of LBIST patterns");

                if ($isunknown(signature)) //checks for unknown/unresolved bits, 0 if none, 1 if yes
                    $fatal(1, "MISR signature contains unknown bits");

                if (signature === 32'h6A86_A2B4) begin //checks controller flags, MISR signature matches golden
                    if (pass !== 1'b1 || fail !== 1'b0)
                        $fatal(1, "Golden signature matched, but PASS/FAIL flags incorrect");
                end
                else begin //checks controller flags,MISR signature doesnt match golden
                    if (pass !== 1'b0 || fail !== 1'b1)
                        $fatal(1, "Signature mismatch, PASS/FAIL flags incorrect");
                end

                //Record fault detection
                if (signature !== 32'h6A86_A2B4) begin
                    detected_count++;

                    $display("Bit %0d SA%0d | Activations=%0d | Signature=%h | DETECTED",
                        bit_idx, sa, activation_count, signature);
                 end
                else begin
                    $display("Bit %0d SA%0d | Activations=%0d | Signature=%h | MISSED",
                            bit_idx, sa, activation_count, signature);
                end

            end   
        end
    

        $display("-------------------------------");
        $display("TOTAL FAULTS CASE = 64");
        $display("FAULTS DETECTED = %0d", detected_count);
        $display("FAULTS MISSED= %0d", 64 - detected_count);
        $display("FAULT COVERAGE = %0.2f%%", (detected_count * 100.0)/64.0);
        $display("-------------------------------");
            

        $display("ALU LBIST FAULT DETECTED");

        $finish;
    end
endmodule