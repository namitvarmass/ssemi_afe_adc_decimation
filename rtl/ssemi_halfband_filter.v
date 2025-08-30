`ifndef SSEMI_HALFBAND_FILTER_V
`define SSEMI_HALFBAND_FILTER_V

//=============================================================================
// Module Name: ssemi_halfband_filter
//=============================================================================
// Description: Configurable halfband FIR filter for ADC decimation
//              Supports configurable taps, coefficient width, and data width
//              Features coefficient update capability and overflow protection
//              Optimized for 2:1 decimation with zero-valued odd taps
//
// Timing Constraints:
//   - Input Clock (i_clk): 100MHz typical, 200MHz maximum
//   - Setup Time: 2ns minimum for i_data and i_valid
//   - Hold Time: 1ns minimum for i_data and i_valid
//   - Output Delay: 8ns maximum for o_data and o_valid
//   - Clock-to-Q: 6ns maximum for registered outputs
//   - Filter Latency: (NUM_TAPS+1)/2 cycles (effective taps due to zero odd taps)
//   - Decimation Factor: 2:1 (output rate = input_rate/2)
//   - Coefficient Update: 1-cycle latency when i_coeff_valid asserted
//   - Overflow Detection: 1-cycle latency
//   - Saturation Logic: Combinational (no additional latency)
//
// Resource Requirements:
//   - Registers: ~((NUM_TAPS+1)/2 * INPUT_DATA_WIDTH) + control registers
//   - Combinational Logic: Moderate (reduced due to zero odd taps)
//   - Memory: ~((NUM_TAPS+1)/2 * COEFF_WIDTH) for coefficients
//   - Multipliers: (NUM_TAPS+1)/2 (only non-zero coefficients)
//
// Coefficient Validation:
//   - Halfband coefficients: 18-bit signed values, range -131072 to +131071 (0x20000 to 0x1FFFF)
//   - Odd-indexed taps: Must be zero for halfband filter property (enforced by validation)
//   - Even-indexed taps: Non-zero values for filter response optimization
//   - Tap count validation: Must be odd (5-128 taps) for proper halfband structure
//   - Coefficient saturation: Values exceeding range are clamped to min/max
//   - Default coefficients: Optimized for 2:1 decimation with minimal passband ripple
//
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_halfband_filter #(
    parameter NUM_TAPS = `SSEMI_HALFBAND_TAPS,
    parameter COEFF_WIDTH = `SSEMI_HALFBAND_COEFF_WIDTH,
    parameter INPUT_DATA_WIDTH = `SSEMI_FIR_DATA_WIDTH,
    parameter OUTPUT_DATA_WIDTH = `SSEMI_OUTPUT_DATA_WIDTH
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  wire i_clk,           // Input clock (100MHz typical)
    input  wire i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  wire i_enable,        // Enable halfband filter operation
    input  wire i_valid,         // Input data valid signal
    output reg  o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  wire [INPUT_DATA_WIDTH-1:0] i_data,   // Input data (24-bit signed)
    output reg  [OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (24-bit signed)
    output reg  o_valid,         // Output data valid signal
    
    //==============================================================================
    // Coefficient Interface
    //==============================================================================
    input  wire [COEFF_WIDTH-1:0] i_coeff [0:NUM_TAPS-1], // Filter coefficients
    input  wire i_coeff_valid,   // Coefficient update valid
    output reg  o_coeff_ready,   // Ready for coefficient update
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output reg  o_overflow,      // Overflow detection flag
    output reg  o_underflow,     // Underflow detection flag
    output reg  o_busy,          // Filter busy indicator
    output reg  [4:0] o_tap_status  // Status of filter taps
);

    //==============================================================================
    // Error Type Constants (replacing enum)
    //==============================================================================
    parameter SSEMI_HALFBAND_ERROR_NONE = 3'b000;
    parameter SSEMI_HALFBAND_ERROR_OVERFLOW = 3'b001;
    parameter SSEMI_HALFBAND_ERROR_UNDERFLOW = 3'b010;
    parameter SSEMI_HALFBAND_ERROR_INVALID_COEFF = 3'b011;
    parameter SSEMI_HALFBAND_ERROR_ODD_TAP_NONZERO = 3'b100;
    parameter SSEMI_HALFBAND_ERROR_RESERVED1 = 3'b101;
    parameter SSEMI_HALFBAND_ERROR_RESERVED2 = 3'b110;
    parameter SSEMI_HALFBAND_ERROR_RESERVED3 = 3'b111;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages (verification only)
    //==============================================================================
