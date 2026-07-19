`timescale 1ns/1ps

module tb_ThreeStageCPU;
    reg clk;
    reg reset;

    wire [31:0] debug_pc;
    wire debug_stall;
    wire debug_flush;
    wire debug_ifid_valid;
    wire debug_exwb_valid;

    integer stall_count;
    integer flush_count;
    integer errors;
    integer cycle_count;
    integer wait_i;

    ThreeStageCPU #(
        .IMEM_DEPTH(256),
        .DMEM_BYTES(1024),
        .IMEM_FILE("imem.mem")
    ) dut (
        .clk(clk),
        .reset(reset),
        .debug_pc(debug_pc),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_ifid_valid(debug_ifid_valid),
        .debug_exwb_valid(debug_exwb_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (reset) begin
            stall_count <= 0;
            flush_count <= 0;
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (debug_stall)
                stall_count <= stall_count + 1;
            if (debug_flush)
                flush_count <= flush_count + 1;
        end
    end

    task check_reg;
        input [4:0] reg_number;
        input [31:0] expected;
        begin
            if (dut.u_regfile.regs[reg_number] !== expected) begin
                $display("ERROR: x%0d = %h, expected %h",
                         reg_number,
                         dut.u_regfile.regs[reg_number],
                         expected);
                errors = errors + 1;
            end else begin
                $display("PASS : x%0d = %h", reg_number, expected);
            end
        end
    endtask

    task check_byte;
        input [31:0] address;
        input [7:0] expected;
        begin
            if (dut.u_dmem.mem[address] !== expected) begin
                $display("ERROR: mem[%0d] = %h, expected %h",
                         address,
                         dut.u_dmem.mem[address],
                         expected);
                errors = errors + 1;
            end else begin
                $display("PASS : mem[%0d] = %h", address, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("rv32_3stage_modular.vcd");
        $dumpvars(0, tb_ThreeStageCPU);

        reset = 1'b1;
        stall_count = 0;
        flush_count = 0;
        cycle_count = 0;
        errors = 0;

        // Wait until DataMemory's initial clear has completed, then preload data.
        #1;
        // Word 5 at byte address 0, little-endian.
        dut.u_dmem.mem[0] = 8'h05;
        dut.u_dmem.mem[1] = 8'h00;
        dut.u_dmem.mem[2] = 8'h00;
        dut.u_dmem.mem[3] = 8'h00;
        // Negative byte used to test LB sign extension.
        dut.u_dmem.mem[8] = 8'h80;

        for (wait_i = 0; wait_i < 3; wait_i = wait_i + 1) begin
            @(posedge clk);
        end
        #1 reset = 1'b0;

        // The program takes fewer than 50 cycles, including bubbles/flushes.
        for (wait_i = 0; wait_i < 55; wait_i = wait_i + 1) begin
            @(posedge clk);
        end
        #1;

        $display("\n--- Architectural checks ---");
        check_reg(5'd0,  32'h0000_0000);
        check_reg(5'd1,  32'h0000_0005); // LW
        check_reg(5'd2,  32'h0000_0008); // LW-use ADDI
        check_reg(5'd3,  32'h0000_0008); // LB
        check_reg(5'd4,  32'h0000_0001);
        check_reg(5'd5,  32'h0000_0002);
        check_reg(5'd6,  32'h0000_0000); // flushed by taken BNE
        check_reg(5'd7,  32'h0000_0028); // JAL link = PC+4
        check_reg(5'd8,  32'h0000_0000); // flushed by JAL
        check_reg(5'd9,  32'hffff_ff80); // LB sign extension
        check_reg(5'd10, 32'hffff_ff81); // LB-use ADDI
        check_reg(5'd11, 32'h0000_0005);
        check_reg(5'd12, 32'h0000_000c);

        check_byte(4, 8'h08); // SB x2,4(x0)
        check_byte(9, 8'h81); // SB low byte of x10

        $display("\n--- Pipeline-control checks ---");
        if (stall_count !== 7) begin
            $display("ERROR: stall_count=%0d, expected 7", stall_count);
            errors = errors + 1;
        end else begin
            $display("PASS : stall_count=7");
        end

        if (flush_count !== 2) begin
            $display("ERROR: flush_count=%0d, expected 2", flush_count);
            errors = errors + 1;
        end else begin
            $display("PASS : flush_count=2");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\nTEST FAILED: %0d error(s)", errors);

        $finish;
    end

    // Timeout guard.
    initial begin
        #2000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
