import rv32i_types::*;

module rv32i_alu_lbist #(
parameter logic [31:0] GOLDEN_SIGNATURE = 32'h6A86_A2B4)
(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic inject_fault,
    input logic [4:0] fault_bit,
    input logic fault_stuck_at,

    output logic busy,
    output logic done,
    output logic pass,
    output logic fail,

    output logic [31:0] signature
);

logic [31:0] lfsr_value;
logic check_pending;
logic accepted_start;

logic [31:0] operand_a;
logic [31:0] operand_b;
logic [31:0] alu_result;
logic [31:0] misr_data;


alu_op_t alu_op;

logic [3:0] op_counter;
logic [6:0] pattern_counter;   // enough for 0–99

lfsr32 prpg (
    .clk       (clk),
    .reset     (reset),
    .enable    (busy),
    .load_seed (accepted_start),
    .rvalue    (lfsr_value)
);

assign operand_a = lfsr_value;

assign accepted_start = start && !busy && !check_pending;

assign operand_b = {
    lfsr_value[15:0],
    lfsr_value[31:16]
};

assign misr_data =
    inject_fault
    ? (
        fault_stuck_at
        ? (alu_result | (32'h1 << fault_bit))
        : (alu_result & ~(32'h1 << fault_bit))
      )
    : alu_result;

rv32i_alu alu_dut (
    .operand_a (operand_a),
    .operand_b (operand_b),
    .alu_op    (alu_op),
    .result    (alu_result)
);

misr32 response_compactor (
    .clk       (clk),
    .reset     (reset),
    .enable    (busy),
    .clear     (accepted_start),
    .data_in   (misr_data),
    .signature (signature)
);

always_comb begin
    case (op_counter)
        4'd0: alu_op = ALU_ADD;
        4'd1: alu_op = ALU_SUB;
        4'd2: alu_op = ALU_AND;
        4'd3: alu_op = ALU_OR;
        4'd4: alu_op = ALU_XOR;
        4'd5: alu_op = ALU_SLL;
        4'd6: alu_op = ALU_SRL;
        4'd7: alu_op = ALU_SRA;
        4'd8: alu_op = ALU_SLT;
        4'd9: alu_op = ALU_SLTU;

        default: alu_op = ALU_ADD;
    endcase
end

//controller logic
always_ff @(posedge clk) begin
    
    if (reset) begin
        busy <= 1'b0;
        done <= 1'b0;
        op_counter <= 4'b0;
        pattern_counter <= 7'b0;
        check_pending   <= 1'b0;
        pass <= 1'b0;
        fail <= 1'b0;
    end

    else begin
        done <= 0;

        // Start LBIST
        if (accepted_start) begin
            busy            <= 1'b1;
            check_pending   <= 1'b0;
            op_counter      <= 4'd0;
            pattern_counter <= 7'd0;
            pass            <= 1'b0;
            fail            <= 1'b0;
        end

        else if (busy) begin
            if (pattern_counter == 7'd99) begin
                busy <= 1'b0;
                check_pending <= 1'b1;
            end

            else begin
                pattern_counter <= pattern_counter + 1'b1;

                if (op_counter == 4'd9)
                    op_counter <= 4'd0;
                else 
                    op_counter <= op_counter + 1'b1;
            end
        end

        //ehcek misr
        else if (check_pending) begin
            check_pending <= 1'b0;
            done          <= 1'b1;

            if (signature == GOLDEN_SIGNATURE) begin
                pass <= 1'b1;
                fail <= 1'b0;
            end
            else begin
                pass <= 1'b0;
                fail <= 1'b1;
            end
        end

    end
end
endmodule