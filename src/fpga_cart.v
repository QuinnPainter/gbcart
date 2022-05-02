module gbrom
(
    // 16 address pins
    input  [15:0] address,

    // Data pins (bidirectional)
    inout [7:0] data,

    // Signals from cartridge
    input nWR,   // Write
    input nRD,   // Read
    
    // Output enable for data level shifter
    output OE,

    // 48 MHz clock from FPGA
    input wire clk,
);

reg[7:0] rom[0:490];

// Read headers & ROM from files
initial
begin
    $readmemh("rom.hex",rom, 0, 490);
end

reg [7:0] data_out = 8'd0;
reg output_enable = 1'd0;

// Enable data output if required, otherwise high-impedance
assign data = output_enable ? data_out : 8'bzzzzzzzz;
assign OE = output_enable;

always @(posedge clk) begin
    // Don't output signal if WR, or address[15] are asserted
    // Or READ is not asserted
    if(address[15] || nRD || ~nWR) begin
        output_enable <= 1'd0;
    end else begin
        data_out <= rom[address];
        output_enable <= 1'd1;
    end
end
endmodule

// https://upduino.readthedocs.io/en/latest/features/specs.html
// https://github.com/ghidraninja/gameboy-fpga-cartridge

module top (
    input wire gpio_2,
    input wire gpio_46,
    input wire gpio_47,
    input wire gpio_45,
    input wire gpio_48,
    input wire gpio_3,
    input wire gpio_4,
    input wire gpio_44,
    input wire gpio_6,
    input wire gpio_9,
    input wire gpio_11,
    input wire gpio_18,
    input wire gpio_19,
    input wire gpio_13,
    input wire gpio_21,
    input wire gpio_12, // address
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
