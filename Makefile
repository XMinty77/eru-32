# ================ eru-32 Makefile ================
# make                 run every unit bench (same as make unit)
# make alu             compile and run one unit bench, tb/unit/alu_tb.sv, with Icarus
# make alu ARGS=+foo   pass plusargs to the bench
# make lint            Verilator lint of the RTL, top module $(TOP)
# make lint-alu        Verilator lint of one unit bench with the RTL
# make synth-check     yosys generic synthesis of the RTL, to catch SV it can't read
# make clean           delete build/
# A bench that fails ($fatal) makes make stop with an error.
# Unit benches are named after what they test; don't name one after a target above.
# =================================================

# Packages, in dependency order: each one is compiled before anything that imports it.
PKGS    :=
# Packages used only by benches.
TB_PKGS :=
# All other RTL files: modules.
RTL     := $(filter-out $(PKGS),$(wildcard rtl/*.sv))
# The core's top module, for lint and synth-check.
TOP     := core

# Unit benches are tb/unit/<unit>_tb.sv; each <unit> becomes a target.
UNITS   := $(patsubst tb/unit/%_tb.sv,%,$(wildcard tb/unit/*_tb.sv))

BUILD     := build
IVERILOG  := iverilog -g2012 -Wall
VVP       := vvp -n
VERILATOR := verilator -Wall --timing
YOSYS     := yosys
ARGS      :=

.PHONY: all unit lint synth-check clean $(UNITS) $(addprefix lint-,$(UNITS))

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
	$(VERILATOR) --lint-only --top-module $(TOP) $(PKGS) $(RTL)

$(addprefix lint-,$(UNITS)): lint-%:
	$(VERILATOR) --lint-only --top-module $*_tb $(PKGS) $(TB_PKGS) $(RTL) tb/unit/$*_tb.sv

# ---------------- synthesis check (yosys) ----------------

synth-check: | $(BUILD)
	@test -n "$(RTL)" || { echo "No RTL in rtl/ yet"; exit 1; }
	$(YOSYS) -q -l $(BUILD)/synth-check.log \
	  -p 'read_verilog -sv $(PKGS) $(RTL); synth -top $(TOP); stat'
	@echo "synth-check: OK (log in $(BUILD)/synth-check.log)"

# ---------------- housekeeping ----------------

$(BUILD) $(BUILD)/unit:
	mkdir -p $@

clean:
	rm -rf $(BUILD)
