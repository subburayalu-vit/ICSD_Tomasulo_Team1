class rat_env extends uvm_env;
  `uvm_component_utils(rat_env)
  rat_agent      agent;
  rat_scoreboard scoreboard;
  function new(string name = "rat_env",uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = rat_agent::type_id::create("agent", this);
    scoreboard = rat_scoreboard::type_id::create("scoreboard", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_port);
  endfunction
endclass
