`timescale 1ns/1ps

module dmem_mbist_fault_tb;

    localparam int DEPTH = 256;

    logic clk;
    logic reset;
    logic start;

    logic busy;
    logic done;
    logic pass;
    logic fail;

    logic        mem_we;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;

    logic [31:0] fail_addr;

    logic [31:0] mem [0:DEPTH-1];


    // ----------------------------
    // DUT
    // ----------------------------

    dmem_mbist #(
        .ADDR_WIDTH(8)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .start     (start),

        .busy      (busy),
        .done      (done),
        .pass      (pass),
        .fail      (fail),

        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),

        .fail_addr (fail_addr)
    );


    // ----------------------------
    // Clock
    // ----------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ----------------------------
    // Memory model
    // ----------------------------

    assign mem_rdata = mem[mem_addr[9:2]];

    always_ff @(posedge clk) begin
        if (mem_we) begin
            mem[mem_addr[9:2]] <= mem_wdata;
        end
    end

    // ----------------------------
    // Test sequence
    // ----------------------------

    initial begin

        reset = 1'b1;
        start = 1'b0;

        repeat (5) @(posedge clk);

        reset = 1'b0;

        // One-cycle START pulse
        @(posedge clk);
        start = 1'b1;

        @(posedge clk);
        start = 1'b0;


        // Wait until entire MBIST finishes
        wait (done == 1'b1);

        #1;

        $display("-------------------------------");
        $display("MBIST finished");
        $display("PASS      = %b", pass);
        $display("FAIL      = %b", fail);
        $display("FAIL ADDR = %h", fail_addr);
        $display("-------------------------------");

        if (pass !== 1'b1)
            $error("MBIST did not PASS fault-free memory");

        if (fail !== 1'b0)
            $error("MBIST falsely detected a memory fault");

        if ((pass === 1'b1) && (fail === 1'b0))
            $display("TEST PASSED: fault-free memory correctly passed");

        $finish;
    end

endmodule