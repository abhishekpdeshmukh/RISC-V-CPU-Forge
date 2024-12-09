module ControlUnit (

    input  packed_inst    if_id_inst,   
    input  packed_inst    id_ex_inst,   
    input  packed_inst    ex_mem_inst,  
    input  packed_inst    mem_wb_inst,  

    input  logic         if_id_flush_out,
    input  logic         id_ex_flush_out,
    input  logic         ex_mem_flush_out,
    input  logic         mem_wb_flush_out,

    input  logic         read_done,       
    input  logic         write_done,       
    input  logic         ecall_stall,
    input  logic         mem_branch_taken,
    input  logic         icache_valid_if,


    output   logic         flush_if_id,
    output   logic         flush_id_ex,
    output   logic         flush_ex_mem,
    output   logic         flush_mem_wb,

    output   logic         enable_if_id,
    output   logic         enable_id_ex,
    output   logic         enable_ex_mem,
    output   logic         enable_mem_wb,
    output   logic         enable_pc
);


    logic         stall_pc;
    logic         stall_if_id;
    logic         stall_id_ex;
    logic         stall_ex_mem;
    logic         stall_mem_wb;

    logic [4:0] if_id_rs1, if_id_rs2;

    assign if_id_rs1 = if_id_inst.rs1;
    assign if_id_rs2 = if_id_inst.rs2;

    always_comb begin

        stall_pc      = 1'b0;
        stall_if_id   = 1'b0;
        stall_id_ex   = 1'b0;
        stall_ex_mem  = 1'b0;
        stall_mem_wb  = 1'b0;
        flush_if_id   = 1'b0;
        flush_id_ex   = 1'b0;
        flush_ex_mem  = 1'b0;
        flush_mem_wb  = 1'b0;
        
        if (mem_branch_taken) begin

            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
            flush_ex_mem  = 1'b1;
            //$display("Detected control hazard: branch_taken_ex=%d. Inserting bubble by flushing.", mem_branch_taken);
        end 

        // ECALL Detection 
        if (ecall_stall ) begin //AKA TODO - CHECK THIS I THINK WE NEED TO DO LIKE ABOVE

            stall_mem_wb  = 1'b1;
            flush_if_id   = 1'b1;
            flush_id_ex   = 1'b1;
            flush_ex_mem  = 1'b1;
            flush_mem_wb  = 1'b1;
            //$display("Detected ECALL hazard");
        end
            

        if (!if_id_flush_out) begin
            

            if (ex_mem_inst.mem_read && !read_done) begin

                stall_pc       = 1'b1;
                flush_mem_wb   = 1'b1;
                stall_ex_mem   = 1'b1;
                //$display("Detected load hazard: id_ex_mem_read=%d, id_ex_rd=x%0d, if_id_rs1=x%0d, if_id_rs2=x%0d, read_done=%d", ex_mem_inst.mem_read, id_ex_inst.rd, if_id_rs1, if_id_rs2, read_done);
            end

            if (ex_mem_inst.mem_write && !write_done) begin

                stall_pc       = 1'b1;
                flush_mem_wb   = 1'b1;
                stall_ex_mem   = 1'b1;
                //$display("Detected store miss: id_ex_mem_write=%d, id_ex_rd=x%0d, write_done=%d",ex_mem_inst.mem_write, id_ex_inst.rd, write_done);
            end


            if (!mem_wb_flush_out && mem_wb_inst.reg_write && (mem_wb_inst.rd != '0) &&
                ((mem_wb_inst.rd == if_id_rs1) || (mem_wb_inst.rd == if_id_rs2))) begin

                stall_if_id   = 1'b1;
                flush_id_ex   = 1'b1;
                stall_pc      = 1'b1;
                //$display("Detected RAW hazard with MEM/WB: mem_wb_rd=x%0d, if_id_rs1=x%0d, if_id_rs2=x%0d",mem_wb_inst.rd, if_id_rs1, if_id_rs2);
            end

            if (!ex_mem_flush_out && ex_mem_inst.reg_write && (ex_mem_inst.rd != '0) &&
                ((ex_mem_inst.rd == if_id_rs1) || (ex_mem_inst.rd == if_id_rs2))) begin

                stall_if_id = 1'b1;
                flush_id_ex   = 1'b1;
                stall_pc    = 1'b1;           
                //$display("Detected RAW hazard with EX/MEM: ex_mem_rd=x%0d, if_id_rs1=x%0d, if_id_rs2=x%0d",ex_mem_inst.rd, if_id_rs1, if_id_rs2);
            end

            if (!id_ex_flush_out && id_ex_inst.reg_write && (id_ex_inst.rd != '0) &&
                ((id_ex_inst.rd == if_id_rs1) || (id_ex_inst.rd == if_id_rs2))) begin

                stall_if_id = 1'b1;
                flush_id_ex   = 1'b1;
                stall_pc    = 1'b1;
                //$display("Detected RAW hazard with ID/EX: id_ex_rd=x%0d, if_id_rs1=x%0d, if_id_rs2=x%0d",id_ex_inst.rd, if_id_rs1, if_id_rs2);
            end     
          
        end
    end
    assign enable_mem_wb = !stall_mem_wb;
    assign enable_ex_mem = !stall_ex_mem;
    assign enable_id_ex = enable_ex_mem && !stall_id_ex;
    assign enable_if_id = (enable_id_ex && !stall_if_id) || mem_branch_taken || ecall_stall;
    assign enable_pc = enable_if_id && icache_valid_if && !mem_branch_taken && !ecall_stall;

endmodule
