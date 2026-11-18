// Core bench: runs a program on the simulation top (docs/tops.md, "Simulation top"),
// which loads its RAM from its default INIT_FILE, build/program.hex.
// Prints each character stored to the print device and ends the run at the first
// store to the exit device: PASS for exit code 0, else FAIL (exit code <n>).
// The bench's last line always starts with PASS or FAIL, on a line of its own.
// Plusargs:
//   +name=<name>      program name, for the default VCD path (default "core")
//   +max_cycles=<n>   timeout in cycles after reset release (default 1000000)
//   +vcd              dump build/core/<name>.vcd; +vcd=<path> dumps to <path>

module core_tb;
  logic        clk = 1'b0;
  logic        rst = 1'b1;
  logic        exit_stb, putc_stb;
  logic [31:0] exit_code;
  logic [7:0]  putc_data;

  sim_top dut (
    .clk_i(clk), .rst_i(rst),
    .exit_stb_o(exit_stb), .exit_code_o(exit_code),
    .putc_stb_o(putc_stb), .putc_data_o(putc_data)
  );

  initial forever #5 clk = ~clk;

  integer max_cycles = 1000000;
  integer n_cycles   = 0;
  string  name       = "core";
  string  vcd_path;
  bit     line_start = 1'b1;  // the output so far ends with a newline (or is empty)

  // Print the result on a line of its own and end the run.
  task automatic end_run(input string result);
    if (!line_start) $write("\n");
    $display("%s", result);
    $fflush;
    $finish;
  endtask

  initial begin
    void'($value$plusargs("max_cycles=%d", max_cycles));
    void'($value$plusargs("name=%s", name));
    if ($test$plusargs("vcd")) begin
      if (!$value$plusargs("vcd=%s", vcd_path)) vcd_path = {"build/core/", name, ".vcd"};
      $dumpfile(vcd_path);
      $dumpvars(0, core_tb);
    end

    // Reset: held for 4 rising edges, released at a falling edge.
    repeat (4) @(posedge clk);
    @(negedge clk) rst = 1'b0;

    // Sample the device ports at each rising edge.
    forever begin
      @(posedge clk);
      if (putc_stb) begin
        $write("%c", putc_data);
        $fflush;
        line_start = (putc_data == 8'h0a);
      end
      n_cycles = n_cycles + 1;
      if (exit_stb) begin
        if (exit_code == 32'd0) end_run("PASS");
        else end_run($sformatf("FAIL (exit code %0d)", $signed(exit_code)));
      end else if (n_cycles >= max_cycles) begin
        end_run("FAIL (timeout)");
      end
    end
  end
endmodule
