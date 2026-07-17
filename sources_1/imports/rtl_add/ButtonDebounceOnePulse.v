// Synchronizes and debounces an active-high pushbutton.
// stable_level follows the debounced button state.
// rising_pulse is high for one CLK100MHZ cycle on each press.
module ButtonDebounceOnePulse #(
    parameter integer COUNT_MAX = 1_000_000
)(
    input  wire clk,
    input  wire reset,
    input  wire button_in,
    output reg  stable_level,
    output reg  rising_pulse
);
    reg sync0;
    reg sync1;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (reset) begin
            sync0 <= 1'b0;
            sync1 <= 1'b0;
        end else begin
            sync0 <= button_in;
            sync1 <= sync0;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            stable_level <= 1'b0;
            rising_pulse <= 1'b0;
            counter      <= 32'd0;
        end else begin
            rising_pulse <= 1'b0;

            if (sync1 == stable_level) begin
                counter <= 32'd0;
            end else if (COUNT_MAX <= 1) begin
                stable_level <= sync1;
                counter      <= 32'd0;
                if (sync1)
                    rising_pulse <= 1'b1;
            end else if (counter >= COUNT_MAX - 1) begin
                stable_level <= sync1;
                counter      <= 32'd0;
                if (sync1)
                    rising_pulse <= 1'b1;
            end else begin
                counter <= counter + 32'd1;
            end
        end
    end
endmodule
