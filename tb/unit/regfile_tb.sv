// Unit bench for the register file (docs/contracts.md, "Register file").
// Inputs change at the falling edge; the write happens at the rising edge.
// Plusargs: +seed=<n> for the random phase (default 1), +n=<count> its length.

module regfile_tb;
  logic        clk = 1'b0;
  logic [4:0]  raddr_a, raddr_b, waddr;
  logic [31:0] rdata_a, rdata_b, wdata;
  logic        we;

  regfile dut (
    .clk_i(clk),
    .raddr_a_i(raddr_a), .rdata_a_o(rdata_a),
    .raddr_b_i(raddr_b), .rdata_b_o(rdata_b),
    .we_i(we), .waddr_i(waddr), .wdata_i(wdata)
  );

  initial forever #5 clk = ~clk;

  // Model: what each register should hold, and whether it has been written.
  logic [31:0] model [32];
  logic        valid [32];

  integer seed = 1;
  integer n    = 2000;
  integer seed0;

  // Set both read addresses, let them settle, compare against the model.
  // Registers never written are skipped.
  task automatic check(input logic [4:0] a, input logic [4:0] b, input string what);
    raddr_a = a;
    raddr_b = b;
    #1;
    if (valid[a] && rdata_a !== model[a])
      $fatal(1, "%s: port A x%0d = %h, expected %h", what, a, rdata_a, model[a]);
    if (valid[b] && rdata_b !== model[b])
      $fatal(1, "%s: port B x%0d = %h, expected %h", what, b, rdata_b, model[b]);
  endtask

  // One cycle: drive the write inputs at the falling edge, write at the rising edge.
  task automatic cycle(input logic e, input logic [4:0] addr, input logic [31:0] data);
    @(negedge clk);
    we    = e;
    waddr = addr;
    wdata = data;
    @(posedge clk);
    if (e && addr != 5'd0) begin
      model[addr] = data;
      valid[addr] = 1'b1;
    end
  endtask

  // Write, then drop we_i at the next falling edge.
  task automatic write(input logic [4:0] addr, input logic [31:0] data);
    cycle(1'b1, addr, data);
    @(negedge clk);
    we = 1'b0;
  endtask

  // Write a value and read it back on both ports.
  task automatic write_check(input logic [4:0] addr, input logic [31:0] data, input string what);
    write(addr, data);
    check(addr, addr, what);
  endtask

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("n=%d", n));
    seed0 = seed;
    for (int i = 0; i < 32; i++) valid[i] = 1'b0;
    model[0] = 32'h0;
    valid[0] = 1'b1;
    we = 1'b0; waddr = 5'd0; wdata = 32'h0; raddr_a = 5'd0; raddr_b = 5'd0;

    // x0 reads 0, also after writes to it with we_i high.
    check(5'd0, 5'd0, "x0 before any write");
    write_check(5'd0, 32'hFFFF_FFFF, "x0 after write of ones");
    write_check(5'd0, 32'hDEAD_BEEF, "x0 after write of DEADBEEF");

    // Every register: all ones, all zeros, walking one, walking zero.
    for (int r = 1; r < 32; r++) begin
      write_check(5'(r), 32'hFFFF_FFFF, "all ones");
      write_check(5'(r), 32'h0000_0000, "all zeros");
      for (int k = 0; k < 32; k++) begin
        write_check(5'(r), 32'h1 << k, "walking one");
        write_check(5'(r), ~(32'h1 << k), "walking zero");
      end
    end

    // Distinct value per register; read all back, so no write landed elsewhere.
    for (int r = 1; r < 32; r++) write(5'(r), {8'(r), 8'(~r), 8'(r * 7), 8'(r ^ 8'hA5)});
    for (int r = 0; r < 32; r++) check(5'(r), 5'(31 - r), "distinct values");

    // Ports independent: every pair of addresses, same and different.
    for (int a = 0; a < 32; a++)
      for (int b = 0; b < 32; b++) check(5'(a), 5'(b), "address pairs");

    // Writes with we_i low change nothing, x0 included.
    for (int r = 0; r < 32; r++) begin
      cycle(1'b0, 5'(r), ~model[r]);
      @(negedge clk);
      for (int q = 0; q < 32; q++) check(5'(q), 5'(31 - q), "write with we_i low");
    end

    // Combinational read: the data follows the address with no clock edge.
    // Four reads (1 time unit each) fit in each low half of the clock.
    for (int r = 0; r < 32; r++) begin
      if (r % 4 == 0) @(negedge clk);
      check(5'(r), 5'(r ^ 1), "combinational read");
    end

    // Read during write: old value before the edge, new value after, no bypass.
    for (int r = 0; r < 32; r++) begin
      @(negedge clk);
      we = 1'b1; waddr = 5'(r); wdata = ~model[r] ^ 32'h0F0F_0000;
      check(5'(r), 5'(r), "read during write, before edge");
      @(posedge clk);
      if (r != 0) model[r] = wdata;
      #1;
      check(5'(r), 5'(r), "read during write, after edge");
      @(negedge clk);
      we = 1'b0;
    end

    // Random phase against the model. Reads are checked before each edge.
    for (int i = 0; i < n; i++) begin
      @(negedge clk);
      we    = 1'($random(seed));
      waddr = 5'($random(seed));
      wdata = 32'($random(seed));
      check(5'($random(seed)), 5'($random(seed)), "random");
      @(posedge clk);
      if (we && waddr != 5'd0) model[waddr] = wdata;
    end
    @(negedge clk);
    we = 1'b0;
    for (int r = 0; r < 32; r++) check(5'(r), 5'(r), "after random");

    $display("regfile_tb: PASS (seed %0d, %0d random cycles)", seed0, n);
    $finish;
  end
endmodule
