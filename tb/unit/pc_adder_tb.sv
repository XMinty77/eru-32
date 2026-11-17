// Unit bench for the PC adders (docs/contracts.md, "PC adders").
// Combinational: pc_plus4_o = pc_i + 4, pc_plus_imm_o = pc_i + imm_i, both mod 2^32.

module pc_adder_tb;

  logic [31:0] pc;
  logic [31:0] imm;
  logic [31:0] pc_plus4;
  logic [31:0] pc_plus_imm;

  int unsigned n_checks;

  pc_adder dut (
      .pc_i         (pc),
      .imm_i        (imm),
      .pc_plus4_o   (pc_plus4),
      .pc_plus_imm_o(pc_plus_imm)
  );

  // Drive both inputs, let the outputs settle, compare with the expected sums.
  task automatic check(input logic [31:0] pc_v, input logic [31:0] imm_v);
    logic [31:0] exp_plus4;
    logic [31:0] exp_plus_imm;
    begin
      pc  = pc_v;
      imm = imm_v;
      #1;
      exp_plus4    = pc_v + 32'd4;
      exp_plus_imm = pc_v + imm_v;
      if (pc_plus4 !== exp_plus4)
        $fatal(1, "pc_plus4_o: pc_i=%08h imm_i=%08h got %08h expected %08h",
               pc_v, imm_v, pc_plus4, exp_plus4);
      if (pc_plus_imm !== exp_plus_imm)
        $fatal(1, "pc_plus_imm_o: pc_i=%08h imm_i=%08h got %08h expected %08h",
               pc_v, imm_v, pc_plus_imm, exp_plus_imm);
      n_checks = n_checks + 1;
    end
  endtask

  // Interesting values for both inputs.
  logic [31:0] corners[15];

  initial begin
    n_checks = 0;

    corners[0]  = 32'h0000_0000;
    corners[1]  = 32'h0000_0004;
    corners[2]  = 32'h0000_0001;
    corners[3]  = 32'h0000_0ffc;
    corners[4]  = 32'h0000_ffff;
    corners[5]  = 32'h7fff_fffc;
    corners[6]  = 32'h7fff_ffff;
    corners[7]  = 32'h8000_0000;
    corners[8]  = 32'h8000_0004;
    corners[9]  = 32'hffff_f000;  // -4096, most negative B-type offset
    corners[10] = 32'hffff_fffc;  // -4
    corners[11] = 32'hffff_fffe;  // -2
    corners[12] = 32'hffff_ffff;  // -1
    corners[13] = 32'hfff0_0000;  // -2^20, most negative J-type offset
    corners[14] = 32'haaaa_aaaa;

    // ---- Directed: PC + 4 ----
    check(32'h0000_0000, 32'h0);  // reset vector
    check(32'h0000_0004, 32'h0);
    check(32'h0000_fffc, 32'h0);  // carry out of the low half
    check(32'h7fff_fffc, 32'h0);  // crosses into the sign bit, no special case
    check(32'hffff_fff8, 32'h0);  // -> fffffffc
    check(32'hffff_fffc, 32'h0);  // wraps to 0
    check(32'hffff_fffe, 32'h0);  // wraps to 2
    check(32'hffff_ffff, 32'h0);  // wraps to 3
    check(32'h0000_0001, 32'h0);  // unaligned PC still just adds 4

    // ---- Directed: PC + imm, positive and negative offsets ----
    check(32'h0000_1000, 32'h0000_0008);
    check(32'h0000_1000, 32'hffff_fff8);  // -8
    check(32'h0000_1000, 32'hffff_f000);  // -4096 -> 0
    check(32'h0000_0000, 32'hffff_fffc);  // 0 - 4 wraps to fffffffc
    check(32'h0000_0004, 32'hffff_fff8);  // 4 - 8 wraps
    check(32'h0000_0000, 32'h0000_0ffe);  // max B-type offset
    check(32'h0000_0000, 32'h000f_fffe);  // max J-type offset
    check(32'h0010_0000, 32'hfff0_0000);  // min J-type offset -> 0
    check(32'hffff_fff0, 32'h0000_0010);  // positive offset wraps past top to 0
    check(32'hffff_fffc, 32'h0000_0ffc);  // wraps
    check(32'h8000_0000, 32'hffff_ffff);  // -> 7fffffff
    check(32'h7fff_ffff, 32'h0000_0001);  // -> 80000000
    check(32'hffff_ffff, 32'hffff_ffff);  // -> fffffffe
    check(32'h8000_0000, 32'h8000_0000);  // -> 0
    check(32'h1234_5678, 32'h0000_0000);  // zero offset gives the PC
    check(32'h5555_5555, 32'haaaa_aaaa);  // -> ffffffff, no carries
    check(32'h5555_5556, 32'haaaa_aaaa);  // -> 0, carry through every bit

    // ---- Directed: every pair of corner values ----
    foreach (corners[i])
      foreach (corners[j]) check(corners[i], corners[j]);

    // ---- Walking ones: carry chain into each bit ----
    for (int b = 0; b < 32; b++) begin
      check(32'h1 << b, 32'h1 << b);
      check((32'h1 << b) - 32'h1, 32'h1);
      check(32'hffff_ffff, 32'h1 << b);
    end

    // ---- Random ----
    // Fully random operands.
    repeat (20000) check($urandom, $urandom);
    // Word-aligned PCs with sign-extended B-type (13-bit) and J-type (21-bit) offsets.
    repeat (5000) begin
      logic [31:0] p;
      logic [19:0] r;
      p = {$urandom} & 32'hffff_fffc;
      r = 20'($urandom);
      check(p, {{20{r[11]}}, r[11:0]} << 1);  // 13-bit B-type offset
      check(p, {{12{r[19]}}, r[19:0]} << 1);  // 21-bit J-type offset
    end
    // PCs near the top and bottom of the address space.
    repeat (2000) begin
      logic [19:0] r;
      r = 20'($urandom);
      check(32'hffff_ff00 | {24'h0, r[7:0]}, {{20{r[19]}}, r[19:8]});
      check({24'h0, r[7:0]}, {{20{r[19]}}, r[19:8]});
    end

    $display("pc_adder_tb: PASS (%0d checks)", n_checks);
    $finish;
  end

endmodule
