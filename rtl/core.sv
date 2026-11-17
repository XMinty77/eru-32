module core (
    input  logic        clk_i,
    input  logic        rst_i,

    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,

    output logic [31:0] data_addr_o,
    input  logic [31:0] data_rdata_i,
    output logic [31:0] data_wdata_o,
    output logic        data_re_o,
    output logic        data_we_o,
    output logic [3:0]  data_be_o
);
    import eru_pkg::*;

    // == Define ==

    // PC
    logic [31:0] pc_q, pc_next;

    // Instruction
    logic [31:0] instr;

    // Convenience signals
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    logic [31:7] instr_imm;

    always_comb begin
        opcode = instr[6:0];
        rd = instr[11:7];
        funct3 = instr[14:12];
        rs1 = instr[19:15];
        rs2 = instr[24:20];
        funct7 = instr[31:25];
        instr_imm = instr[31:7];
    end

    // == Load stall ==

    // Load stalls constitute two cycles
    //    first cycle: stall_q = 0, stall = 1, memory reads the data while pc, register write and fetch hold
    //   second cycle: stall_q = 1, stall = 0, the holds are unlocked, and loaded word is written
    logic is_a_load, stall_q, stall;
    assign is_a_load = opcode == LOAD;
    assign stall = !stall_q && is_a_load;

    always_ff @(posedge clk_i) begin
        if (rst_i)  stall_q <= '0;
        else        stall_q <= stall;
    end


    // == Instantiate ==

    // PC adder
    logic [31:0] pc_adder_pc, pc_adder_imm, pc_adder_pc_plus4, pc_adder_pc_plus_imm;
    pc_adder pc_adder (
        .pc_i           (pc_adder_pc),
        .imm_i          (pc_adder_imm),
        .pc_plus4_o     (pc_adder_pc_plus4),
        .pc_plus_imm_o  (pc_adder_pc_plus_imm)
    );

    // Register file
    logic [31:0] regfile_wdata, regfile_rdata_a, regfile_rdata_b;
    logic [4:0] regfile_raddr_a, regfile_raddr_b, regfile_waddr;
    logic regfile_we;

    regfile regfile (
        .clk_i      (clk_i),
        .raddr_a_i  (regfile_raddr_a),
        .raddr_b_i  (regfile_raddr_b),
        .we_i       (regfile_we),
        .wdata_i    (regfile_wdata),
        .waddr_i    (regfile_waddr),
        .rdata_a_o  (regfile_rdata_a),
        .rdata_b_o  (regfile_rdata_b)
    );

    // ALU
    logic [31:0] alu_a, alu_b, alu_result;
    logic alu_eq, alu_lt;
    alu_op_e alu_op;

    alu alu (
        .a_i        (alu_a),
        .b_i        (alu_b),
        .op_i       (alu_op),
        .result_o   (alu_result),
        .eq_o       (alu_eq),
        .lt_o       (alu_lt)
    );

    // Decoder
    logic [31:0] decoder_instr;
    logic decoder_data_we, decoder_data_re, decoder_regfile_we;
    imm_op_e decoder_imm_op;
    alu_op_e decoder_alu_op;
    alu_a_sel_e decoder_alu_a_sel;
    alu_b_sel_e decoder_alu_b_sel;
    wb_sel_e decoder_wb_sel;
    pc_sel_e decoder_pc_sel;

    decoder decoder (
        .instr_i        (decoder_instr),
        .imm_op_o       (decoder_imm_op),
        .data_we_o      (decoder_data_we),
        .data_re_o      (decoder_data_re),
        .regfile_we_o   (decoder_regfile_we),
        .alu_op_o       (decoder_alu_op),
        .alu_a_sel_o    (decoder_alu_a_sel),
        .alu_b_sel_o    (decoder_alu_b_sel),
        .wb_sel_o       (decoder_wb_sel),
        .pc_sel_o       (decoder_pc_sel)
    );

    // Immediate generator
    logic [31:7] immgen_instr_imm;
    imm_op_e immgen_op;
    logic [31:0] immgen_imm;
    immgen immgen (
        .op_i           (immgen_op),
        .instr_imm_i    (immgen_instr_imm),
        .imm_o          (immgen_imm)
    );

    // Branch condition
    logic [2:0] branch_cond_funct3;
    logic branch_cond_eq, branch_cond_lt, branch_cond_taken;
    branch_cond branch_cond (
        .funct3_i   (branch_cond_funct3),
        .eq_i       (branch_cond_eq),
        .lt_i       (branch_cond_lt),
        .taken_o    (branch_cond_taken)
    );

    // Word aligner
    logic [1:0] word_align_offset, word_align_size;
    logic [3:0] word_align_be;
    logic [31:0] word_align_wdata_i, word_align_wdata_o, word_align_rdata_i, word_align_rdata_o;

    word_align word_align (
        .offset_i   (word_align_offset),
        .size_i     (word_align_size),
        .wdata_i    (word_align_wdata_i),
        .wdata_o    (word_align_wdata_o),
        .be_o       (word_align_be),
        .rdata_i    (word_align_rdata_i),
        .rdata_o    (word_align_rdata_o)
    );

    // Load extender
    logic [2:0] load_ext_funct3;
    logic [31:0] load_ext_data_i, load_ext_data_o;

    load_ext load_ext (
        .funct3_i   (load_ext_funct3),
        .data_i     (load_ext_data_i),
        .data_o     (load_ext_data_o)
    );

    // == Fetch ==

    // Advance PC
    always_ff @(posedge clk_i) begin
        if (rst_i)                      pc_q <= '0;
        else if (!stall)                pc_q <= pc_next;
    end

    // Calculate next PC
    always_comb begin
        pc_adder_pc = pc_q;
        pc_adder_imm = immgen_imm;
        branch_cond_funct3 = funct3;
        branch_cond_eq = alu_eq;
        branch_cond_lt = alu_lt;
        case (decoder_pc_sel)
            PC_PC4:     pc_next = pc_adder_pc_plus4;
            PC_BRANCH:  pc_next = branch_cond_taken ? pc_adder_pc_plus_imm : pc_adder_pc_plus4;
            PC_JALR:    pc_next = {alu_result[31:1], 1'b0};
            PC_JAL:     pc_next = alu_result;
            default:    pc_next = 'x;
        endcase
    end

    // Fetch instruction
    always_comb begin
        instr_addr_o = rst_i ? 0 : (stall ? pc_q : pc_next);
        instr = instr_rdata_i;
    end

    // == Decode ==

    // Decode instruction
    always_comb begin
        decoder_instr = instr;
    end

    // Generate immediate
    always_comb begin
        immgen_instr_imm = instr_imm;
        immgen_op = decoder_imm_op;
    end

    // Wire up register file addresses
    always_comb begin
        regfile_raddr_a = rs1;
        regfile_raddr_b = rs2;
        regfile_waddr   = rd;
    end

    // == Execute ==

    // Drive ALU
    always_comb begin
        alu_op = decoder_alu_op;

        case (decoder_alu_a_sel)
            SEL_RS1:    alu_a = regfile_rdata_a;
            SEL_PC:     alu_a = pc_q;
            default:    alu_a = 'x;
        endcase

        case (decoder_alu_b_sel)
            SEL_RS2:    alu_b = regfile_rdata_b;
            SEL_IMM:    alu_b = immgen_imm;
            default:    alu_b = 'x;
        endcase
    end

    // Drive data aligner
    always_comb begin
        word_align_offset  = alu_result[1:0];
        word_align_size    = funct3[1:0];
    end

    // Drive data port
    always_comb begin
        // Enables
        data_we_o       = decoder_data_we && !rst_i;
        // Read in the first cycle of a load only (!stall_q: not the second cycle)
        data_re_o       = decoder_data_re && !stall_q;
        data_be_o       = word_align_be;

        // Address always calculated by ALU
        data_addr_o     = alu_result;

        // STORE
        word_align_wdata_i = regfile_rdata_b;
        data_wdata_o    = word_align_wdata_o;
    end

    // Drive regfile port
    always_comb begin
        // LOAD
        word_align_rdata_i = data_rdata_i;
        load_ext_funct3 = funct3;
        load_ext_data_i = word_align_rdata_o;

        // Write enable and data
        regfile_we = decoder_regfile_we && !stall;
        case (decoder_wb_sel)
            WB_ALU:     regfile_wdata = alu_result;
            WB_LOAD:    regfile_wdata = load_ext_data_o;
            WB_PC4:     regfile_wdata = pc_adder_pc_plus4;
            WB_IMM:     regfile_wdata = immgen_imm;
            default:    regfile_wdata = 'x;
        endcase
    end
endmodule
