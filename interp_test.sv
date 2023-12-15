// To Do
// Wrapper test module that creates random stimulus
// Transfer Matlab model to C and build a DPI to assert outputs
// Add logic to prevent invalid upfactor to NTAPS ratio (assert)?

// Currently output file is imported to matlab and compared to model's output.

module interp_test;

  parameter logic  [31:0]   NUM_DATA = 100000;        // Number of Input Samples
  parameter logic  [31:0]   NUM_TAPS = 30;            // Number of Filter Coefficients
  parameter logic  [31:0]   UPFACTOR = 5;             // Upsampling Factor
  parameter logic  [31:0]   NUM_OUT = NUM_DATA*UPFACTOR+NUM_TAPS-UPFACTOR;
  parameter logic  [31:0]   IW = 16;                  // Input Witdh
  parameter logic  [31:0]   TW = 16;                  // Coefficient Width
  parameter logic  [31:0]   OW = IW+TW;               // Output Width

  // Inputs 
  logic signed   [IW-1:0]   data      [NUM_DATA-1:0]; // Data Train
  logic signed   [IW-1:0]   i_sample;                 // Sample
  logic                     ce;                       // Clock enable
  
  // Outputs
  logic signed   [OW-1:0]   result    [NUM_OUT-1:0];  // Output Train
  logic signed   [OW-1:0]   o_sample;                 // Module output sample

  // Clock and Reset Signals
  logic                     clk;
  logic                     reset;
  logic                     clk_slow;                 // Clock on input side
  logic                     reset_slow;         

  // Counter Variables
  reg              [31:0]   i;                        // Input Counter
  reg              [31:0]   k;                        // Output Counter
  integer                   fd;                       // Output File Pointer

  // Clock rate ratios must match UPFACTOR

  basic_clk_reset_gen #(
    .CLK_RATE(100_000_000) 
  ) clk_gen (
    .clk  (clk),
    .reset(reset)
  );

  basic_clk_reset_gen #(
    .CLK_RATE(100_000_000/5)
  ) clk_gen2 (
    .clk  (clk_slow),
    .reset(reset_slow)
  );

  interpolator #(
    .UPFACTOR(UPFACTOR),
    .NTAPS(NUM_TAPS),
    .IW(IW),
    .TW(TW),
    .OW(OW)
  ) DUT (
    .i_clk(clk),
    .i_reset(reset),
    .i_ce(ce),
    .i_sample(i_sample),
    .o_result(o_sample)
  );

  initial begin
    @(posedge clk_slow);
    $display("Starting testbench");

    // Read input file (must be in hex)
    $readmemh("/home/adam/Code/DD/sig.txt", data);
    
    // Create results file 
    fd = $fopen("/home/adam/Code/Matlab/results.txt","w");

    #1us;
    $display("Test started");

    // Synchronize module to slow clock
    @(posedge clk_slow);

    i_sample <= data[0];
    ce <= 1;

    fork 
    // Feed input signal into module
    begin
      for (i = 1; i < NUM_DATA+NUM_TAPS; i++) begin
        @(posedge clk_slow);
        if(i<NUM_DATA) begin
            i_sample <= data[i];
        end else begin
            i_sample <= 0;
        end
      end
    end

    // Assign output values to result register
    begin
      // Wait for signal to propagate through pipeline
      @(posedge clk);
      @(posedge clk);
      for (k = 0; k < NUM_OUT; k++) begin
        @(posedge clk);
        result[k] <= o_sample;
      end
    end
    join

    $display("Input Data");
    $displayh(data);

    $fwriteh(fd,result);

    $display("Output");
    $display(result);

    $fclose(fd);

    $finish();
  end  
  
  //initial begin
  // // Test for reset
    //#100;
    //$display("resetting");
    //reset <= 1'b1;
    //#10;
    //reset <= 1'b0;
  //end

endmodule