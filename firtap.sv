/////////////////////////////////////////////////////////////////////////////////
// 
// Implementation of a multiply and add node with variable buffering. Multiple 
// of these can be linked to build a polyphase multirate filter. Bit reduction 
// is optimized for precision, with product rounded convergently (round to even).
//
/////////////////////////////////////////////////////////////////////////////////

module firtap #(
    parameter		IW=16, TW=IW, OW=IW+TW, NTAPS, UPFACTOR, BUFFER = UPFACTOR-2
  ) (
    input	   wire			                      i_clk, i_reset,
    input    wire			                      i_ce,

     input 	 wire    signed  [(TW-1):0]     i_tap,          // Coefficients
  
    input    wire    signed  [(IW-1):0]     i_sample,       // Data Input
 
    // Accumulator Pipeline
    input	   wire    signed  [(OW-1):0]	    i_partial_acc,  // Previous Accumulator
    output 	 reg	   signed  [(OW-1):0]	    o_acc,         

    input	   reg 	            	 [31:0]     i_k
  );

  // Local declarations
  reg    signed	  [(TW+IW-1):0]	             product;
  reg	   signed	  [(TW+IW-1):0]	             product_rounded;
  reg 	 signed      [(OW-1):0]              product_truncated;

  reg    signed	 [BUFFER:0]  [(OW-1):0]  acc_pipe;      // Accumulator Buffer

  // Reset pipeline
  always @(posedge i_clk)
  if (i_reset)
  begin
    acc_pipe <= 0;
    o_acc <= 0;
  end 

  // Multiply the filter tap by the incoming sample
  always @(posedge i_clk)
    if (i_reset)
      product <= 0;
    else if (i_ce) begin
      product <= i_tap * i_sample;
    end
  
  initial	o_acc = 0; // Initialize output accumulator


  // Add product to accumulate pipeline
  always @(posedge i_clk)
  if (i_reset)
    o_acc <= 0;
  else if (i_ce) begin
    if(i_k == NTAPS/UPFACTOR-1) begin 
      // Last tap in chain, no buffering
      o_acc <= { {(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-1){product_rounded[(TW+IW-1)]}}, 
      product_rounded[TW+IW-1:(TW+IW+$clog2(NTAPS/UPFACTOR))-OW-1] } + i_partial_acc;
    end else begin
      // Variable Buffer
      acc_pipe <= {acc_pipe, product_truncated};
      o_acc <= acc_pipe[BUFFER];
    end
  end

  // Bit shift is calculated to maximize precision following matlab model

  // Convergent Rounding Implementation
  assign product_rounded = product[TW+IW-1:0]
  + {{(OW-(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-1)){1'b0}}, 
  product[(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-1)], // Round bit
  {(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-2){!product[(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-1)]}}}; 

  // Truncate product register and add accumulator input, extend sign bit
  assign product_truncated = { {(TW+IW+$clog2(NTAPS/UPFACTOR)-OW-1){product_rounded[(TW+IW-1)]}}, // Sign bit extension
  product_rounded[TW+IW-1:(TW+IW+$clog2(NTAPS/UPFACTOR))-OW-1] } + i_partial_acc; // Truncation and accumulation
endmodule