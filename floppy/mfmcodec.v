`define WPC_NOPCOMP		0
`define WPC_LATE		1
`define WPC_EARLY		2

module cdrpll(
	input mclk,
	input mr,
	input en,
	input in,
	output reg data,
	output samp_en,
	output out,

	input [1:0] wpc_action,
	output reg wpc_pulse
);

// MINIMUM PERIOD:	7/8 T	(maximum frequency:	8/7 f)
// MAXIMUM PERIOD:	9/8 T	(minimum frequency:	8/9 f)
// f = 1MHz		=>		f_max = 1.14MHz,	f_min = 0.88MHz
// FREQUENCY MARGIN:		+14%, -11%

reg [3:0] counter;
reg [2:0] in_sampling;
wire rising_edge;
assign rising_edge = in_sampling[2:1] == 2'b01;

assign out = counter>=8 && counter<=15;
assign samp_en = counter == 7;

always @* begin
	wpc_pulse = counter>=0 && counter<=7;
	case (wpc_action)
	`WPC_LATE: wpc_pulse = counter>=2 && counter<=7;
	`WPC_EARLY: wpc_pulse = counter>=0 && (counter<=7 || counter>=14);
	endcase
end

always @(posedge mclk, posedge mr) begin
	if (mr) begin
		counter <= 0;
		in_sampling <= 0;
		data <= 0;
	end else if (en) begin
		in_sampling <= {in_sampling[1:0], in};
		if (rising_edge) begin
			data <= 1;
			counter <= 0;
		end else begin
			if (counter == 15) data <= 0;
			counter <= counter+1;
		end
	end
end

endmodule

module mfmcodec(
	input mclk,
	input n_mr,
	input en,
	input encode_en,
	input wcp_en,

	input rd,
	output wg, wr,

	inout [7:0] d,
	inout a1,
	output dck,

	output bus_cycle,
	output write_pulse
);

reg [1:0] wpc_action;
wire wpc_pulse;

wire cdrpll_data, cdrpll_samp_en, cdrpll_out;
cdrpll cdrpll_I(
	mclk,
	~n_mr,
	en,
	rd,
	cdrpll_data, cdrpll_samp_en,
	cdrpll_out,
	wpc_action,
	wpc_pulse
);

function automatic [7:0] from_mfm(input [15:0] mfm);
	from_mfm = {mfm[14], mfm[12], mfm[10], mfm[8],
	mfm[6], mfm[4], mfm[2], mfm[0]};
endfunction
function automatic [15:0] to_mfm(input [7:0] d, input last);
	to_mfm = {~(d[7] | last), d[7], ~(d[6] | d[7]), d[6], ~(d[5] | d[6]), d[5], ~(d[4] | d[5]), d[4],
		~(d[3] | d[4]), d[3], ~(d[2] | d[3]), d[2], ~(d[1] | d[2]), d[1], ~(d[0] | d[1]), d[0]};
endfunction

reg [19:0] buffer;
reg [3:0] bits;
reg [7:0] hold;
reg a1_hold;

wire [15:0] a1_word;
assign a1_word = to_mfm(8'hA1, 1'b0) & ~16'h20;

// tristates/bibufs
wire d__e, a1__e;
wire [7:0] d__a;
wire a1__a;
wire [7:0] d__y;
wire a1__y;
assign d__y = d;
assign a1__y = a1;
assign d = d__e ? d__a : 8'bz;
assign a1 = a1__e ? a1__a : 1'bz;

assign d__e = ~encode_en;
assign d__a = hold;
assign a1__e = ~encode_en;
assign a1__a = a1_hold;

assign dck = bits[3];
assign bus_cycle = bits>=6 && bits<=7;
assign write_pulse = bits==7;

assign wg = en && encode_en;
assign wr = en && encode_en && buffer[17] && wpc_pulse;

wire [2:0] wpc_window;
assign wpc_window = {buffer[19], buffer[17], buffer[15]};

always @* begin
	wpc_action = `WPC_NOPCOMP;
	if (wcp_en) begin
		if (wpc_window == 3'b011) wpc_action = `WPC_LATE;
		else if (wpc_window == 3'b110) wpc_action = `WPC_EARLY;
	end
end

always @(posedge mclk, negedge n_mr) begin
	if (~n_mr) begin
		buffer <= 0;
		bits <= 0;
		hold <= 0;
		a1_hold <= 0;
	end else if (en && cdrpll_samp_en) begin
		if (encode_en) begin
			bits <= bits+1;
			if (bits==15) buffer[15:0] <= (a1__y ? a1_word : to_mfm(d__y, buffer[15]));
			else buffer[15:0] <= {buffer[14:0], 1'b0};
			buffer[19:16] <= {buffer[18:16], buffer[15]};
		end else begin
			buffer[15:0] <= {buffer[14:0], cdrpll_data};
			if (buffer[15:0]==a1_word) bits <= 0;
			else bits <= bits+1;
			if (bits==15 || buffer[15:0]==a1_word)
				hold <= from_mfm(buffer[15:0]);
			if (buffer[15:0]==a1_word) a1_hold <= 1;
			else if (bits==15) a1_hold <= 0;
		end
	end
end

endmodule
