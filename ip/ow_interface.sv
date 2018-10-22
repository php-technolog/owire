module ow_interface(
	input logic clk,
	input logic reset,
	// avalon bus
	input logic avs_clk,
	input logic [0:0] avs_address,
	input logic [3:0] avs_byteenable, 
	input logic avs_write,
	input logic [31:0]	avs_writedata,
	input logic avs_read,
	output logic [31:0]	avs_readdata,
	output logic waitrequest,
	// owire module
	output logic [7:0] bus_out,
	input logic [7:0] bus_in,
	input logic ow_presence,
	input logic ow_error,
	input logic ow_done,
	input logic ow_irq,
	// ow_protocol module
	input logic cmd_error, // неверная команда
	input logic cmd_ready, // готовность к приему следующей команды
	input logic rdreq, // запрос на чтение данных из буфера
	output logic rdready, // данные прочитаны
	input logic wrreq, // запрос на запись данных в буфер
	output logic wrready, // данные записаны
	output logic clear // сброс всей системы в начальное состояние, используется при возникновении ошибки
);

wire local_reset;
assign local_reset = reset | clear;

assign waitrequest = 1'b0;

wire data_clk;
wire ow_clk;
assign data_clk = avs_clk;
assign ow_clk = clk;

wire [7:0] data_out;
wire [7:0] data_in;

wire ow_read;
wire ow_write;
wire ow_wrfull;
wire ow_rdempty;

wire data_read;
wire data_write;
wire data_wrfull;
wire data_rdempty;

wire [7:0] ow_status;
wire status_read;

wire [7:0] cmd_status;
wire cmd_status_read;

reg [7:0] ctrl_status;
wire ctrl_write;

wire address_zero;
assign address_zero = (avs_address == 0);

assign data_read = avs_read & address_zero & avs_byteenable[0];
assign avs_readdata[7:0] = data_read ? data_in : 8'b0;
assign status_read = avs_read & address_zero & avs_byteenable[1];
assign avs_readdata[15:8] = status_read ? ow_status : 8'b0;
assign cmd_status_read = avs_read & address_zero & avs_byteenable[2];
assign avs_readdata[23:16] = cmd_status_read ? cmd_status : 8'b0;
assign avs_readdata[31:24] = 8'b0;

assign data_write = avs_write & address_zero & avs_byteenable[0];
assign data_out = data_write ? avs_writedata[7:0] : 8'b0;
assign ctrl_write = avs_write & address_zero & avs_byteenable[1];

always_ff @ (posedge avs_clk or posedge reset)
	begin
		if (reset)
			begin
				ctrl_status <= 8'b0;
			end
		else if (ctrl_write)
			begin
				ctrl_status <= avs_writedata[15:8];
			end
	end

// порядок очистки, сначала записываем бит 0, потом ждем, когда установится бит clear в cmd_status, потом сбрасываем бит 0 и ждем сброса бита clear в cmd_status
always_ff @ (posedge clk or posedge reset)
	begin
		clear <= reset ? 1'b0 : ctrl_status[0];
	end
	
assign ow_status = {ow_rdempty, data_wrfull, data_rdempty, ow_wrfull, ow_presence, ow_error, ow_irq, ow_done};
// значения ow_presence, ow_error, ow_irq верны при ow_done = 1
assign cmd_status = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, clear, cmd_error, cmd_ready};

// входящий поток данных
dcfifo	fifo_in (
			.aclr (local_reset),
			.data (bus_in), // данные с шины 1-wire
			.rdclk (data_clk),
			.rdreq (data_read),
			.wrclk (ow_clk),
			.wrreq (ow_write),
			.q (data_in),
			.rdempty (data_rdempty),
			.wrfull (ow_wrfull),
			.rdfull (),
			.rdusedw (),
			.wrempty (),
			.wrusedw ());
defparam
	fifo_in.intended_device_family = "Cyclone IV E",
	fifo_in.lpm_numwords = 16,
	fifo_in.lpm_showahead = "ON",
	fifo_in.lpm_type = "dcfifo",
	fifo_in.lpm_width = 8,
	fifo_in.lpm_widthu = 4,
	fifo_in.overflow_checking = "ON",
	fifo_in.rdsync_delaypipe = 5,
	fifo_in.read_aclr_synch = "OFF",
	fifo_in.underflow_checking = "ON",
	fifo_in.use_eab = "OFF",
	fifo_in.write_aclr_synch = "OFF",
	fifo_in.wrsync_delaypipe = 5;

assign ow_write = ~ow_wrfull & ~wrready;
	
reg wrready_state;
assign wrready = ~wrready_state;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				wrready_state <= 1'b0;
			end
		else
			begin
				if (ow_write)
					begin
						wrready_state <= 1'b0;
					end
				else if (pos_wrreq)
					begin
						wrready_state <= 1'b1;
					end
			end
	end

reg wrreq_state;
wire pos_wrreq;
assign pos_wrreq = ~wrreq_state & wrreq;

always_ff @ (posedge clk or posedge local_reset)
	begin
		wrreq_state <= local_reset ? 1'b0 : wrreq;
	end

// исходящий поток данных
dcfifo	fifo_out (
			.aclr (local_reset),
			.data (data_out), // данные с шины Avalon
			.rdclk (ow_clk),
			.rdreq (ow_read),
			.wrclk (data_clk),
			.wrreq (data_write),
			.q (bus_out),
			.rdempty (ow_rdempty),
			.wrfull (data_wrfull),
			.rdfull (),
			.rdusedw (),
			.wrempty (),
			.wrusedw ());
defparam
	fifo_out.intended_device_family = "Cyclone IV E",
	fifo_out.lpm_numwords = 16,
	fifo_out.lpm_showahead = "OFF",
	fifo_out.lpm_type = "dcfifo",
	fifo_out.lpm_width = 8,
	fifo_out.lpm_widthu = 4,
	fifo_out.overflow_checking = "ON",
	fifo_out.rdsync_delaypipe = 5,
	fifo_out.read_aclr_synch = "OFF",
	fifo_out.underflow_checking = "ON",
	fifo_out.use_eab = "OFF",
	fifo_out.write_aclr_synch = "OFF",
	fifo_out.wrsync_delaypipe = 5;
	
assign ow_read = ~ow_rdempty & ~rdready;
	
reg rdready_state;
assign rdready = ~rdready_state;

always_ff @ (posedge clk or posedge local_reset)
	begin
		if (local_reset)
			begin
				rdready_state <= 1'b0;
			end
		else
			begin
				if (ow_read)
					begin
						rdready_state <= 1'b0;
					end
				else if (pos_rdreq)
					begin
						rdready_state <= 1'b1;
					end
			end
	end

reg rdreq_state;
wire pos_rdreq;
assign pos_rdreq = ~rdreq_state & rdreq;

always_ff @ (posedge clk or posedge local_reset)
	begin
		rdreq_state <= local_reset ? 1'b0 : rdreq;
	end
	
endmodule
