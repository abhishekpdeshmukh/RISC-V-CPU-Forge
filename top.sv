// IFStage Module with FSM-based AXI4 Read Burst Handling
`include "Sysbus.defs"
`include "pipeline_reg.sv"
`include "fetcher.sv"
`include "decode.sv"
`include "alu.sv"
`include "regfile.sv"
`include "execute.sv"
`include "hazard.sv"


// Top Module Integrating IFStage, IF_ID, IDStage, ID_EX, EXStage, Regfile, and HDU
module top #(
    parameter ID_WIDTH    = 13,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter STRB_WIDTH  = DATA_WIDTH / 8
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    hz32768timer,

    // 64-bit addresses of the program entry point and initial stack pointer
    input  logic [63:0]             entry,
    input  logic [63:0]             stackptr,
    input  logic [63:0]             satp,

    // AXI interface signals
    // AXI4 Write Address Channel
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

    // AXI4 Write Data Channel
    output logic [DATA_WIDTH-1:0]    m_axi_wdata,
    output logic [STRB_WIDTH-1:0]    m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,

    // AXI4 Write Response Channel
    input  logic [ID_WIDTH-1:0]      m_axi_bid,
    input  logic [1:0]               m_axi_bresp,
    input  logic                     m_axi_bvalid,
    output logic                     m_axi_bready,

    // AXI4 Read Address Channel
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

    // AXI4 Read Data Channel
    input  logic [ID_WIDTH-1:0]      m_axi_rid,
    input  logic [DATA_WIDTH-1:0]    m_axi_rdata,
    input  logic [1:0]               m_axi_rresp,
    input  logic                     m_axi_rlast,
    input  logic                     m_axi_rvalid,
    output logic                     m_axi_rready,

    // AXI4 Additional Signals (Assuming they're needed elsewhere)
    input  logic                     m_axi_acvalid,
    output logic                     m_axi_acready,
    input  logic [ADDR_WIDTH-1:0]    m_axi_acaddr,
    input  logic [3:0]               m_axi_acsnoop
);

    // Initialize AXI write channels to default values
    assign m_axi_awid     = '0;
    assign m_axi_awaddr   = '0;
    assign m_axi_awlen    = '0;
    assign m_axi_awsize   = '0;
    assign m_axi_awburst  = '0;
    assign m_axi_awlock   = '0;
    assign m_axi_awcache  = '0;
    assign m_axi_awprot   = '0;
    assign m_axi_awvalid  = '0;
    assign m_axi_wdata    = '0;
    assign m_axi_wstrb    = '0;
    assign m_axi_wlast    = '0;
    assign m_axi_wvalid   = '0;
    assign m_axi_bready   = '0;
    assign m_axi_acready  = '0;

    // Program Counter
    logic [63:0] pc;
    logic [63:0] pc_plus_4;

    // IF Stage Outputs
    logic [31:0] instruction_if;
    logic        if_valid;

    // IF/ID Pipeline Register Outputs
    logic [31:0] instruction_id;
    logic [63:0] pc_id;
    logic        id_valid;

    // ID Stage Outputs
    logic [4:0]            wb_rd_id;
    logic [63:0]           wb_data_id;
    logic                  wb_enable_id;
    decoded_inst_t         decoded_inst_id;
    logic [63:0]           rs1_data_id;
    logic [63:0]           rs2_data_id;
    logic [63:0]           imm_id;
    logic                  alu_src_id;
    logic                  mem_read_id;
    logic                  mem_write_id;
    logic                  reg_write_id;

    // ID/EX Pipeline Register Outputs
    decoded_inst_t         decoded_inst_ex;
    logic [63:0]           rs1_data_ex;
    logic [63:0]           rs2_data_ex;
    logic [63:0]           imm_ex;
    logic                  alu_src_ex;
    logic                  mem_read_ex;
    logic                  mem_write_ex;
    logic                  reg_write_ex;

    // EXStage Outputs
    logic [63:0]           alu_result_ex;
    logic                  alu_zero_ex;
    logic                  mem_read_ex_mem;
    logic                  mem_write_ex_mem;
    logic                  reg_write_ex_mem;
    logic [4:0]            wb_rd_ex_mem;

    // Branch signals from EXStage
    logic                  branch_taken_ex;
    logic [63:0]           branch_target_ex;

    // Hazard Detection Unit Control Signals
    logic                  stall_if_id;
    logic                  stall_pc;
    logic                  flush_if_id;
    logic                  flush_id_ex;

    // Instantiate Hazard Detection Unit
    HazardDetectionUnit hdu (
        .clk(clk),
        .reset(reset),
        // IDs and control signals
        .id_ex_rd(decoded_inst_ex.rd),
        .id_ex_mem_read(mem_read_ex),
        .if_id_rs1(decoded_inst_id.rs1),
        .if_id_rs2(decoded_inst_id.rs2),
        .branch_taken_ex(branch_taken_ex),
        // Control signals
        .stall_if_id(stall_if_id),
        .stall_pc(stall_pc),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );

    // Instantiate IFStage
    IFStage #(
        .ID_WIDTH(13),
        .ADDR_WIDTH(64),
        .DATA_WIDTH(64),
        .STRB_WIDTH(8)
    ) if_stage_inst (
        .clk(clk),
        .reset(reset),
        .pc_in(pc),
        .instruction_out(instruction_if),
        .pc_plus_4(pc_plus_4),
        .if_valid(if_valid),

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

        // Control Inputs
        .flush(flush),
        .stall(stall)
        //.ecall_detected(ecall_detected) // Connected from WBStage or appropriate module
    );

    // Instantiate IF/ID Pipeline Register with Stall and Flush
    IF_ID if_id_inst (
        .clk(clk),
        .reset(reset),
        .stall(stall_if_id),
        .flush(flush_if_id),
        .instruction_in(instruction_if),
        .pc_in(pc),
        .valid_in(if_valid),
        .instruction_out(instruction_id),
        .pc_out(pc_id),
        .valid_out(id_valid)
    );

    // Instantiate IDStage
    IDStage id_stage (
        .clk(clk),
        .reset(reset),
        .instruction_in(instruction_id),
        .pc_in(pc_id),
        // Outputs to Regfile
        .wb_rd(wb_rd_id),
        .wb_data(wb_data_id),
        .wb_enable(wb_enable_id),
        // Outputs to Pipeline Register
        .decoded_inst(decoded_inst_id),
        .rs1_data(rs1_data_id),
        .rs2_data(rs2_data_id),
        .imm(imm_id),
        .alu_src(alu_src_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .reg_write(reg_write_id)
    );

    // Instantiate ID/EX Pipeline Register with Flush
    ID_EX id_ex_inst (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),          // No stall signal for ID/EX in this implementation
        .flush(flush_id_ex),
        .decoded_inst_in(decoded_inst_id),
        .rs1_data_in(rs1_data_id),
        .rs2_data_in(rs2_data_id),
        .imm_in(imm_id),
        .alu_src_in(alu_src_id),
        .mem_read_in(mem_read_id),
        .mem_write_in(mem_write_id),
        .reg_write_in(reg_write_id),
        .decoded_inst_out(decoded_inst_ex),
        .rs1_data_out(rs1_data_ex),
        .rs2_data_out(rs2_data_ex),
        .imm_out(imm_ex),
        .alu_src_out(alu_src_ex),
        .mem_read_out(mem_read_ex),
        .mem_write_out(mem_write_ex),
        .reg_write_out(reg_write_ex)
    );

    // Instantiate EXStage
    EXStage ex_stage (
        .clk(clk),
        .reset(reset),
        .decoded_inst_in(decoded_inst_ex),
        .rs1_data_in(rs1_data_ex),
        .rs2_data_in(rs2_data_ex),
        .imm_in(imm_ex),
        .alu_src_in(alu_src_ex),
        .mem_read_in(mem_read_ex),
        .mem_write_in(mem_write_ex),
        .reg_write_in(reg_write_ex),
        .alu_result_out(alu_result_ex),
        .alu_zero_out(alu_zero_ex),
        .mem_read_out(mem_read_ex_mem),
        .mem_write_out(mem_write_ex_mem),
        .reg_write_out(reg_write_ex_mem),
        .wb_rd_out(wb_rd_ex_mem),
        // Branch outputs
        .branch_taken_out(branch_taken_ex),
        .branch_target_out(branch_target_ex)
    );

    // Instantiate Regfile in the top module
    Regfile regfile_inst (
        .clk(clk),
        .reset(reset),
        .initial_sp(stackptr),
        .rs1(decoded_inst_id.rs1),     // Connection to source register rs1
        .rs2(decoded_inst_id.rs2),     // Connection to source register rs2
        .rd1_data(rs1_data_id),
        .rd2_data(rs2_data_id),
        .rd(wb_rd_ex_mem),              // Destination register from EX/MEM stage
        .rd_data(wb_data_id),           // Data to write back (ALU result or return address)
        .write_enable(reg_write_ex_mem) // Write enable from EX/MEM stage
    );

    // Assign Regfile write-back data
    // Modify this assignment to handle different types of write-back data
    // For example, for `JAL` and `JALR`, `wb_data_id` should be `pc + 4`
    assign wb_data_id = (decoded_inst_id.opcode == 7'b1101111 || decoded_inst_id.opcode == 7'b1100111) ? 
                        (pc_id + 4) : alu_result_ex;

    // Program Counter Update Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= entry;
            $display("Initializing top, entry point = 0x%x", entry);
        end else begin
            if (!stall_pc) begin
                if (branch_taken_ex) begin
                    pc <= branch_target_ex; // Update PC to branch target if branch is taken
                    $display("Top: Branch taken. Updating PC to 0x%h", branch_target_ex);
                end else if (flush_if_id) begin
                    pc <= branch_target_ex; // Update PC to branch target on flush
                    $display("Top: Flush occurred. Updating PC to 0x%h", branch_target_ex);
                end else begin
                    pc <= pc_plus_4; // **Uncommented to ensure PC increments normally**
                    $display("Top: PC updated to 0x%h.", pc_plus_4);
                end
            end
        end
    end



    // Note: Ensure that the Regfile's rs1 and rs2 are correctly connected to the decoded instruction's rs1 and rs2
    // This may require additional signals or connections based on your pipeline's architecture

endmodule

