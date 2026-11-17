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

## Immediate generator (`rtl/immgen.sv`)

Forms the sign-extended immediate of the instruction, in the format the decoder selects.

| Port | Direction | Width | Description |
|---|---|---|---|
| `op_i` | Input | `imm_op_e` (3) | Immediate format |
| `instr_imm_i` | Input | 25 (`[31:7]`) | Instruction bits 31 to 7 |
| `imm_o` | Output | 32 | Immediate |

Formats (`imm_op_e` in `rtl/eru_pkg.sv`); `instr[k]` is `instr_imm_i[k]`, and "sign" is `instr[31]`:

| op | code | `imm_o` |
|---|---|---|
| I | `000` | `[31:11]` sign, `[10:0]` = `instr[30:20]` |
| S | `001` | `[31:11]` sign, `[10:5]` = `instr[30:25]`, `[4:0]` = `instr[11:7]` |
| B | `010` | `[31:12]` sign, `[11]` = `instr[7]`, `[10:5]` = `instr[30:25]`, `[4:1]` = `instr[11:8]`, `[0]` = 0 |
| U | `011` | `[31:12]` = `instr[31:12]`, `[11:0]` = 0 |
| J | `100` | `[31:20]` sign, `[19:12]` = `instr[19:12]`, `[11]` = `instr[20]`, `[10:1]` = `instr[30:21]`, `[0]` = 0 |

- Combinational. The opcode, `instr[6:0]`, is not an input: the decoder reads it. Connect the port as `instr[31:7]`; ports connect by position, so a 32-bit signal would be truncated.
- Other codes are unused, and `imm_o` is undefined for them.

## Word aligner (`rtl/utils/word_align.sv`)

Moves data between the low bytes of a value and its byte lanes in a 32-bit memory word, and forms the byte enables of the access.

| Port | Direction | Width | Description |
|---|---|---|---|
| `offset_i` | Input | 2 | Byte offset of the access in the word (`addr[1:0]`) |
| `size_i` | Input | 2 | Access size: `00` byte, `01` half word, `10` word |
| `wdata_i` | Input | 32 | Data to write, in its low bytes |
| `wdata_o` | Output | 32 | `wdata_i` moved up to its lanes: `wdata_i << (8 * offset_i)` |
| `be_o` | Output | 4 | Byte enables: `0001`, `0011` or `1111` for the size, shifted left by `offset_i` |
| `rdata_i` | Input | 32 | Word as read from memory |
| `rdata_o` | Output | 32 | `rdata_i` moved down from its lanes: `rdata_i >> (8 * offset_i)`, zero fill |

- Combinational. The two directions are independent: `wdata_o` and `be_o` don't depend on `rdata_i`, and `rdata_o` doesn't depend on `size_i` or `wdata_i`.
- `size_i` matches `funct3[1:0]` of loads and stores. `size_i = 11` is unused, and `be_o` is undefined for it.
- Bits and enables shifted past byte 3 are dropped, so an access that crosses the word gives only its bytes inside the word.

## PC adders (`rtl/utils/pc_adder.sv`)

The two dedicated adders on the PC.

| Port | Direction | Width | Description |
|---|---|---|---|
| `pc_i` | Input | 32 | PC |
| `imm_i` | Input | 32 | Immediate |
| `pc_plus4_o` | Output | 32 | `pc_i + 4` |
| `pc_plus_imm_o` | Output | 32 | `pc_i + imm_i` |

- Combinational. Both sums wrap modulo 2^32.

## Branch condition (`rtl/utils/branch_cond.sv`)

Whether a branch is taken, from its `funct3` and the ALU flags.

| Port | Direction | Width | Description |
|---|---|---|---|
| `funct3_i` | Input | 3 | The branch's `funct3` |
| `eq_i` | Input | 1 | `alu.eq_o` |
| `lt_i` | Input | 1 | `alu.lt_o` (the decoder picks SLT or SLTU) |
| `taken_o` | Output | 1 | 1 if the branch is taken |

| `funct3` | instruction | `taken_o` |
|---|---|---|
| `000` | BEQ | `eq_i` |
| `001` | BNE | `!eq_i` |
| `100` | BLT | `lt_i` |
| `101` | BGE | `!lt_i` |
| `110` | BLTU | `lt_i` |
| `111` | BGEU | `!lt_i` |

- Combinational. `funct3` `010` and `011` are unused, and `taken_o` is undefined for them.

## Load extender (`rtl/utils/load_ext.sv`)

Extends the loaded byte, half word or word to 32 bits, from the load's `funct3`.

| Port | Direction | Width | Description |
|---|---|---|---|
| `funct3_i` | Input | 3 | The load's `funct3` |
| `data_i` | Input | 32 | Loaded data in its low bytes (`word_align.rdata_o`) |
| `data_o` | Output | 32 | `data_i` extended |

| `funct3` | instruction | `data_o` |
|---|---|---|
| `000` | LB | `data_i[7:0]`, sign-extended |
| `001` | LH | `data_i[15:0]`, sign-extended |
| `010` | LW | `data_i` |
| `100` | LBU | `data_i[7:0]`, zero-extended |
| `101` | LHU | `data_i[15:0]`, zero-extended |

- Combinational. `funct3` `011`, `110` and `111` are unused, and `data_o` is undefined for them.

## Decoder (`rtl/decoder.sv`)

Forms the core's control signals from the instruction.

