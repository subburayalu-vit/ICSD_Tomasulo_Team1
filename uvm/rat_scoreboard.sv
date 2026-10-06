class rat_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(rat_scoreboard)
  uvm_analysis_imp #(rat_transaction, rat_scoreboard)
  analysis_port;
  bit [3:0] expected_tag [0:31];
  function new(string name = "rat_scoreboard",
               uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for (int i = 0; i < 32; i++)
      expected_tag[i] = 4'd0;
  endfunction
  function void write(rat_transaction tr);
    bit [3:0] expected_tag1;
    bit [3:0] expected_tag2;
    bit expected_cdb_match;
    if (tr.cdb_valid) begin
      for (int i = 1; i < 32; i++) begin
        if (expected_tag[i] == tr.cdb_tag)
          expected_tag[i] = 4'd0;
      end
    end
    if (tr.issue_en && (tr.issue_dest != 5'd0))
      expected_tag[tr.issue_dest] = tr.issue_tag;
    expected_tag[0] = 4'd0;
    expected_tag1 =(tr.lookup_reg1 == 5'd0) ?4'd0 : expected_tag[tr.lookup_reg1];
    expected_tag2 =(tr.lookup_reg2 == 5'd0) ?4'd0 : expected_tag[tr.lookup_reg2];
    expected_cdb_match = 1'b0;
    if (tr.cdb_valid) begin
      for (int i = 1; i < 32; i++) begin
        if (expected_tag[i] == tr.cdb_tag)
          expected_cdb_match = 1'b1;
      end
    end
    if (tr.tag1 !== expected_tag1) begin
      `uvm_error("RAT_SB",$sformatf("TAG1 MISMATCH: expected=%0d actual=%0d",expected_tag1, tr.tag1))
    end
    if (tr.tag2 !== expected_tag2) begin
      `uvm_error("RAT_SB",$sformatf("TAG2 MISMATCH: expected=%0d actual=%0d",expected_tag2, tr.tag2))
    end
    if (tr.cdb_match !== expected_cdb_match) begin
      `uvm_error("RAT_SB",$sformatf("CDB MATCH MISMATCH: expected=%0d actual=%0d",expected_cdb_match, tr.cdb_match))
    end
    if ((tr.tag1 === expected_tag1) &&(tr.tag2 === expected_tag2) &&(tr.cdb_match === expected_cdb_match)) begin
      `uvm_info("RAT_SB","RAT CHECK PASSED",UVM_MEDIUM)
    end
  endfunction
endclass
