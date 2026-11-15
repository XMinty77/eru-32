# Datapath

The units and the wiring between them. The port tables are in `contracts.md`; this document refers to ports by name. The top module is `rtl/core.sv`: it instantiates the units, the PC register, the adders and the muxes, and holds no logic of its own.

- **ALU operands:** `a` is rs1 or the PC; `b` is rs2 or the immediate. The decoder drives both selects.
- **PC + 4:** a dedicated adder. Its output is the default next PC and the link value for JAL and JALR.
- **PC + imm:** a dedicated adder. Its output is the target for branches and JAL.
- **Branch condition:** the ALU compares rs1 and rs2 and gives `eq_o` and `lt_o`.
