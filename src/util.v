// https://github.com/osresearch/up5k
`ifndef util_v
`define util_v

`define CLOG2(x) \
   x <= 2	 ? 1 : \
   x <= 4	 ? 2 : \
   x <= 8	 ? 3 : \
   x <= 16	 ? 4 : \
   x <= 32	 ? 5 : \
   x <= 64	 ? 6 : \
   x <= 128	 ? 7 : \
   x <= 256	 ? 8 : \
   x <= 512	 ? 9 : \
   x <= 1024	 ? 10 : \
   x <= 2048	 ? 11 : \
   x <= 4096	 ? 12 : \
   x <= 8192	 ? 13 : \
   x <= 16384	 ? 14 : \
   x <= 32768	 ? 15 : \
   x <= 65536	 ? 16 : \
   -1

module divide_by_n(
	input clk,
	output reg out
);
	parameter N = 2;

	reg [`CLOG2(N)-1:0] counter;

	always @(posedge clk) begin
		out <= 0;

		if (counter == 0) begin
			out <= 1;
			counter <= N - 1;
        end else begin
			counter <= counter - 1;
        end
	end
endmodule

`endif
