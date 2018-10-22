module termostat(
	input logic clk,
	input logic reset_n,
	inout wire dq
);

wire ow_out;
wire ow_in;

assign ow_in = dq;
assign dq = ow_out ? 1'bZ : 1'b0;

wire [7:0] bus_in;
wire [7:0] bus_out;

wire [2:0] ow_cmd;
wire ow_presence;
wire ow_error;
wire ow_done;
wire ow_irq;

wire crc8_enable;
wire crc16_enable;
wire crc_valid;

wire protocol_rdreq, device_rdreq, rdreq, rdready, protocol_wrreq, device_wrreq, wrreq, wrready, protocol_error, protocol_ready;

// полагаем, что на выходе модулей не будет конфликта, иначе нужна более строгая проверка
assign rdreq = protocol_rdreq | device_rdreq;
assign wrreq = protocol_wrreq | device_wrreq;

wire device_crc8_enable, protocol_crc8_enable;
wire device_crc16_enable, protocol_crc16_enable;
assign crc8_enable = device_crc8_enable | protocol_crc8_enable;
assign crc16_enable = device_crc16_enable | protocol_crc16_enable;

wire slave_ctrl, slave_error, slave_ready;

wire [2:0] protocol_ow_cmd, device_ow_cmd;

wire clear;

wire [7:0] family;

assign ow_cmd = protocol_ow_cmd | device_ow_cmd; // полагаем, что на выходе модулей не будет конфликта, иначе нужна более строгая проверка

termostat_qsys u0 (
	.clk_clk                    (clk),                   //                clk.clk
	.reset_reset_n              (reset_n),               //              reset.reset_n
	.interface_bus_out          (bus_out),               //      interface_bus.out
	.interface_bus_in           (bus_in),                //                   .in
	.interface_owire_presence   (ow_presence),           //    interface_owire.presence
	.interface_owire_error      (ow_error),              //                   .error
	.interface_owire_done       (ow_done),               //                   .done
	.interface_owire_irq        (ow_irq),                //                   .irq
	.interface_owire_clear      (clear),                 //                   .clear
	.interface_protocol_rdreq   (rdreq),                 // interface_protocol.rdreq
	.interface_protocol_rdready (rdready),               //                   .rdready
	.interface_protocol_wrreq   (wrreq),                 //                   .wrreq
	.interface_protocol_wrready (wrready),               //                   .wrready
	.interface_protocol_error   (protocol_error),        //                   .error
	.interface_protocol_ready   (protocol_ready),        //                   .ready
	.protocol_bus_in            (bus_out),               //       protocol_bus.in
	.protocol_bus_out           (bus_in),                //       protocol_bus.out
	.protocol_owire_cmd         (protocol_ow_cmd),       //     protocol_owire.cmd
	.protocol_owire_presence    (ow_presence),           //                   .presence
	.protocol_owire_error       (ow_error),              //                   .error
	.protocol_owire_done        (ow_done),               //                   .done
	.protocol_owire_irq         (ow_irq),                //                   .irq
	.protocol_owire_clear       (clear),                 //                   .clear
	.protocol_protocol_rdreq    (protocol_rdreq),        //  protocol_protocol.rdreq
	.protocol_protocol_rdready  (rdready),               //                   .rdready
	.protocol_protocol_wrreq    (protocol_wrreq),        //                   .wrreq
	.protocol_protocol_wrready  (wrready),               //                   .wrready
	.protocol_protocol_error    (protocol_error),        //                   .error
	.protocol_protocol_ready    (protocol_ready),        //                   .ready
	.protocol_crc_enable8       (protocol_crc8_enable),  //       protocol_crc.enable8
	.protocol_crc_enable16      (protocol_crc16_enable), //       protocol_crc.enable16
	.protocol_crc_valid         (crc_valid),             //                   .valid   
	.protocol_slave_ctrl        (slave_ctrl),            //     protocol_slave.ctrl
	.protocol_slave_error       (slave_error),           //                   .error
	.protocol_slave_ready       (slave_ready),           //                   .ready
	.protocol_family_device     (family),                //    protocol_family.device
	.ow_in                      (ow_in),                 //                 ow.in
	.ow_out                     (ow_out),                //                   .out
	.master_owire_cmd           (ow_cmd),                //       master_owire.cmd
	.master_owire_presence      (ow_presence),           //                   .presence
	.master_owire_error         (ow_error),              //                   .error
	.master_owire_done          (ow_done),               //                   .done
	.master_owire_irq           (ow_irq),                //                   .irq
	.master_owire_clear         (clear),                 //                   .clear
	.master_bus_in              (bus_out),               //         master_bus.in
	.master_bus_out             (bus_in),                //                   .out
	.master_crc_enable8         (crc8_enable),           //         master_crc.enable8
	.master_crc_enable16        (crc16_enable),          //         master_crc.enable16
	.master_crc_valid           (crc_valid),             //                   .valid
	.device_bus_in              (bus_out),               //         device_bus.in
	.device_slave_ctrl          (slave_ctrl),            //       device_slave.ctrl
	.device_slave_error         (slave_error),           //                   .error
	.device_slave_ready         (slave_ready),           //                   .ready
	.device_family_device       (family),                //      device_family.device
	.device_protocol_rdreq      (device_rdreq),          //    device_protocol.rdreq
	.device_protocol_rdready    (rdready),               //                   .rdready
	.device_protocol_wrreq      (device_wrreq),          //                   .wrreq
	.device_protocol_wrready    (wrready),               //                   .wrready
	.device_owire_presence      (ow_presence),           //       device_owire.presence
	.device_owire_error         (ow_error),              //                   .error
	.device_owire_done          (ow_done),               //                   .done
	.device_owire_irq           (ow_irq),                //                   .irq
	.device_owire_clear         (clear),                 //                   .clear
	.device_owire_cmd           (device_ow_cmd),         //                   .cmd
	.device_crc_valid           (crc_valid),             //         device_crc.valid
	.device_crc_enable8         (device_crc8_enable),    //                   .enable8
	.device_crc_enable16        (device_crc16_enable)    //                   .enable16
);

endmodule
