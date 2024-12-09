`include "Sysbus.defs"
`include "pipeline_reg.sv"
`include "types.sv"
`include "icache.sv"
`include "dcache.sv"
`include "decoder.sv"
`include "regfile.sv"
`include "alu.sv"
`include "arbiter.sv"
`include "control.sv"


module IFStage #(
    parameter ID_WIDTH    = 13,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter STRB_WIDTH  = DATA_WIDTH / 8
) (
    input  logic                   clk,
    input  logic                   reset,
    input  logic [63:0]            pc_in,
    output logic                   if_valid,
    output logic [63:0]            pc_out,
    output logic [31:0]            instruction_out,


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

    input  logic [ID_WIDTH-1:0]    m_axi_rid,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                   m_axi_rlast,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,

    input  logic                   flush,     
    input  logic                   branch_taken  
);

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

        .flush(flush),
        .stall('0) // Moved stall logic to stall_pc
    );

    assign pc_out = pc_in;
endmodule


module IDStage (
    input  logic         clk,
    input  logic         reset,
    input packed_inst decoded_inst_in,

    output packed_inst decoded_inst_out
);

    assign decoded_inst_out = decoded_inst_in;
endmodule



module EXStage (
    input  logic                 clk,
    input  logic                 reset,

    input  packed_inst           decoded_inst_in,
    input  logic [63:0]          rs1_data_in,
    input  logic [63:0]          rs2_data_in,

    output logic [63:0]          alu_result_out,
    output packed_inst           decoded_inst_out,
    output logic [63:0]          store_data_out,

    output logic                 branch_taken_out,
    output logic [63:0]          branch_target_out
);


    logic [63:0] operand_b;
    logic [63:0] alu_result;
    logic        branch_taken;
    logic [63:0] branch_target;

    assign operand_b = decoded_inst_in.alu_src_imm ? decoded_inst_in.imm  : rs2_data_in;

    ALU alu_inst (
        .a(rs1_data_in),
        .b(operand_b),
        .instr(decoded_inst_in),
        .result(alu_result),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );
    
    assign alu_result_out    = alu_result;
    assign branch_taken_out  = branch_taken;
    assign branch_target_out = branch_target;
    assign decoded_inst_out  = decoded_inst_in;
    assign store_data_out    = rs2_data_in;

endmodule


