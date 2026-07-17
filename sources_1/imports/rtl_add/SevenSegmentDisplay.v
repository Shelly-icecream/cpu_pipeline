// Eight-digit multiplexed seven-segment display driver for Nexys4 DDR.
// AN, CA..CG and DP are active-low on the board.
// hex_value[3:0] drives AN[0] (rightmost digit).
module SevenSegmentDisplay #(
    parameter integer SCAN_COUNTER_BITS = 17
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] hex_value,
    input  wire [7:0]  digit_enable,
    output reg  [7:0]  AN,
    output reg         CA,
    output reg         CB,
    output reg         CC,
    output reg         CD,
    output reg         CE,
    output reg         CF,
    output reg         CG,
    output reg         DP
);
    reg [SCAN_COUNTER_BITS-1:0] scan_counter;
    wire [2:0] scan_index;
    reg [3:0] current_nibble;
    reg [6:0] segments;

    assign scan_index = scan_counter[SCAN_COUNTER_BITS-1:SCAN_COUNTER_BITS-3];

    always @(posedge clk) begin
        if (reset)
            scan_counter <= {SCAN_COUNTER_BITS{1'b0}};
        else
            scan_counter <= scan_counter + {{(SCAN_COUNTER_BITS-1){1'b0}}, 1'b1};
    end

    always @(*) begin
        case (scan_index)
            3'd0: current_nibble = hex_value[3:0];
            3'd1: current_nibble = hex_value[7:4];
            3'd2: current_nibble = hex_value[11:8];
            3'd3: current_nibble = hex_value[15:12];
            3'd4: current_nibble = hex_value[19:16];
            3'd5: current_nibble = hex_value[23:20];
            3'd6: current_nibble = hex_value[27:24];
            default: current_nibble = hex_value[31:28];
        endcase

        // segments = {a,b,c,d,e,f,g}, active-low.
        case (current_nibble)
            4'h0: segments = 7'b0000001;
            4'h1: segments = 7'b1001111;
            4'h2: segments = 7'b0010010;
            4'h3: segments = 7'b0000110;
            4'h4: segments = 7'b1001100;
            4'h5: segments = 7'b0100100;
            4'h6: segments = 7'b0100000;
            4'h7: segments = 7'b0001111;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0000100;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b1100000;
            4'hC: segments = 7'b0110001;
            4'hD: segments = 7'b1000010;
            4'hE: segments = 7'b0110000;
            default: segments = 7'b0111000; // F
        endcase

        AN = 8'hff;
        if (digit_enable[scan_index]) begin
            AN[scan_index] = 1'b0;
            {CA, CB, CC, CD, CE, CF, CG} = segments;
        end else begin
            {CA, CB, CC, CD, CE, CF, CG} = 7'b1111111;
        end
        DP = 1'b1;
    end
endmodule
