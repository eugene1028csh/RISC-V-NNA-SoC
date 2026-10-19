module rv32i_imem #(
    parameter DEPTH = 256
)(
    input logic [31:0] addr,
    output logic [31:0] instruction
);

    logic [31:0] mem [0:DEPTH-1]; //256 memory locations, 32 bits each
    //mem is an array that stores all instructions inside imem

    always_comb begin
        instruction = mem[addr[9:2]]; //addr is address input into IMEM
    end

endmodule