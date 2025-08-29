//=============================================================================
// Integration Wrapper for SSEMI ADC Decimator
//=============================================================================
// Description: Integration wrapper module for ssemi_adc_decimator_top
//              Provides consistent interface naming and parameter passing
//              for easy integration into larger designs
// Author:      SSEMI Development Team
// Date:        2025-08-28T14:30:00Z
// License:     Apache-2.0
//=============================================================================

module ssemi_adc_decimator_top_wrapper #(
    parameter CIC_STAGES = 5,              // Number of CIC filter stages
    parameter FIR_TAPS = 64,               // Number of FIR filter taps
    parameter HALFBAND_TAPS = 33,          // Number of halfband filter taps
    parameter DECIMATION_FACTOR = 64       // Overall decimation factor
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  wire i_clk,                     // Input clock (100MHz typical)
    input  wire i_rst_n,                   // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  wire i_enable,                  // Enable decimator operation
    input  wire i_valid,                   // Input data valid signal
    output wire o_ready,                   // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  wire [15:0] i_data,             // Input data (16-bit signed)
    output wire [23:0] o_data,             // Output data (24-bit signed)
    output wire o_valid,                   // Output data valid signal
    
    //==============================================================================
    // Configuration Interface
    //==============================================================================
    input  wire i_config_valid,            // Configuration data valid
    input  wire [7:0] i_config_addr,       // Configuration address
    input  wire [31:0] i_config_data,      // Configuration data
    output wire o_config_ready,            // Configuration ready
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output wire [7:0] o_status,            // Status information
    output wire o_busy,                    // Decimator busy
    output wire o_error,                   // Error flag
    output wire [2:0] o_error_type,        // Specific error type
    output wire [3:0] o_cic_stage_status,  // CIC stage status
    output wire [5:0] o_fir_tap_status,    // FIR tap status
    output wire [4:0] o_halfband_tap_status // Halfband tap status
);

    //==============================================================================
    // Instance of the SSEMI ADC Decimator Top Module
    //==============================================================================
    
    ssemi_adc_decimator_top #(
        .CIC_STAGES(CIC_STAGES),
        .FIR_TAPS(FIR_TAPS),
        .HALFBAND_TAPS(HALFBAND_TAPS),
        .DECIMATION_FACTOR(DECIMATION_FACTOR)
    ) u_ssemi_adc_decimator_top (
        // Clock and Reset
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        
        // Control Interface
        .i_enable(i_enable),
        .i_valid(i_valid),
        .o_ready(o_ready),
        
        // Data Interface
        .i_data(i_data),
        .o_data(o_data),
        .o_valid(o_valid),
        
        // Configuration Interface
        .i_config_valid(i_config_valid),
        .i_config_addr(i_config_addr),
        .i_config_data(i_config_data),
        .o_config_ready(o_config_ready),
        
        // Status and Error Interface
        .o_status(o_status),
        .o_busy(o_busy),
        .o_error(o_error),
        .o_error_type(o_error_type),
        .o_cic_stage_status(o_cic_stage_status),
        .o_fir_tap_status(o_fir_tap_status),
        .o_halfband_tap_status(o_halfband_tap_status)
    );

    //==============================================================================
    // Integration Notes
    //==============================================================================
    //
    // This wrapper provides:
    // 1. Consistent interface naming (_i for inputs, _o for outputs)
    // 2. Parameter passing to the underlying ADC decimator module
    // 3. Easy integration into larger designs
    // 4. Consistent reset and clock handling
    // 5. Multi-stage decimation interface (CIC + FIR + Halfband)
    // 6. Configuration and status interfaces
    // 7. Comprehensive error detection and reporting
    //
    // ADC Decimator Features:
    // - Three-stage architecture: CIC → FIR → Halfband
    // - Configurable decimation factors (32 to 512)
    // - 20kHz passband with <0.01dB ripple
    // - >100dB stopband attenuation
    // - Runtime coefficient configuration
    // - Overflow/underflow detection
    // - Comprehensive status monitoring
    //
    // Integration Guidelines:
    // - Clock: 100MHz typical, single clock domain design
    // - Reset: Active-low asynchronous reset
    // - Data: 16-bit input, 24-bit output (signed)
    // - Configuration: 8-bit address, 32-bit data
    // - Status: 8-bit status, 3-bit error type
    // - Handshaking: Valid/ready protocol for data transfer
    // - Power: Low-power design with clock gating support
    //
    // Usage Examples:
    // - Analog front-end applications
    // - High-performance data acquisition systems
    // - Oversampled ADC data processing
    // - Multi-rate signal processing
    // - Real-time filtering applications
    //
    //=============================================================================

endmodule
