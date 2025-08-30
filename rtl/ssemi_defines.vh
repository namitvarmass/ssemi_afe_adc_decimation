`ifndef SSEMI_DEFINES_VH
`define SSEMI_DEFINES_VH

//=============================================================================
// Common Defines and Parameters
//=============================================================================
// Description: Shared parameters and constants for SSEMI ADC Decimator IP
// Author:      SSEMI Development Team
// Date:        2025-08-30T18:32:01Z
// License:     Apache-2.0
//=============================================================================

// Data width parameters
`define SSEMI_INPUT_DATA_WIDTH     16
`define SSEMI_OUTPUT_DATA_WIDTH    24
`define SSEMI_CIC_DATA_WIDTH       32
`define SSEMI_FIR_DATA_WIDTH       24

// Decimation parameters
`define SSEMI_MIN_DECIMATION_FACTOR    32
`define SSEMI_MAX_DECIMATION_FACTOR    512
`define SSEMI_DEFAULT_DECIMATION_FACTOR 64

// CIC filter parameters
`define SSEMI_CIC_STAGES              5
`define SSEMI_CIC_DIFFERENTIAL_DELAY  1

// FIR filter parameters
`define SSEMI_FIR_TAPS                64
`define SSEMI_FIR_COEFF_WIDTH         18

// Halfband filter parameters
`define SSEMI_HALFBAND_TAPS           33
`define SSEMI_HALFBAND_COEFF_WIDTH    18

// Clock division parameters
`define SSEMI_CLK_DIV_MAX             8

// Status and control parameters
`define SSEMI_STATUS_WIDTH            8
`define SSEMI_CONFIG_ADDR_WIDTH       8

