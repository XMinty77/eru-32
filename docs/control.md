# Control

How the decoder forms each control signal from the instruction, one signal per section. Signal encodings are in `contracts.md`; the value each class needs is in `datapath.fods`.

## Instruction class

The decoder reads the class from the opcode, `instr[6:0]`. Every other section is indexed by class.

| opcode | class |
|---|---|
| `0110011` | R-type |
| `0010011` | I-type ALU |
| `0000011` | loads |
| `1100111` | JALR |
| `0100011` | stores |
| `1100011` | branches |
| `0110111` | LUI |
| `0010111` | AUIPC |
| `1101111` | JAL |
| `0001111` | FENCE |
| `1110011` | ECALL, EBREAK |

FENCE, ECALL and EBREAK are no-ops: they write nothing and go to `PC + 4`.

## ALU op

| instructions | `op` |
|---|---|
| R-type | `{instr[30], funct3}` |
| I-type ALU | `{funct3 == 3'b101 ? instr[30] : 1'b0, funct3}` |
| loads, stores, JALR, AUIPC, JAL | ADD |
| branches | `funct3[1] ? SLTU : SLT` |
| LUI, FENCE, ECALL, EBREAK | don't care |

In I-type, `instr[30]` is `imm[10]`, so it's used only to tell SRAI from SRLI. BEQ and BNE use only `eq_o`, which doesn't depend on `op`.

## ALU operand A select

| instructions | `alu_a_sel` |
|---|---|
| R-type, I-type ALU, loads, JALR, stores, branches | RS1 (`regfile.rdata_a_o`) |
| AUIPC, JAL | PC |
| LUI, FENCE, ECALL, EBREAK | don't care |

## ALU operand B select

| instructions | `alu_b_sel` |
|---|---|
| R-type, branches | RS2 (`regfile.rdata_b_o`) |
| I-type ALU, loads, JALR, stores, AUIPC, JAL | IMM (`immgen.imm_o`) |
| LUI, FENCE, ECALL, EBREAK | don't care |

## Immediate format

| instructions | `imm_op` |
|---|---|
| I-type ALU, loads, JALR | I |
| stores | S |
| branches | B |
| LUI, AUIPC | U |
| JAL | J |
| R-type, FENCE, ECALL, EBREAK | don't care |

## Register write enable

| instructions | `we` |
|---|---|
| R-type, I-type ALU, loads, JALR, LUI, AUIPC, JAL | 1 |
| stores, branches, FENCE, ECALL, EBREAK | 0 |

## Register write data select

| instructions | `wb_sel` |
|---|---|
| R-type, I-type ALU, AUIPC | ALU (`alu.result_o`) |
| loads | LOAD (the extended load data) |
| JALR, JAL | PC4 (`PC + 4`) |
| LUI | IMM (`immgen.imm_o`) |
| stores, branches, FENCE, ECALL, EBREAK | don't care |

## Data memory enables

| instructions | `data_we` | `data_re` |
|---|---|---|
| stores | 1 | 0 |
| loads | 0 | 1 |
| all others | 0 | 0 |

## Next PC select

| instructions | `pc_sel` |
|---|---|
| R-type, I-type ALU, loads, stores, LUI, AUIPC, FENCE, ECALL, EBREAK | PC4 (`PC + 4`) |
| branches | BRANCH (`PC + immgen.imm_o` if the branch condition holds, else `PC + 4`) |
| JALR | JALR (`{alu.result_o[31:1], 1'b0}`) |
| JAL | JAL (`alu.result_o`) |

## Selections by `funct3`

The load data extension, the store byte enables and the branch condition are not decoder outputs. `core.sv` reads `funct3` from `instr[14:12]` and forms them as in the table in `datapath.fods`, since each also needs a value only the datapath has (`data_rdata_i`, `alu.result_o[1:0]`, or the ALU flags).
