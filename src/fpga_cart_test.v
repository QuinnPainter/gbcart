`default_nettype none
`timescale 1ns / 100ps

module fpga_cart_tb;

    reg clk = 0;
    reg [14:0] addr = 0;
    wire [7:0] read_data;
    wire rom_loaded;
    wire spi_sck;
    wire spi_ssn;
    wire spi_mosi;
    //reg spi_miso = 0;
    wire spi_miso;

    initial begin // record to file
        $dumpfile("fpga_cart_test.vcd");
        $dumpvars(0, fpga_cart_tb);
    end

    /*initial begin
        #20000000 $finish;
    end*/

    always #42 clk = !clk;	// ~ 12 MHz

    always begin
        #10 if (rom_loaded == 1) begin $finish; end
    end

    spram_gbrom model_inst(
        .clk (clk),
        .addr (addr),
        .read_data (read_data),
        .rom_loaded (rom_loaded),
        .spi_sck (spi_sck),
        .spi_ssn (spi_ssn),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    sst25vf010A flsh_inst(
        .WPn (1),	
        .SO (spi_miso),
        .HOLDn (1),
        .SCK (spi_sck),
        .CEn (spi_ssn),
        .SI (spi_mosi)
    );

endmodule
