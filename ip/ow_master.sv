module ow_master
#(
	parameter OVERDRIVE = 1'b0, // вкл/выкл повышенной скорости
	parameter MULTIPLIER = 16'd1 // частота в МГц, минимум 1, максимум 100
)
(
	input logic clk,
	input logic reset,
	input logic ow_in,
	output logic ow_out,
	input logic [7:0] bus_in,
	output logic [7:0] bus_out,
	input logic [2:0] cmd,
	output logic presence,
	output logic error,
	output logic done,
	output logic irq,
	input logic clear,
	input logic crc8_enable,
	input logic crc16_enable,
	output logic crc_valid
);

wire local_reset;
assign local_reset = reset | clear;

assign error = ow_error | search_error;

localparam CMD_NONE = 3'd0;
localparam CMD_RESET = 3'd1;
localparam CMD_READ = 3'd2;
localparam CMD_WRITE = 3'd3;
localparam CMD_SEARCH = 3'd4;
localparam CMD_GET_DISCREPANCY = 3'd5;
localparam CMD_GET_FAMILY_DISCREPANCY = 3'd6;
localparam CMD_SET_DISCREPANCY = 3'd7;

localparam NORMAL_RESET_LENGTH = 16'd480;
localparam NORMAL_PRESENCE_DELAY = 16'd540;
localparam NORMAL_PRESENCE_LENGTH = 16'd780;
localparam NORMAL_RESET_END = 16'd960;
localparam NORMAL_IRQ_LENGTH = 16'd3840;

localparam OVERDRIVE_RESET_LENGTH = 16'd48;
localparam OVERDRIVE_PRESENCE_DELAY = 16'd54;
localparam OVERDRIVE_PRESENCE_LENGTH = 16'd78;
localparam OVERDRIVE_RESET_END = 16'd96;
localparam OVERDRIVE_IRQ_LENGTH = 16'd3840;

localparam NORMAL_RW_INIT = 16'd3;
localparam NORMAL_RW_DELAY = 16'd15;
localparam NORMAL_RW_LENGTH = 16'd60;

localparam OVERDRIVE_RW_INIT = 16'd2;
localparam OVERDRIVE_RW_DELAY = 16'd6;
localparam OVERDRIVE_RW_LENGTH = 16'd60;

wire [2:0] ow_cmd;
wire ow_done;
wire ow_error;
wire sdi;
wire sdo;

ow_master_bit
ow_master_bit_module
(
	.clk(clk),
	.reset(local_reset),
	.ow_in(ow_in),
	.ow_out(ow_out),
	.cmd(ow_cmd),
	.presence(presence),
	.done(ow_done),
	.error(ow_error),
	.irq(irq),
	.sdi(sdi),
	.sdo(sdo)
);
defparam
	ow_master_bit_module.RESET_LENGTH = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_RESET_LENGTH : NORMAL_RESET_LENGTH), // длина импульса сброса
	ow_master_bit_module.PRESENCE_DELAY = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_PRESENCE_DELAY : NORMAL_PRESENCE_DELAY), // задержка на ожидание ответа устройства
	ow_master_bit_module.PRESENCE_LENGTH = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_PRESENCE_LENGTH : NORMAL_PRESENCE_LENGTH), // максимальное время ответа устройства
	ow_master_bit_module.IRQ_LENGTH = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_IRQ_LENGTH : NORMAL_IRQ_LENGTH), // максимальная длина прерывания
	ow_master_bit_module.RW_INIT = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_RW_INIT : NORMAL_RW_INIT),
	ow_master_bit_module.RW_DELAY = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_RW_DELAY : NORMAL_RW_DELAY),
	ow_master_bit_module.RW_LENGTH = MULTIPLIER * (OVERDRIVE ? OVERDRIVE_RW_LENGTH : NORMAL_RW_LENGTH);

// состояния автомата
reg [2:0] STATE;

