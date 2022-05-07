
BUILD    := _build

all: fpga_cart.bin

.SECONDARY: # prevents auto-deletion of intermediate files

%.bin: $(BUILD)/%.asc
	@mkdir -p $(dir $@)
	icepack -s $< $@

$(BUILD)/%.asc: $(BUILD)/%.json src/%.pcf
	@mkdir -p $(dir $@)
	nextpnr-ice40 --up5k --package sg48 --json $< --pcf src/$*.pcf --asc $@

$(BUILD)/%.json: src/%.v
	@mkdir -p $(dir $@)
	yosys -q -p "read_verilog $<" -p "synth_ice40 -top top -json $@" -E $(BUILD)/$*.d

test:
	iverilog -D NO_ICE40_DEFAULT_ASSIGNMENTS -I src -o fpga_cart.vvp src/fpga_cart_test.v src/fpga_cart.v /usr/local/share/yosys/ice40/cells_sim.v
	vvp fpga_cart.vvp
	gtkwave fpga_cart_test.vcd

.PHONY: clean
clean:
	$(RM) -rf $(BUILD) fpga_cart.bin *.vvp *.vcd

-include $(BUILD)/*.d
