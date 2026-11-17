// Moves data between low bytes and memory byte lanes, and forms byte enables.
module word_align (
    input  logic [1:0]  offset_i,
    input  logic [1:0]  size_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] wdata_o,
    output logic [3:0]  be_o,
    input  logic [31:0] rdata_i,
    output logic [31:0] rdata_o
);
    logic [4:0] shift;
    logic [3:0] be_base;

    assign shift = {offset_i, 3'b000};

    always_comb case (size_i)
        2'b00:   be_base = 4'b0001;
        2'b01:   be_base = 4'b0011;
        2'b10:   be_base = 4'b1111;
        default: be_base = 'x;
    endcase

    assign wdata_o = wdata_i << shift;
    assign be_o    = be_base << offset_i;
    assign rdata_o = rdata_i >> shift;
endmodule
