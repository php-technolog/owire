/*
 * Формирование сигнала сброса на линии
 * формирует сигнал сброс и детектирует прерывание и присутствие устройства, а также короткое замыкание
 * done = 1, модуль готов и/или выполнил команду
 * irq = 1, устройство сформировало прерывание (не протестировано)
 * presence = 0, error = 0, устройства нет на линии
 * presence = 1, error = 0, устройство есть на линии
 * presence = 0, error = 1, короткое замыкание
 */
module ow_master_bit
#(
	parameter	RESET_LENGTH = 16'd480, // 480 мкс <= Trstl, 8 временных слотов, overdrive 48 <= Trstl < 80 
	parameter	IRQ_WAIT = 16'd540, // [RESET_LENGTH +] 60 мкс время ожидания восстановления линии после сброса, если линия все еще в нуле, то вероятно пришло прерывание
	parameter	IRQ_LENGTH = 16'd3840, // [RESET_LENGTH +] 960 мкс <= Tirq < 3840 мкс, максимальная длина импульса прерывания
	parameter	PRESENCE_DELAY = 16'd540, // [RESET_LENGTH +] 15 мкс <= Tpdh < 60 мкс, 1 временной слот, overdrive 2 <= Tpdh < 6
	parameter	PRESENCE_LENGTH = 16'd780, // [PRESENCE_DELAY +] 60 мкс <= Tpdl < 240 мкс, 1-3 временной слот, overdrive 8 <= Tpdl < 24
	parameter   RESET_END = 16'd960, // 2 тайм-слота (2 * 480 мкс)
	parameter	RW_INIT = 16'd3, // длина импульса инициализации операции
	parameter	RW_DELAY = 16'd15, // задержка на переход линии в другое состояние
	parameter	RW_LENGTH = 16'd60, // окно чтения мастером или устройством данных с линии
	parameter   TIME_SLOT_DELAY = 16'd5 // задержка между тайм-слотами на восстановление линии
)
(
	input logic clk, // 1 MHz
	input logic reset, // общий сброс
	input logic ow_in, // 1-Wire input
	output logic ow_out, // 1-Wire output
	input logic [1:0] cmd, // command
	output logic presence, // есть устройства на линии
	output logic error, // ошибка, линия не была освобождена устройством, возможно короткое замыкание	
	output logic irq, // прерывание на линии
	output logic done, // операция завершена
	input logic sdi, // вход битового потока
	output logic sdo // выход битового потока
);

wire cmd_strobe;
wire pos_cmd_strobe = ~cmd_strobe & (|cmd);

always_ff @ (posedge clk or posedge reset)
	begin
		cmd_strobe <= reset ? 1'b0 : (|cmd);
	end

reg ow_wire_state;

always @ (posedge clk or posedge reset)
	begin
		if (reset)
			ow_wire_state <= 1'b1;
		else
			ow_wire_state <= ow_in;
	end

reg [15:0] timer;
reg timer_enable;

always @ (posedge clk or posedge reset)
	begin
		if (reset)
			timer <= 'b0;
		else if (timer_enable)
			timer++;
		else
			timer <= 'b1;
	end

reg [15:0] timer_limit;
reg timer_overflow;

always @ (negedge clk or posedge reset)
	begin
		if (reset)
			timer_overflow <= 1'b0;
		else if (timer < timer_limit)
			timer_overflow <= 1'b0;
		else if (~timer_enable)
			timer_overflow <= 1'b0;
		else
			timer_overflow <= 1'b1;
	end
	
localparam CMD_NONE = 0;
localparam CMD_RESET = 1;
localparam CMD_READ_BIT = 2;
localparam CMD_WRITE_BIT = 3;

reg we;
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			we <= 1'b0;
		else if (pos_cmd_strobe)
			we = (cmd == CMD_WRITE_BIT);
	end

assign done = STATE == ST_IDLE;

assign timer_enable = ~((STATE == ST_IDLE) | (STATE == ST_DONE_BEGIN));

reg presence_reg;
reg error_reg;
reg irq_reg;

assign presence = presence_reg & done;
assign error = error_reg & done;
assign irq = irq_reg & done;

reg [4:0] STATE;

