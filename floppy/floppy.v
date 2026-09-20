module floppy(
	input mfmcodec_dck,
	input n_mr,

	output mfmcodec_en,
	output reg mfmcodec_encode_en,
	input mfmcodec_bus_cycle,
	input mfmcodec_write_pulse,

	inout [7:0] mfmcodec_d,
	inout mfmcodec_a1,

	input wp,

	input n_cs,
	output reg n_as,
	output reg n_ds,
	output reg n_crcs,

	output n_br,
	input n_bg,

	inout n_we,
	output n_us, n_ls,
	output [7:0] a,
	inout [15:0] d,
	output n_ua, n_da, n_ea,

	output n_busy,

	output stpj,
	input n_stpbk,
	input n_stpk,
	output stp
);

// tristates/bibufs
wire mfmcodec_d__e, mfmcodec_a1__e;
reg [7:0] mfmcodec_d__a;
reg mfmcodec_a1__a;
wire [7:0] mfmcodec_d__y;
wire mfmcodec_a1__y;
assign mfmcodec_d__y = mfmcodec_d;
assign mfmcodec_a1__y = mfmcodec_a1;
assign mfmcodec_d = mfmcodec_d__e ? mfmcodec_d__a : 8'bz;
assign mfmcodec_a1 = mfmcodec_a1__e ? mfmcodec_a1__a : 1'bz;
wire n_br__e, n_us__e, n_ls__e, n_we__e, a__e, d__e, n_ua__e, n_da__e, n_ea__e;
wire n_br__a, n_us__a, n_ls__a, n_we__a, n_ua__a, n_da__a, n_ea__a;
wire [7:0] a__a;
wire [15:0] d__a;
wire n_we__y;
wire [15:0] d__y;
assign n_we__y = n_we;
assign d__y = d;
assign n_br = n_br__e ? n_br__a : 1'bz;
assign n_us = n_us__e ? n_us__a : 1'bz;
assign n_ls = n_ls__e ? n_ls__a : 1'bz;
assign n_we = n_we__e ? n_we__a : 1'bz;
assign n_ua = n_ua__e ? n_ua__a : 1'bz;
assign n_da = n_da__e ? n_da__a : 1'bz;
assign n_ea = n_ea__e ? n_ea__a : 1'bz;
assign a = a__e ? a__a : 8'bz;
assign d = d__e ? d__a : 16'bz;

