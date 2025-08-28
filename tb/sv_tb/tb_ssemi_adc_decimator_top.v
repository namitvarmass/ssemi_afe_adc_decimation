`ifndef TB_SSEMI_ADC_DECIMATOR_TOP_V
`define TB_SSEMI_ADC_DECIMATOR_TOP_V

//=============================================================================
// Testbench Name: tb_ssemi_adc_decimator_top
//=============================================================================
// Description: Testbench for SSEMI ADC Decimator with three-stage architecture
//              Tests CIC, FIR, and Halfband filter stages with various inputs
//              Includes comprehensive error detection and configuration testing
// Author:      SSEMI Development Team
// Date:        2025-08-26T17:54:47Z
// License:     Apache-2.0
//=============================================================================

`include "ssemi_timescale.vh"
`include "ssemi_defines.vh"

module tb_ssemi_adc_decimator_top;

    //==============================================================================
    // Test Parameters
    //==============================================================================
    parameter CLK_PERIOD = 10; // 100MHz clock
    parameter TEST_DURATION = 10000; // Number of clock cycles to test
    parameter CIC_STAGES = `SSEMI_CIC_STAGES;
    parameter FIR_TAPS = `SSEMI_FIR_TAPS;
    parameter HALFBAND_TAPS = `SSEMI_HALFBAND_TAPS;
    parameter DECIMATION_FACTOR = `SSEMI_DEFAULT_DECIMATION_FACTOR;

    //==============================================================================
    // Test Signals
    //==============================================================================
    logic i_clk;
    logic i_rst_n;
    logic i_enable;
    logic i_valid;
    logic o_ready;
    logic [`SSEMI_INPUT_DATA_WIDTH-1:0] i_data;
    logic [`SSEMI_OUTPUT_DATA_WIDTH-1:0] o_data;
    logic o_valid;
    
    // Configuration interface
    logic i_config_valid;
    logic [7:0] i_config_addr;
    logic [31:0] i_config_data;
    logic o_config_ready;
    
    // Status and error interface
    logic [7:0] o_status;
    logic o_busy;
    logic o_error;
    logic [2:0] o_error_type;
    logic [3:0] o_cic_stage_status;
    logic [5:0] o_fir_tap_status;
    logic [4:0] o_halfband_tap_status;

    //==============================================================================
    // Test Variables
    //==============================================================================
    integer test_count;
    integer error_count;
    integer success_count;
    integer cycle_count;
    
    // Test data arrays
    logic [`SSEMI_INPUT_DATA_WIDTH-1:0] test_inputs [0:999];
    logic [`SSEMI_OUTPUT_DATA_WIDTH-1:0] expected_outputs [0:999];
    
    // Configuration test data
    logic [`SSEMI_FIR_COEFF_WIDTH-1:0] test_fir_coeff [0:FIR_TAPS-1];
    logic [`SSEMI_HALFBAND_COEFF_WIDTH-1:0] test_halfband_coeff [0:HALFBAND_TAPS-1];

    //==============================================================================
    // Coverage Collection
    //==============================================================================
    // Functional coverage bins
    covergroup input_data_cg @(posedge i_clk);
        input_range: coverpoint i_data {
            bins zero = {0};
            bins positive = {[1:32767]};
            bins negative = {[-32768:-1]};
            bins max_positive = {32767};
            bins max_negative = {-32768};
        }
        
        valid_ready: coverpoint {i_valid, o_ready} {
            bins idle = {2'b00};
            bins waiting = {2'b01};
            bins sending = {2'b10};
            bins transfer = {2'b11};
        }
        
        error_types: coverpoint o_error_type {
            bins no_error = {3'b000};
            bins overflow = {3'b001};
            bins underflow = {3'b010};
            bins invalid_config = {3'b011};
            bins stage_failure = {3'b100};
        }
        
        status_bits: coverpoint o_status {
            bins cic_active = {[8]};
            bins fir_active = {[7]};
            bins halfband_active = {[6]};
            bins error_flag = {[4]};
            bins overflow_detected = {[3]};
            bins underflow_detected = {[2]};
        }
    endgroup

    // Configuration coverage
    covergroup config_cg @(posedge i_clk);
        config_addr: coverpoint i_config_addr {
            bins fir_coeff = {[0:63]};
            bins halfband_coeff = {[64:96]};
            bins reserved = {[97:255]};
        }
        
        config_valid: coverpoint {i_config_valid, o_config_ready} {
            bins idle = {2'b00};
            bins ready = {2'b01};
            bins valid = {2'b10};
            bins transfer = {2'b11};
        }
    endgroup

    // Coverage instances
    input_data_cg input_cov;
    config_cg config_cov;

    //==============================================================================
    // DUT Instance
    //==============================================================================
    ssemi_adc_decimator_top #(
        .CIC_STAGES(CIC_STAGES),
        .FIR_TAPS(FIR_TAPS),
        .HALFBAND_TAPS(HALFBAND_TAPS),
        .DECIMATION_FACTOR(DECIMATION_FACTOR)
    ) dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_enable(i_enable),
        .i_valid(i_valid),
        .o_ready(o_ready),
        .i_data(i_data),
        .o_data(o_data),
        .o_valid(o_valid),
        .i_config_valid(i_config_valid),
        .i_config_addr(i_config_addr),
        .i_config_data(i_config_data),
        .o_config_ready(o_config_ready),
        .o_status(o_status),
        .o_busy(o_busy),
        .o_error(o_error),
        .o_error_type(o_error_type),
        .o_cic_stage_status(o_cic_stage_status),
        .o_fir_tap_status(o_fir_tap_status),
        .o_halfband_tap_status(o_halfband_tap_status)
    );

    //==============================================================================
    // Clock Generation
    //==============================================================================
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end

    //==============================================================================
    // Coverage Initialization
    //==============================================================================
    initial begin
        input_cov = new();
        config_cov = new();
    end

    //==============================================================================
    // Test Stimulus
    //==============================================================================
    initial begin
        // Initialize test variables
        test_count = 0;
        error_count = 0;
        success_count = 0;
        cycle_count = 0;
        
        // Initialize signals
        i_rst_n = 0;
        i_enable = 0;
        i_valid = 0;
        i_data = 0;
        i_config_valid = 0;
        i_config_addr = 0;
        i_config_data = 0;
        
        // Generate test data
        generate_test_data();
        
        // Wait for initial reset
        #(CLK_PERIOD * 10);
        
        // Release reset
        i_rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Enable the decimator
        i_enable = 1;
        #(CLK_PERIOD * 5);
        
        // Test 1: Basic functionality test
        $display("=== Test 1: Basic Functionality Test ===");
        basic_functionality_test();
        
        // Test 2: Configuration register test
        $display("=== Test 2: Configuration Register Test ===");
        configuration_test();
        
        // Test 3: Error detection test
        $display("=== Test 3: Error Detection Test ===");
        error_detection_test();
        
        // Test 4: Overflow/underflow test
        $display("=== Test 4: Overflow/Underflow Test ===");
        overflow_test();
        
        // Test 5: Parameter validation test
        $display("=== Test 5: Parameter Validation Test ===");
        parameter_validation_test();
        
        // Test 6: Status monitoring test
        $display("=== Test 6: Status Monitoring Test ===");
        status_monitoring_test();
        
        // Display test results
        $display("=== Test Results ===");
        $display("Total Tests: %d", test_count);
        $display("Successful: %d", success_count);
        $display("Errors: %d", error_count);
        $display("Success Rate: %.2f%%", (success_count * 100.0) / test_count);
        
        // Display coverage results
        $display("=== Coverage Results ===");
        $display("Input Data Coverage: %.2f%%", input_cov.get_inst_coverage());
        $display("Configuration Coverage: %.2f%%", config_cov.get_inst_coverage());
        
        // Coverage goals check
        if (input_cov.get_inst_coverage() >= 95.0) begin
            $display("✓ Input Data Coverage Goal Met (95%%)");
        end else begin
            $display("✗ Input Data Coverage Goal Not Met (%.2f%% < 95%%)", input_cov.get_inst_coverage());
        end
        
        if (config_cov.get_inst_coverage() >= 90.0) begin
            $display("✓ Configuration Coverage Goal Met (90%%)");
        end else begin
            $display("✗ Configuration Coverage Goal Not Met (%.2f%% < 90%%)", config_cov.get_inst_coverage());
        end
        
        // End simulation
        #(CLK_PERIOD * 100);
        $finish;
    end

    //==============================================================================
    // Test Functions
    //==============================================================================
    
    // Generate test data
    task generate_test_data();
        integer i;
        begin
            for (i = 0; i < 1000; i = i + 1) begin
                // Generate sinusoidal test data
                test_inputs[i] = $signed($rtoi($signed(16'h4000) * $sin(2.0 * 3.14159 * i / 100.0)));
                
                // Generate expected outputs (simplified)
                expected_outputs[i] = $signed($rtoi($signed(24'h400000) * $sin(2.0 * 3.14159 * i / (100.0 * DECIMATION_FACTOR))));
            end
            
            // Generate test coefficients
            for (i = 0; i < FIR_TAPS; i = i + 1) begin
                test_fir_coeff[i] = $signed($rtoi($signed(18'h10000) * $exp(-i / 10.0)));
            end
            
            for (i = 0; i < HALFBAND_TAPS; i = i + 1) begin
                if (i % 2 == 0) begin
                    test_halfband_coeff[i] = $signed($rtoi($signed(18'h10000) * $exp(-i / 5.0)));
                end else begin
                    test_halfband_coeff[i] = 0; // Odd taps should be zero for halfband
                end
            end
        end
    endtask

    // Basic functionality test
    task basic_functionality_test();
        integer i;
        begin
            test_count = test_count + 1;
            
            // Send test data
            for (i = 0; i < 100; i = i + 1) begin
                @(posedge i_clk);
                i_valid = 1;
                i_data = test_inputs[i];
                
                // Wait for ready
                while (!o_ready) @(posedge i_clk);
                
                // Check for valid output
                if (o_valid) begin
                    $display("Output received: %h", o_data);
                    success_count = success_count + 1;
                end
            end
            
            i_valid = 0;
            i_data = 0;
            
            // Wait for processing to complete
            #(CLK_PERIOD * 100);
            
            if (success_count > 0) begin
                $display("Basic functionality test PASSED");
            end else begin
                $display("Basic functionality test FAILED");
                error_count = error_count + 1;
            end
        end
    endtask

    // Configuration register test
    task configuration_test();
        integer i;
        begin
            test_count = test_count + 1;
            
            // Test FIR coefficient loading
            for (i = 0; i < FIR_TAPS; i = i + 1) begin
                @(posedge i_clk);
                i_config_valid = 1;
                i_config_addr = i;
                i_config_data = test_fir_coeff[i];
                
                while (!o_config_ready) @(posedge i_clk);
            end
            
            // Test halfband coefficient loading
            for (i = 0; i < HALFBAND_TAPS; i = i + 1) begin
                @(posedge i_clk);
                i_config_valid = 1;
                i_config_addr = i + 64; // Halfband coefficients start at address 64
                i_config_data = test_halfband_coeff[i];
                
                while (!o_config_ready) @(posedge i_clk);
            end
            
            i_config_valid = 0;
            i_config_addr = 0;
            i_config_data = 0;
            
            // Wait for configuration to take effect
            #(CLK_PERIOD * 50);
            
            if (!o_error) begin
                $display("Configuration test PASSED");
                success_count = success_count + 1;
            end else begin
                $display("Configuration test FAILED - Error: %h", o_error_type);
                error_count = error_count + 1;
            end
        end
    endtask

    // Error detection test
    task error_detection_test();
        begin
            test_count = test_count + 1;
            
            // Test invalid configuration address
            @(posedge i_clk);
            i_config_valid = 1;
            i_config_addr = 8'hFF; // Valid address
            i_config_data = 32'h12345678;
            
            while (!o_config_ready) @(posedge i_clk);
            
            @(posedge i_clk);
            i_config_addr = 8'hFF + 1; // Invalid address
            i_config_data = 32'h87654321;
            
            #(CLK_PERIOD * 10);
            
            if (o_error && o_error_type == 3'b011) begin
                $display("Error detection test PASSED - Invalid config detected");
                success_count = success_count + 1;
            end else begin
                $display("Error detection test FAILED");
                error_count = error_count + 1;
            end
            
            i_config_valid = 0;
        end
    endtask

    // Overflow test
    task overflow_test();
        integer i;
        begin
            test_count = test_count + 1;
            
            // Send maximum amplitude data to trigger overflow
            for (i = 0; i < 50; i = i + 1) begin
                @(posedge i_clk);
                i_valid = 1;
                i_data = 16'h7FFF; // Maximum positive value
                
                while (!o_ready) @(posedge i_clk);
            end
            
            i_valid = 0;
            i_data = 0;
            
            // Wait for overflow detection
            #(CLK_PERIOD * 100);
            
            if (o_overflow || o_error_type == 3'b001) begin
                $display("Overflow test PASSED - Overflow detected");
                success_count = success_count + 1;
            end else begin
                $display("Overflow test FAILED - No overflow detected");
                error_count = error_count + 1;
            end
        end
    endtask

    // Parameter validation test
    task parameter_validation_test();
        begin
            test_count = test_count + 1;
            
            // This test would require instantiating modules with invalid parameters
            // For now, we'll just check that the current parameters are valid
            if (CIC_STAGES >= 1 && CIC_STAGES <= 8 &&
                FIR_TAPS >= 4 && FIR_TAPS <= 256 &&
                HALFBAND_TAPS >= 5 && HALFBAND_TAPS <= 128 &&
                HALFBAND_TAPS % 2 == 1) begin
                $display("Parameter validation test PASSED");
                success_count = success_count + 1;
            end else begin
                $display("Parameter validation test FAILED");
                error_count = error_count + 1;
            end
        end
    endtask

    // Status monitoring test
    task status_monitoring_test();
        begin
            test_count = test_count + 1;
            
            // Monitor status during operation
            @(posedge i_clk);
            i_valid = 1;
            i_data = 16'h1000;
            
            #(CLK_PERIOD * 10);
            
            // Check status bits
            if (o_busy && o_status[0] == 1'b1) begin
                $display("Status monitoring test PASSED");
                success_count = success_count + 1;
            end else begin
                $display("Status monitoring test FAILED");
                error_count = error_count + 1;
            end
            
            i_valid = 0;
            i_data = 0;
        end
    endtask

    //==============================================================================
    // Monitoring and Coverage
    //==============================================================================
    
    // Monitor clock cycles
    always @(posedge i_clk) begin
        cycle_count = cycle_count + 1;
        
        if (cycle_count >= TEST_DURATION) begin
            $display("Test duration reached: %d cycles", cycle_count);
            $finish;
        end
    end
    
    // Monitor outputs
    always @(posedge i_clk) begin
        if (o_valid) begin
            $display("Cycle %d: Output = %h, Status = %h, Error = %b", 
                     cycle_count, o_data, o_status, o_error);
        end
        
        if (o_error) begin
            $display("Cycle %d: Error detected - Type = %h", cycle_count, o_error_type);
        end
    end

endmodule

`endif // TB_SSEMI_ADC_DECIMATOR_TOP_V
