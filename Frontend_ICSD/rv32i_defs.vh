// Verilog-2001 replacement for package rv32i_types (spec section 2).
// Include with:  `include "rv32i_defs.vh"   (compile with +incdir+<this dir>)
`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

// ---- Opcodes ----
`define OPC_R      7'b0110011
`define OPC_I_ALU  7'b0010011
`define OPC_I_LOAD 7'b0000011
`define OPC_I_JALR 7'b1100111
`define OPC_S      7'b0100011
`define OPC_B      7'b1100011
`define OPC_LUI    7'b0110111
`define OPC_AUIPC  7'b0010111
`define OPC_J      7'b1101111
`define OPC_FENCE  7'b0001111
`define OPC_SYSTEM 7'b1110011

// ---- RSTag (4-bit). Only ALU1..ALU3 used in v1 ----
`define TAG_NONE   4'd0
`define TAG_ALU1   4'd1
`define TAG_ALU2   4'd2
`define TAG_ALU3   4'd3
`define TAG_MUL1   4'd4
`define TAG_MUL2   4'd5
`define TAG_LOAD1  4'd6
`define TAG_LOAD2  4'd7
`define TAG_STORE1 4'd8
`define TAG_STORE2 4'd9

// ---- alu_op_t (4-bit) ----
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9
`define ALU_NOP  4'd15

// ---- DecodedInst flattened to one 102-bit vector (MSB first, spec field order) ----
//  {valid, supported, pc[31:0], opcode[6:0], rd[4:0], rs1[4:0], rs2[4:0],
//   funct3[2:0], funct7[6:0], imm[31:0], op_name[3:0]}
`define DI_W      102
`define DI_VALID  101
`define DI_SUP    100
`define DI_PC_H    99
`define DI_PC_L    68
`define DI_OPC_H   67
`define DI_OPC_L   61
`define DI_RD_H    60
`define DI_RD_L    56
`define DI_RS1_H   55
`define DI_RS1_L   51
`define DI_RS2_H   50
`define DI_RS2_L   46
`define DI_F3_H    45
`define DI_F3_L    43
`define DI_F7_H    42
`define DI_F7_L    36
`define DI_IMM_H   35
`define DI_IMM_L    4
`define DI_OP_H     3
`define DI_OP_L     0
// all-zero payload, valid=0, supported=0, op_name=NOP
`define DI_IDLE   {98'd0, 4'd15}

// ---- simulation-only X detector (Verilog has no $isunknown) ----
`define HAS_X(sig) ((^(sig)) === 1'bx)

`endif
