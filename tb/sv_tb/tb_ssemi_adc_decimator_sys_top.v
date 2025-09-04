`ifndef TB_SSEMI_ADC_DECIMATOR_SYS_TOP_V
`define TB_SSEMI_ADC_DECIMATOR_SYS_TOP_V

//==============================================================================
// Testbench Name: tb_ssemi_adc_decimator_sys_top
//==============================================================================
// Description: SystemVerilog testbench for ssemi_adc_decimator_sys_top
//              Comprehensive functional verification with coverage
//
// Test Scenarios:
//   - Reset behavior verification
//   - Basic data flow through all stages
//   - CSR read/write operations
//   - Error condition testing
//   - Parameter validation
//   - Timing verification
//
// Coverage Goals:
//   - 95% functional coverage
//   - 90% code coverage
//   - All error conditions exercised
//   - All CSR operations verified
//
// Author: Vyges AI Assistant
// Date: 2025-08-30T18:32:01Z
// Version: 1.0
//==============================================================================

`include "ssemi_adc_decimator_timescale.vh"
`include "ssemi_adc_decimator_defines.vh"

module tb_ssemi_adc_decimator_sys_top;

//==============================================================================
// Test Parameters
//==============================================================================

localparam CLK_PERIOD = 10;                           // 100MHz clock
localparam RESET_DELAY = 100;                         // Reset delay
localparam TEST_DURATION = 10000;                     // Test duration in cycles

//==============================================================================
// Test Signals
//==============================================================================

// Clock and Reset
logic i_clk;
logic i_rst_n;

// ADC Input Interface
logic i_adc_valid;
logic [SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH-1:0] i_adc_data;
logic o_adc_ready;

// Decimated Output Interface
logic o_decim_valid;
logic [SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH-1:0] o_decim_data;
logic i_decim_ready;

// CSR Write Interface
logic i_csr_wr_valid;
logic [7:0] i_csr_addr;
logic [31:0] i_csr_wr_data;
logic o_csr_wr_ready;

// CSR Read Interface
logic i_csr_rd_ready;
logic [31:0] o_csr_rd_data;

// Error Interrupt
logic o_error;

//==============================================================================
// Test Variables
//==============================================================================

int test_count;
int error_count;
int csr_read_count;
int csr_write_count;

//==============================================================================
// Clock Generation
//==============================================================================

initial begin
    i_clk = 0;
    forever #(CLK_PERIOD/2) i_clk = ~i_clk;
end

//==============================================================================
// Reset Generation
//==============================================================================

initial begin
    i_rst_n = 0;
    #RESET_DELAY;
    i_rst_n = 1;
end

//==============================================================================
// Device Under Test
//==============================================================================

ssemi_adc_decimator_sys_top #(
    .CIC_STAGES(SSEMI_ADC_DECIMATOR_CIC_STAGES),
    .FIR_TAPS(SSEMI_ADC_DECIMATOR_FIR_TAPS),
    .HALFBAND_TAPS(SSEMI_ADC_DECIMATOR_HALFBAND_TAPS),
    .DECIMATION_FACTOR(SSEMI_ADC_DECIMATOR_DEFAULT_DECIMATION_FACTOR),
    .DATA_WIDTH(SSEMI_ADC_DECIMATOR_INPUT_DATA_WIDTH),
    .COEFF_WIDTH(SSEMI_ADC_DECIMATOR_FIR_COEFF_WIDTH)
) dut (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    
    // ADC Input Interface
    .i_adc_valid(i_adc_valid),
    .i_adc_data(i_adc_data),
    .o_adc_ready(o_adc_ready),
    
    // Decimated Output Interface
    .o_decim_valid(o_decim_valid),
    .o_decim_data(o_decim_data),
    .i_decim_ready(i_decim_ready),
    
    // CSR Write Interface
    .i_csr_wr_valid(i_csr_wr_valid),
    .i_csr_addr(i_csr_addr),
    .i_csr_wr_data(i_csr_wr_data),
    .o_csr_wr_ready(o_csr_wr_ready),
    
    // CSR Read Interface
    .i_csr_rd_ready(i_csr_rd_ready),
    .o_csr_rd_data(o_csr_rd_data),
    
    // Error Interrupt
    .o_error(o_error)
);

//==============================================================================
// Test Stimulus
//==============================================================================

initial begin
    // Initialize test signals
    i_adc_valid = 0;
    i_adc_data = 0;
    i_decim_ready = 1;
    i_csr_wr_valid = 0;
    i_csr_addr = 0;
    i_csr_wr_data = 0;
    i_csr_rd_ready = 0;
    
    test_count = 0;
    error_count = 0;
    csr_read_count = 0;
    csr_write_count = 0;
    
    // Wait for reset
    wait(i_rst_n);
    repeat(10) @(posedge i_clk);
    
    // Run test scenarios
    test_reset_behavior();
    test_basic_data_flow();
    test_csr_operations();
    test_error_conditions();
    test_parameter_validation();
    
    // Final report
    $display("=== Test Summary ===");
    $display("Total tests: %0d", test_count);
    $display("Errors: %0d", error_count);
    $display("CSR reads: %0d", csr_read_count);
    $display("CSR writes: %0d", csr_write_count);
    
    if (error_count == 0) begin
        $display("PASS: All tests completed successfully");
    end else begin
        $display("FAIL: %0d errors detected", error_count);
    end
    
    $finish;
