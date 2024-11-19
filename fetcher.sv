module ICache #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64,
    parameter CACHE_LINE_SIZE = 512, // 64 bytes
    parameter NUMBER_OF_SETS = 512,
    parameter NUMBER_OF_WAYS = 2,
    parameter ID_WIDTH = 13
)(
    input  logic                  clk,
    input  logic                  reset,
    input  logic [ADDR_WIDTH-1:0] address_in,
    output logic [31:0]           instruction_out,
    output logic                  valid_out,

    // AXI4 Read Address Channel
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

    // AXI4 Read Data Channel
    input  logic [ID_WIDTH-1:0]   m_axi_rid,
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready,

    // **New Control Inputs**
    input  logic                  flush,  // High to flush current cache line
    input  logic                  stall   // High to stall cache operations
);

// Cache line structure
typedef struct packed {
    logic                       valid;
    logic [48:0]                tag; // 49 bits (ADDR_WIDTH - 6 - 9)
    logic [CACHE_LINE_SIZE-1:0] data; // Cache line data (512 bits)
} cache_line_t;

// Cache storage
cache_line_t cache [0:NUMBER_OF_SETS-1][0:NUMBER_OF_WAYS-1];

// LRU bits for each set (1 bit for 2-way set-associative)
logic lru [0:NUMBER_OF_SETS-1];

// Extract address fields
localparam INDEX_BITS = 9; // For 512 sets
localparam OFFSET_BITS = 6; // For 64 bytes cache line
localparam TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS; // 64 - 6 - 9 = 49
logic [OFFSET_BITS-1:0]  offset; // Bits [5:0]
logic [INDEX_BITS-1:0]   index;  // Bits [14:6]
logic [TAG_BITS-1:0]     tag;    // Bits [63:15]

assign offset = address_in[OFFSET_BITS-1:0]; // Bits [5:0]
assign index  = address_in[OFFSET_BITS +: INDEX_BITS]; // Bits [6 +: 9]
assign tag    = address_in[ADDR_WIDTH-1 -: TAG_BITS]; // Bits [63 -: 49]

// Cache hit signals
logic hit_way0, hit_way1;
logic [1:0] hit;

// FSM States with Flush and Stall
typedef enum logic [2:0] {
    IDLE,
    MISS,
    REFILL,
    COPY,
    FLUSH,  // New state for handling flush
    STALL   // New state for handling stall
} cache_state_t;

cache_state_t current_state, next_state;

// Read data buffer
logic [CACHE_LINE_SIZE-1:0] refill_data; // 512-bit vector
integer beat_counter;

// Control signals
logic need_refill;
logic lru_way;

// Initialize constant outputs
assign m_axi_arid    = '0;
assign m_axi_arlen   = 8'd7;           // 8 beats for 512 bits (64 bytes)
assign m_axi_arsize  = 3'd3;           // 64-bit transfers (8 bytes per beat)
assign m_axi_arburst = 2'b10;          // WRAP burst type
assign m_axi_arlock  = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot  = 3'b000;

// Edge detection for flush
logic flush_prev;
logic flush_rising_edge;

// Edge detection logic for flush
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        flush_prev <= 1'b0;
    end else begin
        flush_prev <= flush;
    end
end

assign flush_rising_edge = flush && !flush_prev;

// Cache lookup
always_comb begin
    hit_way0 = cache[index][0].valid && (cache[index][0].tag == tag);
    hit_way1 = cache[index][1].valid && (cache[index][1].tag == tag);
    hit = {hit_way1, hit_way0};
    need_refill = ~(hit_way0 | hit_way1);
end

// Instruction output
always_comb begin
    if (hit_way0) begin
        instruction_out = cache[index][0].data[(offset * 8) +: 32];
        valid_out = 1'b1;
    end else if (hit_way1) begin
        instruction_out = cache[index][1].data[(offset * 8) +: 32];
        valid_out = 1'b1;
    end else begin
        instruction_out = 32'b0;
        valid_out = 1'b0;
    end
end

