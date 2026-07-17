`timescale 1ns/1ps

// Core regression test after adding clock_enable and debug-register ports.
// The generated InstructionMemory IP must be present in Vivado.
module tb_ThreeStageCPU_CE;
    reg clk;
    reg reset;
    reg clock_enable;
    reg [4:0] debug_reg_addr;

    wire [31:0] debug_reg_data;
    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;
    wire debug_stall;
    wire debug_flush;
    wire debug_ifid_valid;
    wire debug_exwb_valid;
    wire debug_wb_we;
    wire [4:0] debug_wb_rd;
    wire [31:0] debug_wb_data;

    integer errors;
    integer i;

    ThreeStageCPU #(.DMEM_BYTES(1024)) dut (
        .clk(clk),
        .reset(reset),
        .clock_enable(clock_enable),
        .debug_reg_addr(debug_reg_addr),
        .debug_reg_data(debug_reg_data),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task step_cpu;
        begin
            @(negedge clk);
            clock_enable = 1'b1;
            @(negedge clk);
            clock_enable = 1'b0;
        end
    endtask

    task check_reg;
        input [4:0] index;
        input [31:0] expected;
        begin
            debug_reg_addr = index;
            #1;
            if (debug_reg_data !== expected) begin
                $display("ERROR x%0d=%h expected=%h", index, debug_reg_data, expected);
                errors = errors + 1;
            end else begin
                $display("PASS  x%0d=%h", index, debug_reg_data);
            end
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;
        clock_enable = 1'b0;
        debug_reg_addr = 5'd0;
        repeat (3) @(posedge clk);
        reset = 1'b0;

        dut.u_dmem.mem[0] = 8'h05;
        dut.u_dmem.mem[1] = 8'h00;
        dut.u_dmem.mem[2] = 8'h00;
        dut.u_dmem.mem[3] = 8'h00;
        dut.u_dmem.mem[8] = 8'h80;

        for (i = 0; i < 70; i = i + 1)
            step_cpu();

        check_reg(5'd1, 32'h00000005);
        check_reg(5'd2, 32'h00000008);
        check_reg(5'd7, 32'h00000028);
        check_reg(5'd9, 32'hffffff80);
        check_reg(5'd10, 32'hffffff81);

        if (errors == 0)
            $display("ALL CORE CLOCK-ENABLE TESTS PASSED");
        else
            $display("CORE TEST FAILED: %0d error(s)", errors);
        $finish;
    end
endmodule
