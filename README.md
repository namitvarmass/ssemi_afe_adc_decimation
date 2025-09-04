[![Vyges IP](https://img.shields.io/badge/Vyges-IP%20Block-blue?style=flat&logo=github)](https://vyges.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Design Type](https://img.shields.io/badge/Design%20Type-Digital-purple)](https://vyges.com/docs/design-types)
[![Target](https://img.shields.io/badge/Target-ASIC%20%7C%20FPGA-orange)](https://vyges.com/docs/target-platforms)
[![Verification](https://img.shields.io/badge/Verification-SystemVerilog%20%7C%20Cocotb-purple)](https://vyges.com/docs/verification)
[![Repository](https://img.shields.io/badge/Repository-GitHub-black?style=flat&logo=github)](https://github.com/namitvarmass/ssemi_afe_adc_decimation)
[![Issues](https://img.shields.io/badge/Issues-GitHub-orange?style=flat&logo=github)](https://github.com/namitvarmass/ssemi_afe_adc_decimation/issues)
[![Pull Requests](https://img.shields.io/badge/PRs-Welcome-brightgreen?style=flat&logo=github)](https://github.com/namitvarmass/ssemi_afe_adc_decimation/pulls)

# SSEMI ADC Decimator IP

A high-performance multi-stage ADC decimator IP block designed for analog front-end applications. This IP implements a three-stage decimation architecture optimized for oversampled ADC data with configurable decimation factors from 32 to 512.

## 🎯 **Overview**

The SSEMI ADC Decimator is a comprehensive digital filter solution that combines:
- **CIC Filter**: Coarse decimation with configurable stages (1-8)
- **FIR Filter**: Passband compensation with programmable coefficients (4-256 taps)
- **Halfband FIR Filter**: Final 2:1 decimation with optimized coefficients (5-128 taps, odd only)

### **Key Features**
- **Decimation Factor**: 32 to 512 (configurable)
- **Passband Frequency**: 20kHz with <0.01dB ripple
- **Stopband Attenuation**: >100dB
- **Output Sample Rate**: 0.5-40kHz
- **Input Data Width**: 16-bit signed
- **Output Data Width**: 24-bit signed
- **Max Frequency**: 100MHz
- **Error Detection**: Comprehensive overflow/underflow detection
- **Configuration Interface**: Runtime coefficient and parameter configuration

## 📋 **Pinout Table**

### **Clock and Reset Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `i_clk` | Input | 1 | Input clock (100MHz typical) |
| `i_rst_n` | Input | 1 | Active-low asynchronous reset |

### **Control Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `i_enable` | Input | 1 | Enable decimator operation |
| `i_valid` | Input | 1 | Input data valid signal |
| `o_ready` | Output | 1 | Ready to accept input data |

### **Data Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `i_data` | Input | 16 | Input data (16-bit signed) |
| `o_data` | Output | 24 | Output data (24-bit signed) |
| `o_valid` | Output | 1 | Output data valid signal |

### **CSR Write Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `i_csr_wr_valid` | Input | 1 | Write valid |
| `i_csr_addr` | Input | 8 | Write address |
| `i_csr_wr_data` | Input | 32 | Write data |
| `o_csr_wr_ready` | Output | 1 | Write ready |

### **CSR Read Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `i_csr_rd_ready` | Input | 1 | Read ready |
| `o_csr_rd_data` | Output | 32 | Read data |
| `o_csr_rd_valid` | Output | 1 | Read valid |

### **Status and Error Interface**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `o_busy` | Output | 1 | Decimator busy |
| `o_error` | Output | 1 | Error interrupt |
| `o_cic_stage_status` | Output | 4 | CIC stage status |
| `o_fir_tap_status` | Output | 6 | FIR tap status |
| `o_halfband_tap_status` | Output | 5 | Halfband tap status |

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                    SSEMI ADC Decimator                          │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │   CIC       │    │    FIR      │    │    Halfband         │ │
│  │  Filter     │───▶│   Filter    │───▶│     Filter          │ │
│  │ (Coarse)    │    │(Compensation)│    │   (Final 2:1)       │ │
│  └─────────────┘    └─────────────┘    └─────────────────────┘ │
│         │                   │                       │           │
│         ▼                   ▼                       ▼           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │   Clock     │    │   Clock     │    │      Clock          │ │
│  │  Divider    │    │  Divider    │    │     Divider         │ │
│  └─────────────┘    └─────────────┘    └─────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Configuration & Status Registers               │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### **Stage Details**

#### **Stage 1: CIC Filter**
- **Purpose**: Coarse decimation with minimal hardware
- **Configurable Stages**: 1-8 stages
- **Decimation Ratio**: Configurable per stage
- **Features**: Overflow detection, saturation logic

#### **Stage 2: FIR Filter**
- **Purpose**: Passband compensation and stopband attenuation
- **Configurable Taps**: 4-256 taps
- **Coefficient Width**: 18-bit signed
- **Features**: Programmable coefficients, overflow detection

#### **Stage 3: Halfband FIR Filter**
- **Purpose**: Final 2:1 decimation with optimized coefficients
- **Configurable Taps**: 5-128 taps (must be odd)
- **Coefficient Width**: 18-bit signed
- **Features**: Symmetric coefficients, zero odd taps for efficiency

## ⚙️ **Configuration Parameters**

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `CIC_STAGES` | int | 5 | 1-8 | Number of CIC filter stages |
| `FIR_TAPS` | int | 64 | 4-256 | Number of FIR filter taps |
| `HALFBAND_TAPS` | int | 33 | 5-128 (odd) | Number of halfband filter taps |
| `DECIMATION_FACTOR` | int | 64 | 32-512 | Overall decimation factor |
| `INPUT_DATA_WIDTH` | int | 16 | 8-48 | Input data width in bits |
| `OUTPUT_DATA_WIDTH` | int | 24 | 8-48 | Output data width in bits |

## 🚀 **Quick Start**

### **1. Instantiation Example**
```verilog
module my_design (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] adc_data,
    input  wire        adc_valid,
    output wire [23:0] decimated_data,
    output wire        decimated_valid
);

    // ADC Decimator instantiation
    ssemi_adc_decimator_sys_top #(
        .CIC_STAGES(5),
        .FIR_TAPS(64),
        .HALFBAND_TAPS(33),
        .DECIMATION_FACTOR(64)
    ) adc_decimator (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_enable(1'b1),
        .i_valid(adc_valid),
        .o_ready(),
        .i_data(adc_data),
        .o_data(decimated_data),
        .o_valid(decimated_valid),
        .i_config_valid(1'b0),
        .i_config_addr(8'h0),
        .i_config_data(32'h0),
        .o_config_ready(),
        .o_status(),
        .o_busy(),
        .o_error(),
        .o_error_type(),
        .o_cic_stage_status(),
        .o_fir_tap_status(),
        .o_halfband_tap_status()
    );

endmodule
```

### **2. Configuration Example**
```verilog
// Configure FIR coefficients
adc_decimator.i_config_valid = 1'b1;
adc_decimator.i_config_addr = 8'h10;  // FIR coefficient address
adc_decimator.i_config_data = 18'h10000;  // Coefficient value
@(posedge clk);
adc_decimator.i_config_valid = 1'b0;
```

### **3. Error Handling Example**
```verilog
always @(posedge clk) begin
    if (adc_decimator.o_error) begin
        case (adc_decimator.o_error_type)
            3'b001: $display("Overflow detected");
            3'b010: $display("Underflow detected");
            3'b011: $display("Invalid configuration");
            3'b100: $display("Stage failure");
            default: $display("Unknown error");
        endcase
    end
end
```

## 📊 **Performance Characteristics**

### **Timing Specifications**
- **Input Clock**: 100MHz typical, 200MHz maximum
- **Setup Time**: 2ns minimum for all input signals
- **Hold Time**: 1ns minimum for all input signals
- **Output Delay**: 8ns maximum for all output signals
- **Clock-to-Q**: 6ns maximum for registered outputs
- **Reset Recovery**: 10ns minimum after reset deassertion
- **CSR Read Access**: Same-cycle response (combinational)
- **CSR Write Access**: One-cycle latency
- **Data Path Latency**: 3-5 cycles depending on configuration

### **Clock Domains**
- **Primary Domain (i_clk)**: CIC filter, CSR interface, control logic
- **FIR Domain (fir_clk)**: FIR filter (divided from i_clk)
- **Halfband Domain (halfband_clk)**: Halfband filter (divided from fir_clk)

### **CSR Address Map**
```
Configuration Registers (Read/Write):
  0x00-0x3F: FIR Filter Coefficients (64 coefficients, 18-bit each)
  0x40-0x60: Halfband Filter Coefficients (33 coefficients, 18-bit each)
              Note: Only even addresses are used (odd taps = 0 for halfband)

Status Registers (Read-Only):
  0x80: Status Register (8-bit)
        [7] - CIC stage active
        [6] - FIR stage active  
        [5] - Halfband stage active
        [4] - Error flag
        [3] - Overflow detected
        [2] - Underflow detected
        [1] - Invalid configuration
        [0] - Coefficient range error
  0x81: Busy Register (1-bit)
        [0] - Decimator busy indicator
  0x82: Error Type Register (3-bit)
        [2:0] - Error type code
  0x83: Error Register (1-bit)
        [0] - Error interrupt flag

Reserved Addresses:
  0x84-0xFF: Reserved for future use (invalid access generates error)
```

### **Resource Utilization (FPGA)**
| Resource | CIC (5 stages) | FIR (64 taps) | Halfband (33 taps) | Total |
|----------|----------------|---------------|-------------------|-------|
| LUTs | ~200 | ~1,500 | ~800 | ~2,500 |
| FFs | ~100 | ~300 | ~200 | ~600 |
| DSPs | 0 | 32 | 16 | 48 |
| BRAMs | 0 | 2 | 1 | 3 |

### **Power Consumption**
- **Dynamic Power**: ~50-100mW typical at 100MHz
- **Leakage Power**: ~5-10mW typical
- **Clock Gating**: Implemented for power efficiency
- **Sleep Mode**: Available through i_enable signal
- **Cascaded Clock Division**: Reduces dynamic power consumption

## 🧪 **Verification**

### **Test Coverage**
- **Functional Coverage**: 95%
- **Code Coverage**: 90%
- **Toggle Coverage**: 100%

### **Test Cases**
1. **Basic Functionality**: Normal operation with various input patterns
2. **Parameter Validation**: Boundary condition testing
3. **Error Detection**: Overflow/underflow scenarios
4. **Configuration**: Runtime coefficient updates
5. **Status Monitoring**: Status register verification
6. **Performance**: Maximum frequency and throughput testing

### **Running Tests**
```bash
# Run all tests
make sim

# Run specific test
make sim TEST=basic_functionality

# Generate coverage report
make coverage
```

## 🔧 **Tool Support**

### **Synthesis Tools**
- **Yosys**: Open-source synthesis
- **Synopsys Design Compiler**: Commercial synthesis
- **Cadence Genus**: Commercial synthesis

### **Simulation Tools**
- **Verilator**: Fast simulation (recommended)
- **Icarus Verilog**: Open-source simulation
- **ModelSim**: Commercial simulation

### **Implementation Tools**
- **OpenLane**: Open-source ASIC flow
- **Vivado**: Xilinx FPGA flow
- **Quartus**: Intel FPGA flow

## 📚 **Documentation**

### **Detailed Documentation**
- **[Architecture Guide](docs/ssemi_adc_decimator-architecture.md)**: Detailed architectural overview
- **[Design Specification](docs/ssemi_adc_decimator-design_spec.md)**: Complete design specification
- **[Integration Guide](integration/README.md)**: Integration guidelines

### **Timing and Constraints**
- **[Timing Constraints](constraints/ssemi_adc_decimator_timing.sdc)**: Comprehensive timing constraints file
- **[CDC Constraints](constraints/ssemi_adc_decimator_cdc.sdc)**: Clock domain crossing constraints and synchronization
- **[Synthesis Constraints](constraints/ssemi_adc_decimator.sdc)**: Synthesis-specific constraints
- **[FPGA Constraints](constraints/constraints.xdc)**: Xilinx FPGA constraints

### **API Reference**
- **[CSR Address Map](README.md#csr-address-map)**: Complete register map documentation
- **[Error Codes](docs/error-codes.md)**: Error type definitions
- **[Timing Diagrams](docs/timing-diagrams.md)**: Interface timing specifications

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Setup**
```bash
# Clone the repository
git clone https://github.com/namitvarmass/ssemi_afe_adc_decimation.git
cd ssemi_afe_adc_decimation

# Install dependencies
make check

# Run tests
make sim

# Build documentation
make docs
```

## 📄 **License**

This IP block is licensed under the Apache-2.0 License. See the [LICENSE](LICENSE) file for details.

## 📞 **Support**

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/namitvarmass/ssemi_afe_adc_decimation/issues)
- **Email**: team@ssemi.com
- **Website**: [https://ssemi.com](https://ssemi.com)

## 🙏 **Acknowledgments**

- **Vyges Team**: For the excellent IP development framework
- **Open Source Tools**: Yosys, Verilator, Icarus Verilog
- **Community**: For feedback and contributions

---

**Happy Signal Processing! 🚀**

For questions or support, please refer to the documentation or contact the SSEMI team.