| Port | Direction | Width | Description |
|---|---|---|---|
| `instr_i` | Input | 32 | The instruction |
| `imm_op_o` | Output | `imm_op_e` (3) | Immediate format, to `immgen.op_i` |
| `data_we_o` | Output | 1 | Data memory write enable |
| `data_re_o` | Output | 1 | Data memory read enable |
| `regfile_we_o` | Output | 1 | Register write enable, to `regfile.we_i` |
| `alu_op_o` | Output | `alu_op_e` (4) | ALU operation, to `alu.op_i` |
| `alu_a_sel_o` | Output | `alu_a_sel_e` (1) | ALU operand A select |
| `alu_b_sel_o` | Output | `alu_b_sel_e` (1) | ALU operand B select |
| `wb_sel_o` | Output | `wb_sel_e` (2) | Register write data select |
| `pc_sel_o` | Output | `pc_sel_e` (2) | Next PC select |

Opcodes it recognizes, from `instr_i[6:0]` (`opcode_e` in `rtl/eru_pkg.sv`):

| opcode | code | class |
|---|---|---|
| ALU_R | `0110011` | R-type |
| ALU_I | `0010011` | I-type ALU |
| LOAD | `0000011` | loads |
| JALR | `1100111` | JALR |
| STORE | `0100011` | stores |
| BRANCH | `1100011` | branches |
| LUI | `0110111` | LUI |
| AUIPC | `0010111` | AUIPC |
| JAL | `1101111` | JAL |
| FENCE | `0001111` | FENCE |
| SYSTEM | `1110011` | ECALL, EBREAK |

Selects (in `rtl/eru_pkg.sv`). `imm_op_e` is tabled in the immediate generator section, `alu_op_e` in the ALU section.

`alu_a_sel_e`:

| select | code | operand A |
|---|---|---|
| SEL_RS1 | `0` | `regfile.rdata_a_o` |
| SEL_PC | `1` | PC |

`alu_b_sel_e`:

| select | code | operand B |
|---|---|---|
| SEL_RS2 | `0` | `regfile.rdata_b_o` |
| SEL_IMM | `1` | `immgen.imm_o` |

`wb_sel_e`:

| select | code | register write data |
|---|---|---|
| WB_ALU | `00` | `alu.result_o` |
| WB_LOAD | `01` | The extended load data |
| WB_PC4 | `10` | `PC + 4` |
| WB_IMM | `11` | `immgen.imm_o` |

`pc_sel_e`:

| select | code | next PC |
|---|---|---|
| PC_PC4 | `00` | `PC + 4` |
| PC_BRANCH | `01` | `PC + immgen.imm_o` if the branch condition holds, else `PC + 4` |
| PC_JALR | `10` | `{alu.result_o[31:1], 1'b0}` |
| PC_JAL | `11` | `alu.result_o` |

- Combinational.
- For each recognized opcode, every output takes the value `control.md` gives its class. Where `control.md` says "don't care", that output is undefined.
- The outputs depend only on `instr_i[6:0]`, `funct3` (`instr_i[14:12]`) and `instr_i[30]`. `alu_op_o` is formed as `control.md` gives it even when the result is a code the ALU doesn't use.
- For any other opcode: `data_we_o`, `data_re_o` and `regfile_we_o` are 0, `alu_op_o` is ADD, `alu_a_sel_o` is SEL_RS1, `alu_b_sel_o` is SEL_IMM, `wb_sel_o` is WB_ALU and `pc_sel_o` is PC_PC4. `imm_op_o` is undefined.
- `data_we_o` and `data_re_o` are never 1 together.

## Core (`rtl/core.sv`)

The core's ports to the outside. Each target's top module supplies the memory behind them.

### Instruction port

| Port | Direction | Width | Description |
|---|---|---|---|
| `instr_addr_o` | Output | 32 | Byte address of the next instruction: the next-PC value the PC register loads at the coming edge |
| `instr_rdata_i` | Input | 32 | The instruction at the PC |

- The memory is 32 bits wide and uses `instr_addr_o[31:2]` as the word address.
- Reads are synchronous and happen at every rising edge: the word at `instr_addr_o` appears on `instr_rdata_i` after that edge, the same edge at which the PC register loads that address.
- While `rst_i` is high, `instr_addr_o` is 0, the reset vector, so the word at 0 is on `instr_rdata_i` when reset drops.

### Data port

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_addr_o` | Output | 32 | Byte address |
| `data_re_o` | Output | 1 | Read enable, high for loads |
| `data_we_o` | Output | 1 | Write enable, high for stores |
| `data_be_o` | Output | 4 | Byte enables for stores |
| `data_wdata_o` | Output | 32 | Write data |
| `data_rdata_i` | Input | 32 | Read data |

- The memory is 32 bits wide and uses `data_addr_o[31:2]` as the word address.
- `data_re_o` and `data_we_o` are never high together. With both low, the memory is not accessed.
- `data_we_o` is low while `rst_i` is high.
- A load takes two cycles: `data_re_o` is high in the first only, and the loaded word is written to the register file in the second.
- Reads are synchronous: with `data_re_o` high at a rising edge, the word at `data_addr_o` appears on `data_rdata_i` after that edge. `data_rdata_i` is defined only in the cycle after such an edge. Loads read the whole word; `data_be_o` is ignored.
- Writes are synchronous: at a rising edge with `data_we_o` high, for each `i` with `data_be_o[i]` high, `data_wdata_o[8i+7:8i]` is written to byte `i` of the word (byte address `{data_addr_o[31:2], 2'(i)}`).