localparam ST_IDLE = 0;
// RESET STATES
localparam ST_RESET_SIGNAL_BEGIN = 1;
localparam ST_RESET_SIGNAL_END = 2;
localparam ST_RESET_DELAY_BEGIN = 3;
localparam ST_RESET_DELAY_END = 4;
localparam ST_PRESENCE_DELAY_BEGIN = 5;
localparam ST_PRESENCE_DELAY_END = 6;
localparam ST_IRQ_BEGIN = 7;
localparam ST_IRQ_END = 8;
localparam ST_PRESENCE_BEGIN = 9;
localparam ST_PRESENCE_END = 10;
localparam ST_RESET_BEGIN = 11;
localparam ST_RESET_END = 12;
// READ-WRITE STATES
localparam ST_RW_SIGNAL_BEGIN = 13;
localparam ST_RW_SIGNAL_END = 14;
localparam ST_RW_DELAY_BEGIN = 15;
localparam ST_RW_DELAY_END = 16;
localparam ST_RW_BEGIN = 17;
localparam ST_RW_END = 18;
// TIME SLOT DELAY
localparam ST_DONE_BEGIN = 19;
localparam ST_DONE_END = 20;

always @ (posedge clk or posedge reset)
	begin
		if (reset)
			STATE <= ST_IDLE;
		else
			case (STATE)
				ST_IDLE:
					begin
						if (pos_cmd_strobe)
							begin
								if (cmd == CMD_RESET)
									STATE <= ST_RESET_SIGNAL_BEGIN;
								else if (cmd == CMD_READ_BIT | cmd == CMD_WRITE_BIT)
									STATE <= ST_RW_SIGNAL_BEGIN;
							end
					end
				// RESET
				ST_RESET_SIGNAL_BEGIN: // формируем сигнал сброса на линии
					begin
						STATE <= ST_RESET_SIGNAL_END;
					end
				ST_RESET_SIGNAL_END:
					begin
						if (timer_overflow)
							STATE <= ST_RESET_DELAY_BEGIN;
					end
				ST_RESET_DELAY_BEGIN: // задержка на восстановление линии после сброса
					begin
						STATE <= ST_RESET_DELAY_END;
					end
				ST_RESET_DELAY_END:
					begin
						if (timer_overflow)
							STATE <= ST_IRQ_BEGIN; // прерывание есть
						else if (ow_wire_state)
							STATE <= ST_PRESENCE_DELAY_BEGIN; // прерывания нет, ждем сигнал присутствия
					end
				ST_IRQ_BEGIN: // если на линии ноль, то есть прерывание
					begin
						STATE <= ST_IRQ_END;
					end
				ST_IRQ_END: // ждем восстановления линии после прерывания
					begin
						if (timer_overflow | ow_wire_state)
							STATE <= ST_PRESENCE_DELAY_BEGIN;
					end
				ST_PRESENCE_DELAY_BEGIN: // задержка на ожидание ответа от устройства
					begin
						STATE <= ST_PRESENCE_DELAY_END;
					end
				ST_PRESENCE_DELAY_END: // ждем сигнал присутствия, когда ведомое устройство сбросит линию в ноль
					begin
						if (timer_overflow | ~ow_wire_state)
							STATE <= ST_PRESENCE_BEGIN;
					end
				ST_PRESENCE_BEGIN: // ждем сигнал присутствия устройства
					begin
						STATE <= ST_PRESENCE_END;
					end
				ST_PRESENCE_END: // ждем, когда ведомое устройство вернет линию в исходное состояние
					begin
						if (timer_overflow | ow_wire_state)
							STATE <= ST_RESET_BEGIN;
					end
				ST_RESET_BEGIN:
					begin
						STATE <= ST_RESET_END;
					end
				ST_RESET_END:
					begin
						if ( timer_overflow )
							STATE <= ST_DONE_BEGIN;
					end
				// READ-WRITE
				ST_RW_SIGNAL_BEGIN:
					begin
						STATE <= ST_RW_SIGNAL_END;
					end
				ST_RW_SIGNAL_END:
					begin
						if (timer_overflow)
							STATE <= ST_RW_DELAY_BEGIN;
					end
				ST_RW_DELAY_BEGIN:
					begin
						STATE <= ST_RW_DELAY_END;
					end
				ST_RW_DELAY_END:
					begin
						if ( timer_overflow ) // задержка на установку состояния линии
							STATE <= ST_RW_BEGIN;
					end
				ST_RW_BEGIN:
					begin
						STATE <= ST_RW_END;
					end
				ST_RW_END:
					begin
						if ( timer_overflow )
							STATE <= ST_DONE_BEGIN;
					end
				ST_DONE_BEGIN: // задержка между тайм-слотами
					begin
						STATE <= ST_DONE_END;
					end
				ST_DONE_END:
					begin
						if ( timer_overflow )
							STATE <= ST_IDLE;
					end
			endcase
	end

