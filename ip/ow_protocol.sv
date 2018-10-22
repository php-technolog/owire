module ow_protocol (
	input logic clk,
	input logic reset,
	output logic error, // неверная команда
	output logic ready, // готовность к приему следующей команды
	input logic [7:0] bus_in, // вход команд и данных
	input logic [7:0] data_in, // данные нужны только для выбора семейства устройств
	output logic rdreq, // запрос на чтение данных из буфера
	input logic rdready, // данные прочитаны
	output logic wrreq, // запрос на запись данных в буфер
	input logic wrready, // данные записаны
	//output logic [2:0] rom_byte, // номер байта ROM
	// выход для управления ow_master
	output logic [2:0] ow_cmd,
	input logic ow_presence, // устройство присутствует
	input logic ow_error, // ошибка на шине
	input logic ow_done, // команда выполнена
	input logic ow_irq, // прерывание на шине
	input logic clear,
	output logic crc8_enable,
	output logic crc16_enable,
	input logic crc_valid,
	// управление автоматом для разбора специфичных команд устройства
	output logic slave_ctrl, // 1 - разбор команд производит ведомый автомат
	input logic slave_error, // 1 - ошибка ведомого автомата
	input logic slave_ready, // 1 - ведомый автомат готов к приему команды
	output logic [7:0] family // выбранное семейство
);

wire local_reset;
assign local_reset = reset | clear;

// not use crc16
assign crc16_enable  = 1'b0;

// Вопрос, crc_valid просто выводится или если ~crc_valid останавливать последовательность команд
// скорее сделаем и первое и второе, т.е. выставляем ошибку и выводим сигнал, чтобы определить причину ошибки

// сначала идет код команды, затем данные для нее
// затем идет пользовательская команда

assign ready = STATE == ST_CMD_REQ;

// коды команд протокола 1-Wire
localparam SEARCH_ROM = 8'hF0;
localparam READ_ROM = 8'h33;
localparam MATCH_ROM = 8'h55;
localparam SKIP_ROM = 8'hCC;
localparam ALARM_SEARCH = 8'hEC;
localparam OVERDRIVE_SKIP_ROM = 8'h3C;
localparam OVERDRIVE_MATCH_ROM = 8'h69;

// пользовательские команды
localparam PREFIX_USER_CMD = 8'hFF;
localparam GET_DISCREPANCY = 8'h01;
localparam GET_FAMILY_DISCREPANCY = 8'h02;
localparam SET_DISCREPANCY = 8'h03;

// TODO: есть три пути управления значением last_discrepancy в модуле ow_master,
// 1. вывести напрямую шину из модуля ow_master
// 2. встроить модуль между ow_protocol и ow_master
// 3. включить в ow_protocol пользовательские инструкции
// выбран третий вариант, так как второй сложный и первый не гибкий, плюс третий вариант реализует потоковый режим, недоступный двум первым
// да, включать кастомные команды в протокол не очень хорошо!
// можно использовать префикс для расширения пользовательских команд, например 'hFF или 'h00

reg cmd_search_rom;
reg cmd_read_rom;
reg cmd_match_rom;
reg cmd_skip_rom;
reg cmd_alarm_search;
reg cmd_user_prefix;

reg user_cmd_get_discrepancy;
reg user_cmd_get_family_discrepancy;
reg user_cmd_set_discrepancy;

