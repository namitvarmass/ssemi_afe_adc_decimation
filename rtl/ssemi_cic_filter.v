`ifndef SSEMI_CIC_FILTER_V
`define SSEMI_CIC_FILTER_V

//=============================================================================
// Module Name: ssemi_cic_filter
//=============================================================================
// Description: Configurable CIC (Cascaded Integrator-Comb) filter
//              Supports configurable stages and decimation factor
//              Implements Hogenauer's CIC filter architecture
//              Features comprehensive error detection and overflow protection
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_cic_filter #(
    parameter int CIC_STAGES = `SSEMI_CIC_STAGES,           // Number of CIC stages (1-8)
    parameter int DIFFERENTIAL_DELAY = `SSEMI_CIC_DIFFERENTIAL_DELAY, // Differential delay (1-4)
    parameter int DECIMATION_FACTOR = `SSEMI_DEFAULT_DECIMATION_FACTOR, // Decimation factor (32-512)
    parameter int INPUT_DATA_WIDTH = `SSEMI_INPUT_DATA_WIDTH,  // Input data width
    parameter int OUTPUT_DATA_WIDTH = `SSEMI_CIC_DATA_WIDTH    // Output data width
) (
    //==============================================================================
    // Clock and Reset Interface
    //==============================================================================
    input  logic i_clk,           // Input clock (100MHz typical)
    input  logic i_rst_n,         // Active-low asynchronous reset
    
    //==============================================================================
    // Control Interface
    //==============================================================================
    input  logic i_enable,        // Enable CIC filter operation
    input  logic i_valid,         // Input data valid signal
    output logic o_ready,         // Ready to accept input data
    
    //==============================================================================
    // Data Interface
    //==============================================================================
    input  logic [INPUT_DATA_WIDTH-1:0] i_data,   // Input data (16-bit signed)
    output logic [OUTPUT_DATA_WIDTH-1:0] o_data,  // Output data (32-bit signed)
    output logic o_valid,         // Output data valid signal
    
    //==============================================================================
    // Status and Error Interface
    //==============================================================================
    output logic o_overflow,      // Overflow detection flag
    output logic o_underflow,     // Underflow detection flag
    output logic o_busy,          // Filter busy indicator
    output logic [3:0] o_stage_status  // Status of each CIC stage
);

    //==============================================================================
    // Type Definitions for Better Type Safety
    //==============================================================================
    typedef logic [INPUT_DATA_WIDTH-1:0] ssemi_input_data_t;
    typedef logic [OUTPUT_DATA_WIDTH-1:0] ssemi_output_data_t;
    typedef logic [OUTPUT_DATA_WIDTH-1:0] ssemi_integrator_data_t;
    typedef logic [OUTPUT_DATA_WIDTH-1:0] ssemi_comb_data_t;
    typedef logic [3:0] ssemi_stage_status_t;
    typedef logic [15:0] ssemi_decimation_counter_t;
    
    // Error type enumeration
    typedef enum logic [1:0] {
        CIC_ERROR_NONE = 2'b00,
        CIC_ERROR_OVERFLOW = 2'b01,
        CIC_ERROR_UNDERFLOW = 2'b10,
        CIC_ERROR_INVALID_CONFIG = 2'b11
    } cic_error_type_e;

    //==============================================================================
    // Parameter Validation with Detailed Error Messages
    //==============================================================================
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (CIC_STAGES < 1 || CIC_STAGES > 8) begin
            $error("SSEMI_CIC_FILTER: CIC_STAGES must be between 1 and 8, got %d", CIC_STAGES);
        end
        
        if (DIFFERENTIAL_DELAY < 1 || DIFFERENTIAL_DELAY > 4) begin
            $error("SSEMI_CIC_FILTER: DIFFERENTIAL_DELAY must be between 1 and 4, got %d", DIFFERENTIAL_DELAY);
        end
        
        if (DECIMATION_FACTOR < `SSEMI_MIN_DECIMATION_FACTOR || 
            DECIMATION_FACTOR > `SSEMI_MAX_DECIMATION_FACTOR) begin
            $error("SSEMI_CIC_FILTER: DECIMATION_FACTOR must be between %d and %d, got %d", 
                   `SSEMI_MIN_DECIMATION_FACTOR, `SSEMI_MAX_DECIMATION_FACTOR, DECIMATION_FACTOR);
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

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Integrator stage registers
    ssemi_integrator_data_t integrator_regs [0:CIC_STAGES-1];
    ssemi_integrator_data_t integrator_next [0:CIC_STAGES-1];
    
    // Comb stage registers
    ssemi_comb_data_t comb_regs [0:CIC_STAGES-1][0:DIFFERENTIAL_DELAY-1];
    ssemi_comb_data_t comb_next [0:CIC_STAGES-1][0:DIFFERENTIAL_DELAY-1];
    
    // Decimation control
    ssemi_decimation_counter_t decimation_counter;
    logic decimation_enable;
    logic sample_ready;
    
    // Error detection
    logic overflow_detected;
    logic underflow_detected;
    logic [CIC_STAGES-1:0] stage_overflow;
    logic [CIC_STAGES-1:0] stage_underflow;
    
    // Status tracking
    ssemi_stage_status_t stage_status_reg;
    logic busy_reg;
    
    //==============================================================================
    // Decimation Control Logic
    //==============================================================================
    
    // Decimation counter for controlling output rate
    always_ff @(posedge i_clk or negedge i_rst_n) begin
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
            always_ff @(posedge i_clk or negedge i_rst_n) begin
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
            always_comb begin
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
                always_ff @(posedge i_clk or negedge i_rst_n) begin
                    if (!i_rst_n) begin
                        comb_regs[j][k] <= '0;
                    end else if (!i_enable) begin
                        comb_regs[j][k] <= '0;
                    end else if (decimation_enable) begin
                        comb_regs[j][k] <= comb_next[j][k];
                    end
                end
                
                // Comb computation
                always_comb begin
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
    always_ff @(posedge i_clk or negedge i_rst_n) begin
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
