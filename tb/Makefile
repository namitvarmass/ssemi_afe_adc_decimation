#=============================================================================
# Makefile for SSEMI ADC Decimator Testbench
#=============================================================================
# Description: Build and simulation targets for ADC decimator verification
# Author:      SSEMI Development Team
# Date:        2025-08-26T17:54:47Z
# License:     Apache-2.0
#=============================================================================

# Tool configuration
SIMULATOR ?= icarus
IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

# Directory paths
RTL_DIR = ../rtl
TB_DIR = .
SIM_DIR = ../simulation
WAVE_DIR = $(SIM_DIR)/waveforms

# Source files
RTL_SOURCES = \
	$(RTL_DIR)/ssemi_timescale.vh \
	$(RTL_DIR)/ssemi_defines.vh \
	$(RTL_DIR)/ssemi_clock_divider.v \
	$(RTL_DIR)/ssemi_cic_filter.v \
	$(RTL_DIR)/ssemi_fir_filter.v \
	$(RTL_DIR)/ssemi_halfband_filter.v \
	$(RTL_DIR)/ssemi_adc_decimator_sys_top.v

TB_SOURCES = \
	$(TB_DIR)/sv_tb/tb_ssemi_adc_decimator_sys_top.v

# Simulation targets
SIM_TARGET = ssemi_adc_decimator_sim
VCD_FILE = $(WAVE_DIR)/ssemi_adc_decimator.vcd

# Default target
all: compile run

# Create directories
$(WAVE_DIR):
	mkdir -p $(WAVE_DIR)

# Compile the design
compile: $(WAVE_DIR)
	@echo "Compiling SSEMI ADC Decimator..."
	$(IVERILOG) -o $(SIM_TARGET) \
		-DSIMULATION \
		-I$(RTL_DIR) \
		$(RTL_SOURCES) \
		$(TB_SOURCES)
	@echo "Compilation completed."

# Run simulation
run: compile
	@echo "Running simulation..."
	$(VVP) $(SIM_TARGET) -vcd $(VCD_FILE)
	@echo "Simulation completed."

# View waveforms
wave: run
	@echo "Opening waveform viewer..."
	$(GTKWAVE) $(VCD_FILE) &

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(SIM_TARGET)
	rm -f $(VCD_FILE)
	rm -f *.vcd
	rm -f *.log
	@echo "Clean completed."

# Help target
help:
	@echo "SSEMI ADC Decimator Testbench Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Compile and run simulation (default)"
	@echo "  compile  - Compile the design only"
	@echo "  run      - Run simulation"
	@echo "  wave     - Run simulation and open waveform viewer"
	@echo "  clean    - Clean build artifacts"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  SIMULATOR - Simulator to use (default: icarus)"
	@echo "  IVERILOG  - Icarus Verilog compiler (default: iverilog)"
	@echo "  VVP       - Icarus Verilog simulator (default: vvp)"
	@echo "  GTKWAVE   - Waveform viewer (default: gtkwave)"

# Phony targets
.PHONY: all compile run wave clean help

