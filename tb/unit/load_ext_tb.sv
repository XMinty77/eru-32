// Unit bench for the load extender (rtl/utils/load_ext.sv), written from docs/contracts.md.
// Checks every defined funct3 (LB, LH, LW, LBU, LHU): all 256 low-byte values, all 65536
// low half-word values (for LH and LHU) and random words, with the remaining bits random.
// The reference model shifts the field to the top of the word and shifts it back down,
// arithmetically for the signed loads. Plusarg: +seed=N (default 1).

module load_ext_tb;

  logic [2:0]  funct3;
  logic [31:0] data;
  logic [31:0] data_out;

  load_ext dut (
    .funct3_i (funct3),
    .data_i   (data),
    .data_o   (data_out)
  );

  int unsigned checks = 0;
  int          seed   = 1;
  int          rng;      // copy of seed: $urandom(rng) may overwrite its argument

  localparam logic [2:0] F_LB  = 3'b000;
  localparam logic [2:0] F_LH  = 3'b001;
  localparam logic [2:0] F_LW  = 3'b010;
  localparam logic [2:0] F_LBU = 3'b100;
  localparam logic [2:0] F_LHU = 3'b101;

  // Reference: move the loaded field to bits [31:...], then shift it back to bit 0.
  function automatic logic [31:0] ref_model(input logic [2:0] f3, input logic [31:0] d);
    logic [31:0] byte_top;
    logic [31:0] half_top;
    byte_top = d << 24;
    half_top = d << 16;
    case (f3)
      F_LB:    ref_model = 32'($signed(byte_top) >>> 24);
      F_LH:    ref_model = 32'($signed(half_top) >>> 16);
      F_LW:    ref_model = d;
      F_LBU:   ref_model = byte_top >> 24;
      F_LHU:   ref_model = half_top >> 16;
      default: ref_model = 'x;
    endcase
  endfunction

  function automatic string name_of(input logic [2:0] f3);
    case (f3)
      F_LB:    name_of = "LB";
      F_LH:    name_of = "LH";
      F_LW:    name_of = "LW";
      F_LBU:   name_of = "LBU";
      F_LHU:   name_of = "LHU";
      default: name_of = "?";
    endcase
  endfunction

  task automatic check(input logic [2:0] f3, input logic [31:0] d);
    logic [31:0] exp;
    funct3 = f3;
    data   = d;
    #1;
    exp = ref_model(f3, d);
    checks++;
    if (data_out !== exp)
      $fatal(1, "load_ext_tb: FAIL %s (funct3=%b) data_i=%h: got %h, expected %h (seed %0d)",
             name_of(f3), f3, d, data_out, exp, seed);
  endtask

  // The defined funct3 codes, indexed 0 to 4.
  function automatic logic [2:0] f3_at(input int k);
    case (k)
      0:       f3_at = F_LB;
      1:       f3_at = F_LH;
      2:       f3_at = F_LW;
      3:       f3_at = F_LBU;
      default: f3_at = F_LHU;
    endcase
  endfunction

  initial begin
    void'($value$plusargs("seed=%d", seed));
    rng = seed;
    void'($urandom(rng));

    // Every low byte, other bits random, for every defined funct3.
    for (int k = 0; k < 5; k++)
      for (int b = 0; b < 256; b++)
        check(f3_at(k), {$urandom()} & 32'hFFFF_FF00 | 32'(b));

    // Every low half word, upper bits random, for LH and LHU.
    for (int h = 0; h < 65536; h++) begin
      check(F_LH,  {$urandom()} & 32'hFFFF_0000 | 32'(h));
      check(F_LHU, {$urandom()} & 32'hFFFF_0000 | 32'(h));
    end

    // Fixed corner words.
    for (int k = 0; k < 5; k++) begin
      check(f3_at(k), 32'h0000_0000);
      check(f3_at(k), 32'hFFFF_FFFF);
      check(f3_at(k), 32'h0000_0080);
      check(f3_at(k), 32'hFFFF_FF7F);
      check(f3_at(k), 32'h0000_8000);
      check(f3_at(k), 32'hFFFF_7FFF);
      check(f3_at(k), 32'h8000_0000);
      check(f3_at(k), 32'h7FFF_FFFF);
    end

    // Random words.
    for (int k = 0; k < 5; k++)
      for (int i = 0; i < 20000; i++)
        check(f3_at(k), $urandom());

    $display("load_ext_tb: PASS, %0d checks (seed %0d)", checks, seed);
    $finish;
  end

endmodule
