import uvm_pkg::*;
`include "uvm_macros.svh"

// ============================================================================
// 1. Interface (Strictly compliant port names)
// ============================================================================
interface tomasulo_core_if(input logic clk);
    logic        reset;
    logic        dec_valid;
    logic        dec_supported;
    logic [31:0] dec_pc;
    logic [6:0]  dec_opcode;
    logic [4:0]  dec_rd;
    logic [4:0]  dec_rs1;
    logic [4:0]  dec_rs2;
    logic [2:0]  dec_funct3;
    logic [6:0]  dec_funct7;
    logic [31:0] dec_imm;
    logic [3:0]  dec_op_name;

    logic [3:0]  tag1;
    logic [3:0]  tag2;
    logic [31:0] read_data1;
    logic [31:0] read_data2;
    logic        has_free;
    logic [3:0]  free_tag;
    logic        cdb_valid;
    logic [3:0]  cdb_tag;
    logic [31:0] cdb_data;

    logic [4:0]  lookup_reg1;
    logic [4:0]  lookup_reg2;
    logic        issue_en;
    logic [4:0]  issue_dest;
    logic [3:0]  issue_tag;
    logic        alloc_en;
    logic [3:0]  alloc_op;
    logic [31:0] alloc_Vj;
    logic [31:0] alloc_Vk;
    logic [3:0]  alloc_Qj;
    logic [3:0]  alloc_Qk;
    logic [4:0]  alloc_dest;
    logic        stall_frontend;
endinterface

// ============================================================================
// 2. Sequence Item
// ============================================================================
class tomasulo_seq_item extends uvm_sequence_item;
    `uvm_object_utils(tomasulo_seq_item)

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_I_ALU = 7'b0010011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;

    rand logic        dec_valid;
    rand logic        dec_supported;
    rand logic [31:0] dec_pc;
    rand logic [6:0]  dec_opcode;
    rand logic [4:0]  dec_rd;
    rand logic [4:0]  dec_rs1;
    rand logic [4:0]  dec_rs2;
    rand logic [31:0] dec_imm;
    rand logic [3:0]  dec_op_name;

    rand logic [3:0]  tag1;
    rand logic [3:0]  tag2;
    rand logic [31:0] read_data1;
    rand logic [31:0] read_data2;
    rand logic        has_free;
    rand logic [3:0]  free_tag;
    rand logic        cdb_valid;
    rand logic [3:0]  cdb_tag;
    rand logic [31:0] cdb_data;

    logic [4:0]  lookup_reg1, lookup_reg2;
    logic        issue_en;
    logic [4:0]  issue_dest;
    logic [3:0]  issue_tag;
    logic        alloc_en;
    logic [3:0]  alloc_op;
    logic [31:0] alloc_Vj, alloc_Vk;
    logic [3:0]  alloc_Qj, alloc_Qk;
    logic [4:0]  alloc_dest;
    logic        stall_frontend;

    constraint opc_c { dec_opcode inside {OPC_R, OPC_I_ALU, OPC_LUI, OPC_AUIPC}; }

    function new(string name = "tomasulo_seq_item");
        super.new(name);
    endfunction
endclass

// ============================================================================
// 3. Sequence
// ============================================================================
class tomasulo_sequence extends uvm_sequence #(tomasulo_seq_item);
    `uvm_object_utils(tomasulo_sequence)

    function new(string name = "tomasulo_sequence");
        super.new(name);
    endfunction

    task body();
        repeat(100) begin
            req = tomasulo_seq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize()) `uvm_error("SEQ", "Randomization failed")
            finish_item(req);
        end
    endtask
endclass

