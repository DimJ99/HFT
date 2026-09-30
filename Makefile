# FPGA Tick-to-Trade: build / sim / formal / synth entry point.  `make help` for usage.
#
# Layout conventions (all optional; targets skip what doesn't exist yet):
#   rtl/**/*.{sv,v}        synthesizable RTL; module name == file name
#   model/**/*.cpp         C++ golden models + exchange world  -> build/libmodel.a
#   apps/<name>/*.cpp      C++ executables (replay, exchange sim, ref loop) -> build/bin/<name>
#   tb/common/*.cpp        shared AXI-Stream driver / monitor / scoreboard
#   tb/<block>/*.cpp       Verilator testbench for RTL top module <block>
#   formal/<name>.sby      SymbiYosys jobs

SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT  := $(CURDIR)
BUILD := $(ROOT)/build
export PATH := $(ROOT)/tools/bin:$(ROOT)/tools/oss-cad-suite/bin:$(ROOT)/tools/venv/bin:$(PATH)

# ---- knobs (override on the command line) -------------------------------------
# BLOCK    RTL top module / testbench name, e.g. itch_parser
# SEED     testbench RNG seed (passed as +seed=)
# TRACE    1 = dump FST waves
# ARGS     extra args for the sim binary
# ITCH     ITCH file passed to the testbench as +itch=
# SYMBOL   ticker that `make sample` filters for; UNTIL = feed time to stop at
# PART     Vivado part for `make synth`; set to your board's device
BLOCK    ?=
SEED     ?= 1
TRACE    ?= 1
ARGS     ?=
ITCH     ?= $(firstword $(wildcard data/$(SYMBOL).itch))
CXX      ?= g++
CXXSTD   ?= c++20
OPT      ?= -O2 -g
JOBS     ?= $(shell nproc)
CLK_MHZ  ?= 156.25
CLK_PORT ?= clk
PART     ?= xcku5p-ffvb676-2-e
VENUE    ?= nasdaq
ITCH_GZ  ?= 07302019.NASDAQ_ITCH50.gz
SYMBOL   ?= AAPL
UNTIL    ?= 10:00
COV_N    ?= 500
APP      ?=
SAN_OPT  ?= -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined

# ---- sources -------------------------------------------------------------------
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

