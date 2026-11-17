module immgen (
    input  eru_pkg::imm_op_e            op_i,
    input  logic                [31:7]  instr_imm_i,
    output logic                [31:0]  imm_o
);
    import eru_pkg::*;

    logic sign;
    
    assign sign = instr_imm_i[31];

    always_comb case (op_i)
        I: begin
            imm_o[31:11] = {(31-11+1){sign}};
            imm_o[10:0]  = instr_imm_i[30:20];
        end
        S: begin
            imm_o[31:11] = {(31-11+1){sign}};
            imm_o[10:5]  = instr_imm_i[30:25];
            imm_o[4:0]   = instr_imm_i[11:7];
        end
        B: begin
            imm_o[31:12] = {(31-12+1){sign}};
            imm_o[11]    = instr_imm_i[7];
            imm_o[10:5]  = instr_imm_i[30:25];
            imm_o[4:1]   = instr_imm_i[11:8];
            imm_o[0]     = '0;
        end
        U: begin
            imm_o[31:12] = instr_imm_i[31:12];
            imm_o[11:0]  = '0;
        end
        J: begin
            imm_o[31:20] = {(31-20+1){sign}};
            imm_o[19:12] = instr_imm_i[19:12];
            imm_o[11]    = instr_imm_i[20];
            imm_o[10:1]  = instr_imm_i[30:21];
            imm_o[0]     = '0;
        end
        default: imm_o = 'x;
    endcase
endmodule
