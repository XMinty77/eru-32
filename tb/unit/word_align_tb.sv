// Unit bench for the word aligner (rtl/utils/word_align.sv), from the
// "Word aligner" section of docs/contracts.md.
//
// Every offset and size, each with directed data patterns and random data on
// both directions at once. be_o is not checked for size 11 (undefined there);
// wdata_o and rdata_o are checked for every size, since neither depends on it.
// Random inputs on the other direction check that the two directions are
// independent. Outputs must be fully known (no X or Z).
//
// Plusargs: +n=<random vectors per offset and size> (default 2000).

module word_align_tb;

  logic [1:0]  offset_i;
  logic [1:0]  size_i;
  logic [31:0] wdata_i;
  logic [31:0] wdata_o;
  logic [3:0]  be_o;
  logic [31:0] rdata_i;
  logic [31:0] rdata_o;

  word_align dut (
    .offset_i (offset_i),
    .size_i   (size_i),
    .wdata_i  (wdata_i),
    .wdata_o  (wdata_o),
    .be_o     (be_o),
    .rdata_i  (rdata_i),
    .rdata_o  (rdata_o)
  );

  int unsigned checks = 0;
  int unsigned n_rand = 2000;

  // Expected values, written from the contract.
  function automatic logic [31:0] exp_wdata(logic [1:0] off, logic [31:0] d);
    case (off)
      2'd0:    return d;
      2'd1:    return {d[23:0], 8'h00};
      2'd2:    return {d[15:0], 16'h0000};
      default: return {d[7:0], 24'h000000};
    endcase
  endfunction

  function automatic logic [31:0] exp_rdata(logic [1:0] off, logic [31:0] d);
    case (off)
      2'd0:    return d;
      2'd1:    return {8'h00, d[31:8]};
      2'd2:    return {16'h0000, d[31:16]};
      default: return {24'h000000, d[31:24]};
    endcase
  endfunction

  function automatic logic [3:0] exp_be(logic [1:0] off, logic [1:0] sz);
    logic [3:0] base;
    case (sz)
      2'b00:   base = 4'b0001;
      2'b01:   base = 4'b0011;
      default: base = 4'b1111;  // 10; 11 is never checked
    endcase
    return base << off;
  endfunction

  task automatic apply(logic [1:0] off, logic [1:0] sz, logic [31:0] wd, logic [31:0] rd);
    logic [31:0] ew, er;
    logic [3:0]  eb;
    offset_i = off;
    size_i   = sz;
    wdata_i  = wd;
    rdata_i  = rd;
    #1;
    ew = exp_wdata(off, wd);
    er = exp_rdata(off, rd);
    eb = exp_be(off, sz);
    if (wdata_o !== ew)
      $fatal(1, "wdata_o: offset=%0d size=%b wdata_i=%h rdata_i=%h: got %h, expected %h",
             off, sz, wd, rd, wdata_o, ew);
    if (rdata_o !== er)
      $fatal(1, "rdata_o: offset=%0d size=%b wdata_i=%h rdata_i=%h: got %h, expected %h",
             off, sz, wd, rd, rdata_o, er);
    if (sz != 2'b11 && be_o !== eb)
      $fatal(1, "be_o: offset=%0d size=%b wdata_i=%h rdata_i=%h: got %b, expected %b",
             off, sz, wd, rd, be_o, eb);
    checks++;
  endtask

  // Directed data patterns: zero, all ones, distinct bytes, alternating bits.
  localparam int N_PAT = 6;
  function automatic logic [31:0] pat(int i);
    case (i)
      0:       return 32'h0000_0000;
      1:       return 32'hFFFF_FFFF;
      2:       return 32'h4433_2211;
      3:       return 32'h8899_AABB;
      4:       return 32'hAAAA_AAAA;
      default: return 32'h5555_5555;
    endcase
  endfunction

  initial begin
    if ($value$plusargs("n=%d", n_rand)) ;

    // Byte enables, every offset and defined size, with the table spelled out.
    for (int off = 0; off < 4; off++) begin
      apply(off[1:0], 2'b00, 32'h0, 32'h0);
      if (be_o !== (4'b0001 << off)) $fatal(1, "be_o byte offset %0d: %b", off, be_o);
    end
    apply(2'd0, 2'b01, 32'h0, 32'h0); if (be_o !== 4'b0011) $fatal(1, "be_o half 0: %b", be_o);
    apply(2'd1, 2'b01, 32'h0, 32'h0); if (be_o !== 4'b0110) $fatal(1, "be_o half 1: %b", be_o);
    apply(2'd2, 2'b01, 32'h0, 32'h0); if (be_o !== 4'b1100) $fatal(1, "be_o half 2: %b", be_o);
    apply(2'd3, 2'b01, 32'h0, 32'h0); if (be_o !== 4'b1000) $fatal(1, "be_o half 3 (crosses): %b", be_o);
    apply(2'd0, 2'b10, 32'h0, 32'h0); if (be_o !== 4'b1111) $fatal(1, "be_o word 0: %b", be_o);
    apply(2'd1, 2'b10, 32'h0, 32'h0); if (be_o !== 4'b1110) $fatal(1, "be_o word 1 (crosses): %b", be_o);
    apply(2'd2, 2'b10, 32'h0, 32'h0); if (be_o !== 4'b1100) $fatal(1, "be_o word 2 (crosses): %b", be_o);
    apply(2'd3, 2'b10, 32'h0, 32'h0); if (be_o !== 4'b1000) $fatal(1, "be_o word 3 (crosses): %b", be_o);

    // Directed data in both directions, each pattern paired with every other.
    for (int off = 0; off < 4; off++)
      for (int sz = 0; sz < 4; sz++)
        for (int i = 0; i < N_PAT; i++)
          for (int j = 0; j < N_PAT; j++)
            apply(off[1:0], sz[1:0], pat(i), pat(j));

    // Walking one and walking zero, in both directions.
    for (int off = 0; off < 4; off++)
      for (int sz = 0; sz < 4; sz++)
        for (int b = 0; b < 32; b++) begin
          apply(off[1:0], sz[1:0], 32'h1 << b, ~(32'h1 << b));
          apply(off[1:0], sz[1:0], ~(32'h1 << b), 32'h1 << b);
        end

    // Random data, both directions at once.
    for (int off = 0; off < 4; off++)
      for (int sz = 0; sz < 4; sz++)
        for (int unsigned k = 0; k < n_rand; k++)
          apply(off[1:0], sz[1:0], $urandom, $urandom);

    $display("word_align_tb: PASS (%0d vectors)", checks);
    $finish;
  end

endmodule
