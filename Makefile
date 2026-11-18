# ================ eru-32 Makefile ================
# make                 run every unit bench (same as make unit)
# make alu             compile and run one unit bench, tb/unit/alu_tb.sv, with Icarus
# make alu ARGS=+foo   pass plusargs to the bench
# make lint            Verilator lint of the RTL, top module $(TOP), with waivers.vlt
# make lint-alu        Verilator lint of one unit bench with the RTL
# make synth-check     yosys generic synthesis of the RTL (slang frontend, in the
#                      IIC-OSIC-TOOLS image), to catch SV it can't read
# make run-hello       build sw/hello/ and run it on the simulation top (sim_top in
#                      rtl/tops/sim_top.sv, under tb/core/core_tb.sv), with Verilator:
#                      copies its hex to build/program.hex, which sim_top loads, and
#                      runs the built simulator (no rebuild per program); fails
#                      unless the PASS/FAIL line says PASS
# make run-hello SIM=icarus   the same on Icarus: about 50x slower, but 4-state,
#                      so it shows x from unwritten registers or memory
# make run-hello ARGS=+vcd    also dump build/core/hello.vcd (+vcd=<path> for another
#                      path); +max_cycles=<n> sets the timeout (default 1000000)
# make programs        run every program in sw/; safe with -j: builds run in parallel,
#                      runs one at a time (they share build/program.hex, under flock)
# make clean           delete build/
# A bench that fails ($fatal) makes make stop with an error.
# Unit benches are named after what they test; don't name one after a target above.
# Programs are sw/<name>/*.c and *.S, built with sw/common/ into build/sw/<name>/:
# <name>.elf, <name>.hex (for $readmemh: 32-bit words, @ addresses in words) and <name>.dis.
# =================================================

# Packages, in dependency order: each one is compiled before anything that imports it.
PKGS    := rtl/eru_pkg.sv
# Packages used only by benches.
TB_PKGS :=
# All other RTL files: modules, including the small helpers in rtl/utils/.
# The per-target tops in rtl/tops/ are left out; each build that needs one adds it.
RTL     := $(filter-out $(PKGS),$(wildcard rtl/*.sv rtl/utils/*.sv))
# The core's top module, for lint and synth-check.
TOP     := core
# The simulation top, for the core bench only (not in RTL, lint or synth-check).
SIM_TOP := rtl/tops/sim_top.sv

# Unit benches are tb/unit/<unit>_tb.sv; each <unit> becomes a target.
UNITS   := $(patsubst tb/unit/%_tb.sv,%,$(wildcard tb/unit/*_tb.sv))

# Programs: every directory in sw/ except common/.
PROGS   := $(filter-out common,$(patsubst sw/%/,%,$(wildcard sw/*/)))

BUILD     := build
IVERILOG  := iverilog -g2012 -Wall
VVP       := vvp -n
VERILATOR := verilator -Wall --timing
# synth-check needs yosys with the slang plugin (local yosys can't read packages);
# the IIC-OSIC-TOOLS image has it. Override with YOSYS=yosys if yours has slang.
CHIPTOOLS := hpretl/iic-osic-tools:latest
YOSYS     := docker run --rm --user $(shell id -u):$(shell id -g) -v $(CURDIR):/w -w /w \
             --entrypoint /foss/tools/bin/yosys $(CHIPTOOLS)
ARGS      :=
# Simulator for programs on the core: verilator (default) or icarus.
SIM       := verilator
# Lint warnings accepted on purpose.
WAIVERS   := waivers.vlt
# RISC-V toolchain for the programs. RV32I has no multiply or divide; -lgcc supplies them.
RV_PREFIX := riscv64-unknown-elf-
RV_CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -O2 -Wall -Isw/common \
             -T sw/common/link.ld -Wl,--no-warn-rwx-segments
SW_COMMON := sw/common/crt0.S sw/common/link.ld sw/common/eru.h

.PHONY: all unit lint synth-check programs clean $(UNITS) $(addprefix lint-,$(UNITS)) \
        $(addprefix run-,$(PROGS))

all: unit

unit: $(UNITS)

# ---------------- unit benches (Icarus, 4-state) ----------------

# Compile a bench: packages first, then the RTL, then the bench. -s names the top module.
$(BUILD)/unit/%_tb.vvp: tb/unit/%_tb.sv $(PKGS) $(TB_PKGS) $(RTL) | $(BUILD)/unit
	$(IVERILOG) -s $*_tb -o $@ $(PKGS) $(TB_PKGS) $(RTL) $<

