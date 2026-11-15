# Control

How the decoder forms each control signal from the instruction, one signal per section. Signal encodings are in `contracts.md`.

## ALU op

| instructions | `op` |
|---|---|
| R-type | `{instr[30], funct3}` |
| I-type ALU | `{funct3 == 3'b101 ? instr[30] : 1'b0, funct3}` |
| loads, stores | ADD |
| branches | `funct3[1] ? SLTU : SLT` |

In I-type, `instr[30]` is `imm[10]`, so it's used only to tell SRAI from SRLI. BEQ and BNE use only `eq_o`, which doesn't depend on `op`.