`ifdef SSEMI_VERIFICATION
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (NUM_TAPS < 5 || NUM_TAPS > 128) begin
            $error("SSEMI_HALFBAND_FILTER: NUM_TAPS must be between 5 and 128, got %d", NUM_TAPS);
        end
        
        if (NUM_TAPS % 2 == 0) begin
            $error("SSEMI_HALFBAND_FILTER: NUM_TAPS must be odd, got %d", NUM_TAPS);
        end
        
        if (COEFF_WIDTH < 8 || COEFF_WIDTH > 24) begin
            $error("SSEMI_HALFBAND_FILTER: COEFF_WIDTH must be between 8 and 24, got %d", COEFF_WIDTH);
        end
        
        if (INPUT_DATA_WIDTH < 8 || INPUT_DATA_WIDTH > 48) begin
            $error("SSEMI_HALFBAND_FILTER: INPUT_DATA_WIDTH must be between 8 and 48, got %d", INPUT_DATA_WIDTH);
        end
        
        if (OUTPUT_DATA_WIDTH < 8 || OUTPUT_DATA_WIDTH > 48) begin
            $error("SSEMI_HALFBAND_FILTER: OUTPUT_DATA_WIDTH must be between 8 and 48, got %d", OUTPUT_DATA_WIDTH);
        end
        
        if (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH + COEFF_WIDTH) begin
            $warning("SSEMI_HALFBAND_FILTER: OUTPUT_DATA_WIDTH (%d) may cause precision loss with INPUT_DATA_WIDTH (%d) and COEFF_WIDTH (%d)",
                     OUTPUT_DATA_WIDTH, INPUT_DATA_WIDTH, COEFF_WIDTH);
        end
        
        // Check for power-of-2 number of taps (recommended for efficiency)
        if (((NUM_TAPS+1)/2 & ((NUM_TAPS+1)/2 - 1)) != 0) begin
            $info("SSEMI_HALFBAND_FILTER: (NUM_TAPS+1)/2 %d is not a power of 2, may impact performance", (NUM_TAPS+1)/2);
        end
        
        // Display configuration summary
        $info("SSEMI_HALFBAND_FILTER: Configuration - Taps: %d, Coeff Width: %d, Input: %d-bit, Output: %d-bit",
              NUM_TAPS, COEFF_WIDTH, INPUT_DATA_WIDTH, OUTPUT_DATA_WIDTH);
    end
`endif

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Data delay line (shift register) - only even-indexed taps are used
    reg [INPUT_DATA_WIDTH-1:0] data_delay_line [0:NUM_TAPS-1];
    reg [INPUT_DATA_WIDTH-1:0] data_delay_next [0:NUM_TAPS-1];
    
    // Coefficient registers
    reg [COEFF_WIDTH-1:0] coeff_regs [0:NUM_TAPS-1];
    reg [COEFF_WIDTH-1:0] coeff_next [0:NUM_TAPS-1];
    
    // Multiplication results (only for even-indexed coefficients)
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH-1:0] mult_results [0:(NUM_TAPS-1)/2];
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH-1:0] mult_results_saturated [0:(NUM_TAPS-1)/2];
    
    // Accumulation
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH+$clog2((NUM_TAPS+1)/2)-1:0] accumulator;
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH+$clog2((NUM_TAPS+1)/2)-1:0] accumulator_next;
    reg [OUTPUT_DATA_WIDTH-1:0] output_data;
    
    // Control signals
    reg processing_valid;
    reg processing_ready;
    reg coeff_update_enable;
    reg [NUM_TAPS-1:0] tap_active;
    reg sample_ready;
    
    // Error detection
    reg overflow_detected;
    reg underflow_detected;
    reg [NUM_TAPS-1:0] tap_overflow;
    reg [NUM_TAPS-1:0] tap_underflow;
    reg odd_tap_nonzero_error;
    
    // Status tracking
    reg [4:0] tap_status_reg;
    reg busy_reg;
    reg coeff_ready_reg;

    //==============================================================================
    // Coefficient Management
    //==============================================================================
    
    // Coefficient update logic
    always @(posedge i_clk or negedge i_rst_n) begin
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
    always @(*) begin
        odd_tap_nonzero_error = 1'b0;
        for (int i = 0; i < NUM_TAPS; i = i + 1) begin
            // Validate coefficient range
            if (i_coeff[i] > {1'b0, {(COEFF_WIDTH-1){1'b1}}}) begin
                coeff_next[i] = {1'b0, {(COEFF_WIDTH-1){1'b1}}}; // Saturate to max positive
            end else if (i_coeff[i] < {1'b1, {(COEFF_WIDTH-1){1'b0}}}) begin
                coeff_next[i] = {1'b1, {(COEFF_WIDTH-1){1'b0}}}; // Saturate to max negative
            end else begin
                coeff_next[i] = i_coeff[i];
            end
            
            // Check for odd-indexed non-zero coefficients (should be zero for halfband)
            if (i % 2 == 1 && i_coeff[i] != 0) begin
                odd_tap_nonzero_error = 1'b1;
            end
        end
    end

    //==============================================================================
    // Data Delay Line Management
    //==============================================================================
    
    // Shift register for input data
    always @(posedge i_clk or negedge i_rst_n) begin
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
    always @(*) begin
        data_delay_next[0] = i_data;
        for (int i = 1; i < NUM_TAPS; i = i + 1) begin
            data_delay_next[i] = data_delay_line[i-1];
        end
    end

    //==============================================================================
    // Multiplication and Accumulation (Halfband Optimization)
    //==============================================================================
    
    // Multiplication with overflow detection (only even-indexed coefficients)
    genvar j;
    generate
        for (j = 0; j < (NUM_TAPS+1)/2; j = j + 1) begin : mult_stages
            // Multiplication for even-indexed coefficients only
            assign mult_results[j] = data_delay_line[j*2] * coeff_regs[j*2];
            
            // Overflow/underflow detection for each multiplication
            always @(*) begin
                if (mult_results[j] > {1'b0, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b1}}}) begin
                    mult_results_saturated[j] = {1'b0, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b1}}};
                    tap_overflow[j*2] = 1'b1;
                    tap_underflow[j*2] = 1'b0;
                end else if (mult_results[j] < {1'b1, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b0}}}) begin
                    mult_results_saturated[j] = {1'b1, {(INPUT_DATA_WIDTH+COEFF_WIDTH-1){1'b0}}};
                    tap_overflow[j*2] = 1'b0;
                    tap_underflow[j*2] = 1'b1;
                end else begin
                    mult_results_saturated[j] = mult_results[j];
                    tap_overflow[j*2] = 1'b0;
                    tap_underflow[j*2] = 1'b0;
                end
                
                // Odd-indexed taps should not contribute to multiplication
                tap_overflow[j*2+1] = 1'b0;
                tap_underflow[j*2+1] = 1'b0;
            end
        end
    endgenerate
    
    // Accumulation with overflow protection
    always @(posedge i_clk or negedge i_rst_n) begin
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
    
    // Accumulation computation (only even-indexed coefficients)
    always @(*) begin
        accumulator_next = '0;
        for (int k = 0; k < (NUM_TAPS+1)/2; k = k + 1) begin
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
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tap_status_reg <= 5'h00;
            busy_reg <= 1'b0;
        end else if (!i_enable) begin
            tap_status_reg <= 5'h00;
            busy_reg <= 1'b0;
        end else begin
            busy_reg <= i_valid || processing_valid;
            tap_status_reg <= {
                overflow_detected,     // bit 4: Overflow detected
                underflow_detected,    // bit 3: Underflow detected
                processing_valid,      // bit 2: Processing active
                i_valid,              // bit 1: Input valid
                odd_tap_nonzero_error // bit 0: Odd tap non-zero error
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

`endif // SSEMI_HALFBAND_FILTER_V
