`timescale 1ns/1ps

module rat_tb;
  reg clk;
  reg reset;
  reg        issue_en;
  reg [3:0]  issue_tag;
  reg [4:0]  issue_dest;
  reg        cdb_valid;
  reg [3:0]  cdb_tag;
  reg [4:0]  lookup_reg1;
  reg [4:0]  lookup_reg2;
  wire [3:0] tag1;
  wire [3:0] tag2;
  wire       cdb_match;
  rat dut (
    .clk(clk),
    .reset(reset),
    .issue_en(issue_en),
    .issue_tag(issue_tag),
    .issue_dest(issue_dest),
    .cdb_valid(cdb_valid),
    .cdb_tag(cdb_tag),
    .lookup_reg1(lookup_reg1),
    .lookup_reg2(lookup_reg2),
    .tag1(tag1),
    .tag2(tag2),
    .cdb_match(cdb_match)
  );
  always #5 clk = ~clk;
  initial begin
    clk = 0;
    reset = 1;
    issue_en = 0;
    issue_tag = 0;
    issue_dest = 0;
    cdb_valid = 0;
    cdb_tag = 0;
    lookup_reg1 = 0;
    lookup_reg2 = 0;
    #10;
    #10;
    reset = 0;
    lookup_reg1 = 5'd5;
    #1;
    if (tag1 == 4'd0)
      $display("PASS: RAT reset - x5 = NONE");
    else
      $display("FAIL: RAT reset - x5 = %d", tag1);
    $finish;
  end
endmodule


endmodule
