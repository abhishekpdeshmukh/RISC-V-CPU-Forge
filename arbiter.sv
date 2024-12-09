module Arbiter #(
    parameter ID_WIDTH   = 13,
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64
)(
    input  logic                 clk,
    input  logic                 reset,

    input  logic                 icache_arvalid,
    input  logic [ADDR_WIDTH-1:0] icache_araddr,
    output logic                 icache_arready,
    output logic                 icache_rvalid,
    output logic [DATA_WIDTH-1:0] icache_rdata,
    output logic                 icache_rlast,
    input  logic                 icache_rready,

    input  logic                 dcache_arvalid,
    input  logic [ADDR_WIDTH-1:0] dcache_araddr,
    output logic                 dcache_arready,
    output logic                 dcache_rvalid,
    output logic [DATA_WIDTH-1:0] dcache_rdata,
    output logic                 dcache_rlast,
    input  logic                 dcache_rready,

   
    output logic [ID_WIDTH-1:0]   m_axi_arid,
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]            m_axi_arlen,
    output logic [2:0]            m_axi_arsize,
    output logic [1:0]            m_axi_arburst,
    output logic                  m_axi_arlock,
    output logic [3:0]            m_axi_arcache,
    output logic [2:0]            m_axi_arprot,
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,

    input  logic [ID_WIDTH-1:0]   m_axi_rid,
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready

);

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        MISS,
        REFILL
    } arbiter_state_t;

    arbiter_state_t current_state, next_state;

    logic [ADDR_WIDTH-1:0] selected_araddr;
    logic servicing_icache;  

    assign m_axi_arid     = '0;
    assign m_axi_arlen    = 8'd7;        
    assign m_axi_arsize   = 3'd3;        
    assign m_axi_arburst  = 2'b10;      
    assign m_axi_arlock   = 1'b0;
    assign m_axi_arcache  = 4'b0011;
    assign m_axi_arprot   = 3'b000;

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (icache_arvalid || dcache_arvalid) begin
                    next_state = MISS;
                end
            end
            MISS: begin
                if (m_axi_arvalid && m_axi_arready) begin
                    next_state = REFILL;
                end
            end
            REFILL: begin
                if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state     <= IDLE;
            servicing_icache  <= 1'b0;
            m_axi_arvalid     <= 1'b0;
            m_axi_araddr      <= '0;
            m_axi_rready      <= 1'b0;
            icache_arready    <= 1'b0;
            dcache_arready    <= 1'b0;
            icache_rvalid     <= 1'b0;
            dcache_rvalid     <= 1'b0;
            icache_rdata      <= '0;
            dcache_rdata      <= '0;
            icache_rlast      <= 1'b0;
            dcache_rlast      <= 1'b0;
        end else begin
            current_state <= next_state;

    
            m_axi_arvalid <= m_axi_arvalid;
            m_axi_araddr  <= m_axi_araddr;
            m_axi_rready  <= m_axi_rready;
            icache_arready <= 1'b0;
            dcache_arready <= 1'b0;
            icache_rvalid  <= 1'b0;
            dcache_rvalid  <= 1'b0;
            icache_rlast   <= 1'b0;
            dcache_rlast   <= 1'b0;

            case (current_state)
                IDLE: begin
                  
                    if (icache_arvalid) begin
                        servicing_icache <= 1'b1;
                        icache_arready   <= 1'b1;
                        selected_araddr  <= icache_araddr;
                        m_axi_arvalid    <= 1'b1;
                        m_axi_araddr     <= icache_araddr;
                        m_axi_rready     <= icache_rready;
                    end else if (dcache_arvalid) begin
                        servicing_icache <= 1'b0;
                        dcache_arready   <= 1'b1;
                        selected_araddr  <= dcache_araddr;
                        m_axi_arvalid    <= 1'b1;
                        m_axi_araddr     <= dcache_araddr;
                        m_axi_rready     <= dcache_rready;
                    end else begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b0;
                    end
                end
                MISS: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                    end
                end
                REFILL: begin
                    m_axi_rready <= 1'b1;
                    if (m_axi_rvalid && m_axi_rready) begin

                        if (servicing_icache) begin
                            icache_rvalid <= 1'b1;
                            icache_rdata  <= m_axi_rdata;
                            icache_rlast  <= m_axi_rlast;
                        end else begin
                            dcache_rvalid <= 1'b1;
                            dcache_rdata  <= m_axi_rdata;
                            dcache_rlast  <= m_axi_rlast;
                        end

                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                        end else begin
                            m_axi_rready <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
