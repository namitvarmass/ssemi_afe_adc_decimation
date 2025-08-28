`ifndef SSEMI_CONFIG_STATUS_REGS_SV
`define SSEMI_CONFIG_STATUS_REGS_SV

//=============================================================================
// Module Name: ssemi_config_status_regs
//=============================================================================
// Description: Configuration and status register management for ADC decimator
//              Handles coefficient loading, status reporting, and error detection
//              Provides default coefficient values optimized for specifications
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_config_status_regs #(
    parameter int FIR_TAPS = `SSEMI_FIR_TAPS,
    parameter int HALFBAND_TAPS = `SSEMI_HALFBAND_TAPS
) (
    // Clock and Reset
    input  logic i_clk,           // Input clock
    input  logic i_rst_n,         // Active-low reset
    
    // Control Interface
    input  logic i_enable,        // Enable register access
    input  logic i_config_valid,  // Configuration data valid
    input  logic [7:0] i_config_addr,  // Configuration address
    input  logic [31:0] i_config_data, // Configuration data
    output logic o_config_ready,  // Configuration ready
    
    // Status Interface
    input  logic i_cic_valid,     // CIC stage valid
    input  logic i_fir_valid,     // FIR stage valid
    input  logic i_halfband_valid, // Halfband stage valid
    input  logic i_cic_overflow,  // CIC overflow detected
    input  logic i_fir_overflow,  // FIR overflow detected
    input  logic i_halfband_overflow, // Halfband overflow detected
    input  logic i_cic_underflow, // CIC underflow detected
    input  logic i_fir_underflow, // FIR underflow detected
    input  logic i_halfband_underflow, // Halfband underflow detected
    
    // Coefficient Outputs
    output logic [`SSEMI_FIR_COEFF_WIDTH-1:0] o_fir_coeff [0:FIR_TAPS-1],      // FIR coefficients
    output logic [`SSEMI_HALFBAND_COEFF_WIDTH-1:0] o_halfband_coeff [0:HALFBAND_TAPS-1], // Halfband coefficients
    
    // Status Outputs
    output logic [7:0] o_status,              // Status information
    output logic o_busy,                      // Decimator busy
    output logic o_error,                     // Error flag
    output logic [2:0] o_error_type           // Specific error type
);

    //==============================================================================
    // Type Definitions for Better Type Safety
    //==============================================================================
    typedef logic [`SSEMI_FIR_COEFF_WIDTH-1:0] ssemi_fir_coeff_t;
    typedef logic [`SSEMI_HALFBAND_COEFF_WIDTH-1:0] ssemi_halfband_coeff_t;
    typedef logic [7:0] ssemi_status_t;
    typedef logic [31:0] ssemi_config_data_t;
    typedef logic [7:0] ssemi_config_addr_t;
    typedef logic [2:0] ssemi_error_type_t;
    
    // Error type enumeration
    typedef enum logic [2:0] {
        ERROR_NONE = 3'b000,
        ERROR_OVERFLOW = 3'b001,
        ERROR_UNDERFLOW = 3'b010,
        ERROR_INVALID_CONFIG = 3'b011,
        ERROR_INVALID_ADDR = 3'b100,
        ERROR_COEFF_RANGE = 3'b101,
        ERROR_RESERVED1 = 3'b110,
        ERROR_RESERVED2 = 3'b111
    } error_type_e;

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Configuration registers
    ssemi_config_data_t config_reg [0:255];
    ssemi_status_t status_reg;
    logic busy_reg, error_reg;
    ssemi_error_type_t error_type_reg;
    
    // Error detection signals
    logic overflow_detected;
    logic underflow_detected;
    logic invalid_config;
    logic invalid_addr;
    logic coeff_range_error;
    
    // Parameter validation (verification only)
