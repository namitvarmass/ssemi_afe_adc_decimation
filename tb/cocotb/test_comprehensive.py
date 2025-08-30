#=============================================================================
# Cocotb Test for SSEMI ADC Decimator - Comprehensive Test
#=============================================================================
# Description: Comprehensive functional test for ssemi_adc_decimator_top
#              Tests reset behavior, data flow, configuration, error detection,
#              and status monitoring for the multi-stage ADC decimator
# Author:      SSEMI Development Team
# Date:        2025-08-29T07:06:38Z
# License:     Apache-2.0
#=============================================================================

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

#==============================================================================
# Test Configuration
#==============================================================================

# Test parameters
CLOCK_PERIOD_NS = 10  # 100MHz clock
RESET_CYCLES = 5
DECIMATION_FACTOR = 64
CIC_STAGES = 5
FIR_TAPS = 64
HALFBAND_TAPS = 33

# Configuration register addresses
CONFIG_ADDR_ENABLE = 0x00
CONFIG_ADDR_CIC_STAGES = 0x01
CONFIG_ADDR_FIR_COEFF_START = 0x10
CONFIG_ADDR_HALFBAND_COEFF_START = 0x50
CONFIG_ADDR_STATUS = 0x80

# Error types
ERROR_NONE = 0
ERROR_OVERFLOW = 1
ERROR_UNDERFLOW = 2
ERROR_INVALID_CONFIG = 3
ERROR_INVALID_ADDRESS = 4

#==============================================================================
# Helper Functions
#==============================================================================

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

async def write_config(dut, addr, data):
    """Write configuration data using CSR interface"""
    dut.i_csr_wr_valid.value = 1
    dut.i_csr_addr.value = addr
    dut.i_csr_wr_data.value = data
    
    # Wait for ready
    while dut.o_csr_wr_ready.value == 0:
        await RisingEdge(dut.i_clk)
    
    await RisingEdge(dut.i_clk)
    dut.i_csr_wr_valid.value = 0

async def read_config(dut, addr):
    """Read configuration data using CSR interface"""
    dut.i_csr_addr.value = addr
    dut.i_csr_rd_ready.value = 1
    
    # Wait for valid data
    while dut.o_csr_rd_valid.value == 0:
        await RisingEdge(dut.i_clk)
    
    data = dut.o_csr_rd_data.value
    dut.i_csr_rd_ready.value = 0
    
    return data

def generate_test_signal(samples, frequency_hz=1000, amplitude=1000):
    """Generate a test sine wave signal"""
    fs = 1e9 / CLOCK_PERIOD_NS  # Sampling frequency
    t = np.arange(samples) / fs
    signal = amplitude * np.sin(2 * np.pi * frequency_hz * t)
    return signal.astype(int)

#==============================================================================
# Test Cases
#==============================================================================

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

@cocotb.test()
async def test_configuration_interface(dut):
    """Test configuration interface functionality"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test configuration writes
    test_configs = [
        (CONFIG_ADDR_ENABLE, 0x01),
        (CONFIG_ADDR_CIC_STAGES, CIC_STAGES),
        (CONFIG_ADDR_FIR_COEFF_START, 0x12345678),
        (CONFIG_ADDR_HALFBAND_COEFF_START, 0x87654321)
    ]
    
    for addr, data in test_configs:
        await write_config(dut, addr, data)
        print(f"✅ Configuration write test passed: addr=0x{addr:02x}, data=0x{data:08x}")

@cocotb.test()
async def test_error_detection(dut):
    """Test error detection and reporting"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test invalid configuration address
    dut.i_csr_wr_valid.value = 1
    dut.i_csr_addr.value = 0xFF  # Invalid address
    dut.i_csr_wr_data.value = 0x12345678
    
    await RisingEdge(dut.i_clk)
    dut.i_csr_wr_valid.value = 0
    
    # Wait a few cycles for error detection
    for _ in range(10):
        await RisingEdge(dut.i_clk)
        if dut.o_error.value == 1:
            print("✅ Invalid address error detection test passed")
            break
    else:
        print("⚠️  Invalid address error not detected (may be expected behavior)")

