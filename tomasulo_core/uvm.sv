// ============================================================================
// UVM TESTBENCH FOR tomasulo_core
// Compatible with the revised tomasulo_core.sv
// ============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"


// ============================================================================
// 1. INTERFACE
// ============================================================================

interface tomasulo_core_if(input logic clk);

    // ------------------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------------------
    logic reset;

    // ------------------------------------------------------------------------
    // Decoded instruction
    // ------------------------------------------------------------------------
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

    // ------------------------------------------------------------------------
    // RAT
    // ------------------------------------------------------------------------
    logic [4:0]  rat_lookup_reg1;
    logic [4:0]  rat_lookup_reg2;

    logic [3:0]  rat_tag1;
    logic [3:0]  rat_tag2;

    logic        issue_en;
    logic [4:0]  issue_dest;
    logic [3:0]  issue_tag;

    // ------------------------------------------------------------------------
    // ARF
    // ------------------------------------------------------------------------
    logic [31:0] arf_data1;
    logic [31:0] arf_data2;

    // ------------------------------------------------------------------------
    // Reservation Station
    // ------------------------------------------------------------------------
    logic        rs_has_free;
    logic [3:0]  rs_free_tag;

    logic        rs_alloc_en;
    logic [3:0]  rs_alloc_op;
    logic [31:0] rs_alloc_Vj;
    logic [31:0] rs_alloc_Vk;
    logic [3:0]  rs_alloc_Qj;
    logic [3:0]  rs_alloc_Qk;
    logic [4:0]  rs_alloc_dest;

    // ------------------------------------------------------------------------
    // CDB
    // ------------------------------------------------------------------------
    logic        cdb_valid;
    logic [3:0]  cdb_tag;
    logic [31:0] cdb_data;

    // ------------------------------------------------------------------------
    // Frontend
    // ------------------------------------------------------------------------
    logic        stall_frontend;

endinterface



// ============================================================================
// 2. SEQUENCE ITEM
// ============================================================================

