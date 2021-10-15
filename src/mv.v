// mv.v - midiverb stub. Actual functionality will be added later
// 10-15-21 E. Brombaugh

module mv(
	input clk,
	input reset,
	input ena,
	input signed [15:0] in,
	input [5:0] prog,
	input [12:0] uc_w_addr,
	input [15:0] ucode_data,
	input ucode_wmode, ucode_we,
	output reg signed [15:0] out_l, out_r,
	output reg valid);
		
	// Microcode stored on SPRAM
	wire [15:0] ucode;
	wire [13:0] ucode_addr = {1'b0,ucode_wmode ? uc_w_addr : {rprog,iaddr}};
		
	SB_SPRAM256KA
		ucram(
			.ADDRESS(ucode_addr),
			.DATAIN(ucode_data),
			.MASKWREN(4'hf),
			.WREN(ucode_we),
			.CHIPSELECT(1'b1),
			.CLOCK(clk),
			.STANDBY(1'b0),
			.SLEEP(1'b0),
			.POWEROFF(1'b1),
			.DATAOUT({ucode[7:0],ucode[15:8]})
		);
	
	// pass-thru
	assign out_l = in;
	assign out_r = in;
	assign valid = ena;
endmodule
