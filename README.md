# up5k_resid
Modified reDIP-SID gateware to support audio in/out + DSP

## What is it?
This is a design that hosts a hardware DSP version of the ancient
Alesis Midiverb on the https://github.com/daglem/reDIP-SID. At the
moment the Midiverb logic has been stubbed out while development on
that continues, but this framework contains other things that are
needed to support it:

* Interfaces to the audio codec including I2C initializer and I2S serializer
* Clock generators
* Wet/Dry mixing
* muacm host control interface https://github.com/no2fpga/no2misc/blob/master/rtl/muacm2wb.v

## Caveat
The original reDIP-SID design runs the codec at 96kHz. The Midiverb requires
a sample rate of 23.4375kHz so the I2C initialization code has been altered
for the lower rate and the I2S serializer's internal pipelining had to be
tweaked to ensure proper edge timing at this rate.

