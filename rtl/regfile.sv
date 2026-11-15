module regfile (
    input  logic        clk_i,
    input  logic [4:0]  raddr_a_i,
    input  logic [4:0]  raddr_b_i,
    input  logic        we_i,
    input  logic [31:0] wdata_i,
    input  logic [4:0]  waddr_i,
    output logic [31:0] rdata_a_o,
    output logic [31:0] rdata_b_o
);
    logic [31:0] regs [31];

    assign rdata_a_o = (raddr_a_i == 0) ? 0 : regs[raddr_a_i - 1];
    assign rdata_b_o = (raddr_b_i == 0) ? 0 : regs[raddr_b_i - 1];
    
    always_ff @(posedge clk_i) begin
        if (we_i && waddr_i != 0) regs[waddr_i - 1] <= wdata_i;
    end
endmodule
