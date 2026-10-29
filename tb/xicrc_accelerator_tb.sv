`timescale 1ns/1ps

module xicrc_accelerator_tb;

    logic [31:0] ext_rs1_data;
    logic [31:0] ext_rs2_data;
    logic [6:0]  ext_funct7;
    logic [2:0]  ext_funct3;

    wire         ext_ready;
    wire [31:0]  ext_result;
    wire         ext_writeback;
    wire         ext_illegal;


    xicrc_accelerator_unit dut (
        .ext_rs1_data   (ext_rs1_data),
        .ext_rs2_data   (ext_rs2_data),
        .ext_funct7     (ext_funct7),
        .ext_funct3     (ext_funct3),

        .ext_ready      (ext_ready),
        .ext_result     (ext_result),
        .ext_writeback  (ext_writeback),
        .ext_illegal    (ext_illegal)
    );


    initial begin
        $dumpfile("xicrc.vcd");
        $dumpvars(0, xicrc_accelerator_tb);
    end


    initial begin

        // Default: not an XiCRC instruction
        ext_rs1_data = 32'h0000_0000;
        ext_rs2_data = 32'h0000_0000;
        ext_funct7   = 7'b0000000;
        ext_funct3   = 3'b000;

        #20;


        // ----------------------------
        // CRCB test
        // ----------------------------

        ext_rs1_data = 32'h0000_000D;
        ext_rs2_data = 32'h0000_0000;

        // XiCRC funct7
        ext_funct7 = 7'b1000000;

        // CRCB
        ext_funct3 = 3'b000;

        #20;

        $display("-------------------------------");
        $display("XiCRC CRCB test");
        $display("RS1       = %h", ext_rs1_data);
        $display("RS2       = %h", ext_rs2_data);
        $display("READY     = %b", ext_ready);
        $display("WRITEBACK = %b", ext_writeback);
        $display("ILLEGAL   = %b", ext_illegal);
        $display("RESULT    = %h", ext_result);
        $display("-------------------------------");

        if (ext_ready !== 1'b1)
            $error("XiCRC instruction not recognised");

        if (ext_writeback !== 1'b1)
            $error("XiCRC writeback not asserted");

        if (ext_illegal !== 1'b0)
            $error("Valid XiCRC instruction marked illegal");

        if (ext_result !== 32'h0000_D1AD)
            $error(
                "Wrong CRC result. Expected 0000D1AD, got %h",
                ext_result
            );

        if (
            ext_ready     === 1'b1 &&
            ext_writeback === 1'b1 &&
            ext_illegal   === 1'b0 &&
            ext_result    === 32'h0000_D1AD
        )
            $display("TEST PASSED: CRCB result correctly generated");

        #20;

        $finish;

    end

endmodule