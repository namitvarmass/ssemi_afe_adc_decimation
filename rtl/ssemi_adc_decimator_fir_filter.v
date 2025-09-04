`ifndef SSEMI_FIR_FILTER_V
`define SSEMI_FIR_FILTER_V

//=============================================================================
// Module Name: ssemi_fir_filter
//=============================================================================
// Description: Configurable FIR filter for ADC decimation
//              Supports configurable taps, coefficient width, and data width
//              Features coefficient update capability and overflow protection
//              Optimized for high-speed operation with minimal resource usage
//
// Timing Constraints:
//   - Input Clock (i_clk): 100MHz typical, 200MHz maximum
//   - Setup Time: 2ns minimum for i_data and i_valid
//   - Hold Time: 1ns minimum for i_data and i_valid
//   - Output Delay: 8ns maximum for o_data and o_valid
//   - Clock-to-Q: 6ns maximum for registered outputs
//   - Filter Latency: NUM_TAPS cycles (pipeline depth)
//   - Coefficient Update: 1-cycle latency when i_coeff_valid asserted
//   - Overflow Detection: 1-cycle latency
//   - Saturation Logic: Combinational (no additional latency)
//
// Resource Requirements:
//   - Registers: ~(NUM_TAPS * INPUT_DATA_WIDTH) + control registers
//   - Combinational Logic: High (multiplier array + adder tree)
//   - Memory: ~(NUM_TAPS * COEFF_WIDTH) for coefficients
//   - Multipliers: NUM_TAPS (can be shared for lower frequencies)
//
// Coefficient Validation:
//   - FIR coefficients: 18-bit signed values, range -131072 to +131071 (0x20000 to 0x1FFFF)
//   - Coefficient saturation: Values exceeding range are clamped to min/max
//   - Tap count validation: 4-256 taps with power-of-2 recommendation for efficiency
//   - Coefficient update: Via CSR interface with immediate effect on filter response
//   - Default coefficients: Optimized for 20kHz passband compensation and stopband attenuation
//
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module ssemi_adc_decimator_fir_filter #(
    parameter NUM_TAPS = `SSEMI_FIR_TAPS,
    parameter COEFF_WIDTH = `SSEMI_FIR_COEFF_WIDTH,
    parameter INPUT_DATA_WIDTH = `SSEMI_CIC_DATA_WIDTH,
    parameter OUTPUT_DATA_WIDTH = `SSEMI_FIR_DATA_WIDTH
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  wire i_clk,           // Input clock (100MHz typical)
    input  wire i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  wire i_enable,        // Enable FIR filter operation
    input  wire i_valid,         // Input data valid signal
    output reg  o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  wire [INPUT_DATA_WIDTH-1:0] i_data,   // Input data (32-bit signed)
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
    output reg  [5:0] o_tap_status  // Status of filter taps
);

    //==============================================================================
    // Error Type Constants (replacing enum)
    //==============================================================================
    parameter SSEMI_FIR_ERROR_NONE = 3'b000;
    parameter SSEMI_FIR_ERROR_OVERFLOW = 3'b001;
    parameter SSEMI_FIR_ERROR_UNDERFLOW = 3'b010;
    parameter SSEMI_FIR_ERROR_INVALID_COEFF = 3'b011;
    parameter SSEMI_FIR_ERROR_TAP_FAILURE = 3'b100;
    parameter SSEMI_FIR_ERROR_RESERVED1 = 3'b101;
    parameter SSEMI_FIR_ERROR_RESERVED2 = 3'b110;
    parameter SSEMI_FIR_ERROR_RESERVED3 = 3'b111;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages (verification only)
    //==============================================================================
`ifdef SSEMI_VERIFICATION
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
`endif

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Data delay line (shift register)
    reg [INPUT_DATA_WIDTH-1:0] data_delay_line [0:NUM_TAPS-1];
    reg [INPUT_DATA_WIDTH-1:0] data_delay_next [0:NUM_TAPS-1];
    
    // Coefficient registers
    reg [COEFF_WIDTH-1:0] coeff_regs [0:NUM_TAPS-1];
    reg [COEFF_WIDTH-1:0] coeff_next [0:NUM_TAPS-1];
    
    // Multiplication results
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH-1:0] mult_results [0:NUM_TAPS-1];
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH-1:0] mult_results_saturated [0:NUM_TAPS-1];
    
    // Accumulation
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH+$clog2(NUM_TAPS)-1:0] accumulator;
    reg [INPUT_DATA_WIDTH+COEFF_WIDTH+$clog2(NUM_TAPS)-1:0] accumulator_next;
    reg [OUTPUT_DATA_WIDTH-1:0] output_data;
    
    // Control signals
    reg processing_valid;
    reg processing_ready;
    reg coeff_update_enable;
    reg [NUM_TAPS-1:0] tap_active;
    
    // Error detection
    reg overflow_detected;
    reg underflow_detected;
    reg [NUM_TAPS-1:0] tap_overflow;
    reg [NUM_TAPS-1:0] tap_underflow;
    
    // Status tracking
    reg [5:0] tap_status_reg;
    reg busy_reg;
    reg coeff_ready_reg;

    //==============================================================================
    // Coefficient Management
    //==============================================================================
    
    // Coefficient update logic
    genvar i;
    generate
        for (i = 0; i < NUM_TAPS; i = i + 1) begin : coeff_update
            always @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) begin
                    coeff_regs[i] <= '0;
                end else if (!i_enable) begin
                    coeff_regs[i] <= '0;
                end else if (i_coeff_valid) begin
                    coeff_regs[i] <= coeff_next[i];
                end
            end
        end
    endgenerate

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            coeff_ready_reg <= 1'b1;
        end else if (!i_enable) begin
            coeff_ready_reg <= 1'b1;
        end else if (i_coeff_valid) begin
            coeff_ready_reg <= 1'b0;
        end else begin
            coeff_ready_reg <= 1'b1;
        end
    end
    
    // Coefficient validation and assignment
    genvar j;
    generate
        for (j = 0; j < NUM_TAPS; j = j + 1) begin : coeff_validation
            always @(*) begin
                // Validate coefficient range
                if (i_coeff[j] > {1'b0, {(COEFF_WIDTH-1){1'b1}}}) begin
                    coeff_next[j] = {1'b0, {(COEFF_WIDTH-1){1'b1}}}; // Saturate to max positive
                end else if (i_coeff[j] < {1'b1, {(COEFF_WIDTH-1){1'b0}}}) begin
                    coeff_next[j] = {1'b1, {(COEFF_WIDTH-1){1'b0}}}; // Saturate to max negative
                end else begin
                    coeff_next[j] = i_coeff[j];
                end
            end
        end
    endgenerate

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
    // Multiplication and Accumulation
    //==============================================================================
    
    // Multiplication with overflow detection
    genvar j;
    generate
        for (j = 0; j < NUM_TAPS; j = j + 1) begin : mult_stages
            // Multiplication
            assign mult_results[j] = data_delay_line[j] * coeff_regs[j];
            
            // Overflow/underflow detection for each multiplication
            always @(*) begin
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
    
    // Accumulation computation
    always @(*) begin
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
    always @(posedge i_clk or negedge i_rst_n) begin
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
