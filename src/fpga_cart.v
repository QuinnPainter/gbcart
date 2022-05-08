`include "util.v"
`include "spi_flash_reader.v"

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
    output reg rom_loaded,
    output spi_sck,
    output spi_ssn,
    output spi_mosi,
    input spi_miso
);

    reg [14:0] spram_init_addr; // address used when writing to the SPRAM (extra bit so it can be negative)
    reg [15:0] spram_init_data; // data lines used when writing

    wire [15:0] rdata_16;
    assign read_data = addr[0] ? rdata_16[15:8] : rdata_16[7:0];

    SB_SPRAM256KA spram_inst(
        .DATAIN(spram_init_data),
        .ADDRESS(rom_loaded ? addr[14:1] : spram_init_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(!rom_loaded),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_16)
    );

    reg [7:0] rst_cnt = 0; // generate startup reset signal
    wire rst_n = rst_cnt[7];
    always @(posedge clk) begin
        if (!rst_n)
            rst_cnt <= rst_cnt + 1;
    end

    reg [23:0] spi_addr;
    reg spi_go;
    wire [7:0] spi_data;
    wire spi_valid;
    wire spi_rdy;

    reg [7:0] spi_data_buffer; // Data comes in bytes, so buffer one byte and combine them into one 16 bit num
    reg spi_data_oddbyte;       // keep track of if we're on top or bottom byte

    initial begin
        spram_init_addr = -1; // gets incremented to 0 on first iteration
        spi_addr = 24'h100000;
        spi_go = 0;
        rom_loaded = 0;
        spi_data_oddbyte = 0;
    end

    spi_flash_reader spi_reader_inst (
   	    // SPI interface
   	    .spi_mosi(spi_mosi),
   	    .spi_miso(spi_miso),
   	    .spi_cs_n(spi_ssn),
   	    .spi_clk(spi_sck),
    
   	    // Command interface
   	    .addr(spi_addr),
   	    .len(16'h8000),
   	    .go(spi_go),
   	    .rdy(spi_rdy),
    
   	    // Data interface
   	    .data(spi_data),
   	    .valid(spi_valid),
    
   	    // Clock / Reset
   	    .clk(clk),
   	    .rst(rst_n)
    );

    always @(posedge clk) begin
        if(!rst_n) begin
            spi_go <= 0;
        end else if(spi_rdy & ~spi_go & !rom_loaded) begin
            spi_go <= 1;
        end else begin
            spi_go <= 0;
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
        end else if(spi_valid & !rom_loaded) begin
            if (spi_data_oddbyte) begin
                spram_init_data <= {spi_data, spi_data_buffer}; 
            end else begin
                spi_data_buffer <= spi_data;
            end
            spram_init_addr <= spram_init_addr + spi_data_oddbyte;
            spi_data_oddbyte <= ~spi_data_oddbyte;
            if (spram_init_addr == 16383) begin
                rom_loaded <= 1;
            end
        end
    end

    /*always @(posedge clk) begin
        case (spi_state)
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
    end*/
endmodule
