#=============================================================================
# Cocotb Test for SSEMI ADC Decimator - Reset Behavior
#=============================================================================
# Description: Test reset behavior of ssemi_adc_decimator_sys_top
# Author:      SSEMI Development Team
# Date:        2025-08-29T07:06:38Z
# License:     Apache-2.0
#=============================================================================

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

# Test parameters
CLOCK_PERIOD_NS = 10  # 100MHz clock
RESET_CYCLES = 5

# Error types
ERROR_NONE = 0

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_rst_n.value = 0
    await Timer(CLOCK_PERIOD_NS * RESET_CYCLES, units="ns")
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

@cocotb.test()
async def test_reset_behavior(dut):
    """Test reset behavior of the ADC decimator"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Apply reset
    await reset_dut(dut)
    
    # Check reset values
    assert dut.o_ready.value == 1, f"o_ready should be 1 after reset, got {dut.o_ready.value}"
    assert dut.o_valid.value == 0, f"o_valid should be 0 after reset, got {dut.o_valid.value}"
    assert dut.o_busy.value == 0, f"o_busy should be 0 after reset, got {dut.o_busy.value}"
    assert dut.o_error.value == 0, f"o_error should be 0 after reset, got {dut.o_error.value}"
    assert dut.o_error_type.value == ERROR_NONE, f"o_error_type should be {ERROR_NONE}, got {dut.o_error_type.value}"
    assert dut.o_status.value == 0, f"o_status should be 0 after reset, got {dut.o_status.value}"
    
    print("✅ Reset behavior test passed")
