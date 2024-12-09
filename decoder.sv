module Decode (
    input  logic [63:0] addr,  
    input  logic [31:0] instr, 
    output packed_inst out_instr,
    output string        out_str
);

    always_comb begin
        string outstr;
        out_instr.addr   = addr;
        out_instr.opcode = instr[6:0];
        out_instr.rd     = instr[11:7];
        out_instr.funct3 = instr[14:12];
        out_instr.rs1    = instr[19:15];
        out_instr.rs2    = instr[24:20];
        out_instr.funct7 = instr[31:25];
        out_instr.ecall_flag = 1'b0;
        out_instr.alu_src_imm  = 1'b0;
        out_instr.reg_write = 1'b0;
        out_instr.mem_read  = 1'b0;
        out_instr.mem_write  = 1'b0;

        case (out_instr.opcode)
            7'b0110111: begin // LUI
                out_instr.imm = {instr[31:12], 12'd0}; 
                outstr = $sformatf("lui     %s,0x%x", get_reg_name(out_instr.rd), instr[31:12]);
            end
            7'b0010111: begin // AUIPC

                out_instr.imm = {instr[31:12], 12'd0}; 
            
                outstr = $sformatf("auipc   %s,0x%x", get_reg_name(out_instr.rd), instr[31:12]);
            end
            7'b1101111: begin // JAL
                logic signed [20:0] jal_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                out_instr.imm = jal_imm; // J-type immediate
                outstr = $sformatf("jal     %s,0x%x", get_reg_name(out_instr.rd), addr + jal_imm);
            end
            7'b1100111: begin // JALR
                out_instr.imm = {{20{instr[31]}}, instr[31:20]}; // I-type immediate
                outstr = $sformatf("jalr    %s,%s,0x%x", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
            end
            7'b1100011: begin // Branch instructions
                logic signed [12:0] b_imm = {{7{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                out_instr.imm = b_imm; // B-type immediate
                case (out_instr.funct3)
                    3'b000: outstr = $sformatf("beq     %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    3'b001: outstr = $sformatf("bne     %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    3'b100: outstr = $sformatf("blt     %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    3'b101: outstr = $sformatf("bge     %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    3'b110: outstr = $sformatf("bltu    %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    3'b111: outstr = $sformatf("bgeu    %s,%s,0x%x", get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2), addr + b_imm);
                    default: outstr = "unknown";
                endcase
            end
            7'b0000011: begin 
                out_instr.imm = {{20{instr[31]}}, instr[31:20]}; 
                case (out_instr.funct3)
                    3'b000: outstr = $sformatf("lb      %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b001: outstr = $sformatf("lh      %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b010: outstr = $sformatf("lw      %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b011: outstr = $sformatf("ld      %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b100: outstr = $sformatf("lbu     %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b101: outstr = $sformatf("lhu     %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    3'b110: outstr = $sformatf("lwu     %s,%0d(%s)", get_reg_name(out_instr.rd), $signed(out_instr.imm), get_reg_name(out_instr.rs1));
                    default: outstr = "unknown";
                endcase
            end
            7'b0100011: begin 
                logic signed [11:0] s_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type immediate
                out_instr.imm = s_imm;
                case (out_instr.funct3)
                    3'b000: outstr = $sformatf("sb      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
                    3'b001: outstr = $sformatf("sh      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
                    3'b010: outstr = $sformatf("sw      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
                    3'b011: outstr = $sformatf("sd      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
                    default: outstr = "unknown";
                endcase
            end
            7'b0010011: begin 
                out_instr.imm = {{20{instr[31]}}, instr[31:20]}; 
                case (out_instr.funct3)
                    3'b000: outstr = $sformatf("addi    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b010: outstr = $sformatf("slti    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b011: outstr = $sformatf("sltiu   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b100: outstr = $sformatf("xori    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b110: outstr = $sformatf("ori     %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b111: outstr = $sformatf("andi    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b001: outstr = $sformatf("slli    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
                    3'b101: outstr = out_instr.funct7[5] ? $sformatf("srai    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]) :
                                                        $sformatf("srli    %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
                    default: outstr = "unknown";
                endcase
            end
            7'b0110011: begin 
                out_instr.imm = 64'd0; 
                case (out_instr.funct3)
                    3'b000: outstr = out_instr.funct7[5] ? $sformatf("sub     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("add     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b001: outstr = $sformatf("sll     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b010: outstr = $sformatf("slt     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b011: outstr = $sformatf("sltu    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b100: outstr = $sformatf("xor     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b101: outstr = out_instr.funct7[5] ? $sformatf("sra     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("srl     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b110: outstr = $sformatf("or      %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b111: outstr = $sformatf("and     %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    default: outstr = "unknown";
                endcase
            end
            7'b0011011: begin 
                out_instr.imm = {{20{instr[31]}}, instr[31:20]}; 
           
                case (out_instr.funct3)
                    3'b000: outstr = $sformatf("addiw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
                    3'b001: outstr = $sformatf("slliw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
                    3'b101: outstr = out_instr.funct7[5] ? $sformatf("sraiw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]) :
                                                $sformatf("srliw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
                    default: outstr = "unknown";
                endcase
            end
            7'b0111011: begin 
                out_instr.imm = 64'd0; 
                case (out_instr.funct3)
                    3'b000: outstr = out_instr.funct7[5] ? $sformatf("subw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("addw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b001: outstr = $sformatf("sllw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b100: outstr = out_instr.funct7[5] ? $sformatf("divw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("divuw   %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b110: outstr = out_instr.funct7[5] ? $sformatf("remw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("remuw   %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    3'b101: outstr = out_instr.funct7[5] ? $sformatf("sraw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2)) :
                                                $sformatf("srlw    %s,%s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), get_reg_name(out_instr.rs2));
                    default: outstr = "unknown";
                endcase
            end
            default: outstr = "unknown";
        endcase

        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.rs1 == 5'b00000)
            outstr = $sformatf("li      %s,%0d", get_reg_name(out_instr.rd), $signed(out_instr.imm));
        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.imm == 12'b0)
            outstr = $sformatf("mv      %s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1));
        if (instr == 32'h00000013)
            outstr = "nop";
        if (instr == 32'h00008067)
            outstr = "ret";
        if (instr == 32'h00000073) begin
            outstr = "ecall";
            out_instr.ecall_flag = 'd1;
            out_instr.rd = 5'd10;
            //$display("WOOOOO WE GOT AN ECALL");
        end
        case (out_instr.opcode)
            7'b0111011: out_instr.width_32 = 2'b01; 
            7'b0011011: out_instr.width_32 = 2'b01; 
            7'b0000011: begin 
                if (out_instr.funct3 inside {3'b010, 3'b110}) // lw, lwu
                    out_instr.width_32 = 2'b01;
                else
                    out_instr.width_32 = 2'b00;
            end
            7'b0100011: begin 
                if (out_instr.funct3 == 3'b010) 
                    out_instr.width_32 = 2'b01;
                else
                    out_instr.width_32 = 2'b00;
            end
            default: out_instr.width_32 = 2'b00;
        endcase

        case (out_instr.opcode)
            7'b0000011,
            7'b0100011: begin 
                case (out_instr.funct3)
                    3'b00: out_instr.mem_size = 2'b00; // Byte
                    3'b01: out_instr.mem_size  = 2'b01; // Half-word
                    3'b10: out_instr.mem_size  = 2'b10; // Word
                    3'b11: out_instr.mem_size  = 2'b11; // Double-word
                    default: out_instr.mem_size  = 2'b11; // Default to double-word
                endcase
            end
            default: out_instr.mem_size  = 2'b00; 
        endcase

        out_str = outstr;

        case (out_instr.opcode)

            7'b0110011, 
            7'b0111011: begin 
                out_instr.alu_src_imm  = 1'b0;
                out_instr.reg_write = 1'b1;
            end
    
            7'b0010011, // OP-IMM
            7'b0011011: begin // OP-IMM-32
                out_instr.alu_src_imm  = 1'b1;
                out_instr.reg_write = 1'b1;
            end
    
            7'b0000011: begin
                out_instr.alu_src_imm  = 1'b1;
                out_instr.reg_write = 1'b1;
                out_instr.mem_read  = 1'b1;
            end
    
            7'b0100011: begin
                out_instr.alu_src_imm  = 1'b1;
                out_instr.mem_write  = 1'b1;
            end
    
            7'b0110111, // LUI
            7'b0010111: begin // AUIPC
                out_instr.alu_src_imm  = 1'b1;
                out_instr.reg_write = 1'b1;
            end
    
            7'b1101111, // JAL
            7'b1100111: begin // JALR
                out_instr.alu_src_imm  = 1'b1;
                out_instr.reg_write = 1'b1;
            end
        endcase

    end

    function string get_reg_name(logic [4:0] reg_num);
        case (reg_num)
            5'd0:  return "x0";
            5'd1:  return "x1";
            5'd2:  return "x2";
            5'd3:  return "x3";
            5'd4:  return "x4";
            5'd5:  return "x5";
            5'd6:  return "6";
            5'd7:  return "x7";
            5'd8:  return "x8";
            5'd9:  return "x9";
            5'd10: return "x10";
            5'd11: return "x11";
            5'd12: return "x12";
            5'd13: return "x13";
            5'd14: return "x14";
            5'd15: return "x15";
            5'd16: return "x16";
            5'd17: return "x17";
            5'd18: return "x18";
            5'd19: return "x19";
            5'd20: return "x20";
            5'd21: return "x21";
            5'd22: return "x22";
            5'd23: return "x23";
            5'd24: return "x24";
            5'd25: return "x25";
            5'd26: return "x26";
            5'd27: return "x27";
            5'd28: return "x28";
            5'd29: return "x29";
            5'd30: return "x30";
            5'd31: return "x31";
            default: return $sformatf("%0d", reg_num); 
        endcase
    endfunction


endmodule

