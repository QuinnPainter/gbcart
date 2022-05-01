# Makefile to build UPduino v3.0 rgb_blink.v  with icestorm toolchain
# Original Makefile is taken from: 
# https://github.com/tomverbeure/upduino/tree/master/blink
# On Linux, copy the included upduinov3.rules to /etc/udev/rules.d/ so that we don't have
# to use sudo to flash the bit file.
# Thanks to thanhtranhd for making changes to thsi makefile.

BUILD    := _build

fpga_cart.bin: $(BUILD)/fpga_cart.asc
	@mkdir -p $(dir $@)
	icepack $(BUILD)/fpga_cart.asc fpga_cart.bin

$(BUILD)/fpga_cart.asc: $(BUILD)/fpga_cart.json common/upduino.pcf
	@mkdir -p $(dir $@)
	nextpnr-ice40 --up5k --package sg48 --json $(BUILD)/fpga_cart.json --pcf common/upduino.pcf --asc $(BUILD)/fpga_cart.asc

$(BUILD)/fpga_cart.json: src/fpga_cart.v
	@mkdir -p $(dir $@)
	yosys -q -p "synth_ice40 -json $(BUILD)/fpga_cart.json" src/fpga_cart.v

.PHONY: flash
flash:
	iceprog -d i:0x0403:0x6014 fpga_cart.bin

.PHONY: clean
clean:
	$(RM) -rf $(BUILD) fpga_cart.bin
