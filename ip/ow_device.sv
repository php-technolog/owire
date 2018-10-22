// это шаблон для подчиненных устройств
module ow_device (
	input logic clk,
	input logic reset,
	input logic [7:0] bus_in, // вход команд и данных
	output logic rdreq, // запрос на чтение данных из буфера
	input logic rdready, // данные прочитаны
	output logic wrreq, // запрос на запись данных в буфер
	input logic wrready, // данные записаны
	// выход для управления ow_master
	output logic [2:0] ow_cmd, // 
	input logic ow_presence, // устройство присутствует
	input logic ow_error, // ошибка на шине
	input logic ow_done, // команда выполнена
	input logic ow_irq, // прерывание на шине
	input logic clear,
	output logic crc8_enable,
	output logic crc16_enable,
	input logic crc_valid,
	// family device
	input logic [7:0] family, // выбранное семейство устройств
	// slave
	input logic slave_ctrl, // 1 - разбор команд производит ведомый автомат
	output logic slave_error, // 1 - ошибка ведомого автомата
	output logic slave_ready // 1 - ведомый автомат готов к приему команды
);

wire local_reset;
assign local_reset = reset | clear;

// ow_ready готовность шины к работе
wire ow_ready;
assign ow_ready = ow_presence & ~ow_error & ow_done & ~ow_irq;

// автомат состояний
reg [2:0] STATE;

localparam ST_IDLE = 0;
localparam ST_CMD_REQ = 1;
localparam ST_CMD_PROCESS = 2;
localparam ST_READ_BYTES = 3;
localparam ST_WRITE_BUFFER = 4;
localparam ST_READ_BUFFER = 5;
localparam ST_WRITE_BYTES = 6;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				STATE <= ST_IDLE;
			end
		else
			begin
				case (STATE)
					ST_IDLE:
						begin
							if (pos_slave_ctrl & ow_ready)
								begin
									STATE <= ST_CMD_REQ;
								end
						end
					ST_CMD_REQ:
						begin
							if (pos_rdready)
								begin
									STATE <= ST_CMD_PROCESS;
								end
						end
					ST_CMD_PROCESS:
						begin
							if (pos_ow_done)
								begin
									STATE <= ST_READ_BYTES;
								end
						end
					ST_READ_BYTES:
						begin
							if (pos_ow_done)
								begin
									STATE <= ST_WRITE_BUFFER;
								end
							else if (read_counter_zero)
								begin
									STATE <= ST_READ_BUFFER;
								end
						end
					ST_WRITE_BUFFER:
						begin
							if (pos_wrready)
								begin
									if (read_counter_zero)
										begin
											STATE <= ST_READ_BUFFER;
										end
									else
										begin
											STATE <= ST_READ_BYTES;
										end
								end
						end
					ST_READ_BUFFER:
						begin
							if (pos_rdready)
								begin
									STATE <= ST_WRITE_BYTES;
								end
							else if (write_counter_zero)
								begin
									STATE <= ST_IDLE;
								end
						end
					ST_WRITE_BYTES:
						begin
							if (pos_ow_done)
								begin
									if (write_counter_zero)
										begin
											STATE <= ST_IDLE;
										end
								end
						end
				endcase
			end
	end
	
// read/wrire buffer
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				rdreq <= 1'b0;
			end
		else if (STATE == ST_CMD_REQ)
			begin
				rdreq <= 1'b1;
			end
		else if (STATE == ST_READ_BUFFER)
			begin
				rdreq <= ~write_counter_zero;
			end
		else
			begin
				rdreq <= 1'b0;
			end
	end
	
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				wrreq <= 1'b0;
			end
		else if (STATE == ST_WRITE_BUFFER)
			begin
				wrreq <= ~read_counter_zero;
			end
		else
			begin
				wrreq <= 1'b0;
			end
	end
	
assign family_valid = (family == SAME_FAMILY) | (family == ANY_FAMILY);

// slave_ctrl
reg slave_ctrl_state;
wire pos_slave_ctrl;

