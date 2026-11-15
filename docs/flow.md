# Flow

One section per instruction class: the path it takes through the datapath and the control signals it sets. Written as each class is brought up.

## Branches

The ALU compares rs1 and rs2: BEQ and BNE use `eq_o`, the others use `lt_o` with `op` set to SLT or SLTU. The PC + imm adder supplies the target; the next PC is that or PC + 4.

## JAL

The PC + imm adder supplies the target. PC + 4 is written to rd.

## JALR

PC + 4 is written to rd.
