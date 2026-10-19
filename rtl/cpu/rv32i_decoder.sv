import rv32i_types::*;

module rv32i_decoder(
    //ports
    input  logic [31:0] instruction,
    output logic        reg_write,
    output logic        alu_src,
    output logic        mem_write,
    output result_src_t result_src,
    output logic        branch,
    output logic        jump,
    output logic        jalr,
    output alu_op_t      alu_op,
    output imm_type_t    imm_type,
    output logic        alu_a_pc
    //alu_a_pc = 0  means ALU A comes from rs1, otherwise ALU A comes from PC
);
    //internal signals
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

always_comb begin
    reg_write  = 1'b0;
    alu_src    = 1'b0;
    mem_write  = 1'b0;
    result_src = RES_ALU;
    branch     = 1'b0;
    jump       = 1'b0;
    jalr       = 1'b0;
    alu_op     = ALU_ADD;
    imm_type   = IMM_I;
    alu_a_pc = 1'b0;
case (opcode)
    7'b0110011: begin
        // XiCRC custom instructions
        if (funct7 == 7'b1000000) begin

            alu_src    = 1'b0;
            mem_write  = 1'b0;
            branch     = 1'b0;
            jump       = 1'b0;
            jalr       = 1'b0;

            case (funct3)

                3'b000,   // CRCB
                3'b001,   // CRCH
                3'b010: begin // CRCW
                    reg_write  = 1'b1;
                    result_src = RES_CRC;
                end

                default: begin
                    reg_write  = 1'b0;
                    result_src = RES_ALU;
                end

            endcase

        end

        // Normal RV32I R-type instructions
        else begin

            reg_write  = 1'b1;
            alu_src    = 1'b0;
            mem_write  = 1'b0;
            result_src = RES_ALU;
            branch     = 1'b0;
            jump       = 1'b0;

            case (funct3)

                3'b000: begin
                    if (funct7 == 7'b0100000)
                        alu_op = ALU_SUB;
                    else
                        alu_op = ALU_ADD;
                end

                3'b111: alu_op = ALU_AND;
                3'b110: alu_op = ALU_OR;
                3'b100: alu_op = ALU_XOR;
                3'b001: alu_op = ALU_SLL;

                3'b101: begin
                    if (funct7 == 7'b0100000)
                        alu_op = ALU_SRA;
                    else
                        alu_op = ALU_SRL;
                end

                3'b010: alu_op = ALU_SLT;
                3'b011: alu_op = ALU_SLTU;

                default: alu_op = ALU_ADD;

            endcase
        end
    end

    7'b0010011: begin   //Itype instructions
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_write  = 1'b0;
        result_src = RES_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        imm_type   = IMM_I;

        case (funct3)

            3'b000: alu_op = ALU_ADD;    //ADDI

            3'b010: alu_op = ALU_SLT;    // SLTI

            3'b011: alu_op = ALU_SLTU;   // SLTIU

            3'b100: alu_op = ALU_XOR;    // XORI

            3'b110: alu_op = ALU_OR;     // ORI

            3'b111: alu_op = ALU_AND;    // ANDI

            3'b001: alu_op = ALU_SLL;    // SLLI

            3'b101: begin
                if (funct7 == 7'b0100000)
                    alu_op = ALU_SRA;    //SRAI
                else
                    alu_op = ALU_SRL;    // SRLI
            end

            default: alu_op = ALU_ADD;

        endcase
    end

    //Load
    7'b000011: begin 
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_write  = 1'b0;
        result_src = RES_MEM;
        branch     = 1'b0;
        jump       = 1'b0;
        imm_type   = IMM_I;
        alu_op     = ALU_ADD;
    end

    //Store
    7'b0100011: begin  
        reg_write  = 1'b0;
        alu_src    = 1'b1;
        mem_write  = 1'b1;
        result_src = RES_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        imm_type   = IMM_S;
        alu_op     = ALU_ADD;
    end

    //Branch
    7'b1100011: begin 
        reg_write = 1'b0;
        mem_write = 1'b0;
        branch    = 1'b1;
        jump      = 1'b0;
        imm_type  = IMM_B;
    end

    //JAL
    7'b1101111: begin
        reg_write  = 1'b1;
        mem_write  = 1'b0;
        result_src = RES_PC4;
        branch     = 1'b0;
        jump       = 1'b1;
        imm_type   = IMM_J;

    end

    //JALR
    7'b1100111: begin  
        if (funct3 == 3'b000) begin
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        mem_write  = 1'b0;
        result_src = RES_PC4;
        branch     = 1'b0;
        jump       = 1'b1;
        imm_type   = IMM_I;
        alu_op     = ALU_ADD;
        jalr       = 1'b1;
        end
    end

    //LUI
    7'b0110111: begin 
        reg_write  = 1;       
        mem_write  = 0;      
        result_src = RES_IMM;  //write the immediate directly
        branch     = 0;
        jump       = 0;
        imm_type   = IMM_U;
        //ALU is bypassed, output straight to wrtieback
    end

    //AUIPC
    7'b0010111: begin 
        reg_write  = 1'b1;
        alu_a_pc   = 1'b1;   //alu A comes from pc    
        alu_src    = 1'b1; //alu B = immeidate
        alu_op     = ALU_ADD; 
        result_src = RES_ALU;
        imm_type   = IMM_U;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
    end

    //if the opcode is not 0110011, don’t enter the R-type decode block.
    default: begin
        // Keep safe defaults

    end
endcase
end
endmodule