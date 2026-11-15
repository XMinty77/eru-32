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
endpackage