class tomasulo_seq_item extends uvm_sequence_item;

    `uvm_object_utils(tomasulo_seq_item)

    // ------------------------------------------------------------------------
    // Opcodes
    // ------------------------------------------------------------------------

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_I_ALU = 7'b0010011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;

    // ------------------------------------------------------------------------
    // ALU operation encoding
    // ------------------------------------------------------------------------

    localparam logic [3:0] ALU_ADD  = 4'd0;
    localparam logic [3:0] ALU_SUB  = 4'd1;
    localparam logic [3:0] ALU_SLL  = 4'd2;
    localparam logic [3:0] ALU_SLT  = 4'd3;
    localparam logic [3:0] ALU_SLTU = 4'd4;
    localparam logic [3:0] ALU_XOR  = 4'd5;
    localparam logic [3:0] ALU_SRL  = 4'd6;
    localparam logic [3:0] ALU_SRA  = 4'd7;
    localparam logic [3:0] ALU_OR   = 4'd8;
    localparam logic [3:0] ALU_AND  = 4'd9;
    localparam logic [3:0] ALU_NOP  = 4'd15;

    localparam logic [3:0] TAG_NONE = 4'd0;


    // ------------------------------------------------------------------------
    // DUT INPUTS
    // ------------------------------------------------------------------------

    rand logic        dec_valid;
    rand logic        dec_supported;

    rand logic [31:0] dec_pc;
    rand logic [6:0]  dec_opcode;
    rand logic [4:0]  dec_rd;
    rand logic [4:0]  dec_rs1;
    rand logic [4:0]  dec_rs2;
    rand logic [2:0]  dec_funct3;
    rand logic [6:0]  dec_funct7;
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


    // ------------------------------------------------------------------------
    // DUT OUTPUTS - sampled by monitor
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // RANDOMIZATION CONSTRAINTS
    // ------------------------------------------------------------------------

    constraint opcode_c {
        dec_opcode inside {
            OPC_R,
            OPC_I_ALU,
            OPC_LUI,
            OPC_AUIPC
        };
    }

    constraint valid_c {
        dec_valid dist {
            1'b1 := 9,
            1'b0 := 1
        };
    }

    constraint supported_c {
        dec_supported dist {
            1'b1 := 9,
            1'b0 := 1
        };
    }

    constraint tag_c {
        rat_tag1 inside {[0:3]};
        rat_tag2 inside {[0:3]};
        cdb_tag  inside {[0:3]};
    }

    constraint free_tag_c {

        if (rs_has_free)
            rs_free_tag inside {4'd1, 4'd2, 4'd3};

        else
            rs_free_tag == TAG_NONE;

    }

    constraint op_c {

        if (dec_opcode == OPC_R) begin

            dec_op_name inside {
                ALU_ADD,
                ALU_SUB,
                ALU_SLL,
                ALU_SLT,
                ALU_SLTU,
                ALU_XOR,
                ALU_SRL,
                ALU_SRA,
                ALU_OR,
                ALU_AND
            };

        end

        else if (dec_opcode == OPC_I_ALU) begin

            dec_op_name inside {
                ALU_ADD,
                ALU_SLL,
                ALU_SLT,
                ALU_SLTU,
                ALU_XOR,
                ALU_SRL,
                ALU_SRA,
                ALU_OR,
                ALU_AND
            };

        end

        else begin
            dec_op_name == ALU_ADD;
        end

    }


    // ------------------------------------------------------------------------
    // Construct
    // ------------------------------------------------------------------------

    function new(string name = "tomasulo_seq_item");
        super.new(name);
    endfunction


    // ------------------------------------------------------------------------
    // Generate consistent funct3/funct7 values.
    //
    // tomasulo_core does not currently use these fields, but they are kept
    // coherent with dec_op_name so that the transaction still resembles
    // a legal decoded instruction.
    // ------------------------------------------------------------------------

    function void post_randomize();

        dec_funct3 = 3'b000;
        dec_funct7 = 7'b0000000;

        case (dec_op_name)

            ALU_ADD: begin
                dec_funct3 = 3'b000;
                dec_funct7 = 7'b0000000;
            end

            ALU_SUB: begin
                dec_funct3 = 3'b000;
                dec_funct7 = 7'b0100000;
            end

            ALU_SLL: begin
                dec_funct3 = 3'b001;
                dec_funct7 = 7'b0000000;
            end

            ALU_SLT: begin
                dec_funct3 = 3'b010;
                dec_funct7 = 7'b0000000;
            end

            ALU_SLTU: begin
                dec_funct3 = 3'b011;
                dec_funct7 = 7'b0000000;
            end

            ALU_XOR: begin
                dec_funct3 = 3'b100;
                dec_funct7 = 7'b0000000;
            end

            ALU_SRL: begin
                dec_funct3 = 3'b101;
                dec_funct7 = 7'b0000000;
            end

            ALU_SRA: begin
                dec_funct3 = 3'b101;
                dec_funct7 = 7'b0100000;
            end

            ALU_OR: begin
                dec_funct3 = 3'b110;
                dec_funct7 = 7'b0000000;
            end

            ALU_AND: begin
                dec_funct3 = 3'b111;
                dec_funct7 = 7'b0000000;
            end

            default: begin
                dec_funct3 = 3'b000;
                dec_funct7 = 7'b0000000;
            end

        endcase

    endfunction


    // ------------------------------------------------------------------------
    // Debug string
    // ------------------------------------------------------------------------

    function string convert2string();

        return $sformatf(
            "valid=%0b supported=%0b opcode=%07b "
            "pc=%08h rd=%0d rs1=%0d rs2=%0d imm=%08h op=%0d "
            "RAT=(%0d,%0d) ARF=(%08h,%08h) "
            "RSfree=%0b free_tag=%0d "
            "CDB=(%0b,%0d,%08h)",
            dec_valid,
            dec_supported,
            dec_opcode,
            dec_pc,
            dec_rd,
            dec_rs1,
            dec_rs2,
            dec_imm,
            dec_op_name,
            rat_tag1,
            rat_tag2,
            arf_data1,
            arf_data2,
            rs_has_free,
            rs_free_tag,
            cdb_valid,
            cdb_tag,
            cdb_data
        );

    endfunction

endclass



// ============================================================================
// 3. SEQUENCER
// ============================================================================

class tomasulo_sequencer extends uvm_sequencer #(tomasulo_seq_item);

    `uvm_component_utils(tomasulo_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass



// ============================================================================
// 4. SEQUENCE
// ============================================================================

class tomasulo_sequence extends uvm_sequence #(tomasulo_seq_item);

    `uvm_object_utils(tomasulo_sequence)

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_I_ALU = 7'b0010011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;

    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd9;
    localparam logic [3:0] ALU_XOR = 4'd5;


    function new(string name = "tomasulo_sequence");
        super.new(name);
    endfunction


    // ------------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------------

    task body();

        tomasulo_seq_item req;


        // ====================================================================
        // TEST 1: Normal R-type instruction, both operands available
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("ready_operands");

        start_item(req);

        req.dec_valid     = 1'b1;
        req.dec_supported = 1'b1;
        req.dec_pc       = 32'h0000_0100;
        req.dec_opcode   = OPC_R;

        req.dec_rd       = 5'd5;
        req.dec_rs1      = 5'd1;
        req.dec_rs2      = 5'd2;

        req.dec_imm      = 32'd0;
        req.dec_op_name  = ALU_ADD;

        req.rat_tag1     = 4'd0;
        req.rat_tag2     = 4'd0;

        req.arf_data1    = 32'h0000_0011;
        req.arf_data2    = 32'h0000_0022;

        req.rs_has_free  = 1'b1;
        req.rs_free_tag  = 4'd1;

        req.cdb_valid    = 1'b0;
        req.cdb_tag      = 4'd0;
        req.cdb_data     = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 2: RAW dependency
        //
        // rs1 waits for ALU1.
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("raw_wait");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_0104;
        req.dec_opcode    = OPC_R;

        req.dec_rd        = 5'd6;
        req.dec_rs1       = 5'd5;
        req.dec_rs2       = 5'd2;

        req.dec_imm       = 32'd0;
        req.dec_op_name   = ALU_SUB;

        req.rat_tag1      = 4'd1;
        req.rat_tag2      = 4'd0;

        req.arf_data1     = 32'hAAAA_AAAA;
        req.arf_data2     = 32'h0000_0022;

        req.rs_has_free   = 1'b1;
        req.rs_free_tag   = 4'd2;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 3: Same-cycle CDB bypass
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("cdb_bypass");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_0108;
        req.dec_opcode    = OPC_R;

        req.dec_rd        = 5'd7;
        req.dec_rs1       = 5'd6;
        req.dec_rs2       = 5'd2;

        req.dec_imm       = 32'd0;
        req.dec_op_name   = ALU_AND;

        req.rat_tag1      = 4'd2;
        req.rat_tag2      = 4'd0;

        req.arf_data1     = 32'h1111_1111;
        req.arf_data2     = 32'h2222_2222;

        req.rs_has_free   = 1'b1;
        req.rs_free_tag   = 4'd1;

        req.cdb_valid     = 1'b1;
        req.cdb_tag       = 4'd2;
        req.cdb_data      = 32'hDEAD_BEEF;

        finish_item(req);


        // ====================================================================
        // TEST 4: RS full
        //
        // Valid instruction + no free RS -> stall.
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("rs_full");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_010C;
        req.dec_opcode    = OPC_I_ALU;

        req.dec_rd        = 5'd8;
        req.dec_rs1       = 5'd1;
        req.dec_rs2       = 5'd0;

        req.dec_imm       = 32'd10;
        req.dec_op_name   = ALU_ADD;

        req.rat_tag1      = 4'd0;
        req.rat_tag2      = 4'd0;

        req.arf_data1     = 32'd100;
        req.arf_data2     = 32'd0;

        req.rs_has_free   = 1'b0;
        req.rs_free_tag   = 4'd0;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 5: rd = x0
        //
        // Must not issue and must not stall.
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("rd_x0");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_0110;
        req.dec_opcode    = OPC_R;

        req.dec_rd        = 5'd0;
        req.dec_rs1       = 5'd1;
        req.dec_rs2       = 5'd2;

        req.dec_imm       = 32'd0;
        req.dec_op_name   = ALU_XOR;

        req.rat_tag1      = 4'd0;
        req.rat_tag2      = 4'd0;

        req.arf_data1     = 32'hAAAA_0001;
        req.arf_data2     = 32'hBBBB_0002;

        // Even though RS is full, rd=x0 must not stall.
        req.rs_has_free   = 1'b0;
        req.rs_free_tag   = 4'd0;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 6: Unsupported instruction
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("unsupported");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b0;
        req.dec_pc        = 32'h0000_0114;
        req.dec_opcode    = OPC_R;

        req.dec_rd        = 5'd10;
        req.dec_rs1       = 5'd1;
        req.dec_rs2       = 5'd2;

        req.dec_imm       = 32'd0;
        req.dec_op_name   = ALU_ADD;

        req.rat_tag1      = 4'd3;
        req.rat_tag2      = 4'd2;

        req.arf_data1     = 32'h1234_5678;
        req.arf_data2     = 32'h8765_4321;

        req.rs_has_free   = 1'b0;
        req.rs_free_tag   = 4'd0;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 7: LUI
        //
        // Vj must be 0, Vk = immediate.
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("lui_test");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_0118;
        req.dec_opcode    = OPC_LUI;

        req.dec_rd        = 5'd11;
        req.dec_rs1       = 5'd0;
        req.dec_rs2       = 5'd0;

        req.dec_imm       = 32'h1234_5000;
        req.dec_op_name   = ALU_ADD;

        // These should be ignored by the core for LUI.
        req.rat_tag1      = 4'd3;
        req.rat_tag2      = 4'd2;

        req.arf_data1     = 32'hAAAA_AAAA;
        req.arf_data2     = 32'hBBBB_BBBB;

        req.rs_has_free   = 1'b1;
        req.rs_free_tag   = 4'd3;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // TEST 8: AUIPC
        //
        // Vj must be PC, Vk = immediate.
        // ====================================================================

        req = tomasulo_seq_item::type_id::create("auipc_test");

        start_item(req);

        req.dec_valid      = 1'b1;
        req.dec_supported  = 1'b1;
        req.dec_pc        = 32'h0000_2000;
        req.dec_opcode    = OPC_AUIPC;

        req.dec_rd        = 5'd12;
        req.dec_rs1       = 5'd0;
        req.dec_rs2       = 5'd0;

        req.dec_imm       = 32'h0000_3000;
        req.dec_op_name   = ALU_ADD;

        req.rat_tag1      = 4'd3;
        req.rat_tag2      = 4'd2;

        req.arf_data1     = 32'h1111_1111;
        req.arf_data2     = 32'h2222_2222;

        req.rs_has_free   = 1'b1;
        req.rs_free_tag   = 4'd1;

        req.cdb_valid     = 1'b0;
        req.cdb_tag       = 4'd0;
        req.cdb_data      = 32'd0;

        finish_item(req);


        // ====================================================================
        // RANDOM LEGAL TESTS
        // ====================================================================

        `uvm_info("SEQ",
                  "Starting randomized Tomasulo core tests",
                  UVM_LOW)

        repeat (100) begin

            req = tomasulo_seq_item::type_id::create("random_req");

            start_item(req);

            if (!req.randomize()) begin
                `uvm_fatal("SEQ",
                           "Randomization failed")
            end

            finish_item(req);

        end

        `uvm_info("SEQ",
                  "Tomasulo sequence completed",
                  UVM_LOW)

    endtask

endclass



// ============================================================================
// 5. DRIVER
// ============================================================================

class tomasulo_driver extends uvm_driver #(tomasulo_seq_item);

    `uvm_component_utils(tomasulo_driver)

    virtual tomasulo_core_if vif;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual tomasulo_core_if)::get(
                this,
                "",
                "vif",
                vif)) begin

            `uvm_fatal("DRV",
                       "Virtual interface not found")

        end

    endfunction


    task run_phase(uvm_phase phase);

        forever begin

            seq_item_port.get_next_item(req);

            // ---------------------------------------------------------------
            // Drive on the clock edge.
            //
            // The core is combinational, so outputs settle after these
            // assignments.
            // ---------------------------------------------------------------

            @(posedge vif.clk);

            vif.dec_valid     <= req.dec_valid;
            vif.dec_supported <= req.dec_supported;
            vif.dec_pc        <= req.dec_pc;
            vif.dec_opcode    <= req.dec_opcode;
            vif.dec_rd        <= req.dec_rd;
            vif.dec_rs1       <= req.dec_rs1;
            vif.dec_rs2       <= req.dec_rs2;
            vif.dec_funct3    <= req.dec_funct3;
            vif.dec_funct7    <= req.dec_funct7;
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

            // Tell sequencer transaction has been driven.
            seq_item_port.item_done();

        end

    endtask

endclass



// ============================================================================
// 6. MONITOR
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

        if (!uvm_config_db#(virtual tomasulo_core_if)::get(
                this,
                "",
                "vif",
                vif)) begin

            `uvm_fatal("MON",
                       "Virtual interface not found")

        end

    endfunction


    task run_phase(uvm_phase phase);

        tomasulo_seq_item tr;

        forever begin

            @(posedge vif.clk);

            // Allow driver NBA updates and DUT combinational logic to settle.
            #1;

            tr = tomasulo_seq_item::type_id::create("mon_tr");

            // ---------------------------------------------------------------
            // Inputs
            // ---------------------------------------------------------------

            tr.dec_valid      = vif.dec_valid;
            tr.dec_supported  = vif.dec_supported;
            tr.dec_pc         = vif.dec_pc;
            tr.dec_opcode     = vif.dec_opcode;
            tr.dec_rd         = vif.dec_rd;
            tr.dec_rs1        = vif.dec_rs1;
            tr.dec_rs2        = vif.dec_rs2;
            tr.dec_funct3     = vif.dec_funct3;
            tr.dec_funct7     = vif.dec_funct7;
            tr.dec_imm        = vif.dec_imm;
            tr.dec_op_name    = vif.dec_op_name;

            tr.rat_tag1       = vif.rat_tag1;
            tr.rat_tag2       = vif.rat_tag2;

            tr.arf_data1      = vif.arf_data1;
            tr.arf_data2      = vif.arf_data2;

            tr.rs_has_free    = vif.rs_has_free;
            tr.rs_free_tag    = vif.rs_free_tag;

            tr.cdb_valid      = vif.cdb_valid;
            tr.cdb_tag        = vif.cdb_tag;
            tr.cdb_data       = vif.cdb_data;

            // ---------------------------------------------------------------
            // DUT outputs
            // ---------------------------------------------------------------

            tr.rat_lookup_reg1 = vif.rat_lookup_reg1;
            tr.rat_lookup_reg2 = vif.rat_lookup_reg2;

            tr.issue_en        = vif.issue_en;
            tr.issue_dest      = vif.issue_dest;
            tr.issue_tag       = vif.issue_tag;

            tr.rs_alloc_en     = vif.rs_alloc_en;
            tr.rs_alloc_op     = vif.rs_alloc_op;
            tr.rs_alloc_Vj     = vif.rs_alloc_Vj;
            tr.rs_alloc_Vk     = vif.rs_alloc_Vk;
            tr.rs_alloc_Qj     = vif.rs_alloc_Qj;
            tr.rs_alloc_Qk     = vif.rs_alloc_Qk;
            tr.rs_alloc_dest   = vif.rs_alloc_dest;

            tr.stall_frontend  = vif.stall_frontend;

            ap.write(tr);

        end

    endtask

endclass



// ============================================================================
// 7. SCOREBOARD
// ============================================================================

class tomasulo_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tomasulo_scoreboard)

    uvm_analysis_imp #(tomasulo_seq_item,
                       tomasulo_scoreboard) ap_imp;


    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;

    localparam logic [3:0] TAG_NONE  = 4'd0;


    int total_transactions;
    int total_errors;


    function new(string name, uvm_component parent);

        super.new(name, parent);

        ap_imp = new("ap_imp", this);

        total_transactions = 0;
        total_errors       = 0;

    endfunction


    // ------------------------------------------------------------------------
    // Resolve operand 1 exactly as tomasulo_core does.
    // ------------------------------------------------------------------------

    function automatic void expected_operand1(
        input  tomasulo_seq_item tr,
        output logic [31:0] exp_v,
        output logic [3:0]  exp_q
    );

        if (tr.dec_opcode == OPC_LUI) begin

            exp_v = 32'd0;
            exp_q = TAG_NONE;

        end

        else if (tr.dec_opcode == OPC_AUIPC) begin

            exp_v = tr.dec_pc;
            exp_q = TAG_NONE;

        end

        else if (tr.dec_rs1 == 5'd0) begin

            exp_v = 32'd0;
            exp_q = TAG_NONE;

        end

        else if (tr.rat_tag1 == TAG_NONE) begin

            exp_v = tr.arf_data1;
            exp_q = TAG_NONE;

        end

        else if (tr.cdb_valid &&
                 (tr.cdb_tag == tr.rat_tag1)) begin

            exp_v = tr.cdb_data;
            exp_q = TAG_NONE;

        end

        else begin

            exp_v = 32'd0;
            exp_q = tr.rat_tag1;

        end

    endfunction


    // ------------------------------------------------------------------------
    // Resolve operand 2 exactly as tomasulo_core does.
    // ------------------------------------------------------------------------

    function automatic void expected_operand2(
        input tomasulo_seq_item tr,
        output logic [31:0] exp_v,
        output logic [3:0]  exp_q
    );

        if (tr.dec_opcode == OPC_R) begin

            if (tr.dec_rs2 == 5'd0) begin

                exp_v = 32'd0;
                exp_q = TAG_NONE;

            end

            else if (tr.rat_tag2 == TAG_NONE) begin

                exp_v = tr.arf_data2;
                exp_q = TAG_NONE;

            end

            else if (tr.cdb_valid &&
                     (tr.cdb_tag == tr.rat_tag2)) begin

                exp_v = tr.cdb_data;
                exp_q = TAG_NONE;

            end

            else begin

                exp_v = 32'd0;
                exp_q = tr.rat_tag2;

            end

        end

        else begin

            exp_v = tr.dec_imm;
            exp_q = TAG_NONE;

        end

    endfunction


    // ------------------------------------------------------------------------
    // SCOREBOARD CHECK
    // ------------------------------------------------------------------------

    function void write(tomasulo_seq_item tr);

        logic        issuable;
        logic        expected_stall;
        logic        expected_alloc;

        logic [31:0] expected_Vj;
        logic [31:0] expected_Vk;

        logic [3:0]  expected_Qj;
        logic [3:0]  expected_Qk;


        total_transactions++;


        // --------------------------------------------------------------------
        // Expected issue qualification
        // --------------------------------------------------------------------

        issuable = tr.dec_valid &&
                   tr.dec_supported &&
                   (tr.dec_rd != 5'd0);


        expected_alloc =
            issuable && tr.rs_has_free;


        expected_stall =
            issuable && !tr.rs_has_free;


        // --------------------------------------------------------------------
        // RAT lookup addresses
        // --------------------------------------------------------------------

        if (tr.rat_lookup_reg1 !== tr.dec_rs1) begin

            total_errors++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "RAT lookup 1 mismatch: expected=%0d got=%0d",
                    tr.dec_rs1,
                    tr.rat_lookup_reg1
                )
            );

        end


        if (tr.rat_lookup_reg2 !== tr.dec_rs2) begin

            total_errors++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "RAT lookup 2 mismatch: expected=%0d got=%0d",
                    tr.dec_rs2,
                    tr.rat_lookup_reg2
                )
            );

        end


        // --------------------------------------------------------------------
        // Stall
        // --------------------------------------------------------------------

        if (tr.stall_frontend !== expected_stall) begin

            total_errors++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "STALL mismatch: expected=%0b got=%0b | %s",
                    expected_stall,
                    tr.stall_frontend,
                    tr.convert2string()
                )
            );

        end


        // --------------------------------------------------------------------
        // Issue enable
        // --------------------------------------------------------------------

        if (tr.issue_en !== expected_alloc) begin

            total_errors++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "ISSUE_EN mismatch: expected=%0b got=%0b",
                    expected_alloc,
                    tr.issue_en
                )
            );

        end


        // --------------------------------------------------------------------
        // RS allocation enable
        // --------------------------------------------------------------------

        if (tr.rs_alloc_en !== expected_alloc) begin

            total_errors++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "RS_ALLOC_EN mismatch: expected=%0b got=%0b",
                    expected_alloc,
                    tr.rs_alloc_en
                )
            );

        end


        // --------------------------------------------------------------------
        // If instruction is allocated, check allocation bundle.
        // --------------------------------------------------------------------

        if (expected_alloc) begin

            // ---------------------------------------------------------------
            // Destination
            // ---------------------------------------------------------------

            if (tr.issue_dest !== tr.dec_rd) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "ISSUE_DEST mismatch: expected=%0d got=%0d",
                        tr.dec_rd,
                        tr.issue_dest
                    )
                );

            end


            if (tr.rs_alloc_dest !== tr.dec_rd) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "RS_ALLOC_DEST mismatch: expected=%0d got=%0d",
                        tr.dec_rd,
                        tr.rs_alloc_dest
                    )
                );

            end


            // ---------------------------------------------------------------
            // Tag
            // ---------------------------------------------------------------

            if (tr.issue_tag !== tr.rs_free_tag) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "ISSUE_TAG mismatch: expected=%0d got=%0d",
                        tr.rs_free_tag,
                        tr.issue_tag
                    )
                );

            end


            // ---------------------------------------------------------------
            // Operation
            // ---------------------------------------------------------------

            if (tr.rs_alloc_op !== tr.dec_op_name) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "RS_ALLOC_OP mismatch: expected=%0d got=%0d",
                        tr.dec_op_name,
                        tr.rs_alloc_op
                    )
                );

            end


            // ---------------------------------------------------------------
            // Operand expectations
            // ---------------------------------------------------------------

            expected_operand1(
                tr,
                expected_Vj,
                expected_Qj
            );

            expected_operand2(
                tr,
                expected_Vk,
                expected_Qk
            );


            // ---------------------------------------------------------------
            // Operand J
            // ---------------------------------------------------------------

            if ((tr.rs_alloc_Vj !== expected_Vj) ||
                (tr.rs_alloc_Qj !== expected_Qj)) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "Operand J mismatch: "
                        "expected V=%08h Q=%0d, "
                        "got V=%08h Q=%0d",
                        expected_Vj,
                        expected_Qj,
                        tr.rs_alloc_Vj,
                        tr.rs_alloc_Qj
                    )
                );

            end


            // ---------------------------------------------------------------
            // Operand K
            // ---------------------------------------------------------------

            if ((tr.rs_alloc_Vk !== expected_Vk) ||
                (tr.rs_alloc_Qk !== expected_Qk)) begin

                total_errors++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "Operand K mismatch: "
                        "expected V=%08h Q=%0d, "
                        "got V=%08h Q=%0d",
                        expected_Vk,
                        expected_Qk,
                        tr.rs_alloc_Vk,
                        tr.rs_alloc_Qk
                    )
                );

            end

        end


        // --------------------------------------------------------------------
        // Helpful transaction log
        // --------------------------------------------------------------------

        `uvm_info(
            "SCB",
            $sformatf(
                "Checked: alloc=%0b stall=%0b | "
                "Vj=%08h Qj=%0d | "
                "Vk=%08h Qk=%0d",
                tr.rs_alloc_en,
                tr.stall_frontend,
                tr.rs_alloc_Vj,
                tr.rs_alloc_Qj,
                tr.rs_alloc_Vk,
                tr.rs_alloc_Qk
            ),
            UVM_HIGH
        );

    endfunction


    // ------------------------------------------------------------------------
    // Final report
    // ------------------------------------------------------------------------

    function void report_phase(uvm_phase phase);

        `uvm_info(
            "SCB",
            $sformatf(
                "==================================================\n"
                " Tomasulo Core Verification Summary\n"
                " Transactions checked : %0d\n"
                " Errors                : %0d\n"
                "==================================================",
                total_transactions,
                total_errors
            ),
            UVM_NONE
        );


        if (total_errors == 0) begin

            `uvm_info(
                "SCB",
                "TOMASULO CORE TEST PASSED",
                UVM_NONE
            );

        end

        else begin

            `uvm_error(
                "SCB",
                "TOMASULO CORE TEST FAILED"
            );

        end

    endfunction

endclass



// ============================================================================
// 8. AGENT
// ============================================================================

class tomasulo_agent extends uvm_agent;

    `uvm_component_utils(tomasulo_agent)

    tomasulo_sequencer sqr;
    tomasulo_driver    drv;
    tomasulo_monitor   mon;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        sqr = tomasulo_sequencer::type_id::create(
            "sqr",
            this
        );

        drv = tomasulo_driver::type_id::create(
            "drv",
            this
        );

        mon = tomasulo_monitor::type_id::create(
            "mon",
            this
        );

    endfunction


    function void connect_phase(uvm_phase phase);

        // --------------------------------------------------------------------
        // ONLY this connection between sequencer and driver.
        // --------------------------------------------------------------------

        drv.seq_item_port.connect(
            sqr.seq_item_export
        );

        // --------------------------------------------------------------------
        // IMPORTANT:
        //
        // DO NOT DO THIS:
        //
        // mon.ap.connect(sqr.seq_item_export);
        //
        // The monitor's analysis port is not compatible with the sequencer's
        // seq_item_export.
        // --------------------------------------------------------------------

    endfunction

