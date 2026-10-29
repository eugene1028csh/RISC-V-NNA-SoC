module lfsr32 (
    input logic     clk,
    input logic     reset,
    input logic     enable,
    input logic     load_seed,

    output logic    [31:0] rvalue
);

localparam logic [31:0] SEED = 32'h1ACE_B00C;
logic feedback;

assign feedback =
    rvalue[31] ^
    rvalue[21] ^
    rvalue[1]  ^
    rvalue[0];

    //^ means XOR

always_ff @(posedge clk) begin
    if (reset) begin
        rvalue <=  SEED;
    end else if (load_seed) begin
        rvalue <= SEED;
    end else if (enable) begin
        rvalue <= {rvalue[30:0], feedback};
    end
end


endmodule