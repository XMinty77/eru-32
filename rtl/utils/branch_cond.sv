// Whether a branch is taken, from its funct3 and the ALU flags.
module branch_cond (
    input  logic [2:0] funct3_i,
    input  logic       eq_i,
    input  logic       lt_i,
    output logic       taken_o
);
    always_comb case (funct3_i)
        3'b000:  taken_o = eq_i;
        3'b001:  taken_o = !eq_i;
        3'b100:  taken_o = lt_i;
        3'b101:  taken_o = !lt_i;
        3'b110:  taken_o = lt_i;
        3'b111:  taken_o = !lt_i;
        default: taken_o = 'x;
    endcase
endmodule
