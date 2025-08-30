`ifndef SSEMI_ADC_DECIMATOR_TOP_V
`define SSEMI_ADC_DECIMATOR_TOP_V

//=============================================================================
// Module Name: ssemi_adc_decimator_top
//=============================================================================
// Description: Top-level ADC decimator with three-stage architecture:
//              1. CIC filter for coarse decimation
//              2. FIR filter for passband compensation
//              3. Halfband FIR filter for final decimation
//              Supports decimation factors from 32 to 512
//              Features comprehensive error detection and status reporting
//
// Timing Constraints:
//   - Input Clock (i_clk): 100MHz typical, 200MHz maximum
//   - Setup Time: 2ns minimum for all input signals
//   - Hold Time: 1ns minimum for all input signals
//   - Output Delay: 8ns maximum for all output signals
//   - Clock-to-Q: 6ns maximum for registered outputs
//   - Reset Recovery: 10ns minimum after i_rst_n deassertion
//   - CSR Read Access: Same-cycle response (combinational)
//   - CSR Write Access: One-cycle latency
//   - Data Path Latency: 3-5 cycles depending on configuration
//
// Clock Domains:
//   - Primary Domain (i_clk): CIC filter, CSR interface, control logic
//   - FIR Domain (fir_clk): FIR filter (divided from i_clk)
//   - Halfband Domain (halfband_clk): Halfband filter (divided from fir_clk)
//
// Power Considerations:
//   - Clock gating implemented for power efficiency
//   - Cascaded clock division reduces dynamic power
//   - Coefficient memory can be power-gated when not in use
//
// Coefficient Validation:
//   - FIR coefficients: 18-bit signed values, range -131072 to +131071
//   - Halfband coefficients: 18-bit signed values, odd-indexed taps must be zero
//   - Default coefficients optimized for 20kHz passband, <0.01dB ripple, >100dB attenuation
//   - Coefficient updates via CSR interface with range validation and saturation
//
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_adc_decimator_top #(
    parameter CIC_STAGES = `SSEMI_CIC_STAGES,
    parameter FIR_TAPS = `SSEMI_FIR_TAPS,
    parameter HALFBAND_TAPS = `SSEMI_HALFBAND_TAPS,
    parameter DECIMATION_FACTOR = `SSEMI_DEFAULT_DECIMATION_FACTOR
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  wire i_clk,           // Input clock (100MHz typical)
    input  wire i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  wire i_enable,        // Enable decimator operation
    input  wire i_valid,         // Input data valid signal
    output reg  o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  wire [`SSEMI_INPUT_DATA_WIDTH-1:0] i_data,   // Input data (16-bit signed)
    output reg  [`SSEMI_OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (24-bit signed)
    output reg  o_valid,         // Output data valid signal
    
    //==============================================================================
    // CSR Write Interface
    //==============================================================================
    input  wire i_csr_wr_valid,  // Write valid
    input  wire [7:0] i_csr_addr, // Write address
    input  wire [31:0] i_csr_wr_data, // Write data
    output reg  o_csr_wr_ready,  // Write ready
    
    //==============================================================================
    // CSR Read Interface
    //==============================================================================
    input  wire i_csr_rd_ready,  // Read ready (host ready to accept)
    output reg  [31:0] o_csr_rd_data, // Read data
    output reg  o_csr_rd_valid,  // Read valid
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output reg  o_busy,                      // Decimator busy
    output reg  o_error,                     // Error interrupt
    output reg  [3:0] o_cic_stage_status,    // CIC stage status
    output reg  [5:0] o_fir_tap_status,      // FIR tap status
    output reg  [4:0] o_halfband_tap_status  // Halfband tap status
);

    //==============================================================================
    // Error Type Constants (replacing enum)
    //==============================================================================
    parameter SSEMI_TOP_ERROR_NONE = 3'b000;
    parameter SSEMI_TOP_ERROR_OVERFLOW = 3'b001;
    parameter SSEMI_TOP_ERROR_UNDERFLOW = 3'b010;
    parameter SSEMI_TOP_ERROR_INVALID_CONFIG = 3'b011;
    parameter SSEMI_TOP_ERROR_STAGE_FAILURE = 3'b100;
    parameter SSEMI_TOP_ERROR_RESERVED1 = 3'b101;
    parameter SSEMI_TOP_ERROR_RESERVED2 = 3'b110;
    parameter SSEMI_TOP_ERROR_RESERVED3 = 3'b111;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages (verification only)
    //==============================================================================
