`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// ================================================================
// 1. CDB INTERFACE
// ================================================================

interface cdb_if(input logic clk);

    logic reset;

    // ---------------- FU1 ----------------
    logic        fu1_valid;
    logic [3:0]  fu1_tag;
    logic [31:0] fu1_data;
    logic [4:0]  fu1_dest;

    // ---------------- FU2 ----------------
    logic        fu2_valid;
    logic [3:0]  fu2_tag;
    logic [31:0] fu2_data;
    logic [4:0]  fu2_dest;

    // ---------------- FU3 ----------------
    logic        fu3_valid;
    logic [3:0]  fu3_tag;
    logic [31:0] fu3_data;
    logic [4:0]  fu3_dest;

    // ---------------- CDB OUTPUT ----------------
    logic        cdb_valid;
    logic [3:0]  cdb_tag;
    logic [31:0] cdb_data;
    logic [4:0]  cdb_dest;

endinterface

// ================================================================
// 2. TRANSACTION
// ================================================================

class cdb_transaction extends uvm_sequence_item;

    // FU1 input
    rand bit        fu1_valid;
    rand bit [3:0]  fu1_tag;
    rand bit [31:0] fu1_data;
    rand bit [4:0]  fu1_dest;

    // FU2 input
    rand bit        fu2_valid;
    rand bit [3:0]  fu2_tag;
    rand bit [31:0] fu2_data;
    rand bit [4:0]  fu2_dest;

    // FU3 input
    rand bit        fu3_valid;
    rand bit [3:0]  fu3_tag;
    rand bit [31:0] fu3_data;
    rand bit [4:0]  fu3_dest;

    // DUT output observed by monitor
    bit        cdb_valid;
    bit [3:0]  cdb_tag;
    bit [31:0] cdb_data;
    bit [4:0]  cdb_dest;

    `uvm_object_utils(cdb_transaction)

    function new(string name = "cdb_transaction");
        super.new(name);
    endfunction

endclass


// ================================================================
// 3. DRIVER
// ================================================================

class cdb_driver extends uvm_driver #(cdb_transaction);

    `uvm_component_utils(cdb_driver)

    virtual cdb_if vif;

    function new(
        string name = "cdb_driver",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual cdb_if)::get(
                this,
                "",
                "vif",
                vif
            )) begin

            `uvm_fatal(
                "CDB_DRIVER",
                "Could not get CDB virtual interface"
            )

        end

    endfunction


    task run_phase(uvm_phase phase);

        cdb_transaction tr;

        forever begin

            seq_item_port.get_next_item(tr);

            // Drive before the next positive edge.
            // This avoids a race with the DUT/monitor.

            @(negedge vif.clk);

            vif.fu1_valid <= tr.fu1_valid;
            vif.fu1_tag   <= tr.fu1_tag;
            vif.fu1_data  <= tr.fu1_data;
            vif.fu1_dest  <= tr.fu1_dest;

            vif.fu2_valid <= tr.fu2_valid;
            vif.fu2_tag   <= tr.fu2_tag;
            vif.fu2_data  <= tr.fu2_data;
            vif.fu2_dest  <= tr.fu2_dest;

            vif.fu3_valid <= tr.fu3_valid;
            vif.fu3_tag   <= tr.fu3_tag;
            vif.fu3_data  <= tr.fu3_data;
            vif.fu3_dest  <= tr.fu3_dest;

            seq_item_port.item_done();

        end

    endtask

endclass


// ================================================================
// 4. MONITOR
// ================================================================

class cdb_monitor extends uvm_monitor;

    `uvm_component_utils(cdb_monitor)

    virtual cdb_if vif;

    uvm_analysis_port #(cdb_transaction) analysis_port;


    function new(
        string name = "cdb_monitor",
        uvm_component parent = null
    );

        super.new(name, parent);

        analysis_port =
            new("analysis_port", this);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual cdb_if)::get(
                this,
                "",
                "vif",
                vif
            )) begin

            `uvm_fatal(
                "CDB_MONITOR",
                "Could not get CDB virtual interface"
            )

        end

    endfunction


    task run_phase(uvm_phase phase);

        cdb_transaction tr;

        forever begin

            @(posedge vif.clk);

            // Allow combinational CDB output to settle.
            #1;

            tr =
                cdb_transaction::type_id::create("tr");

            // Capture FU inputs
            tr.fu1_valid = vif.fu1_valid;
            tr.fu1_tag   = vif.fu1_tag;
            tr.fu1_data  = vif.fu1_data;
            tr.fu1_dest  = vif.fu1_dest;

            tr.fu2_valid = vif.fu2_valid;
            tr.fu2_tag   = vif.fu2_tag;
            tr.fu2_data  = vif.fu2_data;
            tr.fu2_dest  = vif.fu2_dest;

            tr.fu3_valid = vif.fu3_valid;
            tr.fu3_tag   = vif.fu3_tag;
            tr.fu3_data  = vif.fu3_data;
            tr.fu3_dest  = vif.fu3_dest;

            // Capture CDB outputs
            tr.cdb_valid = vif.cdb_valid;
            tr.cdb_tag   = vif.cdb_tag;
            tr.cdb_data  = vif.cdb_data;
            tr.cdb_dest  = vif.cdb_dest;

            analysis_port.write(tr);

        end

    endtask

