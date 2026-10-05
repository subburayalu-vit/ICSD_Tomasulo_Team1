module tomasulo_core (
    input  logic        clk,
    input  logic        reset,

    // ------------------------------------------------------------
    // Decoded instruction from frontend
    // ------------------------------------------------------------
    input  logic        dec_valid,
    input  logic        dec_supported,
    input  logic [31:0] dec_pc,
    input  logic [6:0]  dec_opcode,
    input  logic [4:0]  dec_rd,
    input  logic [4:0]  dec_rs1,
    input  logic [4:0]  dec_rs2,
    input  logic [2:0]  dec_funct3,
    input  logic [6:0]  dec_funct7,
    input  logic [31:0] dec_imm,
    input  logic [3:0]  dec_op_name,

    // ------------------------------------------------------------
    // RAT
    // ------------------------------------------------------------
    output logic [4:0]  rat_lookup_reg1,
    output logic [4:0]  rat_lookup_reg2,

    input  logic [3:0]  rat_tag1,
    input  logic [3:0]  rat_tag2,

    output logic        issue_en,
    output logic [4:0]  issue_dest,
    output logic [3:0]  issue_tag,

    // ------------------------------------------------------------
    // ARF
    // ------------------------------------------------------------
    input  logic [31:0] arf_data1,
    input  logic [31:0] arf_data2,

    // ------------------------------------------------------------
    // Reservation Station
    // ------------------------------------------------------------
    input  logic        rs_has_free,
    input  logic [3:0]  rs_free_tag,

    output logic        rs_alloc_en,
    output logic [3:0]  rs_alloc_op,
    output logic [31:0] rs_alloc_Vj,
    output logic [31:0] rs_alloc_Vk,
    output logic [3:0]  rs_alloc_Qj,
    output logic [3:0]  rs_alloc_Qk,
    output logic [4:0]  rs_alloc_dest,

    // ------------------------------------------------------------
    // CDB
    // ------------------------------------------------------------
    input  logic        cdb_valid,
    input  logic [3:0]  cdb_tag,
    input  logic [31:0] cdb_data,

    // ------------------------------------------------------------
    // Frontend
    // ------------------------------------------------------------
    output logic        stall_frontend
);

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_I_ALU = 7'b0010011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;

    localparam logic [3:0] TAG_NONE  = 4'd0;

    logic issuable;
    logic allocate;

    // ============================================================
    // Issue qualification
    // ============================================================

    assign issuable = dec_valid &&
                      dec_supported &&
                      (dec_rd != 5'd0);

    assign allocate = issuable && rs_has_free;

    // ============================================================
    // Frontend stall
    // ============================================================

    assign stall_frontend = issuable && !rs_has_free;

    // ============================================================
    // RAT / ARF lookup addresses
    // ============================================================

    assign rat_lookup_reg1 = dec_rs1;
    assign rat_lookup_reg2 = dec_rs2;

    // ============================================================
    // Issue / RAT update
    // ============================================================

    assign issue_en   = allocate;
    assign issue_dest = dec_rd;
    assign issue_tag  = allocate ? rs_free_tag : TAG_NONE;

    // ============================================================
    // RS allocation
    // ============================================================

    assign rs_alloc_en   = allocate;
    assign rs_alloc_op   = dec_op_name;
    assign rs_alloc_dest = dec_rd;

    // ============================================================
    // Operand resolution
    //
    // Priority:
    //   1. Special instruction behavior
    //   2. x0
    //   3. RAT says value is ready
    //   4. Same-cycle CDB bypass
    //   5. Wait for producer tag
    // ============================================================

    always_comb begin

        // -------------------------
        // Defaults
        // -------------------------
        rs_alloc_Vj = 32'd0;
        rs_alloc_Qj = TAG_NONE;
        rs_alloc_Vk = 32'd0;
        rs_alloc_Qk = TAG_NONE;

        // ========================================================
        // Operand J
        // ========================================================

        case (dec_opcode)

            // LUI: result = 0 + imm
            OPC_LUI: begin
                rs_alloc_Vj = 32'd0;
                rs_alloc_Qj = TAG_NONE;
            end

            // AUIPC: result = PC + imm
            OPC_AUIPC: begin
                rs_alloc_Vj = dec_pc;
                rs_alloc_Qj = TAG_NONE;
            end

            // Normal register operand
            default: begin
                if (dec_rs1 == 5'd0) begin
                    rs_alloc_Vj = 32'd0;
                    rs_alloc_Qj = TAG_NONE;
                end
                else if (rat_tag1 == TAG_NONE) begin
                    rs_alloc_Vj = arf_data1;
                    rs_alloc_Qj = TAG_NONE;
                end
                else if (cdb_valid && (cdb_tag == rat_tag1)) begin
                    rs_alloc_Vj = cdb_data;
                    rs_alloc_Qj = TAG_NONE;
                end
                else begin
                    rs_alloc_Vj = 32'd0;
                    rs_alloc_Qj = rat_tag1;
                end
            end

        endcase

        // ========================================================
        // Operand K
        // ========================================================

        case (dec_opcode)

            // R-type uses rs2
            OPC_R: begin
                if (dec_rs2 == 5'd0) begin
                    rs_alloc_Vk = 32'd0;
                    rs_alloc_Qk = TAG_NONE;
                end
                else if (rat_tag2 == TAG_NONE) begin
                    rs_alloc_Vk = arf_data2;
                    rs_alloc_Qk = TAG_NONE;
                end
                else if (cdb_valid && (cdb_tag == rat_tag2)) begin
                    rs_alloc_Vk = cdb_data;
                    rs_alloc_Qk = TAG_NONE;
                end
                else begin
                    rs_alloc_Vk = 32'd0;
                    rs_alloc_Qk = rat_tag2;
                end
            end

            // I-type ALU, LUI, AUIPC use immediate
            OPC_I_ALU,
            OPC_LUI,
            OPC_AUIPC: begin
                rs_alloc_Vk = dec_imm;
                rs_alloc_Qk = TAG_NONE;
            end

            // Unsupported opcode should never allocate
            default: begin
                rs_alloc_Vk = 32'd0;
                rs_alloc_Qk = TAG_NONE;
            end

        endcase

    end

endmodule