//==============================================================================
// File Name: ssemi_adc_decimator_sys_top_wrapper.v
//==============================================================================
// Description: Integration wrapper module for ssemi_adc_decimator_sys_top
//              Provides standardized interface for system integration
//              with configurable parameters and proper signal mapping
//
// Features:
//   - Standardized interface for system integration
//   - Configurable parameters with default values
//   - Proper signal mapping and direction conversion
//   - Timing constraints: 100MHz max clock frequency
//   - Coefficient validation: 18-bit signed coefficients
//
// Author: Vyges AI Assistant
// Date: 2025-08-30T18:32:01Z
// Version: 1.0
//==============================================================================

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module ssemi_adc_decimator_sys_top_wrapper #(
    parameter CIC_STAGES = SSEMI_ADC_DECIMATOR_CIC_STAGES,           // Number of CIC stages (1-8)
parameter FIR_TAPS = SSEMI_ADC_DECIMATOR_FIR_TAPS,               // Number of FIR filter taps (4-256)
parameter HALFBAND_TAPS = SSEMI_ADC_DECIMATOR_HALFBAND_TAPS,     // Number of halfband filter taps (5-128, odd)
parameter DECIMATION_FACTOR = SSEMI_ADC_DECIMATOR_DEFAULT_DECIMATION_FACTOR, // Overall decimation factor (32-512)
parameter DATA_WIDTH = SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH,           // Input data width (16-32 bits)
parameter COEFF_WIDTH = SSEMI_ADC_DECIMATOR_FIR_COEFF_WIDTH          // Coefficient width (16-24 bits)
) (
    // Clock and Reset
    input wire i_clk,                                  // System clock (max 100MHz)
    input wire i_rst_n,                                // Active-low reset
    
    // ADC Input Interface
    input wire i_adc_valid,                            // ADC data valid
    input wire [DATA_WIDTH-1:0] i_adc_data,           // ADC input data
    output wire o_adc_ready,                           // Ready to accept ADC data
    
    // Decimated Output Interface
    output wire o_decim_valid,                         // Decimated data valid
    output wire [DATA_WIDTH-1:0] o_decim_data,        // Decimated output data
    input wire i_decim_ready,                          // Downstream ready
    
    // CSR Write Interface
    input wire i_csr_wr_valid,                         // CSR write valid
    input wire [7:0] i_csr_addr,                       // CSR address (shared)
    input wire [31:0] i_csr_wr_data,                   // CSR write data
    output wire o_csr_wr_ready,                        // CSR write ready
    
    // CSR Read Interface
    input wire i_csr_rd_ready,                         // CSR read ready
    output wire [31:0] o_csr_rd_data,                  // CSR read data (same-cycle valid)
    
    // Error Interrupt
    output wire o_error                                 // Error interrupt (active high)
);

//==============================================================================
// Internal Coefficient Signals
//==============================================================================

// FIR coefficient array
wire [COEFF_WIDTH-1:0] fir_coeff [0:FIR_TAPS-1];

// Halfband coefficient array
wire [COEFF_WIDTH-1:0] halfband_coeff [0:HALFBAND_TAPS-1];

//==============================================================================
// Top-Level Module Instance
//==============================================================================

ssemi_adc_decimator_sys_top #(
    .CIC_STAGES(CIC_STAGES),
    .FIR_TAPS(FIR_TAPS),
    .HALFBAND_TAPS(HALFBAND_TAPS),
    .DECIMATION_FACTOR(DECIMATION_FACTOR),
    .DATA_WIDTH(DATA_WIDTH),
    .COEFF_WIDTH(COEFF_WIDTH)
) u_ssemi_adc_decimator_sys_top (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    
    // ADC Input Interface
    .i_adc_valid(i_adc_valid),
    .i_adc_data(i_adc_data),
    .o_adc_ready(o_adc_ready),
    
    // Decimated Output Interface
    .o_decim_valid(o_decim_valid),
    .o_decim_data(o_decim_data),
    .i_decim_ready(i_decim_ready),
    
    // CSR Write Interface
    .i_csr_wr_valid(i_csr_wr_valid),
    .i_csr_addr(i_csr_addr),
    .i_csr_wr_data(i_csr_wr_data),
    .o_csr_wr_ready(o_csr_wr_ready),
    
    // CSR Read Interface
    .i_csr_rd_ready(i_csr_rd_ready),
    .o_csr_rd_data(o_csr_rd_data),
    
    // Coefficient Outputs (internal)
    .o_fir_coeff(fir_coeff),
    .o_halfband_coeff(halfband_coeff),
    
    // Error Interrupt
    .o_error(o_error)
);

endmodule
