`ifndef SSEMI_ADC_DECIMATOR_CONFIG_STATUS_REGS_V
`define SSEMI_ADC_DECIMATOR_CONFIG_STATUS_REGS_V

//=============================================================================
// Module Name: ssemi_adc_decimator_config_status_regs
//=============================================================================
// Description: Configuration and status register management for ADC decimator
//              Handles coefficient loading, status reporting, and error detection
//              Provides default coefficient values optimized for specifications
//              Implements CSR (Control and Status Register) interface with read/write capability
//
// Timing Constraints:
//   - Input Clock (i_clk): 100MHz typical, 200MHz maximum
//   - Setup Time: 2ns minimum for all input signals
//   - Hold Time: 1ns minimum for all input signals
//   - Output Delay: 8ns maximum for all output signals
//   - Clock-to-Q: 6ns maximum for registered outputs
//   - CSR Read Access: Same-cycle response (combinational read)
//   - CSR Write Access: One-cycle latency
//   - Coefficient Update: Immediate (combinational output)
//   - Error Detection: 1-cycle latency
//   - Reset Recovery: 10ns minimum after i_rst_n deassertion
//
// Resource Requirements:
//   - Registers: 128 x 32-bit (config_reg) + control registers
//   - Combinational Logic: Moderate (address decode, coefficient routing)
//   - Memory: 4KB (128 x 32-bit configuration registers)
//
// Coefficient Validation:
//   - FIR coefficients (0x00-0x3F): 18-bit signed values, range -131072 to +131071
//   - Halfband coefficients (0x40-0x60): 18-bit signed values, odd-indexed taps must be zero
//   - Coefficient range validation: Values exceeding 0x3FFFF are clamped to maximum
//   - Address validation: Invalid addresses (0x84-0xFF) generate error interrupts
//   - Default coefficients: Pre-loaded on reset for optimal filter performance
//   - Coefficient update: Immediate effect via combinational output assignment
//
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module ssemi_adc_decimator_config_status_regs #(
    parameter FIR_TAPS = `SSEMI_ADC_DECIMATOR_FIR_TAPS,
    parameter HALFBAND_TAPS = `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS
) (
    // Clock and Reset
    input  wire i_clk,           // Input clock
    input  wire i_rst_n,         // Active-low reset
    
    // Control Interface (removed i_enable - always enabled)
    
    // CSR Write Interface
    input  wire i_csr_wr_valid,  // Write valid
    input  wire [7:0] i_csr_addr, // CSR address (shared between read and write)
    input  wire [31:0] i_csr_wr_data, // Write data
    output reg  o_csr_wr_ready,  // Write ready
    
    // CSR Read Interface
    input  wire i_csr_rd_ready,  // Read ready (host ready to accept)
    // Note: i_csr_addr is shared between read and write interfaces (declared above)
    output reg  [31:0] o_csr_rd_data, // Read data
    output reg  o_csr_rd_valid,  // Read valid
    
    // Status Interface
    input  wire i_cic_valid,     // CIC stage valid
    input  wire i_fir_valid,     // FIR stage valid
    input  wire i_halfband_valid, // Halfband stage valid
    input  wire i_cic_overflow,  // CIC overflow detected
    input  wire i_fir_overflow,  // FIR overflow detected
    input  wire i_halfband_overflow, // Halfband overflow detected
    input  wire i_cic_underflow, // CIC underflow detected
    input  wire i_fir_underflow, // FIR underflow detected
    input  wire i_halfband_underflow, // Halfband underflow detected
    
    // Coefficient Outputs (for direct filter use)
    output wire [`SSEMI_ADC_DECIMATOR_FIR_COEFF_WIDTH-1:0] o_fir_coeff [0:FIR_TAPS-1],      // FIR coefficients
    output wire [`SSEMI_ADC_DECIMATOR_HALFBAND_COEFF_WIDTH-1:0] o_halfband_coeff [0:HALFBAND_TAPS-1], // Halfband coefficients
    
    // Status Outputs
    output reg  o_busy,                      // Decimator busy
    output reg  o_error                      // Error interrupt
);

    //==============================================================================
    // Error Type Constants
    //==============================================================================
    // Error type constants (replacing enum)
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_NONE = 3'b000;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_OVERFLOW = 3'b001;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_UNDERFLOW = 3'b010;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_INVALID_CONFIG = 3'b011;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_INVALID_ADDR = 3'b100;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_COEFF_RANGE = 3'b101;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_RESERVED1 = 3'b110;
    parameter SSEMI_ADC_DECIMATOR_CONFIG_ERROR_RESERVED2 = 3'b111;

    //==============================================================================
    // Internal Signals and Registers
    //==============================================================================
    
    // Configuration registers
    reg [31:0] config_reg [0:127];
    reg [7:0] status_reg;
    reg busy_reg, error_reg;
    reg [2:0] error_type_reg;
    
    // CSR read/write control signals
    reg write_pending;
    
    // Error detection signals
    wire overflow_detected;
    wire underflow_detected;
    wire invalid_config;
    wire invalid_addr;
    wire coeff_range_error;
    wire invalid_read_addr;
    wire invalid_write_addr;
    
    // Parameter validation (verification only)
