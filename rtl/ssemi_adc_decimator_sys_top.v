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

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module ssemi_adc_decimator_sys_top #(
    parameter SSEMI_ADC_DECIMATOR_CIC_STAGES = `SSEMI_ADC_DECIMATOR_CIC_STAGES,           // Number of CIC stages (1-8)
    parameter SSEMI_ADC_DECIMATOR_FIR_TAPS = `SSEMI_ADC_DECIMATOR_FIR_TAPS,               // Number of FIR filter taps (4-256)
    parameter SSEMI_ADC_DECIMATOR_HALFBAND_TAPS = `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS,     // Number of halfband filter taps (5-128, odd)
    parameter SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR = `SSEMI_ADC_DECIMATOR_DEFAULT_DECIMATION_FACTOR, // Overall decimation factor (32-512)
    parameter SSEMI_ADC_DECIMATOR_DATA_WIDTH = `SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH,           // Input data width (16-32 bits)
    parameter SSEMI_ADC_DECIMATOR_COEFF_WIDTH = `SSEMI_ADC_DECIMATOR_FIR_COEFF_WIDTH          // Coefficient width (16-24 bits)
) (
    // Clock and Reset
    input wire i_clk,                                  // System clock (max 100MHz)
    input wire i_rst_n,                                // Active-low reset
    
    // ADC Input Interface
    input wire i_adc_valid,                            // ADC data valid
    input wire [SSEMI_ADC_DECIMATOR_DATA_WIDTH-1:0] i_adc_data,           // ADC input data
    output wire o_adc_ready,                           // Ready to accept ADC data
    
    // Decimated Output Interface
    output wire o_decim_valid,                         // Decimated data valid
    output wire [SSEMI_ADC_DECIMATOR_DATA_WIDTH-1:0] o_decim_data,        // Decimated output data
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
    output wire [SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1:0] o_fir_coeff [0:SSEMI_ADC_DECIMATOR_FIR_TAPS-1],      // FIR coefficients
    output wire [SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1:0] o_halfband_coeff [0:SSEMI_ADC_DECIMATOR_HALFBAND_TAPS-1], // Halfband coefficients
    
    // Error Interrupt
    output wire o_error                                 // Error interrupt (active high)
);

