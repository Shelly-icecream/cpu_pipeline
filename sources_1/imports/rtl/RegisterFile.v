module RegisterFile(
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [4:0]  read_register1,
    input  wire [4:0]  read_register2,
    input  wire [4:0]  write_register,
    input  wire [31:0] write_data,
    input  wire [4:0]  debug_register,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    output wire [31:0] debug_data
);
    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (write_enable && (write_register != 5'd0))
                regs[write_register] <= write_data;
            regs[0] <= 32'b0;
        end
    end

    assign read_data1 = (read_register1 == 5'd0)
                      ? 32'b0 : regs[read_register1];
    assign read_data2 = (read_register2 == 5'd0)
                      ? 32'b0 : regs[read_register2];
    assign debug_data = (debug_register == 5'd0)
                      ? 32'b0 : regs[debug_register];
endmodule
