module tomasulo_core (
    input  logic        clk,
    input  logic        reset, // Unused by this purely combinational block

    // Decoded Instruction (from Frontend)
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
    input  logic [3:0]  dec_op_name, // 4-bit ALU operation

    // RAT (Register Alias Table) Interfaces
    output logic [4:0]  rat_lookup_reg1,
    output logic [4:0]  rat_lookup_reg2,
    input  logic [3:0]  rat_tag1,    // 4-bit RS Tag
    input  logic [3:0]  rat_tag2,
    output logic        issue_en,
    output logic [4:0]  issue_dest,
    output logic [3:0]  issue_tag,

    // ARF (Architectural Register File) Interfaces
    input  logic [31:0] arf_data1,
    input  logic [31:0] arf_data2,

    // Reservation Station (RS) Interfaces
    input  logic        rs_has_free,
    input  logic [3:0]  rs_free_tag,
    output logic        rs_alloc_en,
    output logic [3:0]  rs_alloc_op,
    output logic [31:0] rs_alloc_Vj,
    output logic [31:0] rs_alloc_Vk,
    output logic [3:0]  rs_alloc_Qj,
    output logic [3:0]  rs_alloc_Qk,
    output logic [4:0]  rs_alloc_dest,

    // Common Data Bus (CDB Bypass Inputs)
    input  logic        cdb_valid,
    input  logic [3:0]  cdb_tag,
    input  logic [31:0] cdb_data,

    // Frontend Controls
    output logic        stall_frontend
);

    // Local constants to replace the package
    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;
    localparam logic [3:0] TAG_NONE  = 4'd0;

    logic issuable;
    
    // An instruction is valid to issue if it exists, is in our subset, and doesn't target x0
    assign issuable = dec_valid && dec_supported && (dec_rd != 5'd0);

    // Stall frontend if we have a valid instruction but lack a free RS entry
    assign stall_frontend = issuable && !rs_has_free;

    // Drive read addresses to RAT (and implicitly ARF)
    assign rat_lookup_reg1 = dec_rs1;
    assign rat_lookup_reg2 = dec_rs2;

    // Allocation and Issue Signals
    assign rs_alloc_en   = issuable && rs_has_free;
    assign rs_alloc_op   = dec_op_name;
    assign rs_alloc_dest = dec_rd;

    assign issue_en   = rs_alloc_en;
    assign issue_dest = dec_rd;
    assign issue_tag  = rs_free_tag;

    // Operand 1 Resolution (Vj, Qj)
    always_comb begin
        if (dec_opcode == OPC_LUI) begin
            rs_alloc_Vj = 32'd0;
            rs_alloc_Qj = TAG_NONE;
        end else if (dec_opcode == OPC_AUIPC) begin
            rs_alloc_Vj = dec_pc;
            rs_alloc_Qj = TAG_NONE;
        end else if (dec_rs1 == 5'd0) begin
            rs_alloc_Vj = 32'd0;
            rs_alloc_Qj = TAG_NONE;
        end else if (rat_tag1 == TAG_NONE) begin
            rs_alloc_Vj = arf_data1;
            rs_alloc_Qj = TAG_NONE;
        end else if (cdb_valid && (cdb_tag == rat_tag1)) begin
            rs_alloc_Vj = cdb_data;   
            rs_alloc_Qj = TAG_NONE;
        end else begin
            rs_alloc_Vj = 32'd0;
            rs_alloc_Qj = rat_tag1;   
        end
    end

    // Operand 2 Resolution (Vk, Qk)
    always_comb begin
        if (dec_opcode == OPC_R) begin
            if (dec_rs2 == 5'd0) begin
                rs_alloc_Vk = 32'd0;
                rs_alloc_Qk = TAG_NONE;
            end else if (rat_tag2 == TAG_NONE) begin
                rs_alloc_Vk = arf_data2;
                rs_alloc_Qk = TAG_NONE;
            end else if (cdb_valid && (cdb_tag == rat_tag2)) begin
                rs_alloc_Vk = cdb_data;   
                rs_alloc_Qk = TAG_NONE;
            end else begin
                rs_alloc_Vk = 32'd0;
                rs_alloc_Qk = rat_tag2;   
            end
        end else begin
            rs_alloc_Vk = dec_imm;
            rs_alloc_Qk = TAG_NONE;
        end
    end

endmodule