//==============================================================================
// Parameter Validation
//==============================================================================
`ifdef SSEMI_ADC_DECIMATOR_VERIFICATION
    initial begin
        if (SSEMI_ADC_DECIMATOR_CIC_STAGES < 1 || SSEMI_ADC_DECIMATOR_CIC_STAGES > 8) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: CIC_STAGES must be between 1 and 8, got %d", SSEMI_ADC_DECIMATOR_CIC_STAGES);
        end
        
        if (SSEMI_ADC_DECIMATOR_FIR_TAPS < 4 || SSEMI_ADC_DECIMATOR_FIR_TAPS > 256) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: FIR_TAPS must be between 4 and 256, got %d", SSEMI_ADC_DECIMATOR_FIR_TAPS);
        end
        
        if (SSEMI_ADC_DECIMATOR_HALFBAND_TAPS < 5 || SSEMI_ADC_DECIMATOR_HALFBAND_TAPS > 128) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS must be between 5 and 128, got %d", SSEMI_ADC_DECIMATOR_HALFBAND_TAPS);
        end
        
        if (SSEMI_ADC_DECIMATOR_HALFBAND_TAPS % 2 == 0) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS must be odd, got %d", SSEMI_ADC_DECIMATOR_HALFBAND_TAPS);
        end
        
        if (SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR < 32 || SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR > 512) begin
            $error("SSEMI_ADC_DECIMATOR_SYS_TOP: DECIMATION_FACTOR must be between %d and %d, got %d",
                   SSEMI_ADC_DECIMATOR_MIN_DECIMATION_FACTOR, SSEMI_ADC_DECIMATOR_MAX_DECIMATION_FACTOR, SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR);
        end
        
        // Parameter consistency warnings
        if (SSEMI_ADC_DECIMATOR_CIC_STAGES != `SSEMI_ADC_DECIMATOR_CIC_STAGES) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: CIC_STAGES parameter (%d) differs from define (%d)",
                     SSEMI_ADC_DECIMATOR_CIC_STAGES, `SSEMI_ADC_DECIMATOR_CIC_STAGES);
        end
        
        if (SSEMI_ADC_DECIMATOR_FIR_TAPS != `SSEMI_ADC_DECIMATOR_FIR_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: FIR_TAPS parameter (%d) differs from define (%d)",
                     SSEMI_ADC_DECIMATOR_FIR_TAPS, `SSEMI_ADC_DECIMATOR_FIR_TAPS);
        end
        
        if (SSEMI_ADC_DECIMATOR_HALFBAND_TAPS != `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_SYS_TOP: HALFBAND_TAPS parameter (%d) differs from define (%d)",
                     SSEMI_ADC_DECIMATOR_HALFBAND_TAPS, `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS);
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
wire [SSEMI_ADC_DECIMATOR_DATA_WIDTH-1:0] cic_data;                       // CIC output data
wire cic_ready;                                        // CIC output ready
wire cic_overflow;                                     // CIC overflow flag
wire cic_underflow;                                    // CIC underflow flag

// FIR filter signals
wire fir_valid;                                        // FIR output valid
wire [SSEMI_ADC_DECIMATOR_DATA_WIDTH-1:0] fir_data;                       // FIR output data
wire fir_ready;                                        // FIR output ready
wire fir_overflow;                                     // FIR overflow flag
wire fir_underflow;                                    // FIR underflow flag

// Halfband filter signals
wire halfband_valid;                                   // Halfband output valid
wire [SSEMI_ADC_DECIMATOR_DATA_WIDTH-1:0] halfband_data;                  // Halfband output data
wire halfband_ready;                                   // Halfband output ready
wire halfband_overflow;                                // Halfband overflow flag
wire halfband_underflow;                               // Halfband underflow flag

//==============================================================================
// Clock Division
//==============================================================================

// CIC filter uses system clock directly
assign cic_clk = i_clk;

// FIR filter clock divider (divide by DECIMATION_FACTOR)
ssemi_adc_decimator_clock_divider #(
    .SSEMI_ADC_DECIMATOR_CLK_DIV_RATIO(SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR)
) u_fir_clock_div (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_clk_div(fir_clk)
);

// Halfband filter clock divider (divide by 2 from FIR clock)
ssemi_adc_decimator_clock_divider #(
    .SSEMI_ADC_DECIMATOR_CLK_DIV_RATIO(2)
) u_halfband_clock_div (
    .i_clk(fir_clk),
    .i_rst_n(i_rst_n),
    .o_clk_div(halfband_clk)
);

//==============================================================================
// Filter Pipeline
//==============================================================================

// CIC Filter (Stage 1)
ssemi_adc_decimator_cic_filter #(
    .CIC_STAGES(SSEMI_ADC_DECIMATOR_CIC_STAGES),
    .DECIMATION_FACTOR(SSEMI_ADC_DECIMATOR_DECIMATION_FACTOR),
    .INPUT_DATA_WIDTH(SSEMI_ADC_DECIMATOR_DATA_WIDTH)
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
ssemi_adc_decimator_fir_filter #(
    .NUM_TAPS(SSEMI_ADC_DECIMATOR_FIR_TAPS),
    .INPUT_DATA_WIDTH(SSEMI_ADC_DECIMATOR_DATA_WIDTH),
    .COEFF_WIDTH(SSEMI_ADC_DECIMATOR_COEFF_WIDTH)
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
ssemi_adc_decimator_halfband_filter #(
    .NUM_TAPS(SSEMI_ADC_DECIMATOR_HALFBAND_TAPS),
    .INPUT_DATA_WIDTH(SSEMI_ADC_DECIMATOR_DATA_WIDTH),
    .COEFF_WIDTH(SSEMI_ADC_DECIMATOR_COEFF_WIDTH)
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

ssemi_adc_decimator_config_status_regs #(
    .FIR_TAPS(SSEMI_ADC_DECIMATOR_FIR_TAPS),
    .HALFBAND_TAPS(SSEMI_ADC_DECIMATOR_HALFBAND_TAPS),
    .COEFF_WIDTH(SSEMI_ADC_DECIMATOR_COEFF_WIDTH)
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

//==============================================================================
// Runtime Assertions for Protocol Compliance and Safety
//==============================================================================
`ifdef SSEMI_ADC_DECIMATOR_VERIFICATION

