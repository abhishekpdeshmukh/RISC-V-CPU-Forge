// Regfile Module: 32 x 64-bit Registers
module Regfile (
    input logic        clk,
    input logic        reset,
    input  logic [63:0] initial_sp,
    // Read Ports
    input logic [4:0]  rs1,
    input logic [4:0]  rs2,
    output logic [63:0] rd1_data,
    output logic [63:0] rd2_data,
    // Write Port
    input logic [4:0]  rd,
    input logic [63:0] rd_data,
    input logic        write_enable
);

    // Define 32 registers, x0 to x31
    logic [63:0] registers [31:0];

    // Initialize registers to 0 on reset
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 64'b0;
            end
            // Set x2 (sp) to initial_sp
            registers[2] <= initial_sp;
            $display("Regfile: Writing %h to stackptr", initial_sp);
        end else if (write_enable && rd != 5'd0) begin
            registers[rd] <= rd_data;
            //$display("Regfile: Writing %h to x%d", rd_data, rd);
        end
    end

    // Read Operations
    assign rd1_data = registers[rs1];
    assign rd2_data = registers[rs2];

    // Print Regfile contents at the end of simulation
    final begin
        $display("\n=== Final Regfile Contents ===");
        for (int i = 0; i < 32; i = i + 1) begin
            $display("x%0d : \t0x%0x", i, $signed(registers[i]));
        end
        $display("=== End of Regfile Contents ===\n");
    end

endmodule