endclass


// ================================================================
// 5. AGENT
// ================================================================

class cdb_agent extends uvm_agent;

    `uvm_component_utils(cdb_agent)

    uvm_sequencer #(cdb_transaction) sequencer;

    cdb_driver  driver;
    cdb_monitor monitor;


    function new(
        string name = "cdb_agent",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        sequencer =
            uvm_sequencer#(cdb_transaction)::type_id::create(
                "sequencer",
                this
            );

        driver =
            cdb_driver::type_id::create(
                "driver",
                this
            );

        monitor =
            cdb_monitor::type_id::create(
                "monitor",
                this
            );

    endfunction


    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        driver.seq_item_port.connect(
            sequencer.seq_item_export
        );

    endfunction

endclass


// ================================================================
// 6. SEQUENCE
// ================================================================

class cdb_sequence extends uvm_sequence #(cdb_transaction);

    `uvm_object_utils(cdb_sequence)


    function new(string name = "cdb_sequence");

        super.new(name);

    endfunction


    task send_transaction(
        bit        v1,
        bit [3:0]  t1,
        bit [31:0] d1,
        bit [4:0]  r1,

        bit        v2,
        bit [3:0]  t2,
        bit [31:0] d2,
        bit [4:0]  r2,

        bit        v3,
        bit [3:0]  t3,
        bit [31:0] d3,
        bit [4:0]  r3
    );

        cdb_transaction tr;

        tr =
            cdb_transaction::type_id::create("tr");

        start_item(tr);

        tr.fu1_valid = v1;
        tr.fu1_tag   = t1;
        tr.fu1_data  = d1;
        tr.fu1_dest  = r1;

        tr.fu2_valid = v2;
        tr.fu2_tag   = t2;
        tr.fu2_data  = d2;
        tr.fu2_dest  = r2;

        tr.fu3_valid = v3;
        tr.fu3_tag   = t3;
        tr.fu3_data  = d3;
        tr.fu3_dest  = r3;

        finish_item(tr);

    endtask


    task body();

        // ========================================================
        // TEST 1
        // No FU valid
        // Expected: cdb_valid = 0
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 1: No FU valid",
            UVM_MEDIUM
        )

        send_transaction(
            0, 4'd1, 32'h11111111, 5'd8,
            0, 4'd2, 32'h22222222, 5'd9,
            0, 4'd3, 32'h33333333, 5'd10
        );


        // ========================================================
        // TEST 2
        // FU1 only
        // Expected: FU1
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 2: FU1 only",
            UVM_MEDIUM
        )

        send_transaction(
            1, 4'd1, 32'h11111111, 5'd8,
            0, 4'd2, 32'h22222222, 5'd9,
            0, 4'd3, 32'h33333333, 5'd10
        );


        // ========================================================
        // TEST 3
        // FU2 only
        // Expected: FU2
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 3: FU2 only",
            UVM_MEDIUM
        )

        send_transaction(
            0, 4'd1, 32'h11111111, 5'd8,
            1, 4'd2, 32'h22222222, 5'd9,
            0, 4'd3, 32'h33333333, 5'd10
        );


        // ========================================================
        // TEST 4
        // FU3 only
        // Expected: FU3
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 4: FU3 only",
            UVM_MEDIUM
        )

        send_transaction(
            0, 4'd1, 32'h11111111, 5'd8,
            0, 4'd2, 32'h22222222, 5'd9,
            1, 4'd3, 32'h33333333, 5'd10
        );


        // ========================================================
        // TEST 5
        // FU1 + FU2
        // Expected: FU1
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 5: FU1 + FU2 -> FU1 must win",
            UVM_MEDIUM
        )

        send_transaction(
            1, 4'd1, 32'hAAAA0001, 5'd11,
            1, 4'd2, 32'hBBBB0002, 5'd12,
            0, 4'd3, 32'hCCCC0003, 5'd13
        );


        // ========================================================
        // TEST 6
        // FU1 + FU3
        // Expected: FU1
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 6: FU1 + FU3 -> FU1 must win",
            UVM_MEDIUM
        )

        send_transaction(
            1, 4'd1, 32'hAAAA0011, 5'd14,
            0, 4'd2, 32'hBBBB0022, 5'd15,
            1, 4'd3, 32'hCCCC0033, 5'd16
        );


        // ========================================================
        // TEST 7
        // FU2 + FU3
        // Expected: FU2
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 7: FU2 + FU3 -> FU2 must win",
            UVM_MEDIUM
        )

        send_transaction(
            0, 4'd1, 32'hAAAA0011, 5'd17,
            1, 4'd2, 32'hBBBB0022, 5'd18,
            1, 4'd3, 32'hCCCC0033, 5'd19
        );


        // ========================================================
        // TEST 8
        // FU1 + FU2 + FU3
        // Expected: FU1
        // ========================================================

        `uvm_info(
            "CDB_SEQ",
            "TEST 8: ALL THREE -> FU1 must win",
            UVM_MEDIUM
        )

        send_transaction(
            1, 4'd1, 32'hDEAD0001, 5'd20,
            1, 4'd2, 32'hDEAD0002, 5'd21,
            1, 4'd3, 32'hDEAD0003, 5'd22
        );


        `uvm_info(
            "CDB_SEQ",
            "All CDB directed tests sent",
            UVM_MEDIUM
        )

    endtask