`ifdef SSEMI_VERIFICATION
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (CIC_STAGES < 1 || CIC_STAGES > 8) begin
            $error("SSEMI_ADC_DECIMATOR_TOP: CIC_STAGES must be between 1 and 8, got %d", CIC_STAGES);
        end
        
        if (FIR_TAPS < 4 || FIR_TAPS > 256) begin
            $error("SSEMI_ADC_DECIMATOR_TOP: FIR_TAPS must be between 4 and 256, got %d", FIR_TAPS);
        end
        
        if (HALFBAND_TAPS < 5 || HALFBAND_TAPS > 128) begin
            $error("SSEMI_ADC_DECIMATOR_TOP: HALFBAND_TAPS must be between 5 and 128, got %d", HALFBAND_TAPS);
        end
        
        if (HALFBAND_TAPS % 2 == 0) begin
            $error("SSEMI_ADC_DECIMATOR_TOP: HALFBAND_TAPS must be odd, got %d", HALFBAND_TAPS);
        end
        
        if (DECIMATION_FACTOR < `SSEMI_MIN_DECIMATION_FACTOR || 
            DECIMATION_FACTOR > `SSEMI_MAX_DECIMATION_FACTOR) begin
            $error("SSEMI_ADC_DECIMATOR_TOP: DECIMATION_FACTOR must be between %d and %d, got %d", 
                   `SSEMI_MIN_DECIMATION_FACTOR, `SSEMI_MAX_DECIMATION_FACTOR, DECIMATION_FACTOR);
        end
        
        if (CIC_STAGES != `SSEMI_CIC_STAGES) begin
            $warning("SSEMI_ADC_DECIMATOR_TOP: CIC_STAGES parameter (%d) differs from define (%d)", 
                     CIC_STAGES, `SSEMI_CIC_STAGES);
        end
        
        if (FIR_TAPS != `SSEMI_FIR_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_TOP: FIR_TAPS parameter (%d) differs from define (%d)", 
                     FIR_TAPS, `SSEMI_FIR_TAPS);
        end
        
        if (HALFBAND_TAPS != `SSEMI_HALFBAND_TAPS) begin
            $warning("SSEMI_ADC_DECIMATOR_TOP: HALFBAND_TAPS parameter (%d) differs from define (%d)", 
                     HALFBAND_TAPS, `SSEMI_HALFBAND_TAPS);
        end
    end
`endif

    //==============================================================================
    // Internal Signals and Connections
    //==============================================================================
    
    // Clock divider signals
    wire fir_clk;
    wire halfband_clk;
    
    // CIC filter signals
    wire [`SSEMI_CIC_DATA_WIDTH-1:0] cic_output_data;
    wire cic_output_valid;
    wire cic_overflow;
    wire cic_underflow;
    wire cic_busy;
    
    // FIR filter signals
    wire [`SSEMI_FIR_DATA_WIDTH-1:0] fir_output_data;
    wire fir_output_valid;
    wire fir_overflow;
    wire fir_underflow;
    wire fir_busy;
    wire [`SSEMI_FIR_COEFF_WIDTH-1:0] fir_coefficients [0:FIR_TAPS-1];
    
    // Halfband filter signals
    wire [`SSEMI_OUTPUT_DATA_WIDTH-1:0] halfband_output_data;
    wire halfband_output_valid;
    wire halfband_overflow;
    wire halfband_underflow;
    wire halfband_busy;
    wire [`SSEMI_HALFBAND_COEFF_WIDTH-1:0] halfband_coefficients [0:HALFBAND_TAPS-1];
    
    // Configuration and status signals
    wire busy_reg;
    wire error_reg;
    
    // Error aggregation
    wire any_overflow;
    wire any_underflow;
    wire any_stage_failure;

    //==============================================================================
    // Clock Divider Instances
    //==============================================================================
    
    // Clock divider for FIR stage
    ssemi_clock_divider #(
        .CLK_DIV_RATIO(DECIMATION_FACTOR)  // FIR runs at decimated rate
    ) fir_clock_div (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .o_clk_div(fir_clk)
    );
    
    // Clock divider for halfband stage
    ssemi_clock_divider #(
        .CLK_DIV_RATIO(2)  // Halfband runs at 2:1 decimation from FIR rate
    ) halfband_clock_div (
        .i_clk(fir_clk),   // Use FIR clock as input for cascaded division
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .o_clk_div(halfband_clk)
    );

    //==============================================================================
    // Configuration and Status Register Instance
    //==============================================================================
    
    ssemi_config_status_regs #(
        .FIR_TAPS(FIR_TAPS),
        .HALFBAND_TAPS(HALFBAND_TAPS)
    ) config_status_regs (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_wr_valid(i_csr_wr_valid),
        .i_csr_addr(i_csr_addr),
        .i_csr_wr_data(i_csr_wr_data),
        .o_csr_wr_ready(o_csr_wr_ready),
        .i_csr_rd_ready(i_csr_rd_ready),
        .o_csr_rd_data(o_csr_rd_data),
        .o_csr_rd_valid(o_csr_rd_valid),
        .i_cic_valid(cic_output_valid),
        .i_fir_valid(fir_output_valid),
        .i_halfband_valid(halfband_output_valid),
        .i_cic_overflow(cic_overflow),
        .i_fir_overflow(fir_overflow),
        .i_halfband_overflow(halfband_overflow),
        .i_cic_underflow(cic_underflow),
        .i_fir_underflow(fir_underflow),
        .i_halfband_underflow(halfband_underflow),
        .o_fir_coeff(fir_coefficients),
        .o_halfband_coeff(halfband_coefficients),
        .o_busy(busy_reg),
        .o_error(error_reg)
    );

    //==============================================================================
    // CIC Filter Instance
    //==============================================================================
    
    ssemi_cic_filter #(
        .CIC_STAGES(CIC_STAGES),
        .DIFFERENTIAL_DELAY(`SSEMI_CIC_DIFFERENTIAL_DELAY),
        .DECIMATION_FACTOR(DECIMATION_FACTOR),
        .INPUT_DATA_WIDTH(`SSEMI_INPUT_DATA_WIDTH),
        .OUTPUT_DATA_WIDTH(`SSEMI_CIC_DATA_WIDTH)
    ) cic_filter (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .i_valid(i_valid),
        .o_ready(),
        .i_data(i_data),
        .o_data(cic_output_data),
        .o_valid(cic_output_valid),
        .o_overflow(cic_overflow),
        .o_underflow(cic_underflow),
        .o_busy(cic_busy),
        .o_stage_status(o_cic_stage_status)
    );

    //==============================================================================
    // FIR Filter Instance
    //==============================================================================
    
    ssemi_fir_filter #(
        .NUM_TAPS(FIR_TAPS),
        .COEFF_WIDTH(`SSEMI_FIR_COEFF_WIDTH),
        .INPUT_DATA_WIDTH(`SSEMI_CIC_DATA_WIDTH),
        .OUTPUT_DATA_WIDTH(`SSEMI_FIR_DATA_WIDTH)
    ) fir_filter (
        .i_clk(fir_clk),   // Use divided clock for FIR stage
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .i_valid(cic_output_valid),
        .o_ready(),
        .i_data(cic_output_data),
        .o_data(fir_output_data),
        .o_valid(fir_output_valid),
        .i_coeff(fir_coefficients),
        .i_coeff_valid(1'b0),  // Coefficients loaded from config regs
        .o_coeff_ready(),
        .o_overflow(fir_overflow),
        .o_underflow(fir_underflow),
        .o_busy(fir_busy),
        .o_tap_status(o_fir_tap_status)
    );

    //==============================================================================
    // Halfband Filter Instance
    //==============================================================================
    
    ssemi_halfband_filter #(
        .NUM_TAPS(HALFBAND_TAPS),
        .COEFF_WIDTH(`SSEMI_HALFBAND_COEFF_WIDTH),
        .INPUT_DATA_WIDTH(`SSEMI_FIR_DATA_WIDTH),
        .OUTPUT_DATA_WIDTH(`SSEMI_OUTPUT_DATA_WIDTH)
    ) halfband_filter (
        .i_clk(halfband_clk),   // Use divided clock for halfband stage
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .i_valid(fir_output_valid),
        .o_ready(),
        .i_data(fir_output_data),
        .o_data(halfband_output_data),
        .o_valid(halfband_output_valid),
        .i_coeff(halfband_coefficients),
        .i_coeff_valid(1'b0),  // Coefficients loaded from config regs
        .o_coeff_ready(),
        .o_overflow(halfband_overflow),
        .o_underflow(halfband_underflow),
        .o_busy(halfband_busy),
        .o_tap_status(o_halfband_tap_status)
    );

    //==============================================================================
    // Error Detection and Status Aggregation
    //==============================================================================
    
    // Error aggregation
    assign any_overflow = cic_overflow || fir_overflow || halfband_overflow;
    assign any_underflow = cic_underflow || fir_underflow || halfband_underflow;
    assign any_stage_failure = cic_busy && fir_busy && halfband_busy;
    
    // Error type determination (now handled in config_status_regs)
    // Error aggregation and type determination moved to CSR module

    //==============================================================================
    // Output Assignments
    //==============================================================================
    
    // Data outputs
    assign o_data = halfband_output_data;
    assign o_valid = halfband_output_valid;
    assign o_ready = i_enable && !busy_reg;
    
    // Status outputs
    assign o_busy = busy_reg || cic_busy || fir_busy || halfband_busy;
    assign o_error = error_reg || any_overflow || any_underflow || any_stage_failure;

endmodule

`endif // SSEMI_ADC_DECIMATOR_TOP_V