module MemStage #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64,
    parameter ID_WIDTH   = 13
)(
    input  logic                 clk,
    input  logic                 reset,

    input  logic [ADDR_WIDTH-1:0] alu_result_in,    
    input  logic [DATA_WIDTH-1:0] store_data_in,    
    input  packed_inst        decoded_inst_in,
    input  logic                 flush_ex_mem,
    
    output logic [DATA_WIDTH-1:0] mem_data_out,     
    output logic [ADDR_WIDTH-1:0] alu_result_out,    
    output  packed_inst        decoded_inst_out,

    output logic [ID_WIDTH-1:0]   dcache_arid,      
    output logic [ADDR_WIDTH-1:0] dcache_araddr,
    output logic [7:0]            dcache_arlen,
    output logic [2:0]            dcache_arsize,
    output logic [1:0]            dcache_arburst,
    output logic                  dcache_arlock,
    output logic [3:0]            dcache_arcache,
    output logic [2:0]            dcache_arprot,
    output logic                  dcache_arvalid,
    input  logic                  dcache_arready,

    input  logic [DATA_WIDTH-1:0] dcache_rdata,
    input  logic                  dcache_rvalid,
    input  logic                  dcache_rlast,
    output logic                  dcache_rready,

    output logic [ID_WIDTH-1:0]   dcache_awid,     
    output logic [ADDR_WIDTH-1:0] dcache_awaddr,
    output logic [7:0]            dcache_awlen,
    output logic [2:0]            dcache_awsize,
    output logic [1:0]            dcache_awburst,
    output logic                  dcache_awlock,
    output logic [3:0]            dcache_awcache,
    output logic [2:0]            dcache_awprot,
    output logic                  dcache_awvalid,
    input  logic                  dcache_awready,

    output logic [DATA_WIDTH-1:0] dcache_wdata,
    output logic [DATA_WIDTH/8-1:0] dcache_wstrb,
    output logic                  dcache_wlast,
    output logic                  dcache_wvalid,
    input  logic                  dcache_wready,

    input  logic [ID_WIDTH-1:0]   dcache_bid,
    input  logic [1:0]            dcache_bresp,
    input  logic                  dcache_bvalid,
    output logic                  dcache_bready,

    input  logic                     m_axi_acvalid,
    output logic                     m_axi_acready,
    input  logic [ADDR_WIDTH-1:0]    m_axi_acaddr,
    input  logic [3:0]               m_axi_acsnoop,

    output logic                  read_done,
    output logic                  write_done
);

    logic [63:0] mem_load_data;

    always_comb begin

        if (decoded_inst_in.mem_read) begin
            case (decoded_inst_in.funct3)
                3'b100: mem_data_out = { 56'd0, mem_load_data[7:0] };  // LBU
                3'b101: mem_data_out = { 48'd0, mem_load_data[15:0] }; // LHU
                3'b110: mem_data_out = { 32'd0, mem_load_data[31:0] }; // LWU
                default: mem_data_out = mem_load_data;
            endcase
        end
    end

    DCache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_LINE_SIZE(512), 
        .NUMBER_OF_SETS(512),
        .NUMBER_OF_WAYS(2),
        .ID_WIDTH(ID_WIDTH)
    ) dcache_inst (
        .clk(clk),
        .reset(reset),
        
        .valid_in((decoded_inst_in.mem_read || decoded_inst_in.mem_write) && !flush_ex_mem),
        .address_in(alu_result_in),
        .size_in(decoded_inst_in.mem_size),
        .store_enable(decoded_inst_in.mem_write),
        .data_in(store_data_in),
        .read_data_out(mem_load_data),
        .read_valid_out(read_done),
        .write_valid_out(write_done),
        
        .m_axi_arid(dcache_arid),
        .m_axi_araddr(dcache_araddr),
        .m_axi_arlen(dcache_arlen),
        .m_axi_arsize(dcache_arsize),
        .m_axi_arburst(dcache_arburst),
        .m_axi_arlock(dcache_arlock),
        .m_axi_arcache(dcache_arcache),
        .m_axi_arprot(dcache_arprot),
        .m_axi_arvalid(dcache_arvalid),
        .m_axi_arready(dcache_arready),
        
        .m_axi_rid(), 
        .m_axi_rdata(dcache_rdata),
        .m_axi_rresp(), 
        .m_axi_rlast(dcache_rlast),
        .m_axi_rvalid(dcache_rvalid),
        .m_axi_rready(dcache_rready),
        
        .m_axi_awid(dcache_awid),
        .m_axi_awaddr(dcache_awaddr),
        .m_axi_awlen(dcache_awlen),
        .m_axi_awsize(dcache_awsize),
        .m_axi_awburst(dcache_awburst),
        .m_axi_awlock(dcache_awlock),
        .m_axi_awcache(dcache_awcache),
        .m_axi_awprot(dcache_awprot),
        .m_axi_awvalid(dcache_awvalid),
        .m_axi_awready(dcache_awready),
        
        .m_axi_wdata(dcache_wdata),
        .m_axi_wstrb(dcache_wstrb),
        .m_axi_wlast(dcache_wlast),
        .m_axi_wvalid(dcache_wvalid),
        .m_axi_wready(dcache_wready),
        
        .m_axi_bid(dcache_bid),
        .m_axi_bresp(dcache_bresp),
        .m_axi_bvalid(dcache_bvalid),
        .m_axi_bready(dcache_bready),

        .m_axi_acvalid(m_axi_acvalid),
        .m_axi_acready(m_axi_acready),
        .m_axi_acaddr(m_axi_acaddr),
        .m_axi_acsnoop(m_axi_acsnoop)
    );
    
    assign alu_result_out   = alu_result_in;
    assign decoded_inst_out = decoded_inst_in;

    
endmodule


