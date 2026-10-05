`timescale 1ns/1ps
`include "rv32i_defs.vh"
// Plain-Verilog replacement for frontend_sva.sv (no SVA / bind in Verilog).
// Instantiate next to the DUT and connect to the same signals. It samples at every
// posedge clk (before the DUT's nonblocking updates land) and emulates $past/$stable
// with registers. Check names match the SystemVerilog assertions.
module frontend_chk #(
  parameter [31:0] RESET_PC   = 32'h0,
  parameter        STRICT_ENC = 0
)(
  input                  clk,
  input                  reset,
  input                  stall,
  input      [31:0]      mem_inst,
  input      [31:0]      pc,
  input      [31:0]      next_pc,
  input      [`DI_W-1:0] decoded_inst
);
`include "rv32i_funcs.vh"

  // ---- field views of decoded_inst ----
  wire        v     = decoded_inst[`DI_VALID];
  wire        sup   = decoded_inst[`DI_SUP];
  wire [31:0] d_pc  = decoded_inst[`DI_PC_H:`DI_PC_L];
  wire [6:0]  d_opc = decoded_inst[`DI_OPC_H:`DI_OPC_L];
  wire [4:0]  d_rd  = decoded_inst[`DI_RD_H:`DI_RD_L];
  wire [4:0]  d_rs1 = decoded_inst[`DI_RS1_H:`DI_RS1_L];
  wire [4:0]  d_rs2 = decoded_inst[`DI_RS2_H:`DI_RS2_L];
  wire [2:0]  d_f3  = decoded_inst[`DI_F3_H:`DI_F3_L];
  wire [6:0]  d_f7  = decoded_inst[`DI_F7_H:`DI_F7_L];
  wire [31:0] d_imm = decoded_inst[`DI_IMM_H:`DI_IMM_L];
  wire [3:0]  d_op  = decoded_inst[`DI_OP_H:`DI_OP_L];

  wire known_in = !(`HAS_X(mem_inst)) && !(`HAS_X(pc));
  wire [`DI_W+64+0:0] all_sig = {stall, pc, next_pc, decoded_inst};   // for the no-X check

  // ---- reference model of spec section 4.4 table: {supported, op} ----
  function [4:0] exp_dec;
    input [6:0] opc;
    input [2:0] f3;
    input [6:0] f7;
    reg [3:0] op;
    reg       legal, b;
    begin
      b = f7[5];
      case (f3)
        3'b000:  op = (opc == `OPC_R && b) ? `ALU_SUB : `ALU_ADD;  // I_ALU: never SUB
        3'b001:  op = `ALU_SLL;
        3'b010:  op = `ALU_SLT;
        3'b011:  op = `ALU_SLTU;
        3'b100:  op = `ALU_XOR;
        3'b101:  op = b ? `ALU_SRA : `ALU_SRL;
        3'b110:  op = `ALU_OR;
        default: op = `ALU_AND;
      endcase
      legal = 1'b1;
      if (STRICT_ENC) begin
        if (opc == `OPC_R) begin
          if (f3 == 3'b000 || f3 == 3'b101) legal = (f7 == 7'h00) || (f7 == 7'h20);
          else                              legal = (f7 == 7'h00);
        end else if (opc == `OPC_I_ALU) begin
          if (f3 == 3'b001)      legal = (f7 == 7'h00);
          else if (f3 == 3'b101) legal = (f7 == 7'h00) || (f7 == 7'h20);
        end
      end
      if ((opc == `OPC_R || opc == `OPC_I_ALU) && legal) exp_dec = {1'b1, op};
      else if (opc == `OPC_LUI || opc == `OPC_AUIPC)     exp_dec = {1'b1, `ALU_ADD};
      else                                               exp_dec = {1'b0, `ALU_NOP};
    end
  endfunction

  // ---- reference model of the immediate (spec section 2) ----
  function [31:0] exp_imm;
    input [31:0] i;
    input        s;
    begin
      case (i[6:0])
        `OPC_I_ALU:
          if (s && (i[14:12] == 3'b001 || i[14:12] == 3'b101))
            exp_imm = {27'b0, i[24:20]};                              // shamt
          else
            exp_imm = sign_extend({20'b0, i[31:20]}, 12);
        `OPC_I_LOAD, `OPC_I_JALR, `OPC_FENCE, `OPC_SYSTEM:
            exp_imm = sign_extend({20'b0, i[31:20]}, 12);
        `OPC_S:   exp_imm = sign_extend({20'b0, i[31:25], i[11:7]}, 12);
        `OPC_B:   exp_imm = sign_extend({19'b0, i[31], i[7], i[30:25], i[11:8], 1'b0}, 13);
        `OPC_LUI, `OPC_AUIPC: exp_imm = {i[31:12], 12'b0};
        `OPC_J:   exp_imm = sign_extend({11'b0, i[31], i[19:12], i[20], i[30:21], 1'b0}, 21);
        default:  exp_imm = 32'b0;
      endcase
    end
  endfunction

  // ---- bookkeeping ----
  integer errors;
  integer cov_unsup, cov_load, cov_branch, cov_jal, cov_ialu, cov_add, cov_sub,
          cov_sra, cov_lui, cov_auipc, cov_stall, cov_xmem, cov_rst2;

  reg             have_prev, have_prev2;
  reg             prev_reset, prev_stall, prev2_reset;
  reg [31:0]      prev_pc;
  reg [`DI_W-1:0] prev_dec;

  initial begin
    errors = 0;
    cov_unsup = 0; cov_load = 0; cov_branch = 0; cov_jal = 0; cov_ialu = 0;
    cov_add = 0; cov_sub = 0; cov_sra = 0; cov_lui = 0; cov_auipc = 0;
    cov_stall = 0; cov_xmem = 0; cov_rst2 = 0;
    have_prev = 1'b0; have_prev2 = 1'b0;
    if (RESET_PC[1:0] != 2'b00) begin
      errors = errors + 1;
      $display("CHK FAIL @%0t : a_reset_pc_param (RESET_PC not aligned)", $time);
    end
  end

  task fail;
    input [8*24-1:0] name;
    begin
      errors = errors + 1;
      $display("CHK FAIL @%0t : %0s", $time, name);
    end
  endtask

  task report;
    begin
      $display("CHK: check failures = %0d", errors);
      $display("CHK: covers unsup=%0d load=%0d branch=%0d jal=%0d ialu=%0d add=%0d sub=%0d",
               cov_unsup, cov_load, cov_branch, cov_jal, cov_ialu, cov_add, cov_sub);
      $display("CHK: covers sra=%0d lui=%0d auipc=%0d stall_release=%0d xmem=%0d reset_again=%0d",
               cov_sra, cov_lui, cov_auipc, cov_stall, cov_xmem, cov_rst2);
      if (cov_unsup==0 || cov_load==0 || cov_branch==0 || cov_jal==0 || cov_ialu==0 ||
          cov_add==0 || cov_sub==0 || cov_sra==0 || cov_lui==0 || cov_auipc==0 ||
          cov_stall==0 || cov_rst2==0)
        $display("CHK WARNING: some covers never hit - related checks may be vacuous");
    end
  endtask

  // ---- the checks ----
  always @(posedge clk) begin
    // reset
    if (reset === 1'b1) begin
      if (v !== 1'b0) fail("a_reset_inv");
    end

    // same-cycle checks, out of reset
    if (reset === 1'b0) begin
      if (next_pc !== pc + 32'd4) fail("a_next_pc");
      if (pc[1:0] !== 2'b00)      fail("a_align");
      if (known_in) begin
        if (v !== 1'b1) fail("a_valid_up");
      end else begin
        if (v !== 1'b0) fail("a_valid_x");
      end
      if (`HAS_X(all_sig)) fail("a_no_x");
    end

    // decode checks
    if (v === 1'b1) begin
      if (d_pc !== pc) fail("a_pc_attach");
      if (d_opc !== mem_inst[6:0]   || d_rd  !== mem_inst[11:7]  ||
          d_rs1 !== mem_inst[19:15] || d_rs2 !== mem_inst[24:20] ||
          d_f3  !== mem_inst[14:12] || d_f7  !== mem_inst[31:25]) fail("a_fields");
      if ({sup, d_op} !== exp_dec(mem_inst[6:0], mem_inst[14:12], mem_inst[31:25]))
        fail("a_opmap");
      if (d_imm !== exp_imm(mem_inst, sup)) fail("a_imm");
      if (sup === 1'b0 && d_op !== `ALU_NOP) fail("a_unsup_nop");
      if (d_opc === `OPC_I_ALU && d_op === `ALU_SUB) fail("a_addi_nosub");
      if (d_opc === `OPC_I_ALU && d_f3 === 3'b000 && !(sup === 1'b1 && d_op === `ALU_ADD))
        fail("a_addi_add");
    end
    if (sup === 1'b1 && v !== 1'b1) fail("a_sup_valid");

    // temporal checks (emulate |=> / $past / $stable)
    if (have_prev) begin
      if (prev_reset === 1'b1 && pc !== RESET_PC) fail("a_reset_pc");
      if (prev_reset === 1'b0 && reset === 1'b0) begin
        if (prev_stall === 1'b1) begin
          if (pc !== prev_pc)               fail("a_stall_pc");
          if (decoded_inst !== prev_dec)    fail("a_stall_dec");
        end else if (prev_stall === 1'b0) begin
          if (pc !== prev_pc + 32'd4)       fail("a_seq_adv");
        end
      end
    end

    // covers
    if (v === 1'b1) begin
      if (sup === 1'b0)                                    cov_unsup  = cov_unsup  + 1;
      if (d_opc === `OPC_I_LOAD)                           cov_load   = cov_load   + 1;
      if (d_opc === `OPC_B)                                cov_branch = cov_branch + 1;
      if (d_opc === `OPC_J)                                cov_jal    = cov_jal    + 1;
      if (d_opc === `OPC_I_ALU)                            cov_ialu   = cov_ialu   + 1;
      if (d_opc === `OPC_R && d_op === `ALU_ADD)           cov_add    = cov_add    + 1;
      if (d_opc === `OPC_R && d_op === `ALU_SUB)           cov_sub    = cov_sub    + 1;
      if (d_op === `ALU_SRA && sup === 1'b1)               cov_sra    = cov_sra    + 1;
      if (d_opc === `OPC_LUI)                              cov_lui    = cov_lui    + 1;
      if (d_opc === `OPC_AUIPC)                            cov_auipc  = cov_auipc  + 1;
    end
    if (have_prev && prev_reset === 1'b0 && reset === 1'b0 &&
        prev_stall === 1'b1 && stall === 1'b0)             cov_stall  = cov_stall  + 1;
    if (reset === 1'b0 && `HAS_X(mem_inst))                cov_xmem   = cov_xmem   + 1;
    if (have_prev2 && prev2_reset === 1'b0 && prev_reset === 1'b1 && reset === 1'b0)
                                                           cov_rst2   = cov_rst2   + 1;

    // remember this cycle
    prev2_reset = prev_reset;  have_prev2 = have_prev;
    prev_reset  = reset;       prev_stall = stall;
    prev_pc     = pc;          prev_dec   = decoded_inst;
    have_prev   = 1'b1;
  end
endmodule