localparam ST_IDLE = 0; // ожидание команды
localparam ST_RESET = 1; // сброс линии
localparam ST_READ = 2; // чтение одного байта
localparam ST_WRITE = 3; // запись одного байта
localparam ST_SEARCH = 4; // поиск одного байта rom
localparam ST_GET_DISCREPANCY = 5;
localparam ST_GET_FAMILY_DISCREPANCY = 6;
localparam ST_SET_DISCREPANCY = 7;

// регистрация прихода команды, переход из CMD_NONE
reg cmd_state;
wire pos_cmd = ~cmd_state & (|cmd);

always_ff @ (posedge clk or posedge local_reset)
	begin
		cmd_state <= local_reset ? 1'b0 : (|cmd);
	end

// сигналы
assign done = STATE == ST_IDLE;

// автомат состояний команд
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				STATE <= ST_IDLE;
			end
		else
			begin
				case(STATE)
					ST_IDLE:
						begin
							if (pos_cmd)
								begin
									case (cmd)
										CMD_NONE:
											begin
												STATE <= ST_IDLE;
											end
										CMD_RESET:
											begin
												STATE <= ST_RESET;
											end
										CMD_READ:
											begin
												STATE <= ST_READ;
											end
										CMD_WRITE:
											begin
												STATE <= ST_WRITE;
											end
										CMD_SEARCH:
											begin
												STATE <= ST_SEARCH;
											end
										CMD_GET_DISCREPANCY:
											begin
												STATE <= ST_GET_DISCREPANCY;
											end
										CMD_GET_FAMILY_DISCREPANCY:
											begin
												STATE <= ST_GET_FAMILY_DISCREPANCY;
											end
										CMD_SET_DISCREPANCY:
											begin
												STATE <= ST_SET_DISCREPANCY;
											end
									endcase
								end
						end
					ST_RESET:
						begin
							if (pos_ow_done)
								begin
									STATE <= ST_IDLE;
								end
						end
					ST_READ:
						begin
							if (pos_ow_done)
								begin
									if (bit0)
										begin
											STATE <= ST_IDLE;
										end
								end
						end
					ST_WRITE:
						begin
							if (pos_ow_done)
								begin
									if (bit0)
										begin
											STATE <= ST_IDLE;
										end
								end
						end
					ST_SEARCH:
						begin
							if (pos_ow_done)
								begin
									if (bit0 & (SEARCH_STATE == ST_SEARCH_WR_BIT))
										begin
											STATE <= ST_IDLE;
										end
								end
						end
					ST_GET_DISCREPANCY:
						begin
							STATE <= ST_IDLE;
						end
					ST_GET_FAMILY_DISCREPANCY:
						begin
							STATE <= ST_IDLE;
						end
					ST_SET_DISCREPANCY:
						begin
							STATE <= ST_IDLE;
						end
				endcase
			end
	end

// сигналы поиска
wire zero_sig;
assign zero_sig = ~id_bit & ~cmp_id_bit & ( discrepancy_lt | ( discrepancy_gt & ~data_buf[0] ) );

reg zero;
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				zero = 0;
			end
		else if (SEARCH_STATE == ST_SEARCH_RD_CMP_BIT)
			begin
				zero = zero_sig;
			end
		else if (SEARCH_STATE == ST_SEARCH_NONE)
			begin
				zero = 0;
			end
	end

