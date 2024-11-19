`include "types.sv"

// IF_ID Pipeline Register Module
module IF_ID (
    input  logic         clk,
    input  logic         reset,
    input  logic         stall,
    input  logic         flush,
    input  logic [31:0]  instruction_in,
    input  logic [63:0]  pc_in,
    input  logic         valid_in,
    output logic [31:0]  instruction_out,
    output logic [63:0]  pc_out,
    output logic         valid_out
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            instruction_out <= 32'b0;
            pc_out          <= 64'b0;
            valid_out       <= 1'b0;
        end else if (!stall) begin
            instruction_out <= instruction_in;
            pc_out          <= pc_in;
            valid_out       <= valid_in;
        end
        // If stall is asserted, hold the current values
    end

endmodule

// ID_EX Pipeline Register Module
module ID_EX (
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 stall,
    input  logic                 flush,
    // Inputs from ID Stage
    input  decoded_inst_t        decoded_inst_in,
    input  logic [63:0]          rs1_data_in,
    input  logic [63:0]          rs2_data_in,
    input  logic [63:0]          imm_in,
    // Control signals from ID Stage
    input  logic                 alu_src_in,    // Select between rs2_data and immediate for ALU operand
    input  logic                 mem_read_in,   // Control signal for memory read
    input  logic                 mem_write_in,  // Control signal for memory write
    input  logic                 reg_write_in,  // Control signal for register write
    // Outputs to EX Stage
    output decoded_inst_t        decoded_inst_out,
    output logic [63:0]          rs1_data_out,
    output logic [63:0]          rs2_data_out,
    output logic [63:0]          imm_out,
    // Control signals to EX Stage
    output logic                 alu_src_out,
    output logic                 mem_read_out,
    output logic                 mem_write_out,
    output logic                 reg_write_out
);

    // Pipeline Register Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            decoded_inst_out <= '0;
            rs1_data_out     <= '0;
            rs2_data_out     <= '0;
            imm_out          <= '0;
            alu_src_out      <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            reg_write_out    <= 1'b0;
        end else if (!stall) begin
            decoded_inst_out <= decoded_inst_in;
            rs1_data_out     <= rs1_data_in;
            rs2_data_out     <= rs2_data_in;
            imm_out          <= imm_in;
            alu_src_out      <= alu_src_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            reg_write_out    <= reg_write_in;
            // Debugging
            // $display("ID_EX: Decoded rd=%0d, ALU Src=%0b, MEM Read=%0b, MEM Write=%0b, Reg Write=%0b",
            //         decoded_inst_in.rd, alu_src_in, mem_read_in, mem_write_in, reg_write_in);
        end
    end

endmodule

