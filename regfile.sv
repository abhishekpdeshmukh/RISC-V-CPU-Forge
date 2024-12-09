module Regfile (
    input logic        clk,
    input logic        reset,
    input  logic [63:0] initial_sp,
    input logic [4:0]  rs1,
    input logic [4:0]  rs2,
    output logic [63:0] rd1_data,
    output logic [63:0] rd2_data,
    input logic [4:0]  rd,
    input logic [63:0] rd_data,
    input logic        write_enable,
    input logic [63:0] wb_pc,
    output [63:0] a0,
    output [63:0] a1,
    output [63:0] a2,
    output [63:0] a3,
    output [63:0] a4,
    output [63:0] a5,
    output [63:0] a6,
    output [63:0] a7
);
    logic [63:0] registers [31:0];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 64'b0;
            end
            registers[2] <= initial_sp;
        end else if (write_enable && rd != 5'd0) begin
            registers[rd] <= rd_data;
        end
    end

    assign rd1_data = registers[rs1];
    assign rd2_data = registers[rs2];
    assign a0 = registers[5'd10];
    assign a1 = registers[5'd11];
    assign a2 = registers[5'd12];
    assign a3 = registers[5'd13];
    assign a4 = registers[5'd14];
    assign a5 = registers[5'd15];
    assign a6 = registers[5'd16];
    assign a7 = registers[5'd17];

    final begin
        // $display("\n=== Final Regfile Contents ===");
        // for (int i = 0; i < 32; i = i + 1) begin
        //     $display("x%0d : \t0x%0x", i, $signed(registers[i]));
        // end
        // $display("=== End of Regfile Contents ===\n");
    end

endmodule