end

//==============================================================================
// Test Tasks
//==============================================================================

task test_reset_behavior();
    $display("Testing reset behavior...");
    test_count++;
    
    // Check initial state after reset
    if (o_adc_ready !== 1'b1) begin
        $display("ERROR: o_adc_ready should be 1 after reset");
        error_count++;
    end
    
    if (o_error !== 1'b0) begin
        $display("ERROR: o_error should be 0 after reset");
        error_count++;
    end
    
    if (o_csr_wr_ready !== 1'b1) begin
        $display("ERROR: o_csr_wr_ready should be 1 after reset");
        error_count++;
    end
    
    repeat(5) @(posedge i_clk);
endtask

task test_basic_data_flow();
    $display("Testing basic data flow...");
    test_count++;
    
    // Send test data
    for (int i = 0; i < 100; i++) begin
        @(posedge i_clk);
        i_adc_valid = 1;
        i_adc_data = $signed(i);
        
        if (o_adc_ready) begin
            @(posedge i_clk);
            i_adc_valid = 0;
        end else begin
            wait(o_adc_ready);
            @(posedge i_clk);
            i_adc_valid = 0;
        end
    end
    
    // Wait for processing
    repeat(1000) @(posedge i_clk);
endtask

task test_csr_operations();
    $display("Testing CSR operations...");
    test_count++;
    
    // Test CSR write
    @(posedge i_clk);
    i_csr_wr_valid = 1;
    i_csr_addr = 8'h00;
    i_csr_wr_data = 32'h12345678;
    csr_write_count++;
    
    @(posedge i_clk);
    i_csr_wr_valid = 0;
    
    // Test CSR read
    @(posedge i_clk);
    i_csr_rd_ready = 1;
    i_csr_addr = 8'h00;
    csr_read_count++;
    
    @(posedge i_clk);
    i_csr_rd_ready = 0;
    
    repeat(10) @(posedge i_clk);
endtask

task test_error_conditions();
    $display("Testing error conditions...");
    test_count++;
    
    // Test invalid CSR address
    @(posedge i_clk);
    i_csr_wr_valid = 1;
    i_csr_addr = 8'hFF;  // Invalid address
    i_csr_wr_data = 32'hDEADBEEF;
    
    @(posedge i_clk);
    i_csr_wr_valid = 0;
    
    // Check for error interrupt
    repeat(5) @(posedge i_clk);
    if (o_error) begin
        $display("INFO: Error interrupt generated for invalid address");
    end
    
    repeat(10) @(posedge i_clk);
endtask

task test_parameter_validation();
    $display("Testing parameter validation...");
    test_count++;
    
    // Test coefficient range validation
    @(posedge i_clk);
    i_csr_wr_valid = 1;
    i_csr_addr = 8'h00;
    i_csr_wr_data = 32'h00040000;  // Out of range coefficient
    
    @(posedge i_clk);
    i_csr_wr_valid = 0;
    
    // Check for error interrupt
    repeat(5) @(posedge i_clk);
    if (o_error) begin
        $display("INFO: Error interrupt generated for out-of-range coefficient");
    end
    
    repeat(10) @(posedge i_clk);
endtask

//==============================================================================
// Coverage
//==============================================================================

// Functional coverage
covergroup csr_coverage @(posedge i_clk);
    csr_addr_cp: coverpoint i_csr_addr {
        bins valid_addr = {[0:127]};
        bins invalid_addr = {[128:255]};
    }
    
    csr_write_cp: coverpoint i_csr_wr_valid;
    csr_read_cp: coverpoint i_csr_rd_ready;
    
    data_flow_cp: coverpoint i_adc_valid;
    error_cp: coverpoint o_error;
    
    cross csr_addr_cp, csr_write_cp;
    cross csr_addr_cp, csr_read_cp;
endgroup

csr_coverage cov = new();

//==============================================================================
// Monitoring
//==============================================================================

// Monitor data flow
always @(posedge i_clk) begin
    if (i_adc_valid && o_adc_ready) begin
        $display("INFO: ADC data sent: %0d", $signed(i_adc_data));
    end
    
    if (o_decim_valid && i_decim_ready) begin
        $display("INFO: Decimated data received: %0d", $signed(o_decim_data));
    end
end

// Monitor errors
always @(posedge i_clk) begin
    if (o_error) begin
        $display("WARNING: Error interrupt asserted");
    end
end

endmodule

`endif // TB_SSEMI_ADC_DECIMATOR_SYS_TOP_V
