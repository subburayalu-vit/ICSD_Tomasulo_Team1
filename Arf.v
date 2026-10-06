module arf(
  input clk,
  input reset,
  input  cdb_valid,
  input  [4:0]  cdb_dest,
  input  [31:0] cdb_data,
  input  [4:0]  read_addr1,
  input  [4:0]  read_addr2,
  output [31:0] read_data1,
  output [31:0] read_data2
);
  reg [31:0] regfile [0:31];
  integer i;
  assign read_data1 =(read_addr1 == 5'd0) ? 32'd0 : regfile[read_addr1];
  assign read_data2 =(read_addr2 == 5'd0) ? 32'd0 : regfile[read_addr2];
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) begin
        regfile[i] <= 32'd0;
      end
    end
    else begin
      if (cdb_valid && (cdb_dest != 5'd0)) begin
        regfile[cdb_dest] <= cdb_data;
      end
    end
  end
endmodule
