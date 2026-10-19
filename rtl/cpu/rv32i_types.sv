package rv32i_types;
    typedef enum logic [3:0] { //4 bits for each enum value
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_SLT,
        ALU_SLTU
    } alu_op_t;

    typedef enum logic [2:0] {
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J
    } imm_type_t;

    typedef enum logic [2:0] {
        RES_ALU,
        RES_MEM,
        RES_PC4,
        RES_IMM,
        RES_CRC
    } result_src_t;

endpackage


//import into modules using "import rv32i_types::*;", * means import all definitions from rv32i_types