module rv32i_xicrc_lbist (
    input  logic clk,
    input  logic reset,
    input  logic start,

    input logic inject_fault,
    input logic [3:0] fault_bit,
    input logic fault_stuck_at,

    output logic busy,
    output logic done,
    output logic pass,
    output logic fail,

    output logic [31:0] signature
);

localparam logic [31:0] GOLDEN_SIGNATURE = 32'h561D52A3;

logic [31:0] lfsr_value;
logic [31:0] rs1_data; //contains the data being processed by the CRC algorithm
logic [31:0] rs2_data; //contains the initial CRC state (the starting remainder).

logic [1:0]  crc_sel;
logic [15:0] crc_result;

logic [6:0] pattern_counter;
logic [1:0] op_counter;
logic accepted_start;
logic check_pending;
logic [15:0] misr_data;


assign rs1_data = lfsr_value;
assign rs2_data = {
    lfsr_value[15:0],
    lfsr_value[31:16]
};
assign accepted_start = start && !busy && !check_pending;


lfsr32 prpg (
    .clk       (clk),
    .reset     (reset),
    .enable    (busy),
    .load_seed (accepted_start),
    .rvalue    (lfsr_value)
);

xicrc_exec crc_dut (
    .rs1_data   (rs1_data),
    .rs2_data   (rs2_data),
    .crc_sel    (crc_sel),
    .crc_result (crc_result)
);

assign misr_data =
    inject_fault
    ? (fault_stuck_at
        ? (crc_result | (16'h0001 << fault_bit))
        : (crc_result & ~(16'h0001 << fault_bit)))
    : crc_result;

always_comb begin
    case(op_counter)
        2'd0: crc_sel =2'b00;
        2'd1: crc_sel =2'b01;
        2'd2: crc_sel =2'b10;
        default: crc_sel = 2'b00;
    endcase
end

misr32 response_compactor (
    .clk       (clk),
    .reset     (reset),
    .enable    (busy), //Capture a CRC result every active test cycle
    .clear     (accepted_start), //Reset the signature at the beginning of each new test
    .data_in ({16'b0, misr_data}), //Feed the CRC result into the MISR
    .signature (signature) //	Store the accumulated 32-bit signature
);

//reset initializes the hardware; accepted_start initializes a new test run. thats why
//we connect clear to accepted_start and not reset

always_ff @(posedge clk) begin
    if (reset) begin
        busy            <= 1'b0;
        done            <= 1'b0;
        pass            <= 1'b0;
        fail            <= 1'b0;
        check_pending   <= 1'b0;
        pattern_counter <= 7'd0;
        op_counter      <= 2'd0;
    end
    else begin
        done <= 1'b0;

        if (accepted_start) begin
            busy            <= 1'b1;
            pass            <= 1'b0;
            fail            <= 1'b0;
            pattern_counter <= 7'd0;
            op_counter      <= 2'd0;
        end

        else if (busy) begin
            if (pattern_counter == 7'd98) begin
                busy          <= 1'b0;
                check_pending <= 1'b1;
            end
            else begin
                pattern_counter <= pattern_counter + 7'd1;
            end

            if (op_counter == 2'd2)
                op_counter <= 2'd0;
            else
                op_counter <= op_counter + 2'd1;
        end

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