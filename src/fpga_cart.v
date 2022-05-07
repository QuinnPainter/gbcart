`include "util.v"

// https://upduino.readthedocs.io/en/latest/features/specs.html
// https://github.com/ghidraninja/gameboy-fpga-cartridge

module top (
    input [15:0] address,   // Address from cart bus
    inout [7:0] data,       // Data from cart bus
    input nWR,              // Write (from cart bus)
    input nRD,              // Read (from cart bus)
    output data_OE,         // Output enable for data level shifter
    output gb_reset,
    output spi_sck,
    output spi_ssn,
    output spi_mosi,
    input spi_miso
);

    wire clk; // 48 MHz clock from FPGA
    SB_HFOSC u_SB_HFOSC (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));

    wire [7:0] data_out;
    reg output_enable = 1'd0;
    wire rom_loaded;
    assign gb_reset = rom_loaded;

    wire tmpclk;
    //assign tmpclk = clk;
    divide_by_n #(.N(4)) divby (.clk(clk), .out(tmpclk));
    spram_gbrom spram_gbrom_inst (
        .clk (tmpclk),
        .addr (address[14:0]),
        .read_data (data_out),
        .rom_loaded (rom_loaded),
        .spi_sck (spi_sck),
        .spi_ssn (spi_ssn),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    // Enable data output if required, otherwise high-impedance
    assign data = output_enable ? data_out : 8'bzzzzzzzz;
    assign data_OE = output_enable;

    always @(posedge clk) begin
        if (rom_loaded == 1'b1) begin
            // Don't output signal if WR, or address[15] are asserted
            // Or READ is not asserted
            if(address[15] || nRD || ~nWR) begin
                output_enable <= 1'd0;
            end else begin
                output_enable <= 1'd1;
            end
        end
    end
endmodule

// Module that allows access to a 32k (16k x 16) RAM module
// The RAM is first loaded with a 32k ROM from SPI flash
// https://www.digikey.com/en/datasheets/winbond-electronics/winbond-electronicsw25q32jv20spi20revf2005112017
module spram_gbrom (
    input clk,
    input [14:0] addr,
    output [7:0] read_data,
    output rom_loaded,
    output reg spi_sck,
    output reg spi_ssn,
    output reg spi_mosi,
    input spi_miso
);

    reg [13:0] spram_init_addr; // address used when writing to the SPRAM
    reg [15:0] spram_init_data; // data lines used when writing

    wire [15:0] rdata_16;
    assign read_data = addr[0] ? rdata_16[15:8] : rdata_16[7:0];

    SB_SPRAM256KA spram_inst(
        .DATAIN(spram_init_data),
        .ADDRESS(rom_loaded ? addr[14:1] : spram_init_addr),
        .MASKWREN(4'b1111),
        .WREN(!rom_loaded),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_16)
    );

    reg [7:0] flash_wakecommand;
    reg [31:0] flash_readcommand;
    reg [15:0] spi_cur_data; // 16 bit word last read from flash
    reg [2:0] spi_counter_clk;
    reg [4:0] spi_bit_ctr; // 0 to 31
    reg [2:0] spi_state; // 0 = Send wake command, 1 = Delay after wake, 2 = Sending read command, 3 = Reading, 4 = Done reading
    reg [31:0] init_waitctr;

    assign rom_loaded = spi_state == 4;

    initial begin
        spram_init_addr = 0;
        // Read command is 03, data address is 100000
        flash_readcommand = 32'h03100000;
        flash_wakecommand = 8'hAB;
        spi_state = 2;
        spi_bit_ctr = 0;
        spi_counter_clk = 0;
        init_waitctr = 0;
    end

    always @(posedge clk) begin
        case (spi_state)
            0: begin // Waking up the flash
                spi_ssn <= 1'b0;
                spi_counter_clk <= spi_counter_clk + 1;
                case (spi_counter_clk)
                    3'b000: begin
                        spi_sck <= 0;
                        spi_mosi <= flash_wakecommand[7];
                    end
                    3'b100: begin
                        spi_sck <= 1;
                    end
                    3'b111: begin
                        flash_wakecommand[7:0] <= {flash_wakecommand[6:0], flash_wakecommand[7]}; // rotate left
                        spi_bit_ctr <= spi_bit_ctr + 1;
                        if (spi_bit_ctr == 7) begin
                            spi_bit_ctr <= 0;
                            spi_state <= 1;
                        end
                    end
                    default: begin end
                endcase
            end
            1: begin // Delay after sending wake command
                spi_ssn <= 1'b1;
                init_waitctr <= init_waitctr + 1;
                if (init_waitctr == 32'h01000000) begin // overkill delay for sure
                    spi_state = 2;
                end
            end
            2: begin // Send "read" command and address
                spi_ssn <= 1'b0;
                spi_counter_clk <= spi_counter_clk + 1;
                case (spi_counter_clk)
                    3'b000: begin
                        spi_sck <= 0;
                        spi_mosi <= flash_readcommand[31];
                    end
                    3'b100: begin
                        spi_sck <= 1;
                    end
                    3'b111: begin
                        flash_readcommand[31:0] <= {flash_readcommand[30:0], flash_readcommand[31]}; // rotate left
                        spi_bit_ctr <= spi_bit_ctr + 1;
                        if (spi_bit_ctr == 31) begin
                            spi_bit_ctr <= 0;
                            spi_state <= 3;
                        end
                    end
                    default: begin end
                endcase
            end
            3: begin // Read data
                spi_ssn <= 1'b0;
                spi_counter_clk <= spi_counter_clk + 1;
                case (spi_counter_clk)
                    3'b000: begin
                        spi_sck <= 0;
                    end
                    3'b100: begin
                        spi_sck <= 1;
                    end
                    3'b110: begin
                        spi_cur_data[15] <= spi_miso;
                    end
                    3'b111: begin
                        spi_cur_data[15:0] <= {spi_cur_data[14:0], spi_cur_data[15]}; // rotate left
                        spi_bit_ctr <= spi_bit_ctr + 1;
                        if (spi_bit_ctr == 15) begin
                            spi_bit_ctr <= 0;
                            spram_init_data <= spi_cur_data;
                            spram_init_addr <= spram_init_addr + 1;
                            if (spram_init_addr == 16383) begin
                                spi_state <= 4;
                                spi_ssn <= 1'b1;
                            end
                        end
                    end
                    default: begin end
                endcase
            end
            4: begin end // Done reading
        endcase
    end
endmodule
