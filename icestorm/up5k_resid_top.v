`default_nettype none

//`define NO_MUACM

module up5k_resid_top (
    // I2S
    output wire i2s_din,
    input  wire i2s_dout,
    input  wire i2s_sclk,
    input  wire i2s_lrclk,
    // I2C (shared)
    inout  wire scl_led,
    inout  wire sda_btn,
    // USB
    inout  wire usb_dp,
    inout  wire usb_dn,
    output wire usb_pu,
    // Clock
    input  wire sys_clk,
    // data bus
    inout  wire d0,
    inout  wire d1,
    inout  wire d2,
    inout  wire d3,
    inout  wire d4,
    inout  wire d5,
    inout  wire d6,
    inout  wire d7,
    // address bus
    inout  wire a0,
    inout  wire a1,
    inout  wire a2,
    inout  wire a3,
    inout  wire a4,
    // sid clock
    //
    inout  wire phi2,
    // sid chip select
    inout  wire cs_n,
    // sid read/write
    inout  wire rw,
    inout  wire pot_x,
    inout  wire pot_y,
	// spi flash
	output spi_mosi,
	input spi_miso,
	output spi_clk,
	output spi_cs_n,
	output spi_sio2,
	output spi_sio3
);
	// Local reset - delayed for RAM init
	wire rst;
	reg [15:0] rst_cnt = 0;
	wire rst_i = ~rst_cnt[15];
	always @(posedge sys_clk) begin
		if (~rst_cnt[15]) begin
			rst_cnt <= rst_cnt + 1;
		end
	end

	// Promote reset signal to global buffer
	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst)
	);

	// Audio data
	wire i2sSampled;
	wire signed [15:0] rx_l, rx_r;
	wire signed [15:0] tx_l, tx_r;
	wire [1:0] tbl;
	wire [5:0] prog;
	wire [11:0] mix;
	
//`define SAWTOOTH
`ifdef SAWTOOTH
	//------------------------------
	// NCO
	//------------------------------
	reg [31:0] phs;
	wire [31:0] frq = 31'd18325199;	// 100Hz @ 23.4375kHz Fs
	always @(posedge sys_clk)
		if(rst)
			phs <= 16'd0;
		else if(i2sSampled)
			phs <= phs + frq;

	//------------------------------
	// Sinewave shaper
	//------------------------------
	wire signed [15:0] sine;
	sine usine(
		.clk(sys_clk),		// system clock
		.reset(rst),		// system reset
		.ena(i2sSampled),	// system clock enable
		.phs(phs),			// phase input
		.out(sine),			// wave output
		.valid()
	);
	assign tx_l = sine;
	//assign tx_l = {sine[15],sine[15:1]};
		
	//------------------------------
	// Saw shaper
	//------------------------------
	//assign tx_r = phs[31:16];
	assign tx_r = rx_l;
	wire mv_valid = i2sSampled;
`else
	//------------------------------
	// clk divider for Midiverb
	//------------------------------
	reg [2:0] clkdiv;
	reg ena;
	always @(posedge sys_clk)
	begin
		if(rst)
		begin
			clkdiv <= 3'd0;
			ena <= 1'b0;
		end
		else
		begin
			clkdiv <= clkdiv + 3'd1;
			ena <= clkdiv == 3'b111;
		end
	end
	
`define FLASH_PROGS
`ifdef FLASH_PROGS
	//------------------------------
	// SPI Flash RAM loader
	//------------------------------
	wire [15:0] ucode_data;
	wire [12:0] uc_w_addr;
	wire ucode_wmode, ucode_we;
	spi_ctrl uspi(
		.clk(sys_clk),
		.reset(rst),
		.tbl(tbl),
		.wdata(ucode_data),
		.waddr(uc_w_addr),
		.wmode(ucode_wmode),
		.we(ucode_we),
		.spi_mosi(spi_mosi),
		.spi_sclk(spi_clk),
		.spi_cs(spi_cs_n),
		.spi_wp(spi_sio2),
		.spi_hld(spi_sio3),
		.spi_miso(spi_miso),
		.diag()
	);
`else
	//------------------------------
	// Flash RAM loader stubs
	//------------------------------
	wire [15:0] ucode_data = 16'd0;
	wire [12:0] uc_w_addr = 13'd0;
	wire ucode_wmode = 1'b0, ucode_we = 1'b0;
`endif

	wire signed[15:0] mv_l, mv_r;
	wire mv_valid;
