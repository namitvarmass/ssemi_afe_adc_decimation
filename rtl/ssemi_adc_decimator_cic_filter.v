`ifndef SSEMI_ADC_DECIMATOR_CIC_FILTER_V
`define SSEMI_ADC_DECIMATOR_CIC_FILTER_V

//=============================================================================
// Module Name: ssemi_cic_filter
//=============================================================================
// Description: Configurable CIC (Cascaded Integrator-Comb) filter for ADC decimation
//              Supports configurable stages, differential delay, and decimation factor
//              Features overflow/underflow detection and saturation logic
//              Optimized for high-speed operation with minimal resource usage
//
// Timing Constraints:
//   - Input Clock (i_clk): 100MHz typical, 200MHz maximum
//   - Setup Time: 2ns minimum for i_data and i_valid
//   - Hold Time: 1ns minimum for i_data and i_valid
//   - Output Delay: 8ns maximum for o_data and o_valid
//   - Clock-to-Q: 6ns maximum for registered outputs
//   - Decimation Latency: 1-2 cycles depending on DECIMATION_FACTOR
//   - Overflow Detection: 1-cycle latency
//   - Saturation Logic: Combinational (no additional latency)
//
// Resource Requirements:
//   - Registers: ~(CIC_STAGES * INPUT_DATA_WIDTH * 2) + control registers
//   - Combinational Logic: Moderate (integrator and comb sections)
//   - Memory: None (uses registers for delay lines)
//
// Coefficient Validation:
//   - CIC filter uses no external coefficients (internal integrator/comb structure)
//   - Decimation factor validation: 32-512 range with power-of-2 recommendation
//   - Stage count validation: 1-8 stages for optimal performance
//   - Differential delay validation: 1-4 samples for comb filter optimization
//
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module ssemi_adc_decimator_cic_filter #(
    parameter CIC_STAGES = `SSEMI_ADC_DECIMATOR_CIC_STAGES,
    parameter DIFFERENTIAL_DELAY = `SSEMI_ADC_DECIMATOR_CIC_DIFFERENTIAL_DELAY,
    parameter DECIMATION_FACTOR = `SSEMI_ADC_DECIMATOR_DEFAULT_DECIMATION_FACTOR,
    parameter INPUT_DATA_WIDTH = `SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH,
    parameter OUTPUT_DATA_WIDTH = `SSEMI_ADC_DECIMATOR_CIC_DATA_WIDTH
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  wire i_clk,           // Input clock (100MHz typical)
    input  wire i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  wire i_enable,        // Enable CIC filter operation
    input  wire i_valid,         // Input data valid signal
    output reg  o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  wire [INPUT_DATA_WIDTH-1:0] i_data,   // Input data (16-bit signed)
    output reg  [OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (32-bit signed)
    output reg  o_valid,         // Output data valid signal
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output reg  o_overflow,      // Overflow detection flag
    output reg  o_underflow,     // Underflow detection flag
    output reg  o_busy,          // Filter busy indicator
    output reg  [3:0] o_stage_status  // Status of each CIC stage
);

    //==============================================================================
    // Error Type Constants (replacing enum)
    //==============================================================================
    parameter SSEMI_ADC_DECIMATOR_CIC_ERROR_NONE = 2'b00;
    parameter SSEMI_ADC_DECIMATOR_CIC_ERROR_OVERFLOW = 2'b01;
    parameter SSEMI_ADC_DECIMATOR_CIC_ERROR_UNDERFLOW = 2'b10;
    parameter SSEMI_ADC_DECIMATOR_CIC_ERROR_RESERVED = 2'b11;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages (verification only)
    //==============================================================================
`ifdef SSEMI_ADC_DECIMATOR_VERIFICATION
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (CIC_STAGES < 1 || CIC_STAGES > 8) begin
            $error("SSEMI_CIC_FILTER: CIC_STAGES must be between 1 and 8, got %d", CIC_STAGES);
        end
        
        if (DIFFERENTIAL_DELAY < 1 || DIFFERENTIAL_DELAY > 4) begin
            $error("SSEMI_CIC_FILTER: DIFFERENTIAL_DELAY must be between 1 and 4, got %d", DIFFERENTIAL_DELAY);
        end
        
                if (DECIMATION_FACTOR < `SSEMI_ADC_DECIMATOR_MIN_DECIMATION_FACTOR ||
            DECIMATION_FACTOR > `SSEMI_ADC_DECIMATOR_MAX_DECIMATION_FACTOR) begin
            $error("SSEMI_CIC_FILTER: DECIMATION_FACTOR must be between %d and %d, got %d",
                   `SSEMI_ADC_DECIMATOR_MIN_DECIMATION_FACTOR, `SSEMI_ADC_DECIMATOR_MAX_DECIMATION_FACTOR, DECIMATION_FACTOR);
        end
        
        if (INPUT_DATA_WIDTH < 8 || INPUT_DATA_WIDTH > 24) begin
            $error("SSEMI_CIC_FILTER: INPUT_DATA_WIDTH must be between 8 and 24, got %d", INPUT_DATA_WIDTH);
        end
        
        if (OUTPUT_DATA_WIDTH < INPUT_DATA_WIDTH || OUTPUT_DATA_WIDTH > 48) begin
            $error("SSEMI_CIC_FILTER: OUTPUT_DATA_WIDTH must be between %d and 48, got %d", 
                   INPUT_DATA_WIDTH, OUTPUT_DATA_WIDTH);
        end
        
        // Check for power-of-2 decimation factor (recommended)
        if ((DECIMATION_FACTOR & (DECIMATION_FACTOR - 1)) != 0) begin
            $warning("SSEMI_CIC_FILTER: DECIMATION_FACTOR %d is not a power of 2, may cause timing issues", 
                     DECIMATION_FACTOR);
        end
        
        // Display configuration summary
        $info("SSEMI_CIC_FILTER: Configuration - Stages: %d, Delay: %d, Decimation: %d, Input: %d-bit, Output: %d-bit",
              CIC_STAGES, DIFFERENTIAL_DELAY, DECIMATION_FACTOR, INPUT_DATA_WIDTH, OUTPUT_DATA_WIDTH);
    end
