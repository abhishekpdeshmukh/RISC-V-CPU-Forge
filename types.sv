`ifndef TYPES_SV
`define TYPES_SV

// Define the structure for a decoded instruction
typedef struct packed {
    logic [63:0] addr;
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm;
    logic [1:0]  width_32;   // Indicates 32-bit operation
    logic [2:0]  funct3;
    logic [6:0]  funct7;
} decoded_inst_t;

`endif // TYPES_SV
