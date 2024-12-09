// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary design header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef _Vtop_H_
#define _Vtop_H_

#include "verilated_heavy.h"
#include "Vtop__Inlines.h"
#include "Vtop__Dpi.h"

class Vtop__Syms;
class Vtop___024unit;

//----------

VL_MODULE(Vtop) {
  public:
    // CELLS
    // Public to allow access to /*verilator_public*/ items;
    // otherwise the application code can consider these internals.
    Vtop___024unit*    	__PVT____024unit;
    
    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(clk,0,0);
    VL_IN8(reset,0,0);
    VL_IN8(hz32768timer,0,0);
    VL_OUT8(m_axi_awlen,7,0);
    VL_OUT8(m_axi_awsize,2,0);
    VL_OUT8(m_axi_awburst,1,0);
    VL_OUT8(m_axi_awlock,0,0);
    VL_OUT8(m_axi_awcache,3,0);
    VL_OUT8(m_axi_awprot,2,0);
    VL_OUT8(m_axi_awvalid,0,0);
    VL_IN8(m_axi_awready,0,0);
    VL_OUT8(m_axi_wstrb,7,0);
    VL_OUT8(m_axi_wlast,0,0);
    VL_OUT8(m_axi_wvalid,0,0);
    VL_IN8(m_axi_wready,0,0);
    VL_IN8(m_axi_bresp,1,0);
    VL_IN8(m_axi_bvalid,0,0);
    VL_OUT8(m_axi_bready,0,0);
    VL_OUT8(m_axi_arlen,7,0);
    VL_OUT8(m_axi_arsize,2,0);
    VL_OUT8(m_axi_arburst,1,0);
    VL_OUT8(m_axi_arlock,0,0);
    VL_OUT8(m_axi_arcache,3,0);
    VL_OUT8(m_axi_arprot,2,0);
    VL_OUT8(m_axi_arvalid,0,0);
    VL_IN8(m_axi_arready,0,0);
    VL_IN8(m_axi_rresp,1,0);
    VL_IN8(m_axi_rlast,0,0);
    VL_IN8(m_axi_rvalid,0,0);
    VL_OUT8(m_axi_rready,0,0);
    VL_IN8(m_axi_acvalid,0,0);
    VL_OUT8(m_axi_acready,0,0);
    VL_IN8(m_axi_acsnoop,3,0);
    //char	__VpadToAlign33[1];
    VL_OUT16(m_axi_awid,12,0);
    VL_IN16(m_axi_bid,12,0);
    VL_OUT16(m_axi_arid,12,0);
    VL_IN16(m_axi_rid,12,0);
    //char	__VpadToAlign42[6];
    VL_IN64(entry,63,0);
    VL_IN64(stackptr,63,0);
    VL_IN64(satp,63,0);
    VL_OUT64(m_axi_awaddr,63,0);
    VL_OUT64(m_axi_wdata,63,0);
    VL_OUT64(m_axi_araddr,63,0);
    VL_IN64(m_axi_rdata,63,0);
    VL_IN64(m_axi_acaddr,63,0);
    
    // LOCAL SIGNALS
    // Internals; generally not touched by application code
    VL_SIG8(top__DOT__read_done,0,0);
    VL_SIG8(top__DOT__write_done,0,0);
    VL_SIG8(top__DOT__ecall_stall,0,0);
    VL_SIG8(top__DOT__icache_arvalid,0,0);
    VL_SIG8(top__DOT__icache_arready,0,0);
    VL_SIG8(top__DOT__icache_rvalid,0,0);
    VL_SIG8(top__DOT__icache_rlast,0,0);
    VL_SIG8(top__DOT__icache_rready,0,0);
    VL_SIG8(top__DOT__dcache_arvalid,0,0);
    VL_SIG8(top__DOT__dcache_arready,0,0);
    VL_SIG8(top__DOT__dcache_rvalid,0,0);
    VL_SIG8(top__DOT__dcache_rlast,0,0);
    VL_SIG8(top__DOT__dcache_rready,0,0);
    VL_SIG8(top__DOT__enable_if_id,0,0);
    VL_SIG8(top__DOT__flush_if_id,0,0);
    VL_SIG8(top__DOT__if_id_flush_out,0,0);
    VL_SIG8(top__DOT__flush_id_ex,0,0);
    VL_SIG8(top__DOT__id_ex_flush_out,0,0);
    VL_SIG8(top__DOT__flush_ex_mem,0,0);
    VL_SIG8(top__DOT__ex_mem_flush_out,0,0);
    VL_SIG8(top__DOT__flush_mem_wb,0,0);
    VL_SIG8(top__DOT__mem_wb_flush_out,0,0);
    VL_SIG8(top__DOT__icache_valid_if,0,0);
    VL_SIG8(top__DOT__ex_mem_branch_taken,0,0);
    VL_SIG8(top__DOT__wb_rd,4,0);
    VL_SIG8(top__DOT__wb_enable,0,0);
    VL_SIG8(top__DOT__arbiter_inst__DOT__current_state,1,0);
    VL_SIG8(top__DOT__arbiter_inst__DOT__next_state,1,0);
    VL_SIG8(top__DOT__arbiter_inst__DOT__servicing_icache,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__hit_way0,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__hit_way1,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__current_state,2,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__next_state,2,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__need_refill,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__lru_way,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__flush_prev,0,0);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__flush_rising_edge,0,0);
    VL_SIG8(top__DOT__ex_stage__DOT__branch_taken,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__hit_way0,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__hit_way1,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__selected_way,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__current_state,3,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__next_state,3,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__need_refill,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__need_write,0,0);
    VL_SIG8(top__DOT__wb_stage_inst__DOT__ecall_done,0,0);
    VL_SIG8(top__DOT__control__DOT__stall_if_id,0,0);
    VL_SIG8(top__DOT__control__DOT__stall_ex_mem,0,0);
    VL_SIG8(top__DOT__control__DOT__stall_mem_wb,0,0);
    //char	__VpadToAlign165[1];
    VL_SIG16(top__DOT__decoder_inst__DOT__unnamedblk1__DOT__unnamedblk3__DOT__b_imm,12,0);
    VL_SIG16(top__DOT__decoder_inst__DOT__unnamedblk1__DOT__unnamedblk4__DOT__s_imm,11,0);
    //char	__VpadToAlign170[2];
    VL_SIG(top__DOT__instruction_out_if,31,0);
    VL_SIG(top__DOT__instruction_out_if_id,31,0);
    //char	__VpadToAlign180[4];
    VL_SIGW(top__DOT__if_stage_inst__DOT__icache_inst__DOT__refill_data,511,0,16);
    VL_SIG(top__DOT__if_stage_inst__DOT__icache_inst__DOT__beat_counter,31,0);
    VL_SIG(top__DOT__if_stage_inst__DOT__icache_inst__DOT__unnamedblk1__DOT__i,31,0);
    VL_SIG(top__DOT__if_stage_inst__DOT__icache_inst__DOT__unnamedblk5__DOT__bit_position,31,0);
    VL_SIG(top__DOT__decoder_inst__DOT__unnamedblk1__DOT__unnamedblk2__DOT__jal_imm,20,0);
    VL_SIGW(top__DOT__ex_stage__DOT__alu_inst__DOT__mul_result,127,0,4);
    VL_SIGW(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__refill_data,511,0,16);
    VL_SIG(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__beat_counter,31,0);
    VL_SIG(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__write_beat_counter,31,0);
    VL_SIG(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__unnamedblk1__DOT__i,31,0);
    //char	__VpadToAlign356[4];
    VL_SIG64(top__DOT__icache_araddr,63,0);
    VL_SIG64(top__DOT__icache_rdata,63,0);
    VL_SIG64(top__DOT__dcache_araddr,63,0);
    VL_SIG64(top__DOT__dcache_rdata,63,0);
    VL_SIG64(top__DOT__pc,63,0);
    VL_SIG64(top__DOT__pc_out_if_id,63,0);
    VL_SIGW(top__DOT__if_id_decoded_inst,170,0,6);
    VL_SIG64(top__DOT__rs1_data_id,63,0);
    VL_SIG64(top__DOT__rs2_data_id,63,0);
    VL_SIGW(top__DOT__id_ex_decoded_inst,170,0,6);
    VL_SIG64(top__DOT__rs1_data_ex,63,0);
    VL_SIG64(top__DOT__rs2_data_ex,63,0);
    VL_SIG64(top__DOT__a0,63,0);
    VL_SIG64(top__DOT__a1,63,0);
    VL_SIG64(top__DOT__a2,63,0);
    VL_SIG64(top__DOT__a3,63,0);
    VL_SIG64(top__DOT__a4,63,0);
    VL_SIG64(top__DOT__a5,63,0);
    VL_SIG64(top__DOT__a6,63,0);
    VL_SIG64(top__DOT__a7,63,0);
    VL_SIG64(top__DOT__ex_mem_alu_result,63,0);
    VL_SIG64(top__DOT__ex_mem_store_data_out,63,0);
    VL_SIGW(top__DOT__ex_mem_decoded_inst,170,0,6);
    VL_SIG64(top__DOT__ex_mem_branch_target,63,0);
    VL_SIG64(top__DOT__mem_data_mem,63,0);
    VL_SIG64(top__DOT__mem_wb_mem_data,63,0);
    VL_SIG64(top__DOT__mem_wb_alu_result,63,0);
    VL_SIGW(top__DOT__mem_wb_decoded_inst,170,0,6);
    VL_SIG64(top__DOT__mem_wb_store_data,63,0);
    VL_SIG64(top__DOT__wb_data,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__operand_b,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_result,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__branch_target,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__intermediate_result,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__a_sig,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__b_sig,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__product,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__unnamedblk1__DOT__sign_extended_imm,63,0);
    VL_SIG64(top__DOT__ex_stage__DOT__alu_inst__DOT__unnamedblk2__DOT__sign_extended_imm,63,0);
    VL_SIG64(top__DOT__mem_stage_inst__DOT__mem_load_data,63,0);
    VL_SIG64(top__DOT__wb_stage_inst__DOT__ecall_return_val,63,0);
    VL_SIGW(top__DOT__if_stage_inst__DOT__icache_inst__DOT__cache[512][2],561,0,18);
    VL_SIG8(top__DOT__if_stage_inst__DOT__icache_inst__DOT__lru[512],0,0);
    VL_SIG64(top__DOT__regfile_inst__DOT__registers[32],63,0);
    VL_SIGW(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__cache[512][2],561,0,18);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT__lru[512],0,0);
    
    // LOCAL VARIABLES
    // Internals; generally not touched by application code
    VL_SIG8(top__DOT__mem_stage_inst__DOT____Vcellinp__dcache_inst__valid_in,0,0);
    VL_SIG8(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT____Vlvbound1,7,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__0__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__1__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__2__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__3__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__4__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__5__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__6__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__7__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__8__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__9__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__10__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__11__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__12__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__13__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__14__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__15__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__16__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__17__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__18__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__19__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__20__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__21__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__22__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__23__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__24__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__25__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__26__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__27__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__28__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__29__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__30__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__31__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__32__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__33__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__34__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__35__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__36__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__37__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__38__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__39__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__40__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__41__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__42__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__43__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__44__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__45__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__46__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__47__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__48__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__49__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__50__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__51__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__52__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__53__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__54__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__55__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__56__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__57__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__58__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__59__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__60__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__61__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__62__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__63__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__64__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__65__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__66__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__67__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__68__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__69__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__70__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__71__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__72__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__73__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__74__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__75__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__76__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__77__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__78__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__79__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__80__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__81__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__82__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__83__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__84__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__85__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__86__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__87__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__88__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__89__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__90__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__91__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__92__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__93__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__94__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__95__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__96__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__97__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__98__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__99__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__100__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__101__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__102__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__103__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__104__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__105__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__106__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__107__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__108__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__109__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__110__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__111__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__112__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__113__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__114__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__115__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__116__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__117__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__118__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__119__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__120__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__121__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__122__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__123__reg_num,4,0);
    VL_SIG8(__Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__124__reg_num,4,0);
    VL_SIG8(__Vclklast__TOP__clk,0,0);
    VL_SIG8(__Vclklast__TOP__reset,0,0);
    //char	__VpadToAlign149621[1];
    VL_SIG16(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT____Vlvbound2,15,0);
    VL_SIG(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT____Vlvbound3,31,0);
    //char	__VpadToAlign149628[4];
    VL_SIG64(top__DOT__mem_stage_inst__DOT__dcache_inst__DOT____Vlvbound4,63,0);
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__0__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__1__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__2__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__3__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__4__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__5__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__6__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__7__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__8__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__9__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__10__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__11__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__12__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__13__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__14__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__15__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__16__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__17__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__18__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__19__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__20__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__21__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__22__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__23__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__24__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__25__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__26__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__27__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__28__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__29__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__30__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__31__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__32__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__33__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__34__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__35__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__36__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__37__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__38__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__39__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__40__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__41__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__42__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__43__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__44__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__45__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__46__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__47__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__48__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__49__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__50__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__51__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__52__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__53__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__54__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__55__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__56__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__57__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__58__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__59__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__60__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__61__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__62__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__63__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__64__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__65__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__66__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__67__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__68__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__69__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__70__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__71__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__72__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__73__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__74__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__75__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__76__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__77__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__78__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__79__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__80__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__81__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__82__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__83__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__84__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__85__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__86__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__87__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__88__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__89__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__90__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__91__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__92__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__93__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__94__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__95__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__96__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__97__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__98__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__99__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__100__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__101__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__102__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__103__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__104__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__105__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__106__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__107__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__108__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__109__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__110__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__111__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__112__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__113__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__114__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__115__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__116__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__117__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__118__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__119__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__120__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__121__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__122__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__123__Vfuncout;
    string __Vfunc_top__DOT__decoder_inst__DOT__get_reg_name__124__Vfuncout;
    
    // INTERNAL VARIABLES
    // Internals; generally not touched by application code
    //char	__VpadToAlign149644[4];
    Vtop__Syms*	__VlSymsp;		// Symbol table
    
    // PARAMETERS
    // Parameters marked /*verilator public*/ for use by application code
    
    // CONSTRUCTORS
  private:
    Vtop& operator= (const Vtop&);	///< Copying not allowed
    Vtop(const Vtop&);	///< Copying not allowed
  public:
    /// Construct the model; called by application code
    /// The special name  may be used to make a wrapper with a
    /// single model invisible WRT DPI scope names.
    Vtop(const char* name="TOP");
    /// Destroy the model; called (often implicitly) by application code
    ~Vtop();
    
    // USER METHODS
    
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval();
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    
    // INTERNAL METHODS
  private:
    static void _eval_initial_loop(Vtop__Syms* __restrict vlSymsp);
  public:
    void __Vconfigure(Vtop__Syms* symsp, bool first);
  private:
    static QData	_change_request(Vtop__Syms* __restrict vlSymsp);
  public:
    static void	_combo__TOP__10(Vtop__Syms* __restrict vlSymsp);
    static void	_combo__TOP__12(Vtop__Syms* __restrict vlSymsp);
    static void	_combo__TOP__4(Vtop__Syms* __restrict vlSymsp);
    static void	_combo__TOP__7(Vtop__Syms* __restrict vlSymsp);
  private:
    void	_configure_coverage(Vtop__Syms* __restrict vlSymsp, bool first);
    void	_ctor_var_reset();
  public:
    static void	_eval(Vtop__Syms* __restrict vlSymsp);
    static void	_eval_initial(Vtop__Syms* __restrict vlSymsp);
    static void	_eval_settle(Vtop__Syms* __restrict vlSymsp);
    static void	_initial__TOP__1(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__2(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__5(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__8(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__11(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__3(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__6(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__9(Vtop__Syms* __restrict vlSymsp);
} VL_ATTR_ALIGNED(128);

#endif  /*guard*/