`endif

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Integrator stage registers
    reg [OUTPUT_DATA_WIDTH-1:0] integrator_regs [0:CIC_STAGES-1];
    reg [OUTPUT_DATA_WIDTH-1:0] integrator_next [0:CIC_STAGES-1];
    
    // Comb stage registers
    reg [OUTPUT_DATA_WIDTH-1:0] comb_regs [0:CIC_STAGES-1][0:DIFFERENTIAL_DELAY-1];
    reg [OUTPUT_DATA_WIDTH-1:0] comb_next [0:CIC_STAGES-1][0:DIFFERENTIAL_DELAY-1];
    
    // Decimation control
    reg [15:0] decimation_counter;
    reg decimation_enable;
    reg sample_ready;
    
    // Error detection
    reg overflow_detected;
    reg underflow_detected;
    reg [CIC_STAGES-1:0] stage_overflow;
    reg [CIC_STAGES-1:0] stage_underflow;
    
    // Status tracking
    reg [3:0] stage_status_reg;
    reg busy_reg;
    
    //==============================================================================
    // Decimation Control Logic
    //==============================================================================
    
    // Decimation counter for controlling output rate
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            decimation_counter <= 16'h0000;
            decimation_enable <= 1'b0;
        end else if (!i_enable) begin
            decimation_counter <= 16'h0000;
            decimation_enable <= 1'b0;
        end else if (i_valid) begin
            if (decimation_counter == DECIMATION_FACTOR - 1) begin
                decimation_counter <= 16'h0000;
                decimation_enable <= 1'b1;
            end else begin
                decimation_counter <= decimation_counter + 1'b1;
                decimation_enable <= 1'b0;
            end
        end else begin
            decimation_enable <= 1'b0;
        end
    end

    //==============================================================================
    // Integrator Stage Implementation
    //==============================================================================
    
    // Integrator stages with overflow detection
    genvar i;
    generate
        for (i = 0; i < CIC_STAGES; i = i + 1) begin : integrator_stages
            always @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) begin
                    integrator_regs[i] <= '0;
                    stage_overflow[i] <= 1'b0;
                    stage_underflow[i] <= 1'b0;
                end else if (!i_enable) begin
                    integrator_regs[i] <= '0;
                    stage_overflow[i] <= 1'b0;
                    stage_underflow[i] <= 1'b0;
                end else if (i_valid) begin
                    integrator_regs[i] <= integrator_next[i];
                    
                    // Overflow/underflow detection for each stage
                    if (integrator_next[i] > {1'b0, {(OUTPUT_DATA_WIDTH-1){1'b1}}}) begin
                        stage_overflow[i] <= 1'b1;
                    end else if (integrator_next[i] < {1'b1, {(OUTPUT_DATA_WIDTH-1){1'b0}}}) begin
                        stage_underflow[i] <= 1'b1;
                    end else begin
                        stage_overflow[i] <= 1'b0;
                        stage_underflow[i] <= 1'b0;
                    end
                end
            end
            
            // Integrator computation with saturation
            always @(*) begin
                if (i == 0) begin
                    // First stage: add input data
                    integrator_next[i] = integrator_regs[i] + {{(OUTPUT_DATA_WIDTH-INPUT_DATA_WIDTH){i_data[INPUT_DATA_WIDTH-1]}}, i_data};
                end else begin
                    // Subsequent stages: add previous stage output
                    integrator_next[i] = integrator_regs[i] + integrator_regs[i-1];
                end
                
                // Saturation logic to prevent overflow
                if (integrator_next[i] > {1'b0, {(OUTPUT_DATA_WIDTH-1){1'b1}}}) begin
                    integrator_next[i] = {1'b0, {(OUTPUT_DATA_WIDTH-1){1'b1}}};
                end else if (integrator_next[i] < {1'b1, {(OUTPUT_DATA_WIDTH-1){1'b0}}}) begin
                    integrator_next[i] = {1'b1, {(OUTPUT_DATA_WIDTH-1){1'b0}}};
                end
            end
        end
    endgenerate

    //==============================================================================
    // Comb Stage Implementation
    //==============================================================================
    
    // Comb stages with differential delay
    genvar j, k;
    generate
        for (j = 0; j < CIC_STAGES; j = j + 1) begin : comb_stages
            for (k = 0; k < DIFFERENTIAL_DELAY; k = k + 1) begin : delay_elements
                always @(posedge i_clk or negedge i_rst_n) begin
                    if (!i_rst_n) begin
                        comb_regs[j][k] <= '0;
                    end else if (!i_enable) begin
                        comb_regs[j][k] <= '0;
                    end else if (decimation_enable) begin
                        comb_regs[j][k] <= comb_next[j][k];
                    end
                end
                
                // Comb computation
                always @(*) begin
                    if (j == 0) begin
                        if (k == 0) begin
                            // First delay element: store integrator output
                            comb_next[j][k] = integrator_regs[CIC_STAGES-1];
                        end else begin
                            // Subsequent delay elements: shift data
                            comb_next[j][k] = comb_regs[j][k-1];
                        end
                    end else begin
                        if (k == 0) begin
                            // First delay element: store previous stage output
                            comb_next[j][k] = comb_regs[j-1][DIFFERENTIAL_DELAY-1] - comb_regs[j-1][0];
                        end else begin
                            // Subsequent delay elements: shift data
                            comb_next[j][k] = comb_regs[j][k-1];
                        end
                    end
                end
            end
        end
    endgenerate

    //==============================================================================
    // Output Generation and Error Detection
    //==============================================================================
    
    // Output data assignment
    assign o_data = comb_regs[CIC_STAGES-1][DIFFERENTIAL_DELAY-1] - comb_regs[CIC_STAGES-1][0];
    assign o_valid = decimation_enable && i_enable;
    
    // Error detection
    assign overflow_detected = |stage_overflow;
    assign underflow_detected = |stage_underflow;
    
    // Status tracking
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            stage_status_reg <= 4'h0;
            busy_reg <= 1'b0;
        end else if (!i_enable) begin
            stage_status_reg <= 4'h0;
            busy_reg <= 1'b0;
        end else begin
            busy_reg <= i_valid || decimation_enable;
            stage_status_reg <= {
                overflow_detected,     // bit 3: Overflow detected
                underflow_detected,    // bit 2: Underflow detected
                decimation_enable,     // bit 1: Decimation active
                i_valid               // bit 0: Input valid
            };
        end
    end

    //==============================================================================
    // Output Assignments
    //==============================================================================
    
    assign o_ready = i_enable && !busy_reg;
    assign o_overflow = overflow_detected;
    assign o_underflow = underflow_detected;
    assign o_busy = busy_reg;
    assign o_stage_status = stage_status_reg;

endmodule

`endif // SSEMI_CIC_FILTER_V
