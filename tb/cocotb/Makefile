#==============================================================================
# Cocotb Testbench Makefile (Standard Approach)
#==============================================================================
# Description: Makefile for Cocotb testbench execution following standard cocotb
#              approach. Supports Icarus and Verilator simulators with proper
#              VPI integration and fallback patterns.
# Author:      Vyges Team
# Date:        2025-01-20
# Version:     1.0.0
# License:     Apache-2.0
#
# This Makefile follows the cocotb standard approach:
# https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile
#==============================================================================

# Defaults - following cocotb documentation
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Design source files for SSEMI ADC Decimator
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_timescale.vh
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_defines.vh
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_clock_divider.v
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_cic_filter.v
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_fir_filter.v
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_halfband_filter.v
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_config_status_regs.v
VERILOG_SOURCES += $(PWD)/../../rtl/ssemi_adc_decimator_top.v

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = ssemi_adc_decimator_top

# MODULE is the basename of the Python test file
MODULE = test_example

# Check if cocotb-config is available (try multiple locations)
COCOTB_CONFIG := $(shell which cocotb-config 2>/dev/null || echo $(HOME)/.local/bin/cocotb-config)

# Include cocotb's make rules if available, otherwise use fallback
ifneq ($(wildcard $(COCOTB_CONFIG)),)
    # Standard cocotb approach
    include $(shell cocotb-config --makefiles)/Makefile.sim
else
    # Fallback approach when cocotb-config is not available
    @echo "⚠️  cocotb-config not found, using fallback approach"
    @echo "   This will only work with Icarus Verilog simulator"
    @echo "   To enable full cocotb support, install cocotb: pip install cocotb"
    
    # Fallback compilation for Icarus Verilog only
    ifeq ($(SIM),icarus)
        all: compile run
        
        compile:
			@echo "Compiling with Icarus Verilog (fallback mode)..."
			@mkdir -p work
			iverilog -g2012 -I$(PWD)/../../rtl -o work/$(TOPLEVEL).vvp $(VERILOG_SOURCES)
			@echo "✅ Compilation successful"
        
        run: compile
			@echo "Running cocotb tests with Icarus Verilog (fallback mode)..."
			@echo "⚠️  Note: This is a simplified fallback - full cocotb features may not work"
			@echo "   Install cocotb for full functionality: pip install cocotb"
			@echo "✅ Fallback test completed (cocotb not available)"
        
        clean:
			@echo "Cleaning fallback build artifacts..."
			@rm -rf work
			@rm -f *.vcd *.log
			@echo "✅ Clean completed"
    else
        all:
			@echo "❌ Error: cocotb-config not found and SIM=$(SIM) is not supported in fallback mode"
			@echo "   Only SIM=icarus is supported without cocotb"
			@echo "   To use $(SIM), install cocotb: pip install cocotb"
			@exit 1
    endif
endif

# Additional targets for different test modules (only work with full cocotb)
ifneq ($(wildcard $(COCOTB_CONFIG)),)
    test_reset:
		MODULE=test_reset $(MAKE)

    test_data_flow:
		MODULE=test_data_flow $(MAKE)

    test_configuration:
		MODULE=test_configuration $(MAKE)

    test_error_detection:
		MODULE=test_error_detection $(MAKE)

    test_status_monitoring:
		MODULE=test_status_monitoring $(MAKE)

    test_overflow_underflow:
		MODULE=test_overflow_underflow $(MAKE)

    test_parameter_validation:
		MODULE=test_parameter_validation $(MAKE)

    test_handshaking:
		MODULE=test_handshaking $(MAKE)

    test_comprehensive:
		MODULE=test_comprehensive $(MAKE)

    test_all: test_reset test_data_flow test_configuration test_error_detection test_status_monitoring test_overflow_underflow test_parameter_validation test_handshaking test_comprehensive
		@echo "All ADC decimator cocotb tests completed."

    # Coverage report generation
    coverage: run
		@echo "Generating coverage report..."
		@mkdir -p coverage
		@mkdir -p ../../public/coverage
		@if [ -f coverage.xml ] || [ -f coverage.html ]; then \
			echo "Coverage files found:"; \
			ls -la coverage.* 2>/dev/null || echo "No coverage files found"; \
			cp coverage.* ../../public/coverage/ 2>/dev/null || echo "No coverage files to copy"; \
		else \
			echo "No coverage data found"; \
		fi
		@echo "✅ Coverage report generation completed"
