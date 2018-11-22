#include "system.h"
#include "io.h"
#include "stdint.h"

int main () {
	uint8_t status;
	uint8_t cmd_status;
	uint8_t data;
	uint8_t crc;
	uint64_t rom_no;
	uint64_t scratch;
	uint8_t last_discrepancy;
	int i;
	i = 0;
	rom_no = 0;
	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	cmd_status = IORD_8DIRECT(OW_INTERFACE_BASE, 2);
	// инициируем ошибку
	//IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x0F); // invalid cmd
	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	cmd_status = IORD_8DIRECT(OW_INTERFACE_BASE, 2);
	if (1 | cmd_status & 0x02) {
		IOWR_8DIRECT(OW_INTERFACE_BASE, 1, 0x01); // set clear
		while (!(cmd_status & 0x04)) {
			cmd_status = IORD_8DIRECT(OW_INTERFACE_BASE, 2); // wait set clear
		}
		IOWR_8DIRECT(OW_INTERFACE_BASE, 1, 0x00); // reset clear
		while ((cmd_status & 0x04)) {
			cmd_status = IORD_8DIRECT(OW_INTERFACE_BASE, 2); // wait reset clear
		}
	}
	// continue program

	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xF0); // search ROM
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x44); // convert_t

	while (i < 8) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
		if (!(status & 0x20)) {
			rom_no <<= 8;
			data = IORD_8DIRECT(OW_INTERFACE_BASE, 0);
			rom_no += data;
			i++;
		}
	}
	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);

// 0x2863ff0909000050

	// пользовательские команды
	// считывание last_discreparency
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xFF); // prefix
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x01); // команда get_last_discrepancy
	i = 0;
	while (i < 1) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
		if (!(status & 0x20)) {
			last_discrepancy = IORD_8DIRECT(OW_INTERFACE_BASE, 0);
			i++;
		}
	}

	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xFF); // prefix
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x03); // команда set_last_discrepancy
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00); // данные last_discrepancy

	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xFF); // prefix
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x01); // команда get_last_discrepancy
	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	while (status & 0x20) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	}
	last_discrepancy = IORD_8DIRECT(OW_INTERFACE_BASE, 0);

	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x55); // match ROM
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x28);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xbd);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x50);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x05);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x02);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x00);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x08);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xBE); // read scratchpad

	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	i = 0;
	scratch = 0;
	while (i < 8) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
		if (!(status & 0x20)) {
			scratch >>= 8;
			data = IORD_8DIRECT(OW_INTERFACE_BASE, 0);
			scratch += (uint64_t)(((uint64_t)data) << 56);
			i++;
		}
	}
	i = 0;
	while (i < 1) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
		if (!(status & 0x20)) {
			crc = IORD_8DIRECT(OW_INTERFACE_BASE, 0);
			i++;
		}
	}

	float temp;
	temp = (scratch & 0xFFFF) / 16;

	i = 0;
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xF0); // search ROM
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x29); // несуществующее устройство
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xFF);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0xd6);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x92);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x90);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x16);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x05);
	IOWR_8DIRECT(OW_INTERFACE_BASE, 0, 0x3d);
	while (i < 8) {
		status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
		if (!(status & 0x20)) {
			rom_no <<= 8;
			data = IORD_8DIRECT(OW_INTERFACE_BASE, 0);
			rom_no += data;
			i++;
		}
	}
	status = IORD_8DIRECT(OW_INTERFACE_BASE, 1);
	while(1) {}
}
