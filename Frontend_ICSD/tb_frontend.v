`timescale 1ns/1ps
`include "rv32i_defs.vh"
// Self-checking testbench: memory model + random/directed stimulus + frontend_chk.
module tb_frontend;
  parameter STRICT_ENC = 0;     // 0 = spec-literal (default)
  parameter X_TEST     = 1;     // 1 = words NPROG..NPROG+7 return X (unknown-data test)
  parameter NWORDS     = 64;
  parameter NPROG      = 48;

  reg         clk;
  reg         reset;
  reg         stall;
  wire [31:0] mem_inst, pc, next_pc;
  wire [`DI_W-1:0] decoded_inst;
  reg  [31:0] imem [0:NWORDS-1];
  integer     i;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Instruction memory (spec section 3): async read; out-of-range returns NOP 0x00000013
  assign mem_inst = (pc[31:2] < NWORDS) ? imem[pc[7:2]] : 32'h0000_0013;

  frontend #(.RESET_PC(32'h0), .STRICT_ENC(STRICT_ENC)) dut (
    .clk(clk), .reset(reset), .mem_inst(mem_inst), .stall(stall),
    .pc(pc), .next_pc(next_pc), .decoded_inst(decoded_inst)
  );

  frontend_chk #(.RESET_PC(32'h0), .STRICT_ENC(STRICT_ENC)) u_chk (
    .clk(clk), .reset(reset), .stall(stall), .mem_inst(mem_inst),
    .pc(pc), .next_pc(next_pc), .decoded_inst(decoded_inst)
  );

  // random instruction generator (opcode mix, funct7 biased to legal values)
  function [31:0] rand_inst;
    input dummy;
    reg [31:0] r;
    integer k, m;
    begin
      r = $random;
      k = {$random} % 10;
      case (k)
        0: r[6:0] = `OPC_R;
        1: r[6:0] = `OPC_I_ALU;
        2: r[6:0] = `OPC_I_LOAD;
        3: r[6:0] = `OPC_I_JALR;
        4: r[6:0] = `OPC_S;
        5: r[6:0] = `OPC_B;
        6: r[6:0] = `OPC_LUI;
        7: r[6:0] = `OPC_AUIPC;
        8: r[6:0] = `OPC_J;
        default: r[6:0] = `OPC_SYSTEM;
      endcase
      if (r[6:0] == `OPC_R || r[6:0] == `OPC_I_ALU) begin
        m = {$random} % 3;
        if (m == 0)      r[31:25] = 7'b0000000;
        else if (m == 1) r[31:25] = 7'b0100000;
      end
      rand_inst = r;
    end
  endfunction

  initial begin
    reset = 1'b1;
    stall = 1'b0;
    for (i = 0; i < NWORDS; i = i + 1) begin
      if (i < NPROG)                       imem[i] = rand_inst(1'b0);
      else if (X_TEST && i < NPROG + 8)    imem[i] = 32'bx;
      else                                 imem[i] = 32'h0000_0013;
    end
    imem[0] = 32'h003100B3;  // ADD  x1,x2,x3
    imem[1] = 32'h403100B3;  // SUB  x1,x2,x3
    imem[2] = 32'h00510093;  // ADDI x1,x2,5
    imem[3] = 32'h00012083;  // LW   x1,0(x2)   (unsupported -> NOP)
    imem[4] = 32'h4020D0B3;  // SRA  x1,x1,x2
    imem[5] = 32'h0000A0B7;  // LUI  x1,0xA
    imem[6] = 32'hFE000EE3;  // BEQ  x0,x0,-4   (unsupported)
    imem[7] = 32'h0000006F;  // JAL  x0,0       (unsupported)

    repeat (3) @(negedge clk);
    reset = 1'b0;

    repeat (600) begin
      @(negedge clk);
      stall = (({$random} % 4)   == 0);
      reset = (({$random} % 100) == 0);
    end

    @(negedge clk);
    u_chk.report;
    if (u_chk.errors == 0) $display("TB: PASS");
    else                   $display("TB: FAIL (%0d check failures)", u_chk.errors);
    $finish;
  end
endmodule
