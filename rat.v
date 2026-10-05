module rat(
  input  clk,
  input reset,
  input issue_en,
  input [3:0] issue_tag,
  input [4:0] issue_dest,
  input  cdb_valid,
  input  [3:0] cdb_tag,
  input  [4:0] lookup_reg1,
  input  [4:0] lookup_reg2,
  output [3:0] tag1,
  output [3:0] tag2,
  output cdb_match
);
  reg [3:0] tag [0:31];
  integer i;
  assign tag1 = (lookup_reg1 == 5'd0) ? 4'd0 : tag[lookup_reg1];
  assign tag2 = (lookup_reg2 == 5'd0) ? 4'd0 : tag[lookup_reg2];
  reg cdb_match_reg;
  always @(*) begin
    cdb_match_reg = 1'b0;
    if (cdb_valid) begin
      for (i = 1; i < 32; i = i + 1) begin
        if (tag[i] == cdb_tag)
          cdb_match_reg = 1'b1;
      end
    end
  end
  assign cdb_match = cdb_match_reg;
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) begin
        tag[i] <= 4'b0000;
      end
    end
    else begin
      if (cdb_valid) begin
        for (i = 1; i < 32; i = i + 1) begin
          if (tag[i] == cdb_tag) begin
            tag[i] <= 4'd0;
          end
        end
      end
      if (issue_en && (issue_dest != 5'd0)) begin
        tag[issue_dest] <= issue_tag;
      end
    end
  end
endmodule
  
  