RTL_SRCS  := $(call rwildcard,rtl,*.sv *.v)
RTL_INCS  := $(addprefix -I,$(sort $(dir $(RTL_SRCS))))
MODEL_SRC := $(call rwildcard,model,*.cpp)
MODEL_OBJ := $(MODEL_SRC:%.cpp=$(BUILD)/obj/%.o)
TBC_SRCS  := $(wildcard tb/common/*.cpp)
TB_BLOCKS := $(filter-out common,$(notdir $(patsubst %/,%,$(wildcard tb/*/))))
APPS      := $(notdir $(patsubst %/,%,$(wildcard apps/*/)))
SBY_JOBS  := $(basename $(notdir $(wildcard formal/*.sby)))

CPPFLAGS += -Imodel -Itb/common -MMD -MP
CXXFLAGS += -std=$(CXXSTD) $(OPT) -Wall -Wextra -Wpedantic

CCACHE := $(shell command -v ccache 2>/dev/null)
ifneq ($(CCACHE),)
  export OBJCACHE := ccache
  CXX := ccache $(CXX)
endif

VERILATOR_FLAGS := --cc --exe --build -j $(JOBS) --assert -Wall -Wno-fatal \
                   --x-assign unique --x-initial unique \
                   -CFLAGS "-std=$(CXXSTD) -I$(ROOT)/model -I$(ROOT)/tb/common" \
                   -O3 $(RTL_INCS)
ifeq ($(TRACE),1)
  VERILATOR_FLAGS += --trace-fst --trace-structs
endif

# ---- help ----------------------------------------------------------------------
.PHONY: help
help:
	@echo "Environment"
	@echo "  make setup                 install apt deps + OSS CAD Suite + python venv into ./tools"
	@echo "  make doctor                check toolchain versions"
	@echo "  make shell                 subshell with the toolchain on PATH"
	@echo "Data"
	@echo "  make data                  fetch $(ITCH_GZ) ($(VENUE)) into data/"
	@echo "  make data-list VENUE=nasdaq  list downloadable days"
	@echo "  make sample [SYMBOL= UNTIL=]  $(SYMBOL) msgs from start of day to $(UNTIL) -> data/$(SYMBOL).itch"
	@echo "  make coverage [COV_N=]    first $(COV_N) of every msg type, all symbols -> data/coverage.itch"
	@echo "C++"
	@echo "  make model                 build golden models -> build/libmodel.a"
	@echo "  make apps                  build apps/* -> build/bin/  [$(APPS)]"
	@echo "  make run-<app> [ARGS=]     build + run one app, e.g. make run-itch_dump ARGS=data/AAPL.itch"
	@echo "  make check-itch            parse every data/*.itch with itch_dump; fails on any BAD message"
	@echo "  make asan [APP=x ARGS=]    ASan+UBSan build in build/asan, then check-itch (or run APP)"
	@echo "  make check                 every model check (check-itch)"
	@echo "RTL"
	@echo "  make lint [BLOCK=x]        verilator lint"
	@echo "  make sim BLOCK=x [SEED= TRACE=0 ARGS=]   build + run tb/x against rtl top x"
	@echo "  make waves BLOCK=x         open build/sim/x/waves.fst"
	@echo "  make formal [JOB=x]        run formal/*.sby  [$(SBY_JOBS)]"
	@echo "  make synth BLOCK=x [PART= CLK_MHZ=]      Vivado OOC synth + timing"
	@echo "  make test                  lint + model checks + every tb + every formal job"
	@echo "Misc"
	@echo "  make format | clean | distclean"
	@echo ""
	@echo "testbenches: [$(TB_BLOCKS)]   rtl files: $(words $(RTL_SRCS))"

# ---- environment ---------------------------------------------------------------
.PHONY: setup doctor shell
setup:
	@scripts/setup.sh
doctor:
	@scripts/doctor.sh
shell:
	@echo "toolchain on PATH; exit to leave"; exec bash --rcfile <(cat ~/.bashrc 2>/dev/null; echo 'source scripts/env.sh; PS1="(hft) $$PS1"')

# ---- data ----------------------------------------------------------------------
.PHONY: data data-list sample coverage
data:
	@scripts/fetch_itch.sh $(VENUE) $(ITCH_GZ)
data-list:
	@scripts/fetch_itch.sh list $(VENUE)
sample: data/$(SYMBOL).itch
data/$(SYMBOL).itch: | data/$(ITCH_GZ)
	python3 scripts/itch_filter.py data/$(ITCH_GZ) $@ --symbol $(SYMBOL) --until $(UNTIL)
coverage: data/coverage.itch
data/coverage.itch: | data/$(ITCH_GZ)
	python3 scripts/itch_coverage.py data/$(ITCH_GZ) $@ -n $(COV_N)
data/$(ITCH_GZ):
	@scripts/fetch_itch.sh $(VENUE) $(ITCH_GZ)

# ---- C++ models / apps ---------------------------------------------------------
.PHONY: model apps
model: $(BUILD)/libmodel.a

$(BUILD)/libmodel.a: $(MODEL_OBJ)
	@mkdir -p $(@D)
	@if [ -z "$^" ]; then echo "(no model/*.cpp yet)"; ar rcs $@; else ar rcs $@ $^; fi

$(BUILD)/obj/%.o: %.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

define APP_template
$(BUILD)/bin/$(1): $$(patsubst %.cpp,$(BUILD)/obj/%.o,$$(wildcard apps/$(1)/*.cpp)) $(BUILD)/libmodel.a
	@mkdir -p $$(@D)
	$$(CXX) $$(CXXFLAGS) $$^ -o $$@ -lz
.PHONY: run-$(1)
run-$(1): $(BUILD)/bin/$(1)
	$(BUILD)/bin/$(1) $$(ARGS)
endef
$(foreach a,$(APPS),$(eval $(call APP_template,$(a))))
apps: $(APPS:%=$(BUILD)/bin/%)

# ---- model checks: golden models against real data ------------------------------
ITCH_FILES := $(wildcard data/*.itch)

.PHONY: check check-itch asan
check: check-itch

check-itch: $(BUILD)/bin/itch_dump
	@if [ -z "$(ITCH_FILES)" ]; then echo "(no data/*.itch yet; make coverage or make sample)"; exit 0; fi; \
	set -e; for f in $(ITCH_FILES); do echo "== itch_dump $$f"; $(BUILD)/bin/itch_dump $$f; done

# Same targets, rebuilt with sanitizers into a separate tree so normal builds stay fast.
asan:
	@$(MAKE) --no-print-directory BUILD=$(ROOT)/build/asan OPT="$(SAN_OPT)" $(if $(APP),run-$(APP),check-itch)

-include $(shell find $(BUILD)/obj -name '*.d' 2>/dev/null)

# ---- RTL -----------------------------------------------------------------------
define need_block
	@if [ -z "$(BLOCK)" ]; then echo "set BLOCK=<name>  (testbenches: $(TB_BLOCKS))"; exit 1; fi
endef

.PHONY: lint sim waves formal synth test
lint:
	@if [ -z "$(RTL_SRCS)" ]; then echo "(no rtl yet)"; exit 0; fi; \
	verilator --lint-only -Wall $(RTL_INCS) $(if $(BLOCK),--top-module $(BLOCK),-Wno-MULTITOP) $(RTL_SRCS)

SIM_DIR = $(BUILD)/sim/$(BLOCK)
sim: model
	$(need_block)
	@[ -d tb/$(BLOCK) ] || { echo "no tb/$(BLOCK)/"; exit 1; }
	@mkdir -p $(SIM_DIR)
	verilator $(VERILATOR_FLAGS) --top-module $(BLOCK) -Mdir $(SIM_DIR) -o V$(BLOCK) \
	    -LDFLAGS "$(BUILD)/libmodel.a -lz" \
	    $(RTL_SRCS) $(abspath $(wildcard tb/$(BLOCK)/*.cpp) $(TBC_SRCS))
	cd $(SIM_DIR) && ./V$(BLOCK) +seed=$(SEED) $(if $(ITCH),+itch=$(abspath $(ITCH))) $(ARGS)

waves:
	$(need_block)
	@f=$$(ls -t $(SIM_DIR)/*.fst $(SIM_DIR)/*.vcd 2>/dev/null | head -1); \
	[ -n "$$f" ] || { echo "no waves in $(SIM_DIR); run make sim BLOCK=$(BLOCK)"; exit 1; }; \
	if surfer --version >/dev/null 2>&1; then surfer $$f & else gtkwave $$f & fi

JOB ?= $(SBY_JOBS)
formal:
	@if [ -z "$(strip $(JOB))" ]; then echo "(no formal/*.sby yet)"; exit 0; fi; \
	for j in $(JOB); do echo "== sby $$j"; (cd formal && sby -f $$j.sby) || exit 1; done

synth:
	$(need_block)
	@command -v vivado >/dev/null || { echo "vivado not on PATH (source <Vivado>/settings64.sh)"; exit 1; }
	@mkdir -p $(BUILD)/synth/$(BLOCK)
	cd $(BUILD)/synth/$(BLOCK) && vivado -mode batch -nojournal -log vivado.log \
	    -source $(ROOT)/scripts/synth.tcl -tclargs $(BLOCK) $(PART) $(CLK_PORT) \
	    $$(python3 -c "print(f'{1000/$(CLK_MHZ):.3f}')") $(BUILD)/synth/$(BLOCK) $(abspath $(RTL_SRCS))

test: lint check
	@set -e; for b in $(TB_BLOCKS); do $(MAKE) --no-print-directory sim BLOCK=$$b TRACE=0; done
	@$(MAKE) --no-print-directory formal

# ---- misc ----------------------------------------------------------------------
.PHONY: format clean distclean
format:
	@f=$$(find model apps tb -name '*.cpp' -o -name '*.hpp' -o -name '*.h' 2>/dev/null); \
	[ -z "$$f" ] || clang-format -i $$f
clean:
	rm -rf $(BUILD) $(addprefix formal/,$(SBY_JOBS))
distclean: clean
	rm -rf tools
