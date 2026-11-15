// ALU unit bench: every op on a grid of corner values, then random vectors,
// all checked against a reference model.
// Ops are driven by their raw 4-bit codes ({funct7[5], funct3}), so the bench
// also checks the encoding in alu_op_e.
// Plusargs: +seed=<n> (default 1), +n=<random vectors per op> (default 2000).

module alu_tb;
  import eru_pkg::*;

  logic [31:0] a, b;
  logic [3:0]  op;
  alu_op_e     op_e;
  logic [31:0] result;
  logic        eq, lt;

  int unsigned errors = 0;
  int unsigned checks = 0;

  assign op_e = alu_op_e'(op);

  alu dut (
    .a_i      (a),
    .b_i      (b),
    .op_i     (op_e),
    .result_o (result),
    .eq_o     (eq),
    .lt_o     (lt)
  );

  localparam int NumOps = 10;

  function automatic logic [3:0] op_code(int i);
    case (i)
      0:       return 4'b0000;  // ADD
      1:       return 4'b1000;  // SUB
      2:       return 4'b0001;  // SLL
      3:       return 4'b0010;  // SLT
      4:       return 4'b0011;  // SLTU
      5:       return 4'b0100;  // XOR
      6:       return 4'b0101;  // SRL
      7:       return 4'b1101;  // SRA
      8:       return 4'b0110;  // OR
      default: return 4'b0111;  // AND
    endcase
  endfunction

  function automatic string op_name(logic [3:0] o);
    case (o)
      4'b0000: return "ADD";
      4'b1000: return "SUB";
      4'b0001: return "SLL";
      4'b0010: return "SLT";
      4'b0011: return "SLTU";
      4'b0100: return "XOR";
      4'b0101: return "SRL";
      4'b1101: return "SRA";
      4'b0110: return "OR";
      4'b0111: return "AND";
      default: return "???";
    endcase
  endfunction

  // Reference model. Shifts use only b[4:0], as RV32I specifies.
  function automatic logic [31:0] model(logic [3:0] o, logic [31:0] x, logic [31:0] y);
    case (o)
      4'b0000: return x + y;
      4'b1000: return x - y;
      4'b0001: return x << y[4:0];
      4'b0010: return {31'b0, $signed(x) < $signed(y)};
      4'b0011: return {31'b0, x < y};
      4'b0100: return x ^ y;
      4'b0101: return x >> y[4:0];
      4'b1101: return $signed(x) >>> y[4:0];
      4'b0110: return x | y;
      4'b0111: return x & y;
      default: return 'x;
    endcase
  endfunction

  // Drive one vector and check it. lt_o is checked only for SLT and SLTU,
  // where it must match the result's bit 0; eq_o is checked for every op.
  task automatic check(logic [3:0] o, logic [31:0] x, logic [31:0] y);
    logic [31:0] expected;
    op = o;
    a  = x;
    b  = y;
    #1;
    expected = model(o, x, y);
    checks++;
    if (result !== expected) begin
      errors++;
      if (errors <= 10)
        $display("FAIL %-4s a=%h b=%h: result_o=%h, expected %h",
                 op_name(o), x, y, result, expected);
    end
    if (eq !== (x == y)) begin
      errors++;
      if (errors <= 10)
        $display("FAIL %-4s a=%h b=%h: eq_o=%b, expected %b",
                 op_name(o), x, y, eq, x == y);
    end
    if ((o == 4'b0010 || o == 4'b0011) && lt !== expected[0]) begin
      errors++;
      if (errors <= 10)
        $display("FAIL %-4s a=%h b=%h: lt_o=%b, expected %b",
                 op_name(o), x, y, lt, expected[0]);
    end
  endtask

  localparam int NumCorners = 10;

  function automatic logic [31:0] corner(int i);
    case (i)
      0:       return 32'h0000_0000;
      1:       return 32'h0000_0001;
      2:       return 32'h0000_0002;
      3:       return 32'h0000_001f;  // largest shift amount
      4:       return 32'h0000_0020;  // shift amount 0 once b[4:0] is taken
      5:       return 32'h7fff_ffff;
      6:       return 32'h8000_0000;
      7:       return 32'h8000_0001;
      8:       return 32'hffff_ffff;
      default: return 32'hdead_beef;
    endcase
  endfunction

  int unsigned seed = 1;
  int unsigned n    = 2000;
  int unsigned state;  // $urandom(state) updates its argument, so seed stays as given
  logic [31:0] x, y;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("n=%d", n));
    state = seed;
    x = $urandom(state);

    for (int o = 0; o < NumOps; o++)
      for (int i = 0; i < NumCorners; i++)
        for (int j = 0; j < NumCorners; j++)
          check(op_code(o), corner(i), corner(j));

    for (int o = 0; o < NumOps; o++)
      for (int k = 0; k < n; k++) begin
        x = $urandom;
        y = $urandom;
        if (k % 8 == 0) y = x;                       // exercise eq_o = 1
        else if (k % 8 == 1) y = x ^ 32'h8000_0000;  // differ only in the sign bit
        check(op_code(o), x, y);
      end

    if (errors != 0)
      $fatal(1, "alu_tb: %0d of %0d checks failed (seed %0d)", errors, checks, seed);
    $display("alu_tb: PASS, %0d checks (seed %0d)", checks, seed);
    $finish;
  end
endmodule