`define O_IDLE		0
`define O_READ		1
`define O_WRITE		2
`define O_STEP		3
reg [1:0] operation;
wire busy;
assign busy = operation != `O_IDLE;
assign n_busy = ~busy;

wire [1:0] req_operation;
assign req_operation = d__y[9:8];
reg [1:0] operation_hold;
reg operation_load_en;
reg operation_load_en_sample;

wire operation_load_ck;
assign operation_load_ck = operation_load_en ? operation_load_en_sample : ~n_cs;
always @(posedge operation_load_ck, negedge n_mr) begin
	if (~n_mr) begin
		operation_hold <= 0;
		operation_load_en <= 0;
	end else if (operation_load_en) operation_load_en <= 0;
	else if (~n_we__y && (busy || req_operation!=`O_IDLE) && (~wp ||req_operation!=`O_WRITE)) begin
		operation_hold <= req_operation;
		operation_load_en <= 1;
	end
end

assign mfmcodec_en = operation_load_en || operation_load_en_sample || busy;

function automatic [15:0] crc16_1021(input [15:0] s0, input i); begin
	crc16_1021 = {s0[14:13], s0[12]^s0[15], s0[11:6], s0[5]^s0[15], s0[4:1], s0[0]^s0[15], i};
end endfunction

`define S_HUNT_ADRMARK		0
`define S_HUNT_DATMARK		1
`define S_ADDRESS			2
`define S_DATA_READ			3
`define S_CRC_READ			4
`define S_GAP2F				5
`define S_GAP2B_WRITE		6
`define S_SYNC_WRITE		7
`define S_A1_WRITE			8
`define S_DATMARK_WRITE		9
`define S_DATA_WRITE		10
`define S_CRC_WRITE			11
`define S_GAP3F_WRITE		12
(*fsm_encoding="auto"*)reg [3:0] state;
reg [8:0] accumulator;

`define ADRMARK		8'hfe
`define DATMARK		8'hfb
`define GAPFILL		8'h4e
`define SYNCFILL	8'h00

reg [7:0] datahold;

wire even_access, odd_access;
assign odd_access = accumulator[0];
assign even_access = ~odd_access;

wire odd_bus_cycle, even_bus_cycle;
assign odd_bus_cycle = mfmcodec_bus_cycle && odd_access;
assign even_bus_cycle = mfmcodec_bus_cycle && even_access;

reg bus_cycle;
//reg request_bus;
wire bus_acquired;
assign bus_acquired = bus_cycle && ~n_bg;
assign n_br__a = 0;
assign n_br__e = bus_cycle;
//assign n_bacq = ~bus_acquired;

assign mfmcodec_d__e = mfmcodec_encode_en;
assign mfmcodec_a1__e = mfmcodec_encode_en;

reg writing_access;

reg external_access;

//wire bus_available;
//assign bus_available = bus_cycle && (~request_bus || ~n_bg);
assign n_we__e = bus_acquired;
assign a__e = bus_acquired;
assign d__e = bus_acquired && writing_access;
assign n_we__a = ~writing_access;
assign a__a = accumulator[8:1];
assign d__a = {datahold, mfmcodec_d__y};

wire write_pulse;
assign write_pulse = writing_access && mfmcodec_write_pulse;
assign n_us__e = bus_acquired;
assign n_ls__e = bus_acquired;
assign n_us__a = ~(external_access && ~write_pulse);
assign n_ls__a = ~(external_access && ~write_pulse);

assign n_ua__e = bus_acquired;
assign n_da__e = bus_acquired;
assign n_ea__e = bus_acquired;
assign n_ua__a = 1;
assign n_da__a = 0;
assign n_ea__a = 1;

wire cs_pulse;
assign cs_pulse = bus_acquired && ~write_pulse;

wire [7:0] data_to_encode;
assign data_to_encode = odd_access ? datahold : d__y[15:8];

reg [7:0] to_encode;
reg encode_a1;

reg stpbk_asserted;
assign stpj = operation==`O_STEP && n_stpbk && ~stpbk_asserted;
wire stpbk_ck;
assign stpbk_ck = stpbk_asserted ? mfmcodec_dck : n_stpbk;

assign stp = stpj && n_stpk;

always @(posedge stpbk_ck, negedge n_mr) begin
	if (~n_mr) stpbk_asserted <= 0;
	else if (stpbk_asserted) stpbk_asserted <= 0;
	else stpbk_asserted <= 1;
end

always @* begin
	mfmcodec_encode_en = 0;
	to_encode = data_to_encode;
	encode_a1 = 0;

	n_as = 1;
	n_ds = 1;
	n_crcs = 1;

	writing_access = 0;

	external_access = 0;

	bus_cycle = 0;

	if (busy) begin
		case (state)
		`S_HUNT_ADRMARK, `S_HUNT_DATMARK, `S_GAP2F: begin end
		`S_ADDRESS: begin
			n_as = ~cs_pulse;
			bus_cycle = even_bus_cycle;
		end
		`S_DATA_READ: begin
			n_ds = ~bus_acquired;
			writing_access = 1;
			bus_cycle = odd_bus_cycle;
			external_access = 1;
		end
		`S_CRC_READ: begin
			n_crcs = ~cs_pulse;
			writing_access = 1;
			bus_cycle = odd_bus_cycle;
		end
		`S_GAP2B_WRITE, `S_GAP3F_WRITE: begin
			mfmcodec_encode_en = 1;
			to_encode = `GAPFILL;
		end
		`S_SYNC_WRITE: begin
			mfmcodec_encode_en = 1;
			to_encode = `SYNCFILL;
		end
		`S_A1_WRITE: begin
			mfmcodec_encode_en = 1;
			encode_a1 = 1;
		end
		`S_DATMARK_WRITE: begin
			mfmcodec_encode_en = 1;
			to_encode = `DATMARK;
		end
		`S_DATA_WRITE: begin
			mfmcodec_encode_en = 1;
			n_ds = ~bus_acquired;
			bus_cycle = even_bus_cycle;
			external_access = 1;
		end
		`S_CRC_WRITE: begin
			mfmcodec_encode_en = 1;
			n_crcs = ~cs_pulse;
			bus_cycle = even_bus_cycle;
		end
		endcase
	end
end

always @(posedge mfmcodec_dck, negedge n_mr) begin
	if (~n_mr) begin
		operation <= `O_IDLE;
		operation_load_en_sample <= 0;
		state <= `S_HUNT_ADRMARK;
		accumulator <= 0;
		datahold <= 0;
		mfmcodec_d__a <= 0;
		mfmcodec_a1__a <= 0;
	end else begin
		operation_load_en_sample <= operation_load_en;
		if (operation_load_en_sample) begin
			operation <= operation_hold;
			state <= `S_HUNT_ADRMARK;
			accumulator <= 0;
		end else if (busy) begin
			if (operation==`O_STEP) begin
				if (stpbk_asserted) operation <= `O_IDLE;
			end else begin
			case (state)
			`S_HUNT_ADRMARK, `S_HUNT_DATMARK: begin
				if (accumulator[1:0] == 3) begin
					accumulator <= 0;
					if (state == `S_HUNT_ADRMARK) begin
						if (mfmcodec_d__y == `ADRMARK)
							state <= `S_ADDRESS;
					end else if (state == `S_HUNT_DATMARK) begin
						if (mfmcodec_d__y == `DATMARK)
							state <= `S_DATA_READ;
					end
				end else begin
					if (mfmcodec_a1__y) accumulator <= accumulator + 1;
					else accumulator <= 0;		// (if accumulator[1:0] != 0)
				end
			end
			`S_ADDRESS: begin
				if (accumulator[1:0] == 2) begin
					accumulator <= 0;
					if (mfmcodec_d__y == d__y[15:8]) begin
						if (operation == `O_READ) state <= `S_HUNT_DATMARK;
						else state <= `S_GAP2F;
					end else state <= `S_HUNT_ADRMARK;
				end else accumulator <= accumulator + 1;
			end
			`S_DATA_READ: begin
				if (accumulator == 511) begin
					state <= `S_CRC_READ;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				if (even_access) datahold <= mfmcodec_d__y;
			end
			`S_CRC_READ: begin
				if (accumulator[1:0] == 1) begin
					operation <= `O_IDLE;
					state <= `S_HUNT_ADRMARK;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				if (even_access) datahold <= mfmcodec_d__y;
			end
			`S_GAP2F: begin
				// 8 instead of 9, phase shifting for writing
				// to_encode starts being written AFTER mfmcodec_event (not ON)
				// 11 instead of 8 because we get here from address' N byte, 3 bytes before
				// the actual gap2 start
				// 10 instead of 11 because mfmcodec loads on the next cycle
				if (accumulator[3:0] == 10) begin
					state <= `S_GAP2B_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
			end
			`S_GAP2B_WRITE: begin
				if (accumulator[3:0] == 11) begin
					state <= `S_SYNC_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_SYNC_WRITE: begin
				if (accumulator[3:0] == 11) begin
					state <= `S_A1_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_A1_WRITE: begin
				if (accumulator[1:0] == 2) begin
					state <= `S_DATMARK_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_DATMARK_WRITE: begin
				state <= `S_DATA_WRITE;
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_DATA_WRITE: begin
				if (accumulator == 511) begin
					state <= `S_CRC_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				if (even_access) datahold <= d__y[7:0];
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_CRC_WRITE: begin
				if (accumulator[0] == 1) begin
					state <= `S_GAP3F_WRITE;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				if (even_access) datahold <= d__y[7:0];
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			`S_GAP3F_WRITE: begin
				if (accumulator[1:0] == 3) begin
					operation <= `O_IDLE;
					state <= `S_HUNT_ADRMARK;
					accumulator <= 0;
				end else accumulator <= accumulator + 1;
				mfmcodec_d__a <= to_encode;
				mfmcodec_a1__a <= encode_a1;
			end
			endcase
			end
		end //else if (operation_load_en && (~wp || operation_hold!=`O_WRITE))
			//operation <= operation_hold;
	end
end

endmodule