# Run a bench. vvp exits with status 1 when the bench calls $fatal(1, ...).
$(UNITS): %: $(BUILD)/unit/%_tb.vvp
	$(VVP) $< $(ARGS)

# ---------------- lint (Verilator) ----------------

lint:
	@test -n "$(RTL)" || { echo "No RTL in rtl/ yet"; exit 1; }
	$(VERILATOR) --lint-only --top-module $(TOP) $(WAIVERS) $(PKGS) $(RTL)

$(addprefix lint-,$(UNITS)): lint-%:
	$(VERILATOR) --lint-only --top-module $*_tb $(WAIVERS) $(PKGS) $(TB_PKGS) $(RTL) tb/unit/$*_tb.sv

# ---------------- synthesis check (yosys) ----------------

synth-check: | $(BUILD)
	@test -n "$(RTL)" || { echo "No RTL in rtl/ yet"; exit 1; }
	$(YOSYS) -m slang -q -l $(BUILD)/synth-check.log \
	  -p 'read_slang $(PKGS) $(RTL) --top $(TOP); synth -top $(TOP); stat'
	@echo "synth-check: OK (log in $(BUILD)/synth-check.log)"

# ---------------- programs on the core ----------------

programs: $(addprefix run-,$(PROGS))

# The core harness, built for each simulator. CORE_SIM is the command that runs it.
$(BUILD)/core/core_tb.vvp: tb/core/core_tb.sv $(PKGS) $(TB_PKGS) $(RTL) $(SIM_TOP) | $(BUILD)/core
	$(IVERILOG) -s core_tb -o $@ $(PKGS) $(TB_PKGS) $(RTL) $(SIM_TOP) $<

$(BUILD)/core/vl/Vcore_tb: tb/core/core_tb.sv $(PKGS) $(TB_PKGS) $(RTL) $(SIM_TOP) $(WAIVERS) | $(BUILD)/core
	$(VERILATOR) --binary --trace -j 0 --top-module core_tb -Mdir $(BUILD)/core/vl \
	  $(WAIVERS) $(PKGS) $(TB_PKGS) $(RTL) $(SIM_TOP) $<

ifeq ($(SIM),icarus)
CORE_BIN := $(BUILD)/core/core_tb.vvp
CORE_SIM := $(VVP) $(CORE_BIN)
else ifeq ($(SIM),verilator)
CORE_BIN := $(BUILD)/core/vl/Vcore_tb
CORE_SIM := $(CORE_BIN)
else
$(error SIM must be verilator or icarus, not $(SIM))
endif

# Build one program: crt0.S first, so _start is at 0. Then the hex image and a disassembly.
define PROG_RULES
$(BUILD)/sw/$(1)/$(1).elf: $(wildcard sw/$(1)/*.c sw/$(1)/*.S) $(SW_COMMON)
	@mkdir -p $$(@D)
	$(RV_PREFIX)gcc $(RV_CFLAGS) -o $$@ sw/common/crt0.S $(wildcard sw/$(1)/*.c sw/$(1)/*.S) -lgcc

$(BUILD)/sw/$(1)/$(1).hex: $(BUILD)/sw/$(1)/$(1).elf
	$(RV_PREFIX)objcopy -O verilog --verilog-data-width=4 $$< $$@
	$(RV_PREFIX)objdump -d $$< > $(BUILD)/sw/$(1)/$(1).dis

# Run it: copy its hex to build/program.hex (sim_top's INIT_FILE) and run the bench;
# the output is also kept in build/core/<name>.log. Every run shares program.hex, so
# the copy and the run hold a lock on build/program.lock (flock): runs never overlap,
# even under -j, while the builds before them stay parallel.
# The bench's own last line starts with PASS or FAIL (Verilator prints a report
# after it); only PASS succeeds.
run-$(1): $(CORE_BIN) $(BUILD)/sw/$(1)/$(1).hex
	flock $(BUILD)/program.lock sh -c 'cp $(BUILD)/sw/$(1)/$(1).hex $(BUILD)/program.hex && \
	  $(CORE_SIM) +name=$(1) $$(ARGS)' | tee $(BUILD)/core/$(1).log
	@grep -E '^(PASS|FAIL)' $(BUILD)/core/$(1).log | tail -n 1 | grep -q '^PASS'
endef
$(foreach p,$(PROGS),$(eval $(call PROG_RULES,$(p))))

# ---------------- housekeeping ----------------

$(BUILD) $(BUILD)/unit $(BUILD)/core:
	mkdir -p $@

clean:
	rm -rf $(BUILD)