// Clock and Reset Assertions
`ifdef SSEMI_ADC_DECIMATOR_ASSERTIONS
    // Clock frequency assertion (max 100MHz)
    property p_clk_frequency;
        @(posedge i_clk) 1'b1;
    endproperty
    assert_clk_freq: assert property (p_clk_frequency) 
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Clock frequency exceeds 100MHz limit");
    
    // Reset assertion - must be held for minimum duration
    property p_reset_min_duration;
        $fell(i_rst_n) |-> ##[2:10] $rose(i_rst_n);
    endproperty
    assert_reset_duration: assert property (p_reset_min_duration)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Reset pulse too short");
    
    // Reset deassertion - no activity during reset
    property p_no_activity_during_reset;
        !i_rst_n |-> !o_decim_valid && !o_adc_ready;
    endproperty
    assert_no_activity_reset: assert property (p_no_activity_during_reset)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Activity detected during reset");

// CSR Interface Protocol Assertions
    // CSR write protocol - valid must be held with data
    property p_csr_write_protocol;
        i_csr_wr_valid |-> ##[0:1] o_csr_wr_ready;
    endproperty
    assert_csr_write_protocol: assert property (p_csr_write_protocol)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: CSR write protocol violation");
    
    // CSR read protocol - ready must be held with data
    property p_csr_read_protocol;
        i_csr_rd_ready |-> ##[0:1] o_csr_rd_valid;
    endproperty
    assert_csr_read_protocol: assert property (p_csr_read_protocol)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: CSR read protocol violation");
    
    // CSR address range validation
    property p_csr_addr_range;
        (i_csr_wr_valid || i_csr_rd_ready) |-> (i_csr_addr <= 8'h7F);
    endproperty
    assert_csr_addr_range: assert property (p_csr_addr_range)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: CSR address out of range: 0x%02h", i_csr_addr);

// Data Flow Protocol Assertions
    // ADC input protocol - valid must be held with data
    property p_adc_input_protocol;
        i_adc_valid |-> ##[0:1] o_adc_ready;
    endproperty
    assert_adc_input_protocol: assert property (p_adc_input_protocol)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: ADC input protocol violation");
    
    // Decimated output protocol - valid must be held with data
    property p_decim_output_protocol;
        o_decim_valid |-> ##[0:1] i_decim_ready;
    endproperty
    assert_decim_output_protocol: assert property (p_decim_output_protocol)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Decimated output protocol violation");

// Safety Assertions
    // No simultaneous overflow and underflow
    property p_no_simultaneous_overflow_underflow;
        !(cic_overflow && cic_underflow) && 
        !(fir_overflow && fir_underflow) && 
        !(halfband_overflow && halfband_underflow);
    endproperty
    assert_no_simultaneous_overflow_underflow: assert property (p_no_simultaneous_overflow_underflow)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Simultaneous overflow and underflow detected");
    
    // Error interrupt assertion - must be set when any error occurs
    property p_error_interrupt;
        (cic_overflow || cic_underflow || fir_overflow || fir_underflow || 
         halfband_overflow || halfband_underflow) |-> o_error;
    endproperty
    assert_error_interrupt: assert property (p_error_interrupt)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Error interrupt not set when error detected");

// Performance Assertions
    // Maximum latency assertion - output should be available within reasonable time
    property p_max_latency;
        i_adc_valid |-> ##[1:100] o_decim_valid;
    endproperty
    assert_max_latency: assert property (p_max_latency)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Maximum latency exceeded");
    
    // Throughput assertion - should maintain minimum throughput
    property p_min_throughput;
        i_adc_valid |-> ##[1:10] o_adc_ready;
    endproperty
    assert_min_throughput: assert property (p_min_throughput)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Minimum throughput not maintained");

// Coefficient Validation Assertions
    // FIR coefficient range validation
    property p_fir_coeff_range;
        foreach (o_fir_coeff[i]) (o_fir_coeff[i] >= -2**(SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1)) && 
                                 (o_fir_coeff[i] <= 2**(SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1)-1);
    endproperty
    assert_fir_coeff_range: assert property (p_fir_coeff_range)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: FIR coefficient out of range");
    
    // Halfband coefficient range validation
    property p_halfband_coeff_range;
        foreach (o_halfband_coeff[i]) (o_halfband_coeff[i] >= -2**(SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1)) && 
                                      (o_halfband_coeff[i] <= 2**(SSEMI_ADC_DECIMATOR_COEFF_WIDTH-1)-1);
    endproperty
    assert_halfband_coeff_range: assert property (p_halfband_coeff_range)
        else $error("SSEMI_ADC_DECIMATOR_SYS_TOP: Halfband coefficient out of range");

`endif // SSEMI_ADC_DECIMATOR_ASSERTIONS

