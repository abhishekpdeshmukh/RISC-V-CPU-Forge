module ALU (
    input  logic [63:0]       a,              
    input  logic [63:0]       b,              
    input  packed_inst     instr,          
    output logic [63:0]       result,         
    output logic              branch_taken,   
    output logic [63:0]       branch_target   
);

    logic [63:0]   intermediate_result;
    logic [127:0]  mul_result;
    logic [63:0]   a_sig, b_sig;
    logic [63:0]   product;

    logic [63:0] imm_s_type; 
    logic [63:0] imm_i_type; 
    always_comb begin

        if (instr.opcode == 7'b0100011) begin 

            imm_s_type = {{52{instr.imm[11]}}, instr.imm[11:5], instr.imm[4:0]};
        end else begin
            imm_s_type = {64{1'b0}}; 
        end

        if (instr.opcode == 7'b0000011) begin 

            imm_i_type = {{52{instr.imm[11]}}, instr.imm[11:0]};
        end else begin
            imm_i_type = {64{1'b0}}; 
        end
    end

    always_comb begin

        intermediate_result = '0;
        mul_result          = '0;
        a_sig               = a;
        b_sig               = b;
        product             = '0;
        branch_taken        = 1'b0;
        branch_target       = 64'b0;
        
        case (instr.opcode)
            7'b0110011, 7'b0111011: begin 
                case (instr.funct7)
                    7'b0000000, 7'b0100000: begin 
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
                            3'b010: intermediate_result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0; // SLT
                            3'b011: intermediate_result = (a < b) ? 64'd1 : 64'd0; // SLTU
                            3'b100: intermediate_result = a ^ b; // XOR
                            3'b110: intermediate_result = a | b; // OR
                            3'b111: intermediate_result = a & b; // AND
                            default: intermediate_result = '0; 
                        endcase
                    end
                    7'b0000001: begin 
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
                            3'b010: intermediate_result = ($signed(a) * $unsigned(b)); // MULHSU
                            3'b011: intermediate_result = mul_result[127:64]; // MULHU
                            3'b100: begin // DIV, DIVW
                                if (instr.width_32) begin

                                    intermediate_result = {{32{$signed(a[31:0]) / $signed(b[31:0])}}, $signed(a[31:0]) / $signed(b[31:0])};
                                end else begin
                                    intermediate_result = ($signed(a) / $signed(b));
                                end
                            end
                            3'b101: begin // DIVU, DIVUW
                                if (instr.width_32) begin

                                    intermediate_result = {{32{a[31:0] / b[31:0]}}, a[31:0] / b[31:0]};
                                end else begin
                                    intermediate_result = (a / b);
                                end
                            end
                            3'b110: begin // REM, REMW
                                if (instr.width_32) begin

                                    intermediate_result = {{32{$signed(a[31:0]) % $signed(b[31:0])}}, $signed(a[31:0]) % $signed(b[31:0])};
                                end else begin
                                    intermediate_result = ($signed(a) % $signed(b));
                                end
                            end
                            3'b111: begin // REMU, REMUW
                                if (instr.width_32) begin

                                    intermediate_result = {{32{a[31:0] % b[31:0]}}, a[31:0] % b[31:0]};
                                end else begin
                                    intermediate_result = (a % b);
                                end
                            end
                            default: intermediate_result = '0; 
                        endcase
                    end
                    default: intermediate_result = '0; 
                endcase
            end
            7'b0110111: begin // LUI

                intermediate_result = $signed({instr.imm[31:12], 12'b0});
            end

            7'b0010111: begin // AUIPC
              
                logic [63:0] sign_extended_imm = {{32{instr.imm[31]}}, instr.imm};
                intermediate_result = instr.addr + sign_extended_imm;
                // $display("======== Decoded Instruction Details ========");
                 
                // $display("============================================");
            end
            7'b0010011, 7'b0011011: begin // I-type instructions (including immediate operations)

                logic [63:0] sign_extended_imm = {{52{instr.imm[11]}}, instr.imm};

                case (instr.funct3)
                    3'b000: begin // ADDI, ADDIW
                        if (instr.width_32) begin
                            product = a[31:0] + sign_extended_imm[31:0];

                            intermediate_result = {{32{product[31]}}, product[31:0]};
                        end else begin
                            intermediate_result = a + sign_extended_imm;
                        end
                        if (instr.addr == 64'h21790) begin
                            // $display("=== ADDI/ADDIW Instruction at PC 21790 ===");
                            // $display("=========================================");
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
                        if (instr.funct7[5]) begin // SRAI, SRAIW (Arithmetic Right Shift)
                            if (instr.width_32) begin

                                product[31:0] = a[31:0] >>> instr.imm[4:0];
                                intermediate_result = {{32{product[31]}}, product[31:0]};
                                
                            end else begin

                                intermediate_result = $signed(a) >>> instr.imm[5:0];
                            
                            end
                            
                        end else begin // SRLI, SRLIW 
                            if (instr.width_32) begin

                                product[31:0] = a[31:0] >> instr.imm[4:0];
                                intermediate_result = {{32{product[31]}}, product[31:0]};
                            end else begin

                                intermediate_result = a >> instr.imm[5:0];
                            end
                        end
                    end

                    3'b010: begin // SLTI
                        intermediate_result = ($signed(a) < $signed(sign_extended_imm)) ? 64'd1 : 64'd0;
                    end
                    3'b011: begin // SLTIU
                        intermediate_result = (a < sign_extended_imm) ? 64'd1 : 64'd0;
                    end
                    3'b100: begin // XORI
                        intermediate_result = a ^ sign_extended_imm;
                    end
                    3'b110: begin // ORI
                        intermediate_result = a | sign_extended_imm;
                    end
                    3'b111: begin // ANDI
                        intermediate_result = a & sign_extended_imm;
                    end
                    default: begin
                        intermediate_result = '0; 
                    end
                endcase
            end
            7'b0000011: begin 

                intermediate_result = a + imm_i_type;

                if (instr.addr == 64'h2178c) begin
                    // $display("=== Load Instruction (LD) at PC 0x2178c ===");
                   
                    // $display("===========================================");
                end
            end
            7'b0100011: begin 
                intermediate_result = a + imm_s_type;
                
            end

            7'b1100011: begin 

                case (instr.funct3)
                    3'b000: branch_taken = (a == b);                          // BEQ
                    3'b001: branch_taken = (a != b);                          // BNE
                    3'b100: branch_taken = ($signed(a) < $signed(b));         // BLT
                    3'b101: branch_taken = ($signed(a) >= $signed(b));        // BGE
                    3'b110: branch_taken = (a < b);                           // BLTU
                    3'b111: branch_taken = (a >= b);                          // BGEU
                    default: branch_taken = 1'b0;
                endcase

                if (branch_taken) begin

                    branch_target = $signed(instr.addr) + $signed(instr.imm);
                   
                end

                intermediate_result = branch_target;
            end

            7'b1101111: begin // JAL
                branch_taken = 1'b1; 
                branch_target = $signed(instr.addr) + $signed(instr.imm);
                intermediate_result = instr.addr + 64'd4; 
            end

            7'b1100111: begin // JALR
                branch_taken = 1'b1; 
                branch_target = ($signed(a) + $signed(instr.imm)) & ~1'b1;
                intermediate_result = instr.addr + 64'd4;
                // $display("=== JALR Instruction Execution ===");
               
                // $display("==================================");
                if (branch_target == 64'd0) $finish;
            end

            default: begin
                intermediate_result = 64'hAAAABBBB;; 
            end
        endcase

        result = intermediate_result;

    end

endmodule