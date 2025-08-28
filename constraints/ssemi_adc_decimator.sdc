#=============================================================================
# Synthesis Constraints for SSEMI ADC Decimator
#=============================================================================
# Description: Timing constraints for ADC decimator synthesis
# Author:      SSEMI Development Team
# Date:        2025-08-26T17:54:47Z
# License:     Apache-2.0
#=============================================================================

# Clock definitions
create_clock -name i_clk -period 10.0 [get_ports i_clk]

# Clock uncertainty
set_clock_uncertainty 0.1 [get_clocks i_clk]

# Input delays
set_input_delay -clock i_clk -max 1.0 [get_ports i_data*]
set_input_delay -clock i_clk -max 1.0 [get_ports i_valid]
set_input_delay -clock i_clk -max 1.0 [get_ports i_enable]
set_input_delay -clock i_clk -max 1.0 [get_ports i_config*]

# Output delays
set_output_delay -clock i_clk -max 1.0 [get_ports o_data*]
set_output_delay -clock i_clk -max 1.0 [get_ports o_valid]
set_output_delay -clock i_clk -max 1.0 [get_ports o_ready]
set_output_delay -clock i_clk -max 1.0 [get_ports o_status*]

# False paths
set_false_path -from [get_ports i_rst_n]
set_false_path -to [get_ports o_busy]
set_false_path -to [get_ports o_error]

# Multi-cycle paths for filter stages
set_multicycle_path -setup 2 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */cic_filter/*/D]
set_multicycle_path -hold 1 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */cic_filter/*/D]

set_multicycle_path -setup 4 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */fir_filter/*/D]
set_multicycle_path -hold 1 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */fir_filter/*/D]

set_multicycle_path -setup 8 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */halfband_filter/*/D]
set_multicycle_path -hold 1 -from [get_clocks i_clk] -to [get_clocks i_clk] -through [get_pins */halfband_filter/*/D]

# Area constraints
set_max_area 0

# Power constraints
set_max_dynamic_power 10mW
set_max_leakage_power 1mW

# Operating conditions
set_operating_conditions -library typical

# Wire load model
set_wire_load_model -name "tsmc18_wl10" -library typical

# Don't touch nets
set_dont_touch_network [get_clocks i_clk]
set_dont_touch_network [get_ports i_rst_n]

# Optimization constraints
set_optimize_registers true
set_optimize_multicells true

# End of constraints
