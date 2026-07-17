`include "cpu_defs.vh"

// For B/J instructions, imm is generated as offset>>1 and shift_left1=1.
// The separate ShiftLeft1 module then restores the byte offset.
module ImmGen(
    input  wire [31:0] instruction,
    output reg  [31:0] imm,
    output reg         shift_left1
);
    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        imm = 32'b0;
        shift_left1 = 1'b0;

        case (opcode)
            `OPCODE_LOAD,
            `OPCODE_OP_IMM: begin
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end

            `OPCODE_STORE: begin
                imm = {{20{instruction[31]}},
                       instruction[31:25], instruction[11:7]};
            end

            `OPCODE_BRANCH: begin
                // Signed value of branch byte offset divided by two.
                imm = {{20{instruction[31]}}, instruction[31],
                       instruction[7], instruction[30:25],
                       instruction[11:8]};
                shift_left1 = 1'b1;
            end

            `OPCODE_JAL: begin
                // Signed value of JAL byte offset divided by two.
                imm = {{12{instruction[31]}}, instruction[31],
                       instruction[19:12], instruction[20],
                       instruction[30:21]};
                shift_left1 = 1'b1;
            end

            default: begin
                imm = 32'b0;
                shift_left1 = 1'b0;
            end
        endcase
    end
endmodule