else
    test_reset:
		@echo "⚠️  cocotb not available - skipping test_reset"
		@echo "   Install cocotb: pip install cocotb"
    
    test_data_flow:
		@echo "⚠️  cocotb not available - skipping test_data_flow"
		@echo "   Install cocotb: pip install cocotb"
    
    test_configuration:
		@echo "⚠️  cocotb not available - skipping test_configuration"
		@echo "   Install cocotb: pip install cocotb"
    
    test_error_detection:
		@echo "⚠️  cocotb not available - skipping test_error_detection"
		@echo "   Install cocotb: pip install cocotb"
    
    test_status_monitoring:
		@echo "⚠️  cocotb not available - skipping test_status_monitoring"
		@echo "   Install cocotb: pip install cocotb"
    
    test_overflow_underflow:
		@echo "⚠️  cocotb not available - skipping test_overflow_underflow"
		@echo "   Install cocotb: pip install cocotb"
    
    test_parameter_validation:
		@echo "⚠️  cocotb not available - skipping test_parameter_validation"
		@echo "   Install cocotb: pip install cocotb"
    
    test_handshaking:
		@echo "⚠️  cocotb not available - skipping test_handshaking"
		@echo "   Install cocotb: pip install cocotb"
    
    test_comprehensive:
		@echo "⚠️  cocotb not available - skipping test_comprehensive"
		@echo "   Install cocotb: pip install cocotb"
    
    test_all:
		@echo "⚠️  cocotb not available - skipping test_all"
		@echo "   Install cocotb: pip install cocotb"
    
    coverage:
		@echo "⚠️  cocotb not available - skipping coverage"
		@echo "   Install cocotb: pip install cocotb"
endif

# Help target
help:
	@echo "Cocotb Testbench Makefile for SSEMI ADC Decimator"
	@echo "=================================================="
	@echo ""
	@echo "Available targets:"
	@echo "  all                    - Compile and run default test (default)"
	@echo "  test_reset             - Test reset behavior (requires cocotb)"
	@echo "  test_data_flow         - Test basic data flow (requires cocotb)"
	@echo "  test_configuration     - Test configuration interface (requires cocotb)"
	@echo "  test_error_detection   - Test error detection (requires cocotb)"
	@echo "  test_status_monitoring - Test status monitoring (requires cocotb)"
	@echo "  test_overflow_underflow- Test overflow/underflow detection (requires cocotb)"
	@echo "  test_parameter_validation - Test parameter validation (requires cocotb)"
	@echo "  test_handshaking       - Test handshaking protocol (requires cocotb)"
	@echo "  test_comprehensive     - Run comprehensive test (requires cocotb)"
	@echo "  test_all               - Run all test modules (requires cocotb)"
	@echo "  coverage               - Generate coverage report (requires cocotb)"
	@echo "  clean                  - Clean build artifacts"
	@echo "  help                   - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  SIM                    - Simulator to use (icarus, verilator, vcs, modelsim)"
	@echo "  TOPLEVEL               - Top-level module name (ssemi_adc_decimator_top)"
	@echo "  MODULE                 - Python test module name"
	@echo ""
	@echo "Cocotb Status:"
ifneq ($(wildcard $(COCOTB_CONFIG)),)
	@echo "  ✅ cocotb-config found: $(COCOTB_CONFIG)"
	@echo "  ✅ Full cocotb functionality available"
else
	@echo "  ❌ cocotb-config not found"
	@echo "  ⚠️  Only basic Icarus Verilog compilation available"
	@echo "  💡 Install cocotb: pip install cocotb"
	@echo "  💡 Or add ~/.local/bin to PATH: export PATH=\"\$$HOME/.local/bin:\$$PATH\""
endif
	@echo ""
	@echo "Examples:"
	@echo "  make SIM=verilator"
	@echo "  make SIM=icarus test_rescaling"
	@echo "  make SIM=vcs test_all"

# Phony targets
.PHONY: test_rescaling test_edge_cases test_all coverage help 