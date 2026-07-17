module PC #(
    parameter RESET_PC = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= RESET_PC;
        else if (enable)
            pc <= next_pc;
    end
endmodule