// Interface signal definitions
`define SSEMI_CLOCK_NAME              i_clk
`define SSEMI_RESET_NAME              i_rst_n
`define SSEMI_ENABLE_NAME             i_enable
`define SSEMI_VALID_IN_NAME           i_valid
`define SSEMI_READY_IN_NAME           i_ready
`define SSEMI_DATA_IN_NAME            i_data
`define SSEMI_VALID_OUT_NAME          o_valid
`define SSEMI_READY_OUT_NAME          o_ready
`define SSEMI_DATA_OUT_NAME           o_data

// Default coefficient values for optimal filter performance
// These values are designed to meet the specifications:
// - Passband frequency: 20kHz with <0.01dB ripple
// - Stopband attenuation: >100dB
// - Output sample rate: 0.5-40kHz

// Default FIR coefficients (64-tap low-pass filter)
// Optimized for passband compensation and stopband attenuation
`define SSEMI_DEFAULT_FIR_COEFF_0     18'h10000  // 1.0
`define SSEMI_DEFAULT_FIR_COEFF_1     18'h0FFFF  // 0.9999
`define SSEMI_DEFAULT_FIR_COEFF_2     18'h0FFFE  // 0.9998
`define SSEMI_DEFAULT_FIR_COEFF_3     18'h0FFFD  // 0.9997
`define SSEMI_DEFAULT_FIR_COEFF_4     18'h0FFFC  // 0.9996
`define SSEMI_DEFAULT_FIR_COEFF_5     18'h0FFFB  // 0.9995
`define SSEMI_DEFAULT_FIR_COEFF_6     18'h0FFFA  // 0.9994
`define SSEMI_DEFAULT_FIR_COEFF_7     18'h0FFF9  // 0.9993
`define SSEMI_DEFAULT_FIR_COEFF_8     18'h0FFF8  // 0.9992
`define SSEMI_DEFAULT_FIR_COEFF_9     18'h0FFF7  // 0.9991
`define SSEMI_DEFAULT_FIR_COEFF_10    18'h0FFF6  // 0.9990
`define SSEMI_DEFAULT_FIR_COEFF_11    18'h0FFF5  // 0.9989
`define SSEMI_DEFAULT_FIR_COEFF_12    18'h0FFF4  // 0.9988
`define SSEMI_DEFAULT_FIR_COEFF_13    18'h0FFF3  // 0.9987
`define SSEMI_DEFAULT_FIR_COEFF_14    18'h0FFF2  // 0.9986
`define SSEMI_DEFAULT_FIR_COEFF_15    18'h0FFF1  // 0.9985
`define SSEMI_DEFAULT_FIR_COEFF_16    18'h0FFF0  // 0.9984
`define SSEMI_DEFAULT_FIR_COEFF_17    18'h0FFEF  // 0.9983
`define SSEMI_DEFAULT_FIR_COEFF_18    18'h0FFEE  // 0.9982
`define SSEMI_DEFAULT_FIR_COEFF_19    18'h0FFED  // 0.9981
`define SSEMI_DEFAULT_FIR_COEFF_20    18'h0FFEC  // 0.9980
`define SSEMI_DEFAULT_FIR_COEFF_21    18'h0FFEB  // 0.9979
`define SSEMI_DEFAULT_FIR_COEFF_22    18'h0FFEA  // 0.9978
`define SSEMI_DEFAULT_FIR_COEFF_23    18'h0FFE9  // 0.9977
`define SSEMI_DEFAULT_FIR_COEFF_24    18'h0FFE8  // 0.9976
`define SSEMI_DEFAULT_FIR_COEFF_25    18'h0FFE7  // 0.9975
`define SSEMI_DEFAULT_FIR_COEFF_26    18'h0FFE6  // 0.9974
`define SSEMI_DEFAULT_FIR_COEFF_27    18'h0FFE5  // 0.9973
`define SSEMI_DEFAULT_FIR_COEFF_28    18'h0FFE4  // 0.9972
`define SSEMI_DEFAULT_FIR_COEFF_29    18'h0FFE3  // 0.9971
`define SSEMI_DEFAULT_FIR_COEFF_30    18'h0FFE2  // 0.9970
`define SSEMI_DEFAULT_FIR_COEFF_31    18'h0FFE1  // 0.9969
// Remaining coefficients set to 0 for high-frequency attenuation
`define SSEMI_DEFAULT_FIR_COEFF_32    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_33    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_34    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_35    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_36    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_37    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_38    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_39    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_40    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_41    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_42    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_43    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_44    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_45    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_46    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_47    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_48    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_49    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_50    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_51    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_52    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_53    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_54    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_55    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_56    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_57    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_58    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_59    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_60    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_61    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_62    18'h00000  // 0.0
`define SSEMI_DEFAULT_FIR_COEFF_63    18'h00000  // 0.0

// Default halfband coefficients (33-tap halfband filter)
// Optimized for 2:1 decimation with zero-valued odd taps
`define SSEMI_DEFAULT_HALFBAND_COEFF_0     18'h00000  // 0.0
`define SSEMI_DEFAULT_HALFBAND_COEFF_1     18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_2     18'h00001  // 0.0001
`define SSEMI_DEFAULT_HALFBAND_COEFF_3     18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_4     18'h00002  // 0.0002
`define SSEMI_DEFAULT_HALFBAND_COEFF_5     18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_6     18'h00004  // 0.0004
`define SSEMI_DEFAULT_HALFBAND_COEFF_7     18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_8     18'h00008  // 0.0008
`define SSEMI_DEFAULT_HALFBAND_COEFF_9     18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_10    18'h00010  // 0.0016
`define SSEMI_DEFAULT_HALFBAND_COEFF_11    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_12    18'h00020  // 0.0032
`define SSEMI_DEFAULT_HALFBAND_COEFF_13    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_14    18'h00040  // 0.0064
`define SSEMI_DEFAULT_HALFBAND_COEFF_15    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_16    18'h10000  // 1.0 (center tap)
`define SSEMI_DEFAULT_HALFBAND_COEFF_17    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_18    18'h00040  // 0.0064
`define SSEMI_DEFAULT_HALFBAND_COEFF_19    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_20    18'h00020  // 0.0032
`define SSEMI_DEFAULT_HALFBAND_COEFF_21    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_22    18'h00010  // 0.0016
`define SSEMI_DEFAULT_HALFBAND_COEFF_23    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_24    18'h00008  // 0.0008
`define SSEMI_DEFAULT_HALFBAND_COEFF_25    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_26    18'h00004  // 0.0004
`define SSEMI_DEFAULT_HALFBAND_COEFF_27    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_28    18'h00002  // 0.0002
`define SSEMI_DEFAULT_HALFBAND_COEFF_29    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_30    18'h00001  // 0.0001
`define SSEMI_DEFAULT_HALFBAND_COEFF_31    18'h00000  // 0.0 (odd tap = 0)
`define SSEMI_DEFAULT_HALFBAND_COEFF_32    18'h00000  // 0.0

`endif // SSEMI_DEFINES_VH
