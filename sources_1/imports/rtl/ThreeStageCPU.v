`include "cpu_defs.vh"

// Three stages:
//   Stage 1: IF
//   Stage 2: ID + EX + branch/jump resolution
//   Stage 3: MEM + WB
//
// InstructionMemory is the Vivado ROM IP generated from the COE file.
module ThreeStageCPU #(
    parameter DMEM_BYTES = 1024
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        clock_enable,
    input  wire [4:0]  debug_reg_addr,
    output wire [31:0] debug_reg_data,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire        debug_stall,
    output wire        debug_flush,
    output wire        debug_ifid_valid,
    output wire        debug_exwb_valid,
    output wire        debug_wb_we,
    output wire [4:0]  debug_wb_rd,
    output wire [31:0] debug_wb_data
);
    // ------------------------------------------------------------
    // Stage 1: IF
    // ------------------------------------------------------------
    wire [31:0] pc_current;
    wire [31:0] pc_plus4;
    wire [31:0] fetched_instruction;
    wire [31:0] next_pc;
    wire        pc_enable;

    Adder32 u_pc_plus4(
        .a(pc_current),
        .b(32'd4),
        .sum(pc_plus4)
    );

    // Vivado Distributed Memory Generator ROM IP.
    // The IP component name must be InstructionMemory, with ports a[7:0] and spo[31:0].
    // PC is byte-addressed, so PC[9:2] selects one of 256 32-bit instructions.
    InstructionROM u_imem (
    .a   (pc_current[9:2]),
    .spo (fetched_instruction)
);

    PC u_pc(
        .clk(clk),
        .reset(reset),
        .enable(pc_enable),
        .next_pc(next_pc),
        .pc(pc_current)
    );

    // ------------------------------------------------------------
    // IF/ID pipeline register
    // ------------------------------------------------------------
    wire        ifid_valid;
    wire [31:0] ifid_pc;
    wire [31:0] ifid_instruction;
    wire        ifid_enable;
    wire        ifid_flush;

    IF_ID_Reg u_ifid(
        .clk(clk),
        .reset(reset),
        .enable(ifid_enable),
        .flush(ifid_flush),
        .in_valid(1'b1),
        .in_pc(pc_current),
        .in_instruction(fetched_instruction),
        .out_valid(ifid_valid),
        .out_pc(ifid_pc),
        .out_instruction(ifid_instruction)
    );

    // ------------------------------------------------------------
    // Stage 2: ID + EX
    // ------------------------------------------------------------
    wire [6:0] id_opcode = ifid_instruction[6:0];
    wire [4:0] id_rd = ifid_instruction[11:7];
    wire [2:0] id_funct3 = ifid_instruction[14:12];
    wire [4:0] id_rs1 = ifid_instruction[19:15];
    wire [4:0] id_rs2 = ifid_instruction[24:20];
    wire       id_funct7_bit5 = ifid_instruction[30];

    wire       ctrl_branch_bne;
    wire       ctrl_jump_jal;
    wire       ctrl_mem_read;
    wire       ctrl_mem_write;
    wire       ctrl_mem_byte;
    wire [1:0] ctrl_wb_sel;
    wire [1:0] ctrl_alu_op;
    wire       ctrl_alu_src;
    wire       ctrl_reg_write;
    wire       ctrl_use_rs1;
    wire       ctrl_use_rs2;
    wire       ctrl_illegal;

    Control u_control(
        .opcode(id_opcode),
        .funct3(id_funct3),
        .branch_bne(ctrl_branch_bne),
        .jump_jal(ctrl_jump_jal),
        .mem_read(ctrl_mem_read),
        .mem_write(ctrl_mem_write),
        .mem_byte(ctrl_mem_byte),
        .wb_sel(ctrl_wb_sel),
        .alu_op(ctrl_alu_op),
        .alu_src(ctrl_alu_src),
        .reg_write(ctrl_reg_write),
        .use_rs1(ctrl_use_rs1),
        .use_rs2(ctrl_use_rs2),
        .illegal_instruction(ctrl_illegal)
    );

    wire [31:0] id_read_data1;
    wire [31:0] id_read_data2;
    wire        wb_write_enable;
    wire [4:0]  wb_rd;
    wire [31:0] wb_write_data;

    RegisterFile u_regfile(
        .clk(clk),
        .reset(reset),
        .write_enable(wb_write_enable),
        .read_register1(id_rs1),
        .read_register2(id_rs2),
        .write_register(wb_rd),
        .write_data(wb_write_data),
        .debug_register(debug_reg_addr),
        .read_data1(id_read_data1),
        .read_data2(id_read_data2),
        .debug_data(debug_reg_data)
    );

    wire [31:0] imm_raw;
    wire        imm_needs_shift;
    wire [31:0] imm_shifted;
    wire [31:0] id_immediate;

    ImmGen u_immgen(
        .instruction(ifid_instruction),
        .imm(imm_raw),
        .shift_left1(imm_needs_shift)
    );

    ShiftLeft1 u_shift_imm(
        .in(imm_raw),
        .out(imm_shifted)
    );

    Mux2_32 u_imm_select(
        .in0(imm_raw),
        .in1(imm_shifted),
        .sel(imm_needs_shift),
        .out(id_immediate)
    );

    wire [3:0] alu_control;
    wire [31:0] alu_operand2;
    wire [31:0] alu_result;
    wire        alu_zero;

    ALUControl u_alu_control(
        .alu_op(ctrl_alu_op),
        .funct3(id_funct3),
        .funct7_bit5(id_funct7_bit5),
        .alu_control(alu_control)
    );

    Mux2_32 u_alu_src_mux(
        .in0(id_read_data2),
        .in1(id_immediate),
        .sel(ctrl_alu_src),
        .out(alu_operand2)
    );

    ALU u_alu(
        .a(id_read_data1),
        .b(alu_operand2),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(alu_zero)
    );

    wire [31:0] id_pc_plus4;
    wire [31:0] redirect_target;

    Adder32 u_id_pc_plus4(
        .a(ifid_pc),
        .b(32'd4),
        .sum(id_pc_plus4)
    );

    Adder32 u_redirect_adder(
        .a(ifid_pc),
        .b(id_immediate),
        .sum(redirect_target)
    );

    // ------------------------------------------------------------
    // EX/WB stage wires are declared here because hazard detection
    // compares the ID instruction against the current MEM/WB producer.
    // ------------------------------------------------------------
    wire        exwb_valid;
    wire        exwb_reg_write;
    wire        exwb_mem_read;
    wire        exwb_mem_write;
    wire        exwb_mem_byte;
    wire [1:0]  exwb_wb_sel;
    wire [4:0]  exwb_rd;
    wire [31:0] exwb_alu_result;
    wire [31:0] exwb_store_data;
    wire [31:0] exwb_pc_plus4;

    wire data_hazard_stall;

    HazardUnit u_hazard(
        .ifid_valid(ifid_valid),
        .id_use_rs1(ctrl_use_rs1),
        .id_use_rs2(ctrl_use_rs2),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .exwb_valid(exwb_valid),
        .exwb_reg_write(exwb_reg_write),
        .exwb_rd(exwb_rd),
        .stall(data_hazard_stall)
    );

    // Branch/jump must wait if its source register has a RAW hazard.
    wire branch_taken = ifid_valid && ctrl_branch_bne
                      && (id_read_data1 != id_read_data2);
    wire jump_taken = ifid_valid && ctrl_jump_jal;
    wire redirect_valid = !data_hazard_stall
                        && (branch_taken || jump_taken);

    assign pc_enable = clock_enable && !data_hazard_stall;
    assign ifid_enable = clock_enable && !data_hazard_stall;
    assign ifid_flush = clock_enable && redirect_valid;

    Mux2_32 u_next_pc_mux(
        .in0(pc_plus4),
        .in1(redirect_target),
        .sel(redirect_valid),
        .out(next_pc)
    );

    // A stall freezes PC and IF/ID, while flushing EX/WB's new input.
    // The previous EX/WB instruction still completes MEM/WB at this edge.
    wire exwb_input_valid = ifid_valid && !ctrl_illegal;

    EX_WB_Reg u_exwb(
        .clk(clk),
        .reset(reset),
        .enable(clock_enable),
        .flush(clock_enable && data_hazard_stall),
        .in_valid(exwb_input_valid),
        .in_reg_write(ctrl_reg_write),
        .in_mem_read(ctrl_mem_read),
        .in_mem_write(ctrl_mem_write),
        .in_mem_byte(ctrl_mem_byte),
        .in_wb_sel(ctrl_wb_sel),
        .in_rd(id_rd),
        .in_alu_result(alu_result),
        .in_store_data(id_read_data2),
        .in_pc_plus4(id_pc_plus4),
        .out_valid(exwb_valid),
        .out_reg_write(exwb_reg_write),
        .out_mem_read(exwb_mem_read),
        .out_mem_write(exwb_mem_write),
        .out_mem_byte(exwb_mem_byte),
        .out_wb_sel(exwb_wb_sel),
        .out_rd(exwb_rd),
        .out_alu_result(exwb_alu_result),
        .out_store_data(exwb_store_data),
        .out_pc_plus4(exwb_pc_plus4)
    );

    // ------------------------------------------------------------
    // Stage 3: MEM + WB
    // ------------------------------------------------------------
    wire [31:0] memory_read_data;

    DataMemory #(
        .MEM_BYTES(DMEM_BYTES)
    ) u_dmem(
        .clk(clk),
        .mem_read(exwb_valid && exwb_mem_read),
        .mem_write(clock_enable && exwb_valid && exwb_mem_write),
        .byte_access(exwb_mem_byte),
        .address(exwb_alu_result),
        .write_data(exwb_store_data),
        .read_data(memory_read_data)
    );

    wire [31:0] alu_or_memory;

    Mux2_32 u_wb_mem_mux(
        .in0(exwb_alu_result),
        .in1(memory_read_data),
        .sel(exwb_wb_sel == `WB_MEM),
        .out(alu_or_memory)
    );

    Mux2_32 u_wb_pc4_mux(
        .in0(alu_or_memory),
        .in1(exwb_pc_plus4),
        .sel(exwb_wb_sel == `WB_PC4),
        .out(wb_write_data)
    );

    assign wb_write_enable = clock_enable && exwb_valid && exwb_reg_write;
    assign wb_rd = exwb_rd;

    // Debug outputs for the testbench, waveform and board display.
    assign debug_pc = pc_current;
    assign debug_instruction = ifid_instruction;
    assign debug_stall = clock_enable && data_hazard_stall;
    assign debug_flush = ifid_flush;
    assign debug_ifid_valid = ifid_valid;
    assign debug_exwb_valid = exwb_valid;
    assign debug_wb_we = wb_write_enable;
    assign debug_wb_rd = wb_rd;
    assign debug_wb_data = wb_write_data;
endmodule
