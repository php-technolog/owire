# TCL File Generated by Component Editor 14.0
# Fri Sep 28 13:01:28 MSD 2018
# DO NOT MODIFY


# 
# ow_master "1-Wire Master" v1.0
#  2018.09.28.13:01:28
# 
# 

# 
# request TCL package from ACDS 14.0
# 
package require -exact qsys 14.0


# 
# module ow_master
# 
set_module_property DESCRIPTION ""
set_module_property NAME ow_master
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP Protocol
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME "1-Wire Master"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL ow_master
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ow_master.sv SYSTEM_VERILOG PATH ow_master.sv TOP_LEVEL_FILE
add_fileset_file ow_master_bit.sv SYSTEM_VERILOG PATH ow_master_bit.sv


# 
# parameters
# 
add_parameter OVERDRIVE INTEGER 0
set_parameter_property OVERDRIVE DEFAULT_VALUE 0
set_parameter_property OVERDRIVE DISPLAY_NAME OVERDRIVE
set_parameter_property OVERDRIVE TYPE INTEGER
set_parameter_property OVERDRIVE UNITS None
set_parameter_property OVERDRIVE ALLOWED_RANGES -2147483648:2147483647
set_parameter_property OVERDRIVE HDL_PARAMETER true
add_parameter MULTIPLIER INTEGER 1
set_parameter_property MULTIPLIER DEFAULT_VALUE 1
set_parameter_property MULTIPLIER DISPLAY_NAME MULTIPLIER
set_parameter_property MULTIPLIER TYPE INTEGER
set_parameter_property MULTIPLIER UNITS None
set_parameter_property MULTIPLIER ALLOWED_RANGES -2147483648:2147483647
set_parameter_property MULTIPLIER HDL_PARAMETER true


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset reset Input 1


# 
# connection point data_bus
# 
add_interface data_bus conduit end
set_interface_property data_bus associatedClock clock
set_interface_property data_bus associatedReset reset
set_interface_property data_bus ENABLED true
set_interface_property data_bus EXPORT_OF ""
set_interface_property data_bus PORT_NAME_MAP ""
set_interface_property data_bus CMSIS_SVD_VARIABLES ""
set_interface_property data_bus SVD_ADDRESS_GROUP ""

add_interface_port data_bus bus_in in Input 8
add_interface_port data_bus bus_out out Output 8


# 
# connection point ow
# 
add_interface ow conduit end
set_interface_property ow associatedClock clock
set_interface_property ow associatedReset reset
set_interface_property ow ENABLED true
set_interface_property ow EXPORT_OF ""
set_interface_property ow PORT_NAME_MAP ""
set_interface_property ow CMSIS_SVD_VARIABLES ""
set_interface_property ow SVD_ADDRESS_GROUP ""

add_interface_port ow ow_in in Input 1
add_interface_port ow ow_out out Output 1


# 
# connection point owire
# 
add_interface owire conduit end
set_interface_property owire associatedClock clock
set_interface_property owire associatedReset reset
set_interface_property owire ENABLED true
set_interface_property owire EXPORT_OF ""
set_interface_property owire PORT_NAME_MAP ""
set_interface_property owire CMSIS_SVD_VARIABLES ""
set_interface_property owire SVD_ADDRESS_GROUP ""

add_interface_port owire cmd cmd Input 3
add_interface_port owire presence presence Output 1
add_interface_port owire error error Output 1
add_interface_port owire done done Output 1
add_interface_port owire irq irq Output 1
add_interface_port owire clear clear Input 1


# 
# connection point crc
# 
add_interface crc conduit end
set_interface_property crc associatedClock ""
set_interface_property crc associatedReset ""
set_interface_property crc ENABLED true
set_interface_property crc EXPORT_OF ""
set_interface_property crc PORT_NAME_MAP ""
set_interface_property crc CMSIS_SVD_VARIABLES ""
set_interface_property crc SVD_ADDRESS_GROUP ""

add_interface_port crc crc_valid valid Output 1
add_interface_port crc crc8_enable enable8 Input 1
add_interface_port crc crc16_enable enable16 Input 1