reg [3:0] rom_byte;
wire [6:0] id_bit_num;
reg [6:0] last_discrepancy;
reg [6:0] last_zero;
reg [6:0] last_family_discrepancy;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				last_zero <= 0;
			end
		else if (pos_ow_done)
			begin
				if (SEARCH_STATE == ST_SEARCH_WR_BIT)
					begin
						if (zero)
							begin
								last_zero = id_bit_num;
							end
					end
			end
		else if (STATE == ST_RESET)
			begin
				if (rom_byte == 0)
					begin
						last_zero = 0;
					end
			end
	end
	
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				last_family_discrepancy <= 0;
			end
		else if (pos_ow_done)
			begin
				if (SEARCH_STATE == ST_SEARCH_WR_BIT)
					begin
						if (zero)
							begin
								if (id_bit_num < 9)
									begin
										last_family_discrepancy <= id_bit_num;
									end
							end
					end
			end
	end

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				rom_byte <= 3'b0;
			end
		else if (pos_ow_done)
			begin
				if (SEARCH_STATE == ST_SEARCH_WR_BIT)
					begin
						rom_byte <= rom_byte + (&num_bit);
					end
			end
		else if (done)
			begin
				if (rom_byte > 7)
					begin
						rom_byte <= 0;
					end
			end
	end

assign id_bit_num = {rom_byte, num_bit};

wire discrepancy_gt;
wire discrepancy_lt;
assign discrepancy_gt = last_discrepancy > id_bit_num;
assign discrepancy_lt = last_discrepancy < id_bit_num;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				last_discrepancy <= 7'b0;
			end
		else if (pos_cmd)
			begin
				if (cmd == CMD_SET_DISCREPANCY)
					begin
						last_discrepancy <= bus_in[6:0];
					end
			end
		else if (done)
			begin
				if (rom_byte > 7)
					begin
						last_discrepancy <= last_zero;
					end
			end
	end
	
reg search_error;
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			search_error <= 1'b0;
		else if (SEARCH_STATE == ST_SEARCH_WR_BIT)
			search_error <= id_bit & cmp_id_bit;
	end

// автомат состояний поиска ROM
reg [1:0] SEARCH_STATE;

localparam ST_SEARCH_NONE = 0;
localparam ST_SEARCH_RD_BIT = 1;
localparam ST_SEARCH_RD_CMP_BIT = 2;
localparam ST_SEARCH_WR_BIT = 3;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				SEARCH_STATE <= ST_SEARCH_NONE;
			end
		else if (STATE == ST_SEARCH)
			begin
				case(SEARCH_STATE)
					ST_SEARCH_NONE:
						begin
							SEARCH_STATE <= ST_SEARCH_RD_BIT;
						end
					ST_SEARCH_RD_BIT:
						begin
							if (pos_ow_done)
								begin
									SEARCH_STATE <= ST_SEARCH_RD_CMP_BIT;
								end
						end
					ST_SEARCH_RD_CMP_BIT:
						begin
							if (pos_ow_done)
								begin
									SEARCH_STATE <= ST_SEARCH_WR_BIT;
								end
						end
					ST_SEARCH_WR_BIT:
						begin
							if (pos_ow_done)
								begin
									SEARCH_STATE <= ST_SEARCH_NONE;
								end
						end
				endcase
			end
		else
			begin
				SEARCH_STATE <= ST_SEARCH_NONE;
			end
	end
	
// логика поиска
reg id_bit;
reg cmp_id_bit;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				id_bit <= 1;
				cmp_id_bit <= 1;
			end
		else
			begin
				case(SEARCH_STATE)
					ST_SEARCH_NONE:
						begin
							// skip
						end
					ST_SEARCH_RD_BIT:
						begin
							id_bit <= sdo;
						end
					ST_SEARCH_RD_CMP_BIT:
						begin
							cmp_id_bit <= sdo;
						end
					ST_SEARCH_WR_BIT:
						begin
							// skip
						end
				endcase
			end
	end
	
// счет битов в байте
reg [2:0] num_bit;
wire bit0;

assign bit0 = ~(|num_bit); // проверка на ноль

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				num_bit <= 3'b1;
			end
		else if (done | (STATE == ST_RESET))
			begin
				num_bit <= 3'b1;
			end
		else if (STATE == ST_SEARCH)
			begin
				if ((SEARCH_STATE == ST_SEARCH_WR_BIT))
					begin
						if (pos_ow_done)
							begin
								num_bit++;
							end
					end
			end
		else
			begin
				if (pos_ow_done)
					begin
						num_bit++;
					end
			end
	end
	
