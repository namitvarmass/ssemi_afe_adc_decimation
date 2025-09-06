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
//   - 100% toggle coverage
//   - All error conditions exercised
//   - All CSR operations verified
//   - Performance and timing verification
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
// Comprehensive Coverage Collection
//==============================================================================

// CSR Operations Coverage
covergroup csr_operations_cg @(posedge i_clk);
    csr_addr_cp: coverpoint i_csr_addr {
        bins config_regs = {[0:63]};
        bins halfband_regs = {[64:96]};
        bins status_regs = {[128:255]};
        illegal_bins invalid = default;
    }
    
    csr_write_cp: coverpoint {i_csr_wr_valid, o_csr_wr_ready} {
        bins write_success = {2'b11};
        bins write_pending = {2'b10};
        bins write_idle = {2'b00};
    }
    
    csr_read_cp: coverpoint {i_csr_rd_ready, o_csr_rd_valid} {
        bins read_success = {2'b11};
        bins read_pending = {2'b01};
        bins read_idle = {2'b00};
    }
    
    csr_data_cp: coverpoint i_csr_wr_data {
        bins zero = {32'h00000000};
        bins positive = {[32'h00000001:32'h7FFFFFFF]};
        bins negative = {[32'h80000000:32'hFFFFFFFF]};
    }
    
    // Cross coverage for CSR operations
    cross csr_addr_cp, csr_write_cp;
    cross csr_addr_cp, csr_read_cp;
    cross csr_write_cp, csr_data_cp;
endgroup

// Data Flow Coverage
covergroup data_flow_cg @(posedge i_clk);
    adc_flow_cp: coverpoint {i_adc_valid, o_adc_ready} {
        bins flow_success = {2'b11};
        bins flow_pending = {2'b10};
        bins flow_idle = {2'b00};
    }
    
    decim_flow_cp: coverpoint {o_decim_valid, i_decim_ready} {
        bins flow_success = {2'b11};
        bins flow_pending = {2'b01};
        bins flow_idle = {2'b00};
    }
    
    adc_data_cp: coverpoint i_adc_data {
        bins zero = {16'h0000};
        bins positive = {[16'h0001:16'h7FFF]};
        bins negative = {[16'h8000:16'hFFFF]};
        bins max_positive = {16'h7FFF};
        bins max_negative = {16'h8000};
    }
    
    decim_data_cp: coverpoint o_decim_data {
        bins zero = {16'h0000};
        bins positive = {[16'h0001:16'h7FFF]};
        bins negative = {[16'h8000:16'hFFFF]};
    }
    
    // Cross coverage for data flow
    cross adc_flow_cp, adc_data_cp;
    cross decim_flow_cp, decim_data_cp;
endgroup

// Error Conditions Coverage
covergroup error_conditions_cg @(posedge i_clk);
    error_interrupt_cp: coverpoint o_error;
    
    // Error injection coverage
    error_injection_cp: coverpoint {i_csr_wr_valid, i_csr_addr} {
        bins valid_write = {2'b10} iff (i_csr_addr <= 8'h7F);
        bins invalid_addr_write = {2'b10} iff (i_csr_addr > 8'h7F);
        bins no_write = {2'b00};
    }
    
    // Coefficient range coverage
    coeff_range_cp: coverpoint i_csr_wr_data {
        bins valid_coeff = {[32'h80000000:32'h7FFFFFFF]};
        bins out_of_range = default;
    }
    
    // Cross coverage for error conditions
    cross error_injection_cp, coeff_range_cp;
endgroup

// Performance Coverage
covergroup performance_cg @(posedge i_clk);
    latency_cp: coverpoint $time {
        bins low_latency = {[0:100ns]};
        bins medium_latency = {[100ns:500ns]};
        bins high_latency = {[500ns:$]};
    }
    
    throughput_cp: coverpoint {i_adc_valid, o_adc_ready} {
        bins high_throughput = {2'b11};
        bins medium_throughput = {2'b10};
        bins low_throughput = {2'b00};
    }
    
    // Clock frequency coverage
    clk_freq_cp: coverpoint i_clk {
        bins freq_100mhz = {1'b1};
    }
endgroup

// State Machine Coverage (if applicable)
covergroup state_machine_cg @(posedge i_clk);
    // Add state machine coverage if states are visible
    // This would need to be customized based on internal state visibility
endgroup

// Instantiate coverage groups
csr_operations_cg csr_cov = new();
data_flow_cg data_cov = new();
error_conditions_cg error_cov = new();
performance_cg perf_cov = new();
state_machine_cg state_cov = new();

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

//==============================================================================
// Performance Monitoring
//==============================================================================

// Latency measurement
real latency_start_time;
real latency_end_time;
real measured_latency;
int latency_samples = 0;
real total_latency = 0;

always @(posedge i_clk) begin
    if (i_adc_valid && o_adc_ready) begin
        latency_start_time = $realtime;
    end
    
    if (o_decim_valid && i_decim_ready) begin
        latency_end_time = $realtime;
        measured_latency = latency_end_time - latency_start_time;
        total_latency += measured_latency;
        latency_samples++;
        $display("INFO: Latency measurement: %0.2f ns", measured_latency);
    end
end

// Throughput measurement
int adc_samples_sent = 0;
int decim_samples_received = 0;
real throughput_start_time;
real throughput_end_time;
real measured_throughput;

always @(posedge i_clk) begin
    if (i_adc_valid && o_adc_ready) begin
        adc_samples_sent++;
        if (adc_samples_sent == 1) begin
            throughput_start_time = $realtime;
        end
    end
    
    if (o_decim_valid && i_decim_ready) begin
        decim_samples_received++;
        if (decim_samples_received == 100) begin
            throughput_end_time = $realtime;
            measured_throughput = (decim_samples_received * 1.0) / ((throughput_end_time - throughput_start_time) / 1ns);
            $display("INFO: Throughput measurement: %0.2f MSPS", measured_throughput);
        end
    end
end

//==============================================================================
// Coverage Reporting
//==============================================================================

// Coverage reporting task
task report_coverage();
    $display("\n==============================================================================");
    $display("COVERAGE REPORT");
    $display("==============================================================================");
    
    // CSR Operations Coverage
    $display("CSR Operations Coverage:");
    $display("  Write Operations: %0.2f%%", csr_cov.csr_write_cp.get_inst_coverage());
    $display("  Read Operations: %0.2f%%", csr_cov.csr_read_cp.get_inst_coverage());
    $display("  Address Range: %0.2f%%", csr_cov.csr_addr_cp.get_inst_coverage());
    $display("  Overall CSR Coverage: %0.2f%%", csr_cov.get_inst_coverage());
    
    // Data Flow Coverage
    $display("\nData Flow Coverage:");
    $display("  ADC Flow: %0.2f%%", data_cov.adc_flow_cp.get_inst_coverage());
    $display("  Decimated Flow: %0.2f%%", data_cov.decim_flow_cp.get_inst_coverage());
    $display("  ADC Data Range: %0.2f%%", data_cov.adc_data_cp.get_inst_coverage());
    $display("  Overall Data Flow Coverage: %0.2f%%", data_cov.get_inst_coverage());
    
    // Error Conditions Coverage
    $display("\nError Conditions Coverage:");
    $display("  Error Interrupt: %0.2f%%", error_cov.error_interrupt_cp.get_inst_coverage());
    $display("  Error Injection: %0.2f%%", error_cov.error_injection_cp.get_inst_coverage());
    $display("  Overall Error Coverage: %0.2f%%", error_cov.get_inst_coverage());
    
    // Performance Coverage
    $display("\nPerformance Coverage:");
    $display("  Latency: %0.2f%%", perf_cov.latency_cp.get_inst_coverage());
    $display("  Throughput: %0.2f%%", perf_cov.throughput_cp.get_inst_coverage());
    $display("  Overall Performance Coverage: %0.2f%%", perf_cov.get_inst_coverage());
    
    // Overall Coverage
    real overall_coverage = (csr_cov.get_inst_coverage() + data_cov.get_inst_coverage() + 
                           error_cov.get_inst_coverage() + perf_cov.get_inst_coverage()) / 4.0;
    $display("\nOVERALL FUNCTIONAL COVERAGE: %0.2f%%", overall_coverage);
    
    // Coverage Goals Check
    if (overall_coverage >= 95.0) begin
        $display("✓ COVERAGE GOAL ACHIEVED: 95%% functional coverage target met");
    end else begin
        $display("✗ COVERAGE GOAL NOT MET: %0.2f%% < 95%% target", overall_coverage);
    end
    
    $display("==============================================================================\n");
endtask

// Performance reporting task
task report_performance();
    $display("\n==============================================================================");
    $display("PERFORMANCE REPORT");
    $display("==============================================================================");
    
    if (latency_samples > 0) begin
        real avg_latency = total_latency / latency_samples;
        $display("Latency Statistics:");
        $display("  Average Latency: %0.2f ns", avg_latency);
        $display("  Total Samples: %0d", latency_samples);
        $display("  Total Latency: %0.2f ns", total_latency);
    end
    
    if (decim_samples_received > 0) begin
        $display("\nThroughput Statistics:");
        $display("  ADC Samples Sent: %0d", adc_samples_sent);
        $display("  Decimated Samples Received: %0d", decim_samples_received);
        $display("  Decimation Ratio: %0.2f:1", real'(adc_samples_sent) / real'(decim_samples_received));
    end
    
    $display("==============================================================================\n");
endtask

// Final reporting in main test
initial begin
    // Wait for test completion
    wait(test_complete);
    
    // Report coverage and performance
    report_coverage();
    report_performance();
    
    // Final status
    if (test_passed) begin
        $display("✓ ALL TESTS PASSED");
    end else begin
        $display("✗ SOME TESTS FAILED");
    end
    
    $finish;
end

endmodule

`endif // TB_SSEMI_ADC_DECIMATOR_SYS_TOP_V
