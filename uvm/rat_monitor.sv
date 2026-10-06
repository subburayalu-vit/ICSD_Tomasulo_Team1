class rat_monitor extends uvm_monitor;
  `uvm_component_utils(rat_monitor)
  virtual rat_if vif;
  uvm_analysis_port #(rat_transaction) analysis_port;
  function new(string name = "rat_monitor",
               uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rat_if)::get(
      this, "", "vif", vif))
      `uvm_fatal("MONITOR",
                 "Could not get RAT interface")
  endfunction
  task run_phase(uvm_phase phase);
    rat_transaction tr;
    forever begin
      @(posedge vif.clk);
      tr = rat_transaction::type_id::create("tr");
      tr.issue_en    = vif.issue_en;
      tr.issue_dest  = vif.issue_dest;
      tr.issue_tag   = vif.issue_tag;
      tr.cdb_valid   = vif.cdb_valid;
      tr.cdb_tag     = vif.cdb_tag;
      tr.lookup_reg1 = vif.lookup_reg1;
      tr.lookup_reg2 = vif.lookup_reg2;
      tr.tag1        = vif.tag1;
      tr.tag2        = vif.tag2;
      tr.cdb_match   = vif.cdb_match;
      analysis_port.write(tr);
    end
  endtask
endclass
