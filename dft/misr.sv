module misr32 (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        clear,

    input  logic [31:0] data_in,

    output logic [31:0] signature
);

    logic feedback;
    logic [31:0] shifted_state;

    // Same polynomial structure as the LFSR
    assign feedback =
        signature[31] ^
        signature[21] ^
        signature[1]  ^
        signature[0];

    assign shifted_state =
        {signature[30:0], feedback};

    always_ff @(posedge clk) begin

        if (reset) begin
            signature <= 32'h0000_0000;
        end

        else if (clear) begin
            signature <= 32'h0000_0000;
        end

        else if (enable) begin
            signature <= shifted_state ^ data_in;
        end

    end

endmodule