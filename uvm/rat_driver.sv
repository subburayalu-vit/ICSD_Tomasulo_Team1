class rat_driver extends uvm_driver #(rat_transaction);
  `uvm_component_utils(rat_driver)
  virtual rat_if vif;
  function new(string name = "rat_driver",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rat_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRIVER","Could not get RAT interface")
  endfunction
  task run_phase(uvm_phase phase);
    rat_transaction tr;
    forever begin
      seq_item_port.get_next_item(tr);
      @(posedge vif.clk);
      vif.issue_en    <= tr.issue_en;
      vif.issue_dest  <= tr.issue_dest;
      vif.issue_tag   <= tr.issue_tag;
      vif.cdb_valid   <= tr.cdb_valid;
      vif.cdb_tag     <= tr.cdb_tag;
      vif.lookup_reg1 <= tr.lookup_reg1;
      vif.lookup_reg2 <= tr.lookup_reg2;
      seq_item_port.item_done();
    end
  endtask
endclass
