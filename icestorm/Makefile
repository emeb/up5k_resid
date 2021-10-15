# Makefile for icestorm tools + yosys + nextpnr
# Modified from examples in icestorm distribution
# 01-16-18 E. Brombaugh

# src directory
VPATH = ../src

SRC =	up5k_resid_top.v ../src/i2s.v ../src/muacm.v ../src/i2c_master.v \
		../src/i2c_state_machine.v ../src/sysmgr_hfosc.v ../src/sat.v \
		../src/mv.v ../src/spi_ctrl.v ../src/wetdry.v ../src/sine.v \
		../src/muacm2wb.v ../src/stream2wb.v ../src/xclk_wb.v \
		../src/xclk_strobe.v ../src/muacm_xclk.v

# project stuff
PROJ = up5k_resid_top
PIN_DEF = up5k_resid_top.pcf
SDC = up5k_resid_top.sdc
DEVICE = up5k
PACKAGE = sg48

TOOLS = /opt/openfpga/fpga-toolchain
YOSYS = $(TOOLS)/bin/yosys
YOSYS_SYNTH_ARGS = -dsp -relut -dffe_min_ce_use 4
NEXTPNR = $(TOOLS)/bin/nextpnr-ice40
NEXTPNR_ARGS = --pre-pack $(SDC) --placer heap
ICEPACK = $(TOOLS)/bin/icepack
ICETIME = $(TOOLS)/bin/icetime
ICEPROG = $(TOOLS)/bin/iceprog
ICEBRAM = $(TOOLS)/bin/icebram
CDCPROG = cdc_prog
DFU_UTIL = dfu-util
VERILATOR = verilator
TECH_LIB = $(TOOLS)/share/yosys/ice40/cells_sim.v

all: $(PROJ).bin

%.json: $(SRC)
	$(YOSYS) -g -p 'synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(PROJ) -json $@' $(SRC)

%.asc: %.json $(PIN_DEF) 
	$(NEXTPNR) $(NEXTPNR_ARGS) --$(DEVICE) --package $(PACKAGE) --json $< \
	--pcf $(PIN_DEF) --asc $@
		
%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 $<

flash: $(PROJ).bin
	$(CDCPROG) -w -a 0x80000 -p /dev/ttyACM0 $<

dfu: $(PROJ).bin
	$(DFU_UTIL) -a0 -D $< -R
    
ucode: ucode.bin
	$(CDCPROG) -a 0x300000 -w -p /dev/ttyACM0 $<

lint: $(SRC)
	$(VERILATOR) --lint-only -Wall --top-module $(PROJ) $(TECH_LIB) $(SRC)

clean:
	rm -f *.json *.asc *.rpt *.bin

.SECONDARY:
.PHONY: all prog clean
