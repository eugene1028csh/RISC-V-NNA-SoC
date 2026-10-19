module rv32i_dmem #( //the # tells systemverilog “the following parentheses contain parameters, not normal ports.""
    parameter DEPTH = 256
)(
    input  logic        clk,
    input  logic        mem_write,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);

    logic [31:0] mem [0:DEPTH-1];

    assign read_data = mem[addr[9:2]]; //whichever address comes in, immediately output the corresponding word.

    always_ff @(posedge clk) begin
    if (mem_write == 1'b1) begin
        mem[addr[9:2]] <= write_data;
    end
    end 

endmodule