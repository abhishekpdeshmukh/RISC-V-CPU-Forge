module ALU (
    input logic [63:0] a,
    input logic [63:0] b,
    input decoded_inst_t instr,
    output logic [63:0] result,
    output logic zero
);

logic [63:0] intermediate_result;
logic [127:0] mul_result;
logic [63:0] a_sig, b_sig;
logic [63:0] product;

always_comb begin
    zero = 1'b0;
    intermediate_result = '0;
    mul_result = '0;
    a_sig = a;
    b_sig = b;
    product = '0;

    case (instr.opcode)
        7'b0110011, 7'b0111011: begin // R-type instructions (including RV64I and RV64M)
            case (instr.funct7)
                7'b0000000, 7'b0100000: begin // Normal ops and subtract/arithmetic shift
                    case (instr.funct3)
                        3'b000: begin // ADD, SUB, ADDW, SUBW
                            if (instr.funct7[5]) begin // SUB, SUBW
                                product = a_sig - b_sig;
                            end else begin // ADD, ADDW
                                product = a_sig + b_sig;
                            end
                            if (instr.width_32) begin
                                intermediate_result = {{32{product[31]}}, product[31:0]};
                            end else begin
                                intermediate_result = product;
                            end
                        end
                        3'b001: begin // SLL, SLLW
                            if (instr.width_32) begin
                                product[31:0] = a[31:0] << b[4:0];
                                intermediate_result = {{32{product[31]}}, product[31:0]};
                            end else begin
                                intermediate_result = a << b[5:0];
                            end
                        end
                        3'b101: begin // SRL, SRA, SRLW, SRAW
                            if (instr.funct7[5]) begin // SRA, SRAW
                                if (instr.width_32) begin
                                    product[31:0] = $signed(a_sig[31:0]) >>> b[4:0];
                                    intermediate_result = {{32{product[31]}}, product[31:0]};
                                end else begin
                                    intermediate_result = $signed(a) >>> b[5:0];
                                end
                            end else begin // SRL, SRLW
                                if (instr.width_32) begin
                                    product[31:0] = a[31:0] >> b[4:0];
                                    intermediate_result = {{32{product[31]}}, product[31:0]};
                                end else begin
                                    intermediate_result = a >> b[5:0];
                                end
                            end
                        end
                        3'b010: intermediate_result = $signed(a) < $signed(b); // SLT
                        3'b011: intermediate_result = a < b; // SLTU
                        3'b100: intermediate_result = a ^ b; // XOR
                        3'b110: intermediate_result = a | b; // OR
                        3'b111: intermediate_result = a & b; // AND
                    endcase
                end
                7'b0000001: begin // Multiply/Divide ops
                    case (instr.funct3)
                        3'b000: begin // MUL, MULW
                            mul_result = a * b;
                            if (instr.width_32) begin
                                intermediate_result = {{32{mul_result[31]}}, mul_result[31:0]};
                            end else begin
                                intermediate_result = mul_result[63:0];
                            end
                        end
                        3'b001: intermediate_result = mul_result[127:64]; // MULH
                        3'b010: intermediate_result = $signed(a) * $unsigned(b); // MULHSU
                        3'b011: intermediate_result = mul_result[127:64]; // MULHU
                        3'b100: begin // DIV, DIVW
                            if (instr.width_32) begin
                                intermediate_result = {{32{$signed(a[31:0]) / $signed(b[31:0])}}, $signed(a[31:0]) / $signed(b[31:0])};
                            end else begin
                                intermediate_result = $signed(a) / $signed(b);
                            end
                        end
                        3'b101: begin // DIVU, DIVUW
                            if (instr.width_32) begin
                                intermediate_result = {{32{a[31:0] / b[31:0]}}, a[31:0] / b[31:0]};
                            end else begin
                                intermediate_result = a / b;
                            end
                        end
                        3'b110: begin // REM, REMW
                            if (instr.width_32) begin
                                intermediate_result = {{32{$signed(a[31:0]) % $signed(b[31:0])}}, $signed(a[31:0]) % $signed(b[31:0])};
                            end else begin
                                intermediate_result = $signed(a) % $signed(b);
                            end
                        end
                        3'b111: begin // REMU, REMUW
                            if (instr.width_32) begin
                                intermediate_result = {{32{a[31:0] % b[31:0]}}, a[31:0] % b[31:0]};
                            end else begin
                                intermediate_result = a % b;
                            end
                        end
                    endcase
                end
            endcase
        end
        7'b0010011, 7'b0011011: begin // I-type instructions
            logic [63:0] sign_extended_imm = {{52{instr.imm[11]}}, instr.imm};
            case (instr.funct3)
                3'b000: begin // ADDI, ADDIW
                    if (instr.width_32) begin
                        product = a[31:0] + sign_extended_imm[31:0];
                        intermediate_result = {{32{product[31]}}, product[31:0]};
                    end else begin
                        intermediate_result = a + sign_extended_imm;
                    end
                end
                3'b001: begin // SLLI, SLLIW
                    if (instr.width_32) begin
                        product[31:0] = a[31:0] << instr.imm[4:0];
                        intermediate_result = {{32{product[31]}}, product[31:0]};
                    end else begin
                        intermediate_result = a << instr.imm[5:0];
                    end
                end
                3'b101: begin // SRLI, SRAI, SRLIW, SRAIW
                    if (instr.imm[11:5] == 7'b0000000) begin // SRLI, SRLIW
                        if (instr.width_32) begin
                            product[31:0] = a[31:0] >> instr.imm[4:0];
                            intermediate_result = {{32{product[31]}}, product[31:0]};
                        end else begin
                            intermediate_result = a >> instr.imm[5:0];
                        end
                    end else if (instr.imm[11:5] == 7'b0100000) begin // SRAI, SRAIW
                        if (instr.width_32) begin
                            product[31:0] = $signed(a[31:0]) >>> instr.imm[4:0];
                            intermediate_result = {{32{product[31]}}, product[31:0]};
                        end else begin
                            intermediate_result = $signed(a) >>> instr.imm[5:0];
                        end
                    end
                end
                3'b010: intermediate_result = $signed(a) < $signed(sign_extended_imm); // SLTI
                3'b011: intermediate_result = a < sign_extended_imm; // SLTIU
                3'b100: intermediate_result = a ^ sign_extended_imm; // XORI
                3'b110: intermediate_result = a | sign_extended_imm; // ORI
                3'b111: intermediate_result = a & sign_extended_imm; // ANDI
            endcase
        end
        // ... (rest of the cases remain the same)
    endcase

    result = intermediate_result;
    zero = (result == 64'b0);
end

endmodule