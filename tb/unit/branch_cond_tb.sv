// Unit bench for the branch condition (rtl/utils/branch_cond.sv), from the
// "Branch condition" section of docs/contracts.md.
//
// 1. Every branch funct3 with every combination of eq_i and lt_i, against the
//    contract's table (including flag combinations the ALU never produces).
// 2. Operand pairs (directed corner cases, then random): the bench forms eq_i
//    and lt_i the way the ALU contract defines them (lt_i signed for BLT/BGE,
//    unsigned for BLTU/BGEU, per control.md) and checks taken_o against the
//    RV32I branch semantics.
// 3. funct3 010 and 011 are driven but not checked: taken_o is undefined there.
//
// Plusargs: +seed=<n> (random seed), +n=<count> (random pairs per funct3).

module branch_cond_tb;

  logic [2:0] funct3;
  logic       eq;
  logic       lt;
  logic       taken;

  branch_cond dut (
    .funct3_i(funct3),
    .eq_i    (eq),
    .lt_i    (lt),
    .taken_o (taken)
  );

  int unsigned checks = 0;

  // The branch funct3 values, in contract order.
  localparam int NBR = 6;
  function automatic logic [2:0] branch(input int i);
    case (i)
      0:       return 3'b000;
      1:       return 3'b001;
      2:       return 3'b100;
      3:       return 3'b101;
      4:       return 3'b110;
      default: return 3'b111;
    endcase
  endfunction

  function automatic string name(input logic [2:0] f);
    case (f)
      3'b000:  return "BEQ";
      3'b001:  return "BNE";
      3'b100:  return "BLT";
      3'b101:  return "BGE";
      3'b110:  return "BLTU";
      3'b111:  return "BGEU";
      default: return "unused";
    endcase
  endfunction

  // The contract's table, from the flags.
  function automatic logic from_table(input logic [2:0] f, input logic e, input logic l);
    case (f)
      3'b000:  return e;
      3'b001:  return !e;
      3'b100:  return l;
      3'b101:  return !l;
      3'b110:  return l;
      3'b111:  return !l;
      default: return 1'bx;
    endcase
  endfunction

  // RV32I branch semantics, from the operands.
  function automatic logic arch(input logic [2:0] f, input logic [31:0] a, input logic [31:0] b);
    case (f)
      3'b000:  return a == b;
      3'b001:  return a != b;
      3'b100:  return $signed(a) <  $signed(b);
      3'b101:  return $signed(a) >= $signed(b);
      3'b110:  return a <  b;
      3'b111:  return a >= b;
      default: return 1'bx;
    endcase
  endfunction

  task automatic check_flags(input logic [2:0] f, input logic e, input logic l);
    logic exp;
    funct3 = f;
    eq     = e;
    lt     = l;
    #1;
    exp = from_table(f, e, l);
    checks++;
    if (taken !== exp)
      $fatal(1, "%s (funct3=%b) eq_i=%b lt_i=%b: taken_o=%b, expected %b",
             name(f), f, e, l, taken, exp);
  endtask

  // Flags as the ALU forms them for this branch: eq always, lt signed for
  // funct3[1] = 0 (SLT) and unsigned for funct3[1] = 1 (SLTU).
  task automatic check_operands(input logic [2:0] f, input logic [31:0] a, input logic [31:0] b);
    logic exp;
    funct3 = f;
    eq     = (a == b);
    lt     = f[1] ? (a < b) : ($signed(a) < $signed(b));
    #1;
    exp = arch(f, a, b);
    checks++;
    if (taken !== exp)
      $fatal(1, "%s (funct3=%b) a=%h b=%h (eq_i=%b lt_i=%b): taken_o=%b, expected %b",
             name(f), f, a, b, eq, lt, taken, exp);
  endtask

  // Directed operand values: zero, one, all-ones, and both sides of the sign
  // boundary.
  localparam int NV = 9;
  function automatic logic [31:0] val(input int i);
    case (i)
      0:       return 32'h0000_0000;
      1:       return 32'h0000_0001;
      2:       return 32'hFFFF_FFFF;
      3:       return 32'hFFFF_FFFE;
      4:       return 32'h7FFF_FFFF;
      5:       return 32'h7FFF_FFFE;
      6:       return 32'h8000_0000;
      7:       return 32'h8000_0001;
      default: return 32'h1234_5678;
    endcase
  endfunction

  int unsigned seed = 1;
  int unsigned state;  // $urandom(state) updates its argument, so seed stays as given
  int unsigned n    = 2000;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("n=%d", n));
    state = seed;
    void'($urandom(state));

    // 1. The table, exhaustively.
    for (int i = 0; i < NBR; i++)
      for (int fl = 0; fl < 4; fl++)
        check_flags(branch(i), fl[1], fl[0]);

    // 2a. Directed operand pairs: every pair of the values (equal pairs on the
    //     diagonal), for every branch.
    for (int i = 0; i < NBR; i++)
      for (int x = 0; x < NV; x++)
        for (int y = 0; y < NV; y++)
          check_operands(branch(i), val(x), val(y));

    // 2b. Random pairs: a quarter equal, a quarter differing in one bit, the
    //     rest independent, so equal and near-equal pairs come up often.
    for (int i = 0; i < NBR; i++)
      for (int k = 0; k < int'(n); k++) begin
        logic [31:0] a, b;
        a = $urandom;
        case ($urandom % 4)
          0:       b = a;
          1:       b = a ^ (32'h1 << ($urandom % 32));
          default: b = $urandom;
        endcase
        check_operands(branch(i), a, b);
      end

    // 3. funct3 010 and 011: taken_o is undefined, so nothing is checked. They
    //    are driven to make sure the unit settles back afterward.
    for (int f = 2; f <= 3; f++)
      for (int fl = 0; fl < 4; fl++) begin
        funct3 = 3'(f);
        eq     = fl[1];
        lt     = fl[0];
        #1;
      end
    for (int i = 0; i < NBR; i++)
      for (int fl = 0; fl < 4; fl++)
        check_flags(branch(i), fl[1], fl[0]);

    $display("branch_cond_tb: PASS (%0d checks, seed %0d)", checks, seed);
    $finish;
  end

endmodule
