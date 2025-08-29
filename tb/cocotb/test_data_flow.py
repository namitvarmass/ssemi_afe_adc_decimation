#=============================================================================
# Cocotb Test for SSEMI ADC Decimator - Data Flow
#=============================================================================
# Description: Test basic data flow through ssemi_adc_decimator_top
# Author:      SSEMI Development Team
# Date:        2025-08-29T07:06:38Z
# License:     Apache-2.0
#=============================================================================

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Test parameters
CLOCK_PERIOD_NS = 10  # 100MHz clock
RESET_CYCLES = 5
DECIMATION_FACTOR = 64

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_rst_n.value = 0
    await Timer(CLOCK_PERIOD_NS * RESET_CYCLES, units="ns")
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

async def wait_for_ready(dut, timeout_cycles=1000):
    """Wait for the DUT to be ready"""
    for _ in range(timeout_cycles):
        await RisingEdge(dut.i_clk)
        if dut.o_ready.value == 1:
            return True
    return False

def generate_test_signal(samples, frequency_hz=1000, amplitude=1000):
    """Generate a test sine wave signal"""
    fs = 1e9 / CLOCK_PERIOD_NS  # Sampling frequency
    t = np.arange(samples) / fs
    signal = amplitude * np.sin(2 * np.pi * frequency_hz * t)
    return signal.astype(int)

@cocotb.test()
async def test_basic_data_flow(dut):
    """Test basic data flow through the decimator"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Enable the decimator
    dut.i_enable.value = 1
    
    # Generate test signal
    test_samples = 1000
    test_signal = generate_test_signal(test_samples, frequency_hz=1000, amplitude=1000)
    
    output_samples = []
    sample_count = 0
    
    for i, data in enumerate(test_signal):
        # Wait for ready
        if not await wait_for_ready(dut):
            raise cocotb.result.TestFailure("DUT not ready within timeout")
        
        # Apply input data
        dut.i_data.value = data
        dut.i_valid.value = 1
        await RisingEdge(dut.i_clk)
        
        # Check for output
        if dut.o_valid.value == 1:
            output_samples.append(int(dut.o_data.value))
            sample_count += 1
        
        # Clear input valid after one cycle
        dut.i_valid.value = 0
    
    # Verify decimation
    expected_output_samples = test_samples // DECIMATION_FACTOR
    assert len(output_samples) > 0, "No output samples received"
    assert len(output_samples) <= expected_output_samples, f"Too many output samples: {len(output_samples)} > {expected_output_samples}"
    
    print(f"✅ Basic data flow test passed: {len(output_samples)} output samples from {test_samples} input samples")