// Compute next_state combinationally
always_comb begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (flush_rising_edge) begin
                next_state = FLUSH;
            end else if (need_refill && !stall) begin
                next_state = MISS;
            end else if (stall) begin
                next_state = STALL;
            end
        end
        MISS: begin
            if (flush_rising_edge) begin
                next_state = FLUSH;
            end else if (m_axi_arready && m_axi_arvalid) begin
                next_state = REFILL;
            end
        end
        REFILL: begin
            if (flush_rising_edge) begin
                next_state = FLUSH;
            end else if (m_axi_rvalid && m_axi_rready) begin
                if (m_axi_rlast) begin
                    next_state = COPY;
                end
            end
        end
        COPY: begin
            if (flush_rising_edge) begin
                next_state = FLUSH;
            end else if (stall) begin
                next_state = STALL;
            end else begin
                next_state = IDLE;
            end
        end
        FLUSH: begin
            // After flushing, return to IDLE
            next_state = IDLE;
        end
        STALL: begin
            if (!stall) begin
                // Resume previous operation
                if (need_refill) begin
                    next_state = MISS;
                end else begin
                    next_state = IDLE;
                end
            end
        end
        default: next_state = IDLE;
    endcase
end

// FSM for cache control and AXI read
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        current_state <= IDLE;
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;
        beat_counter  <= 0;

        // Reset LRU and cache contents
        for (int i = 0; i < NUMBER_OF_SETS; i++) begin
            lru[i] = 1'b0;
            for (int j = 0; j < NUMBER_OF_WAYS; j++) begin
                cache[i][j].valid = 1'b0;
                cache[i][j].tag   = '0;
                cache[i][j].data  = '0;
            end
        end
    end else begin
        current_state <= next_state;

        case (current_state)
            IDLE: begin
                if (flush_rising_edge) begin
                    // Invalidate the current cache line being fetched
                    for (int j = 0; j < NUMBER_OF_WAYS; j++) begin
                        cache[index][j].valid <= 1'b0;
                    end
                    $display("ICache: Flush initiated. Cache lines invalidated for index %d.", index);
                end else if (need_refill && !stall) begin
                    m_axi_araddr  <= {tag, index, {OFFSET_BITS{1'b0}}}; // Correctly align to cache line
                    m_axi_arvalid <= 1'b1;
                    m_axi_arsize  <= 3'b011;  // 64-bit transfer per beat
                    m_axi_arlen   <= 8'h07;   // 8-beat transfer for 512 bits
                    m_axi_arburst <= 2'b10;   // WRAP burst type
                    m_axi_arlock  <= 1'b0;
                    m_axi_arcache <= 4'b0011;
                    m_axi_arprot  <= 3'b000;
                    $display("ICache: Initiating AXI read burst at address 0x%h.", {tag, index, {OFFSET_BITS{1'b0}}});
                end

                if (m_axi_arready && m_axi_arvalid) begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b1;
                    beat_counter  <= 0;
                    refill_data   <= '0;
                end
            end

            MISS: begin
                if (flush_rising_edge) begin
                    // Invalidate cache lines during MISS
                    for (int j = 0; j < NUMBER_OF_WAYS; j++) begin
                        cache[index][j].valid <= 1'b0;
                    end
                    $display("ICache: Flush during MISS. Cache lines invalidated for index %d.", index);
                end else if (m_axi_arready && m_axi_arvalid) begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b1;
                    beat_counter  <= 0;
                    refill_data   <= '0;
                end
            end

            REFILL: begin
                if (flush_rising_edge) begin
                    // Handle flush during REFILL by discarding fetched data
                    refill_data <= '0;
                    m_axi_rready  <= 1'b0;
                    $display("ICache: Flush during REFILL. Discarding fetched data.");
                end else if (m_axi_rvalid && m_axi_rready) begin
                    int bit_position = beat_counter * DATA_WIDTH;
                    refill_data[bit_position +: DATA_WIDTH] <= m_axi_rdata;
                    $display("ICache: Received data beat %0d at bit position %0d: 0x%h", beat_counter, bit_position, m_axi_rdata);
                    beat_counter <= beat_counter + 1;
                    if (m_axi_rdata == 64'b0) begin
                        $finish;
                    end
                end
            end

            COPY: begin
                if (flush_rising_edge) begin
                    // Handle flush during COPY by discarding data
                    refill_data <= '0;
                    m_axi_rready  <= 1'b0;
                    $display("ICache: Flush during COPY. Discarding fetched data.");
                end else if (stall) begin
                    // Hold the COPY state if stalled
                    $display("ICache: Stall during COPY. Holding state.");
                end else begin
                    m_axi_rready <= 1'b0;

                    // Update cache line
                    lru_way = lru[index];
                    cache[index][lru_way].valid <= 1'b1;
                    cache[index][lru_way].tag   <= tag;
                    cache[index][lru_way].data  <= refill_data;
                    // Update LRU
                    lru[index] <= ~lru_way;

                    $display("ICache: Cache line updated at index %0d, way %0d with tag 0x%h.", index, lru_way, tag);
                end
            end

            FLUSH: begin
                // Reset refill data and AXI signals
                refill_data   <= '0;
                m_axi_arvalid <= 1'b0;
                m_axi_rready  <= 1'b0;
                beat_counter  <= 0;
                $display("ICache: Flush completed. Returning to IDLE state.");
            end

            STALL: begin
                // Maintain current cache state without initiating new operations
                m_axi_arvalid <= 1'b0;
                m_axi_rready  <= 1'b0;
                $display("ICache: Stall active. Maintaining current state.");
            end

            default: begin
                // Default behavior
                next_state = IDLE;
            end
        endcase
    end
end

// Update LRU on cache hit
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // LRU and cache are already reset in the FSM block
    end else begin
        if (current_state != FLUSH && current_state != STALL) begin
            if (hit_way0) begin
                lru[index] <= 1'b1; // Way 0 was used; mark way 1 as LRU
                $display("ICache: LRU updated for index %0d: Way 0 accessed.", index);
            end else if (hit_way1) begin
                lru[index] <= 1'b0; // Way 1 was used; mark way 0 as LRU
                $display("ICache: LRU updated for index %0d: Way 1 accessed.", index);
            end
        end
    end
end

endmodule


// IFStage Module with Flush and Stall Support
module IFStage #(
    parameter ID_WIDTH    = 13,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter STRB_WIDTH  = DATA_WIDTH / 8
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
    output logic                   m_axi_rready,

    // **Control Inputs**
    input  logic                   flush,      // High to flush current fetch
    input  logic                   stall       // High to stall the fetcher
);

    // Instantiate ICache with Flush and Stall
    ICache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_LINE_SIZE(512),
        .NUMBER_OF_SETS(512),
        .NUMBER_OF_WAYS(2),
        .ID_WIDTH(ID_WIDTH)
    ) icache_inst (
        .clk(clk),
        .reset(reset),
        .address_in(pc_in),
        .instruction_out(instruction_out),
        .valid_out(if_valid),

        // AXI Interface
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
        .m_axi_rready(m_axi_rready),

        // **Connect Control Inputs**
        .flush(flush),
        .stall(stall)
    );

    // PC Update Logic with Flush and Stall Considerations
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_plus_4 <= pc_in;
        end else begin
            if (flush) begin
                // If flush is asserted, set pc_plus_4 to a target address
                // Modify as per your flush logic (e.g., jump to syscall handler)
                pc_plus_4 <= pc_in + 64'd4; // Example: simple increment
                $display("IFStage: Flush active. PC_plus_4 set to 0x%h.", pc_plus_4);
            end else if (!stall && if_valid) begin
                pc_plus_4 <= pc_in + 64'd4;
                $display("IFStage: PC: 0x%h PC_plus_4 updated to 0x%h.", pc_in, pc_plus_4);
            end else begin
                // Hold PC_plus_4 if stalled or instruction not valid
                pc_plus_4 <= pc_plus_4;
                $display("IFStage: PC_plus_4 held at 0x%h.", pc_plus_4);
            end
        end
    end

endmodule


