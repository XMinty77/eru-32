// The two dedicated adders on the PC.
module pc_adder (
    input  logic [31:0] pc_i,
    input  logic [31:0] imm_i,
    output logic [31:0] pc_plus4_o,
    output logic [31:0] pc_plus_imm_o
);
    assign pc_plus4_o    = pc_i + 32'd4;
    assign pc_plus_imm_o = pc_i + imm_i;
endmodule
