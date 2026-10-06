class rat_agent extends uvm_agent;
  `uvm_component_utils(rat_agent)
  uvm_sequencer #(rat_transaction) sequencer;
  rat_driver            driver;
  rat_monitor           monitor;
  function new(string name = "rat_agent",uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer#(rat_transaction)::type_id::create("sequencer", this);
    driver = rat_driver::type_id::create("driver", this);
    monitor = rat_monitor::type_id::create("monitor", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
