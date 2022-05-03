module gbrom (
    input clk,              // 48 MHz clock from FPGA
    input [15:0] address,   // Address from cart bus
    inout [7:0] data,       // Data from cart bus
    input nWR,              // Write (from cart bus)
    input nRD,              // Read (from cart bus)
    output OE,              // Output enable for data level shifter
);

wire [7:0] data_out;
reg output_enable = 1'd0;
wire rom_loaded;

spram_gbrom spram_gbrom_inst (
    .clk (clk),
    .addr (address[14:0]),
    .read_data (data_out),
    .rom_loaded (rom_loaded)
);

/*reg[7:0] rom[0:490];

// Read headers & ROM from files
initial begin
    $readmemh("rom.hex",rom, 0, 490);
end*/

// Enable data output if required, otherwise high-impedance
assign data = output_enable ? data_out : 8'bzzzzzzzz;
assign OE = output_enable;

always @(posedge clk) begin
    if (rom_loaded == 1'b1) begin
        // Don't output signal if WR, or address[15] are asserted
        // Or READ is not asserted
        if(address[15] || nRD || ~nWR) begin
            output_enable <= 1'd0;
        end else begin
            //data_out <= rom[address];
            output_enable <= 1'd1;
        end
    end
end
endmodule

// Module that allows access to a 32k (16k x 16) RAM module
// The RAM is first loaded with a 32k ROM from SPI flash
module spram_gbrom (
    input clk,
    input [14:0] addr,
    output [7:0] read_data,
    output reg rom_loaded,
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

initial begin
    rom_loaded = 1'b0;
    spram_init_addr = 0;
end

always @(posedge clk) begin
    if (rom_loaded == 1'b0) begin
        spram_init_data <= 16'b1001000010010000; // todo: actual data
        spram_init_addr = spram_init_addr + 1;
        if (spram_init_addr == 16383) begin
            rom_loaded <= 1'b1;
        end
    end
end
endmodule

// https://upduino.readthedocs.io/en/latest/features/specs.html
// https://github.com/ghidraninja/gameboy-fpga-cartridge

module top (
    input gpio_2,
    input gpio_46,
    input gpio_47,
    input gpio_45,
    input gpio_48,
    input gpio_3,
    input gpio_4,
    input gpio_44,
    input gpio_6,
    input gpio_9,
    input gpio_11,
    input gpio_18,
    input gpio_19,
    input gpio_13,
    input gpio_21,
    input gpio_12, // address
    inout gpio_42,
    inout gpio_36,
    inout gpio_43,
    inout gpio_34,
    inout gpio_37,
    inout gpio_31,
    inout gpio_32,
    inout gpio_27, // data
    input gpio_25, // write
    input gpio_26, // read
    output gpio_38, // OE
);

    wire int_osc;

    SB_HFOSC u_SB_HFOSC (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(int_osc));

    wire [15:0] address;
    wire [7:0] data;

    assign address[15] = gpio_2;
    assign address[14] = gpio_46;
    assign address[13] = gpio_47;
    assign address[12] = gpio_45;
    assign address[11] = gpio_48;
    assign address[10] = gpio_3;
    assign address[9] = gpio_4;
    assign address[8] = gpio_44;
    assign address[7] = gpio_6;
    assign address[6] = gpio_9;
    assign address[5] = gpio_11;
    assign address[4] = gpio_18;
    assign address[3] = gpio_19;
    assign address[2] = gpio_13;
    assign address[1] = gpio_21;
    assign address[0] = gpio_12;

    assign data[7] = gpio_42;
    assign data[6] = gpio_36;
    assign data[5] = gpio_43;
    assign data[4] = gpio_34;
    assign data[3] = gpio_37;
    assign data[2] = gpio_31;
    assign data[1] = gpio_32;
    assign data[0] = gpio_27;

    // vin is gpio_23
    gbrom gbromA(
        .address (address),
        .data (data),
        .nWR (gpio_25),
        .nRD (gpio_26),
        .OE  (gpio_38),
        .clk (int_osc)
    );

endmodule

/*module spi_flash(
    input clk,
    output spi_sck,
    output spi_ss,
    output spi_mosi,
    input spi_miso,
);

    spi_send_rcv_byte spi_send_rcv_byte_inst (
        .clk (clk),
        .spi_sck (spi_sck),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

initial begin
end

always @(posedge clk) begin
end
endmodule

module spi_send_rcv_byte(
    input clk,
    output reg spi_sck,
    output reg spi_mosi,
    input spi_miso,
    inout [7:0] data,
    output reg read_finished
)

reg [1:0] state; // 0 = Inactive, 1 = Read, 2 = Write
reg [2:0] counter_clk;

reg [7:0] cur_byte;
reg [2:0] bit_ctr; // counts 0 to 7

assign data = state == 1 ? cur_byte : 8'bzzzzzzzz;

initial begin
    state = 0;
    bit_ctr = 0;
    read_finished = 0;
end

always @(posedge clk) begin
    case (state)
        1: begin // Read
            read_finished <= 0;
            counter_clk <= counter_clk + 1
            spi_mosi <= 0;
            case (counter_clk)
                3'b000: begin
                    spi_sck <= 0;
                end
                3'b100: begin
                    spi_sck <= 1;
                end
                3'b110: begin
                    cur_byte[7] <= spi_miso;
                end
                3'b111: begin
                    cur_byte <= {cur_byte[6:0], cur_byte[7]} // rotate left
                    bit_ctr <= bit_ctr + 1;
                    if (bit_ctr == 7) begin
                        state <= 0;
                        read_finished <= 1;
                    end
                end
            endcase
        end
        2: begin // Write
            counter_clk <= counter_clk + 1
            case (counter_clk)
                3'b000: begin
                    cur_byte <= data;
                    spi_sck <= 0;
                    spi_mosi <= cur_byte[7];
                end
                3'b100: begin
                    spi_sck <= 1;
                end
                3'b111: begin
                    cur_byte <= {cur_byte[6:0], cur_byte[7]} // rotate left
                    bit_ctr <= bit_ctr + 1;
                    if (bit_ctr == 7) begin
                        state <= 0;
                    end
                end
            endcase
        end
    endcase
end
endmodule*/
