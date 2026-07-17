`timescale 1ns/1ps

// Vivado simulation testbench. The generated InstructionMemory IP must be
// present in the project simulation sources.
module tb_CPUBoardTop;
    reg CLK100MHZ;
    reg CPU_RESETN;
    reg BTNC;
    reg BTNU;
    reg [15:0] SW;

    wire [15:0] LED;
    wire [7:0] AN;
    wire CA, CB, CC, CD, CE, CF, CG, DP;

    integer errors;
    integer enable_count;
    integer i;

    CPUBoardTop #(
        .DMEM_BYTES(1024),
        .AUTO_DIVISOR(4),
        .DEBOUNCE_COUNT_MAX(2),
        .DISPLAY_SCAN_BITS(5)
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNC(BTNC),
        .BTNU(BTNU),
        .SW(SW),
        .LED(LED),
        .AN(AN),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP)
    );

    initial begin
        CLK100MHZ = 1'b0;
        forever #5 CLK100MHZ = ~CLK100MHZ;
    end

    always @(posedge CLK100MHZ) begin
        if (dut.cpu_enable)
            enable_count = enable_count + 1;
    end

    task press_step;
        begin
            BTNC = 1'b1;
            repeat (5) @(posedge CLK100MHZ);
            BTNC = 1'b0;
            repeat (5) @(posedge CLK100MHZ);
        end
    endtask

    task check32;
        input [255:0] name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual !== expected) begin
                $display("ERROR %-24s actual=%h expected=%h", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("PASS  %-24s value=%h", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;
        enable_count = 0;
        CPU_RESETN = 1'b0;
        BTNC = 1'b0;
        BTNU = 1'b0;
        SW = 16'b0; // manual mode

        repeat (5) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;
        repeat (5) @(posedge CLK100MHZ);

        // Manual stepping must produce one CPU enable pulse per press.
        press_step();
        press_step();
        press_step();
        if (enable_count !== 3) begin
            $display("ERROR manual enable_count=%0d, expected 3", enable_count);
            errors = errors + 1;
        end else begin
            $display("PASS  manual stepping generated 3 CPU cycles");
        end

        // Restart, initialize the unchanged byte-array DataMemory, and auto-run.
        CPU_RESETN = 1'b0;
        repeat (3) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;
        repeat (4) @(posedge CLK100MHZ);

        dut.u_cpu.u_dmem.mem[0] = 8'h05;
        dut.u_cpu.u_dmem.mem[1] = 8'h00;
        dut.u_cpu.u_dmem.mem[2] = 8'h00;
        dut.u_cpu.u_dmem.mem[3] = 8'h00;
        dut.u_cpu.u_dmem.mem[8] = 8'h80;

        SW[15] = 1'b1; // auto mode
        for (i = 0; i < 70; i = i + 1) begin
            @(posedge CLK100MHZ);
            while (!dut.cpu_enable)
                @(posedge CLK100MHZ);
        end
        SW[15] = 1'b0;
        repeat (3) @(posedge CLK100MHZ);

        check32("register x1", dut.u_cpu.u_regfile.regs[1], 32'h00000005);
        check32("register x2", dut.u_cpu.u_regfile.regs[2], 32'h00000008);
        check32("register x7", dut.u_cpu.u_regfile.regs[7], 32'h00000028);
        check32("register x9", dut.u_cpu.u_regfile.regs[9], 32'hffffff80);
        check32("register x10", dut.u_cpu.u_regfile.regs[10], 32'hffffff81);

        // Register-number display: manually inspect x2.
        SW[11] = 1'b0;
        SW[4:0] = 5'd2;
        SW[14] = 1'b0;
        SW[12] = 1'b0;
        SW[13] = 1'b1;
        #1;
        check32("decimal register display", dut.display_value, 32'h00000002);

        // Register-content display: x2 should contain 8.
        SW[13] = 1'b0;
        SW[12] = 1'b1;
        #1;
        check32("register-content display", dut.display_value, 32'h00000008);

        // Instruction display has the highest priority.
        SW[14] = 1'b1;
        #1;
        check32("instruction display", dut.display_value, dut.debug_instruction);

        // Default display is PC.
        SW[14] = 1'b0;
        SW[13] = 1'b0;
        SW[12] = 1'b0;
        #1;
        check32("default PC display", dut.display_value, dut.debug_pc);

        if (errors == 0)
            $display("\nALL BOARD-TOP TESTS PASSED");
        else
            $display("\nBOARD-TOP TEST FAILED: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
