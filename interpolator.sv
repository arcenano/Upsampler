/////////////////////////////////////////////////////////////////////////////////
// 
// Implementation of a polyphase multirate filter for interpolation. FIR Filter
// taps are read in from txt file. NTAPS must be divisible by UPFACTOR. 
//
/////////////////////////////////////////////////////////////////////////////////

module interpolator #(
    parameter       UPFACTOR=4, NTAPS = 32, IW = 16, TW = 16, OW = 32
  ) (
    input	   wire			               i_clk, i_reset,
    input	   wire			               i_ce,
    input    wire	signed [(IW-1):0]  i_sample,
    output   wire	signed [(OW-1):0]	 o_result
  );

  // Local declarations
  logic	   signed  [(TW-1):0]        taps		     [NTAPS-1:0];
  wire	   signed  [(IW-1):0]        sample	     [NTAPS/UPFACTOR:0];
  wire	   signed  [(OW-1):0]        result	     [NTAPS/UPFACTOR:0];
  reg      signed  [(TW-1):0]        muxed_taps  [NTAPS/UPFACTOR-1:0];
  reg      signed      [31:0]        count;
  genvar	                           k;

  // Every tap takes in the same sample
  assign	sample[0] = i_sample;

  // Initialize the partial summing accumulator with zero
  assign	result[0] = 0;

  // Assign the output to last accumulate node
  assign o_result = result[NTAPS/UPFACTOR];

  // Coefficient Mux Counter
  always @(posedge i_clk) begin
    if(i_reset) begin
      count <= 0;
    end else if (i_ce) begin
      if(count == UPFACTOR -1 ) begin
        count <= 0;
      end else begin
        count <= count + 1;
      end
    end
  end

  // Coefficient Mux
  always_comb begin                              
    for (int i = 0; i < NTAPS/UPFACTOR; i++) begin 
      muxed_taps[(NTAPS/UPFACTOR-1)-i] = taps[i*UPFACTOR+count];
    end
  end

  // Read in Coefficients (hex)
  initial begin
    $readmemh("/home/adam/Code/DD/taps.txt", taps);
    $display(taps);
  end 

  generate
    // Build Polyphase Filter by Linking FIRTAP modules
    for(k=0; k<NTAPS/UPFACTOR; k=k+1)
    begin: POLYPHASE
      firtap #(
        .IW(IW), 
        .OW(OW), 
        .TW(TW),
        .NTAPS(NTAPS),
        .UPFACTOR(UPFACTOR)
      ) tapk(
        // Timing and Control Signals
        .i_clk(i_clk), 
        .i_reset(i_reset),
        .i_ce(i_ce),

        // Taps
        .i_tap(muxed_taps[k]),

        // Input
        .i_sample(sample[0]),

        // Accumulation Pipeline
        .i_partial_acc(result[k]),  
        .o_acc(result[k+1]),

        // Index
        .i_k(k)
      );
    end
  endgenerate
endmodule
