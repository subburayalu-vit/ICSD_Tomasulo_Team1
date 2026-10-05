module tomasulo_core (
    input  logic        clk,
    input  logic        reset,

    // decoded_inst (Frontend)
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

    // rat_lookup_tags (from RAT)
    input  logic [3:0]  tag1,
    input  logic [3:0]  tag2,

    // arf_read_data (from ARF)
    input  logic [31:0] read_data1,
    input  logic [31:0] read_data2,

    // rs_read_data (from RS)
    input  logic        has_free,
    input  logic [3:0]  free_tag,

    // cdb inputs (from CDB)
    input  logic        cdb_valid,
    input  logic [3:0]  cdb_tag,
    input  logic [31:0] cdb_data,
    
    // rat_lookup_regs (to RAT/ARF)
    output logic [4:0]  lookup_reg1,
    output logic [4:0]  lookup_reg2,

    // rat_update (to RAT)
    output logic        issue_en,
    output logic [4:0]  issue_dest,
    output logic [3:0]  issue_tag,

    // rs_alloc_info (to RS)
    output logic        alloc_en,
    output logic [3:0]  alloc_op,
    output logic [31:0] alloc_Vj,
    output logic [31:0] alloc_Vk,
    output logic [3:0]  alloc_Qj,
    output logic [3:0]  alloc_Qk,
    output logic [4:0]  alloc_dest,

    // stall (to Frontend)
    output logic        stall_frontend
);

    localparam logic [6:0] OPC_R     = 7'b0110011;
    localparam logic [6:0] OPC_LUI   = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC = 7'b0010111;
    localparam logic [3:0] TAG_NONE  = 4'd0;

    logic issuable;
    
    // issuable = decoded_inst.valid && decoded_inst.supported && rd != 0[cite: 3]
    assign issuable = dec_valid && dec_supported && (dec_rd != 5'd0);

    // Stall: stall_frontend = issuable && !has_free[cite: 3]
    assign stall_frontend = issuable && !has_free;

    // RAT lookups[cite: 3]
    assign lookup_reg1 = dec_rs1;
    assign lookup_reg2 = dec_rs2;

    // Allocation[cite: 3]
    assign alloc_en   = issuable && has_free;
    assign alloc_op   = dec_op_name;
    assign alloc_dest = dec_rd;

    // Rename[cite: 3]
    assign issue_en   = alloc_en;
    assign issue_dest = dec_rd;
    assign issue_tag  = free_tag;

    // Operand 1 (j) resolution[cite: 3]
    always_comb begin
        if (dec_opcode == OPC_LUI) begin
            alloc_Vj = 32'd0;
            alloc_Qj = TAG_NONE;
        end else if (dec_opcode == OPC_AUIPC) begin
            alloc_Vj = dec_pc;
            alloc_Qj = TAG_NONE;
        end else if (dec_rs1 == 5'd0) begin
            alloc_Vj = 32'd0;
            alloc_Qj = TAG_NONE;
        end else if (tag1 == TAG_NONE) begin
            alloc_Vj = read_data1;
            alloc_Qj = TAG_NONE;
        end else if (cdb_valid && (cdb_tag == tag1)) begin
            alloc_Vj = cdb_data;   
            alloc_Qj = TAG_NONE;
        end else begin
            alloc_Vj = 32'd0;
            alloc_Qj = tag1;   
        end
    end

    // Operand 2 (k) resolution[cite: 3]
    always_comb begin
        if (dec_opcode == OPC_R) begin
            if (dec_rs2 == 5'd0) begin
                alloc_Vk = 32'd0;
                alloc_Qk = TAG_NONE;
            end else if (tag2 == TAG_NONE) begin
                alloc_Vk = read_data2;
                alloc_Qk = TAG_NONE;
            end else if (cdb_valid && (cdb_tag == tag2)) begin
                alloc_Vk = cdb_data;   
                alloc_Qk = TAG_NONE;
            end else begin
                alloc_Vk = 32'd0;
                alloc_Qk = tag2;   
            end
        end else begin
            alloc_Vk = dec_imm;
            alloc_Qk = TAG_NONE;
        end
    end

endmodule