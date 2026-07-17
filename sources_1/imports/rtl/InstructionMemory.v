`include "cpu_defs.vh"

module InstructionMemory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);

    // CPU 使用字节地址，ROM 使用指令编号。
    // 256 深度的 ROM 需要 8 位地址。
    wire [7:0] rom_address;
    wire [31:0] rom_instruction;
    wire address_in_range;

    assign rom_address = address[9:2];

    // 256 条指令占用 1024 字节：
    // 有效 PC 范围为 0x00000000～0x000003FC。
    assign address_in_range = (address[31:10] == 22'b0);

    // 这里的模块名和端口名必须与 Vivado 的
    // Instantiation Template 完全一致。
    InstructionROM u_instruction_rom (
        .a   (rom_address),
        .spo (rom_instruction)
    );

    // 超出 ROM 范围时输出 NOP，避免地址截断后回绕到 ROM 开头。
    assign instruction = address_in_range
                       ? rom_instruction
                       : `RV32_NOP;

endmodule