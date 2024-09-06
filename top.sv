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
    DECODE      = 3'b011,   //TODO: remove this state we if we are moving decode to new FSM
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
        // Print the instructions
        if (cir_1)
          $display("PC 0x%x: Instruction 0x%x ", pc, cir_1);
        if (cir_2)
          $display("PC 0x%x: Instruction 0x%x ", pc+4, cir_2);
      end
    end
  end

  // FSM Next State and Output Logic
  always_comb begin

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

        m_axi_arvalid = 1'b0; // Deassert arvalid after handshake
        m_axi_rready = 1'b1;  // Ready to accept data
        
        if (m_axi_rvalid) begin

          // Each beat of data contains 64 bits (8 bytes)
          cir_1 = m_axi_rdata[31:0];   // Extract lower 32 bits
          cir_2 = m_axi_rdata[63:32];  // Extract upper 32 bits

          // Terminate the simulation when an all-zero (64'b0) response is received from memory
          if (m_axi_rdata == 64'b0) begin
            $finish;
          end

          // Increment PC by 8 for the 2 instructions read. 
          // However it's only used to initiate a new read request 
          // after m_axi_rlast=1 (for next 64 bytes)
          pc_next = pc + 8;

          // If the last beat of the burst has been received
          if (m_axi_rlast) begin
            next_state = DONE;
          end
        end
      end
      
      DONE: begin
        // De-assert m_axi_rready until next 64-byte read request
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

  string out;
  
  // INSTRUCTION DECODE END  

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end

endmodule
