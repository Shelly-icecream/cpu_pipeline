`ifndef CPU_DEFS_VH
`define CPU_DEFS_VH

// RV32I opcodes
`define OPCODE_LOAD    7'b0000011
`define OPCODE_OP_IMM  7'b0010011
`define OPCODE_STORE   7'b0100011
`define OPCODE_OP      7'b0110011
`define OPCODE_BRANCH  7'b1100011
`define OPCODE_JAL     7'b1101111

// Main-control ALU operation classes
`define ALUOP_ADD      2'b00
`define ALUOP_SUB      2'b01
`define ALUOP_RTYPE    2'b10

// ALU control codes
`define ALU_ADD        4'b0000
`define ALU_SUB        4'b0001
`define ALU_AND        4'b0010
`define ALU_OR         4'b0011
`define ALU_XOR        4'b0100
`define ALU_SLT        4'b0101

// Write-back selections
`define WB_ALU         2'b00
`define WB_MEM         2'b01
`define WB_PC4         2'b10

// Architectural NOP: addi x0, x0, 0
`define RV32_NOP       32'h0000_0013

`endif
