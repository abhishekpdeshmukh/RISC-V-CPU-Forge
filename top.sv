`include "Sysbus.defs"
`include "decoder.sv"
`include "regfile.sv"
`include "alu.sv"


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
  typedef enum logic [3:0] {
      IDLE        = 4'b0000,
      FETCH       = 4'b0001,
      DECODE      = 4'b0010,
      REG_READ    = 4'b0011,
      EXECUTE     = 4'b0100,
      REG_WRITE   = 4'b0101,
      DONE        = 4'b0110
  } IF_state_t;


  IF_state_t current_state, next_state;

  // Define a register for the program counter
  logic [63:0] pc, pc_next;

  // Each beat of data contains two 32-bit instructions
  logic [31:0] cir_1, cir_2, cir;
   logic flag;

  decoded_inst_t decoded_instr;
  string decoded_str;

  Decode u_decode (
      .addr(pc),
      .instr(cir),                // Choose instruction to decode
      .out_instr(decoded_instr),  // Decoded instruction string
      .out_str(decoded_str)  // Decoded instruction string
    );

  // New wp2 signals
  logic [63:0] rs1_data, rs2_data, alu_result;
  logic [3:0] alu_op;
  logic alu_zero;
  logic reg_write;

  // Instantiate RegisterFile
  RegisterFile u_regfile (
      .clk(clk),
      .rst(reset),
      .rs1_addr(decoded_instr.rs1),
      .rs2_addr(decoded_instr.rs2),
      .rd_addr(decoded_instr.rd),
      .rd_data(alu_result),
      .rd_write(reg_write),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data)
  );

  // Instantiate ALU
  ALU u_alu (
      .a(rs1_data),
      .b(rs2_data),
      .instr(decoded_instr),
      .result(alu_result),
      .zero(alu_zero)
  );

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      pc <= entry;  // Initialize program counter with entry point
      flag <= 1'b0;
    end else begin
      current_state <= next_state;
      pc <= pc_next;
      
      if (current_state == DECODE && m_axi_rvalid) begin
          $display("   %h:\t   %h\t%s", pc, cir, decoded_str); 
          flag <= ~flag;
      end
    end
  end

  // FSM Next State and Output Logic
  // logic flag;
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
          next_state = DECODE;
          m_axi_rready = 1'b1;
        end
        
      end
      
      DECODE: begin

        m_axi_arvalid = 1'b0; // Deassert arvalid after handshake
        reg_write = 1'b0;
        if (m_axi_rvalid) begin

          if(!flag) begin
            cir = m_axi_rdata[31:0];
            m_axi_rready = 1'b0;
          end
          else begin
            //$display("aka 2");
            cir = m_axi_rdata[63:32]; 
            m_axi_rready = 1'b1; // Ready to accept data
            
          end
          pc_next = pc + 4;

          // Terminate the simulation when an all-zero (64'b0) response is received from memory
          if (m_axi_rdata == 64'b0) begin
            u_regfile.get_reg_values();
            $finish;
          end

          m_axi_rready = 1'b0;
          next_state = REG_READ;
        end
      end

      REG_READ: begin
          // Read from register file
          next_state = EXECUTE;
      end
      EXECUTE: begin
          // Set ALU operation based on instruction

          next_state = REG_WRITE;
      end
      REG_WRITE: begin
          reg_write = 1'b1;
          if(!flag) begin
            m_axi_rready = 1'b1;
          end 
          if (m_axi_rlast && !flag) begin
            next_state = DONE;
          end
          else begin
            next_state = DECODE;
          end
      end

      DONE: begin
        // Initiate new 64-byte read request
        m_axi_rready = 1'b0;
        reg_write = 1'b0;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end







  endmodule
