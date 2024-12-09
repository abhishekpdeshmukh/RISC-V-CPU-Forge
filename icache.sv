module ICache #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64,
    parameter CACHE_LINE_SIZE = 512, 
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

    input  logic [ID_WIDTH-1:0]   m_axi_rid,
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready,

    input  logic                  flush,  
    input  logic                  stall   
);

    typedef struct packed {
        logic                       valid;
        logic [48:0]                tag; 
        logic [CACHE_LINE_SIZE-1:0] data; 
    } cache_line_t;

    cache_line_t cache [0:NUMBER_OF_SETS-1][0:NUMBER_OF_WAYS-1];

    logic lru [0:NUMBER_OF_SETS-1];

    localparam INDEX_BITS = 9; 
    localparam OFFSET_BITS = 6; 
    localparam TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS; 
    logic [OFFSET_BITS-1:0]  offset; 
    logic [INDEX_BITS-1:0]   index;  
    logic [TAG_BITS-1:0]     tag;    

    assign offset = address_in[OFFSET_BITS-1:0]; 
    assign index  = address_in[OFFSET_BITS +: INDEX_BITS]; 
    assign tag    = address_in[ADDR_WIDTH-1 -: TAG_BITS]; 

    logic hit_way0, hit_way1;
    logic [1:0] hit;

    typedef enum logic [2:0] {
        IDLE,
        MISS,
        REFILL,
        COPY,
        FLUSH,  
        STALL   
    } cache_state_t;

    cache_state_t current_state, next_state;

    logic [CACHE_LINE_SIZE-1:0] refill_data; 
    integer beat_counter;

    logic need_refill;
    logic lru_way;

    assign m_axi_arid    = '0;
    assign m_axi_arlen   = 8'd7;          
    assign m_axi_arsize  = 3'd3;          
    assign m_axi_arburst = 2'b10;        
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;

    logic flush_prev;
    logic flush_rising_edge;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            flush_prev <= 1'b0;
        end else begin
            flush_prev <= flush;
        end
    end

    assign flush_rising_edge = flush && !flush_prev;

    always_comb begin
        hit_way0 = cache[index][0].valid && (cache[index][0].tag == tag);
        hit_way1 = cache[index][1].valid && (cache[index][1].tag == tag);
        hit = {hit_way1, hit_way0};
        need_refill = ~(hit_way0 | hit_way1);
    end

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
                next_state = IDLE;
            end
            STALL: begin
                if (!stall) begin

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

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            beat_counter  <= 0;

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

                        for (int j = 0; j < NUMBER_OF_WAYS; j++) begin
                            cache[index][j].valid <= 1'b0;
                        end
                        //$display("ICache: Flush initiated. Cache lines invalidated for index %d.", index);
                    end else if (need_refill && !stall) begin
                        m_axi_araddr  <= {tag, index, {OFFSET_BITS{1'b0}}}; 
                        m_axi_arvalid <= 1'b1;
                        m_axi_arsize  <= 3'b011;  
                        m_axi_arlen   <= 8'h07;  
                        m_axi_arburst <= 2'b10;  
                        m_axi_arlock  <= 1'b0;
                        m_axi_arcache <= 4'b0011;
                        m_axi_arprot  <= 3'b000;
                        //$display("ICache: Initiating AXI read burst at address 0x%h.", {tag, index, {OFFSET_BITS{1'b0}}});
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

                        for (int j = 0; j < NUMBER_OF_WAYS; j++) begin
                            cache[index][j].valid <= 1'b0;
                        end
                        //$display("ICache: Flush during MISS. Cache lines invalidated for index %d.", index);
                    end else if (m_axi_arready && m_axi_arvalid) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        beat_counter  <= 0;
                        refill_data   <= '0;
                    end
                end

                REFILL: begin
                    if (flush_rising_edge) begin

                        refill_data <= '0;
                        m_axi_rready  <= 1'b0;
                        //$display("ICache: Flush during REFILL. Discarding fetched data.");
                    end else if (m_axi_rvalid && m_axi_rready) begin
                        int bit_position = beat_counter * DATA_WIDTH;
                        refill_data[bit_position +: DATA_WIDTH] <= m_axi_rdata;
                        //$display("ICache: Received data beat %0d at bit position %0d: 0x%h", beat_counter, bit_position, m_axi_rdata);
                        beat_counter <= beat_counter + 1;
                        if (m_axi_rdata == 64'b0) begin
                            //$finish;
                        end
                        // if (m_axi_rdata == 64'b0) begin
                        //     $finish;
                        // end
                    end
                end

                COPY: begin
                    if (flush_rising_edge) begin

                        refill_data <= '0;
                        m_axi_rready  <= 1'b0;
                        //$display("ICache: Flush during COPY. Discarding fetched data.");
                    end else if (stall) begin

                        //$display("ICache: Stall during COPY. Holding state.");
                    end else begin
                        m_axi_rready <= 1'b0;

                        lru_way = lru[index];
                        cache[index][lru_way].valid <= 1'b1;
                        cache[index][lru_way].tag   <= tag;
                        cache[index][lru_way].data  <= refill_data;

                        lru[index] <= ~lru_way;

                        //$display("ICache: Cache line updated at index %0d, way %0d with tag 0x%h.", index, lru_way, tag);
                    end
                end

                FLUSH: begin

                    refill_data   <= '0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    beat_counter  <= 0;
                    //$display("ICache: Flush completed. Returning to IDLE state.");
                end

                STALL: begin

                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    //$display("ICache: Stall active. Maintaining current state.");
                end

                default: begin

                    next_state = IDLE;
                end
            endcase
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin

        end else begin
            if (current_state != FLUSH && current_state != STALL) begin
                if (hit_way0) begin
                    lru[index] <= 1'b1; 
                    //$display("ICache: LRU updated for index %0d: Way 0 accessed.", index);
                end else if (hit_way1) begin
                    lru[index] <= 1'b0; 
                    //$display("ICache: LRU updated for index %0d: Way 1 accessed.", index);
                end
            end
        end
    end

endmodule