endclass


// ================================================================
// 7. SCOREBOARD
// ================================================================

class cdb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(cdb_scoreboard)

    uvm_analysis_imp #(cdb_transaction, cdb_scoreboard)
        analysis_port;


    function new(
        string name = "cdb_scoreboard",
        uvm_component parent = null
    );

        super.new(name, parent);

        analysis_port =
            new("analysis_port", this);

    endfunction


    function void write(cdb_transaction tr);

        bit        expected_valid;
        bit [3:0]  expected_tag;
        bit [31:0] expected_data;
        bit [4:0]  expected_dest;

        // Default output
        expected_valid = 1'b0;
        expected_tag   = 4'd0;
        expected_data  = 32'd0;
        expected_dest  = 5'd0;


        // ========================================================
        // CDB fixed-priority arbitration
        //
        // FU1 > FU2 > FU3
        // ========================================================

        if (tr.fu1_valid) begin

            expected_valid = 1'b1;
            expected_tag   = tr.fu1_tag;
            expected_data  = tr.fu1_data;
            expected_dest  = tr.fu1_dest;

        end

        else if (tr.fu2_valid) begin

            expected_valid = 1'b1;
            expected_tag   = tr.fu2_tag;
            expected_data  = tr.fu2_data;
            expected_dest  = tr.fu2_dest;

        end

        else if (tr.fu3_valid) begin

            expected_valid = 1'b1;
            expected_tag   = tr.fu3_tag;
            expected_data  = tr.fu3_data;
            expected_dest  = tr.fu3_dest;

        end


        // ========================================================
        // Check VALID
        // ========================================================

        if (tr.cdb_valid !== expected_valid) begin

            `uvm_error(
                "CDB_SB",
                $sformatf(
                    "VALID ERROR: expected=%0d actual=%0d",
                    expected_valid,
                    tr.cdb_valid
                )
            )

        end


        // ========================================================
        // Check TAG
        // ========================================================

        if (tr.cdb_tag !== expected_tag) begin

            `uvm_error(
                "CDB_SB",
                $sformatf(
                    "TAG ERROR: expected=%0d actual=%0d",
                    expected_tag,
                    tr.cdb_tag
                )
            )

        end


        // ========================================================
        // Check DATA
        // ========================================================

        if (tr.cdb_data !== expected_data) begin

            `uvm_error(
                "CDB_SB",
                $sformatf(
                    "DATA ERROR: expected=%08h actual=%08h",
                    expected_data,
                    tr.cdb_data
                )
            )

        end


        // ========================================================
        // Check DEST
        // ========================================================

        if (tr.cdb_dest !== expected_dest) begin

            `uvm_error(
                "CDB_SB",
                $sformatf(
                    "DEST ERROR: expected=%0d actual=%0d",
                    expected_dest,
                    tr.cdb_dest
                )
            )

        end


        // ========================================================
        // PASS MESSAGE
        // ========================================================

        if ((tr.cdb_valid === expected_valid) &&
            (tr.cdb_tag   === expected_tag)   &&
            (tr.cdb_data  === expected_data)  &&
            (tr.cdb_dest  === expected_dest)) begin

            `uvm_info(
                "CDB_SB",
                $sformatf(
                    "PASS: valid=%0d tag=%0d data=%08h dest=%0d",
                    tr.cdb_valid,
                    tr.cdb_tag,
                    tr.cdb_data,
                    tr.cdb_dest
                ),
                UVM_MEDIUM
            )

        end

    endfunction

endclass


// ================================================================
// 8. ENVIRONMENT
// ================================================================

class cdb_env extends uvm_env;

    `uvm_component_utils(cdb_env)

    cdb_agent      agent;
    cdb_scoreboard scoreboard;


    function new(
        string name = "cdb_env",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        agent =
            cdb_agent::type_id::create(
                "agent",
                this
            );

        scoreboard =
            cdb_scoreboard::type_id::create(
                "scoreboard",
                this
            );

    endfunction


    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        agent.monitor.analysis_port.connect(
            scoreboard.analysis_port
        );

    endfunction

endclass


// ================================================================
// 9. TEST
// ================================================================

class cdb_test extends uvm_test;

    `uvm_component_utils(cdb_test)

    cdb_env env;


    function new(
        string name = "cdb_test",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        env =
            cdb_env::type_id::create(
                "env",
                this
            );

    endfunction


    task run_phase(uvm_phase phase);

        cdb_sequence seq;

        phase.raise_objection(this);

        `uvm_info(
            "CDB_TEST",
            "Starting CDB UVM test",
            UVM_LOW
        )

        seq =
            cdb_sequence::type_id::create(
                "seq"
            );

        seq.start(
            env.agent.sequencer
        );

        // Allow final transaction to be observed
        #20;

        `uvm_info(
            "CDB_TEST",
            "CDB UVM test completed",
            UVM_LOW
        )

        phase.drop_objection(this);

    endtask

endclass


// ================================================================
// 10. TOP-LEVEL TESTBENCH
// ================================================================

module cdb_tb_top;

    logic clk;

    // CDB interface
    cdb_if vif(clk);


    // ============================================================
    // DUT
    // ============================================================

    cdb dut (

        .clk       (clk),
        .reset     (vif.reset),

        // FU1
        .fu1_valid (vif.fu1_valid),
        .fu1_tag   (vif.fu1_tag),
        .fu1_data  (vif.fu1_data),
        .fu1_dest  (vif.fu1_dest),

        // FU2
        .fu2_valid (vif.fu2_valid),
        .fu2_tag   (vif.fu2_tag),
        .fu2_data  (vif.fu2_data),
        .fu2_dest  (vif.fu2_dest),

        // FU3
        .fu3_valid (vif.fu3_valid),
        .fu3_tag   (vif.fu3_tag),
        .fu3_data  (vif.fu3_data),
        .fu3_dest  (vif.fu3_dest),

        // CDB
        .cdb_valid (vif.cdb_valid),
        .cdb_tag   (vif.cdb_tag),
        .cdb_data  (vif.cdb_data),
        .cdb_dest  (vif.cdb_dest)

    );


    // ============================================================
    // CLOCK
    // ============================================================

    initial begin

        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end

    end


    // ============================================================
    // INITIAL VALUES
    // ============================================================

    initial begin

        vif.reset = 1'b1;

        vif.fu1_valid = 1'b0;
        vif.fu1_tag   = 4'd0;
        vif.fu1_data  = 32'd0;
        vif.fu1_dest  = 5'd0;

        vif.fu2_valid = 1'b0;
        vif.fu2_tag   = 4'd0;
        vif.fu2_data  = 32'd0;
        vif.fu2_dest  = 5'd0;

        vif.fu3_valid = 1'b0;
        vif.fu3_tag   = 4'd0;
        vif.fu3_data  = 32'd0;
        vif.fu3_dest  = 5'd0;

        #20;

        vif.reset = 1'b0;

    end


    // ============================================================
    // UVM CONFIGURATION
    // ============================================================

    initial begin

        uvm_config_db#(virtual cdb_if)::set(
            null,
            "*",
            "vif",
            vif
        );

        run_test("cdb_test");

    end

endmodule