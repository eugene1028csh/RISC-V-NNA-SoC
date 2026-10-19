module rv32i_regfile (
//ports
input logic clk,
input logic write_en,

input logic [4:0] rs1_addr,
input logic [4:0] rs2_addr,
input logic [4:0] wr_addr,
input logic [31:0] wr_data,

output logic [31:0] rs1_data,
output logic [31:0] rs2_data
/*
The addresses are inputs, because the CPU tells the register file which registers it wants to read.
The read data are outputs, because the register file returns the contents.

rs1_addr, rs2_addr, rd_addr → 5 bits
because 2^5 = 32 registers

rd_data, rs1_data, rs2_data → 32 bits
because RV32 registers are 32 bits wide
*/
);
logic [31:0] regs [31:0];
//internal signal/ storage declaration
// before the array name (regs), [31:0] is width of each element in the array, after the name, 
// [31:0] is the number of elements in the array

always_ff @(posedge clk) begin
//this block describes sequential/register logic, its the write block
    if (write_en && wr_addr != 5'd0)
        regs[wr_addr] <= wr_data;
    //cant write into register x0 because RISC-V uses it as a zero value, a RISC-V rule
end

always_comb begin
    //this is th read blcok
    if (rs1_addr == 5'd0)
        rs1_data = 32'd0;
    else 
        rs1_data = regs[rs1_addr]; //give me the register stored at the index/address rs1_addr

    if (rs2_addr == 5'd0)
        rs2_data = 32'd0;
    else 
        rs2_data = regs[rs2_addr];
end

endmodule