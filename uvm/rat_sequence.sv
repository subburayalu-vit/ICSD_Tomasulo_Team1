class rat_sequence extends uvm_sequence #(rat_transaction);
  `uvm_object_utils(rat_sequence)
  function new(string name = "rat_sequence");
    super.new(name);
  endfunction
  task body();
    rat_transaction tr;
    tr = rat_transaction::type_id::create("tr");
    start_item(tr);
    tr.issue_en    = 1'b1;
    tr.issue_dest  = 5'd5;
    tr.issue_tag   = 4'd1;
    tr.cdb_valid   = 1'b0;
    tr.cdb_tag     = 4'd0;
    tr.lookup_reg1 = 5'd5;
    tr.lookup_reg2 = 5'd0;
    finish_item(tr);
  endtask
endclass