// управление командами модуля ow_master_bit
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				ow_cmd <= CMD_NONE;
			end
		else if (done)
			begin
				ow_cmd <= CMD_NONE;
			end
		else if (pos_ow_done)
			begin
				ow_cmd <= CMD_NONE;
			end
		else
			begin
				case(STATE)
					ST_RESET:
						begin
							ow_cmd <= CMD_RESET;
						end
					ST_READ:
						begin
							ow_cmd <= CMD_READ;
						end
					ST_WRITE:
						begin
							ow_cmd <= CMD_WRITE;
						end
					ST_SEARCH:
						begin
							case(SEARCH_STATE)
								ST_SEARCH_NONE:
									begin
										ow_cmd <= CMD_NONE;
									end
								ST_SEARCH_RD_BIT:
									begin
										ow_cmd <= CMD_READ;
									end
								ST_SEARCH_RD_CMP_BIT:
									begin
										ow_cmd <= CMD_READ;
									end
								ST_SEARCH_WR_BIT:
									begin
										ow_cmd <= CMD_WRITE;
									end
							endcase
						end
					default:
						begin
							ow_cmd <= CMD_NONE;
						end
				endcase
			end
	end
	
// завершение команды модулем ow_master_bit
reg ow_done_state;
wire pos_ow_done = ~ow_done_state & ow_done;

always_ff @ (posedge clk or posedge local_reset)
	begin
		ow_done_state <= local_reset ? 1'b0 : ow_done;
	end

// буфер данных
reg [7:0] data_buf;

assign sdi = data_buf[0];

assign bus_out = done ? data_buf : 8'b0;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if(local_reset)
			begin
				data_buf = 0;
			end
		else if (pos_cmd)
			begin
				if (cmd == CMD_WRITE)
					begin
						data_buf <= bus_in;
					end
				else if (cmd == CMD_SEARCH)
					begin
						data_buf <= bus_in;
					end
// не нужен, так как пишем напрямую в регистер last_discrepancy
/*				else if (cmd == CMD_SET_DISCREPANCY)
					begin
						data_buf <= bus_in;
					end*/
				else if (cmd == CMD_GET_DISCREPANCY)
					begin
						data_buf[6:0] <= last_discrepancy;
						data_buf[7] <= 1'b0;
					end
				else if (cmd == CMD_GET_FAMILY_DISCREPANCY)
					begin
						data_buf[6:0] <= last_family_discrepancy;
						data_buf[7] <= 1'b0;
					end
			end
		else if (pos_ow_done)
			begin
				if (STATE == ST_READ)
					begin
						data_buf <= {sdo, data_buf[7:1]}; // читаем бит
					end
				else if (STATE == ST_WRITE)
					begin
						data_buf <= {data_buf[0], data_buf[7:1]}; // пишем бит
					end
				else if (STATE == ST_SEARCH)
					begin
						if (SEARCH_STATE == ST_SEARCH_RD_CMP_BIT)
							begin
								// TODO: данный алгоритм использует только точки ветвления и никак неучитывает значения между ними
								// с одной стороны, это упрощает перебор всех устройств, но с другой стороны можно получить неоднозначный результат
								// так же можно реализовать вариант обращения к устройству без запоминания всего 64-битного кода
								// еще одно замечание, CRC всегда соответствует предшевствующим 7-ми байтам, поэтому коллизий (ветвлений) не должно быть в CRC
								//data_buf[0] <= id_bit | (~id_bit & ~cmp_id_bit & ((discrepancy_gt & data_buf[0])) | (~discrepancy_lt & ~discrepancy_gt)); // выбираем бит
								// TODO: во втором случае теряется гибкость
								// для более строгого выбора, нужно выбирать бит из маски при discrepancy_gt
								data_buf[0] <= ( ( ~zero_sig & ~id_bit ) | id_bit ) & ~cmp_id_bit; // выбираем бит
							end
						else if (SEARCH_STATE == ST_SEARCH_WR_BIT)
							begin
								data_buf <= {data_buf[0], data_buf[7:1]};
							end
					end
			end
	end
	