// проверяем приход сигнала slave_ctrl
assign pos_slave_ctrl = ~slave_ctrl_state & slave_ctrl;
always_ff @ (posedge clk or posedge local_reset)
	begin
		slave_ctrl_state <= local_reset ? 1'b0 : slave_ctrl;
	end
	
// slave_ready
assign slave_ready = (STATE == ST_IDLE);

// сколько данных нужно прочитать или записать, разрядность может быть как увеличена, так и уменьшена в зависимости от объема передаваемых данных.
reg [7:0] read_bytes;
reg [7:0] write_bytes;

// счетчики для чтения/записи
reg [7:0] read_counter;
reg [7:0] write_counter;

wire read_counter_zero = ~(|read_counter);
wire write_counter_zero = ~(|write_counter);

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				read_counter <= 8'b0;
				write_counter <= 8'b0;
			end
		else if (pos_ow_done)
			begin
				if (STATE == ST_CMD_PROCESS)
					begin
						read_counter <= read_bytes;
						write_counter <= write_bytes;
					end
			end
		else if (pos_wrready)
			begin
				if (STATE == ST_WRITE_BUFFER)
					begin
						if (~read_counter_zero)
							begin
								read_counter--;
							end
					end
			end
		else if (pos_rdready)
			begin
				if (STATE == ST_READ_BUFFER)
					begin
						if (~write_counter_zero)
							begin
								write_counter--;
							end
					end
			end	
	end

// команды для модуля ow_master
// полный список смотри ow_protocol.sv
localparam CMD_NONE = 3'd0; // нет команды
localparam CMD_READ = 3'd2; // чтение байта
localparam CMD_WRITE = 3'd3; // запись байта

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
		else if (STATE == ST_CMD_PROCESS)
			begin
				ow_cmd <= CMD_WRITE;
			end
		else if (STATE == ST_READ_BYTES)
			begin
				if (~read_counter_zero)
					begin
						ow_cmd <= CMD_READ;
					end
			end
		else if (STATE == ST_WRITE_BYTES)
			begin
				if (~write_counter_zero)
					begin
						ow_cmd <= CMD_WRITE;
					end
			end
		else
			begin
				ow_cmd <= CMD_NONE;
			end
	end
	
// завершение команды модулем ow_master
reg ow_done_state;
wire pos_ow_done = ~ow_done_state & ow_done;

always_ff @ (posedge clk or posedge local_reset)
	begin
		ow_done_state <= local_reset ? 1'b1 : ow_done;
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

// custom for device
// for test device DS18B20

// family check
wire family_valid;
localparam SAME_FAMILY = 8'h28; // DS18B20
localparam ANY_FAMILY = 8'hFF; // отвечает любое устройство
	
// команды
// команда, кол-во байт для чтений, кол-во байт для записи
localparam DEV_CMD_CONVERT_T = 8'h44;
localparam DEV_CMD_CONVERT_T_READ = 8'h00;
localparam DEV_CMD_CONVERT_T_WRITE = 8'h00;

localparam DEV_CMD_WRITE_SCRATCHPAD = 8'h4E;
localparam DEV_CMD_WRITE_SCRATCHPAD_READ = 8'h00;
localparam DEV_CMD_WRITE_SCRATCHPAD_WRITE = 8'h03;

localparam DEV_CMD_READ_SCRATCHPAD = 8'hBE;
localparam DEV_CMD_READ_SCRATCHPAD_READ = 8'h09;
localparam DEV_CMD_READ_SCRATCHPAD_WRITE = 8'h00;

localparam DEV_CMD_COPY_SCRATCHPAD = 8'h48;
localparam DEV_CMD_COPY_SCRATCHPAD_READ = 8'h00;
localparam DEV_CMD_COPY_SCRATCHPAD_WRITE = 8'h00;

localparam DEV_CMD_RECALL_E2 = 8'hB8;
localparam DEV_CMD_RECALL_E2_READ = 8'h01;
localparam DEV_CMD_RECALL_E2_WRITE = 8'h00;

