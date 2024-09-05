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


  // BEGIN INSTRUCTION FETCH STAGE

  // State definition
  typedef enum logic [2:0] {
    IDLE,
    FETCH,
    WAIT,
    DECODE,
    DONE
  } IF_state_t;

  IF_state_t current_state, next_state;

  logic [63:0] pc, pc_next;       // Program Counter 
  logic [31:0] curr_instruction, curr_instruction_1;  // Fetched Instruction (internal)
  string out,out_next;
  logic [4:0] rd, rs1, rs2;       // Destination and source registers
  logic [31:0] imm;               // Immediate value
  logic [6:0] opcode;             // Opcode
  logic [2:0] funct3;             // Funct3
  logic [6:0] funct7;             // Funct7
  logic fetch_done;        // Internal signal to indicate fetch completion
  logic decode_done;
  // State transition and sequential logic
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      pc <= entry;
      $display("Entry = %d", entry);
    end else begin
      pc <= pc_next;
      current_state <= next_state;  // Update state
      if (fetch_done) begin
        // "terminate the simulation when an all-zero (64'b0) response is received from memory"
        if (curr_instruction == 64'b0 || curr_instruction_1 == 64'b0) begin
          $finish;
        end else begin
          $display("Fetched Instruction %3d 0x%x PC: 0x%x ", pc/4 + 1, curr_instruction, pc);
          $display("Fetched Instruction %3d 0x%x PC: 0x%x ", pc/4 + 2, curr_instruction_1, pc+4);
        end
      end
      if (decode_done) begin
        out_next <= out;
        $display("%s\n", out_next); 
        
      end
    end
  end

  // Instruction fetch FSM state logic 
  always_comb begin
    // Default outputs
    next_state = current_state;
    out = "";
    m_axi_arvalid = 1'b0;
    m_axi_rready = 1'b0;
    fetch_done = 1'b0;
    decode_done = 1'b0;
    pc_next = pc; // Default to hold current PC value

    case (current_state)
      IDLE: begin
        // Start fetching immediately after reset
        next_state = FETCH;
      end

      FETCH: begin
        m_axi_arvalid = 1'b1;
        m_axi_araddr = pc;
        m_axi_arsize = 3'b011;      // 64-bit transfer
        m_axi_arlen  = 8'd7;        // 8-beat transfer
        m_axi_arburst = 2'b10;      // Wrap burst
        //$display("FETCH!");

        if (m_axi_arready && m_axi_arvalid) begin
            // Only move to WAIT if the request has been accepted
            next_state = WAIT;
        end else begin
            // Stay in FETCH until the request is accepted
            next_state = FETCH;
        end
      end

      WAIT: begin
        m_axi_rready = 1'b1;

        if (m_axi_rvalid && m_axi_rlast) begin
            next_state = DONE; // Move to DECODE state
        end else begin
            next_state = WAIT; // Remain in WAIT until the transaction is complete
        end
      end

      DECODE: begin
        // Decode the instruction based on RISC-V format
        opcode = curr_instruction[6:0];
        rd     = curr_instruction[11:7];
        funct3 = curr_instruction[14:12];
        rs1    = curr_instruction[19:15];
        rs2    = curr_instruction[24:20];
        funct7 = curr_instruction[31:25];
        decode_done = 1'b1;
        case (opcode)
          7'b0110011: begin // R-type
            case (funct3)
              3'b000: out = $sformatf("ADD %0d", rd);
              3'b111: out = $sformatf("AND %0d", rd);
              3'b110: out = $sformatf("OR %0d", rd);
              // Add other R-type instructions as needed
              
              default: out = $sformatf("Unknown R-type Instruction");
            endcase
          end
          7'b0010011: begin // I-type
            imm = curr_instruction[31:20];
            case (funct3)
              3'b000: out = $sformatf("ADDI %0d", rd);
              3'b111: out = $sformatf("ANDI %0d", rd);
              3'b110: out = $sformatf("ORI %0d", rd);
              // Add other I-type instructions as needed
              default: out = $sformatf("Unknown I-type Instruction");
            endcase
          end
          7'b0000011: begin // Load (I-type)
            imm = curr_instruction[31:20];
            case (funct3)
              3'b010: out = $sformatf("LW %0d", rd);
              3'b000: out = $sformatf("LB %0d", rd);
              3'b001: out = $sformatf("LH %0d", rd);
              // Add other load instructions as needed
              default: out = $sformatf("Unknown Load Instruction");
            endcase
          end
          7'b1100111: begin // JALR (I-type)
            imm = curr_instruction[31:20];
            imm = curr_instruction[31:20];
            // Example: JALR rd, imm(rs1)
            out = $sformatf("JALR %0d", rd);
          end
          7'b0100011: begin // S-type (Store)
            imm = {curr_instruction[31:25], curr_instruction[11:7]};
            case (funct3)
              3'b010: out = $sformatf("SW (no rd)");
              3'b000: out = $sformatf("SB (no rd)");
              3'b001: out = $sformatf("SH (no rd)");
              // Add other store instructions as needed
              default: out = $sformatf("Unknown Store Instruction");
            endcase
          end
          7'b1100011: begin // B-type (Branch)
            imm = {curr_instruction[31], curr_instruction[7], curr_instruction[30:25], curr_instruction[11:8]};
            case (funct3)
              3'b000: out = $sformatf("BEQ (no rd)");
              3'b001: out = $sformatf("BNE (no rd)");
              3'b100: out = $sformatf("BLT (no rd)");
              3'b101: out = $sformatf("BGE (no rd)");
              default: out = $sformatf("Unknown Store Instruction");
            endcase
          end
          7'b1101111: begin // J-type (JAL)
            imm = {curr_instruction[31], curr_instruction[19:12], curr_instruction[20], curr_instruction[30:21]};
            out = $sformatf("JAL %0d", rd);
          end
          default: begin
            out = $sformatf("Unknown Instruction: 0x%x", curr_instruction);
            decode_done = 1'b0;
          end
          
        endcase

        // Move to the DONE state after decoding
        next_state = FETCH;
      end

      DONE: begin

        fetch_done = 1'b1;             // Signal that fetch is done
        // Instruction fetched, go to IDLE or FETCH based on system design
        next_state = DECODE;
        pc_next = pc + 8;  // Move to the next instruction
        next_state = DECODE;
        curr_instruction = m_axi_rdata[31:0];
        curr_instruction_1 = m_axi_rdata[63:32];
        
      end

      default: 
        next_state = IDLE;
    endcase
  end

  // END INSTRUCTION FETCH STAGE

  // END INSTRUCTION DECODE STAGE

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end

endmodule
