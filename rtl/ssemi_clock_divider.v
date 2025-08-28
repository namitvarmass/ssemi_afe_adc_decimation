`ifndef SSEMI_CLOCK_DIVIDER_V
`define SSEMI_CLOCK_DIVIDER_V

//=============================================================================
// Module Name: ssemi_clock_divider
//=============================================================================
// Description: Configurable clock divider for decimation stages
//              Supports division ratios from 1 to SSEMI_CLK_DIV_MAX
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module ssemi_clock_divider #(
    parameter CLK_DIV_RATIO = 2  // Clock division ratio (1 to SSEMI_CLK_DIV_MAX)
) (
    // Clock and Reset
    input  wire i_clk,           // Input clock
    input  wire i_rst_n,         // Active-low reset
    
    // Control
    input  wire i_enable,        // Enable clock division
    input  wire i_sync_reset,    // Synchronous reset for counter
    
    // Output
    output reg  o_clk_div,       // Divided clock output
    output wire o_clk_div_pos,   // Positive edge of divided clock
    output wire o_clk_div_neg    // Negative edge of divided clock
);

    // Internal signals
    reg [`SSEMI_CLK_DIV_MAX-1:0] clk_counter;
    reg clk_div_reg;
    reg clk_div_pos_reg, clk_div_neg_reg;
    
    // Parameter validation
    initial begin
        if (CLK_DIV_RATIO < 1 || CLK_DIV_RATIO > `SSEMI_CLK_DIV_MAX) begin
            $error("CLK_DIV_RATIO must be between 1 and %d", `SSEMI_CLK_DIV_MAX);
        end
    end
    
    // Clock counter logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            clk_counter <= 0;
        end else if (!i_enable || i_sync_reset) begin
            clk_counter <= 0;
        end else if (clk_counter >= CLK_DIV_RATIO - 1) begin
            clk_counter <= 0;
        end else begin
            clk_counter <= clk_counter + 1;
        end
    end
    
    // Clock division logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            clk_div_reg <= 1'b0;
        end else if (!i_enable || i_sync_reset) begin
            clk_div_reg <= 1'b0;
        end else if (clk_counter == 0) begin
            clk_div_reg <= ~clk_div_reg;
        end
    end
    
    // Edge detection logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            clk_div_pos_reg <= 1'b0;
            clk_div_neg_reg <= 1'b0;
        end else if (!i_enable || i_sync_reset) begin
            clk_div_pos_reg <= 1'b0;
            clk_div_neg_reg <= 1'b0;
        end else begin
            clk_div_pos_reg <= (clk_counter == 0) && !clk_div_reg;
            clk_div_neg_reg <= (clk_counter == 0) && clk_div_reg;
        end
    end
    
    // Output assignments
    assign o_clk_div = clk_div_reg;
    assign o_clk_div_pos = clk_div_pos_reg;
    assign o_clk_div_neg = clk_div_neg_reg;

endmodule

`endif // SSEMI_CLOCK_DIVIDER_V
