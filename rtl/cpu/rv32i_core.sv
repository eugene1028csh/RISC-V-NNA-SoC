import rv32i_types::*;

module rv32i_core (
    input logic clk,
    input logic reset,

    //mmio ports
    output logic [31:0] bus_addr,
    output logic [31:0] bus_write_data,
    output logic        bus_write_en,

    input  logic [31:0] bus_read_data,
    input  logic        bus_hit
);
    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus4;
    logic [31:0] instruction;

    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [4:0]  rd_addr;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] writeback_data;

    logic [31:0] immediate;

    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_result;

    logic [31:0] mem_read_data;
    logic [31:0] dmem_read_data;
    logic        dmem_write_en;
    logic [31:0] crc_result;
    logic        crc_ready;
    logic        crc_writeback;
    logic        crc_illegal;

    logic        reg_write;
    logic        alu_src;
    logic        alu_a_pc;
    logic        mem_write;
    logic        branch;
    logic        branch_taken;
    logic        jump;
    logic        jalr;

    alu_op_t      alu_op;
    imm_type_t    imm_type;
    result_src_t  result_src;

    //instantiating pc
    rv32i_pc pc_unit (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );

    //connect pc to imem
    rv32i_imem imem (
        .addr(pc),
        .instruction(instruction)
    );

    //instruction field extration for register addresses
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr  = instruction[11:7];

    xicrc_accelerator_unit xicrc_unit (
        .ext_rs1_data   (rs1_data),
        .ext_rs2_data   (rs2_data),
        .ext_funct7     (instruction[31:25]),
        .ext_funct3     (instruction[14:12]),

        .ext_ready      (crc_ready),
        .ext_result     (crc_result),
        .ext_writeback  (crc_writeback),
        .ext_illegal    (crc_illegal)
    );

    //instantiating decoder
    rv32i_decoder decoder (
        .instruction(instruction),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_a_pc(alu_a_pc),
        .mem_write(mem_write),
        .result_src(result_src),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .alu_op(alu_op),
        .imm_type(imm_type)
    );

    //reg file
    rv32i_regfile regfile (
    .clk(clk),
    .write_en(reg_write), //connect the register file’s write_en input to the core’s reg_write signal.
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .wr_addr(rd_addr),
    .wr_data(writeback_data),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
    );

    //immediate generator
    rv32i_imme_gnrtr immgen (
    .instruction(instruction),
    .imm_type(imm_type),
    .immediate(immediate)
    );

    assign alu_a = alu_a_pc ? pc : rs1_data;
    assign alu_b = alu_src ? immediate : rs2_data;


    rv32i_alu alu (
        .operand_a(alu_a),
        .operand_b(alu_b),
        .alu_op(alu_op),
        .result(alu_result)
    );

    rv32i_branch_unit branch_unit (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .funct3(instruction[14:12]),

        .branch_taken(branch_taken)
    );

    assign bus_addr       = alu_result;
    assign bus_write_data = rs2_data;
    assign bus_write_en   = mem_write;
    assign dmem_write_en = mem_write && !bus_hit;
    rv32i_dmem dmem (
        .clk(clk),
        .mem_write(dmem_write_en),

        .addr(alu_result),
        .write_data(rs2_data),

        .read_data(dmem_read_data)
    );

    assign mem_read_data = bus_hit ? bus_read_data : dmem_read_data;
    assign pc_plus4 = pc + 32'd4;

    always_comb begin

        case (result_src)

            RES_ALU:
                writeback_data = alu_result;

            RES_MEM:
                writeback_data = mem_read_data;

            RES_PC4:
                writeback_data = pc_plus4;

            RES_IMM:
                writeback_data = immediate;

            RES_CRC:
                writeback_data = crc_result;

            default:
                writeback_data = 32'd0;

        endcase

    end

 rv32i_next_pc next_pc_unit (
        .pc(pc),
        .immediate(immediate),

        .branch(branch),
        .branch_taken(branch_taken),

        .jump(jump),
        .jalr(jalr),

        .rs1_data(rs1_data),

        .next_pc(next_pc)
    );

endmodule

