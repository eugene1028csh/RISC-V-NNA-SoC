// If Zmmul and Xicrc share the same core extension hook, their
// responses must be combined by an extension router/arbiter. Do not directly
// drive the same core inputs from two modules.

module xicrc_accelerator_unit #(
    parameter [15:0] POLY = 16'h1021
) (
    input  wire [31:0] ext_rs1_data,
    input  wire [31:0] ext_rs2_data,
    input  wire [6:0]  ext_funct7,
    input  wire [2:0]  ext_funct3,

    output wire        ext_ready,
    output wire [31:0] ext_result,
    output wire        ext_writeback,
    output wire        ext_illegal
);

    wire is_xicrc = (ext_funct7 == 7'b1000000);
    wire valid_variant = (ext_funct3 == 3'b000) ||
                         (ext_funct3 == 3'b001) ||
                         (ext_funct3 == 3'b010);

    wire [1:0] crc_sel = ext_funct3[1:0];
    wire [15:0] crc_result;

    xicrc_exec #(
        .POLY(POLY)
    ) u_xicrc_exec (
        .rs1_data   (ext_rs1_data),
        .rs2_data   (ext_rs2_data),
        .crc_sel    (crc_sel),
        .crc_result (crc_result)
    );

    assign ext_ready     = is_xicrc;
    assign ext_writeback = is_xicrc && valid_variant;
    assign ext_illegal   = is_xicrc && !valid_variant;
    assign ext_result    = (is_xicrc && valid_variant) ?
                           {16'h0000, crc_result} : 32'h0000_0000;

endmodule
