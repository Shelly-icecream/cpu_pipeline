`include "cpu_defs.vh"

module ALU(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alu_control)
            `ALU_ADD: result = a + b;
            `ALU_SUB: result = a - b;
            `ALU_AND: result = a & b;
            `ALU_OR : result = a | b;
            `ALU_XOR: result = a ^ b;
            `ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default : result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule
