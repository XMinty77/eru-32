// Extends loaded data to 32 bits, from the load's funct3.
module load_ext (
    input  logic [2:0]  funct3_i,
    input  logic [31:0] data_i,
    output logic [31:0] data_o
);
    import eru_pkg::*;

    always_comb case (funct3_i)
        F3_LB:   data_o = {{24{data_i[7]}}, data_i[7:0]};
        F3_LH:   data_o = {{16{data_i[15]}}, data_i[15:0]};
        F3_LW:   data_o = data_i;
        F3_LBU:  data_o = {24'b0, data_i[7:0]};
        F3_LHU:  data_o = {16'b0, data_i[15:0]};
        default: data_o = 'x;
    endcase
endmodule
