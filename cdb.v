`timescale 1ns / 1ps
module cdb (
    input  clk,
    input  reset,
    input  fu1_valid,
    input  [3:0] fu1_tag,
    input  [31:0] fu1_data,
    input  [4:0] fu1_dest,
    input  fu2_valid,
    input  [3:0] fu2_tag,
    input  [31:0] fu2_data,
    input  [4:0] fu2_dest,
    input  fu3_valid,
    input  [3:0] fu3_tag,
    input  [31:0] fu3_data,
    input  [4:0] fu3_dest,
    output reg  cdb_valid,
    output reg  [3:0] cdb_tag,
    output reg [31:0] cdb_data,
    output reg  [4:0] cdb_dest
);
    always @(*) begin
        cdb_valid = 1'b0;
        cdb_tag   = 4'b0000;
        cdb_data  = 32'b0;
        cdb_dest  = 5'b0;  
        if (fu1_valid) begin
            cdb_valid = 1'b1;
            cdb_tag   = fu1_tag;
            cdb_data  = fu1_data;
            cdb_dest  = fu1_dest;
        end
        else if (fu2_valid) begin
            cdb_valid = 1'b1;
            cdb_tag   = fu2_tag;
            cdb_data  = fu2_data;
            cdb_dest  = fu2_dest;
        end
        else if (fu3_valid) begin
            cdb_valid = 1'b1;
            cdb_tag   = fu3_tag;
            cdb_data  = fu3_data;
            cdb_dest  = fu3_dest;
        end
    end
endmodule
