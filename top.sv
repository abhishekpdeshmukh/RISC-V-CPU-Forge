`include "Sysbus.defs"

module top
#(
  ID_WIDTH = 13,
  ADDR_WIDTH = 64,
  DATA_WIDTH = 64,
  STRB_WIDTH = DATA_WIDTH/8
)
(
  input  clk,
         reset,
         hz32768timer,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,
 
  // interface to connect to the bus
  output  wire [ID_WIDTH-1:0]    m_axi_awid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
  output  wire [7:0]             m_axi_awlen,
  output  wire [2:0]             m_axi_awsize,
  output  wire [1:0]             m_axi_awburst,
  output  wire                   m_axi_awlock,
  output  wire [3:0]             m_axi_awcache,
  output  wire [2:0]             m_axi_awprot,
  output  wire                   m_axi_awvalid,
  input   wire                   m_axi_awready,
  output  wire [DATA_WIDTH-1:0]  m_axi_wdata,
  output  wire [STRB_WIDTH-1:0]  m_axi_wstrb,
  output  wire                   m_axi_wlast,
  output  wire                   m_axi_wvalid,
  input   wire                   m_axi_wready,
  input   wire [ID_WIDTH-1:0]    m_axi_bid,
  input   wire [1:0]             m_axi_bresp,
  input   wire                   m_axi_bvalid,
  output  wire                   m_axi_bready,
  output  wire [ID_WIDTH-1:0]    m_axi_arid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_araddr,
  output  wire [7:0]             m_axi_arlen,
  output  wire [2:0]             m_axi_arsize,
  output  wire [1:0]             m_axi_arburst,
  output  wire                   m_axi_arlock,
  output  wire [3:0]             m_axi_arcache,
  output  wire [2:0]             m_axi_arprot,
  output  wire                   m_axi_arvalid,
  input   wire                   m_axi_arready,
  input   wire [ID_WIDTH-1:0]    m_axi_rid,
  input   wire [DATA_WIDTH-1:0]  m_axi_rdata,
  input   wire [1:0]             m_axi_rresp,
  input   wire                   m_axi_rlast,
  input   wire                   m_axi_rvalid,
  output  wire                   m_axi_rready,
  input   wire                   m_axi_acvalid,
  output  wire                   m_axi_acready,
  input   wire [ADDR_WIDTH-1:0]  m_axi_acaddr,
  input   wire [3:0]             m_axi_acsnoop
);

  // INSTRUCTION FETCH START 

  // Define the states of the FSM
  typedef enum logic [2:0] {
    IDLE        = 3'b000,
    FETCH       = 3'b001,
    WAIT        = 3'b010,
    DECODE      = 3'b011,
    DONE        = 3'b100
  } IF_state_t;

  IF_state_t current_state, next_state;

  // Define a register for the program counter
  logic [63:0] pc, pc_next;

  // Each beat of data contains two 32-bit instructions
  logic [31:0] cir_1, cir_2;

  // FSM State Transition Logic (sequential, update pc here)
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      pc <= entry;  // Initialize program counter with entry point
    end else begin
      current_state <= next_state;
      pc <= pc_next;
      if (current_state == WAIT && m_axi_rvalid) begin
        // Decode and print the instructions
        if (cir_1) begin
          decode_and_print(pc, cir_1);
        end
        if (cir_2) begin
          decode_and_print(pc + 4, cir_2);
        end
      end
    end
  end

  // FSM Next State and Output Logic
  always_comb begin
    // Default outputs
    // next_state = current_state;
    // m_axi_arvalid = 1'b0;
    // m_axi_rready = 1'b0;

    case (current_state)
      IDLE: begin
        next_state = FETCH;
      end
      
      FETCH: begin
        // Set up AXI read address
        m_axi_arid    = '0;               // Hardcoded id = 0
        m_axi_araddr  = pc;               // Set current program counter
        m_axi_arsize  = 3'b011;           // 64-bit transfer per beat
        m_axi_arlen   = 8'h07;;           // 8-beat transfer (64*8 = 512 bits per request)
        m_axi_arburst = 2'b10;            // Wrap burst
        m_axi_arlock  = 1'b0;             // Not locked tx (READ)
        m_axi_arcache = 4'b0011;          // Cacheable, bufferable
        m_axi_arprot  = 3'b000;           // Unprivileged, secure, data access
        m_axi_arvalid = 1'b1;             // Ready to initiate read

        if (m_axi_arready) begin
          next_state = WAIT;
        end
      end
      
      WAIT: begin
        // Ready to accept data
        m_axi_rready = 1'b1;
        m_axi_arvalid = 1'b0;
        if (m_axi_rvalid) begin
          // Each beat of data contains 64 bits (8 bytes)
          cir_1 = m_axi_rdata[31:0];   // Extract lower 32 bits
          cir_2 = m_axi_rdata[63:32];  // Extract upper 32 bits

          // Terminate the simulation when an all-zero (64'b0) response is received from memory
          if (m_axi_rdata == 64'b0) begin
            $finish;
          end

          // Increment PC by 8 for the 2 instructions read. 
          pc_next = pc + 8;

          // If the last beat of the burst has been received
          if (m_axi_rlast) begin
            next_state = DONE;
          end
        end
      end
      
      DONE: begin
        // Initiate new 64-byte read request
        m_axi_rready = 1'b0;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // INSTRUCTION FETCH END 

  // INSTRUCTION DECODE BEGIN

  logic [4:0]  rd, rs1, rs2;       // Destination and source registers
  logic [31:0] imm;                // Immediate value
  logic [6:0]  opcode;             // Opcode
  logic [2:0]  funct3;             // Funct3
  logic [6:0]  funct7;             // Funct7

  string mnemonic;

  

function void decode_and_print(logic [63:0] addr, logic [31:0] instr);
    // Extract instruction fields
    opcode = instr[6:0];
    rd     = instr[11:7];
    funct3 = instr[14:12];
    rs1    = instr[19:15];
    rs2    = instr[24:20];
    funct7 = instr[31:25];
    imm    = {{20{instr[31]}}, instr[31:20]}; // I-type immediate

    // Decode instruction
    case (opcode)
      7'b0110111: begin // LUI
        mnemonic = $sformatf("lui     %s,0x%x", get_reg_name(rd), instr[31:12]);
      end
      7'b0010111: begin // AUIPC
        mnemonic = $sformatf("auipc   %s,0x%x", get_reg_name(rd), instr[31:12]);
      end
      7'b1101111: begin // JAL
        logic signed [20:0] jal_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        mnemonic = $sformatf("jal     %s,0x%x", get_reg_name(rd), addr + jal_imm);
      end
      7'b1100111: begin // JALR
        mnemonic = $sformatf("jalr    %s", get_reg_name(rd));
      end
      7'b1100011: begin // Branch instructions
        logic signed [12:0] b_imm = {{7{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        case (funct3)
          3'b000: mnemonic = $sformatf("beqz    %s,0x%x", get_reg_name(rs1), addr + b_imm);
          3'b001: mnemonic = $sformatf("bnez    %s,0x%x", get_reg_name(rs1), addr + b_imm);
          3'b100: mnemonic = $sformatf("blt     %s,%s,0x%x", get_reg_name(rs1), get_reg_name(rs2), addr + b_imm);
          3'b101: mnemonic = $sformatf("bge     %s,%s,0x%x", get_reg_name(rs1), get_reg_name(rs2), addr + b_imm);
          3'b110: mnemonic = $sformatf("bltu    %s,%s,0x%x", get_reg_name(rs1), get_reg_name(rs2), addr + b_imm);
          3'b111: mnemonic = $sformatf("bgeu    %s,%s,0x%x", get_reg_name(rs1), get_reg_name(rs2), addr + b_imm);
          default: mnemonic = "unknown";
        endcase
      end
      7'b0000011: begin // Load instructions
        case (funct3)
          3'b000: mnemonic = $sformatf("lb      %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b001: mnemonic = $sformatf("lh      %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b010: mnemonic = $sformatf("lw      %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b011: mnemonic = $sformatf("ld      %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b100: mnemonic = $sformatf("lbu     %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b101: mnemonic = $sformatf("lhu     %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          3'b110: mnemonic = $sformatf("lwu     %s,%0d(%s)", get_reg_name(rd), $signed(imm), get_reg_name(rs1));
          default: mnemonic = "unknown";
        endcase
      end
      7'b0100011: begin // Store instructions
        logic signed [11:0] s_imm = {instr[31:25], instr[11:7]};
        case (funct3)
          3'b000: mnemonic = $sformatf("sb      %s,%0d(%s)", get_reg_name(rs2), $signed(s_imm), get_reg_name(rs1));
          3'b001: mnemonic = $sformatf("sh      %s,%0d(%s)", get_reg_name(rs2), $signed(s_imm), get_reg_name(rs1));
          3'b010: mnemonic = $sformatf("sw      %s,%0d(%s)", get_reg_name(rs2), $signed(s_imm), get_reg_name(rs1));
          3'b011: mnemonic = $sformatf("sd      %s,%0d(%s)", get_reg_name(rs2), $signed(s_imm), get_reg_name(rs1));
          default: mnemonic = "unknown";
        endcase
      end
      7'b0010011: begin // Immediate arithmetic instructions
        case (funct3)
          3'b000: mnemonic = $sformatf("addi    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b010: mnemonic = $sformatf("slti    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b011: mnemonic = $sformatf("sltiu   %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b100: mnemonic = $sformatf("xori    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b110: mnemonic = $sformatf("ori     %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b111: mnemonic = $sformatf("andi    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b001: mnemonic = $sformatf("slli    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]);
          3'b101: mnemonic = funct7[5] ? $sformatf("srai    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]) :
                                         $sformatf("srli    %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]);
          default: mnemonic = "unknown";
        endcase
      end
      7'b0110011: begin // Register arithmetic instructions
        case (funct3)
          3'b000: mnemonic = funct7[5] ? $sformatf("sub     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2)) :
                                         $sformatf("add     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b001: mnemonic = $sformatf("sll     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b010: mnemonic = $sformatf("slt     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b011: mnemonic = $sformatf("sltu    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b100: mnemonic = $sformatf("xor     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b101: mnemonic = funct7[5] ? $sformatf("sra     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2)) :
                                         $sformatf("srl     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b110: mnemonic = $sformatf("or      %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b111: mnemonic = $sformatf("and     %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          default: mnemonic = "unknown";
        endcase
      end
      7'b0011011: begin // RISC-V 64-bit specific instructions
        case (funct3)
          3'b000: mnemonic = $sformatf("addiw   %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), $signed(imm));
          3'b001: mnemonic = $sformatf("slliw   %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]);
          3'b101: mnemonic = funct7[5] ? $sformatf("sraiw   %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]) :
                                         $sformatf("srliw   %s,%s,%0d", get_reg_name(rd), get_reg_name(rs1), instr[24:20]);
          default: mnemonic = "unknown";
        endcase
      end
      7'b0111011: begin // RISC-V 64-bit specific register-register instructions
        case (funct3)
          3'b000: mnemonic = funct7[5] ? $sformatf("subw    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2)) :
                                         $sformatf("addw    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b001: mnemonic = $sformatf("sllw    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          3'b101: mnemonic = funct7[5] ? $sformatf("sraw    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2)) :
                                         $sformatf("srlw    %s,%s,%s", get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
          default: mnemonic = "unknown";
        endcase
      end
      default: mnemonic = "unknown";
    endcase

    // Special cases and pseudo-instructions
    if (instr == 32'h00000013) mnemonic = "nop";
    if (instr == 32'h00008067) mnemonic = "ret";
    if (opcode == 7'b0010011 && funct3 == 3'b000 && rs1 == 5'b00000) mnemonic = $sformatf("li      %s,%0d", get_reg_name(rd), $signed(imm));
    if (opcode == 7'b0010011 && funct3 == 3'b000 && imm == 12'b0) mnemonic = $sformatf("mv      %s,%s", get_reg_name(rd), get_reg_name(rs1));

    // Print the decoded instruction
    $display("   %h:\t%s", addr, mnemonic);
  endfunction







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
