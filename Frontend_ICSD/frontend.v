`timescale 1ns/1ps
`include "rv32i_defs.vh"
// Spec section 4 frontend: PC register + fetch + combinational decode.
module frontend #(
  parameter [31:0] RESET_PC   = 32'h0000_0000,
  parameter        STRICT_ENC = 0
)(
  input                   clk,
  input                   reset,         // synchronous, active-high
  input      [31:0]       mem_inst,      // from instruction memory (addr = pc)
  input                   stall,         // from core stall_frontend
  output reg [31:0]       pc,
  output     [31:0]       next_pc,
  output     [`DI_W-1:0]  decoded_inst
);
  wire fetch_ok;
`ifndef SYNTHESIS
  assign fetch_ok = !reset && !(`HAS_X(mem_inst)) && !(`HAS_X(pc));
`else
  assign fetch_ok = !reset;
`endif

  assign next_pc = pc + 32'd4;

  always @(posedge clk) begin
    if (reset)       pc <= RESET_PC;
    else if (!stall) pc <= next_pc;      // else hold
  end

  decoder #(.STRICT_ENC(STRICT_ENC)) u_dec (
    .fetch_ok (fetch_ok),
    .inst     (mem_inst),
    .pc       (pc),
    .d        (decoded_inst)
  );

`ifndef SYNTHESIS
  initial if (RESET_PC[1:0] != 2'b00)
    $display("ERROR frontend: RESET_PC must be word aligned");
`endif
endmodule
