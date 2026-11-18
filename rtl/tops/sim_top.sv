module sim_top #(
    parameter int    RAM_BYTES = 8 * 1024 * 1024,
    parameter string INIT_FILE = "build/program.hex"
) (
    input  logic        clk_i,
    input  logic        rst_i,
    output logic        exit_stb_o,
    output logic [31:0] exit_code_o,
    output logic        putc_stb_o,
    output logic [7:0]  putc_data_o
);
    localparam int          RAM_WORDS       = RAM_BYTES / 4;
    localparam int          RAM_ADDR_BITS   = $clog2(RAM_BYTES);
    localparam logic [31:0] EXIT_ADDR       = 32'h8000_0000;
    localparam logic [31:0] PUTC_ADDR       = 32'h8000_0004;

    logic [31:0] mem [RAM_WORDS];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    function automatic logic in_ram(input logic [31:0] addr);
        return addr < RAM_BYTES;
    endfunction

    function automatic logic [31:0] read_ram(input logic [31:0] addr);
        return in_ram(addr) ? mem[addr[RAM_ADDR_BITS-1:2]] : 32'h0;
    endfunction

    logic [31:0] instr_addr, data_addr, wdata;
    logic [3:0]  be;
    logic        re, we;

    logic [31:0] instr_q, data_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) { exit_stb_o, putc_stb_o } <= '0;

        instr_q <= read_ram(instr_addr);
        if (re) data_q <= read_ram(data_addr);

        if (we) begin
            if (data_addr == EXIT_ADDR) begin
                exit_stb_o <= '1;
                exit_code_o <= wdata;
            end else exit_stb_o <= '0;

            if (data_addr == PUTC_ADDR) begin
                putc_stb_o <= '1;
                putc_data_o <= wdata[7:0];
            end else putc_stb_o <= '0;

            if (in_ram(data_addr)) begin
                for (int i = 0; i < 4; i++)
                    if (be[i]) mem[data_addr[RAM_ADDR_BITS-1:2]][i*8 +: 8] <= wdata[i*8 +: 8];
            end
        end else { exit_stb_o, putc_stb_o } <= '0;
    end

    core u_core (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .instr_addr_o   (instr_addr),
        .instr_rdata_i  (instr_q),

        .data_addr_o    (data_addr),
        .data_rdata_i   (data_q),
        .data_wdata_o   (wdata),

        .data_re_o      (re),
        .data_we_o      (we),
        .data_be_o      (be)
    );
endmodule