`define MV
`ifdef MV
	//------------------------------
	// Midiverb DSP
	//------------------------------
    mv uut(
        .clk(sys_clk),          	// 24 MHz system clock
        .reset(rst),      			// reset
		.ena(ena),					// 1/8 rate clock enable
		.prog(prog),				// program number
		.uc_w_addr(uc_w_addr),		// microcode write addr
		.ucode_data(ucode_data),	// microcode write data
		.ucode_wmode(ucode_wmode),	// microcode write mode
		.ucode_we(ucode_we),		// microcode write enable
		.in(rx_l),					// audio input
		.out_l(mv_l),				// left output
		.out_r(mv_r),				// right output
		.valid(mv_valid)			// valid output
	);
`else
	// bypass mv
	assign mv_l = rx_l;
	assign mv_r = rx_r;
	assign mv_valid = i2sSampled;
`endif
	
	wire signed [15:0] tx_l, tx_r;
	wire wd_valid;
`define WD
`ifdef WD
	//------------------------------
	// wet/dry mix
	//------------------------------
	wetdry uwd(
		.clk(sys_clk),
		.reset(rst),
		.ena(mv_valid),
		.pot(mix),
		.dry_l(rx_l),
		.dry_r(rx_l),
		.wet_l(mv_l),
		.wet_r(mv_r),
		.out_l(tx_l),
		.out_r(tx_r),
		.valid(wd_valid)
	);
`else
	// bypass w/d mix
	assign tx_l = mv_l;
	assign tx_r = mv_r;
`endif
`endif
		
	// I2S encoder
	wire i2sSampled;
	i2s u_i2s (
		.CLK(sys_clk),
		.IN_L(tx_l),
		.IN_R(tx_r),
		.OUT_L(rx_l),
		.OUT_R(rx_r),
		.i2s_sclk(i2s_sclk),
		.i2s_lrclk(i2s_lrclk),
		.i2s_din(i2s_din),
		.i2s_dout(i2s_dout),
		.i2s_sampled(i2sSampled)
	);

	// I2C setup
	i2c_state_machine ism (
		.scl_led(scl_led),
		.sda_btn(sda_btn),
		.btn    (),
		.led    (1'b0),
		.done   (),
		.clk    (sys_clk),
		.rst    (rst)
	);

`ifndef NO_MUACM
	// Use HF OSC to generate USB clock
	wire clk_usb;
	wire rst_usb;
	sysmgr_hfosc sysmgr_I (
		.rst_in (rst),
		.clk_out(clk_usb),
		.rst_out(rst_usb)
	);

//`define RAW_MUACM
`ifdef RAW_MUACM
	// Local signals
	wire bootloader;
	reg  boot = 1'b0;

	// Instance
	wire [7:0] in_data;
	wire in_last, in_valid, in_ready;
	muacm acm_I (
		.usb_dp       (usb_dp),
		.usb_dn       (usb_dn),
		.usb_pu       (usb_pu),
		.in_data      (in_data),
		.in_last      (in_last),
		.in_valid     (in_valid),
		.in_ready     (in_ready),
		.in_flush_now (1'b0),
		.in_flush_time(1'b1),
		.out_data     (in_data),
		.out_last     (in_last),
		.out_valid    (in_valid),
		.out_ready    (in_ready),
		.bootloader   (bootloader),
		.clk          (clk_usb),
		.rst          (rst_usb)
	);
	
	// static controls
	assign tbl = 2'b00;
	assign prog = 6'd49;
	assign mix = 12'h800;

	// Warmboot
	always @(posedge clk_usb) begin
		boot <= boot | bootloader;
	end
`else
	// WB MUACM
	wire [31:0] aux_csr;
	wire  boot;
	reg wb_ack;
	reg wb_cyc;
	muacm2wb uwb (
		.usb_dp(usb_dp),
		.usb_dn(usb_dn),
		.usb_pu(usb_pu),

		.usb_clk(clk_usb),
		.usb_rst(rst_usb),

		.wb_wdata(),
		.wb_rdata(),
		.wb_addr(),
		.wb_we(),
		.wb_cyc(wb_cyc),
		.wb_ack(wb_ack),

		.aux_csr(aux_csr),

		.bootloader(boot),

		.clk(sys_clk),
		.rst(rst)
	);
	
	// dummy wb ack
	always @(posedge sys_clk)
		wb_ack <= wb_cyc & ~wb_ack;	
	
	// hook up csr
	// dynamic controls
	assign tbl = aux_csr[19:18];
	assign prog = aux_csr[17:12];
	assign mix = aux_csr[11:0];
	
`endif
	SB_WARMBOOT warmboot (
		.BOOT(boot),
		.S0  (1'b1),
		.S1  (1'b0)
	);
`endif
	
	// diagnostics
	assign d0 = rx_l[15];
	assign d1 = rx_l[14];
	assign d2 = i2s_lrclk;
	assign d3 = i2s_sclk;
	assign d4 = i2s_din;
	assign d5 = i2s_dout;
	assign d6 = i2sSampled;
	assign d7 = mv_valid;
		
endmodule