always @ (negedge clk or posedge reset)
	begin
		if (reset)
			timer_limit <= RESET_LENGTH;
		else if (STATE == ST_RESET_SIGNAL_BEGIN)
			timer_limit <= RESET_LENGTH;
		else if (STATE == ST_RESET_DELAY_BEGIN)
			timer_limit <= IRQ_WAIT;
		else if (STATE == ST_IRQ_BEGIN)
			timer_limit <= IRQ_LENGTH;
		else if (STATE == ST_PRESENCE_DELAY_BEGIN)
			timer_limit <= PRESENCE_DELAY;
		else if (STATE == ST_PRESENCE_BEGIN)
			timer_limit <= PRESENCE_LENGTH;
		else if (STATE == ST_RW_SIGNAL_BEGIN)
			timer_limit <= RW_INIT;
		else if (STATE == ST_RW_DELAY_BEGIN)
			timer_limit <= RW_DELAY;
		else if (STATE == ST_RW_BEGIN)
			timer_limit <= RW_LENGTH;
		else if (STATE == ST_RESET_BEGIN)
			timer_limit <= RESET_END;
		else if (STATE == ST_DONE_BEGIN)
			timer_limit <= TIME_SLOT_DELAY;
	end

// RESET
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			presence_reg <= 1'b0;
		else if (STATE == ST_RESET_SIGNAL_BEGIN)
			presence_reg <= 1'b0;
		else if (STATE == ST_PRESENCE_END)
			presence_reg <= ~timer_overflow & (presence_reg | ~ow_wire_state); // если на линии был ноль, то значит устройство на линии есть
	end

// поддержка прерываний не протестирована!
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			irq_reg <= 1'b0;
		else if (STATE == ST_RESET_SIGNAL_BEGIN)
			irq_reg <= 1'b0;
		else if (STATE == ST_IRQ_END)
			irq_reg <= ~timer_overflow & (irq_reg | ~ow_wire_state); // регистрируем прерывание
	end
			
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			error_reg <= 1'b0;
		else if (STATE == ST_RESET_SIGNAL_BEGIN)
			error_reg <= 1'b0;
		else if (STATE == ST_RESET_SIGNAL_END)
			error_reg <= error_reg | (ow_wire_state & timer_overflow); // не удалось сбросить линию в ноль
		else if (STATE == ST_IRQ_END)
			error_reg <= error_reg | timer_overflow; // слишком длинное прерывание
		else if (STATE == ST_PRESENCE_END)
			error_reg <= error_reg | timer_overflow; // линия не освобождена, возможно короткое замыкание
	end

// READ-WRITE
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			ow_out <= 1'b1;
		else if (STATE == ST_IDLE)
			ow_out <= 1'b1;
		else if (STATE == ST_RESET_SIGNAL_BEGIN)
			ow_out <= 1'b0;
		else if (STATE == ST_RESET_DELAY_BEGIN)
			ow_out <= 1'b1;
		else if (STATE == ST_RW_SIGNAL_END)
			ow_out <= 1'b0;
		else if (STATE == ST_RW_DELAY_BEGIN)
			// выставляем нужный бит для записи
			// переводим линию в третье состояние для чтения
			ow_out <= we ? sdi : 1'b1;
		else if (STATE == ST_DONE_BEGIN)
			ow_out <= 1'b1;
	end
	
always @ (posedge clk or posedge reset)
	begin
		if (reset)
			sdo <= 1'b1;
		else if (STATE == ST_RW_SIGNAL_BEGIN)
			sdo <= 1'b1;
		else if (STATE == ST_RW_END)
			sdo <= sdo & ow_wire_state; // читаем ответ, при записи на выходе будет входное значение
	end

endmodule
