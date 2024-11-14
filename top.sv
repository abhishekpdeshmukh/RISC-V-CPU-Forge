`include "Sysbus.defs"


// Define decoded_inst_t struct
typedef struct packed {
    logic [63:0] addr;
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] imm;
    logic [1:0] width_32;     // 32-bit op 
    logic [2:0] funct3; 
    logic [6:0] funct7;
} decoded_inst_t;

// IFStage Module with FSM-based AXI4 Read Burst Handling
module IFStage #(
    parameter ID_WIDTH    = 13,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter STRB_WIDTH  = DATA_WIDTH/8
) (
    input  logic                   clk,
    input  logic                   reset,
    input  logic [63:0]            pc_in,
    output logic [31:0]            instruction_out,
    output logic [63:0]            pc_plus_4,
    output logic                   if_valid,

    // AXI4 Read Address Channel
    output logic [ID_WIDTH-1:0]    m_axi_arid,
    output logic [ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [7:0]             m_axi_arlen,
    output logic [2:0]             m_axi_arsize,
    output logic [1:0]             m_axi_arburst,
    output logic                   m_axi_arlock,
    output logic [3:0]             m_axi_arcache,
    output logic [2:0]             m_axi_arprot,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,

    // AXI4 Read Data Channel
    input  logic [ID_WIDTH-1:0]    m_axi_rid,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                   m_axi_rlast,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready
);

    // Define the states of the FSM
    typedef enum logic [1:0] {
        IDLE,
        READ_ADDR,
        READ_DATA,
        READ_DONE
    } IF_state_t;

    IF_state_t current_state, next_state;

    // Instruction Buffer: 16 Instructions
    logic [31:0] instruction_buffer [0:15];
    integer      beat_counter;   // Counts received AXI beats (0 to 7)
    integer      output_counter; // Counts output instructions (0 to 15)

    // Control Signals
    logic        is_fetching;

    // Initialize Control Signals
    initial begin
        beat_counter   = 0;
        output_counter = 0;
        is_fetching    = 1'b0;
    end

    // Initialize AXI4 Read Address ID (can be set to 0 if not used)
    assign m_axi_arid = 0;

    // State Machine and Instruction Buffering
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            //current_state    <= IDLE;
            m_axi_arvalid    <= 1'b0;
            m_axi_araddr     <= 0;
            m_axi_arlen      <= 8'd0;
            m_axi_arsize     <= 3'd0;
            m_axi_arburst    <= 2'b00;
            m_axi_arlock     <= 1'b0;
            m_axi_arcache    <= 4'b0000;
            m_axi_arprot     <= 3'b000;
            m_axi_rready     <= 1'b0;
            if_valid         <= 1'b0;
            instruction_out <= 32'b0;
            beat_counter     <= 0;
            output_counter   <= 0;
            pc_plus_4        <= pc_in;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    // Initiate AXI read burst
                    m_axi_arid    <= '0;               // Hardcoded id = 0
                    m_axi_araddr  <= {pc_in[ADDR_WIDTH-1:6], 6'b0}; // Align to 64-byte boundary
                    m_axi_arsize  <= 3'b011;           // 64-bit transfer per beat
                    m_axi_arlen   <= 8'h07;            // 8-beat transfer (64*8 = 512 bits per request)
                    m_axi_arburst <= 2'b10;            // Wrap burst
                    m_axi_arlock  <= 1'b0;             // Not locked tx (READ)
                    m_axi_arcache <= 4'b0011;          // Cacheable, bufferable
                    m_axi_arprot  <= 3'b000;           // Unprivileged, secure, data access
                    m_axi_arvalid <= 1'b1;             // Ready to initiate read

                    $display("IFStage: Initiating AXI read burst at PC 0x%h", pc_in);

                    if (m_axi_arready) begin
                        next_state    <= READ_DATA;
                        m_axi_rready  <= 1'b1; // Ready to receive read data
                        beat_counter  <= 0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_DATA: begin
                    m_axi_arvalid <= 1'b0;
                    if (m_axi_rvalid) begin
                        // Store two instructions per AXI beat
                        instruction_buffer[beat_counter*2    ] <= m_axi_rdata[31:0];
                        instruction_buffer[beat_counter*2 + 1] <= m_axi_rdata[63:32];
                        $display("IFStage: Received AXI beat %0d: 0x%h and 0x%h",
                                 beat_counter, m_axi_rdata[31:0], m_axi_rdata[63:32]);
                        beat_counter <= beat_counter + 1;

                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            next_state    <= READ_DONE;
                            output_counter <= 0;
                            if_valid       <= 1'b1;
                        end else begin
                            next_state <= READ_DATA;
                        end
                    end else begin
                        next_state <= READ_DATA;
                    end
                end

                READ_DONE: begin
                    // Output one instruction per cycle
                    if (output_counter < 16) begin
                        if (instruction_buffer[output_counter] == 32'b0 && instruction_out == 32'b0) begin
                            $finish;
                        end
                        instruction_out <= instruction_buffer[output_counter];
                        //$display("IFStage: Sending 0x%h to IF/ID", instruction_buffer[output_counter]); 
                        output_counter   <= output_counter + 1;
                        if_valid         <= 1'b1;
                        next_state        <= READ_DONE;
                        pc_plus_4 <= pc_in + 4;
                    end else begin
                        // All instructions have been output
                        instruction_out <= 32'b0;
                        if_valid         <= 1'b0;
                        next_state        <= IDLE;
                        pc_plus_4 <= pc_in + 4;
                    end
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Display fetched instructions (Optional)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Do nothing
        end else if (current_state == READ_DONE && if_valid) begin
            //$display("IFStage: Fetched Instructions up to beat_counter=%0d", beat_counter);
        end else if (current_state == READ_DONE) begin
            //$display("IFStage: Fetched Instructions: 0x%h ", instruction_out);
        end
    end

endmodule

// IF_ID Pipeline Register Module Handling Two Instructions
module IF_ID (
    input  logic         clk,
    input  logic         reset,
    input  logic [31:0]  instruction_in,
    input  logic [63:0]  pc_in,
    input  logic         valid_in,
    output logic [31:0]  instruction_out,
    output logic [63:0]  pc_out,
    output logic         valid_out
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            instruction_out <= 32'b0;
            pc_out          <= 64'b0;
            valid_out       <= 1'b0;
        end else begin
            instruction_out <= instruction_in;
            //$display("IF_ID: instruction_in: 0x%h", instruction_in);
            pc_out          <= pc_in;
            valid_out       <= valid_in;
        end
    end

endmodule

// Decode Module
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
        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.rs1 == 5'b00000)
            outstr = $sformatf("li      %s,%0d", get_reg_name(out_instr.rd), $signed(out_instr.imm));
        if (out_instr.opcode == 7'b0010011 && out_instr.funct3 == 3'b000 && out_instr.imm == 12'b0)
            outstr = $sformatf("mv      %s,%s", get_reg_name(out_instr.rd), get_reg_name(out_instr.rs1));
        if (instr == 32'h00000013)
            outstr = "nop";
        if (instr == 32'h00008067)
            outstr = "ret";

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

  // Function to get register names
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

// IDStage Module Handling Single Instruction with Decoder Integration
module IDStage (
    input  logic         clk,
    input  logic         reset,
    input  logic [31:0]  instruction_in,
    input  logic [63:0]  pc_in,
    // Outputs to Regfile
    output logic [4:0]    wb_rd,
    output logic [63:0]   wb_data,
    output logic          wb_enable,
    // Outputs to Pipeline Register
    output decoded_inst_t  decoded_inst,
    output logic [63:0]   rs1_data,
    output logic [63:0]   rs2_data,
    output logic [63:0]   imm,
    output logic          alu_src,
    output logic          mem_read,
    output logic          mem_write,
    output logic          reg_write
);

    // Internal signals for Decode module
    decoded_inst_t decoded_inst_internal;
    string decoded_str;

    // Instantiate Decode module
    Decode decoder_inst (
        .addr(pc_in),
        .instr(instruction_in),
        .out_instr(decoded_inst_internal),
        .out_str(decoded_str)
    );

    // Assign decoded instruction to output
    assign decoded_inst = decoded_inst_internal;

    // Connect rs1_data and rs2_data from Regfile
    // These should be connected externally via the top module
    // For example, top module assigns rs1_data_id and rs2_data_id to rs1_data and rs2_data
    // Here, we assume that rs1_data and rs2_data are driven externally

    // Assign immediate value
    assign imm = decoded_inst_internal.imm;

    // Control Signal Generation Based on Decoded Instruction
    always_comb begin
        // Default control signal assignments
        alu_src   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        // Initialize other control signals as needed

        case (decoded_inst_internal.opcode)
            // R-Type Arithmetic Instructions (64-bit and 32-bit)
            7'b0110011, // OP
            7'b0111011: begin // OP-32
                alu_src   = 1'b0;
                reg_write = 1'b1;
            end

            // I-Type Arithmetic Instructions (64-bit and 32-bit)
            7'b0010011, // OP-IMM
            7'b0011011: begin // OP-IMM-32
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end

            // Load Instructions
            7'b0000011: begin
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                reg_write = 1'b1;
            end

            // Store Instructions
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
            end

            // Branch Instructions
            7'b1100011: begin
                alu_src   = 1'b0;
                // Set additional branch-related control signals if needed
                // Example:
                // branch = 1'b1;
            end

            // Upper Immediate Instructions: LUI and AUIPC
            7'b0110111, // LUI
            7'b0010111: begin // AUIPC
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end

            // Jump Instructions: JAL and JALR
            7'b1101111, // JAL
            7'b1100111: begin // JALR
                alu_src   = 1'b1;
                reg_write = 1'b1;
                // If needed, set jump-related control signals
                // Example:
                // jump = 1'b1;
            end

            default: begin
                // Handle unknown or unimplemented opcodes
                alu_src   = 1'b0;
                mem_read  = 1'b0;
                mem_write = 1'b0;
                reg_write = 1'b0;
                // Optionally, assert an error signal or set a trap
            end
        endcase
    end



    // Assign write-back signals
    assign wb_rd     = decoded_inst_internal.rd;
    assign wb_data   = rs1_data; // **Review Needed: Placeholder assignment**
    assign wb_enable = reg_write;


    // Display the decoded instruction
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Optionally, you can reset display or hold previous state
        end else begin
            if (instruction_in != 32'b0) begin
                //$display("IDStage: PC: 0x%x Instruction: 0x%h decoded_str : %s", pc_in, instruction_in, decoded_str);
            end
        end
    end

endmodule

// Regfile Module: 32 x 64-bit Registers
module Regfile (
    input logic clk,
    input logic reset,
    input  logic [63:0] initial_sp,
    // Read Ports
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    output logic [63:0] rd1_data,
    output logic [63:0] rd2_data,
    // Write Port
    input logic [4:0] rd,
    input logic [63:0] rd_data,
    input logic write_enable
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

// ALU Module: Performs arithmetic and logical operations
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
        // rest of the cases - loads jumps etc will be taken care post wp2
        7'b0000011, // Load instructions
        7'b0100011: begin // Store instructions
            // Effective address calculation: rs1 + imm
            intermediate_result = a + $signed(instr.imm);
            result = intermediate_result;
        end
    endcase

    result = intermediate_result;
    zero = (result == 64'b0);
end

endmodule



// ID_EX Pipeline Register Module
module ID_EX (
    input  logic                 clk,
    input  logic                 reset,
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
        if (reset) begin
            decoded_inst_out <= '0;
            rs1_data_out     <= '0;
            rs2_data_out     <= '0;
            imm_out          <= '0;
            alu_src_out      <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            reg_write_out    <= 1'b0;
        end else begin
            decoded_inst_out <= decoded_inst_in;
            rs1_data_out     <= rs1_data_in;
            rs2_data_out     <= rs2_data_in;
            imm_out          <= imm_in;
            alu_src_out      <= alu_src_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            reg_write_out    <= reg_write_in;
            // Debugging
            //y("ID_EX: Decoded rd=%0d, ALU Src=%0b, MEM Read=%0b, MEM Write=%0b, Reg Write=%0b",
                    //decoded_inst_in.rd, alu_src_in, mem_read_in, mem_write_in, reg_write_in);
        end
    end

endmodule

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
    output logic [4:0]           wb_rd_out
);

    // Internal signals
    logic [63:0] operand_b;
    logic [63:0] alu_result;
    logic        alu_zero;
    
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
    
    // Assign ALU outputs
    assign alu_result_out = alu_result;
    assign alu_zero_out   = alu_zero;
    
    // Pass control signals to EX_MEM
    assign mem_read_out    = mem_read_in;
    assign mem_write_out   = mem_write_in;
    assign reg_write_out   = reg_write_in;
    assign wb_rd_out       = decoded_inst_in.rd;

endmodule

// Top Module Integrating IFStage, IF_ID, IDStage, ID_EX, EXStage, and Regfile
module top
#(
  parameter ID_WIDTH    = 13,
  parameter ADDR_WIDTH  = 64,
  parameter DATA_WIDTH  = 64,
  parameter STRB_WIDTH  = DATA_WIDTH/8
)
(
  input  logic                    clk,
  input  logic                    reset,
  input  logic                    hz32768timer,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  logic [63:0]             entry,
  input  logic [63:0]             stackptr,
  input  logic [63:0]             satp,

  // AXI interface signals
  // AXI4 Write Address Channel
  output logic [ID_WIDTH-1:0]     m_axi_awid,
  output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
  output logic [7:0]              m_axi_awlen,
  output logic [2:0]              m_axi_awsize,
  output logic [1:0]              m_axi_awburst,
  output logic                   m_axi_awlock,
  output logic [3:0]              m_axi_awcache,
  output logic [2:0]              m_axi_awprot,
  output logic                   m_axi_awvalid,
  input  logic                   m_axi_awready,

  // AXI4 Write Data Channel
  output logic [DATA_WIDTH-1:0]    m_axi_wdata,
  output logic [STRB_WIDTH-1:0]    m_axi_wstrb,
  output logic                    m_axi_wlast,
  output logic                    m_axi_wvalid,
  input  logic                    m_axi_wready,

  // AXI4 Write Response Channel
  input  logic [ID_WIDTH-1:0]      m_axi_bid,
  input  logic [1:0]               m_axi_bresp,
  input  logic                     m_axi_bvalid,
  output logic                     m_axi_bready,

  // AXI4 Read Address Channel
  output logic [ID_WIDTH-1:0]      m_axi_arid,
  output logic [ADDR_WIDTH-1:0]    m_axi_araddr,
  output logic [7:0]               m_axi_arlen,
  output logic [2:0]               m_axi_arsize,
  output logic [1:0]               m_axi_arburst,
  output logic                     m_axi_arlock,
  output logic [3:0]               m_axi_arcache,
  output logic [2:0]               m_axi_arprot,
  output logic                     m_axi_arvalid,
  input  logic                     m_axi_arready,

  // AXI4 Read Data Channel
  input  logic [ID_WIDTH-1:0]      m_axi_rid,
  input  logic [DATA_WIDTH-1:0]    m_axi_rdata,
  input  logic [1:0]               m_axi_rresp,
  input  logic                     m_axi_rlast,
  input  logic                     m_axi_rvalid,
  output logic                     m_axi_rready,

  // AXI4 Additional Signals (Assuming they're needed elsewhere)
  input  logic                     m_axi_acvalid,
  output logic                     m_axi_acready,
  input  logic [ADDR_WIDTH-1:0]    m_axi_acaddr,
  input  logic [3:0]               m_axi_acsnoop
);

    // Initialize AXI write channels to default
    assign m_axi_awid     = '0;
    assign m_axi_awaddr   = '0;
    assign m_axi_awlen    = '0;
    assign m_axi_awsize   = '0;
    assign m_axi_awburst  = '0;
    assign m_axi_awlock   = '0;
    assign m_axi_awcache  = '0;
    assign m_axi_awprot   = '0;
    assign m_axi_awvalid  = '0;
    assign m_axi_wdata    = '0;
    assign m_axi_wstrb    = '0;
    assign m_axi_wlast    = '0;
    assign m_axi_wvalid   = '0;
    assign m_axi_bready   = '0;
    assign m_axi_acready  = '0;

    // Program Counter
    logic [63:0] pc;
    logic [63:0] pc_plus_4;

    // IF Stage Outputs
    logic [31:0] instruction_if;
    logic        if_valid;

    // IF/ID Pipeline Register Outputs
    logic [31:0] instruction_id;
    logic [63:0] pc_id;
    logic        id_valid;

    // ID Stage Outputs
    logic [4:0]            wb_rd_id;
    logic [63:0]           wb_data_id;
    logic                  wb_enable_id;
    decoded_inst_t         decoded_inst_id;
    logic [63:0]           rs1_data_id;
    logic [63:0]           rs2_data_id;
    logic [63:0]           imm_id;
    logic                  alu_src_id;
    logic                  mem_read_id;
    logic                  mem_write_id;
    logic                  reg_write_id;

    // ID/EX Pipeline Register Outputs
    decoded_inst_t         decoded_inst_ex;
    logic [63:0]           rs1_data_ex;
    logic [63:0]           rs2_data_ex;
    logic [63:0]           imm_ex;
    logic                  alu_src_ex;
    logic                  mem_read_ex;
    logic                  mem_write_ex;
    logic                  reg_write_ex;

    // EXStage Outputs
    logic [63:0]           alu_result_ex;
    logic                  alu_zero_ex;
    logic                  mem_read_ex_mem;
    logic                  mem_write_ex_mem;
    logic                  reg_write_ex_mem;
    logic [4:0]            wb_rd_ex_mem;

    // Instantiate IFStage
    IFStage #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) if_stage (
        .clk(clk),
        .reset(reset),
        .pc_in(pc),
        .instruction_out(instruction_if),
        .pc_plus_4(pc_plus_4),
        .if_valid(if_valid),

        // AXI4 Read interface signals connected to top module's AXI read address channel
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    // Instantiate IF/ID Pipeline Register
    IF_ID if_id_inst (
        .clk(clk),
        .reset(reset),
        .instruction_in(instruction_if),
        .pc_in(pc),
        .valid_in(if_valid),
        .instruction_out(instruction_id),
        .pc_out(pc_id),
        .valid_out(id_valid)
    );

    // Instantiate IDStage
    IDStage id_stage (
        .clk(clk),
        .reset(reset),
        .instruction_in(instruction_id),
        .pc_in(pc_id),
        // Outputs to Regfile
        .wb_rd(wb_rd_id),
        .wb_data(wb_data_id),
        .wb_enable(wb_enable_id),
        // Outputs to Pipeline Register
        .decoded_inst(decoded_inst_id),
        .rs1_data(rs1_data_id),
        .rs2_data(rs2_data_id),
        .imm(imm_id),
        .alu_src(alu_src_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .reg_write(reg_write_id)
    );

    // Instantiate ID/EX Pipeline Register
    ID_EX id_ex_inst (
        .clk(clk),
        .reset(reset),
        .decoded_inst_in(decoded_inst_id),
        .rs1_data_in(rs1_data_id),
        .rs2_data_in(rs2_data_id),
        .imm_in(imm_id),
        .alu_src_in(alu_src_id),
        .mem_read_in(mem_read_id),
        .mem_write_in(mem_write_id),
        .reg_write_in(reg_write_id),
        .decoded_inst_out(decoded_inst_ex),
        .rs1_data_out(rs1_data_ex),
        .rs2_data_out(rs2_data_ex),
        .imm_out(imm_ex),
        .alu_src_out(alu_src_ex),
        .mem_read_out(mem_read_ex),
        .mem_write_out(mem_write_ex),
        .reg_write_out(reg_write_ex)
    );

    // Instantiate EXStage
    EXStage ex_stage (
        .clk(clk),
        .reset(reset),
        .decoded_inst_in(decoded_inst_ex),
        .rs1_data_in(rs1_data_ex),
        .rs2_data_in(rs2_data_ex),
        .imm_in(imm_ex),
        .alu_src_in(alu_src_ex),
        .mem_read_in(mem_read_ex),
        .mem_write_in(mem_write_ex),
        .reg_write_in(reg_write_ex),
        .alu_result_out(alu_result_ex),
        .alu_zero_out(alu_zero_ex),
        .mem_read_out(mem_read_ex_mem),
        .mem_write_out(mem_write_ex_mem),
        .reg_write_out(reg_write_ex_mem),
        .wb_rd_out(wb_rd_ex_mem)
    );

    // Instantiate Regfile in the top module
    Regfile regfile_inst (
        .clk(clk),
        .reset(reset),
        .initial_sp(stackptr),
        .rs1(decoded_inst_id.rs1),    // Correct connection to source register rs1
        .rs2(decoded_inst_id.rs2),    // Correct connection to source register rs2
        .rd1_data(rs1_data_id),
        .rd2_data(rs2_data_id),
        .rd(wb_rd_ex_mem),             // Destination register from EX/MEM stage
        .rd_data(alu_result_ex),       // ALU result from EX stage
        .write_enable(reg_write_ex_mem) // Write enable from EX/MEM stage
    );



    // Assign Regfile read data to IDStage outputs
    // Note: In this design, rs1 and rs2 are assumed to be fetched based on the decoded instruction's rs1 and rs2 fields
    // Ensure that the IDStage correctly provides rs1 and rs2 addresses to the Regfile
    // Adjust the connections if necessary based on your pipeline's design

    // Program Counter Update Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= entry;
            $display("Initializing top, entry point = 0x%x", entry);
        end else begin
            if (if_valid) begin
                pc <= pc_plus_4; // Update PC to next instruction
            end else begin
                pc <= pc; // Hold PC if instruction not valid
            end
        end
    end

    // Note: Ensure that the Regfile's rs1 and rs2 are correctly connected to the decoded instruction's rs1 and rs2
    // This may require additional signals or connections based on your pipeline's architecture

endmodule
