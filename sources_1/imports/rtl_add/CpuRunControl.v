// Produces a one-system-clock-wide clock-enable pulse for the CPU.
// auto_mode=0: one CPU cycle per debounced step_pulse.
// auto_mode=1: one CPU cycle every AUTO_DIVISOR system clocks.
module CpuRunControl #(
    parameter integer AUTO_DIVISOR = 50_000_000
)(
    input  wire clk,
    input  wire reset,
    input  wire auto_mode,
    input  wire step_pulse,
    output reg  cpu_enable
);
    reg [31:0] auto_counter;

    always @(posedge clk) begin
        if (reset) begin
            auto_counter <= 32'd0;
            cpu_enable   <= 1'b0;
        end else begin
            cpu_enable <= 1'b0;

            if (auto_mode) begin
                if (AUTO_DIVISOR <= 1) begin
                    cpu_enable   <= 1'b1;
                    auto_counter <= 32'd0;
                end else if (auto_counter >= AUTO_DIVISOR - 1) begin
                    cpu_enable   <= 1'b1;
                    auto_counter <= 32'd0;
                end else begin
                    auto_counter <= auto_counter + 32'd1;
                end
            end else begin
                auto_counter <= 32'd0;
                if (step_pulse)
                    cpu_enable <= 1'b1;
            end
        end
    end
endmodule
