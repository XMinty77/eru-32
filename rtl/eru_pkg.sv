package eru_pkg;
    typedef enum logic [3:0] {
        ADD     = 4'b0000,
        SLL     = 4'b0001,
        SLT     = 4'b0010,
        SLTU    = 4'b0011,
        XOR     = 4'b0100,
        SRL     = 4'b0101,
        OR      = 4'b0110,
        AND     = 4'b0111,
        SUB     = 4'b1000,
        SRA     = 4'b1101
    } alu_op_e;

    typedef enum logic [2:0] {
        I, S, B, U, J
    } imm_op_e;

    typedef enum logic [6:0] {
        // I-type
        ALU_I   = 7'b0010011,
        LOAD    = 7'b0000011,
        JALR    = 7'b1100111,
        // TODO: FENCE, SYSTEM (ECALL+EBREAK)

        // S-type
        STORE   = 7'b0100011,

        // B-type
        BRANCH  = 7'b1100011,

        // U-type
        LUI     = 7'b0110111,
        AUIPC   = 7'b0010111,

        // J-type
        JAL     = 7'b1101111,

        // R-type
        ALU_R   = 7'b0110011
    } opcode_e;

    // funct3 of loads
    localparam logic [2:0] F3_LB  = 3'b000;
    localparam logic [2:0] F3_LH  = 3'b001;
    localparam logic [2:0] F3_LW  = 3'b010;
    localparam logic [2:0] F3_LBU = 3'b100;
    localparam logic [2:0] F3_LHU = 3'b101;

    typedef enum logic {
        SEL_RS1, SEL_PC
    } alu_a_sel_e;

    typedef enum logic {
        SEL_RS2, SEL_IMM
    } alu_b_sel_e;

    typedef enum logic [1:0] {
        WB_ALU, WB_LOAD, WB_PC4, WB_IMM
    } wb_sel_e;

    typedef enum logic [1:0] {
        PC_PC4, PC_BRANCH, PC_JALR, PC_JAL
    } pc_sel_e;
endpackage
