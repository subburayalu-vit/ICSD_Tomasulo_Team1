class rat_transaction extends uvm_sequence_item;
  rand bit        issue_en;
  rand bit [4:0]  issue_dest;
  rand bit [3:0]  issue_tag;
  rand bit        cdb_valid;
  rand bit [3:0]  cdb_tag;
  rand bit [4:0]  lookup_reg1;
  rand bit [4:0]  lookup_reg2;
  bit [3:0]       tag1;
  bit [3:0]       tag2;
  bit             cdb_match;
  `uvm_object_utils(rat_transaction)
  function new(string name = "rat_transaction");
    super.new(name);
  endfunction
endclass