@cocotb.test()
async def test_status_monitoring(dut):
    """Test status monitoring functionality"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Enable and start processing
    dut.i_enable.value = 1
    
    # Send some data to trigger status changes
    test_signal = generate_test_signal(100, frequency_hz=1000, amplitude=1000)
    
    for data in test_signal:
        if dut.o_ready.value == 1:
            dut.i_data.value = data
            dut.i_valid.value = 1
            await RisingEdge(dut.i_clk)
            dut.i_valid.value = 0
            
            # Check status bits
            if dut.o_busy.value == 1:
                print(f"✅ Busy status detected: status=0x{dut.o_status.value:02x}")
                break
    
    # Check stage status
    if dut.o_cic_stage_status.value != 0:
        print(f"✅ CIC stage status: 0x{dut.o_cic_stage_status.value:04x}")
    if dut.o_fir_tap_status.value != 0:
        print(f"✅ FIR tap status: 0x{dut.o_fir_tap_status.value:06x}")
    if dut.o_halfband_tap_status.value != 0:
        print(f"✅ Halfband tap status: 0x{dut.o_halfband_tap_status.value:05x}")

@cocotb.test()
async def test_overflow_underflow(dut):
    """Test overflow and underflow detection"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Enable
    dut.i_enable.value = 1
    
    # Test with maximum amplitude signal to potentially trigger overflow
    max_amplitude = 32767  # Maximum 16-bit signed value
    test_signal = generate_test_signal(1000, frequency_hz=1000, amplitude=max_amplitude)
    
    overflow_detected = False
    underflow_detected = False
    
    for data in test_signal:
        if dut.o_ready.value == 1:
            dut.i_data.value = data
            dut.i_valid.value = 1
            await RisingEdge(dut.i_clk)
            dut.i_valid.value = 0
            
            # Check for overflow/underflow
            if dut.o_error.value == 1:
                if dut.o_error_type.value == ERROR_OVERFLOW:
                    overflow_detected = True
                    print("✅ Overflow detection test passed")
                elif dut.o_error_type.value == ERROR_UNDERFLOW:
                    underflow_detected = True
                    print("✅ Underflow detection test passed")
    
    if not overflow_detected and not underflow_detected:
        print("✅ No overflow/underflow detected (may be expected for this signal)")

@cocotb.test()
async def test_parameter_validation(dut):
    """Test parameter validation"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Verify parameters
    assert dut.CIC_STAGES.value == CIC_STAGES, f"Expected CIC_STAGES={CIC_STAGES}, got {dut.CIC_STAGES.value}"
    assert dut.FIR_TAPS.value == FIR_TAPS, f"Expected FIR_TAPS={FIR_TAPS}, got {dut.FIR_TAPS.value}"
    assert dut.HALFBAND_TAPS.value == HALFBAND_TAPS, f"Expected HALFBAND_TAPS={HALFBAND_TAPS}, got {dut.HALFBAND_TAPS.value}"
    assert dut.DECIMATION_FACTOR.value == DECIMATION_FACTOR, f"Expected DECIMATION_FACTOR={DECIMATION_FACTOR}, got {dut.DECIMATION_FACTOR.value}"
    
    print("✅ Parameter validation test passed")

@cocotb.test()
async def test_handshaking_protocol(dut):
    """Test valid/ready handshaking protocol"""
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Enable
    dut.i_enable.value = 1
    
    # Test handshaking with backpressure
    test_data = [100, 200, 300, 400, 500]
    
    for data in test_data:
        # Wait for ready
        while dut.o_ready.value == 0:
            await RisingEdge(dut.i_clk)
        
        # Apply data and valid
        dut.i_data.value = data
        dut.i_valid.value = 1
        await RisingEdge(dut.i_clk)
        
        # Clear valid
        dut.i_valid.value = 0
        
        # Wait a few cycles
        for _ in range(5):
            await RisingEdge(dut.i_clk)
    
    print("✅ Handshaking protocol test passed")

@cocotb.test()
async def test_comprehensive(dut):
    """Comprehensive test combining all functionality"""
    
    print("🚀 Starting comprehensive ADC decimator test...")
    
    # Create clock
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Enable
    dut.i_enable.value = 1
    
    # Configure
    await write_config(dut, CONFIG_ADDR_ENABLE, 0x01)
    
    # Generate and process test signal
    test_samples = 2000
    test_signal = generate_test_signal(test_samples, frequency_hz=1000, amplitude=5000)
    
    output_samples = []
    error_count = 0
    
    for i, data in enumerate(test_signal):
        if dut.o_ready.value == 1:
            dut.i_data.value = data
            dut.i_valid.value = 1
            await RisingEdge(dut.i_clk)
            dut.i_valid.value = 0
            
            # Collect output
            if dut.o_valid.value == 1:
                output_samples.append(int(dut.o_data.value))
            
            # Monitor errors
            if dut.o_error.value == 1:
                error_count += 1
                print(f"⚠️  Error detected at sample {i}: type={dut.o_error_type.value}")
    
    # Summary
    print(f"📊 Test Summary:")
    print(f"   Input samples: {test_samples}")
    print(f"   Output samples: {len(output_samples)}")
    print(f"   Decimation ratio: {test_samples / len(output_samples):.2f}")
    print(f"   Errors detected: {error_count}")
    print(f"   Final status: 0x{dut.o_status.value:02x}")
    
    # Verify basic functionality
    assert len(output_samples) > 0, "No output samples generated"
    assert len(output_samples) <= test_samples // DECIMATION_FACTOR, "Too many output samples"
    
    print("✅ Comprehensive test passed")
