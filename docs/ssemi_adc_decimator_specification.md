# SSEMI ADC Decimator Specification

## Overview

The SSEMI ADC Decimator is a high-performance, configurable digital decimation filter designed for oversampled ADC applications. The design implements a three-stage decimation architecture that provides excellent filtering performance while maintaining high throughput and low power consumption.

## Key Features

- **Decimation Factor**: Configurable from 32 to 512 (OSR: 32-512)
- **Passband Frequency**: 20kHz with <0.01dB ripple
- **Stopband Attenuation**: >100dB
- **Output Sample Rate**: 0.5-40kHz
- **Input Data Width**: 16-bit
- **Output Data Width**: 24-bit
- **Three-Stage Architecture**: CIC + FIR + Halfband FIR
- **Configurable Parameters**: All filter stages are parameterizable
- **Single Clock Domain**: Unified clock with internal division
- **Verilog-2001 Compatible**: Standard RTL implementation

## Architecture

### Three-Stage Decimation Pipeline

```
Input ADC Data (16-bit)
    ↓
┌─────────────────────────────────────┐
│ Stage 1: CIC Filter                │
│ - Coarse decimation (32-512x)      │
│ - 5 configurable stages            │
│ - Differential delay: 1            │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Stage 2: FIR Filter                │
│ - Passband compensation            │
│ - 64 configurable taps             │
│ - 18-bit coefficients              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Stage 3: Halfband FIR Filter       │
│ - Final 2:1 decimation             │
│ - 33 configurable taps             │
│ - 18-bit coefficients              │
└─────────────────────────────────────┘
    ↓
Output Data (24-bit)
```

### Clock Architecture

The design uses a single input clock with internal clock dividers for each stage:

- **Input Clock**: Main system clock
- **CIC Clock**: Divided by decimation factor
- **FIR Clock**: Further divided by 2
- **Halfband Clock**: Further divided by 2

## Module Hierarchy

```
ssemi_adc_decimator_sys_top
├── ssemi_clock_divider (3 instances)
├── ssemi_cic_filter
├── ssemi_fir_filter
└── ssemi_halfband_filter
```

## Interface Specification

### Clock and Reset
- `i_clk`: Input clock (100MHz typical)
- `i_rst_n`: Active-low asynchronous reset

### Control Interface
- `i_enable`: Enable decimator operation
- `i_config_valid`: Configuration data valid
- `i_config_addr[7:0]`: Configuration address
- `i_config_data[31:0]`: Configuration data
- `o_config_ready`: Configuration ready

### Data Interface
- `i_data[15:0]`: Input data (16-bit signed)
- `i_valid`: Input data valid
- `o_ready`: Ready for input data
- `o_data[23:0]`: Output data (24-bit signed)
- `o_valid`: Output data valid
- `i_ready`: Downstream ready

### Status Interface
- `o_status[7:0]`: Status information
- `o_busy`: Decimator busy flag
- `o_error`: Error flag

## Filter Specifications

### CIC Filter (Stage 1)
- **Type**: Cascaded Integrator-Comb
- **Stages**: 5 (configurable)
- **Differential Delay**: 1 (configurable)
- **Decimation Factor**: 32-512 (configurable)
- **Data Width**: 16-bit input, 32-bit internal, 24-bit output
- **Frequency Response**: sinc^5(f) characteristic

### FIR Filter (Stage 2)
- **Type**: Symmetric FIR
- **Taps**: 64 (configurable)
- **Coefficient Width**: 18-bit
- **Data Width**: 24-bit
- **Purpose**: Passband compensation and stopband attenuation
- **Optimization**: Symmetric coefficient structure for efficiency

### Halfband FIR Filter (Stage 3)
- **Type**: Halfband FIR with 2:1 decimation
- **Taps**: 33 (configurable, must be odd)
- **Coefficient Width**: 18-bit
- **Data Width**: 24-bit input, 24-bit output
- **Purpose**: Final decimation and filtering
- **Optimization**: Zero-valued odd taps for efficiency

## Performance Specifications

### Frequency Response
- **Passband**: 0 to 20kHz
- **Passband Ripple**: <0.01dB
- **Stopband**: >40kHz
- **Stopband Attenuation**: >100dB
- **Transition Band**: 20kHz to 40kHz