// ============================================================================
// 4. Driver
// ============================================================================
class tomasulo_driver extends uvm_driver #(tomasulo_seq_item);
    `uvm_component_utils(tomasulo_driver)
    virtual tomasulo_core_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tomasulo_core_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.dec_valid     <= req.dec_valid;
            vif.dec_supported <= req.dec_supported;
            vif.dec_pc        <= req.dec_pc;
            vif.dec_opcode    <= req.dec_opcode;
            vif.dec_rd        <= req.dec_rd;
            vif.dec_rs1       <= req.dec_rs1;
            vif.dec_rs2       <= req.dec_rs2;
            vif.dec_imm       <= req.dec_imm;
            vif.dec_op_name   <= req.dec_op_name;
            vif.tag1          <= req.tag1;
            vif.tag2          <= req.tag2;
            vif.read_data1    <= req.read_data1;
            vif.read_data2    <= req.read_data2;
            vif.has_free      <= req.has_free;
            vif.free_tag      <= req.free_tag;
            vif.cdb_valid     <= req.cdb_valid;
            vif.cdb_tag       <= req.cdb_tag;
            vif.cdb_data      <= req.cdb_data;
            seq_item_port.item_done();
        end
    endtask
endclass

// ============================================================================
// 5. Monitor
// ============================================================================
class tomasulo_monitor extends uvm_monitor;
    `uvm_component_utils(tomasulo_monitor)
    virtual tomasulo_core_if vif;
    uvm_analysis_port #(tomasulo_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tomasulo_core_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        tomasulo_seq_item item;
        forever begin
            @(posedge vif.clk);
            #1; // Delay to sample combinationally settled outputs
            item = tomasulo_seq_item::type_id::create("item");
            item.dec_valid     = vif.dec_valid;
            item.dec_supported = vif.dec_supported;
            item.dec_pc        = vif.dec_pc;
            item.dec_opcode    = vif.dec_opcode;
            item.dec_rd        = vif.dec_rd;
            item.dec_rs1       = vif.dec_rs1;
            item.dec_rs2       = vif.dec_rs2;
            item.dec_imm       = vif.dec_imm;
            item.dec_op_name   = vif.dec_op_name;
            item.tag1          = vif.tag1;
            item.tag2          = vif.tag2;
            item.read_data1    = vif.read_data1;
            item.read_data2    = vif.read_data2;
            item.has_free      = vif.has_free;
            item.free_tag      = vif.free_tag;
            item.cdb_valid     = vif.cdb_valid;
            item.cdb_tag       = vif.cdb_tag;
            item.cdb_data      = vif.cdb_data;
            
            item.lookup_reg1   = vif.lookup_reg1;
            item.lookup_reg2   = vif.lookup_reg2;
            item.issue_en      = vif.issue_en;
            item.issue_dest    = vif.issue_dest;
            item.issue_tag     = vif.issue_tag;
            item.alloc_en      = vif.alloc_en;
            item.alloc_op      = vif.alloc_op;
            item.alloc_Vj      = vif.alloc_Vj;
            item.alloc_Vk      = vif.alloc_Vk;
            item.alloc_Qj      = vif.alloc_Qj;
            item.alloc_Qk      = vif.alloc_Qk;
            item.alloc_dest    = vif.alloc_dest;
            item.stall_frontend= vif.stall_frontend;
            ap.write(item);
        end
    endtask
endclass

// ============================================================================
// 6. Scoreboard
// ============================================================================
class tomasulo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(tomasulo_scoreboard)
    uvm_analysis_imp #(tomasulo_seq_item, tomasulo_scoreboard) ap_imp;

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;
    localparam logic [3:0] TAG_NONE  = 4'd0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(tomasulo_seq_item tr);
        logic issuable, exp_stall, exp_alloc;
        logic [31:0] exp_Vj, exp_Vk;
        logic [3:0]  exp_Qj, exp_Qk;

        issuable = tr.dec_valid && tr.dec_supported && (tr.dec_rd != 0);
        exp_stall = issuable && !tr.has_free;
        exp_alloc = issuable && tr.has_free;

        if (tr.dec_opcode == OPC_LUI) begin
            exp_Vj = 0; exp_Qj = TAG_NONE;
        end else if (tr.dec_opcode == OPC_AUIPC) begin
            exp_Vj = tr.dec_pc; exp_Qj = TAG_NONE;
        end else if (tr.dec_rs1 == 0) begin
            exp_Vj = 0; exp_Qj = TAG_NONE;
        end else if (tr.tag1 == TAG_NONE) begin
            exp_Vj = tr.read_data1; exp_Qj = TAG_NONE;
        end else if (tr.cdb_valid && (tr.cdb_tag == tr.tag1)) begin
            exp_Vj = tr.cdb_data; exp_Qj = TAG_NONE; 
        end else begin
            exp_Vj = 0; exp_Qj = tr.tag1;
        end

        if (tr.dec_opcode == OPC_R) begin
            if (tr.dec_rs2 == 0) begin
                exp_Vk = 0; exp_Qk = TAG_NONE;
            end else if (tr.tag2 == TAG_NONE) begin
                exp_Vk = tr.read_data2; exp_Qk = TAG_NONE;
            end else if (tr.cdb_valid && (tr.cdb_tag == tr.tag2)) begin
                exp_Vk = tr.cdb_data; exp_Qk = TAG_NONE; 
            end else begin
                exp_Vk = 0; exp_Qk = tr.tag2;
            end
        end else begin
            exp_Vk = tr.dec_imm; exp_Qk = TAG_NONE;
        end

        if (tr.stall_frontend !== exp_stall)
            `uvm_error("SCB", $sformatf("Stall mismatch: Expected %0b, Got %0b", exp_stall, tr.stall_frontend))
        
        if (tr.alloc_en !== exp_alloc)
            `uvm_error("SCB", $sformatf("Alloc EN mismatch: Expected %0b, Got %0b", exp_alloc, tr.alloc_en))
            
        if (exp_alloc) begin
            if (tr.alloc_Vj !== exp_Vj || tr.alloc_Qj !== exp_Qj)
                `uvm_error("SCB", $sformatf("Op1 mismatch: Exp V/Q %0h/%0d, Got %0h/%0d", exp_Vj, exp_Qj, tr.alloc_Vj, tr.alloc_Qj))
            if (tr.alloc_Vk !== exp_Vk || tr.alloc_Qk !== exp_Qk)
                `uvm_error("SCB", $sformatf("Op2 mismatch: Exp V/Q %0h/%0d, Got %0h/%0d", exp_Vk, exp_Qk, tr.alloc_Vk, tr.alloc_Qk))
        end
    endfunction
