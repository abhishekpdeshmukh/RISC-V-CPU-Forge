// EXStage Module: Execute Stage
module EXStage (
    input  logic                 clk,
    input  logic                 reset,
    // Inputs from ID_EX Pipeline Register
    input  decoded_inst_t        decoded_inst_in,
    input  logic [63:0]          rs1_data_in,
    input  logic [63:0]          rs2_data_in,
    input  logic [63:0]          imm_in,
    // Control signals from ID_EX
    input  logic                 alu_src_in,    // Select between rs2_data and immediate
    input  logic                 mem_read_in,   // Memory read control
    input  logic                 mem_write_in,  // Memory write control
    input  logic                 reg_write_in,  // Register write control
    // Outputs to EX_MEM Pipeline Register
    output logic [63:0]          alu_result_out,
    output logic                 alu_zero_out,
    // Control signals to EX_MEM
    output logic                 mem_read_out,
    output logic                 mem_write_out,
    output logic                 reg_write_out,
    output logic [4:0]           wb_rd_out,
    // Branch outputs
    output logic                 branch_taken_out,
    output logic [63:0]          branch_target_out
);

    // Internal signals
    logic [63:0] operand_b;
    logic [63:0] alu_result;
    logic        alu_zero;
    logic        branch_taken;
    logic [63:0] branch_target;

    // Select ALU operand B based on alu_src_in
    assign operand_b = alu_src_in ? imm_in : rs2_data_in;

    // Instantiate ALU
    ALU alu_inst (
        .a(rs1_data_in),
        .b(operand_b),
        .instr(decoded_inst_in),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Branch decision logic
    always_comb begin
        branch_taken = 1'b0;
        branch_target = 64'b0;

        case (decoded_inst_in.opcode) //AKA TODO
        //case (0)
            7'b1100011: begin // Branch instructions
                case (decoded_inst_in.funct3)
                    3'b000: branch_taken = (rs1_data_in == rs2_data_in);   // BEQ
                    3'b001: branch_taken = (rs1_data_in != rs2_data_in);   // BNE
                    3'b100: branch_taken = ($signed(rs1_data_in) < $signed(rs2_data_in)); // BLT
                    3'b101: branch_taken = ($signed(rs1_data_in) >= $signed(rs2_data_in)); // BGE
                    3'b110: branch_taken = (rs1_data_in < rs2_data_in);    // BLTU
                    3'b111: branch_taken = (rs1_data_in >= rs2_data_in);   // BGEU
                    default: branch_taken = 1'b0;
                endcase

                if (branch_taken) begin
                    branch_target = decoded_inst_in.addr + imm_in; // Calculate branch target
                end
            end

            7'b1101111: begin // JAL
                branch_taken = 1'b1; // Always taken
                branch_target = decoded_inst_in.addr + imm_in; // Calculate jump target
            end

            7'b1100111: begin // JALR
                branch_taken = 1'b1; // Always taken
                branch_target = (rs1_data_in + imm_in) & ~1'b1; // Calculate jump target (aligned)
            end

            default: begin
                branch_taken = 1'b0;
                branch_target = 64'b0;
            end
        endcase
    end

    // Assign outputs
    assign alu_result_out    = alu_result;
    assign alu_zero_out      = alu_zero;
    assign mem_read_out      = mem_read_in;
    assign mem_write_out     = mem_write_in;
    assign reg_write_out     = reg_write_in;
    assign wb_rd_out         = decoded_inst_in.rd;
    assign branch_taken_out  = branch_taken;
    assign branch_target_out = branch_target;

endmodule