### Timing Specifications
- **Input Clock Frequency**: Up to 100MHz
- **Output Sample Rate**: 0.5-40kHz (configurable)
- **Latency**: <100 clock cycles
- **Throughput**: 1 sample per output clock cycle

### Power Specifications
- **Dynamic Power**: <10mW at 100MHz
- **Static Power**: <1mW
- **Power Management**: Clock gating support

## Configuration

### Coefficient Loading
Filter coefficients are loaded through the configuration interface:

- **FIR Coefficients**: Addresses 0-63
- **Halfband Coefficients**: Addresses 64-96
- **Control Registers**: Addresses 128-255

### Parameter Configuration
Key parameters are set at synthesis time:

```verilog
parameter CIC_DECIMATION_FACTOR = 64;     // CIC decimation factor
parameter CIC_STAGES = 5;                 // Number of CIC stages
parameter FIR_TAPS = 64;                  // FIR filter taps
parameter HALFBAND_TAPS = 33;             // Halfband filter taps
parameter INPUT_WIDTH = 16;               // Input data width
parameter OUTPUT_WIDTH = 24;              // Output data width
```

## Verification

### Testbench Features
- **Functional Verification**: All three stages tested
- **Performance Verification**: Frequency response validation
- **Corner Case Testing**: Reset, enable/disable, overflow
- **Waveform Generation**: VCD file output for analysis

### Test Scenarios
1. **Sine Wave Input**: 1kHz test signal
2. **Step Function**: Transient response testing
3. **Random Input**: Statistical performance validation
4. **Coefficient Loading**: Configuration interface testing

### Coverage Goals
- **Functional Coverage**: 95%
- **Code Coverage**: 90%
- **Toggle Coverage**: 100%

## Implementation Guidelines

### Synthesis
- **Target Technology**: ASIC/FPGA compatible
- **Optimization**: Area and power optimized
- **Timing**: Multi-cycle paths for high-frequency operation
- **Constraints**: SDC/XDC files provided

### Layout Considerations
- **Clock Distribution**: Balanced clock tree
- **Power Distribution**: Multiple power domains
- **Signal Integrity**: Careful routing for high-speed signals
- **Thermal Management**: Adequate heat dissipation

## Usage Examples

### Basic Instantiation
```verilog
ssemi_adc_decimator_sys_top #(
    .CIC_DECIMATION_FACTOR(64),
    .CIC_STAGES(5),
    .FIR_TAPS(64),
    .HALFBAND_TAPS(33)
) decimator (
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_enable(enable),
    .i_data(adc_data),
    .i_valid(adc_valid),
    .o_data(filtered_data),
    .o_valid(filtered_valid)
);
```

### Coefficient Loading
```verilog
// Load FIR coefficients
for (int i = 0; i < 64; i++) begin
    @(posedge clk);
    i_config_valid = 1;
    i_config_addr = i;
    i_config_data = fir_coeff[i];
end
```

## File Structure

```
rtl/
├── ssemi_timescale.vh          # Common timescale definition
├── ssemi_defines.vh            # Common parameters and defines
├── ssemi_clock_divider.v       # Clock divider module
├── ssemi_cic_filter.v          # CIC filter module
├── ssemi_fir_filter.v          # FIR filter module
├── ssemi_halfband_filter.v     # Halfband filter module
└── ssemi_adc_decimator_sys_top.v   # Top-level wrapper

tb/
├── sv_tb/
│   └── tb_ssemi_adc_decimator_sys_top.v  # Testbench
└── Makefile                    # Simulation makefile

docs/
└── ssemi_adc_decimator_specification.md  # This document
```

## Compliance

### Standards Compliance
- **Verilog-2001**: Full compliance
- **Vyges Conventions**: Follows all naming and structure guidelines
- **Synthesis**: Compatible with major synthesis tools
- **Simulation**: Compatible with major simulators

### Quality Assurance
- **Linting**: Passes all linting checks
- **Synthesis**: Synthesizable RTL
- **Simulation**: Comprehensive testbench coverage
- **Documentation**: Complete specification and user guide

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-08-26 | SSEMI Team | Initial release |

## License

Apache-2.0 License - See LICENSE file for details.

## Support

For technical support and questions:
- Email: support@ssemi.com
- Documentation: https://docs.ssemi.com
- Repository: https://github.com/ssemi/adc-decimator
