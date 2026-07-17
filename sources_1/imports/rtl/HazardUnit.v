// No forwarding is used in this design.
// A RAW dependency on the instruction currently in MEM/WB causes one stall:
//   1) freeze PC,
//   2) freeze IF/ID,
//   3) flush EX/WB input, inserting a bubble.
// This includes the required LW-use/LB-use hazard and also protects ADDI/ADD-use.
module HazardUnit(
    input  wire       ifid_valid,
    input  wire       id_use_rs1,
    input  wire       id_use_rs2,
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,

    input  wire       exwb_valid,
    input  wire       exwb_reg_write,
    input  wire [4:0] exwb_rd,

    output wire       stall
);
    wire rs1_hazard;
    wire rs2_hazard;

    assign rs1_hazard = id_use_rs1 && (id_rs1 == exwb_rd);
    assign rs2_hazard = id_use_rs2 && (id_rs2 == exwb_rd);

    assign stall = ifid_valid && exwb_valid && exwb_reg_write
                 && (exwb_rd != 5'd0)
                 && (rs1_hazard || rs2_hazard);
endmodule
