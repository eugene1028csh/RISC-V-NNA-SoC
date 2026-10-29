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

            8'd7: instruction = 32'h40000537; // lui x10, 0x40000
                                      // x10 = 0x40000000


            // -------------------------------------------------
            // NNA base address
            // x10 = 0x40000000
            // -------------------------------------------------

            8'd8:  instruction = 32'h01000293; // 16
            8'd9:  instruction = 32'h00552823; // B0  -> 0x10
            8'd10: instruction = 32'h00F00293; // 15
            8'd11: instruction = 32'h00552A23; // B1  -> 0x14
            8'd12: instruction = 32'h00E00293; // 14
            8'd13: instruction = 32'h00552C23; // B2  -> 0x18
            8'd14: instruction = 32'h00D00293; // 13
            8'd15: instruction = 32'h00552E23; // B3  -> 0x1C

            8'd16: instruction = 32'h00C00293; // 12
            8'd17: instruction = 32'h02552023; // B4  -> 0x20
            8'd18: instruction = 32'h00B00293; // 11
            8'd19: instruction = 32'h02552223; // B5  -> 0x24
            8'd20: instruction = 32'h00A00293; // 10
            8'd21: instruction = 32'h02552423; // B6  -> 0x28
            8'd22: instruction = 32'h00900293; // 9
            8'd23: instruction = 32'h02552623; // B7  -> 0x2C

            8'd24: instruction = 32'h00800293; // 8
            8'd25: instruction = 32'h02552823; // B8  -> 0x30
            8'd26: instruction = 32'h00700293; // 7
            8'd27: instruction = 32'h02552A23; // B9  -> 0x34
            8'd28: instruction = 32'h00600293; // 6
            8'd29: instruction = 32'h02552C23; // B10 -> 0x38
            8'd30: instruction = 32'h00500293; // 5
            8'd31: instruction = 32'h02552E23; // B11 -> 0x3C

            8'd32: instruction = 32'h00400293; // 4
            8'd33: instruction = 32'h04552023; // B12 -> 0x40
            8'd34: instruction = 32'h00300293; // 3
            8'd35: instruction = 32'h04552223; // B13 -> 0x44
            8'd36: instruction = 32'h00200293; // 2
            8'd37: instruction = 32'h04552423; // B14 -> 0x48
            8'd38: instruction = 32'h00100293; // 1
            8'd39: instruction = 32'h04552623; // B15 -> 0x4C

            8'd40: instruction = 32'h00100293; // 1
            8'd41: instruction = 32'h04552823; // A0  -> 0x50
            8'd42: instruction = 32'h00200293; // 2
            8'd43: instruction = 32'h04552A23; // A1  -> 0x54
            8'd44: instruction = 32'h00300293; // 3
            8'd45: instruction = 32'h04552C23; // A2  -> 0x58
            8'd46: instruction = 32'h00400293; // 4
            8'd47: instruction = 32'h04552E23; // A3  -> 0x5C

            8'd48: instruction = 32'h00500293; // 5
            8'd49: instruction = 32'h06552023; // A4  -> 0x60
            8'd50: instruction = 32'h00600293; // 6
            8'd51: instruction = 32'h06552223; // A5  -> 0x64
            8'd52: instruction = 32'h00700293; // 7
            8'd53: instruction = 32'h06552423; // A6  -> 0x68
            8'd54: instruction = 32'h00800293; // 8
            8'd55: instruction = 32'h06552623; // A7  -> 0x6C

            8'd56: instruction = 32'h00900293; // 9
            8'd57: instruction = 32'h06552823; // A8  -> 0x70
            8'd58: instruction = 32'h00A00293; // 10
            8'd59: instruction = 32'h06552A23; // A9  -> 0x74
            8'd60: instruction = 32'h00B00293; // 11
            8'd61: instruction = 32'h06552C23; // A10 -> 0x78
            8'd62: instruction = 32'h00C00293; // 12
            8'd63: instruction = 32'h06552E23; // A11 -> 0x7C

            8'd64: instruction = 32'h00D00293; // 13
            8'd65: instruction = 32'h08552023; // A12 -> 0x80
            8'd66: instruction = 32'h00E00293; // 14
            8'd67: instruction = 32'h08552223; // A13 -> 0x84
            8'd68: instruction = 32'h00F00293; // 15
            8'd69: instruction = 32'h08552423; // A14 -> 0x88
            8'd70: instruction = 32'h01000293; // 16
            8'd71: instruction = 32'h08552623; // A15 -> 0x8C

            8'd72: instruction = 32'h08052823; // bias0 = 0 -> 0x90
            8'd73: instruction = 32'h08052A23; // bias1 = 0 -> 0x94
            8'd74: instruction = 32'h08052C23; // bias2 = 0 -> 0x98
            8'd75: instruction = 32'h08052E23; // bias3 = 0 -> 0x9C

            8'd76: instruction = 32'h00100293; // x5 = 1
            8'd77: instruction = 32'h00552023; // START -> 0x00

            8'd78: instruction = 32'h00452303; // lw x6, 0x04(x10)
            8'd79: instruction = 32'hFE030EE3; // beq x6,x0,-4
            8'd80: instruction = 32'h0C052A03; // OUT0  -> 0xC0 = 80
            8'd81: instruction = 32'h0C452A03; // OUT1  -> 0xC4 = 70
            8'd82: instruction = 32'h0C852A03; // OUT2  -> 0xC8 = 60
            8'd83: instruction = 32'h0CC52A03; // OUT3  -> 0xCC = 50

            8'd84: instruction = 32'h0D052A03; // OUT4  -> 0xD0 = 240
            8'd85: instruction = 32'h0D452A03; // OUT5  -> 0xD4 = 214
            8'd86: instruction = 32'h0D852A03; // OUT6  -> 0xD8 = 188
            8'd87: instruction = 32'h0DC52A03; // OUT7  -> 0xDC = 162

            8'd88: instruction = 32'h0E052A03; // OUT8  -> 0xE0 = 400
            8'd89: instruction = 32'h0E452A03; // OUT9  -> 0xE4 = 358
            8'd90: instruction = 32'h0E852A03; // OUT10 -> 0xE8 = 316
            8'd91: instruction = 32'h0EC52A03; // OUT11 -> 0xEC = 274

            8'd92: instruction = 32'h0F052A03; // OUT12 -> 0xF0 = 560
            8'd93: instruction = 32'h0F452A03; // OUT13 -> 0xF4 = 502
            8'd94: instruction = 32'h0F852A03; // OUT14 -> 0xF8 = 444
            8'd95: instruction = 32'h0FC52A03; // OUT15 -> 0xFC = 386

            8'd96: instruction = 32'h0000006F; // jal x0,0

            // NOP for unused addresses
            default:
                instruction = 32'h00000013; // addi x0,x0,0

        endcase
    end

endmodule