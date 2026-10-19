module rv32i_branch_unit (
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [2:0] funct3,
    output logic branch_taken
);

//branch_taken = 1 => redirect the PC
//branch_taken = 0 => continue with PC + 4

always_comb begin
    branch_taken = 1'b0;
    case(funct3)
    3'b000: begin //Branch Equal
        if (rs1_data == rs2_data)
            branch_taken = 1'b1; 
    end

    3'b001: begin //Branch Not Equal
        if (rs1_data != rs2_data)
            branch_taken = 1'b1;
    end

    3'b100: begin //BLT
        if ($signed(rs1_data) < $signed(rs2_data))
            branch_taken = 1'b1;
    end
    
    3'b101: begin //BGE
         if ($signed(rs1_data) >= $signed(rs2_data))
            branch_taken = 1'b1;
    end

    3'b110: begin      //BLTU
        if (rs1_data < rs2_data)
            branch_taken = 1'b1;
    end

    3'b111: begin      // BGEU
        if (rs1_data >= rs2_data)
            branch_taken = 1'b1;
    end

    default:;

    endcase
end
endmodule