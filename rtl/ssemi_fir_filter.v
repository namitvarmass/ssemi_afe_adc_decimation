`ifndef SSEMI_FIR_FILTER_V
`define SSEMI_FIR_FILTER_V

//=============================================================================
// Module Name: ssemi_fir_filter
//=============================================================================
// Description: Configurable FIR filter with programmable coefficients
//              Supports configurable number of taps and coefficient width
//              Implements symmetric FIR filter for efficient implementation
//              Features comprehensive error detection and overflow protection
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_fir_filter #(
    parameter int NUM_TAPS = `SSEMI_FIR_TAPS,              // Number of filter taps (4-256)
    parameter int COEFF_WIDTH = `SSEMI_FIR_COEFF_WIDTH,    // Coefficient width (8-24 bits)
    parameter int INPUT_DATA_WIDTH = `SSEMI_CIC_DATA_WIDTH, // Input data width
    parameter int OUTPUT_DATA_WIDTH = `SSEMI_FIR_DATA_WIDTH // Output data width
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  logic i_clk,           // Input clock (100MHz typical)
    input  logic i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  logic i_enable,        // Enable FIR filter operation
    input  logic i_valid,         // Input data valid signal
    output logic o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  logic [INPUT_DATA_WIDTH-1:0] i_data,   // Input data (32-bit signed)
    output logic [OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (24-bit signed)
    output logic o_valid,         // Output data valid signal
    
    //==============================================================================
    // Coefficient Interface
    //==============================================================================
    input  logic [COEFF_WIDTH-1:0] i_coeff [0:NUM_TAPS-1], // Filter coefficients
    input  logic i_coeff_valid,   // Coefficient update valid
    output logic o_coeff_ready,   // Ready for coefficient update
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output logic o_overflow,      // Overflow detection flag
    output logic o_underflow,     // Underflow detection flag
    output logic o_busy,          // Filter busy indicator
    output logic [5:0] o_tap_status  // Status of filter taps
);

    //==============================================================================
    // Type Definitions for Better Type Safety
    //==============================================================================
    typedef logic [INPUT_DATA_WIDTH-1:0] ssemi_input_data_t;
    typedef logic [OUTPUT_DATA_WIDTH-1:0] ssemi_output_data_t;
    typedef logic [COEFF_WIDTH-1:0] ssemi_coeff_t;
    typedef logic [INPUT_DATA_WIDTH+COEFF_WIDTH-1:0] ssemi_mult_result_t;
    typedef logic [INPUT_DATA_WIDTH+COEFF_WIDTH+$clog2(NUM_TAPS)-1:0] ssemi_accum_result_t;
    typedef logic [5:0] ssemi_tap_status_t;
    typedef logic [$clog2(NUM_TAPS)-1:0] ssemi_tap_index_t;
    
    // Error type enumeration
    typedef enum logic [2:0] {
        FIR_ERROR_NONE = 3'b000,
        FIR_ERROR_OVERFLOW = 3'b001,
        FIR_ERROR_UNDERFLOW = 3'b010,
        FIR_ERROR_INVALID_CONFIG = 3'b011,
        FIR_ERROR_COEFF_RANGE = 3'b100,
        FIR_ERROR_RESERVED1 = 3'b101,
        FIR_ERROR_RESERVED2 = 3'b110,
        FIR_ERROR_RESERVED3 = 3'b111
    } fir_error_type_e;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages
    //==============================================================================
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (NUM_TAPS < 4 || NUM_TAPS > 256) begin
            $error("SSEMI_FIR_FILTER: NUM_TAPS must be between 4 and 256, got %d", NUM_TAPS);
        end
        
        if (COEFF_WIDTH < 8 || COEFF_WIDTH > 24) begin
            $error("SSEMI_FIR_FILTER: COEFF_WIDTH must be between 8 and 24, got %d", COEFF_WIDTH);
        end
        
        if (INPUT_DATA_WIDTH < 8 || INPUT_DATA_WIDTH > 48) begin
            $error("SSEMI_FIR_FILTER: INPUT_DATA_WIDTH must be between 8 and 48, got %d", INPUT_DATA_WIDTH);
        end
        
        if (OUTPUT_DATA_WIDTH < 8 || OUTPUT_DATA_WIDTH > 48) begin
            $error("SSEMI_FIR_FILTER: OUTPUT_DATA_WIDTH must be between 8 and 48, got %d", OUTPUT_DATA_WIDTH);
        end
        
        if (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH + COEFF_WIDTH) begin
            $warning("SSEMI_FIR_FILTER: OUTPUT_DATA_WIDTH (%d) may cause precision loss with INPUT_DATA_WIDTH (%d) and COEFF_WIDTH (%d)",
                     OUTPUT_DATA_WIDTH, INPUT_DATA_WIDTH, COEFF_WIDTH);
        end
        
        // Check for power-of-2 number of taps (recommended for efficiency)
        if ((NUM_TAPS & (NUM_TAPS - 1)) != 0) begin
            $info("SSEMI_FIR_FILTER: NUM_TAPS %d is not a power of 2, may impact performance", NUM_TAPS);
        end
        
        // Display configuration summary
        $info("SSEMI_FIR_FILTER: Configuration - Taps: %d, Coeff Width: %d, Input: %d-bit, Output: %d-bit",
              NUM_TAPS, COEFF_WIDTH, INPUT_DATA_WIDTH, OUTPUT_DATA_WIDTH);
    end

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Data delay line (shift register)
    ssemi_input_data_t data_delay_line [0:NUM_TAPS-1];
    ssemi_input_data_t data_delay_next [0:NUM_TAPS-1];
    
    // Coefficient registers
    ssemi_coeff_t coeff_regs [0:NUM_TAPS-1];
    ssemi_coeff_t coeff_next [0:NUM_TAPS-1];
    
    // Multiplication results
    ssemi_mult_result_t mult_results [0:NUM_TAPS-1];
    ssemi_mult_result_t mult_results_saturated [0:NUM_TAPS-1];
    
    // Accumulation
    ssemi_accum_result_t accumulator;
    ssemi_accum_result_t accumulator_next;
    ssemi_output_data_t output_data;
    
    // Control signals
    logic processing_valid;
    logic processing_ready;
    logic coeff_update_enable;
    logic [NUM_TAPS-1:0] tap_active;
    
    // Error detection
    logic overflow_detected;
    logic underflow_detected;
    logic [NUM_TAPS-1:0] tap_overflow;
    logic [NUM_TAPS-1:0] tap_underflow;
    
    // Status tracking
    ssemi_tap_status_t tap_status_reg;
    logic busy_reg;
    logic coeff_ready_reg;

    //==============================================================================
    // Coefficient Management
    //==============================================================================
    
    // Coefficient update logic
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                coeff_regs[i] <= '0;
            end
            coeff_ready_reg <= 1'b1;
        end else if (!i_enable) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                coeff_regs[i] <= '0;
            end
            coeff_ready_reg <= 1'b1;
        end else if (i_coeff_valid) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                coeff_regs[i] <= coeff_next[i];
            end
            coeff_ready_reg <= 1'b0;
        end else begin
            coeff_ready_reg <= 1'b1;
        end
    end
    
    // Coefficient validation and assignment
    always_comb begin
        for (int i = 0; i < NUM_TAPS; i = i + 1) begin
            // Validate coefficient range
            if (i_coeff[i] > {1'b0, {(COEFF_WIDTH-1){1'b1}}}) begin
                coeff_next[i] = {1'b0, {(COEFF_WIDTH-1){1'b1}}}; // Saturate to max positive
            end else if (i_coeff[i] < {1'b1, {(COEFF_WIDTH-1){1'b0}}}) begin
                coeff_next[i] = {1'b1, {(COEFF_WIDTH-1){1'b0}}}; // Saturate to max negative
            end else begin
                coeff_next[i] = i_coeff[i];
            end
        end
    end

    //==============================================================================
    // Data Delay Line Management
    //==============================================================================
    
    // Shift register for input data
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                data_delay_line[i] <= '0;
            end
        end else if (!i_enable) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                data_delay_line[i] <= '0;
            end
        end else if (i_valid) begin
            for (int i = 0; i < NUM_TAPS; i = i + 1) begin
                data_delay_line[i] <= data_delay_next[i];
            end
        end
    end
    
    // Data delay line shift logic
    always_comb begin
        data_delay_next[0] = i_data;
        for (int i = 1; i < NUM_TAPS; i = i + 1) begin
            data_delay_next[i] = data_delay_line[i-1];
        end
    end

    //==============================================================================
    // Multiplication and Accumulation
    //==============================================================================
    
    // Multiplication with overflow detection
    genvar j;
    generate
        for (j = 0; j < NUM_TAPS; j = j + 1) begin : mult_stages
            // Multiplication
            assign mult_results[j] = data_delay_line[j] * coeff_regs[j];
            
            // Overflow/underflow detection for each multiplication
            always_comb begin
                if (mult_results[j] > {1'b0, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b1}}}) begin
                    mult_results_saturated[j] = {1'b0, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b1}}};
                    tap_overflow[j] = 1'b1;
                    tap_underflow[j] = 1'b0;
                end else if (mult_results[j] < {1'b1, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b0}}}) begin
                    mult_results_saturated[j] = {1'b1, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b0}}};
                    tap_overflow[j] = 1'b0;
                    tap_underflow[j] = 1'b1;
                end else begin
                    mult_results_saturated[j] = mult_results[j];
                    tap_overflow[j] = 1'b0;
                    tap_underflow[j] = 1'b0;
                end
            end
        end
    endgenerate
    
    // Accumulation with overflow protection
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            accumulator <= '0;
            output_data <= '0;
            processing_valid <= 1'b0;
        end else if (!i_enable) begin
            accumulator <= '0;
            output_data <= '0;
            processing_valid <= 1'b0;
        end else if (i_valid) begin
            accumulator <= accumulator_next;
            
            // Output data with saturation
            if (accumulator_next > {1'b0, {(OUTPUT_DATA_WIDTH-1){1'b1}}}) begin
                output_data <= {1'b0, {(OUTPUT_DATA_WIDTH-1){1'b1}}};
            end else if (accumulator_next < {1'b1, {(OUTPUT_DATA_WIDTH-1){1'b0}}}) begin
                output_data <= {1'b1, {(OUTPUT_DATA_WIDTH-1){1'b0}}};
            end else begin
                output_data <= accumulator_next[OUTPUT_DATA_WIDTH-1:0];
            end
            
            processing_valid <= 1'b1;
        end else begin
            processing_valid <= 1'b0;
        end
    end
    
    // Accumulation computation
    always_comb begin
        accumulator_next = '0;
        for (int k = 0; k < NUM_TAPS; k = k + 1) begin
            accumulator_next = accumulator_next + mult_results_saturated[k];
        end
    end

    //==============================================================================
    // Error Detection and Status Tracking
    //==============================================================================
    
    // Error detection
    assign overflow_detected = |tap_overflow;
    assign underflow_detected = |tap_underflow;
    
    // Status tracking
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tap_status_reg <= 6'h00;
            busy_reg <= 1'b0;
        end else if (!i_enable) begin
            tap_status_reg <= 6'h00;
            busy_reg <= 1'b0;
        end else begin
            busy_reg <= i_valid || processing_valid;
            tap_status_reg <= {
                overflow_detected,     // bit 5: Overflow detected
                underflow_detected,    // bit 4: Underflow detected
                processing_valid,      // bit 3: Processing active
                i_valid,              // bit 2: Input valid
                i_coeff_valid,        // bit 1: Coefficient update
                busy_reg              // bit 0: Busy state
            };
        end
    end

    //==============================================================================
    // Output Assignments
    //==============================================================================
    
    assign o_data = output_data;
    assign o_valid = processing_valid;
    assign o_ready = i_enable && !busy_reg;
    assign o_coeff_ready = coeff_ready_reg;
    assign o_overflow = overflow_detected;
    assign o_underflow = underflow_detected;
    assign o_busy = busy_reg;
    assign o_tap_status = tap_status_reg;

endmodule

`endif // SSEMI_FIR_FILTER_V
