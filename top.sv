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
  typedef enum logic [1:0] {
    IDLE,
    FETCH,
    WAIT,
    DONE
  } IF_state_t;

  IF_state_t current_state, next_state;

  logic [63:0] pc, pc_next;       // Program Counter 
  logic [31:0] curr_instruction;  // Fetched Instruction (internal)
  logic        fetch_done;        // Internal signal to indicate fetch completion

  // State transition and sequential logic
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      pc <= entry;
      $display("Entry = %d", entry);
    end else begin
      pc <= pc_next;
      current_state <= next_state;  // Update state
    end
  end

  // Instruction fetch FSM state logic 
  // TODO - things break when I change below assignments from blocking to non-blocking. But always_ff assignments need to be non-blocking?
  always_ff @(posedge clk) begin
    // Default outputs
    next_state = current_state;
    m_axi_arvalid = 0;
    m_axi_rready = 0;
    fetch_done = 0;

    case (current_state)
      IDLE: begin
        // Start fetching immediately after reset
        next_state = FETCH;
        // $display("IDLE!");
      end

      FETCH: begin
        m_axi_arvalid = 1;
        m_axi_araddr = pc;
        m_axi_arsize = 3'b010;      // 32-bit transfer
        m_axi_arlen  = 8'd7;        // 8-beat transfer
        m_axi_arburst = 2'b10;      // Wrap burst
        $display("FETCH!");

        if (m_axi_arready && m_axi_arvalid) begin
            // Only move to WAIT if the request has been accepted
            next_state = WAIT;
            // $display("Moving to WAIT state");
        end else begin
            // Stay in FETCH until the request is accepted
            // $display("Stay in WAIT state");
            next_state = FETCH;
        end
      end

      WAIT: begin
        m_axi_rready = 1;
        // $display("WAIT!");

        if (m_axi_rvalid && m_axi_rlast) begin
            fetch_done = 1;             // Signal that fetch is done
            next_state = DONE;
            //$display("Going to DONE!");
        end else begin
            next_state = WAIT; // Remain in WAIT until the transaction is complete
            //$display("REMAIN WAIT!");
        end
      end


      DONE: begin
        // "terminate the simulation when an all-zero (64'b0) response is received from memory"
        if (m_axi_rdata == 64'b0)
          $finish;

        // Instruction fetched, go to IDLE or FETCH based on system design
        pc_next = pc + 4;  // Move to the next instruction
        next_state = IDLE;
        curr_instruction = m_axi_rdata;
        //$display("DONE!");
        $display("Fetched Instruction %3d 0x%x PC: 0x%x ", pc/4, curr_instruction, pc);

      end

      default: 
        next_state = IDLE;
    endcase
  end

  // END INSTRUCTION FETCH STAGE

  // BEGIN INSTRUCTION DECODE STAGE
  // END INSTRUCTION DECODE STAGE

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