endclass



// ============================================================================
// 9. ENVIRONMENT
// ============================================================================

class tomasulo_env extends uvm_env;

    `uvm_component_utils(tomasulo_env)

    tomasulo_agent      agent;
    tomasulo_scoreboard scb;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        agent = tomasulo_agent::type_id::create(
            "agent",
            this
        );

        scb = tomasulo_scoreboard::type_id::create(
            "scb",
            this
        );

    endfunction


    function void connect_phase(uvm_phase phase);

        // Monitor -> Scoreboard
        agent.mon.ap.connect(
            scb.ap_imp
        );

    endfunction

endclass



// ============================================================================
// 10. TEST
// ============================================================================

class tomasulo_test extends uvm_test;

    `uvm_component_utils(tomasulo_test)

    tomasulo_env      env;
    tomasulo_sequence seq;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        env = tomasulo_env::type_id::create(
            "env",
            this
        );

    endfunction


    task run_phase(uvm_phase phase);

        phase.raise_objection(this);


        `uvm_info(
            "TEST",
            "Starting tomasulo_core verification",
            UVM_LOW
        );


        seq = tomasulo_sequence::type_id::create(
            "seq"
        );


        seq.start(
            env.agent.sqr
        );


        // Give monitor/scoreboard time to process final transaction.
        #20;


        `uvm_info(
            "TEST",
            "Tomasulo core verification complete",
            UVM_LOW
        );


        phase.drop_objection(this);

    endtask