module WBStage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  logic                 clk,
    input  logic                 reset,

    input  logic [DATA_WIDTH-1:0] mem_data_in,      
    input  logic [DATA_WIDTH-1:0] alu_result_in,    
    input  packed_inst         decoded_inst_in,
    input  logic                  is_mem_wb_flush,
    output logic [63:0]           wb_pc,

    output logic [4:0]            wb_rd,           
    output logic [DATA_WIDTH-1:0] wb_data,        
    output logic                  wb_enable,       
    input  logic [63:0]           store_data_in,
    // ECALL Handling
    input  logic [63:0]           a0, a1, a2, a3, a4, a5, a6, a7, 
    output logic                  ecall_stall
);


    
    logic [63:0] ecall_return_val;
    logic ecall_done;
    
    always_comb begin
        if (!is_mem_wb_flush) begin
            if (decoded_inst_in.ecall_flag && ecall_done) begin

                wb_data = ecall_return_val;
                wb_enable = 1'b1;
                wb_rd  = 'd10; 
                wb_pc = decoded_inst_in.addr;
            end
            else if (decoded_inst_in.reg_write && decoded_inst_in.rd != 5'd0) begin
                wb_rd     =  decoded_inst_in.rd;
                wb_data   =  decoded_inst_in.mem_read ? mem_data_in : alu_result_in;
                wb_enable =  1'b1;
                wb_pc = decoded_inst_in.addr;
            end
            else begin
                wb_rd    = 5'd0;
                wb_data  = '0;
                wb_enable = 1'b0;
                wb_pc = 'b0;
            end
        end else begin
            wb_rd    = 5'd0;
            wb_data  = '0;
            wb_enable = 1'b0;
            wb_pc = 'b0;
        end
    end


	always_comb begin
		if (decoded_inst_in.ecall_flag && !is_mem_wb_flush && !ecall_done) begin
            //$display("WBStage: still in do_call");
			ecall_stall = 1;
		end
		else begin
			ecall_stall = 0;
		end
	end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ecall_done <= 0;
        end else if (!decoded_inst_in.ecall_flag || ecall_done || is_mem_wb_flush) begin
            ecall_done <= 0;
        end else if (decoded_inst_in.ecall_flag && !ecall_done && !is_mem_wb_flush) begin
            //$display("WBStage: calling do_ecall");
            do_ecall(a7, a0, a1, a2, a3, a4, a5, a6, ecall_return_val);
            ecall_done <= 1;
        end if (decoded_inst_in.mem_write) begin
            case (decoded_inst_in.mem_size)
                2'b00: begin 
                    do_pending_write(alu_result_in, store_data_in[7:0], 1);
                end
                2'b01: begin 
                    do_pending_write(alu_result_in, store_data_in[15:0], 2);
                end
                2'b10: begin 
                    do_pending_write(alu_result_in, store_data_in[31:0], 4);
                end
                2'b11: begin 
                    do_pending_write(alu_result_in, store_data_in, 8);
                end
            endcase  
        end
    end

    logic is_ecall_debug;
    assign is_ecall_debug = decoded_inst_in.ecall_flag;

endmodule


module top #(
    parameter ID_WIDTH    = 13,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter STRB_WIDTH  = DATA_WIDTH / 8
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    hz32768timer,

    input  logic [63:0]             entry,
    input  logic [63:0]             stackptr,
    input  logic [63:0]             satp,

    
    output logic [ID_WIDTH-1:0]     m_axi_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    output logic                    m_axi_awlock,
    output logic [3:0]              m_axi_awcache,
    output logic [2:0]              m_axi_awprot,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,

    output logic [DATA_WIDTH-1:0]    m_axi_wdata,
    output logic [STRB_WIDTH-1:0]    m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,

    input  logic [ID_WIDTH-1:0]      m_axi_bid,
    input  logic [1:0]               m_axi_bresp,
    input  logic                     m_axi_bvalid,
    output logic                     m_axi_bready,

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

    input  logic [ID_WIDTH-1:0]      m_axi_rid,
    input  logic [DATA_WIDTH-1:0]    m_axi_rdata,
    input  logic [1:0]               m_axi_rresp,
    input  logic                     m_axi_rlast,
    input  logic                     m_axi_rvalid,
    output logic                     m_axi_rready,

    input  logic                     m_axi_acvalid,
    output logic                     m_axi_acready,
    input  logic [ADDR_WIDTH-1:0]    m_axi_acaddr,
    input  logic [3:0]               m_axi_acsnoop
);


    logic                  read_done;
    logic                  write_done;
    logic                  ecall_stall;

    
    logic                 icache_arvalid;
    logic [ADDR_WIDTH-1:0] icache_araddr;
    logic                 icache_arready;
    logic                 icache_rvalid;
    logic [DATA_WIDTH-1:0] icache_rdata;
    logic                 icache_rlast;
    logic                 icache_rready;


    logic                 dcache_arvalid;
    logic [ADDR_WIDTH-1:0] dcache_araddr;
    logic                 dcache_arready;
    logic                 dcache_rvalid;
    logic [DATA_WIDTH-1:0] dcache_rdata;
    logic                 dcache_rlast;
    logic                 dcache_rready;

    logic               enable_if_id;
    logic               flush_if_id;
    logic               if_id_flush_out;

    logic               enable_id_ex;
    logic               flush_id_ex;
    logic               id_ex_flush_out;  

    logic               enable_ex_mem;
    logic               flush_ex_mem;
    logic               ex_mem_flush_out;

    logic               enable_mem_wb;
    logic               flush_mem_wb;
    logic               mem_wb_flush_out;

    logic               enable_pc;

    Arbiter #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) arbiter_inst (
        .clk(clk),
        .reset(reset),

        .icache_arvalid(icache_arvalid),
        .icache_araddr(icache_araddr),
        .icache_arready(icache_arready),
        .icache_rvalid(icache_rvalid),
        .icache_rdata(icache_rdata),
        .icache_rlast(icache_rlast),
        .icache_rready(icache_rready),

        .dcache_arvalid(dcache_arvalid),
        .dcache_araddr(dcache_araddr),
        .dcache_arready(dcache_arready),
        .dcache_rvalid(dcache_rvalid),
        .dcache_rdata(dcache_rdata),
        .dcache_rlast(dcache_rlast),
        .dcache_rready(dcache_rready),

       
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



    logic [63:0]           pc; 

    logic                  icache_valid_if;
    logic [31:0]           instruction_out_if;
    logic [63:0]           pc_out_if;

    IFStage #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) if_stage_inst (
        .clk(clk),
        .reset(reset),
        .pc_in(pc),
        .if_valid(icache_valid_if),
        .pc_out(pc_out_if),
        .instruction_out(instruction_out_if),

        .m_axi_arid(icache_arid),
        .m_axi_araddr(icache_araddr),
        .m_axi_arlen(icache_arlen),
        .m_axi_arsize(icache_arsize),
        .m_axi_arburst(icache_arburst),
        .m_axi_arlock(icache_arlock),
        .m_axi_arcache(icache_arcache),
        .m_axi_arprot(icache_arprot),
        .m_axi_arvalid(icache_arvalid),
        .m_axi_arready(icache_arready),

        .m_axi_rid(icache_rid),
        .m_axi_rdata(icache_rdata),
        .m_axi_rresp(icache_rresp),
        .m_axi_rlast(icache_rlast),
        .m_axi_rvalid(icache_rvalid),
        .m_axi_rready(icache_rready),

        .flush(flush_if_id), 
        .branch_taken(branch_taken_delay)
    );

    logic                   icache_valid_if_id;
    logic [63:0]            pc_out_if_id;
    logic [31:0]            instruction_out_if_id;
    

    IF_ID if_id_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable_if_id),
        .flush_in(flush_if_id),
        .flush_out(if_id_flush_out),
        .pc_in(pc_out_if),
        .pc_out(pc_out_if_id),
        .instruction_in(instruction_out_if),
        .instruction_out(instruction_out_if_id),
        .icache_valid_in(icache_valid_if),
        .icache_valid_out(icache_valid_if_id)
    );


    packed_inst  if_id_decoded_inst;
    string          decoded_str;

    Decode decoder_inst (
        .addr(pc_out_if_id),
        .instr(instruction_out_if_id),
        .out_instr(if_id_decoded_inst),
        .out_str(decoded_str)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
        end else begin
            if (icache_valid_if_id && instruction_out_if_id) begin
                //$display("IDStage: PC: 0x%x Instruction: 0x%h decoded_str : %s", pc_out_if_id, instruction_out_if_id, decoded_str);
            end 
        end
    end

    packed_inst decoded_inst_id_out;
    logic [63:0] debug_2_id_pc = decoded_inst_id_out.addr;
    IDStage id_stage (
        .clk(clk),
        .reset(reset),
        .decoded_inst_in(if_id_decoded_inst),
        .decoded_inst_out(decoded_inst_id_out)
    );


    logic [63:0]           rs1_data_id;
    logic [63:0]           rs2_data_id;
    packed_inst         id_ex_decoded_inst;
    logic [63:0] debug_3_id_ex_pc = id_ex_decoded_inst.addr;
    logic [63:0]           rs1_data_ex;
    logic [63:0]           rs2_data_ex;

    ID_EX id_ex_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable_id_ex),
        .flush_in(flush_id_ex || if_id_flush_out),
        .flush_out(id_ex_flush_out),
        .decoded_inst_in(decoded_inst_id_out),
        .rs1_data_in(rs1_data_id),
        .rs2_data_in(rs2_data_id),
        .decoded_inst_out(id_ex_decoded_inst),
        .rs1_data_out(rs1_data_ex),
        .rs2_data_out(rs2_data_ex)
    );

    logic [63:0]           a0, a1, a2, a3, a4, a5, a6, a7; // for ecall

    Regfile regfile_inst (
        .clk(clk),
        .reset(reset),
        .initial_sp(stackptr),
        .rs1(if_id_decoded_inst.rs1),
        .rs2(if_id_decoded_inst.rs2),
        .wb_pc(wb_pc),
        .rd1_data(rs1_data_id),
        .rd2_data(rs2_data_id),
        .rd(wb_rd),                    
        .rd_data(wb_data),             
        .write_enable(wb_enable),      
        .a0(a0), .a1(a1), .a2(a2), .a3(a3), .a4(a4), .a5(a5), .a6(a6), .a7(a7) // ecall
    );


    logic [63:0]           alu_result_ex;
    logic [63:0]           rs2_data_ex_out; 
    packed_inst         decoded_inst_ex_out;
    logic [63:0] debug_4_ex_pc = decoded_inst_ex_out.addr;

    logic                  branch_taken_ex;
    logic [63:0]           branch_target_ex;

    EXStage ex_stage (
        .clk(clk),
        .reset(reset),
        .decoded_inst_in(id_ex_decoded_inst),
        .rs1_data_in(rs1_data_ex), 
        .rs2_data_in(rs2_data_ex),
        .alu_result_out(alu_result_ex),
        .decoded_inst_out(decoded_inst_ex_out),
        .store_data_out(rs2_data_ex_out),

        .branch_taken_out(branch_taken_ex),
        .branch_target_out(branch_target_ex)
    );


    logic [63:0] ex_mem_alu_result;
    logic [63:0] ex_mem_store_data_out;
    packed_inst ex_mem_decoded_inst;
    logic [63:0] debug_5_ex_mem_pc = ex_mem_decoded_inst.addr;
    logic                  ex_mem_branch_taken;
    logic [63:0]           ex_mem_branch_target;

    EX_MEM ex_mem_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable_ex_mem),
        .flush_in(flush_ex_mem || id_ex_flush_out),
        .flush_out(ex_mem_flush_out),

        .alu_result_in(alu_result_ex),
        .decoded_inst_in(decoded_inst_ex_out),
        .store_data_in(rs2_data_ex_out), 
        .branch_taken_in(branch_taken_ex),
        .branch_target_in(branch_target_ex),

        .alu_result_out(ex_mem_alu_result),
        .decoded_inst_out(ex_mem_decoded_inst),
        .store_data_out(ex_mem_store_data_out),
        .branch_taken_out(ex_mem_branch_taken),
        .branch_target_out(ex_mem_branch_target)
    );


    logic [DATA_WIDTH-1:0]    mem_data_mem;    
    logic [DATA_WIDTH-1:0]    alu_result_mem;   
    packed_inst            decoded_inst_mem_out;
    logic [63:0] debug_6_mem_pc = decoded_inst_mem_out.addr;


    MemStage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) mem_stage_inst (
        .clk(clk),
        .reset(reset),

        .alu_result_in(ex_mem_alu_result),
        .store_data_in(ex_mem_store_data_out), 
        .decoded_inst_in(ex_mem_decoded_inst),
        .flush_ex_mem(ex_mem_flush_out),

        .mem_data_out(mem_data_mem),
        .alu_result_out(alu_result_mem),
        .decoded_inst_out(decoded_inst_mem_out),

        .dcache_arid(dcache_arid),
        .dcache_araddr(dcache_araddr),
        .dcache_arlen(dcache_arlen),
        .dcache_arsize(dcache_arsize),
        .dcache_arburst(dcache_arburst),
        .dcache_arlock(dcache_arlock),
        .dcache_arcache(dcache_arcache),
        .dcache_arprot(dcache_arprot),
        .dcache_arvalid(dcache_arvalid),
        .dcache_arready(dcache_arready),

        .dcache_rdata(dcache_rdata),
        .dcache_rvalid(dcache_rvalid),
        .dcache_rlast(dcache_rlast),
        .dcache_rready(dcache_rready),

        .dcache_awid(m_axi_awid),
        .dcache_awaddr(m_axi_awaddr),
        .dcache_awlen(m_axi_awlen),
        .dcache_awsize(m_axi_awsize),
        .dcache_awburst(m_axi_awburst),
        .dcache_awlock(m_axi_awlock),
        .dcache_awcache(m_axi_awcache),
        .dcache_awprot(m_axi_awprot),
        .dcache_awvalid(m_axi_awvalid),
        .dcache_awready(m_axi_awready),

        .dcache_wdata(m_axi_wdata),
        .dcache_wstrb(m_axi_wstrb),
        .dcache_wlast(m_axi_wlast),
        .dcache_wvalid(m_axi_wvalid),
        .dcache_wready(m_axi_wready),

        .dcache_bid(m_axi_bid),
        .dcache_bresp(m_axi_bresp),
        .dcache_bvalid(m_axi_bvalid),
        .dcache_bready(m_axi_bready),

        .read_done(read_done),
        .write_done(write_done),

        .m_axi_acvalid(m_axi_acvalid),
        .m_axi_acready(m_axi_acready),
        .m_axi_acaddr(m_axi_acaddr),
        .m_axi_acsnoop(m_axi_acsnoop)
    );

    
    logic [DATA_WIDTH-1:0] mem_wb_mem_data;
    logic [DATA_WIDTH-1:0] mem_wb_alu_result;
    packed_inst         mem_wb_decoded_inst;
    logic [63:0] debug_7_mem_wb_pc = mem_wb_decoded_inst.addr;
    logic debug_7_mem_wb_ecall = mem_wb_decoded_inst.ecall_flag;
    logic [63:0] wb_pc;

    logic [63:0] mem_wb_store_data;

    MEM_WB #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mem_wb_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable_mem_wb),
        .flush_in(flush_mem_wb || ex_mem_flush_out),
        .flush_out(mem_wb_flush_out), 

        .mem_data_in(mem_data_mem),       
        .alu_result_in(alu_result_mem),    
        .decoded_inst_in(decoded_inst_mem_out),
        .mem_data_out(mem_wb_mem_data),    
        .alu_result_out(mem_wb_alu_result),
        .decoded_inst_out(mem_wb_decoded_inst),
        .store_data_in(ex_mem_store_data_out),
        .store_data_out(mem_wb_store_data)
    );


    logic [4:0]            wb_rd;
    logic [DATA_WIDTH-1:0] wb_data;
    logic                  wb_enable;

    WBStage #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) wb_stage_inst (
        .clk(clk),
        .reset(reset),

        .is_mem_wb_flush(mem_wb_flush_out),
        .mem_data_in(mem_wb_mem_data),
        .alu_result_in(mem_wb_alu_result),
        .decoded_inst_in(mem_wb_decoded_inst),
        .store_data_in(mem_wb_store_data),
        
        .wb_rd(wb_rd),
        .wb_data(wb_data),
        .wb_enable(wb_enable),
        .wb_pc(wb_pc),

        //ecall stuff
        .a0(a0), .a1(a1), .a2(a2), .a3(a3), .a4(a4), .a5(a5), .a6(a6), .a7(a7),
        .ecall_stall(ecall_stall)
    );


    ControlUnit control (

        .if_id_inst(if_id_decoded_inst),
        .id_ex_inst(id_ex_decoded_inst),
        .ex_mem_inst(ex_mem_decoded_inst),
        .mem_wb_inst(mem_wb_decoded_inst),
        
        .if_id_flush_out(if_id_flush_out),
        .id_ex_flush_out(id_ex_flush_out),
        .ex_mem_flush_out(ex_mem_flush_out),
        .mem_wb_flush_out(mem_wb_flush_out),
                
        .read_done(read_done),
        .write_done(write_done),
        .icache_valid_if(icache_valid_if),
        
        .ecall_stall(ecall_stall),
        .mem_branch_taken(ex_mem_branch_taken),

        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex),
        .flush_ex_mem(flush_ex_mem),
        .flush_mem_wb(flush_mem_wb),

        .enable_if_id(enable_if_id),
        .enable_id_ex(enable_id_ex),
        .enable_ex_mem(enable_ex_mem),
        .enable_mem_wb(enable_mem_wb),
        .enable_pc(enable_pc)
    );


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
          
            pc <= entry;
            //$display("Initializing top, entry point = 0x%h", entry);
        end else if (enable_pc) begin
            pc <= pc + 64'd4;
            //$display("Top: Updating PC to 0x%h", pc + 64'd4);
        end else if (mem_wb_decoded_inst.ecall_flag) begin 
            pc <= mem_wb_decoded_inst.addr + 64'd4;
            //$display("Top: ECALL - PC kept at 0x%h.", mem_wb_decoded_inst.addr + 64'd4);
        end else if (ex_mem_branch_taken) begin 
            pc <= ex_mem_branch_target;
            //if (ex_mem_branch_target == entry) $finish;
            //$display("Top: Branch taken. Updating PC to 0x%h", branch_target_ex);
        end else begin
            pc <= pc;
            //$display("Top: Stalling PC to 0x%h", pc);
        end
    end

    // always_comb begin
    //     if (pc == 32'h00000000000000d8) begin
    //         $finish;
    //     end
    // end

    // logic [63:0] debug_1_if_id_pc = if_id_decoded_inst.addr;
    // logic [6:0]  debug_1_if_id_opcode = if_id_decoded_inst;
    // logic [4:0]  debug_1_if_id_rd = if_id_decoded_inst.addr;
    // logic [4:0]  debug_1_if_id_rs1 = if_id_decoded_inst.addr;
    // logic [4:0]  debug_1_if_id_rs2 = if_id_decoded_inst.addr;
    // logic [31:0] debug_1_if_id_imm = if_id_decoded_inst.addr;
    // logic [1:0]  debug_1_if_id_width_32 = if_id_decoded_inst.addr;
    // logic [2:0]  debug_1_if_id_funct3 = if_id_decoded_inst.addr;
    // logic [6:0]  debug_1_if_id_funct7 = if_id_decoded_inst.addr;
    // logic debug_1_if_id_reg_write = if_id_decoded_inst.addr;
    // logic debug_1_if_id_alu_src_imm = if_id_decoded_inst.addr;
    // logic debug_1_if_id_mem_read = if_id_decoded_inst.addr;
    // logic debug_1_if_id_mem_write = if_id_decoded_inst.addr;
    // logic [1:0]   debug_1_if_id_mem_size = if_id_decoded_inst.addr;
    // logic debug_1_if_id_branch_taken = if_id_decoded_inst.addr;
    // logic debug_1_if_id_ecall_flag = if_id_decoded_inst.addr;



endmodule
