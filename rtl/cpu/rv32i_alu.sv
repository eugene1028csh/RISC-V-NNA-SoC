import rv32i_types::*;

module rv32i_alu (
    input logic [31:0] operand_a,
    input logic [31:0] operand_b,
    input alu_op_t alu_op,
    output logic [31:0] result
);
logic [4:0] add_low;
logic [27:0] add_high;
logic [31:0] add_result;

assign add_low =
    {1'b0, operand_a[3:0]} +
    {1'b0, operand_b[3:0]};

wire carry_into_bit4;

assign carry_into_bit4 = add_low[4];

assign add_high =
    operand_a[31:4] +
    operand_b[31:4] +
    carry_into_bit4;

assign add_result = {add_high, add_low[3:0]};

//always_comb means this block describes a combinational logic
always_comb begin
    case(alu_op)
        ALU_ADD: result = add_result;
        ALU_SUB: result = operand_a - operand_b;
        ALU_AND: result = operand_a & operand_b;
        ALU_OR: result = operand_a | operand_b;
        ALU_XOR: result = operand_a ^ operand_b;
        ALU_SLL: result = operand_a << operand_b[4:0]; //But there’s one catch: for RV32, only the lower 5 bits of the shift amount matter.
        ALU_SRL: result = operand_a >> operand_b[4:0]; //always fills from the left with 0
        ALU_SRA: result = $signed(operand_a) >>> operand_b[4:0]; //fills from the left with the old sign bit
        ALU_SLT: result = $signed(operand_a) < $signed(operand_b);
        // Signed comparison: output 1 if operand_a < operand_b, otherwise 0.
        ALU_SLTU: result = operand_a < operand_b;
        // Unsigned comparison: output 1 if operand_a < operand_b, otherwise 0.
        default: result = 32'b0;
    endcase
end

endmodule