#!/usr/bin/env python3

#
# memtest.py
#
# Base utiity/driver classes for the various control software variants
#
# Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: MIT
#

import binascii
import random
import serial
import sys
import argparse

# ----------------------------------------------------------------------------
# Serial commands
# ----------------------------------------------------------------------------

class WishboneInterface(object):

	COMMANDS = {
		'SYNC' : 0,
		'REG_ACCESS' : 1,
		'DATA_SET' : 2,
		'DATA_GET' : 3,
		'AUX_CSR' : 4,
	}

	def __init__(self, port):
		self.ser = ser = serial.Serial()
		ser.port = port
		ser.baudrate = 2000000
		ser.stopbits = 2
		ser.timeout = 0.1
		ser.open()

		if not self.sync():
			raise RuntimeError("Unable to sync")

	def sync(self):
		for i in range(10):
			self.ser.write(b'\x00')
			d = self.ser.read(4)
			if (len(d) == 4) and (d == b'\xca\xfe\xba\xbe'):
				print("Synced")
				return True
		return False

	def write(self, addr, data):
		cmd_a = ((self.COMMANDS['DATA_SET']   << 36) | data).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['REG_ACCESS'] << 36) | addr).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)

	def read(self, addr):
		cmd_a = ((self.COMMANDS['REG_ACCESS'] << 36) | (1<<20) | addr).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['DATA_GET']   << 36)).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)
		d = self.ser.read(4)
		if len(d) != 4:
			raise RuntimeError('Comm error')
		return int.from_bytes(d, 'big')

	def aux_csr(self, value):
		cmd = ((self.COMMANDS['AUX_CSR'] << 36) | value).to_bytes(5, 'big')
		self.ser.write(cmd)

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

parser = argparse.ArgumentParser(description='Talk to the reSID Midiverb FPGA')
parser.add_argument('-p', '--prog', dest='prog', default = 21,
                    help='Program # (0-62)')
parser.add_argument('-m', '--mix', dest='mix', default = 2048,
                    help='Wet/Dry mix 0-4095')
parser.add_argument('-r', '--rom', dest='rom', default = 0,
                    help='Midiverb ROM (0 = midiverb, 1=midifex)')
parser.add_argument('-d', '--device', dest='device', default='/dev/ttyACM0',
                    help='USB serial device of FPGA')
args = parser.parse_args()

# Connect to board
wb = WishboneInterface(args.device)

rom = int(args.rom) & 1
prog = int(args.prog) & 63
mix = int(args.mix) & 4095

print(rom)
print(prog)
print(mix)

# build aux reg
aux = (rom << 18) | (prog << 12) | mix

print(aux)

# set aux
wb.aux_csr(aux)
