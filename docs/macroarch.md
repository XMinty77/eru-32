# Macroarchitecture

RV32I core, unprivileged, no Zicsr yet.

Single-cycle with load stalls so that memory can be synchronous (e.g. FPGA block RAM).

The core contains no memory. It has an instruction port and a data port, and each target's top module supplies the memory behind them and decides the address map, so the same core RTL serves every target. The data port is in `contracts.md`; the tops are in `tops.md`.

Reset is synchronous and active-high (`rst_i`). The PC resets to 0, the reset vector. The register file is not reset, so `x1`–`x31` are unspecified until written.
