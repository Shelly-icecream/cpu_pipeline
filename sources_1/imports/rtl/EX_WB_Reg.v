`include "cpu_defs.vh"

module EX_WB_Reg(
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        flush,

    input  wire        in_valid,
    input  wire        in_reg_write,
    input  wire        in_mem_read,
    input  wire        in_mem_write,
    input  wire        in_mem_byte,
    input  wire [1:0]  in_wb_sel,
    input  wire [4:0]  in_rd,
    input  wire [31:0] in_alu_result,
    input  wire [31:0] in_store_data,
    input  wire [31:0] in_pc_plus4,

    output reg         out_valid,
    output reg         out_reg_write,
    output reg         out_mem_read,
    output reg         out_mem_write,
    output reg         out_mem_byte,
    output reg  [1:0]  out_wb_sel,
    output reg  [4:0]  out_rd,
    output reg  [31:0] out_alu_result,
    output reg  [31:0] out_store_data,
    output reg  [31:0] out_pc_plus4
);
    always @(posedge clk) begin
        if (reset || flush) begin
            out_valid <= 1'b0;
            out_reg_write <= 1'b0;
            out_mem_read <= 1'b0;
            out_mem_write <= 1'b0;
            out_mem_byte <= 1'b0;
            out_wb_sel <= `WB_ALU;
            out_rd <= 5'b0;
            out_alu_result <= 32'b0;
            out_store_data <= 32'b0;
            out_pc_plus4 <= 32'b0;
        end else if (enable) begin
            out_valid <= in_valid;
            out_reg_write <= in_reg_write;
            out_mem_read <= in_mem_read;
            out_mem_write <= in_mem_write;
            out_mem_byte <= in_mem_byte;
            out_wb_sel <= in_wb_sel;
            out_rd <= in_rd;
            out_alu_result <= in_alu_result;
            out_store_data <= in_store_data;
            out_pc_plus4 <= in_pc_plus4;
        end
    end
endmodule
