# Erudite 32

An RV32I core I'm writing in SystemVerilog, to be taken from the ISA through a full open chip flow: simulation, FPGA (Tang Nano 20K...?) and sky130 through IIC-OSIC-TOOLS.

Scope of first version: unprivileged single-cycle RV32I (with load stalls), no Zicsr (so no traps).For testing: Unit benches, riscv-tests, riscv-arch-test and a trace compared against Spike.

## Versioning

- **Major:** new feature, behavior or microarchitecture generation.
- **Minor:** other microarchitecture changes.
- **Patch:** routine milestones (fixes, units, refactors, ...etc).

## Layout

```
docs/          spec
rtl/           RTL/SystemVerilog code
tb/unit/       unit benches (Icarus)
tb/core/       core harness (Verilator)
sw/            linker script, programs, test environments
third_party/   riscv-tests, riscv-arch-test
scripts/       utility scripts
build/         build outputs
```

## Building

The comment at the top of the `Makefile` lists every target. Needs Verilator 5, Icarus Verilog 12, yosys and a RISC-V GCC with the `rv32i/ilp32` multilib (`riscv64-unknown-elf-gcc`).
