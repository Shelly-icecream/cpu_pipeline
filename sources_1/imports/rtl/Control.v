`include "cpu_defs.vh"

module Control(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    output reg        branch_bne,
    output reg        jump_jal,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_byte,
    output reg  [1:0] wb_sel,
    output reg  [1:0] alu_op,
    output reg        alu_src,
    output reg        reg_write,
    output reg        use_rs1,
    output reg        use_rs2,
    output reg        illegal_instruction
);
    always @(*) begin
        branch_bne = 1'b0;
        jump_jal = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_byte = 1'b0;
        wb_sel = `WB_ALU;
        alu_op = `ALUOP_ADD;
        alu_src = 1'b0;
        reg_write = 1'b0;
        use_rs1 = 1'b0;
        use_rs2 = 1'b0;
        illegal_instruction = 1'b0;

        case (opcode)
            `OPCODE_LOAD: begin
                // LB funct3=000, LW funct3=010
                if ((funct3 == 3'b000) || (funct3 == 3'b010)) begin
                    mem_read = 1'b1;
                    mem_byte = (funct3 == 3'b000);
                    wb_sel = `WB_MEM;
                    alu_op = `ALUOP_ADD;
                    alu_src = 1'b1;
                    reg_write = 1'b1;
                    use_rs1 = 1'b1;
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            `OPCODE_STORE: begin
                // SB funct3=000, SW funct3=010
                if ((funct3 == 3'b000) || (funct3 == 3'b010)) begin
                    mem_write = 1'b1;
                    mem_byte = (funct3 == 3'b000);
                    alu_op = `ALUOP_ADD;
                    alu_src = 1'b1;
                    use_rs1 = 1'b1;
                    use_rs2 = 1'b1;
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            `OPCODE_OP_IMM: begin
                // ADDI
                if (funct3 == 3'b000) begin
                    alu_op = `ALUOP_ADD;
                    alu_src = 1'b1;
                    reg_write = 1'b1;
                    wb_sel = `WB_ALU;
                    use_rs1 = 1'b1;
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            `OPCODE_OP: begin
                // ADD/SUB are selected by ALUControl.
                if (funct3 == 3'b000) begin
                    alu_op = `ALUOP_RTYPE;
                    alu_src = 1'b0;
                    reg_write = 1'b1;
                    wb_sel = `WB_ALU;
                    use_rs1 = 1'b1;
                    use_rs2 = 1'b1;
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            `OPCODE_BRANCH: begin
                // BNE
                if (funct3 == 3'b001) begin
                    branch_bne = 1'b1;
                    alu_op = `ALUOP_SUB;
                    alu_src = 1'b0;
                    use_rs1 = 1'b1;
                    use_rs2 = 1'b1;
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            `OPCODE_JAL: begin
                jump_jal = 1'b1;
                reg_write = 1'b1;
                wb_sel = `WB_PC4;
            end

            default: begin
                illegal_instruction = 1'b1;
            end
        endcase
    end
endmodule
