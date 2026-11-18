# Tops

One section per target's top module: what it holds around the core, its address map and its ports. The tops live in `rtl/tops/`, one file each. The core's own ports are in `contracts.md`, "Core".

## Simulation top

The top module for simulation, `sim_top` in `rtl/tops/sim_top.sv`: the core, the RAM and the memory-mapped devices below. It holds no simulation-only code; the testbench turns the device ports into output, PASS/FAIL and the end of the run.

### Address map

| Address | Size | What |
|---|---|---|
| `0x0000_0000` | 8 MB | RAM; the reset vector is its first word |
| `0x8000_0000` | 4 B | Exit: a store ends the run; the stored word is the exit code (0 = pass) |
| `0x8000_0004` | 4 B | Print: a store prints its low byte as a character |

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk_i` | Input | 1 | Clock |
| `rst_i` | Input | 1 | Synchronous, active-high reset, to the core |
| `exit_stb_o` | Output | 1 | A store to the exit address |
| `exit_code_o` | Output | 32 | The word stored to the exit address |
| `putc_stb_o` | Output | 1 | A store to the print address |
| `putc_data_o` | Output | 8 | The low byte stored to the print address |

- The RAM is 8 MB (a parameter), behind both of the core's ports, with the timing `Core` gives them.
- The RAM is loaded with `$readmemh` from the parameter `INIT_FILE`, default `build/program.hex`: one 32-bit word per entry, `@` addresses in words.
- For each store to the exit address, `exit_stb_o` is high at exactly one rising edge, with `exit_code_o` the stored word at that edge. Likewise `putc_stb_o` and `putc_data_o` for the print address.
- Stores to addresses outside the RAM and the devices do nothing. Loads from outside the RAM return undefined data.