// CRC
// crc8[7:0]=1+x^4+x^5+x^8;
// crc16[15:0]=1+x^2+x^15+x^16;
reg [7:0] crc8;
reg [15:0] crc16;
reg crc_in;
wire crc_shift;
assign crc_valid = ~(|crc8) & ~(|crc16) ;

reg crc8_enable_state;
wire pos_crc8_enable;
assign pos_crc8_enable = ~crc8_enable_state & crc8_enable;

always_ff @ (posedge clk or posedge local_reset)
	begin
		crc8_enable_state <= local_reset ? 1'b0 : crc8_enable;
	end

reg crc8_shift_state;
wire pos_crc8_shift;
assign pos_crc8_shift = ~crc8_shift_state & crc_shift & crc8_enable;

always_ff @ (posedge clk or posedge local_reset)
	begin
		crc8_shift_state <= local_reset ? 1'b0 : crc_shift & crc8_enable;
	end

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			crc8 <= 8'b0;
		else if (pos_crc8_enable)
			crc8 <= 8'b0;
		else if (pos_crc8_shift)
			// сдвиг влево
			//crc8 <= {crc8[6:5], crc8[4]^crc8[7]^crc_in, crc8[3]^crc8[7]^crc_in, crc8[2:0], crc8[7] ^ crc_in};
			// сдвиг вправо
			crc8 <= {crc8[0] ^ crc_in, crc8[7:5], crc8[4]^crc8[0]^crc_in, crc8[3]^crc8[0]^crc_in, crc8[2:1]};
	end
	
// CRC16
reg crc16_enable_state;
wire pos_crc16_enable;
assign pos_crc16_enable = ~crc16_enable_state & crc16_enable;

always_ff @ (posedge clk or posedge local_reset)
	begin
		crc16_enable_state <= local_reset ? 1'b0 : crc16_enable;
	end

reg crc16_shift_state;
wire pos_crc16_shift;
assign pos_crc16_shift = ~crc16_shift_state & crc_shift & crc16_enable;

always_ff @ (posedge clk or posedge local_reset)
	begin
		crc16_shift_state <= local_reset ? 1'b0 : crc_shift & crc16_enable;
	end

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			crc16 <= 8'b0;
		else if (pos_crc16_enable)
			crc16 <= 8'b0;
		else if (pos_crc16_shift)
			// сдвиг влево
			// crc16 <= {crc16[14]^crc16[15]^crc_in, crc16[13:2], crc16[1]^crc16[15]^crc_in, crc16[0], crc16[15]^crc_in};
			// сдвиг вправо
			crc16 <= {crc16[0]^crc_in, crc16[15], crc16[14]^crc16[0]^crc_in, crc16[13:2], crc16[1]^crc16[0]^crc_in};
	end

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			crc_in <= 1'b0;
		else if (pos_ow_done)
			begin
				if (STATE == ST_READ)
					crc_in <= sdo;
				else if (STATE == ST_SEARCH)
					begin
						if (SEARCH_STATE == ST_SEARCH_WR_BIT)
							crc_in <= data_buf[0];
					end
			end
	end
	
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			crc_shift <= 1'b0;
		else if (pos_ow_done)
			begin
				if (STATE == ST_READ)
					crc_shift <= 1'b1;
				else if (STATE == ST_SEARCH)
					begin
						if (SEARCH_STATE == ST_SEARCH_WR_BIT)
							crc_shift <= 1'b1;
					end
			end
		else
			crc_shift <= 1'b0;
	end
	
endmodule
