module rv32i_dmem #( //the # tells systemverilog “the following parentheses contain parameters, not normal ports.""
    parameter DEPTH = 256
)(
    input  logic        clk,
    input  logic        mem_write,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,

    //BISR repair interface
    input logic     repair_valid,
    input logic [$clog2(DEPTH)-1 : 0] repair_addr
    //$clog2 means ceiling of log base 2, 
    // -> means “How many bits do I need to represent 256 different addresses?”
    // since we have 256 addresses, 2^8 is 256, hence $clog2(256) is 8
    //in thie context its basiclaly logic [7:0] repair_addr;
);
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [31:0] mem [0:DEPTH-1];

    //spare word reg
    logic [31:0] spare_word;

    logic [ADDR_WIDTH-1:0] word_addr;

    assign word_addr = addr[ADDR_WIDTH+1:2];

    //assign read_data = mem[addr[9:2]]; //whichever address comes in, immediately output the corresponding word.

    assign read_data = (repair_valid && (word_addr == repair_addr))
        ? spare_word
        : mem[word_addr];
        //ternary operations
        //condition ? value_if_true : value_if_false

    always_ff @(posedge clk) begin
    if (mem_write == 1'b1) begin
        if (repair_valid && (word_addr == repair_addr))
            spare_word <= write_data;
        else
            mem[word_addr] <= write_data;
    end
    end 

endmodule