`include "cpu_defs.vh"

module IF_ID_Reg(
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        flush,
    input  wire        in_valid,
    input  wire [31:0] in_pc,
    input  wire [31:0] in_instruction,
    output reg         out_valid,
    output reg  [31:0] out_pc,
    output reg  [31:0] out_instruction
);
    always @(posedge clk) begin
        if (reset || flush) begin
            out_valid <= 1'b0;
            out_pc <= 32'b0;
            out_instruction <= `RV32_NOP;
        end else if (enable) begin
            out_valid <= in_valid;
            out_pc <= in_pc;
            out_instruction <= in_instruction;
        end
    end
endmodule
