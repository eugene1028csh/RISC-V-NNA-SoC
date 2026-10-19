import rv32i_types::*;

module rv32i_imme_gnrtr(
input logic [31:0] instruction,
output logic [31:0] immediate,
input imm_type_t imm_type
);

always_comb begin
    case (imm_type)

    IMM_I : immediate = {{20{instruction[31]}}, instruction [31:20]};
    /*
    20 * MSB (bit 31) +
    append the original 12-bit immediate instruction[31:20]
    */
    IMM_S : immediate = {{20{instruction[31]}}, instruction [31:25], instruction [11:7]};
    /*
    20 copied sign bits + 7 upper immediate bits + 5 lower immediate bits = 32 bits total
    */
    IMM_B : immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    /*
    imm[12]   = instruction[31]
    imm[11]   = instruction[7]
    imm[10:5] = instruction[30:25]
    imm[4:1]  = instruction[11:8]
    imm[0]    = 0
    But our CPU wants 32 bits, so we sign-extend it with 19{instruction[31]}}
    The confusing part is that instruction[31] appears twice: once to fill the upper
    19 sign-extension bits, and once because it is also the actual imm[12] bit.
    */
    IMM_U : immediate ={instruction[31:12], 12'b0};

    IMM_J : immediate ={{11{instruction[31]}},instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    default  : immediate = 32'd0;

    endcase
end

endmodule