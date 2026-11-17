module decoder
    import eru_pkg::*;
(
    input  logic        [31:0]  instr_i,
    output imm_op_e             imm_op_o,
    output logic                data_we_o,
    output logic                data_re_o,
    output logic                regfile_we_o,
    output alu_op_e             alu_op_o,
    output alu_a_sel_e          alu_a_sel_o,
    output alu_b_sel_e          alu_b_sel_o,
    output wb_sel_e             wb_sel_o,
    output pc_sel_e             pc_sel_o
);
    logic [6:0] opcode;
    logic [2:0] funct3;
    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];

    always_comb begin
        data_re_o = '0;
        data_we_o = '0;
        regfile_we_o = '0;

        alu_a_sel_o = SEL_RS1;
        alu_b_sel_o = SEL_IMM;
        alu_op_o = ADD;

        wb_sel_o = WB_ALU;
        pc_sel_o = PC_PC4;

        /* Branch:
         *  Specifies if needed
         *  Does not specify if is default from above
         *  Specifies 'x if don't care
         */
        case (opcode)
            ALU_R: begin
                imm_op_o = imm_op_e'('x);
                alu_op_o = alu_op_e'({instr_i[30], funct3});
                alu_b_sel_o = SEL_RS2;
                regfile_we_o = '1;
            end

            ALU_I: begin
                imm_op_o = I;
                alu_op_o = alu_op_e'({funct3 == 3'b101 ? instr_i[30] : 1'b0, funct3});
                regfile_we_o = '1;
            end

            LOAD: begin
                imm_op_o = I;
                data_re_o = '1;
                wb_sel_o = WB_LOAD;
                regfile_we_o = '1;
            end

            JALR: begin
                imm_op_o = I;
                wb_sel_o = WB_PC4;
                pc_sel_o = PC_JALR;
                regfile_we_o = '1;
            end

            STORE: begin
                imm_op_o = S;
                data_we_o = '1;
                wb_sel_o = wb_sel_e'('x);
            end

            BRANCH: begin
                imm_op_o = B;
                alu_op_o = alu_op_e'(funct3[1] ? SLTU : SLT);
                alu_b_sel_o = SEL_RS2;
                wb_sel_o = wb_sel_e'('x);
                pc_sel_o = PC_BRANCH;
            end

            LUI: begin
                imm_op_o = U;
                alu_op_o = alu_op_e'('x);
                alu_a_sel_o = alu_a_sel_e'('x);
                alu_b_sel_o = alu_b_sel_e'('x);
                wb_sel_o = WB_IMM;
                regfile_we_o = '1;
            end

            AUIPC: begin
                imm_op_o = U;
                alu_a_sel_o = SEL_PC;
                regfile_we_o = '1;
            end

            JAL: begin
                imm_op_o = J;
                alu_a_sel_o = SEL_PC;
                wb_sel_o = WB_PC4;
                pc_sel_o = PC_JAL;
                regfile_we_o = '1;
            end

            default: imm_op_o = imm_op_e'('x);
        endcase
    end
endmodule
