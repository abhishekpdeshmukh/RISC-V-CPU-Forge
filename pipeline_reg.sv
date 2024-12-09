`include "types.sv"

module IF_ID (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush_in,
    input  logic [31:0] instruction_in,
    input  logic [63:0] pc_in,
    input  logic        icache_valid_in,
    output logic [31:0] instruction_out,
    output logic [63:0] pc_out,
    output logic        icache_valid_out,
    output logic        flush_out
);
    always_ff @(posedge clk or posedge reset) begin

        if (reset) begin
            instruction_out        <= 32'b0;
            pc_out                 <= 64'b0;
            icache_valid_out       <= 1'b0;
            flush_out              <= 1'b1;
        end else if (enable) begin
            if (flush_in) begin
                instruction_out        <= 32'b0; 
                pc_out                 <= 1'b0;
                icache_valid_out       <= 1'b0;
                flush_out              <= 1'b1;
            end else begin
                instruction_out        <= instruction_in;
                pc_out                 <= pc_in;
                icache_valid_out       <= icache_valid_in;
                flush_out              <= 1'b0;
            end
        end
    end
endmodule

module ID_EX (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush_in,
    input  packed_inst decoded_inst_in,
    input  logic [63:0]  rs1_data_in,
    input  logic [63:0]  rs2_data_in,
    output packed_inst decoded_inst_out,
    output logic [63:0]  rs1_data_out,
    output logic [63:0]  rs2_data_out,
    output logic         flush_out
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_inst_out <= '0;
            rs1_data_out     <= '0;
            rs2_data_out     <= '0;
            flush_out          <= 1'b1;
        end else if (enable) begin
            if (flush_in) begin
                decoded_inst_out <= '0;
                rs1_data_out     <= '0;
                rs2_data_out     <= '0;
                flush_out        <= 1'b1;
            end else begin
                decoded_inst_out <= decoded_inst_in;
                rs1_data_out     <= rs1_data_in;
                rs2_data_out     <= rs2_data_in;
                flush_out        <= 1'b0;
            end
        end
    end
endmodule



module EX_MEM #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 flush_in,
    input  logic                 enable,

    input  logic [63:0]          alu_result_in,
    input  packed_inst           decoded_inst_in,
    input  logic [63:0]          store_data_in,
    input  logic                 branch_taken_in,
    input  logic [63:0]          branch_target_in,

    output logic [63:0]          alu_result_out,
    output logic                 alu_zero_out,
    output packed_inst            decoded_inst_out,
    output  logic                 branch_taken_out,
    output  logic [63:0]          branch_target_out,

    output logic [DATA_WIDTH-1:0] store_data_out,
    output logic         flush_out
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_inst_out   <= '0;
            alu_result_out     <= '0;
            store_data_out     <= '0;
            flush_out          <= 1'b1;
            branch_taken_out     <= '0;
            branch_target_out     <= '0;
        end else if (enable) begin
            if (flush_in) begin
                decoded_inst_out   <= '0;
                alu_result_out     <= '0;
                store_data_out     <= '0;
                branch_taken_out     <= '0;
                branch_target_out     <= '0;
                flush_out          <= 1'b1;
            end else begin
                decoded_inst_out   <= decoded_inst_in;
                alu_result_out     <= alu_result_in;
                store_data_out     <= store_data_in;
                branch_taken_out     <= branch_taken_in;
                branch_target_out     <= branch_target_in;
                flush_out          <= 1'b0;
            end
        end
    end
endmodule


module MEM_WB #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        flush_in,
    input  logic        enable,

    input  logic [DATA_WIDTH-1:0] mem_data_in,   
    input  logic [DATA_WIDTH-1:0] alu_result_in, 
    input  packed_inst            decoded_inst_in,
    input  logic [63:0]           store_data_in,

    output logic [DATA_WIDTH-1:0] mem_data_out,    
    output logic [DATA_WIDTH-1:0] alu_result_out,  
    output  packed_inst           decoded_inst_out,
    output logic                  flush_out,
    output logic [63:0]           store_data_out
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_inst_out   <= '0;
            mem_data_out       <= '0;
            alu_result_out     <= '0;
            store_data_out     <= '0;
            flush_out          <= 1'b1;

        end else if (enable) begin
            if (flush_in) begin
                decoded_inst_out   <= '0;
                mem_data_out       <= '0;
                alu_result_out     <= '0;
                store_data_out     <= '0;
                flush_out          <= 1'b1;
            end else begin
                decoded_inst_out   <= decoded_inst_in;
                mem_data_out       <= mem_data_in;
                alu_result_out     <= alu_result_in;
                store_data_out     <= store_data_in;
                flush_out          <= 1'b0;
            end
        end
    end

endmodule


  