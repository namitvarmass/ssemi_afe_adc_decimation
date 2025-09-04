`ifndef SSEMI_ADC_DECIMATOR_SYS_TOP_V
`define SSEMI_ADC_DECIMATOR_SYS_TOP_V

//==============================================================================
// Module Name: ssemi_adc_decimator_sys_top
//==============================================================================
// Description: Top-level ADC decimator system with configurable CIC, FIR, and 
//              halfband filters. Implements a three-stage decimation pipeline
//              with comprehensive error detection and CSR interface.
//
// Architecture:
//   - Stage 1: CIC Filter (configurable stages, decimation)
//   - Stage 2: FIR Filter (frequency shaping, compensation)
//   - Stage 3: Halfband Filter (2:1 decimation, final shaping)
//   - CSR Interface: Configuration and status registers
//   - Clock Division: Cascaded clock division for power optimization
//
// Clock Domain Crossing (CDC):
//   - i_clk: Main system clock domain (CSR interface, CIC filter)
//   - fir_clk: FIR filter clock domain (i_clk / DECIMATION_FACTOR)
//   - halfband_clk: Halfband filter clock domain (fir_clk / 2)
//   - CDC paths: CIC->FIR, FIR->Halfband, Status signals to CSR
//   - All CDC paths require proper synchronization in RTL implementation
//
// Features:
//   - Configurable decimation factor (32-512)
//   - Comprehensive error detection and reporting
//   - Same-cycle CSR read access
//   - Overflow/underflow protection with saturation
//   - Parameter validation with detailed error messages
//   - Timing constraints: 100MHz max clock frequency
//   - Coefficient validation: 18-bit signed coefficients
//
// Author: Vyges AI Assistant
// Date: 2025-08-30T18:32:01Z
// Version: 1.0
//==============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_adc_decimator_sys_top #(
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
    
    // Coefficient Outputs (direct to filters)
    output wire [COEFF_WIDTH-1:0] o_fir_coeff [0:FIR_TAPS-1],      // FIR coefficients
    output wire [COEFF_WIDTH-1:0] o_halfband_coeff [0:HALFBAND_TAPS-1], // Halfband coefficients
    
    // Error Interrupt
    output wire o_error                                 // Error interrupt (active high)
);

//==============================================================================
// Parameter Validation
//==============================================================================
`ifdef SSEMI_ADC_DECIMATOR_VERIFICATION
    initial begin
        if (CIC_STAGES < 1 || CIC_STAGES > 8) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: CIC_STAGES must be between 1 and 8, got %d", CIC_STAGES);
        end
        
        if (FIR_TAPS < 4 || FIR_TAPS > 256) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: FIR_TAPS must be between 4 and 256, got %d", FIR_TAPS);
        end
        
        if (HALFBAND_TAPS < 5 || HALFBAND_TAPS > 128) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS must be between 5 and 128, got %d", HALFBAND_TAPS);
        end
        
        if (HALFBAND_TAPS % 2 == 0) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS must be odd, got %d", HALFBAND_TAPS);
        end
        
        if (DECIMATION_FACTOR < 32 || DECIMATION_FACTOR > 512) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: DECIMATION_FACTOR must be between %d and %d, got %d",
                   SSEMI_ADC_DECIMATOR_MIN_DECIMATION_FACTOR, SSEMI_ADC_DECIMATOR_MAX_DECIMATION_FACTOR, DECIMATION_FACTOR);
        end
        
        // Parameter consistency warnings
        if (CIC_STAGES != SSEMI_ADC_DECIMATOR_CIC_STAGES) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: CIC_STAGES parameter (%d) differs from define (%d)",
                     CIC_STAGES, SSEMI_ADC_DECIMATOR_CIC_STAGES);
        end
        
        if (FIR_TAPS != SSEMI_ADC_DECIMATOR_FIR_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: FIR_TAPS parameter (%d) differs from define (%d)",
                     FIR_TAPS, SSEMI_ADC_DECIMATOR_FIR_TAPS);
        end
        
        if (HALFBAND_TAPS != SSEMI_ADC_DECIMATOR_HALFBAND_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS parameter (%d) differs from define (%d)",
                     HALFBAND_TAPS, SSEMI_ADC_DECIMATOR_HALFBAND_TAPS);
        end
    end
`endif

//==============================================================================
// Internal Signals
//==============================================================================

// Clock division signals
wire cic_clk;                                          // CIC filter clock (same as i_clk)
wire fir_clk;                                          // FIR filter clock (divided)
wire halfband_clk;                                     // Halfband filter clock (divided)

// CIC filter signals
wire cic_valid;                                        // CIC output valid
wire [DATA_WIDTH-1:0] cic_data;                       // CIC output data
wire cic_ready;                                        // CIC output ready
wire cic_overflow;                                     // CIC overflow flag
wire cic_underflow;                                    // CIC underflow flag

