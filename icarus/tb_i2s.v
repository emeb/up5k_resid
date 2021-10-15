// tb_i2s.v - test i2s slave interace
// 09-03-21 E. Brombaugh

`default_nettype none

module tb_i2s;
    reg clk;
    reg reset;
	reg signed [15:0] IN_L, IN_R;
	wire i2s_sclk;
	wire i2s_lrclk;
	wire i2s_dout;
	wire signed [15:0] OUT_L, OUT_R;
	wire i2s_din;
	wire i2s_sampled;
	
    // 24 MHz clock source
    always
        #20.8333 clk = ~clk;
	
    // reset
    initial
    begin
`ifdef icarus
  		$dumpfile("tb_i2s.vcd");
		$dumpvars;
`endif

        // init regs
        clk = 1'b0;
        reset = 1'b1;
		
        // release reset
        #1000
        reset = 1'b0;
        
`ifdef icarus
        // stop after 1 sec
		#1000000 $finish;
`endif
    end
	
	// I2S master timing
	reg [3:0] cnt;
	reg [5:0] bits;
	always @(posedge clk)
		if(reset)
		begin
			cnt <= 4'd0;
			bits <= 6'd0;
		end
		else
		begin
			cnt <= cnt + 4'd1;
			
			if(cnt == 4'hf)
				bits <= bits + 6'd1;
		end
	assign i2s_sclk = cnt[3];
	assign i2s_lrclk = bits[5];
	assign i2s_dout = i2s_din;
		
	// I2S TX data
	always @(posedge clk)
		if(reset)
		begin
			IN_L <= 16'd0;
			IN_R <= 16'd0;
		end
		else if(i2s_sampled)
		begin
			IN_L <= IN_L + 16'd1;
			IN_R <= IN_R - 16'd1;
		end
		
	// UUT
	i2s uut(
		.CLK(clk),
        .IN_L(IN_L),
		.IN_R(IN_R),
        .i2s_sclk(i2s_sclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_dout(i2s_dout),
		.OUT_L(OUT_L),
		.OUT_R(OUT_R),
        .i2s_din(i2s_din),
        .i2s_sampled(i2s_sampled)
	);
endmodule
