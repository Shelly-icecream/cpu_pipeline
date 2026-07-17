module DataMemory #(
    parameter MEM_BYTES = 1024
)(
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        byte_access,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);
    // Byte-addressed, little-endian memory.
    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1)
            mem[i] = 8'b0;
    end

    always @(*) begin
        read_data = 32'b0;
        if (mem_read) begin
            if (byte_access) begin
                if (address < MEM_BYTES)
                    read_data = {{24{mem[address][7]}}, mem[address]};
            end else begin
                if (address + 32'd3 < MEM_BYTES)
                    read_data = {mem[address + 32'd3],
                                 mem[address + 32'd2],
                                 mem[address + 32'd1],
                                 mem[address]};
            end
        end
    end

    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_access) begin
                if (address < MEM_BYTES)
                    mem[address] <= write_data[7:0];
            end else begin
                if (address + 32'd3 < MEM_BYTES) begin
                    mem[address]          <= write_data[7:0];
                    mem[address + 32'd1]  <= write_data[15:8];
                    mem[address + 32'd2]  <= write_data[23:16];
                    mem[address + 32'd3]  <= write_data[31:24];
                end
            end
        end
    end
endmodule