// FIR filter signals
wire fir_valid;                                        // FIR output valid
wire [DATA_WIDTH-1:0] fir_data;                       // FIR output data
wire fir_ready;                                        // FIR output ready
wire fir_overflow;                                     // FIR overflow flag
wire fir_underflow;                                    // FIR underflow flag

// Halfband filter signals
wire halfband_valid;                                   // Halfband output valid
wire [DATA_WIDTH-1:0] halfband_data;                  // Halfband output data
wire halfband_ready;                                   // Halfband output ready
wire halfband_overflow;                                // Halfband overflow flag
wire halfband_underflow;                               // Halfband underflow flag

//==============================================================================
// Clock Division
//==============================================================================

// CIC filter uses system clock directly
assign cic_clk = i_clk;

// FIR filter clock divider (divide by DECIMATION_FACTOR)
ssemi_clock_divider #(
    .CLK_DIV_RATIO(DECIMATION_FACTOR)
) u_fir_clock_div (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_clk_div(fir_clk)
);

// Halfband filter clock divider (divide by 2 from FIR clock)
ssemi_clock_divider #(
    .CLK_DIV_RATIO(2)
) u_halfband_clock_div (
    .i_clk(fir_clk),
    .i_rst_n(i_rst_n),
    .o_clk_div(halfband_clk)
);

//==============================================================================
// Filter Pipeline
//==============================================================================

// CIC Filter (Stage 1)
ssemi_cic_filter #(
    .NUM_STAGES(CIC_STAGES),
    .DECIMATION_FACTOR(DECIMATION_FACTOR),
    .DATA_WIDTH(DATA_WIDTH)
) u_cic_filter (
    .i_clk(cic_clk),
    .i_rst_n(i_rst_n),
    .i_valid(i_adc_valid),
    .i_data(i_adc_data),
    .o_ready(o_adc_ready),
    .o_valid(cic_valid),
    .o_data(cic_data),
    .i_ready(cic_ready),
    .o_overflow(cic_overflow),
    .o_underflow(cic_underflow)
);

// FIR Filter (Stage 2)
ssemi_fir_filter #(
    .NUM_TAPS(FIR_TAPS),
    .DATA_WIDTH(DATA_WIDTH),
    .COEFF_WIDTH(COEFF_WIDTH)
) u_fir_filter (
    .i_clk(fir_clk),
    .i_rst_n(i_rst_n),
    .i_valid(cic_valid),
    .i_data(cic_data),
    .o_ready(cic_ready),
    .o_valid(fir_valid),
    .o_data(fir_data),
    .i_ready(fir_ready),
    .i_coeff(o_fir_coeff),
    .o_overflow(fir_overflow),
    .o_underflow(fir_underflow)
);

// Halfband Filter (Stage 3)
ssemi_halfband_filter #(
    .NUM_TAPS(HALFBAND_TAPS),
    .DATA_WIDTH(DATA_WIDTH),
    .COEFF_WIDTH(COEFF_WIDTH)
) u_halfband_filter (
    .i_clk(halfband_clk),
    .i_rst_n(i_rst_n),
    .i_valid(fir_valid),
    .i_data(fir_data),
    .o_ready(fir_ready),
    .o_valid(halfband_valid),
    .o_data(halfband_data),
    .i_ready(halfband_ready),
    .i_coeff(o_halfband_coeff),
    .o_overflow(halfband_overflow),
    .o_underflow(halfband_underflow)
);

//==============================================================================
// Output Assignment
//==============================================================================

assign o_decim_valid = halfband_valid;
assign o_decim_data = halfband_data;
assign halfband_ready = i_decim_ready;

//==============================================================================
// Configuration and Status Registers
//==============================================================================

ssemi_config_status_regs #(
    .FIR_TAPS(FIR_TAPS),
    .HALFBAND_TAPS(HALFBAND_TAPS),
    .COEFF_WIDTH(COEFF_WIDTH)
) u_config_status_regs (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    
    // CSR Write Interface
    .i_csr_wr_valid(i_csr_wr_valid),
    .i_csr_addr(i_csr_addr),
    .i_csr_wr_data(i_csr_wr_data),
    .o_csr_wr_ready(o_csr_wr_ready),
    
    // CSR Read Interface
    .i_csr_rd_ready(i_csr_rd_ready),
    .o_csr_rd_data(o_csr_rd_data),
    
    // Coefficient Outputs
    .o_fir_coeff(o_fir_coeff),
    .o_halfband_coeff(o_halfband_coeff),
    
    // Error Inputs
    .i_cic_overflow(cic_overflow),
    .i_cic_underflow(cic_underflow),
    .i_fir_overflow(fir_overflow),
    .i_fir_underflow(fir_underflow),
    .i_halfband_overflow(halfband_overflow),
    .i_halfband_underflow(halfband_underflow),
    
    // Error Output
    .o_error(o_error)
);

endmodule

`endif // SSEMI_ADC_DECIMATOR_SYS_TOP_V
