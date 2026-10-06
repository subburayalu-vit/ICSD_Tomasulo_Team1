interface rat_if(input logic clk);
  logic reset;
  logic        issue_en;
  logic [4:0]  issue_dest;
  logic [3:0]  issue_tag;
  logic        cdb_valid;
  logic [3:0]  cdb_tag;
  logic [4:0]  lookup_reg1;
  logic [4:0]  lookup_reg2;
  logic [3:0]  tag1;
  logic [3:0]  tag2;
  logic        cdb_match;

endinterface
