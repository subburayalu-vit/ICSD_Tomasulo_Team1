import uvm_pkg::*;
`include "uvm_macros.svh"

// ============================================================================
// 1. Interface
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

    logic [3:0]  rat_tag1;
    logic [3:0]  rat_tag2;
    logic [31:0] arf_data1;
    logic [31:0] arf_data2;
    logic        rs_has_free;
    logic [3:0]  rs_free_tag;
    logic        cdb_valid;
    logic [3:0]  cdb_tag;
    logic [31:0] cdb_data;

    logic [4:0]  rat_lookup_reg1;
    logic [4:0]  rat_lookup_reg2;
    logic        issue_en;
    logic [4:0]  issue_dest;
    logic [3:0]  issue_tag;
    logic        rs_alloc_en;
    logic [3:0]  rs_alloc_op;
    logic [31:0] rs_alloc_Vj;
    logic [31:0] rs_alloc_Vk;
    logic [3:0]  rs_alloc_Qj;
    logic [3:0]  rs_alloc_Qk;
    logic [4:0]  rs_alloc_dest;
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

    rand logic [3:0]  rat_tag1;
    rand logic [3:0]  rat_tag2;
    rand logic [31:0] arf_data1;
    rand logic [31:0] arf_data2;
    rand logic        rs_has_free;
    rand logic [3:0]  rs_free_tag;
    rand logic        cdb_valid;
    rand logic [3:0]  cdb_tag;
    rand logic [31:0] cdb_data;

    logic [4:0]  rat_lookup_reg1, rat_lookup_reg2;
    logic        issue_en;
    logic [4:0]  issue_dest;
    logic [3:0]  issue_tag;
    logic        rs_alloc_en;
    logic [3:0]  rs_alloc_op;
    logic [31:0] rs_alloc_Vj, rs_alloc_Vk;
    logic [3:0]  rs_alloc_Qj, rs_alloc_Qk;
    logic [4:0]  rs_alloc_dest;
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
            vif.rat_tag1      <= req.rat_tag1;
            vif.rat_tag2      <= req.rat_tag2;
            vif.arf_data1     <= req.arf_data1;
            vif.arf_data2     <= req.arf_data2;
            vif.rs_has_free   <= req.rs_has_free;
            vif.rs_free_tag   <= req.rs_free_tag;
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
            item.rat_tag1      = vif.rat_tag1;
            item.rat_tag2      = vif.rat_tag2;
            item.arf_data1     = vif.arf_data1;
            item.arf_data2     = vif.arf_data2;
            item.rs_has_free   = vif.rs_has_free;
            item.rs_free_tag   = vif.rs_free_tag;
            item.cdb_valid     = vif.cdb_valid;
            item.cdb_tag       = vif.cdb_tag;
            item.cdb_data      = vif.cdb_data;
            item.issue_en      = vif.issue_en;
            item.issue_dest    = vif.issue_dest;
            item.issue_tag     = vif.issue_tag;
            item.rs_alloc_en   = vif.rs_alloc_en;
            item.rs_alloc_op   = vif.rs_alloc_op;
            item.rs_alloc_Vj   = vif.rs_alloc_Vj;
            item.rs_alloc_Vk   = vif.rs_alloc_Vk;
            item.rs_alloc_Qj   = vif.rs_alloc_Qj;
            item.rs_alloc_Qk   = vif.rs_alloc_Qk;
            item.rs_alloc_dest = vif.rs_alloc_dest;
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
        exp_stall = issuable && !tr.rs_has_free;
        exp_alloc = issuable && tr.rs_has_free;

        if (tr.dec_opcode == OPC_LUI) begin
            exp_Vj = 0; exp_Qj = TAG_NONE;
        end else if (tr.dec_opcode == OPC_AUIPC) begin
            exp_Vj = tr.dec_pc; exp_Qj = TAG_NONE;
        end else if (tr.dec_rs1 == 0) begin
            exp_Vj = 0; exp_Qj = TAG_NONE;
        end else if (tr.rat_tag1 == TAG_NONE) begin
            exp_Vj = tr.arf_data1; exp_Qj = TAG_NONE;
        end else if (tr.cdb_valid && (tr.cdb_tag == tr.rat_tag1)) begin
            exp_Vj = tr.cdb_data; exp_Qj = TAG_NONE; 
        end else begin
            exp_Vj = 0; exp_Qj = tr.rat_tag1;
        end

        if (tr.dec_opcode == OPC_R) begin
            if (tr.dec_rs2 == 0) begin
                exp_Vk = 0; exp_Qk = TAG_NONE;
            end else if (tr.rat_tag2 == TAG_NONE) begin
                exp_Vk = tr.arf_data2; exp_Qk = TAG_NONE;
            end else if (tr.cdb_valid && (tr.cdb_tag == tr.rat_tag2)) begin
                exp_Vk = tr.cdb_data; exp_Qk = TAG_NONE; 
            end else begin
                exp_Vk = 0; exp_Qk = tr.rat_tag2;
            end
        end else begin
            exp_Vk = tr.dec_imm; exp_Qk = TAG_NONE;
        end

        if (tr.stall_frontend !== exp_stall)
            `uvm_error("SCB", $sformatf("Stall mismatch: Expected %0b, Got %0b", exp_stall, tr.stall_frontend))
        
        if (tr.rs_alloc_en !== exp_alloc)
            `uvm_error("SCB", $sformatf("Alloc EN mismatch: Expected %0b, Got %0b", exp_alloc, tr.rs_alloc_en))
            
        if (exp_alloc) begin
            if (tr.rs_alloc_Vj !== exp_Vj || tr.rs_alloc_Qj !== exp_Qj)
                `uvm_error("SCB", $sformatf("Op1 mismatch: Exp V/Q %0h/%0d, Got %0h/%0d", exp_Vj, exp_Qj, tr.rs_alloc_Vj, tr.rs_alloc_Qj))
            if (tr.rs_alloc_Vk !== exp_Vk || tr.rs_alloc_Qk !== exp_Qk)
                `uvm_error("SCB", $sformatf("Op2 mismatch: Exp V/Q %0h/%0d, Got %0h/%0d", exp_Vk, exp_Qk, tr.rs_alloc_Vk, tr.rs_alloc_Qk))
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
        mon.ap.connect(sqr.seq_item_export); // Unused loopback prevention, mon is isolated
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
        .rat_lookup_reg1(vif.rat_lookup_reg1),
        .rat_lookup_reg2(vif.rat_lookup_reg2),
        .rat_tag1(vif.rat_tag1),
        .rat_tag2(vif.rat_tag2),
        .issue_en(vif.issue_en),
        .issue_dest(vif.issue_dest),
        .issue_tag(vif.issue_tag),
        .arf_data1(vif.arf_data1),
        .arf_data2(vif.arf_data2),
        .rs_has_free(vif.rs_has_free),
        .rs_free_tag(vif.rs_free_tag),
        .rs_alloc_en(vif.rs_alloc_en),
        .rs_alloc_op(vif.rs_alloc_op),
        .rs_alloc_Vj(vif.rs_alloc_Vj),
        .rs_alloc_Vk(vif.rs_alloc_Vk),
        .rs_alloc_Qj(vif.rs_alloc_Qj),
        .rs_alloc_Qk(vif.rs_alloc_Qk),
        .rs_alloc_dest(vif.rs_alloc_dest),
        .cdb_valid(vif.cdb_valid),
        .cdb_tag(vif.cdb_tag),
        .cdb_data(vif.cdb_data),
        .stall_frontend(vif.stall_frontend)
    );

    initial begin
        uvm_config_db#(virtual tomasulo_core_if)::set(null, "*", "vif", vif);
        run_test("tomasulo_test");
    end
endmodule