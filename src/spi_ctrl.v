// spi_ctrl.v - read spi flash into SPRAM
// 04-24-21 E. Brombaugh

`default_nettype none

module spi_ctrl(
    input clk,
    input reset,
    input [1:0] tbl,
    output reg [15:0] wdata,
    output reg [12:0] waddr,
    output reg wmode,
    output reg we,
    output spi_mosi,
    output reg spi_sclk,
    output reg spi_cs,
    output spi_wp,
    output spi_hld,
    input spi_miso,
	output [1:0] diag
	);
	
	// detect change in wavetable setting
	reg [1:0] prev_tbl;
	reg start;
	always @(posedge clk)
		if(reset)
		begin
			prev_tbl <= 2'b11;
			start <= 1'b0;
		end
		else if(!wmode)
		begin
			start <= (prev_tbl != tbl);
			prev_tbl <= tbl;
		end
	
	// top-level state machine
	reg [1:0] state;
	reg spi_start, spi_done;
	always @(posedge clk)
		if(reset)
		begin
			// start off waiting
			state <= 2'b00;
			wmode <= 1'b0;
			spi_start <= 1'b0;
		end
		else
		begin
			spi_start <= 1'b0;
			
			case(state)
				2'b00:
				begin
					// waiting for start
					wmode <= 1'b0;
					state <= 2'b00;
					if(start)
					begin
						spi_start <= 1'b1;
						state <= 2'b01;
						wmode <= 1'b1;
					end
				end
				
				2'b01:
				begin
					// sending wakeup
					if(spi_done)
					begin
						spi_start <= 1'b1;
						state <= 2'b10;
					end
				end
				
				2'b10:
				begin
					// sending address
					if(spi_done)
					begin
						spi_start <= 1'b1;
						state <= 2'b11;
					end
				end
				
				2'b11:
				begin
					// receiving data
					if(spi_done)
					begin
						state <= 2'b00;
						wmode <= 1'b0;
					end
				end
			endcase
		end
		
	// SPI transaction state machine
	reg [5:0] spi_bcnt;		// bit count
	reg [14:0] spi_wcnt;	// word count
	reg [31:0] spi_tx;		// tx data register
	reg [15:0] spi_rx;		// rx data register
	reg delay;				// delay mode
	always @(posedge clk)
		if(reset)
		begin
			delay <= 1'b0;
			spi_sclk <= 1'b0;
			spi_bcnt <= 5'd0;
			spi_wcnt <= 15'h0000;
			waddr <= 13'd0;
			we <= 1'b0;
			spi_done <= 1'b0;
			spi_cs <= 1'b1;
			spi_tx <= 32'h00000000;
			spi_rx <= 16'h0000;
		end
		else
		begin
			we <= 1'b0;
			spi_done <= 1'b0;
				
			if(spi_wcnt == 14'h0000)
			begin
				if(spi_start)
					case(state)
						2'b01:
						begin
							// send wake up from powerdown
							spi_bcnt <= 6'd7;
							spi_wcnt <= 15'h0001;
							spi_tx <= 32'hAB000000;
							spi_cs <= 1'b0;
						end
					
						2'b10:
						begin
							// send read command
							spi_bcnt <= 6'd31;
							spi_wcnt <= 15'h0001;
							// simple read starting at addr 0x300000
							// tables located at 0x300000, 0x308000, 0x310000
							// max for 32Mb part is 0x3fffff
							//spi_tx <= {8'h03,7'h18,prev_tbl,15'h0000};
							spi_tx <= {8'h03,8'h30,prev_tbl,14'h0000};
							spi_cs <= 1'b0;
						end
					
						2'b11:
						begin
							// receive data
							spi_bcnt <= 5'd15;
							// 16k words
							spi_wcnt <= 15'h2000;
							//spi_wcnt <= 15'h0200;
							spi_tx <= 32'h00000000;
							waddr <= 13'h1fff;
						end
					endcase
			end
			else if(!delay)
			begin
				// toggle the serial clock
				spi_sclk <= ~spi_sclk;
					
				// advance state
				if(spi_sclk)
				begin
					// end of word
					if(spi_bcnt == 6'h00)
					begin
						// time to write?
						if(state == 2'b11)
						begin
							wdata <= {spi_rx[14:0],spi_miso};
							waddr <= waddr + 13'h0001;
							we <= 1'b1;
							spi_bcnt <= 6'd15;
						end
						
						// decrement word counter
						spi_wcnt <= spi_wcnt - 15'h0001;
						
						// done?
						if(spi_wcnt == 15'h0001)
						begin
							if(state[0])
							begin
								spi_cs <= 1'b1;
								if(!state[1])
								begin
									// start 20us delay after powerup cmd
									delay <= 1'b1;
									spi_wcnt <= 15'd960;
								end
							end
							
							if(state != 2'b01)
								spi_done <= 1'b1;
						end
					end
					else
					begin
						// shift and decrement bit counter
						spi_tx <= {spi_tx[30:0],1'b0};
						spi_bcnt <= spi_bcnt - 6'h01;
						spi_rx <= {spi_rx[14:0],spi_miso};
					end
				end
			end
			else
			begin
				// delay mode
				if(spi_wcnt==15'h0001)
				begin
					delay <= 1'b0;
					spi_done <= 1'b1;
				end
				spi_wcnt <= spi_wcnt-15'h0001;
			end
		end
		
	// temp tie down outputs
	//assign wdata = 16'h0000;
	//assign waddr = 13'h0000;
	//assign wmode = 1'b0;
	//assign we = 1'b0;
	assign spi_mosi = spi_tx[31];
	//assign spi_sclk = 1'b0;
	//assign spi_cs = 1'b1;
	assign spi_wp = 1'b1;
	assign spi_hld = 1'b1;
	assign diag = spi_wcnt[1:0];
endmodule
