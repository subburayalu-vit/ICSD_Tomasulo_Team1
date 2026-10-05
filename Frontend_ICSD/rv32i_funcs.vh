// Verilog replacement for the package function sign_extend().
// Include INSIDE a module body:  `include "rv32i_funcs.vh"
function [31:0] sign_extend;
  input [31:0] value;
  input integer from_bits;
  reg [31:0] mask, sign, v;
  begin
    mask = (from_bits >= 32) ? 32'hFFFF_FFFF : ((32'd1 << from_bits) - 32'd1);
    sign = 32'd1 << (from_bits - 1);
    v    = value & mask;
    sign_extend = (v ^ sign) - sign;
  end
endfunction
