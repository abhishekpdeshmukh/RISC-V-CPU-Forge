typedef struct packed {
    logic [63:0] addr;
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] imm;
    logic [1:0] width_32;     //  32-bit op 
    logic [2:0] funct3; 
    logic [6:0] funct7;
} decoded_inst_t;

module Decode
(
  input  logic [63:0] addr,         // Current instruction address (PC)
  input  logic [31:0] instr,        // 32-bit instruction to decode
  output decoded_inst_t out_instr,
  output string out_str
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
        out_instr.imm    = {{20{instr[31]}}, instr[31:20]}; // I-type immediate
        
        // Decode instruction
        case (out_instr.opcode)
        7'b0110111: begin // LUI
            outstr = $sformatf("lui     %s,0x%x", get_reg_name(out_instr.rd ), instr[31:12]);
        end
        7'b0010111: begin // AUIPC
            outstr = $sformatf("auipc   %s,0x%x", get_reg_name(out_instr.rd ), instr[31:12]);
        end
        7'b1101111: begin // JAL
            logic signed [20:0] jal_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            outstr = $sformatf("jal     %s,0x%x", get_reg_name(out_instr.rd), addr + jal_imm);
        end
        7'b1100111: begin // JALR
            outstr = $sformatf("jalr    %s", get_reg_name(out_instr.rd ));
        end
        7'b1100011: begin // Branch instructions (e.g., BEQ, BNE, BLT)
            logic signed [12:0] b_imm = {{7{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
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
        7'b0000011: begin // Load instructions
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
        7'b0100011: begin // Store instructions
            logic signed [11:0] s_imm = {instr[31:25], instr[11:7]};
            case (out_instr.funct3)
            3'b000: outstr = $sformatf("sb      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
            3'b001: outstr = $sformatf("sh      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
            3'b010: outstr = $sformatf("sw      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
            3'b011: outstr = $sformatf("sd      %s,%0d(%s)", get_reg_name(out_instr.rs2), $signed(s_imm), get_reg_name(out_instr.rs1));
            default: outstr = "unknown";
            endcase
        end
        7'b0010011: begin // Immediate arithmetic instructions
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
        7'b0110011: begin // Register arithmetic instructions
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
        7'b0011011: begin // RISC-V 64-bit specific instructions
            case (out_instr.funct3)
            3'b000: outstr = $sformatf("addiw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), $signed(out_instr.imm));
            3'b001: outstr = $sformatf("slliw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
            3'b101: outstr = out_instr.funct7[5] ? $sformatf("sraiw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]) :
                                            $sformatf("srliw   %s,%s,%0d", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1), instr[24:20]);
            default: outstr = "unknown";
            endcase
        end
        7'b0111011: begin // RISC-V 64-bit specific register-register instructions
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

        // Special cases and pseudo-instructions
        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.rs1 == 5'b00000) outstr = $sformatf("li      %s,%0d", get_reg_name(out_instr.rd), $signed(out_instr.imm));
        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.imm == 12'b0) outstr = $sformatf("mv      %s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1));
        if (instr == 32'h00000013) outstr = "nop";
        if (instr == 32'h00008067) outstr = "ret";

        // Set width_32 for all relevant instructions
        case (out_instr.opcode)
            7'b0111011: out_instr.width_32 = 2'b01; // 32-bit arithmetic operations (addw, subw, etc.)
            7'b0011011: out_instr.width_32 = 2'b01; // 32-bit immediate arithmetic operations (addiw, slliw, etc.)
            7'b0000011: begin // Load instructions
                if (out_instr.funct3 inside {3'b010, 3'b110}) // lw, lwu
                    out_instr.width_32 = 2'b01;
                else
                    out_instr.width_32 = 2'b00;
            end
            7'b0100011: begin // Store instructions
                if (out_instr.funct3 == 3'b010) // sw
                    out_instr.width_32 = 2'b01;
                else
                    out_instr.width_32 = 2'b00;
            end
            default: out_instr.width_32 = 2'b00;
        endcase

        out_str = outstr;

  end

  function string get_reg_name(logic [4:0] reg_num);
      case (reg_num)
        5'd0: return "zero";
        5'd1: return "ra";
        5'd2: return "sp";
        5'd3: return "gp";
        5'd4: return "tp";
        5'd5: return "t0";
        5'd6: return "t1";
        5'd7: return "t2";
        5'd8: return "s0";
        5'd9: return "s1";
        5'd10: return "a0";
        5'd11: return "a1";
        5'd12: return "a2";
        5'd13: return "a3";
        5'd14: return "a4";
        5'd15: return "a5";
        5'd16: return "a6";
        5'd17: return "a7";
        5'd18: return "s2";
        5'd19: return "s3";
        5'd20: return "s4";
        5'd21: return "s5";
        5'd22: return "s6";
        5'd23: return "s7";
        5'd24: return "s8";
        5'd25: return "s9";
        5'd26: return "s10";
        5'd27: return "s11";
        5'd28: return "t3";
        5'd29: return "t4";
        5'd30: return "t5";
        5'd31: return "t6";
        default: return $sformatf("x%0d", reg_num);
      endcase
    endfunction
endmodule