endclass

// ============================================================================
// 7. Agent and Environment
// ============================================================================
class tomasulo_agent extends uvm_agent;
    `uvm_component_utils(tomasulo_agent)
    uvm_sequencer #(tomasulo_seq_item) sqr;
    tomasulo_driver drv;
    tomasulo_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(tomasulo_seq_item)::type_id::create("sqr", this);
        drv = tomasulo_driver::type_id::create("drv", this);
        mon = tomasulo_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        // The rogue monitor connection has been safely removed.
    endfunction
endclass

class tomasulo_env extends uvm_env;
    `uvm_component_utils(tomasulo_env)
    tomasulo_agent agent;
    tomasulo_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = tomasulo_agent::type_id::create("agent", this);
        scb = tomasulo_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.mon.ap.connect(scb.ap_imp);
    endfunction
endclass

// ============================================================================
// 8. Test
// ============================================================================
class tomasulo_test extends uvm_test;
    `uvm_component_utils(tomasulo_test)
    tomasulo_env env;
    tomasulo_sequence seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tomasulo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq = tomasulo_sequence::type_id::create("seq");
        seq.start(env.agent.sqr);
        #50;
        phase.drop_objection(this);
    endtask
endclass

// ============================================================================
// 9. Top Level Module
// ============================================================================
module tb_top;
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    tomasulo_core_if vif(clk);

    tomasulo_core dut (
        .clk(vif.clk),
        .reset(vif.reset),
        .dec_valid(vif.dec_valid),
        .dec_supported(vif.dec_supported),
        .dec_pc(vif.dec_pc),
        .dec_opcode(vif.dec_opcode),
        .dec_rd(vif.dec_rd),
        .dec_rs1(vif.dec_rs1),
        .dec_rs2(vif.dec_rs2),
        .dec_funct3(vif.dec_funct3),
        .dec_funct7(vif.dec_funct7),
        .dec_imm(vif.dec_imm),
        .dec_op_name(vif.dec_op_name),
        .tag1(vif.tag1),
        .tag2(vif.tag2),
        .read_data1(vif.read_data1),
        .read_data2(vif.read_data2),
        .has_free(vif.has_free),
        .free_tag(vif.free_tag),
        .cdb_valid(vif.cdb_valid),
        .cdb_tag(vif.cdb_tag),
        .cdb_data(vif.cdb_data),
        .lookup_reg1(vif.lookup_reg1),
        .lookup_reg2(vif.lookup_reg2),
        .issue_en(vif.issue_en),
        .issue_dest(vif.issue_dest),
        .issue_tag(vif.issue_tag),
        .alloc_en(vif.alloc_en),
        .alloc_op(vif.alloc_op),
        .alloc_Vj(vif.alloc_Vj),
        .alloc_Vk(vif.alloc_Vk),
        .alloc_Qj(vif.alloc_Qj),
        .alloc_Qk(vif.alloc_Qk),
        .alloc_dest(vif.alloc_dest),
        .stall_frontend(vif.stall_frontend)
    );

    initial begin
        uvm_config_db#(virtual tomasulo_core_if)::set(null, "*", "vif", vif);
        run_test("tomasulo_test");
    end
endmodule