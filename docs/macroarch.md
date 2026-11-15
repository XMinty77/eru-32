# Macroarchitecture

RV32I core, unprivileged, no Zicsr yet.

Single-cycle with load stalls so that memory can be synchronous (e.g. FPGA block RAM).

Reset is synchronous and active-high (`rst_i`). The register file is not reset, so `x1`–`x31` are unspecified until written.
