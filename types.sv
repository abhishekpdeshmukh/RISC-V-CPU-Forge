`ifndef TYPES_SV
`define TYPES_SV

// structure for a decoded instruction
typedef struct packed {
    logic [31:0] pc;
    logic [63:0] addr;
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm;
    logic [1:0]  width_32;   
    // logic [63:0] imm;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic reg_write;
    logic alu_src_imm;
    logic mem_read;
    logic mem_write;
    logic [1:0]   mem_size;
    logic branch_taken;
    logic ecall_flag;
    logic load_unsigned;
} packed_inst;

`endif 