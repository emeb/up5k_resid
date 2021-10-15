// wetdry.v - wet/dry mix
// 09-05-21 E. Brombaugh

`default_nettype none

module wetdry(
    input clk,              // system clock
    input reset,			// system reset
	input ena,				// system clock enable
	input signed [15:0] in,	// signed binary input
	input [11:0] pot,
	input  signed [15:0] dry_l, dry_r, wet_l, wet_r,
	output reg signed [15:0] out_l, out_r,
	output reg valid
);
	// invert pot
	wire signed [15:0] gain = {4'h0,pot}, igain = {4'h0,~pot};
	
	// state machine controls muxing into MAC
	reg [2:0] state;
	reg signed [27:0] prod;
	reg signed [28:0] sum;
	wire signed [15:0] sat;
	reg signed [15:0] hold;
	always @(posedge clk)
		if(reset)
		begin
			state <= 3'd0;
			hold <= 16'd0;
			out_l <= 16'd0;
			out_r <= 16'd0;
			valid <= 1'b0;
		end
		else
			case(state)
				3'd0:	// wait for valid
				begin
					valid <= 1'b0;
					if(ena)
					begin
						// start with left chl dry
						state <= 3'd1;
						prod <= dry_l * igain;
					end
				end
			
				3'd1:
				begin
					// left chl wet
					state <= 3'd2;
					prod <= wet_l * gain;
					sum <= prod;
				end
			
				3'd2:
				begin
					// right chl dry
					state <= 3'd3;
					prod <= dry_r * igain;
					sum <= sum + prod;
				end
			
				3'd3:
				begin
					// right chl wet
					state <= 3'd4;
					prod <= wet_r * gain;
					sum <= prod;
					hold <= sat;
				end
			
				3'd4:
				begin
					// last sum
					state <= 3'd5;
					sum <= sum + prod;
				end
			
				3'd5:
				begin
					// finish
					state <= 3'd0;
					out_l <= hold;
					out_r <= sat;
					valid <= 1'b1;
				end
			endcase
	
	// saturate sum down to 16 bits
	sat #(.isz(17), .osz(16))
		usat(
			.in(sum[29:12]),
			.out(sat)
		);
endmodule

