# Contracts

One section per unit: its ports, its behavior and its encodings. The RTL and the unit bench follow this document.

## ALU (`rtl/alu.sv`)

Arithmetic and logic operations, both for the instructions that name them and for branch comparisons.

| Port | Direction | Width | Description |
|---|---|---|---|
| `a_i` | Input | 32 | Operand A |
| `b_i` | Input | 32 | Operand B |
| `op_i` | Input | `alu_op_e` (4) | Operation |
| `result_o` | Output | 32 | Result |
| `eq_o` | Output | 1 | Flag `a_i == b_i` |
| `lt_o` | Output | 1 | Flag `a_i < b_i`, signed for SLT, unsigned for SLTU |

Operations, with `op_i = {funct7[5], funct3}` (`alu_op_e` in `rtl/eru_pkg.sv`):

| op | code | `result_o` |
|---|---|---|
| ADD | `0000` | `a + b` |
| SUB | `1000` | `a - b` |
| SLL | `0001` | `a << b[4:0]` |
| SLT | `0010` | 1 if `a < b` signed, else 0 |
| SLTU | `0011` | 1 if `a < b` unsigned, else 0 |
| XOR | `0100` | `a ^ b` |
| SRL | `0101` | `a >> b[4:0]`, zero fill |
| SRA | `1101` | `a >> b[4:0]`, sign fill |
| OR | `0110` | `a \| b` |
| AND | `0111` | `a & b` |

- Shifts use only `b[4:0]`.
- `eq_o` is valid for every op. `lt_o` is defined only when `op_i` is SLT or SLTU.
- Other codes are unused, and `result_o` is undefined for them.

## Register file (`rtl/regfile.sv`)

The 32 integer registers `x0`–`x31`: two asynchronous read ports and one synchronous write port.

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk_i` | Input | 1 | Clock |
| `raddr_a_i` | Input | 5 | Read port A address |
| `rdata_a_o` | Output | 32 | Read port A data |
| `raddr_b_i` | Input | 5 | Read port B address |
| `rdata_b_o` | Output | 32 | Read port B data |
| `we_i` | Input | 1 | Write enable |
| `waddr_i` | Input | 5 | Write address |
| `wdata_i` | Input | 32 | Write data |

- Storage holds `x1`–`x31` only; there is no entry for `x0`.
- Reads are combinational: `rdata_a_o` and `rdata_b_o` show the entry at `raddr_a_i` and `raddr_b_i`. A read of address 0 gives 0.
- At each rising edge of `clk_i` with `we_i` high, `wdata_i` is stored at `waddr_i`. A write to address 0 is discarded.
- A read of the address being written in the same cycle gives the old value until the edge and the new value after it. There is no bypass from `wdata_i`.
- No reset: entries are unspecified until written.
