module RegisterFile 
(
    input  logic clk,
    input  logic rst,
    input  logic [4:0] rs1_addr,
    input  logic [4:0] rs2_addr,
    input  logic [4:0] rd_addr,
    input  logic [63:0] rd_data,
    input  logic rd_write,
    output logic [63:0] rs1_data,
    output logic [63:0] rs2_data
);

    logic [63:0] registers [32:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= '0;
            end
        end else if (rd_write && rd_addr != 0) begin
            registers[rd_addr] <= rd_data;
            //$display("Register %d : %d", rd_addr, $signed(rd_data));
        end
    end

    assign rs1_data = (rs1_addr == 0) ? '0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? '0 : registers[rs2_addr];


    task get_reg_values;
        $display("\n\nPrinting register file: ");
        for (int i = 0; i < 32; i++) begin
            $display("x%0d : \t0x%0x", i, $signed(registers[i]));
        end
    endtask

endmodule