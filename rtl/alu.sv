module alu (
    input  logic [31:0]         a_i,
    input  logic [31:0]         b_i,
    input  eru_pkg::alu_op_e    op_i,
    output logic [31:0]         result_o,
    output logic                eq_o,
    output logic                lt_o
);
    import eru_pkg::*;

    always_comb begin
        result_o = '0;
        eq_o = (a_i == b_i);
        lt_o = (op_i == SLT) ? ($signed(a_i) < $signed(b_i)) : (a_i < b_i);

        case (op_i)
            ADD:        result_o = a_i + b_i;
            SUB:        result_o = a_i - b_i;
            XOR:        result_o = a_i ^ b_i;
            AND:        result_o = a_i & b_i;
            OR:         result_o = a_i | b_i;
            SLL:        result_o = a_i <<  b_i[4:0];
            SRL:        result_o = a_i >>  b_i[4:0];
            SRA:        result_o = $signed(a_i) >>> b_i[4:0];
            SLT, SLTU:  result_o = {31'b0, lt_o};
            default: ;
        endcase
    end
endmodule
