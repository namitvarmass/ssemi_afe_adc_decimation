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
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_adc_decimator_top #(
    parameter int CIC_STAGES = `SSEMI_CIC_STAGES,
    parameter int FIR_TAPS = `SSEMI_FIR_TAPS,
    parameter int HALFBAND_TAPS = `SSEMI_HALFBAND_TAPS,
    parameter int DECIMATION_FACTOR = `SSEMI_DEFAULT_DECIMATION_FACTOR
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  logic i_clk,           // Input clock (100MHz typical)
    input  logic i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  logic i_enable,        // Enable decimator operation
    input  logic i_valid,         // Input data valid signal
    output logic o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  logic [`SSEMI_INPUT_DATA_WIDTH-1:0] i_data,   // Input data (16-bit signed)
    output logic [`SSEMI_OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (24-bit signed)
    output logic o_valid,         // Output data valid signal
    
    //==============================================================================
    // Configuration Interface
    //==============================================================================
    input  logic i_config_valid,  // Configuration data valid
    input  logic [7:0] i_config_addr,  // Configuration address
    input  logic [31:0] i_config_data, // Configuration data
    output logic o_config_ready,  // Configuration ready
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output logic [7:0] o_status,              // Status information
    output logic o_busy,                      // Decimator busy
    output logic o_error,                     // Error flag
    output logic [2:0] o_error_type,          // Specific error type
    output logic [3:0] o_cic_stage_status,    // CIC stage status
    output logic [5:0] o_fir_tap_status,      // FIR tap status
    output logic [4:0] o_halfband_tap_status  // Halfband tap status
);

    //==============================================================================
    // Type Definitions for Better Type Safety
    //==============================================================================
    typedef logic [`SSEMI_INPUT_DATA_WIDTH-1:0] ssemi_input_data_t;
    typedef logic [`SSEMI_OUTPUT_DATA_WIDTH-1:0] ssemi_output_data_t;
    typedef logic [`SSEMI_CIC_DATA_WIDTH-1:0] ssemi_cic_data_t;
    typedef logic [`SSEMI_FIR_DATA_WIDTH-1:0] ssemi_fir_data_t;
    typedef logic [`SSEMI_FIR_COEFF_WIDTH-1:0] ssemi_fir_coeff_t;
    typedef logic [`SSEMI_HALFBAND_COEFF_WIDTH-1:0] ssemi_halfband_coeff_t;
    typedef logic [7:0] ssemi_status_t;
    typedef logic [2:0] ssemi_error_type_t;
    
    // Error type enumeration
    typedef enum logic [2:0] {
        TOP_ERROR_NONE = 3'b000,
        TOP_ERROR_OVERFLOW = 3'b001,
        TOP_ERROR_UNDERFLOW = 3'b010,
        TOP_ERROR_INVALID_CONFIG = 3'b011,
        TOP_ERROR_STAGE_FAILURE = 3'b100,
        TOP_ERROR_RESERVED1 = 3'b101,
        TOP_ERROR_RESERVED2 = 3'b110,
        TOP_ERROR_RESERVED3 = 3'b111
    } top_error_type_e;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages
    //==============================================================================
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
        
        // Display configuration summary
        $info("SSEMI_ADC_DECIMATOR_TOP: Configuration - CIC Stages: %d, FIR Taps: %d, Halfband Taps: %d, Decimation: %d",
              CIC_STAGES, FIR_TAPS, HALFBAND_TAPS, DECIMATION_FACTOR);
    end

    //==============================================================================
    // Internal Signals and Connections
    //==============================================================================
    
    // Clock divider signals
    logic cic_clk;
    logic fir_clk;
    logic halfband_clk;
    
    // CIC filter signals
    ssemi_cic_data_t cic_output_data;
    logic cic_output_valid;
    logic cic_overflow;
    logic cic_underflow;
    logic cic_busy;
    
    // FIR filter signals
    ssemi_fir_data_t fir_output_data;
    logic fir_output_valid;
    logic fir_overflow;
    logic fir_underflow;
    logic fir_busy;
    ssemi_fir_coeff_t fir_coefficients [0:FIR_TAPS-1];
    
    // Halfband filter signals
    ssemi_output_data_t halfband_output_data;
    logic halfband_output_valid;
    logic halfband_overflow;
    logic halfband_underflow;
    logic halfband_busy;
    ssemi_halfband_coeff_t halfband_coefficients [0:HALFBAND_TAPS-1];
    
    // Configuration and status signals
    ssemi_status_t status_reg;
    logic busy_reg;
    logic error_reg;
    ssemi_error_type_t error_type_reg;
    
    // Error aggregation
    logic any_overflow;
    logic any_underflow;
    logic any_stage_failure;

    //==============================================================================
    // Clock Divider Instances
    //==============================================================================
    
    // Clock divider for CIC stage
    ssemi_clock_divider #(
        .CLK_DIV_RATIO(1)  // CIC runs at full clock rate
    ) cic_clock_div (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .o_clk_div(cic_clk)
    );
    
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
        .CLK_DIV_RATIO(2)  // Halfband runs at 2:1 decimation
    ) halfband_clock_div (
        .i_clk(i_clk),
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
        .i_enable(i_enable),
        .i_config_valid(i_config_valid),
        .i_config_addr(i_config_addr),
        .i_config_data(i_config_data),
        .o_config_ready(o_config_ready),
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
        .o_status(status_reg),
        .o_busy(busy_reg),
        .o_error(error_reg),
        .o_error_type(error_type_reg)
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
        .i_clk(i_clk),
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
        .i_clk(i_clk),
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
    
    // Error type determination
    always_comb begin
        if (any_overflow) begin
            error_type_reg = TOP_ERROR_OVERFLOW;
        end else if (any_underflow) begin
            error_type_reg = TOP_ERROR_UNDERFLOW;
        end else if (error_reg) begin
            error_type_reg = TOP_ERROR_INVALID_CONFIG;
        end else if (any_stage_failure) begin
            error_type_reg = TOP_ERROR_STAGE_FAILURE;
        end else begin
            error_type_reg = TOP_ERROR_NONE;
        end
    end

    //==============================================================================
    // Output Assignments
    //==============================================================================
    
    // Data outputs
    assign o_data = halfband_output_data;
    assign o_valid = halfband_output_valid;
    assign o_ready = i_enable && !busy_reg;
    
    // Status outputs
    assign o_status = status_reg;
    assign o_busy = busy_reg || cic_busy || fir_busy || halfband_busy;
    assign o_error = error_reg || any_overflow || any_underflow || any_stage_failure;
    assign o_error_type = error_type_reg;

endmodule

`endif // SSEMI_ADC_DECIMATOR_TOP_V
