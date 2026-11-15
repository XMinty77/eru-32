// Unit bench for the immediate generator (docs/contracts.md, "Immediate generator").
// Every format on directed patterns and known encodings, then random instructions,
// all checked against a reference model. Codes other than the five formats are
// not checked: imm_o is undefined for them.
// Formats are driven by their raw 3-bit codes, so the bench also checks the
// encoding in imm_op_e.
// Plusargs: +seed=<n> (default 1), +n=<random instructions per format> (default 2000).

module immgen_tb;
  import eru_pkg::*;

  logic [2:0]  op;
  imm_op_e     op_e;
  // Whole instructions, so encodings read as written; only [31:7] reach the DUT.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] instr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] imm;

  int unsigned errors = 0;
  int unsigned checks = 0;

  assign op_e = imm_op_e'(op);

  immgen dut (
    .op_i        (op_e),
    .instr_imm_i (instr[31:7]),
    .imm_o       (imm)
  );

  localparam int NumFormats = 5;

  function automatic string fmt_name(logic [2:0] o);
    case (o)
      3'b000:  return "I";
      3'b001:  return "S";
      3'b010:  return "B";
      3'b011:  return "U";
      3'b100:  return "J";
      default: return "?";
    endcase
  endfunction

  // Reference model: gather the immediate's fields into its natural width,
  // then sign-extend that value to 32 bits. instr[6:0] is not an input, so the
  // model doesn't take it.
  function automatic logic [31:0] model(logic [2:0] o, logic [31:7] w);
    logic signed [11:0] i12;
    logic signed [12:0] b13;
    logic signed [20:0] j21;
    logic signed [31:0] r;
    case (o)
      3'b000: begin
        i12 = $signed(w[31:20]);
        r   = 32'(i12);
      end
      3'b001: begin
        i12 = $signed({w[31:25], w[11:7]});
        r   = 32'(i12);
      end
      3'b010: begin
        b13 = $signed({w[31], w[7], w[30:25], w[11:8], 1'b0});
        r   = 32'(b13);
      end
      3'b011: r = $signed({w[31:12], 12'b0});
      3'b100: begin
        j21 = $signed({w[31], w[19:12], w[20], w[30:21], 1'b0});
        r   = 32'(j21);
      end
      default: r = 'x;
    endcase
    return r;
  endfunction

  // Drive one instruction and compare against an expected value.
  task automatic check_exp(logic [2:0] o, logic [31:0] w, logic [31:0] expected,
                           string what);
    op    = o;
    instr = w;
    #1;
    checks++;
    if (imm !== expected) begin
      errors++;
      if (errors <= 10)
        $display("FAIL %s %s instr=%h: imm_o=%h, expected %h",
                 fmt_name(o), what, w, imm, expected);
    end
  endtask

  // Drive one instruction and compare against the model.
  task automatic check(logic [2:0] o, logic [31:0] w, string what);
    check_exp(o, w, model(o, w[31:7]), what);
  endtask

  integer seed = 1;
  integer n    = 2000;
  integer seed0;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("n=%d", n));
    seed0 = seed;

    for (int f = 0; f < NumFormats; f++) begin
      // Sign bit 0 and 1, all zeros, all ones, alternating bits.
      check(3'(f), 32'h0000_0000, "all zeros");
      check(3'(f), 32'hFFFF_FFFF, "all ones");
      check(3'(f), 32'h7FFF_FFFF, "sign 0, rest ones");
      check(3'(f), 32'h8000_0000, "sign 1, rest zeros");
      check(3'(f), 32'h5555_5555, "alternating 01");
      check(3'(f), 32'hAAAA_AAAA, "alternating 10");
      // Walking one and walking zero across the bits an immediate can use.
      for (int k = 7; k < 32; k++) begin
        check(3'(f), 32'h1 << k, "walking one");
        check(3'(f), ~(32'h1 << k), "walking zero");
      end
    end

    // Known encodings, with the immediate written out by hand.
    check_exp(3'b000, 32'hFFF0_0093, 32'hFFFF_FFFF, "addi x1,x0,-1");
    check_exp(3'b000, 32'h7FF0_0093, 32'h0000_07FF, "addi x1,x0,2047");
    check_exp(3'b000, 32'h8000_0093, 32'hFFFF_F800, "addi x1,x0,-2048");
    check_exp(3'b000, 32'h0040_A103, 32'h0000_0004, "lw x2,4(x1)");
    check_exp(3'b000, 32'hFF81_00E7, 32'hFFFF_FFF8, "jalr x1,-8(x2)");
    check_exp(3'b001, 32'hFE20_AE23, 32'hFFFF_FFFC, "sw x2,-4(x1)");
    check_exp(3'b001, 32'h7E20_AFA3, 32'h0000_07FF, "sw x2,2047(x1)");
    check_exp(3'b001, 32'h8020_A023, 32'hFFFF_F800, "sw x2,-2048(x1)");
    check_exp(3'b010, 32'h8000_0063, 32'hFFFF_F000, "beq x0,x0,-4096");
    check_exp(3'b010, 32'h7E00_0FE3, 32'h0000_0FFE, "beq x0,x0,+4094");
    check_exp(3'b010, 32'hFE20_8EE3, 32'hFFFF_FFFC, "beq x1,x2,-4");
    check_exp(3'b010, 32'h0020_8463, 32'h0000_0008, "beq x1,x2,+8");
    check_exp(3'b011, 32'hFFFF_F0B7, 32'hFFFF_F000, "lui x1,0xFFFFF");
    check_exp(3'b011, 32'h1234_50B7, 32'h1234_5000, "lui x1,0x12345");
    check_exp(3'b011, 32'h8000_0097, 32'h8000_0000, "auipc x1,0x80000");
    check_exp(3'b100, 32'h8000_006F, 32'hFFF0_0000, "jal x0,-1048576");
    check_exp(3'b100, 32'h7FFF_F06F, 32'h000F_FFFE, "jal x0,+1048574");
    check_exp(3'b100, 32'hFFDF_F0EF, 32'hFFFF_FFFC, "jal x1,-4");
    check_exp(3'b100, 32'h0010_00EF, 32'h0000_0800, "jal x1,+2048");

    // Random instructions, every format.
    for (int f = 0; f < NumFormats; f++)
      for (int k = 0; k < n; k++)
        check(3'(f), 32'($random(seed)), "random");

    if (errors != 0)
      $fatal(1, "immgen_tb: %0d of %0d checks failed (seed %0d)", errors, checks, seed0);
    $display("immgen_tb: PASS, %0d checks (seed %0d, %0d random per format)",
             checks, seed0, n);
    $finish;
  end
endmodule
