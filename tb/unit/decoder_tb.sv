// Unit bench for the decoder (docs/contracts.md, "Decoder"; docs/control.md).
//
// Every opcode (all 128), every funct3 and both values of instr[30] are applied,
// each with several fills of the other instruction bits, which the outputs must
// not depend on. Outputs control.md marks "don't care" (and imm_op_o for unknown
// opcodes) are not checked. A few real encodings are checked by name first.
module decoder_tb;
    import eru_pkg::*;

    logic [31:0] instr;
    logic [2:0]  imm_op;
    logic        data_we;
    logic        data_re;
    logic        regfile_we;
    logic [3:0]  alu_op;
    logic        alu_a_sel;
    logic        alu_b_sel;
    logic [1:0]  wb_sel;
    logic [1:0]  pc_sel;

    decoder dut (
        .instr_i      (instr),
        .imm_op_o     (imm_op),
        .data_we_o    (data_we),
        .data_re_o    (data_re),
        .regfile_we_o (regfile_we),
        .alu_op_o     (alu_op),
        .alu_a_sel_o  (alu_a_sel),
        .alu_b_sel_o  (alu_b_sel),
        .wb_sel_o     (wb_sel),
        .pc_sel_o     (pc_sel)
    );

    int checks = 0;

    // Bits the outputs may depend on: opcode [6:0], funct3 [14:12] and [30].
    localparam logic [31:0] USED = 32'h4000_707F;

    // Fills for the bits the outputs must ignore.
    localparam int NFILL = 8;

    // Expected outputs, from the per-signal tables in control.md. c_* is 1 where
    // the output is defined for the instruction's class.
    logic [2:0] e_imm_op;
    logic       e_data_we, e_data_re, e_regfile_we;
    logic [3:0] e_alu_op;
    logic       e_alu_a_sel, e_alu_b_sel;
    logic [1:0] e_wb_sel, e_pc_sel;
    logic       c_imm_op, c_alu_op, c_alu_a_sel, c_alu_b_sel, c_wb_sel;

    function automatic string class_name(input logic [6:0] opcode);
        case (opcode)
            7'b0110011: class_name = "R-type";
            7'b0010011: class_name = "I-type ALU";
            7'b0000011: class_name = "load";
            7'b1100111: class_name = "JALR";
            7'b0100011: class_name = "store";
            7'b1100011: class_name = "branch";
            7'b0110111: class_name = "LUI";
            7'b0010111: class_name = "AUIPC";
            7'b1101111: class_name = "JAL";
            default:    class_name = "unknown opcode";
        endcase
    endfunction

    task automatic expect_for(input logic [6:0] opcode, input logic [2:0] funct3,
                              input logic b30);
        // Defaults: the values contracts.md gives for any other opcode.
        e_imm_op     = 3'bx;
        e_data_we    = 1'b0;
        e_data_re    = 1'b0;
        e_regfile_we = 1'b0;
        e_alu_op     = ADD;
        e_alu_a_sel  = SEL_RS1;
        e_alu_b_sel  = SEL_IMM;
        e_wb_sel     = WB_ALU;
        e_pc_sel     = PC_PC4;
        c_imm_op     = 1'b0;
        c_alu_op     = 1'b1;
        c_alu_a_sel  = 1'b1;
        c_alu_b_sel  = 1'b1;
        c_wb_sel     = 1'b1;

        case (opcode)
            7'b0110011: begin // R-type
                e_alu_op     = {b30, funct3};
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_RS2;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_ALU;
                e_pc_sel     = PC_PC4;
            end
            7'b0010011: begin // I-type ALU
                e_alu_op     = {funct3 == 3'b101 ? b30 : 1'b0, funct3};
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = I;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_ALU;
                e_pc_sel     = PC_PC4;
            end
            7'b0000011: begin // loads
                e_alu_op     = ADD;
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = I;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_LOAD;
                e_data_re    = 1'b1;
                e_pc_sel     = PC_PC4;
            end
            7'b1100111: begin // JALR
                e_alu_op     = ADD;
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = I;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_PC4;
                e_pc_sel     = PC_JALR;
            end
            7'b0100011: begin // stores
                e_alu_op     = ADD;
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = S;  c_imm_op = 1'b1;
                e_regfile_we = 1'b0;
                c_wb_sel     = 1'b0;
                e_data_we    = 1'b1;
                e_pc_sel     = PC_PC4;
            end
            7'b1100011: begin // branches
                e_alu_op     = funct3[1] ? SLTU : SLT;
                e_alu_a_sel  = SEL_RS1;
                e_alu_b_sel  = SEL_RS2;
                e_imm_op     = B;  c_imm_op = 1'b1;
                e_regfile_we = 1'b0;
                c_wb_sel     = 1'b0;
                e_pc_sel     = PC_BRANCH;
            end
            7'b0110111: begin // LUI
                c_alu_op     = 1'b0;
                c_alu_a_sel  = 1'b0;
                c_alu_b_sel  = 1'b0;
                e_imm_op     = U;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_IMM;
                e_pc_sel     = PC_PC4;
            end
            7'b0010111: begin // AUIPC
                e_alu_op     = ADD;
                e_alu_a_sel  = SEL_PC;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = U;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_ALU;
                e_pc_sel     = PC_PC4;
            end
            7'b1101111: begin // JAL
                e_alu_op     = ADD;
                e_alu_a_sel  = SEL_PC;
                e_alu_b_sel  = SEL_IMM;
                e_imm_op     = J;  c_imm_op = 1'b1;
                e_regfile_we = 1'b1;
                e_wb_sel     = WB_PC4;
                e_pc_sel     = PC_JAL;
            end
            default: ; // unknown opcode: the defaults above
        endcase
    endtask

    task automatic fail(input logic [31:0] ins, input string what, input string port,
                        input logic [3:0] got, input logic [3:0] exp);
        $fatal(1, "decoder_tb: %s, instr %h (%s, funct3 %b, instr[30] %b): %s = %b, expected %b",
               what, ins, class_name(ins[6:0]), ins[14:12], ins[30], port, got, exp);
    endtask

    // Apply one instruction and compare every defined output.
    task automatic check(input logic [31:0] ins, input string what);
        instr = ins;
        #1;
        expect_for(ins[6:0], ins[14:12], ins[30]);
        if (data_we !== e_data_we)
            fail(ins, what, "data_we_o", 4'(data_we), 4'(e_data_we));
        if (data_re !== e_data_re)
            fail(ins, what, "data_re_o", 4'(data_re), 4'(e_data_re));
        if (regfile_we !== e_regfile_we)
            fail(ins, what, "regfile_we_o", 4'(regfile_we), 4'(e_regfile_we));
        if (pc_sel !== e_pc_sel)
            fail(ins, what, "pc_sel_o", 4'(pc_sel), 4'(e_pc_sel));
        if (c_imm_op && imm_op !== e_imm_op)
            fail(ins, what, "imm_op_o", 4'(imm_op), 4'(e_imm_op));
        if (c_alu_op && alu_op !== e_alu_op)
            fail(ins, what, "alu_op_o", alu_op, e_alu_op);
        if (c_alu_a_sel && alu_a_sel !== e_alu_a_sel)
            fail(ins, what, "alu_a_sel_o", 4'(alu_a_sel), 4'(e_alu_a_sel));
        if (c_alu_b_sel && alu_b_sel !== e_alu_b_sel)
            fail(ins, what, "alu_b_sel_o", 4'(alu_b_sel), 4'(e_alu_b_sel));
        if (c_wb_sel && wb_sel !== e_wb_sel)
            fail(ins, what, "wb_sel_o", 4'(wb_sel), 4'(e_wb_sel));
        if (data_we === 1'b1 && data_re === 1'b1)
            fail(ins, what, "{data_we_o, data_re_o}", {2'b0, data_we, data_re}, 4'b0000);
        checks++;
    endtask

    // Fill k of the ignored bits: all zeros, all ones, then random.
    function automatic logic [31:0] fill(input int k);
        case (k)
            0:       fill = 32'h0000_0000;
            1:       fill = 32'hFFFF_FFFF;
            default: fill = $urandom;
        endcase
    endfunction

    initial begin
        // ---- Named encodings ----
        check(32'h0031_00B3, "add x1, x2, x3");
        check(32'h4031_00B3, "sub x1, x2, x3");
        check(32'h0031_10B3, "sll x1, x2, x3");
        check(32'h0031_20B3, "slt x1, x2, x3");
        check(32'h0031_30B3, "sltu x1, x2, x3");
        check(32'h0031_40B3, "xor x1, x2, x3");
        check(32'h0031_50B3, "srl x1, x2, x3");
        check(32'h4031_50B3, "sra x1, x2, x3");
        check(32'h0031_60B3, "or x1, x2, x3");
        check(32'h0031_70B3, "and x1, x2, x3");
        check(32'hFFF1_0093, "addi x1, x2, -1 (instr[30] = 1, still ADD)");
        check(32'h4001_2093, "slti x1, x2, 1024 (instr[30] = 1, still SLT)");
        check(32'hC001_3093, "sltiu x1, x2, -1024");
        check(32'h7FF1_4093, "xori x1, x2, 2047");
        check(32'hC001_6093, "ori x1, x2, -1024");
        check(32'hFFF1_7093, "andi x1, x2, -1");
        check(32'h01F1_1093, "slli x1, x2, 31");
        check(32'h01F1_5093, "srli x1, x2, 31");
        check(32'h41F1_5093, "srai x1, x2, 31");
        check(32'hFFC1_0083, "lb x1, -4(x2)");
        check(32'h0041_1083, "lh x1, 4(x2)");
        check(32'h0001_2083, "lw x1, 0(x2)");
        check(32'h0001_4083, "lbu x1, 0(x2)");
        check(32'h0001_5083, "lhu x1, 0(x2)");
        check(32'h0031_0223, "sb x3, 4(x2)");
        check(32'hFE31_1E23, "sh x3, -4(x2)");
        check(32'h0031_2023, "sw x3, 0(x2)");
        check(32'h0031_0463, "beq x2, x3, 8");
        check(32'hFE31_1CE3, "bne x2, x3, -8");
        check(32'h0031_4463, "blt x2, x3, 8");
        check(32'h0031_5463, "bge x2, x3, 8");
        check(32'h0031_6463, "bltu x2, x3, 8");
        check(32'h0031_7463, "bgeu x2, x3, 8");
        check(32'h0001_00E7, "jalr x1, 0(x2)");
        check(32'hFFF1_00E7, "jalr x1, -1(x2)");
        check(32'h1234_50B7, "lui x1, 0x12345");
        check(32'hFFFF_F0B7, "lui x1, 0xfffff");
        check(32'h1234_5097, "auipc x1, 0x12345");
        check(32'h0080_00EF, "jal x1, 8");
        check(32'hFFDF_F0EF, "jal x1, -4");
        check(32'h0000_0013, "nop (addi x0, x0, 0)");
        check(32'h0FF0_000F, "fence (unknown opcode)");
        check(32'h0000_0073, "ecall (unknown opcode)");
        check(32'h0010_0073, "ebreak (unknown opcode)");
        check(32'h0000_0000, "all zeros (unknown opcode)");
        check(32'hFFFF_FFFF, "all ones (unknown opcode)");

        // ---- Every opcode, funct3 and instr[30], with several fills ----
        for (int op = 0; op < 128; op++)
            for (int f3 = 0; f3 < 8; f3++)
                for (int b30 = 0; b30 < 2; b30++)
                    for (int k = 0; k < NFILL; k++)
                        check((fill(k) & ~USED) | {1'b0, 1'(b30), 15'b0, 3'(f3), 5'b0, 7'(op)},
                              "sweep");

        $display("decoder_tb: PASS (%0d checks)", checks);
        $finish;
    end
endmodule