localparam DEV_CMD_READ_POWER_SUPPLY = 8'hB4;
localparam DEV_CMD_READ_POWER_SUPPLY_READ = 8'h01;
localparam DEV_CMD_READ_POWER_SUPPLY_WRITE = 8'h00;

// автомат выбора команды

// проверка команд
wire valid;
assign valid = local_reset ? 1'b1 : ((STATE == ST_CMD_REQ) & pos_rdready ? (dev_convert_t ^ dev_write_scratchpad ^ dev_read_scratchpad ^ dev_copy_scratchpad ^ dev_recall_e2 ^ dev_read_power_supply) : valid);
assign slave_error = ~valid;

reg dev_convert_t, dev_write_scratchpad, dev_read_scratchpad, dev_copy_scratchpad, dev_recall_e2, dev_read_power_supply;

always_ff @ (negedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				dev_convert_t = 1'b0;
				dev_write_scratchpad = 1'b0;
				dev_read_scratchpad = 1'b0;
				dev_copy_scratchpad = 1'b0;
				dev_recall_e2 = 1'b0;
				dev_read_power_supply = 1'b0;
			end
		else if ((STATE == ST_CMD_REQ) & pos_rdready)
			begin
				dev_convert_t = (bus_in == DEV_CMD_CONVERT_T);
				dev_write_scratchpad = (bus_in == DEV_CMD_WRITE_SCRATCHPAD);
				dev_read_scratchpad = (bus_in == DEV_CMD_READ_SCRATCHPAD);
				dev_copy_scratchpad = (bus_in == DEV_CMD_COPY_SCRATCHPAD);
				dev_recall_e2 = (bus_in == DEV_CMD_RECALL_E2);
				dev_read_power_supply = (bus_in == DEV_CMD_READ_POWER_SUPPLY);
			end
	end

// this device not use crc16
assign crc16_enable  = 1'b0;	

// управление разрешением счета CRC
// только для команды READ_SCRATCHPAD

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				crc8_enable <= 1'b0;
			end
		else if (dev_read_scratchpad)
			begin
				if (STATE == ST_READ_BYTES)
					begin
						crc8_enable <= 1'b1;
					end
				else if (STATE == ST_WRITE_BUFFER)
					begin
						crc8_enable <= 1'b1;
					end
				else
					begin
						crc8_enable <= 1'b0;
					end
			end
		else
			begin
				crc8_enable <= 1'b0;
			end
	end
	
// установка количества байт для чтения или записи
always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				read_bytes <= 8'h00;
				write_bytes <= 8'h00;
			end
		else if (valid)
			begin
				if (STATE == ST_CMD_PROCESS)
					begin
						if (dev_convert_t)
							begin
								read_bytes <= DEV_CMD_CONVERT_T_READ;
								write_bytes <= DEV_CMD_CONVERT_T_WRITE;
							end
						else if (dev_write_scratchpad)
							begin
								read_bytes <= DEV_CMD_WRITE_SCRATCHPAD_READ;
								write_bytes <= DEV_CMD_WRITE_SCRATCHPAD_WRITE;
							end
						else if (dev_read_scratchpad)
							begin
								read_bytes <= DEV_CMD_READ_SCRATCHPAD_READ;
								write_bytes <= DEV_CMD_READ_SCRATCHPAD_WRITE;
							end
						else if (dev_copy_scratchpad)
							begin
								read_bytes <= DEV_CMD_COPY_SCRATCHPAD_READ;
								write_bytes <= DEV_CMD_COPY_SCRATCHPAD_WRITE;
							end
						else if (dev_recall_e2)
							begin
								read_bytes <= DEV_CMD_RECALL_E2_READ;
								write_bytes <= DEV_CMD_RECALL_E2_WRITE;
							end
						else if (dev_read_power_supply)
							begin
								read_bytes <= DEV_CMD_READ_POWER_SUPPLY_READ;
								write_bytes <= DEV_CMD_READ_POWER_SUPPLY_WRITE;
							end
					end
			end
	end

endmodule