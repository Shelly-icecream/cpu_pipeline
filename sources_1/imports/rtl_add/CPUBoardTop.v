// Nexys4 DDR board-level top module for the three-stage RV32I CPU.
//
// Controls:
//   CPU_RESETN : dedicated active-low board reset
//   BTNU       : debounced soft reset
//   BTNC       : execute one CPU cycle in manual mode
//   SW[15]     : 0=manual step, 1=automatic slow run
//   SW[14]     : display current ID-stage instruction in hexadecimal
//   SW[13]     : display inspected register number in decimal
//   SW[12]     : display inspected register contents in hexadecimal
//   SW[11]     : 0=inspect register SW[4:0], 1=inspect last written register
//   SW[4:0]    : manually selected register number
//
// Display priority: SW14 > SW13 > SW12 > default PC display.
module CPUBoardTop #(
    parameter integer DMEM_BYTES          = 1024,
    parameter integer AUTO_DIVISOR        = 50_000_000, // 2 CPU cycles/s at 100 MHz
    parameter integer DEBOUNCE_COUNT_MAX  = 1_000_000,  // about 10 ms at 100 MHz
    parameter integer DISPLAY_SCAN_BITS   = 17
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire [7:0]  AN,
    output wire        CA,
    output wire        CB,
    output wire        CC,
    output wire        CD,
    output wire        CE,
    output wire        CF,
    output wire        CG,
    output wire        DP
);
    // Dedicated reset: asynchronous assertion, synchronous release.
    reg [1:0] reset_pipe;
    always @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN)
            reset_pipe <= 2'b11;
        else
            reset_pipe <= {reset_pipe[0], 1'b0};
    end
    wire board_reset = reset_pipe[1];

    wire step_level;
    wire step_pulse;
    wire soft_reset_level;
    wire soft_reset_pulse_unused;

    ButtonDebounceOnePulse #(
        .COUNT_MAX(DEBOUNCE_COUNT_MAX)
    ) u_step_button (
        .clk(CLK100MHZ),
        .reset(board_reset),
        .button_in(BTNC),
        .stable_level(step_level),
        .rising_pulse(step_pulse)
    );

    ButtonDebounceOnePulse #(
        .COUNT_MAX(DEBOUNCE_COUNT_MAX)
    ) u_reset_button (
        .clk(CLK100MHZ),
        .reset(board_reset),
        .button_in(BTNU),
        .stable_level(soft_reset_level),
        .rising_pulse(soft_reset_pulse_unused)
    );

    wire system_reset = board_reset | soft_reset_level;
    wire cpu_enable;

    CpuRunControl #(
        .AUTO_DIVISOR(AUTO_DIVISOR)
    ) u_run_control (
        .clk(CLK100MHZ),
        .reset(system_reset),
        .auto_mode(SW[15]),
        .step_pulse(step_pulse),
        .cpu_enable(cpu_enable)
    );

    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;
    wire        debug_stall;
    wire        debug_flush;
    wire        debug_ifid_valid;
    wire        debug_exwb_valid;
    wire        debug_wb_we;
    wire [4:0]  debug_wb_rd;
    wire [31:0] debug_wb_data;

    reg [4:0] last_written_register;
    reg       stall_seen;
    reg       flush_seen;
    reg       cpu_heartbeat;
    wire [4:0] inspected_register = SW[11]
                                      ? last_written_register
                                      : SW[4:0];
    wire [31:0] inspected_register_data;

    ThreeStageCPU #(
        .DMEM_BYTES(DMEM_BYTES)
    ) u_cpu (
        .clk(CLK100MHZ),
        .reset(system_reset),
        .clock_enable(cpu_enable),
        .debug_reg_addr(inspected_register),
        .debug_reg_data(inspected_register_data),
        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_ifid_valid(debug_ifid_valid),
        .debug_exwb_valid(debug_exwb_valid),
        .debug_wb_we(debug_wb_we),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_data(debug_wb_data)
    );

    always @(posedge CLK100MHZ) begin
        if (system_reset) begin
            last_written_register <= 5'd0;
            stall_seen            <= 1'b0;
            flush_seen            <= 1'b0;
            cpu_heartbeat         <= 1'b0;
        end else begin
            if (debug_wb_we && (debug_wb_rd != 5'd0))
                last_written_register <= debug_wb_rd;
            if (debug_stall)
                stall_seen <= 1'b1;
            if (debug_flush)
                flush_seen <= 1'b1;
            if (cpu_enable)
                cpu_heartbeat <= ~cpu_heartbeat;
        end
    end

    reg [3:0] reg_tens;
    reg [3:0] reg_ones;
    always @(*) begin
        if (inspected_register >= 5'd30) begin
            reg_tens = 4'd3;
            reg_ones = inspected_register - 5'd30;
        end else if (inspected_register >= 5'd20) begin
            reg_tens = 4'd2;
            reg_ones = inspected_register - 5'd20;
        end else if (inspected_register >= 5'd10) begin
            reg_tens = 4'd1;
            reg_ones = inspected_register - 5'd10;
        end else begin
            reg_tens = 4'd0;
            reg_ones = inspected_register[3:0];
        end
    end

    reg [31:0] display_value;
    reg [7:0]  display_digit_enable;
    always @(*) begin
        display_value        = debug_pc;
        display_digit_enable = 8'hff;

        if (SW[12]) begin
            display_value        = inspected_register_data;
            display_digit_enable = 8'hff;
        end

        if (SW[13]) begin
            display_value = {24'd0, reg_tens, reg_ones};
            display_digit_enable = (reg_tens == 4'd0)
                                 ? 8'b0000_0001
                                 : 8'b0000_0011;
        end

        if (SW[14]) begin
            display_value        = debug_instruction;
            display_digit_enable = 8'hff;
        end
    end

    SevenSegmentDisplay #(
        .SCAN_COUNTER_BITS(DISPLAY_SCAN_BITS)
    ) u_display (
        .clk(CLK100MHZ),
        .reset(system_reset),
        .hex_value(display_value),
        .digit_enable(display_digit_enable),
        .AN(AN),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP)
    );

    // Status LEDs.
    assign LED[4:0]   = inspected_register;
    assign LED[5]     = stall_seen;
    assign LED[6]     = flush_seen;
    assign LED[7]     = debug_ifid_valid;
    assign LED[8]     = debug_exwb_valid;
    assign LED[9]     = (last_written_register != 5'd0);
    assign LED[10]    = cpu_heartbeat;
    assign LED[11]    = SW[15];
    assign LED[15:12] = 4'b0000;
endmodule
