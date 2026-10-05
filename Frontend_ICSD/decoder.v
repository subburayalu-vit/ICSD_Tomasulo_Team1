`timescale 1ns/1ps
`include "rv32i_defs.vh"
// Spec section 4 decode. Payload is gated by fetch_ok so the output is fully
// defined (all zero, op_name=NOP, valid=0) when memory data / pc is X or in reset.
// STRICT_ENC=0 (default) is spec-literal: only funct7[5] selects ADD/SUB, SRL/SRA.
module decoder #(
  parameter STRICT_ENC = 0
)(
  input                  fetch_ok,
  input      [31:0]      inst,
  input      [31:0]      pc,
  output reg [`DI_W-1:0] d
);
  wire [2:0] f3 = inst[14:12];
  wire [6:0] f7 = inst[31:25];

  wire f7_plain = STRICT_ENC ? (f7 == 7'b0000000) : 1'b1;
  wire f7_zero  = STRICT_ENC ? (f7 == 7'b0000000) : ~f7[5];
  wire f7_one   = STRICT_ENC ? (f7 == 7'b0100000) :  f7[5];

  wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_u = {inst[31:12], 12'b0};
  wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
  wire [31:0] shamt = {27'b0, inst[24:20]};

  reg        sup_r;
  reg [3:0]  op_r;
  reg [31:0] imm_r;

  always @(*) begin
    sup_r = 1'b0;
    op_r  = `ALU_NOP;
    imm_r = 32'b0;

    if (fetch_ok) begin
      case (inst[6:0])
        `OPC_R: begin
          case (f3)
            3'b000: begin
              if (f7_zero)     begin sup_r = 1'b1; op_r = `ALU_ADD; end
              else if (f7_one) begin sup_r = 1'b1; op_r = `ALU_SUB; end
            end
            3'b101: begin
              if (f7_zero)     begin sup_r = 1'b1; op_r = `ALU_SRL; end
              else if (f7_one) begin sup_r = 1'b1; op_r = `ALU_SRA; end
            end
            3'b001: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_SLL;  end
            3'b010: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_SLT;  end
            3'b011: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_SLTU; end
            3'b100: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_XOR;  end
            3'b110: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_OR;   end
            3'b111: if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_AND;  end
            default: ;
          endcase
        end

        `OPC_I_ALU: begin
          imm_r = imm_i;
          case (f3)
            3'b000: begin sup_r = 1'b1; op_r = `ALU_ADD;  end   // never SUB
            3'b010: begin sup_r = 1'b1; op_r = `ALU_SLT;  end
            3'b011: begin sup_r = 1'b1; op_r = `ALU_SLTU; end
            3'b100: begin sup_r = 1'b1; op_r = `ALU_XOR;  end
            3'b110: begin sup_r = 1'b1; op_r = `ALU_OR;   end
            3'b111: begin sup_r = 1'b1; op_r = `ALU_AND;  end
            3'b001: begin
              if (f7_plain) begin sup_r = 1'b1; op_r = `ALU_SLL; imm_r = shamt; end
            end
            3'b101: begin
              if (f7_zero)     begin sup_r = 1'b1; op_r = `ALU_SRL; imm_r = shamt; end
              else if (f7_one) begin sup_r = 1'b1; op_r = `ALU_SRA; imm_r = shamt; end
            end
            default: ;
          endcase
        end

        `OPC_LUI, `OPC_AUIPC: begin
          sup_r = 1'b1; op_r = `ALU_ADD; imm_r = imm_u;
        end

        // decoded for type/immediate only; supported stays 0 (bubble in v1)
        `OPC_I_LOAD, `OPC_I_JALR, `OPC_FENCE, `OPC_SYSTEM: imm_r = imm_i;
        `OPC_S: imm_r = imm_s;
        `OPC_B: imm_r = imm_b;
        `OPC_J: imm_r = imm_j;
        default: ;
      endcase
    end

    if (fetch_ok)
      d = {1'b1, sup_r, pc, inst[6:0], inst[11:7], inst[19:15], inst[24:20],
           f3, f7, imm_r, op_r};
    else
      d = `DI_IDLE;
  end
endmodule