always_ff @ (negedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				cmd_search_rom = 1'b0;
				cmd_read_rom = 1'b0;
				cmd_match_rom = 1'b0;
				cmd_skip_rom = 1'b0;
				cmd_alarm_search = 1'b0;
				cmd_user_prefix = 1'b0;
			end
		else if ((STATE == ST_CMD_REQ) & pos_rdready)
			begin
				cmd_search_rom = bus_in == SEARCH_ROM;
				cmd_read_rom = bus_in == READ_ROM;
				cmd_match_rom = (bus_in == MATCH_ROM) | (bus_in == OVERDRIVE_MATCH_ROM);
				cmd_skip_rom = (bus_in == SKIP_ROM) | (bus_in == OVERDRIVE_SKIP_ROM);
				cmd_alarm_search = bus_in == ALARM_SEARCH;
				cmd_user_prefix = bus_in == PREFIX_USER_CMD;
			end
		else if ((STATE == ST_USER_CMD_REQ) & pos_rdready)
			begin
				user_cmd_get_discrepancy = bus_in == GET_DISCREPANCY;
				user_cmd_get_family_discrepancy = bus_in == GET_FAMILY_DISCREPANCY;
				user_cmd_set_discrepancy = bus_in == SET_DISCREPANCY;
			end
	end

// проверка команд
wire valid;
assign valid = local_reset ? 1'b1 : ((STATE == ST_CMD_REQ) & pos_rdready ? (cmd_search_rom ^ cmd_read_rom ^ cmd_match_rom ^ cmd_skip_rom ^ cmd_alarm_search ^ (cmd_user_prefix & user_valid)) : valid);
assign error = ~valid | ~crc_valid; // в текущей реализации ошибка не останавливает последовательность команд

// проверка валидности пользовательских команд
wire user_valid;
assign user_valid = local_reset ? 1'b1 : ((STATE == ST_USER_CMD_REQ) & pos_rdready ? (user_cmd_get_discrepancy ^ user_cmd_get_family_discrepancy ^ user_cmd_set_discrepancy) : user_valid);

// завершение команды модулем ow_master
reg ow_done_state;
wire pos_ow_done = ~ow_done_state & ow_done;

always_ff @ (posedge clk or posedge local_reset)
	begin
		ow_done_state <= local_reset ? 1'b1 : ow_done;
	end
	
// завершение команды устройством
reg slave_ready_state;
wire pos_slave_ready = ~slave_ready_state & slave_ready;

always_ff @ (posedge clk or posedge local_reset)
	begin
		slave_ready_state <= local_reset ? 1'b1 : slave_ready;
	end
	
// ожидание готовности данных
reg rdready_state;
wire pos_rdready = ~rdready_state & rdready;

always_ff @ (posedge clk or posedge local_reset)
	begin
		rdready_state <= local_reset ? 1'b1 : rdready;
	end
	
// запись данных
reg wrready_state;
wire pos_wrready = ~wrready_state & wrready;

always_ff @ (posedge clk or posedge local_reset)
	begin
		wrready_state <= local_reset ? 1'b1 : wrready;
	end

// автомат состояний команд
reg [3:0] STATE;

localparam ST_CMD_REQ = 4'd0; // чтение команды
localparam ST_RESET = 4'd1; // сброс линии 1-Wire
localparam ST_CMD_RUN = 4'd2; // отправка команды на линию 1-Wire
localparam ST_READ_BUF = 4'd3; // чтение байта из буфера
localparam ST_CMD_PROCESS = 4'd4; // команда для модуля ow_master
localparam ST_WRITE_BUF = 4'd5; // запись байта в буфер
localparam ST_DONE = 4'd6; // передача управления ведомому устройству
localparam ST_USER_CMD_REQ = 4'd7; // ошидание пользовательской команды
localparam ST_USER_READ_DATA = 4'd8;
localparam ST_USER_WRITE_DATA = 4'd9;

// команды для модуля ow_master
localparam CMD_NONE = 3'd0; // нет команды
localparam CMD_RESET = 3'd1; // сброс шины
localparam CMD_READ = 3'd2; // чтение байта
localparam CMD_WRITE = 3'd3; // запись байта
localparam CMD_SEARCH = 3'd4; // поиск устройства, один байт
localparam CMD_GET_DISCREPANCY = 3'd5;
localparam CMD_GET_FAMILY_DISCREPANCY = 3'd6;
localparam CMD_SET_DISCREPANCY = 3'd7;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				STATE <= ST_CMD_REQ;
			end
		else
			begin
				case (STATE)
					ST_CMD_REQ: // запрос и ожидание команды
						begin
							if (pos_rdready)
								begin
									if (cmd_user_prefix)
										begin
											STATE <= ST_USER_CMD_REQ;
										end
									else
										begin
											STATE <= ST_RESET;
										end
								end
						end
					ST_RESET: // сброс линии 1-Wire
						begin
							if (pos_ow_done)
								begin
									if (ow_presence)
										begin
											STATE <= ST_CMD_RUN;
										end
									else
										begin
											STATE <= ST_CMD_REQ;
										end
								end
						end
					ST_CMD_RUN: // отправка команды на выполнение
						begin
							if (pos_ow_done)
								begin
									if (cmd_skip_rom)
										begin
											STATE <= ST_DONE;
										end
									else
										begin
											STATE <= ST_READ_BUF;
										end
								end
						end
					ST_READ_BUF: // чтение данных для команды
						begin
							if (cmd_search_rom | cmd_match_rom | cmd_alarm_search)
								begin
									if (pos_rdready)
										begin
											STATE <= ST_CMD_PROCESS;
										end
								end
							else
								begin
									STATE <= ST_CMD_PROCESS;
								end
						end
					ST_CMD_PROCESS: // исполнение команды
						begin
							if (pos_ow_done)
								begin
									STATE <= ST_WRITE_BUF;
								end
						end
					ST_WRITE_BUF: // запись результата команды
						begin
							if (cmd_search_rom | cmd_read_rom | cmd_alarm_search)
								begin
									if (pos_wrready)
										begin
											if (num_byte_zero)
												begin
													STATE <= ST_DONE;
												end
											else
												begin
													STATE <= ST_READ_BUF;
												end
										end
								end
							else if (num_byte_zero)
								begin
									STATE <= ST_DONE;
								end
							else
								begin
									STATE <= ST_READ_BUF;
								end
						end
					ST_DONE: // передача управления ведомому устройству
						begin
							if (pos_slave_ready)
								begin
									STATE <= ST_CMD_REQ;
								end
						end
					ST_USER_CMD_REQ: // чтение пользовательской команды
						begin
							if (pos_rdready)
								begin
									STATE <= ST_USER_READ_DATA;
								end
						end
					ST_USER_READ_DATA: // чтение данных из буфера или из регистра
						begin
							if (pos_ow_done | pos_rdready)
								begin
									STATE <= ST_USER_WRITE_DATA;
								end
						end
					ST_USER_WRITE_DATA: // запись данных в буфер или в регистр
						begin
							if (pos_ow_done | pos_wrready)
								begin
									STATE <= ST_CMD_REQ;
								end
						end
				endcase
			end
	end

// read from buffer
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				rdreq <= 1'b0;
			end
		else if (pos_rdready)
			begin
				rdreq <= 1'b0;
			end
		else if (STATE == ST_CMD_REQ)
			begin
				rdreq <= 1'b1;
			end
		else if (STATE == ST_READ_BUF)
			begin
				if (cmd_search_rom | cmd_match_rom | cmd_alarm_search)
					begin
						rdreq <= 1'b1;
					end
			end
		else if (STATE == ST_USER_CMD_REQ)
			begin
				rdreq <= 1'b1;
			end
		else if (STATE == ST_USER_READ_DATA)
			begin
				if (user_cmd_set_discrepancy)
					begin
						rdreq <= 1'b1;
					end
			end
		else
			begin
				rdreq <= 1'b0;
			end
	end

// write to buffer
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				wrreq <= 1'b0;
			end
		else if (pos_wrready)
			begin
				wrreq <= 1'b0;
			end
		else if (STATE == ST_WRITE_BUF)
			begin
				if (cmd_search_rom | cmd_read_rom | cmd_alarm_search)
					begin
						wrreq <= 1'b1;
					end
			end
		else if (STATE == ST_USER_WRITE_DATA)
			begin
				if (user_cmd_get_discrepancy | user_cmd_get_family_discrepancy)
					begin
						wrreq <= 1'b1;
					end
			end
		else
			begin
				wrreq <= 1'b0;
			end
	end

// num_byte
reg [2:0] num_byte; // счетчик на восемь байт ROM
wire num_byte_zero;
assign num_byte_zero = ~(|num_byte);
//assign rom_byte = num_byte;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				num_byte <= 3'b0;
			end
		else if (STATE == ST_CMD_PROCESS)
			begin
				if (pos_ow_done)
					begin
						num_byte++;
					end
			end
		else if (STATE == ST_CMD_REQ)
			begin
				num_byte <= 3'b0;
			end
	end
	
// управление ведомым устройством
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				slave_ctrl <= 1'b0;
			end
		else if (STATE == ST_DONE)
			begin
				slave_ctrl <= 1'b1;
			end
		else
			begin
				slave_ctrl <= 1'b0;
			end
	end

// команды для ow_master
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				ow_cmd <= CMD_NONE;
			end
		else if (pos_ow_done)
			begin
				ow_cmd <= CMD_NONE;
			end
		else if (STATE == ST_RESET)
			begin
				ow_cmd <= CMD_RESET;
			end
		else if (STATE == ST_CMD_RUN)
			begin
				ow_cmd <= CMD_WRITE;
			end
		else if (STATE == ST_CMD_PROCESS)
			begin
				if (cmd_search_rom | cmd_alarm_search)
					begin
						ow_cmd <= CMD_SEARCH;
					end
				else if (cmd_match_rom)
					begin
						ow_cmd <= CMD_WRITE;
					end
				else if (cmd_read_rom)
					begin
						ow_cmd <= CMD_READ;
					end
			end
		else if (STATE == ST_USER_READ_DATA)
			begin
				if (user_cmd_get_discrepancy)
					begin
						ow_cmd <= CMD_GET_DISCREPANCY;
					end
				else if (user_cmd_get_family_discrepancy)
					begin
						ow_cmd <= CMD_GET_FAMILY_DISCREPANCY;
					end
				else
					begin
						ow_cmd <= CMD_NONE;
					end
			end
		else if (STATE == ST_USER_WRITE_DATA)
			begin
				if (user_cmd_set_discrepancy)
					begin
						ow_cmd <= CMD_SET_DISCREPANCY;
					end
				else
					begin
						ow_cmd <= CMD_NONE;
					end
			end
		else
			begin
				ow_cmd <= CMD_NONE;
			end
	end
	
// CRC

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			crc8_enable <= 1'b0;
		else if (STATE == ST_CMD_RUN)
			crc8_enable <= 1'b1;
		else if (STATE == ST_DONE)
			crc8_enable <= 1'b0;
	end
	
// family
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				family <= 8'hFF; // любое устройство
			end
		else if (cmd_skip_rom)
			begin
				family <= 8'hFF;
			end
		else if (cmd_match_rom)
			begin
				if (STATE == ST_READ_BUF)
					begin
						if (pos_rdready)
							begin
								if (num_byte_zero)
									begin
										family <= bus_in;
									end
							end
					end
			end
		else if (cmd_search_rom | cmd_read_rom | cmd_alarm_search)
			begin
				if (STATE == ST_WRITE_BUF)
					begin
						if (pos_wrready)
							begin
								if (num_byte == 1)
									begin
										family <= data_in;
									end
							end
					end
			end
		else
			begin
				family <= 8'hFF; // никогда не выполняется
			end
	end

endmodule