endclass



// ============================================================================
// 11. TOP LEVEL
// ============================================================================

module tb_top;

    logic clk;


    // ------------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // Interface
    // ------------------------------------------------------------------------

    tomasulo_core_if vif(clk);


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    tomasulo_core dut (

        .clk            (vif.clk),
        .reset          (vif.reset),

        .dec_valid      (vif.dec_valid),
        .dec_supported  (vif.dec_supported),
        .dec_pc         (vif.dec_pc),
        .dec_opcode     (vif.dec_opcode),
        .dec_rd         (vif.dec_rd),
        .dec_rs1        (vif.dec_rs1),
        .dec_rs2        (vif.dec_rs2),
        .dec_funct3     (vif.dec_funct3),
        .dec_funct7     (vif.dec_funct7),
        .dec_imm        (vif.dec_imm),
        .dec_op_name    (vif.dec_op_name),

        .rat_lookup_reg1(vif.rat_lookup_reg1),
        .rat_lookup_reg2(vif.rat_lookup_reg2),

        .rat_tag1       (vif.rat_tag1),
        .rat_tag2       (vif.rat_tag2),

        .issue_en       (vif.issue_en),
        .issue_dest     (vif.issue_dest),
        .issue_tag      (vif.issue_tag),

        .arf_data1      (vif.arf_data1),
        .arf_data2      (vif.arf_data2),

        .rs_has_free    (vif.rs_has_free),
        .rs_free_tag    (vif.rs_free_tag),

        .rs_alloc_en    (vif.rs_alloc_en),
        .rs_alloc_op    (vif.rs_alloc_op),
        .rs_alloc_Vj    (vif.rs_alloc_Vj),
        .rs_alloc_Vk    (vif.rs_alloc_Vk),
        .rs_alloc_Qj    (vif.rs_alloc_Qj),
        .rs_alloc_Qk    (vif.rs_alloc_Qk),
        .rs_alloc_dest  (vif.rs_alloc_dest),

        .cdb_valid      (vif.cdb_valid),
        .cdb_tag        (vif.cdb_tag),
        .cdb_data       (vif.cdb_data),

        .stall_frontend (vif.stall_frontend)

    );


    // ------------------------------------------------------------------------
    // Initial values
    // ------------------------------------------------------------------------

    initial begin

        vif.reset         = 1'b1;

        vif.dec_valid     = 1'b0;
        vif.dec_supported = 1'b0;
        vif.dec_pc        = 32'd0;
        vif.dec_opcode    = 7'd0;
        vif.dec_rd        = 5'd0;
        vif.dec_rs1       = 5'd0;
        vif.dec_rs2       = 5'd0;
        vif.dec_funct3    = 3'd0;
        vif.dec_funct7    = 7'd0;
        vif.dec_imm       = 32'd0;
        vif.dec_op_name   = 4'd15;

        vif.rat_tag1      = 4'd0;
        vif.rat_tag2      = 4'd0;

        vif.arf_data1     = 32'd0;
        vif.arf_data2     = 32'd0;

        vif.rs_has_free   = 1'b1;
        vif.rs_free_tag   = 4'd1;

        vif.cdb_valid     = 1'b0;
        vif.cdb_tag       = 4'd0;
        vif.cdb_data      = 32'd0;


        // tomasulo_core is combinational, so reset is not functionally needed,
        // but keep it asserted briefly for a clean testbench startup.
        repeat (2)
            @(posedge clk);

        vif.reset = 1'b0;

    end


    // ------------------------------------------------------------------------
    // UVM configuration + test
    // ------------------------------------------------------------------------

    initial begin

        uvm_config_db#(virtual tomasulo_core_if)::set(
            null,
            "*",
            "vif",
            vif
        );

        run_test("tomasulo_test");

    end

endmodule