`ifdef SSEMI_VERIFICATION
    initial begin
        // Comprehensive parameter validation with detailed error messages
        if (FIR_TAPS < 4 || FIR_TAPS > 256) begin
            $error("SSEMI_CONFIG_STATUS_REGS: FIR_TAPS must be between 4 and 256, got %d", FIR_TAPS);
        end
        
        if (HALFBAND_TAPS % 2 == 0) begin
            $error("SSEMI_CONFIG_STATUS_REGS: HALFBAND_TAPS must be odd, got %d", HALFBAND_TAPS);
        end
        
        if (HALFBAND_TAPS < 5 || HALFBAND_TAPS > 128) begin
            $error("SSEMI_CONFIG_STATUS_REGS: HALFBAND_TAPS must be between 5 and 128, got %d", HALFBAND_TAPS);
        end
        
        if (FIR_TAPS != `SSEMI_FIR_TAPS) begin
            $warning("SSEMI_CONFIG_STATUS_REGS: FIR_TAPS parameter (%d) differs from define (%d)", 
                     FIR_TAPS, `SSEMI_FIR_TAPS);
        end
        
        if (HALFBAND_TAPS != `SSEMI_HALFBAND_TAPS) begin
            $warning("SSEMI_CONFIG_STATUS_REGS: HALFBAND_TAPS parameter (%d) differs from define (%d)", 
                     HALFBAND_TAPS, `SSEMI_HALFBAND_TAPS);
        end
    end
`endif

    //==============================================================================
    // Configuration Register Management
    //==============================================================================
    
    // Configuration register write logic
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Initialize configuration registers with default values
            for (int i = 0; i < 256; i = i + 1) begin
                config_reg[i] <= 32'h00000000;
            end
            
            // Load default FIR coefficients
            config_reg[0] <= `SSEMI_DEFAULT_FIR_COEFF_0;
            config_reg[1] <= `SSEMI_DEFAULT_FIR_COEFF_1;
            config_reg[2] <= `SSEMI_DEFAULT_FIR_COEFF_2;
            config_reg[3] <= `SSEMI_DEFAULT_FIR_COEFF_3;
            config_reg[4] <= `SSEMI_DEFAULT_FIR_COEFF_4;
            config_reg[5] <= `SSEMI_DEFAULT_FIR_COEFF_5;
            config_reg[6] <= `SSEMI_DEFAULT_FIR_COEFF_6;
            config_reg[7] <= `SSEMI_DEFAULT_FIR_COEFF_7;
            config_reg[8] <= `SSEMI_DEFAULT_FIR_COEFF_8;
            config_reg[9] <= `SSEMI_DEFAULT_FIR_COEFF_9;
            config_reg[10] <= `SSEMI_DEFAULT_FIR_COEFF_10;
            config_reg[11] <= `SSEMI_DEFAULT_FIR_COEFF_11;
            config_reg[12] <= `SSEMI_DEFAULT_FIR_COEFF_12;
            config_reg[13] <= `SSEMI_DEFAULT_FIR_COEFF_13;
            config_reg[14] <= `SSEMI_DEFAULT_FIR_COEFF_14;
            config_reg[15] <= `SSEMI_DEFAULT_FIR_COEFF_15;
            config_reg[16] <= `SSEMI_DEFAULT_FIR_COEFF_16;
            config_reg[17] <= `SSEMI_DEFAULT_FIR_COEFF_17;
            config_reg[18] <= `SSEMI_DEFAULT_FIR_COEFF_18;
            config_reg[19] <= `SSEMI_DEFAULT_FIR_COEFF_19;
            config_reg[20] <= `SSEMI_DEFAULT_FIR_COEFF_20;
            config_reg[21] <= `SSEMI_DEFAULT_FIR_COEFF_21;
            config_reg[22] <= `SSEMI_DEFAULT_FIR_COEFF_22;
            config_reg[23] <= `SSEMI_DEFAULT_FIR_COEFF_23;
            config_reg[24] <= `SSEMI_DEFAULT_FIR_COEFF_24;
            config_reg[25] <= `SSEMI_DEFAULT_FIR_COEFF_25;
            config_reg[26] <= `SSEMI_DEFAULT_FIR_COEFF_26;
            config_reg[27] <= `SSEMI_DEFAULT_FIR_COEFF_27;
            config_reg[28] <= `SSEMI_DEFAULT_FIR_COEFF_28;
            config_reg[29] <= `SSEMI_DEFAULT_FIR_COEFF_29;
            config_reg[30] <= `SSEMI_DEFAULT_FIR_COEFF_30;
            config_reg[31] <= `SSEMI_DEFAULT_FIR_COEFF_31;
            config_reg[32] <= `SSEMI_DEFAULT_FIR_COEFF_32;
            config_reg[33] <= `SSEMI_DEFAULT_FIR_COEFF_33;
            config_reg[34] <= `SSEMI_DEFAULT_FIR_COEFF_34;
            config_reg[35] <= `SSEMI_DEFAULT_FIR_COEFF_35;
            config_reg[36] <= `SSEMI_DEFAULT_FIR_COEFF_36;
            config_reg[37] <= `SSEMI_DEFAULT_FIR_COEFF_37;
            config_reg[38] <= `SSEMI_DEFAULT_FIR_COEFF_38;
            config_reg[39] <= `SSEMI_DEFAULT_FIR_COEFF_39;
            config_reg[40] <= `SSEMI_DEFAULT_FIR_COEFF_40;
            config_reg[41] <= `SSEMI_DEFAULT_FIR_COEFF_41;
            config_reg[42] <= `SSEMI_DEFAULT_FIR_COEFF_42;
            config_reg[43] <= `SSEMI_DEFAULT_FIR_COEFF_43;
            config_reg[44] <= `SSEMI_DEFAULT_FIR_COEFF_44;
            config_reg[45] <= `SSEMI_DEFAULT_FIR_COEFF_45;
            config_reg[46] <= `SSEMI_DEFAULT_FIR_COEFF_46;
            config_reg[47] <= `SSEMI_DEFAULT_FIR_COEFF_47;
            config_reg[48] <= `SSEMI_DEFAULT_FIR_COEFF_48;
            config_reg[49] <= `SSEMI_DEFAULT_FIR_COEFF_49;
            config_reg[50] <= `SSEMI_DEFAULT_FIR_COEFF_50;
            config_reg[51] <= `SSEMI_DEFAULT_FIR_COEFF_51;
            config_reg[52] <= `SSEMI_DEFAULT_FIR_COEFF_52;
            config_reg[53] <= `SSEMI_DEFAULT_FIR_COEFF_53;
            config_reg[54] <= `SSEMI_DEFAULT_FIR_COEFF_54;
            config_reg[55] <= `SSEMI_DEFAULT_FIR_COEFF_55;
            config_reg[56] <= `SSEMI_DEFAULT_FIR_COEFF_56;
            config_reg[57] <= `SSEMI_DEFAULT_FIR_COEFF_57;
            config_reg[58] <= `SSEMI_DEFAULT_FIR_COEFF_58;
            config_reg[59] <= `SSEMI_DEFAULT_FIR_COEFF_59;
            config_reg[60] <= `SSEMI_DEFAULT_FIR_COEFF_60;
            config_reg[61] <= `SSEMI_DEFAULT_FIR_COEFF_61;
            config_reg[62] <= `SSEMI_DEFAULT_FIR_COEFF_62;
            config_reg[63] <= `SSEMI_DEFAULT_FIR_COEFF_63;
            
            // Load default halfband coefficients
            config_reg[64] <= `SSEMI_DEFAULT_HALFBAND_COEFF_0;
            config_reg[65] <= `SSEMI_DEFAULT_HALFBAND_COEFF_1;
            config_reg[66] <= `SSEMI_DEFAULT_HALFBAND_COEFF_2;
            config_reg[67] <= `SSEMI_DEFAULT_HALFBAND_COEFF_3;
            config_reg[68] <= `SSEMI_DEFAULT_HALFBAND_COEFF_4;
            config_reg[69] <= `SSEMI_DEFAULT_HALFBAND_COEFF_5;
            config_reg[70] <= `SSEMI_DEFAULT_HALFBAND_COEFF_6;
            config_reg[71] <= `SSEMI_DEFAULT_HALFBAND_COEFF_7;
            config_reg[72] <= `SSEMI_DEFAULT_HALFBAND_COEFF_8;
            config_reg[73] <= `SSEMI_DEFAULT_HALFBAND_COEFF_9;
            config_reg[74] <= `SSEMI_DEFAULT_HALFBAND_COEFF_10;
            config_reg[75] <= `SSEMI_DEFAULT_HALFBAND_COEFF_11;
            config_reg[76] <= `SSEMI_DEFAULT_HALFBAND_COEFF_12;
            config_reg[77] <= `SSEMI_DEFAULT_HALFBAND_COEFF_13;
            config_reg[78] <= `SSEMI_DEFAULT_HALFBAND_COEFF_14;
            config_reg[79] <= `SSEMI_DEFAULT_HALFBAND_COEFF_15;
            config_reg[80] <= `SSEMI_DEFAULT_HALFBAND_COEFF_16;
            config_reg[81] <= `SSEMI_DEFAULT_HALFBAND_COEFF_17;
            config_reg[82] <= `SSEMI_DEFAULT_HALFBAND_COEFF_18;
            config_reg[83] <= `SSEMI_DEFAULT_HALFBAND_COEFF_19;
            config_reg[84] <= `SSEMI_DEFAULT_HALFBAND_COEFF_20;
            config_reg[85] <= `SSEMI_DEFAULT_HALFBAND_COEFF_21;
            config_reg[86] <= `SSEMI_DEFAULT_HALFBAND_COEFF_22;
            config_reg[87] <= `SSEMI_DEFAULT_HALFBAND_COEFF_23;
            config_reg[88] <= `SSEMI_DEFAULT_HALFBAND_COEFF_24;
            config_reg[89] <= `SSEMI_DEFAULT_HALFBAND_COEFF_25;
            config_reg[90] <= `SSEMI_DEFAULT_HALFBAND_COEFF_26;
            config_reg[91] <= `SSEMI_DEFAULT_HALFBAND_COEFF_27;
            config_reg[92] <= `SSEMI_DEFAULT_HALFBAND_COEFF_28;
            config_reg[93] <= `SSEMI_DEFAULT_HALFBAND_COEFF_29;
            config_reg[94] <= `SSEMI_DEFAULT_HALFBAND_COEFF_30;
            config_reg[95] <= `SSEMI_DEFAULT_HALFBAND_COEFF_31;
            config_reg[96] <= `SSEMI_DEFAULT_HALFBAND_COEFF_32;
            
        end else if (!i_enable) begin
            // Keep current values when disabled
        end else if (i_config_valid) begin
            // Validate address range
            if (i_config_addr <= 8'hFF) begin
                config_reg[i_config_addr] <= i_config_data;
            end
        end
    end

    //==============================================================================
    // Error Detection and Reporting
    //==============================================================================
    
    // Overflow/underflow detection
    assign overflow_detected = i_cic_overflow || i_fir_overflow || i_halfband_overflow;
    assign underflow_detected = i_cic_underflow || i_fir_underflow || i_halfband_underflow;
    
    // Configuration validation
    assign invalid_config = (i_config_addr > 8'hFF);
    assign invalid_addr = (i_config_addr < 8'h00) || (i_config_addr > 8'hFF);
    assign coeff_range_error = (i_config_addr >= 8'h40) && (i_config_addr <= 8'h60) && 
                               (i_config_data > 32'h0003FFFF); // Check coefficient range
    
    // Error type determination
    always_comb begin
        if (overflow_detected) begin
            error_type_reg = ERROR_OVERFLOW;
        end else if (underflow_detected) begin
            error_type_reg = ERROR_UNDERFLOW;
        end else if (invalid_config || invalid_addr) begin
            error_type_reg = ERROR_INVALID_CONFIG;
        end else if (coeff_range_error) begin
            error_type_reg = ERROR_COEFF_RANGE;
        end else begin
            error_type_reg = ERROR_NONE;
        end
    end

    //==============================================================================
    // Status and Control Logic
    //==============================================================================
    
    // Status register and control logic
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            status_reg <= 8'h00;
            busy_reg <= 1'b0;
            error_reg <= 1'b0;
        end else if (!i_enable) begin
            status_reg <= 8'h00;
            busy_reg <= 1'b0;
            error_reg <= 1'b0;
        end else begin
            busy_reg <= i_cic_valid || i_fir_valid || i_halfband_valid;
            
            // Enhanced status register with detailed information
            status_reg <= {
                i_cic_valid,           // bit 7: CIC stage active
                i_fir_valid,           // bit 6: FIR stage active  
                i_halfband_valid,      // bit 5: Halfband stage active
                error_reg,             // bit 4: Error flag
                overflow_detected,     // bit 3: Overflow detected
                underflow_detected,    // bit 2: Underflow detected
                invalid_config,        // bit 1: Invalid configuration
                coeff_range_error      // bit 0: Coefficient range error
            };
            
            error_reg <= overflow_detected || underflow_detected || 
                        invalid_config || invalid_addr || coeff_range_error;
        end
    end

    //==============================================================================
    // Coefficient Output Assignment
    //==============================================================================
    
    // FIR coefficient assignment
    genvar i;
    generate
        for (i = 0; i < FIR_TAPS; i = i + 1) begin : fir_coeff_gen
            assign o_fir_coeff[i] = config_reg[i][`SSEMI_FIR_COEFF_WIDTH-1:0];
        end
    endgenerate
    
    // Halfband coefficient assignment
    genvar j;
    generate
        for (j = 0; j < HALFBAND_TAPS; j = j + 1) begin : halfband_coeff_gen
            assign o_halfband_coeff[j] = config_reg[j+64][`SSEMI_HALFBAND_COEFF_WIDTH-1:0];
        end
    endgenerate

    //==============================================================================
    // Output Assignments
    //==============================================================================
    
    assign o_config_ready = 1'b1; // Always ready for configuration
    assign o_status = status_reg;
    assign o_busy = busy_reg;
    assign o_error = error_reg;
    assign o_error_type = error_type_reg;

endmodule

`endif // SSEMI_CONFIG_STATUS_REGS_SV