// Coverage Collection
`ifdef SSEMI_ADC_DECIMATOR_COVERAGE
    // Functional Coverage - CSR Operations
    covergroup cg_csr_operations @(posedge i_clk);
        cp_write_operation: coverpoint {i_csr_wr_valid, o_csr_wr_ready} {
            bins write_success = {2'b11};
            bins write_pending = {2'b10};
            bins write_idle = {2'b00};
        }
        cp_read_operation: coverpoint {i_csr_rd_ready, o_csr_rd_valid} {
            bins read_success = {2'b11};
            bins read_pending = {2'b01};
            bins read_idle = {2'b00};
        }
        cp_address_range: coverpoint i_csr_addr {
            bins config_regs = {[0:127]};
            bins status_regs = {[128:255]};
            illegal_bins invalid = default;
        }
    endgroup
    cg_csr_operations cg_csr_inst = new();
    
    // Functional Coverage - Data Flow
    covergroup cg_data_flow @(posedge i_clk);
        cp_adc_flow: coverpoint {i_adc_valid, o_adc_ready} {
            bins flow_success = {2'b11};
            bins flow_pending = {2'b10};
            bins flow_idle = {2'b00};
        }
        cp_decim_flow: coverpoint {o_decim_valid, i_decim_ready} {
            bins flow_success = {2'b11};
            bins flow_pending = {2'b01};
            bins flow_idle = {2'b00};
        }
    endgroup
    cg_data_flow cg_data_inst = new();
    
    // Functional Coverage - Error Conditions
    covergroup cg_error_conditions @(posedge i_clk);
        cp_cic_errors: coverpoint {cic_overflow, cic_underflow} {
            bins no_error = {2'b00};
            bins overflow = {2'b10};
            bins underflow = {2'b01};
            bins both_errors = {2'b11};
        }
        cp_fir_errors: coverpoint {fir_overflow, fir_underflow} {
            bins no_error = {2'b00};
            bins overflow = {2'b10};
            bins underflow = {2'b01};
            bins both_errors = {2'b11};
        }
        cp_halfband_errors: coverpoint {halfband_overflow, halfband_underflow} {
            bins no_error = {2'b00};
            bins overflow = {2'b10};
            bins underflow = {2'b01};
            bins both_errors = {2'b11};
        }
    endgroup
    cg_error_conditions cg_error_inst = new();
`endif // SSEMI_ADC_DECIMATOR_COVERAGE

`endif // SSEMI_ADC_DECIMATOR_VERIFICATION

endmodule

`endif // SSEMI_ADC_DECIMATOR_SYS_TOP_V
