`timescale 1ns/1ps
module tb_top;
  logic clk;
  rat_if vif(clk);
  rat dut (
    .clk          (clk),
    .reset        (vif.reset),

    .issue_en     (vif.issue_en),
    .issue_tag    (vif.issue_tag),
    .issue_dest   (vif.issue_dest),

    .cdb_valid    (vif.cdb_valid),
    .cdb_tag      (vif.cdb_tag),
    .lookup_reg1  (vif.lookup_reg1),
    .lookup_reg2  (vif.lookup_reg2),
    .tag1         (vif.tag1),
    .tag2         (vif.tag2),
    .cdb_match    (vif.cdb_match)
  );
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  initial begin
    vif.reset       = 1'b1;
    vif.issue_en    = 1'b0;
    vif.issue_dest  = 5'd0;
    vif.issue_tag   = 4'd0;
    vif.cdb_valid   = 1'b0;
    vif.cdb_tag     = 4'd0;
    vif.lookup_reg1 = 5'd0;
    vif.lookup_reg2 = 5'd0;
    #20;
    vif.reset = 1'b0;
  end
  initial begin
    uvm_config_db#(virtual rat_if)::set(null,"*","vif",vif);
    run_test("rat_test");
  end
endmodule
