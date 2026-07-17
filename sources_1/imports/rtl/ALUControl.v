`include "cpu_defs.vh"

module ALUControl(
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_bit5,
    output reg  [3:0] alu_control
);
    always @(*) begin
        case (alu_op)
            `ALUOP_ADD: alu_control = `ALU_ADD;
            `ALUOP_SUB: alu_control = `ALU_SUB;

            `ALUOP_RTYPE: begin
                case (funct3)
                    3'b000: alu_control = funct7_bit5
                                           ? `ALU_SUB : `ALU_ADD;
                    3'b111: alu_control = `ALU_AND;
                    3'b110: alu_control = `ALU_OR;
                    3'b100: alu_control = `ALU_XOR;
                    3'b010: alu_control = `ALU_SLT;
                    default: alu_control = `ALU_ADD;
                endcase
            end

            default: alu_control = `ALU_ADD;
        endcase
    end
endmodule
