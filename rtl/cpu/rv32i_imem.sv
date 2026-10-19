module rv32i_imem #(
    parameter DEPTH = 256
)(
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    always_comb begin
        case (addr[9:2])

            // -------------------------------------------------
            // XiCRC self-check
            // CRCB(13, initial_crc=0) should produce 0xD1AD
            // If CRC is wrong -> hang at instruction 6
            // -------------------------------------------------

            8'd0: instruction = 32'h00D00093; // addi x1, x0, 13
            8'd1: instruction = 32'h00000113; // addi x2, x0, 0
            8'd2: instruction = 32'h802081B3; // CRCB x3, x1, x2

            8'd3: instruction = 32'h0000D237; // lui  x4, 0xD
            8'd4: instruction = 32'h1AD20213; // addi x4, x4, 0x1AD
                                                 // x4 = 0x0000D1AD

            8'd5: instruction = 32'h00418463; // beq x3, x4, +8
            8'd6: instruction = 32'h0000006F; // FAIL: jal x0, 0


            // -------------------------------------------------
            // NNA base address
            // x10 = 0x40000000
            // -------------------------------------------------

            8'd7: instruction = 32'h40000537; // lui x10, 0x40000


            // -------------------------------------------------
            // Inputs: [1, 2, 3, 4]
            // -------------------------------------------------

            8'd8:  instruction = 32'h00100293; // addi x5,x0,1
            8'd9:  instruction = 32'h00552823; // sw x5,0x10(x10)

            8'd10: instruction = 32'h00200293; // addi x5,x0,2
            8'd11: instruction = 32'h00552A23; // sw x5,0x14(x10)

            8'd12: instruction = 32'h00300293; // addi x5,x0,3
            8'd13: instruction = 32'h00552C23; // sw x5,0x18(x10)

            8'd14: instruction = 32'h00400293; // addi x5,x0,4
            8'd15: instruction = 32'h00552E23; // sw x5,0x1C(x10)


            // -------------------------------------------------
            // Weights: 1..16
            // -------------------------------------------------

            8'd16: instruction = 32'h00100293;
            8'd17: instruction = 32'h04552023; // weight0  = 1

            8'd18: instruction = 32'h00200293;
            8'd19: instruction = 32'h04552223; // weight1  = 2

            8'd20: instruction = 32'h00300293;
            8'd21: instruction = 32'h04552423; // weight2  = 3

            8'd22: instruction = 32'h00400293;
            8'd23: instruction = 32'h04552623; // weight3  = 4

            8'd24: instruction = 32'h00500293;
            8'd25: instruction = 32'h04552823; // weight4  = 5

            8'd26: instruction = 32'h00600293;
            8'd27: instruction = 32'h04552A23; // weight5  = 6

            8'd28: instruction = 32'h00700293;
            8'd29: instruction = 32'h04552C23; // weight6  = 7

            8'd30: instruction = 32'h00800293;
            8'd31: instruction = 32'h04552E23; // weight7  = 8

            8'd32: instruction = 32'h00900293;
            8'd33: instruction = 32'h06552023; // weight8  = 9

            8'd34: instruction = 32'h00A00293;
            8'd35: instruction = 32'h06552223; // weight9  = 10

            8'd36: instruction = 32'h00B00293;
            8'd37: instruction = 32'h06552423; // weight10 = 11

            8'd38: instruction = 32'h00C00293;
            8'd39: instruction = 32'h06552623; // weight11 = 12

            8'd40: instruction = 32'h00D00293;
            8'd41: instruction = 32'h06552823; // weight12 = 13

            8'd42: instruction = 32'h00E00293;
            8'd43: instruction = 32'h06552A23; // weight13 = 14

            8'd44: instruction = 32'h00F00293;
            8'd45: instruction = 32'h06552C23; // weight14 = 15

            8'd46: instruction = 32'h01000293;
            8'd47: instruction = 32'h06552E23; // weight15 = 16


            // -------------------------------------------------
            // Biases: [-40, -60, 5, -200]
            // -------------------------------------------------

            8'd48: instruction = 32'hFD800293; // addi x5,x0,-40
            8'd49: instruction = 32'h08552023; // bias0

            8'd50: instruction = 32'hFC400293; // addi x5,x0,-60
            8'd51: instruction = 32'h08552223; // bias1

            8'd52: instruction = 32'h00500293; // addi x5,x0,5
            8'd53: instruction = 32'h08552423; // bias2

            8'd54: instruction = 32'hF3800293; // addi x5,x0,-200
            8'd55: instruction = 32'h08552623; // bias3


            // -------------------------------------------------
            // START
            // -------------------------------------------------

            8'd56: instruction = 32'h00100293; // x5 = 1
            8'd57: instruction = 32'h00552023; // sw x5,0(x10)


            // -------------------------------------------------
            // Poll STATUS until DONE = 1
            // -------------------------------------------------

            8'd58: instruction = 32'h00452303; // lw x6,4(x10)
            8'd59: instruction = 32'hFE030EE3; // beq x6,x0,-4


            // -------------------------------------------------
            // Read results
            //
            // Expected:
            // x20 = 0
            // x21 = 10
            // x22 = 115
            // x23 = 0
            // -------------------------------------------------

            8'd60: instruction = 32'h0C052A03; // lw x20,0xC0(x10)
            8'd61: instruction = 32'h0C452A83; // lw x21,0xC4(x10)
            8'd62: instruction = 32'h0C852B03; // lw x22,0xC8(x10)
            8'd63: instruction = 32'h0CC52B83; // lw x23,0xCC(x10)


            // Finished: stay here forever
            8'd64: instruction = 32'h0000006F; // jal x0,0


            // NOP for unused addresses
            default:
                instruction = 32'h00000013; // addi x0,x0,0

        endcase
    end

endmodule