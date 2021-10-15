`default_nettype none

// I2S slave module
// sample rate is 96Khz
module i2s(
        input CLK,								// system clock (24Mhz)
        input signed [15:0] IN_L, IN_R,			// 16bit signed sample input
        input i2s_sclk,							// I2S clock
        input i2s_lrclk,						// I2S LR clock
        input i2s_dout,							// I2S ADC data out
		output reg signed [15:0] OUT_L, OUT_R,	// 16bit signed sample output
        output i2s_din,							// I2S DAC data in
        output reg i2s_sampled					// asserted at sample-rate
    );
	
	// synchronize inputs to sysclk and detect edges
    reg [1:0] i2s_sclk_sync;
    reg       i2s_sclk_rise;
    reg       i2s_sclk_fall;
    reg [1:0] i2s_lrclk_sync;
    reg [1:0] i2s_dout_sync;
    always @(posedge CLK) begin
        i2s_sclk_sync  <= { i2s_sclk_sync[0],   i2s_sclk };
        i2s_sclk_rise  <=   i2s_sclk_sync[0] & ~i2s_sclk_sync[1];
        i2s_sclk_fall  <=  ~i2s_sclk_sync[0] &  i2s_sclk_sync[1];
        i2s_lrclk_sync <= { i2s_lrclk_sync[0], i2s_lrclk };
        i2s_dout_sync <= { i2s_dout_sync[0], ~i2s_dout };
    end

	// clock out TX data, clock in RX data
    reg w;                   	// word select and dout delay
	reg [16:0] data; 			// output shift register
    reg [15:0] rx, hold; 		// input shift & hold registers
	reg [5:0] bcnt;				// bit counter for RX
    assign i2s_din = data[16];  // output msb
    always @(posedge CLK) begin
        i2s_sampled <= 0;
        if (i2s_sclk_rise) begin
            // Reload on word select change
            if (i2s_lrclk_sync[1] ^ w) begin
                if(i2s_lrclk_sync[1])
					data <= {1'b0,IN_R};
				else
					data <= {1'b0,IN_L};
                i2s_sampled <= i2s_lrclk_sync[1];
				
				// restart RX
				bcnt <= 6'd17;
				rx <= {15'd0,i2s_dout_sync[1]};
            end else begin
				if(|bcnt)
					bcnt <= bcnt - 6'd1;
					
				// shift in on rising edge and bcnt in range
				if(bcnt > 6'd1) begin
					rx <= {rx[14:0],i2s_dout_sync[1]};
				end else if(bcnt == 6'd1) begin
					if(i2s_lrclk_sync[1]) begin
						OUT_R <= rx;
						OUT_L <= hold;
					end else
						hold <= rx;
				end
			end
			
            // Save word select
            w <= i2s_lrclk_sync[1];
        end else if (i2s_sclk_fall) begin
            // Shift on falling edge
            data <= { data[15:0], 1'b0 };
        end
    end
endmodule
