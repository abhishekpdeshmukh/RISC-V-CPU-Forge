module DCache #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64,
    parameter CACHE_LINE_SIZE = 512, 
    parameter NUMBER_OF_SETS = 512,
    parameter NUMBER_OF_WAYS = 2,
    parameter ID_WIDTH = 13,
    parameter STRB_WIDTH  = DATA_WIDTH / 8
)(
    input  logic                  clk,
    input  logic                  reset,
    
    input  logic                  valid_in,         
    input  logic [ADDR_WIDTH-1:0] address_in,      
    input  logic [1:0]            size_in,         
    input  logic                  store_enable,   
    input  logic [DATA_WIDTH-1:0] data_in,         
    output logic [DATA_WIDTH-1:0] read_data_out,  
    output logic                  read_valid_out,     
    output logic                  write_valid_out,     
    
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
    
    output logic [ID_WIDTH-1:0]   m_axi_awid,
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]            m_axi_awlen,
    output logic [2:0]            m_axi_awsize,
    output logic [1:0]            m_axi_awburst,
    output logic                  m_axi_awlock,
    output logic [3:0]            m_axi_awcache,
    output logic [2:0]            m_axi_awprot,
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,
    
    output logic [DATA_WIDTH-1:0] m_axi_wdata,
    output logic                  m_axi_wlast,
    output logic [DATA_WIDTH/8-1:0]    m_axi_wstrb,
    output logic                  m_axi_wvalid,
    input  logic                  m_axi_wready,
    
    input  logic [ID_WIDTH-1:0]   m_axi_bid,
    input  logic [1:0]            m_axi_bresp,
    input  logic                  m_axi_bvalid,
    output logic                  m_axi_bready,

    input  logic                     m_axi_acvalid,
    output logic                     m_axi_acready,
    input  logic [ADDR_WIDTH-1:0]    m_axi_acaddr,
    input  logic [3:0]               m_axi_acsnoop
);
    
    typedef struct packed {
        logic                       valid;
        logic [48:0]                tag;   
        logic [CACHE_LINE_SIZE-1:0] data;  
    } cache_line_t;

    cache_line_t cache [0:NUMBER_OF_SETS-1][0:NUMBER_OF_WAYS-1];

    logic lru [0:NUMBER_OF_SETS-1];

    localparam OFFSET_BITS = 6; 
    localparam INDEX_BITS  = 9; 
    localparam TAG_BITS    = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS; 

    logic [OFFSET_BITS-1:0] offset; 
    logic [INDEX_BITS-1:0]  index;  
    logic [TAG_BITS-1:0]    tag;    

    assign offset = address_in[OFFSET_BITS-1:0]; 
    assign index  = address_in[OFFSET_BITS +: INDEX_BITS]; 
    assign tag    = address_in[ADDR_WIDTH-1 -: TAG_BITS]; 

    logic [INDEX_BITS-1:0] snoop_index = m_axi_acaddr[OFFSET_BITS +: INDEX_BITS];
    logic [TAG_BITS-1:0] snoop_tag = m_axi_acaddr[ADDR_WIDTH-1 -: TAG_BITS];

    logic hit_way0, hit_way1;
    logic [1:0] hit;

    always_comb begin
        hit_way0 = cache[index][0].valid && (cache[index][0].tag == tag);
        hit_way1 = cache[index][1].valid && (cache[index][1].tag == tag);
        hit = {hit_way1, hit_way0};
    end

    logic selected_way;
    assign selected_way = (hit_way0) ? 1'b0 :
                          (hit_way1) ? 1'b1 :
                          lru[index]; 

    always_comb begin
        read_valid_out = 1'b0;
        if (valid_in && !store_enable && (hit_way0 || hit_way1)) begin
            case (size_in)
                2'b00: begin // Byte
                    read_data_out = {{56{cache[index][selected_way].data[(offset * 8) +:8][7]}}, cache[index][selected_way].data[(offset * 8) +:8]};
                end
                2'b01: begin // Half-word
                    read_data_out = {{48{cache[index][selected_way].data[(offset * 8) +:16][15]}}, cache[index][selected_way].data[(offset * 8) +:16]};
                end
                2'b10: begin // Word
                    read_data_out = {{32{cache[index][selected_way].data[(offset * 8) +:32][31]}}, cache[index][selected_way].data[(offset * 8) +:32]};
                end
                2'b11: begin // Double-word
                    read_data_out = cache[index][selected_way].data[(offset * 8) +:64];
                end
                default: begin
                    read_data_out = '0;
                end
            endcase
            read_valid_out = 1'b1;
        end else begin
            read_data_out = '0;
        end
    end

    always_comb begin
        write_valid_out = 1'b0;
        if (current_state == IDLE && (need_write && (hit_way0 || hit_way1))) begin
            write_valid_out = 1'b1;
        end
        if (current_state == UPDATE_CACHE_FOR_WRITE && next_state == IDLE) begin
            write_valid_out = 1'b1;
        end
    end

    typedef enum logic [3:0] {
        IDLE,
        INITIATE_READ,
        WAIT_READ,
        UPDATE_CACHE,
        INITIATE_WRITE_ADDR,
        SEND_WRITE_DATA,
        WAIT_WRITE_RESPONSE,
        INITIATE_READ_FOR_WRITE,
        WAIT_READ_FOR_WRITE,
        UPDATE_CACHE_FOR_WRITE
    } cache_state_t;

    cache_state_t current_state, next_state;

    logic [CACHE_LINE_SIZE-1:0] refill_data;
    integer beat_counter;
    integer write_beat_counter;

    logic need_refill;
    logic need_write;

    assign need_refill = valid_in && !store_enable && !(hit_way0 || hit_way1);
    assign need_write  = valid_in && store_enable;

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (need_refill) begin
                    next_state = INITIATE_READ;
                end else if (need_write && (hit_way0 || hit_way1)) begin
                    next_state = IDLE;
                end else if (need_write && !(hit_way0 || hit_way1)) begin
                    next_state = INITIATE_READ_FOR_WRITE; 
                end
            end

            INITIATE_READ: begin
                if (m_axi_arvalid && m_axi_arready) begin
                    next_state = WAIT_READ;
                end
            end

            WAIT_READ: begin
                if (m_axi_rvalid && m_axi_rlast) begin
                    next_state = UPDATE_CACHE;
                end
            end

            UPDATE_CACHE: begin
                next_state = IDLE;
            end

            INITIATE_WRITE_ADDR: begin
                if (m_axi_awvalid && m_axi_awready) begin
                    next_state = SEND_WRITE_DATA;
                end
            end

            SEND_WRITE_DATA: begin
                if (write_beat_counter == 7 && m_axi_wvalid && m_axi_wready) begin
                    next_state = WAIT_WRITE_RESPONSE;
                end 
            end

            WAIT_WRITE_RESPONSE: begin
                if (m_axi_bvalid) begin
                    next_state = IDLE;
                end
            end

            INITIATE_READ_FOR_WRITE: begin
                if (m_axi_arvalid && m_axi_arready) begin
                    next_state = WAIT_READ_FOR_WRITE;
                end
            end

            WAIT_READ_FOR_WRITE: begin
                if (m_axi_rvalid && m_axi_rlast) begin
                    next_state = UPDATE_CACHE_FOR_WRITE;
                end
            end

            UPDATE_CACHE_FOR_WRITE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state      <= IDLE;
            m_axi_arvalid      <= 1'b0;
            m_axi_rready       <= 1'b0;
            m_axi_awvalid      <= 1'b0;
            m_axi_wvalid       <= 1'b0;
            m_axi_wlast        <= 1'b0;
            m_axi_bready       <= 1'b0;
            beat_counter       <= 0;
            write_beat_counter <= 0;
            refill_data        <= '0;
            m_axi_acready      <= 1'b0;

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
                    if (m_axi_acvalid && (m_axi_acsnoop == 4'hd)) begin

                        for (int way = 0; way < NUMBER_OF_WAYS; way++) begin
                            if (cache[snoop_index][way].valid && cache[snoop_index][way].tag == snoop_tag) begin
                                cache[snoop_index][way].valid <= 1'b0;
                            end
                        end               
                    end else if (valid_in) begin

                        if (need_refill) begin

                            m_axi_araddr  <= {tag, index, {OFFSET_BITS{1'b0}}}; 
                            m_axi_arvalid <= 1'b1;
                            m_axi_arid    <= 'd1; 
                            m_axi_arlen    <= 8'd7;       
                            m_axi_arsize   <= 3'd3;      
                            m_axi_arburst  <= 2'b01;    
                            m_axi_arlock   <= 1'b0;
                            m_axi_arcache  <= 4'b0011;
                            m_axi_arprot   <= 3'b000;
                                
                        end else if (need_write && (hit_way0 || hit_way1)) begin
                            case (size_in)
                                2'b00: begin // Store Byte (sb)
                                    cache[index][selected_way].data[(offset * 8) +: 8]   <=  data_in[7:0];
                                end
                                2'b01: begin // Store Half-Word (sh)
                                    cache[index][selected_way].data[(offset * 8) +: 16]  <=  data_in[15:0];
                                end
                                2'b10: begin // Store Word (sw)
                                    cache[index][selected_way].data[(offset * 8) +: 32]  <=  data_in[31:0];
                                end
                                2'b11: begin // Store Double-Word (sd)
                                    cache[index][selected_way].data[(offset * 8) +: 64]  <=  data_in;
                                end
                                default: begin
                                    //$display("we shouldnt be here");
                                    cache[index][selected_way].data[(offset * 8) +: 64]  <=  '0; // Default to 0 for undefined sizes
                                end
                            endcase  
                        end else if (need_write && !(hit_way0 || hit_way1)) begin

                            m_axi_araddr  <= {tag, index, {OFFSET_BITS{1'b0}}}; 
                            m_axi_arvalid <= 1'b1;
                            m_axi_arid    <= 'd1; 
                            m_axi_arlen    <= 8'd7;       
                            m_axi_arsize   <= 3'd3;        
                            m_axi_arburst  <= 2'b10;      
                            m_axi_arlock   <= 1'b0;
                            m_axi_arcache  <= 4'b0011;
                            m_axi_arprot   <= 3'h6;
                        end
                    end
                end

                INITIATE_READ: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0; 
                        m_axi_rready  <= 1'b1; 
                        beat_counter  <= 0;
                        refill_data   <= '0;
                    end
                end

                WAIT_READ: begin
                    if (m_axi_rvalid) begin
                        refill_data[(beat_counter * DATA_WIDTH) +: DATA_WIDTH] <= m_axi_rdata;
                       
                        beat_counter <= beat_counter + 1;
                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0; 
                            //$display("DCache: Received last data beat.");
                        end
                    end
                end

                UPDATE_CACHE: begin

                    cache[index][selected_way].valid <= 1'b1;
                    cache[index][selected_way].tag   <= tag;
                    cache[index][selected_way].data  <= refill_data;

                    lru[index] <= ~selected_way;
                end

                INITIATE_WRITE_ADDR: begin
                    
                end
                SEND_WRITE_DATA: begin
                    if (m_axi_wready) begin
                        if (m_axi_awvalid && m_axi_awready) begin
                            m_axi_wvalid <= 1'b1;
                            m_axi_awvalid <= 1'b0;
                            write_beat_counter <= 0;
                            m_axi_wlast <=0;
                        end
                        m_axi_wdata <= cache[index][selected_way].data[(write_beat_counter * DATA_WIDTH) +: DATA_WIDTH];
                        
                        m_axi_wlast <= (write_beat_counter == 7) ? 1'b1 : 1'b0;
                        
                        
                        if (write_beat_counter == 7) begin
                            m_axi_wvalid <= 1'b0;
                        end
                        write_beat_counter <= write_beat_counter + 1;
                    end
                end


                WAIT_WRITE_RESPONSE: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b1; 
                    end
                    if (m_axi_bready && m_axi_bvalid) begin

                        m_axi_bready <= 1'b0; 
                    end
                end

                INITIATE_READ_FOR_WRITE: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0; 
                        m_axi_rready  <= 1'b1;  
                        beat_counter  <= 0;
                        refill_data   <= '0;
                    end
                end

                WAIT_READ_FOR_WRITE: begin
                    if (m_axi_rvalid) begin
                        refill_data[(beat_counter * DATA_WIDTH) +: DATA_WIDTH] <= m_axi_rdata;
                        
                        beat_counter <= beat_counter + 1;
                        if (m_axi_rlast) begin
                        
                            case (size_in)
                                2'b00: begin // Store Byte (sb)
                                    refill_data[(offset * 8) +: 8]   <=  data_in[7:0];
                                end
                                2'b01: begin // Store Half-Word (sh)
                                    refill_data[(offset * 8) +: 16]  <=  data_in[15:0];
                                end
                                2'b10: begin // Store Word (sw)
                                    refill_data[(offset * 8) +: 32]  <=  data_in[31:0];
                                end
                                2'b11: begin // Store Double-Word (sd)
                                    refill_data[(offset * 8) +: 64]  <=  data_in;
                                end
                            endcase                        

                            m_axi_rready <= 1'b0;
                        end
                    end
                end

                UPDATE_CACHE_FOR_WRITE: begin

                    cache[index][selected_way].valid <= 1'b1;
                    cache[index][selected_way].tag   <= tag;
                    cache[index][selected_way].data  <= refill_data;
                   
                end

                default: begin

                end
            endcase

            
            if (current_state == WAIT_READ || current_state == WAIT_READ_FOR_WRITE) begin
                m_axi_rready <= 1'b1;
            end else begin
                m_axi_rready <= 1'b0;
            end

            if (current_state == WAIT_WRITE_RESPONSE) begin
                m_axi_bready <= 1'b1;
            end else begin
                m_axi_bready <= 1'b0;
            end

            if (current_state == IDLE) begin
                m_axi_acready <= 1'b1;
            end else begin
                m_axi_acready <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin

        end else begin
            if (!store_enable && (hit_way0 || hit_way1) && valid_in) begin
                if (hit_way0) begin
                    lru[index] <= 1'b1; 
                end else if (hit_way1) begin
                    lru[index] <= 1'b0; 
                end
            end else if (store_enable && (hit_way0 || hit_way1) && valid_in) begin
                if (hit_way0) begin
                    lru[index] <= 1'b1;
                end else if (hit_way1) begin
                    lru[index] <= 1'b0;
                end
            end
        end
    end

endmodule

