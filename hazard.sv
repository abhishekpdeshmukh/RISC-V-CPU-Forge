// Hazard Detection Unit Module
// Enhanced Hazard Detection for All RAW Hazards
module HazardDetectionUnit (
    input  logic         clk,
    input  logic         reset,
    // IDs and control signals of instructions in different stages
    input  logic [4:0]   id_ex_rd,
    input  logic         id_ex_mem_read, // Indicates if ID/EX stage instruction is a load
    input  logic [4:0]   if_id_rs1,
    input  logic [4:0]   if_id_rs2,
    input  logic [4:0]   ex_mem_rd,      // Destination register in EX/MEM stage
    input  logic         ex_mem_reg_write, // Indicates if EX/MEM stage instruction writes to a register
    input  logic [4:0]   mem_wb_rd,      // Destination register in MEM/WB stage
    input  logic         mem_wb_reg_write, // Indicates if MEM/WB stage instruction writes to a register
    input  logic         branch_taken_ex, // Indicates if a branch is taken in EX stage
    // Output control signals
    output logic         stall_if_id,
    output logic         stall_pc,
    output logic         flush_if_id,
    output logic         flush_id_ex
);

    always_comb begin
        // Default control signals
        stall_if_id   = 1'b0;
        stall_pc      = 1'b0;
        flush_if_id   = 1'b0;
        flush_id_ex   = 1'b0;

        // Load-Use Hazard Detection
        if (id_ex_mem_read && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            // Stall the pipeline
            stall_if_id = 1'b1;
            stall_pc    = 1'b1;
            flush_id_ex = 1'b1; // Insert a bubble in ID/EX stage
            $display("Detected Load-Use hazard: id_ex_rd=%d, if_id_rs1=%d, if_id_rs2=%d", id_ex_rd, if_id_rs1, if_id_rs2);
        end

        // RAW Hazard Detection - forwarding is not implemented
        else if (
            (ex_mem_reg_write && (ex_mem_rd == if_id_rs1 || ex_mem_rd == if_id_rs2)) ||
            (mem_wb_reg_write && (mem_wb_rd == if_id_rs1 || mem_wb_rd == if_id_rs2))
        ) begin
            // Stall the pipeline
            stall_if_id = 1'b1;
            stall_pc    = 1'b1;
            flush_id_ex = 1'b1; // Insert a bubble in ID/EX stage
            $display("Detected RAW hazard: ex_mem_rd=%d or mem_wb_rd=%d matches if_id_rs1=%d or if_id_rs2=%d",
                     ex_mem_rd, mem_wb_rd, if_id_rs1, if_id_rs2);
        end

        // Control Hazard Detection (Branch or Jump Taken)
        if (branch_taken_ex) begin
            // Flush instructions in IF/ID and ID/EX pipeline registers
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
            $display("Detected control hazard");
        end
    end

endmodule