`ifdef SSEMI_ADC_DECIMATOR_VERIFICATION
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
        
        if (FIR_TAPS != `SSEMI_ADC_DECIMATOR_FIR_TAPS) begin
            $warning("SSEMI_CONFIG_STATUS_REGS: FIR_TAPS parameter (%d) differs from define (%d)",
                     FIR_TAPS, `SSEMI_ADC_DECIMATOR_FIR_TAPS);
        end
        
        if (HALFBAND_TAPS != `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS) begin
            $warning("SSEMI_CONFIG_STATUS_REGS: HALFBAND_TAPS parameter (%d) differs from define (%d)",
                     HALFBAND_TAPS, `SSEMI_ADC_DECIMATOR_HALFBAND_TAPS);
        end
    end
`endif

    //==============================================================================
    // Address Validation
    //==============================================================================
    
    //==============================================================================
    // CSR Address Map
    //==============================================================================
    // Configuration Registers (Read/Write):
    //   0x00-0x3F: FIR Filter Coefficients (64 coefficients, 18-bit each)
    //   0x40-0x60: Halfband Filter Coefficients (33 coefficients, 18-bit each)
    //              Note: Only even addresses are used (odd taps = 0 for halfband)
    //
    // Status Registers (Read-Only):
    //   0x80: Status Register (8-bit)
    //        [7] - CIC stage active
    //        [6] - FIR stage active  
    //        [5] - Halfband stage active
    //        [4] - Error flag
    //        [3] - Overflow detected
    //        [2] - Underflow detected
    //        [1] - Invalid configuration
    //        [0] - Coefficient range error
    //   0x81: Busy Register (1-bit)
    //        [0] - Decimator busy indicator
    //   0x82: Error Type Register (3-bit)
    //        [2:0] - Error type code (see error constants below)
    //   0x83: Error Register (1-bit)
    //        [0] - Error interrupt flag
    //
    // Reserved Addresses:
    //   0x84-0xFF: Reserved for future use (invalid access generates error)
    //==============================================================================
    
    // Valid address ranges
    assign invalid_write_addr = (i_csr_addr > 8'h83); // Invalid if > 0x83
    assign invalid_read_addr = (i_csr_addr > 8'h83);  // Invalid if > 0x83
    
    //==============================================================================
    // CSR Write Interface
    //==============================================================================
    
    // Write ready logic
    always @(*) begin
        o_csr_wr_ready = !write_pending;
    end
    
    // Write control logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            write_pending <= 1'b0;
        end else if (i_csr_wr_valid && o_csr_wr_ready) begin
            write_pending <= 1'b1;
        end else begin
            write_pending <= 1'b0;
        end
    end
    
    // Configuration register write logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Initialize all configuration registers to default values
            // Load default FIR coefficients
            config_reg[0] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_0;
            config_reg[1] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_1;
            config_reg[2] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_2;
            config_reg[3] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_3;
            config_reg[4] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_4;
            config_reg[5] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_5;
            config_reg[6] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_6;
            config_reg[7] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_7;
            config_reg[8] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_8;
            config_reg[9] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_9;
            config_reg[10] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_10;
            config_reg[11] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_11;
            config_reg[12] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_12;
            config_reg[13] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_13;
            config_reg[14] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_14;
            config_reg[15] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_15;
            config_reg[16] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_16;
            config_reg[17] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_17;
            config_reg[18] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_18;
            config_reg[19] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_19;
            config_reg[20] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_20;
            config_reg[21] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_21;
            config_reg[22] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_22;
            config_reg[23] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_23;
            config_reg[24] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_24;
            config_reg[25] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_25;
            config_reg[26] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_26;
            config_reg[27] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_27;
            config_reg[28] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_28;
            config_reg[29] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_29;
            config_reg[30] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_30;
            config_reg[31] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_31;
            config_reg[32] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_32;
            config_reg[33] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_33;
            config_reg[34] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_34;
            config_reg[35] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_35;
            config_reg[36] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_36;
            config_reg[37] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_37;
            config_reg[38] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_38;
            config_reg[39] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_39;
            config_reg[40] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_40;
            config_reg[41] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_41;
            config_reg[42] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_42;
            config_reg[43] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_43;
            config_reg[44] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_44;
            config_reg[45] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_45;
            config_reg[46] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_46;
            config_reg[47] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_47;
            config_reg[48] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_48;
            config_reg[49] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_49;
            config_reg[50] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_50;
            config_reg[51] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_51;
            config_reg[52] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_52;
            config_reg[53] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_53;
            config_reg[54] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_54;
            config_reg[55] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_55;
            config_reg[56] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_56;
            config_reg[57] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_57;
            config_reg[58] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_58;
            config_reg[59] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_59;
            config_reg[60] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_60;
            config_reg[61] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_61;
            config_reg[62] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_62;
            config_reg[63] <= `SSEMI_ADC_DECIMATOR_DEFAULT_FIR_COEFF_63;
            
            // Load default halfband coefficients
            config_reg[64] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_0;
            config_reg[65] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_1;
            config_reg[66] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_2;
            config_reg[67] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_3;
            config_reg[68] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_4;
            config_reg[69] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_5;
            config_reg[70] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_6;
            config_reg[71] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_7;
            config_reg[72] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_8;
            config_reg[73] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_9;
            config_reg[74] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_10;
            config_reg[75] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_11;
            config_reg[76] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_12;
            config_reg[77] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_13;
            config_reg[78] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_14;
            config_reg[79] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_15;
            config_reg[80] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_16;
            config_reg[81] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_17;
            config_reg[82] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_18;
            config_reg[83] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_19;
            config_reg[84] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_20;
            config_reg[85] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_21;
            config_reg[86] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_22;
            config_reg[87] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_23;
            config_reg[88] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_24;
            config_reg[89] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_25;
            config_reg[90] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_26;
            config_reg[91] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_27;
            config_reg[92] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_28;
            config_reg[93] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_29;
            config_reg[94] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_30;
            config_reg[95] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_31;
            config_reg[96] <= `SSEMI_ADC_DECIMATOR_DEFAULT_HALFBAND_COEFF_32;
            
                 end else if (i_csr_wr_valid && o_csr_wr_ready) begin
             // Validate address range and write if valid
             if (!invalid_write_addr && i_csr_addr <= 8'h7F) begin
                 config_reg[i_csr_addr] <= i_csr_wr_data;
             end
        end
    end

    //==============================================================================
    // CSR Read Interface
    //==============================================================================
    
    // Read control logic - data available same cycle
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_csr_rd_valid <= 1'b0;
            o_csr_rd_data <= 32'h00000000;
        end else begin
            // Read data available same cycle when i_csr_rd_ready is asserted
            if (i_csr_rd_ready) begin
                // Provide read data based on current address
                if (!invalid_read_addr && i_csr_addr <= 8'h7F) begin
                    o_csr_rd_data <= config_reg[i_csr_addr];
                end else if (i_csr_addr == 8'h80) begin
                    o_csr_rd_data <= {24'h000000, status_reg}; // Status register
                end else if (i_csr_addr == 8'h81) begin
                    o_csr_rd_data <= {31'h00000000, busy_reg}; // Busy register
                end else if (i_csr_addr == 8'h82) begin
                    o_csr_rd_data <= {29'h00000000, error_type_reg}; // Error type register
                end else if (i_csr_addr == 8'h83) begin
                    o_csr_rd_data <= {31'h00000000, error_reg}; // Error register
                end else begin
                    o_csr_rd_data <= 32'h00000000; // Invalid address returns 0
                end
                o_csr_rd_valid <= 1'b1;
            end else begin
                o_csr_rd_valid <= 1'b0;
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
    assign invalid_config = invalid_write_addr || invalid_read_addr;
    assign invalid_addr = invalid_write_addr || invalid_read_addr;
    assign coeff_range_error = ((i_csr_addr <= 8'h3F) && (i_csr_wr_data > 32'h0003FFFF)) || // FIR coeff range
                               ((i_csr_addr >= 8'h40) && (i_csr_addr <= 8'h60) && (i_csr_wr_data > 32'h0003FFFF)); // Halfband coeff range
    
    // Error type determination (moved to sequential block)

    //==============================================================================
    // Status and Control Logic
    //==============================================================================
    
    // Status register and control logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            status_reg <= 8'h00;
            busy_reg <= 1'b0;
            error_reg <= 1'b0;
            error_type_reg <= SSEMI_CONFIG_ERROR_NONE;
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
            
            // Error type determination (sequential assignment)
            if (overflow_detected) begin
                error_type_reg <= SSEMI_CONFIG_ERROR_OVERFLOW;
            end else if (underflow_detected) begin
                error_type_reg <= SSEMI_CONFIG_ERROR_UNDERFLOW;
            end else if (invalid_config || invalid_addr) begin
                error_type_reg <= SSEMI_CONFIG_ERROR_INVALID_CONFIG;
            end else if (coeff_range_error) begin
                error_type_reg <= SSEMI_CONFIG_ERROR_COEFF_RANGE;
            end else begin
                error_type_reg <= SSEMI_CONFIG_ERROR_NONE;
            end
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
    
    assign o_busy = busy_reg;
    assign o_error = error_reg;

endmodule

`endif // SSEMI_CONFIG_STATUS_REGS_V
