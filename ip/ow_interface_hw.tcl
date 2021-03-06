# TCL File Generated by Component Editor 14.0
# Fri Sep 28 13:01:38 MSD 2018
# DO NOT MODIFY


# 
# ow_interface "1-Wire Interface" v1.0
# Starosta 2018.09.28.13:01:38
# 1-Wire interface to Avalon MM
# 

# 
# request TCL package from ACDS 14.0
# 
package require -exact qsys 14.0


# 
# module ow_interface
# 
set_module_property DESCRIPTION "1-Wire interface to Avalon MM"
set_module_property NAME ow_interface
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP Protocol
set_module_property AUTHOR "Starosta"
set_module_property DISPLAY_NAME "1-Wire Interface"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL ow_interface
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ow_interface.sv SYSTEM_VERILOG PATH ow_interface.sv TOP_LEVEL_FILE


# 
# parameters
# 


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
# connection point avalon_slave
# 
add_interface avalon_slave avalon end
set_interface_property avalon_slave addressUnits WORDS
set_interface_property avalon_slave associatedClock avalon_clock
set_interface_property avalon_slave associatedReset reset
set_interface_property avalon_slave bitsPerSymbol 8
set_interface_property avalon_slave burstOnBurstBoundariesOnly false
set_interface_property avalon_slave burstcountUnits WORDS
set_interface_property avalon_slave explicitAddressSpan 0
set_interface_property avalon_slave holdTime 0
set_interface_property avalon_slave linewrapBursts false
set_interface_property avalon_slave maximumPendingReadTransactions 0
set_interface_property avalon_slave maximumPendingWriteTransactions 0
set_interface_property avalon_slave readLatency 0
set_interface_property avalon_slave readWaitTime 1
set_interface_property avalon_slave setupTime 0
set_interface_property avalon_slave timingUnits Cycles
set_interface_property avalon_slave writeWaitTime 0
set_interface_property avalon_slave ENABLED true
set_interface_property avalon_slave EXPORT_OF ""
set_interface_property avalon_slave PORT_NAME_MAP ""
set_interface_property avalon_slave CMSIS_SVD_VARIABLES ""
set_interface_property avalon_slave SVD_ADDRESS_GROUP ""

add_interface_port avalon_slave avs_address address Input 1
add_interface_port avalon_slave avs_byteenable byteenable Input 4
add_interface_port avalon_slave avs_write write Input 1
add_interface_port avalon_slave avs_writedata writedata Input 32
add_interface_port avalon_slave avs_read read Input 1
add_interface_port avalon_slave avs_readdata readdata Output 32
add_interface_port avalon_slave waitrequest waitrequest Output 1
set_interface_assignment avalon_slave embeddedsw.configuration.isFlash 0
set_interface_assignment avalon_slave embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avalon_slave embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avalon_slave embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avalon_clock
# 
add_interface avalon_clock clock end
set_interface_property avalon_clock clockRate 0
set_interface_property avalon_clock ENABLED true
set_interface_property avalon_clock EXPORT_OF ""
set_interface_property avalon_clock PORT_NAME_MAP ""
set_interface_property avalon_clock CMSIS_SVD_VARIABLES ""
set_interface_property avalon_clock SVD_ADDRESS_GROUP ""

add_interface_port avalon_clock avs_clk clk Input 1


# 
# connection point ow_protocol
# 
add_interface ow_protocol conduit end
set_interface_property ow_protocol associatedClock clock
set_interface_property ow_protocol associatedReset reset
set_interface_property ow_protocol ENABLED true
set_interface_property ow_protocol EXPORT_OF ""
set_interface_property ow_protocol PORT_NAME_MAP ""
set_interface_property ow_protocol CMSIS_SVD_VARIABLES ""
set_interface_property ow_protocol SVD_ADDRESS_GROUP ""

add_interface_port ow_protocol rdreq rdreq Input 1
add_interface_port ow_protocol rdready rdready Output 1
add_interface_port ow_protocol wrreq wrreq Input 1
add_interface_port ow_protocol wrready wrready Output 1
add_interface_port ow_protocol cmd_error error Input 1
add_interface_port ow_protocol cmd_ready ready Input 1


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

add_interface_port data_bus bus_out out Output 8
add_interface_port data_bus bus_in in Input 8


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

add_interface_port owire ow_presence presence Input 1
add_interface_port owire ow_error error Input 1
add_interface_port owire ow_done done Input 1
add_interface_port owire ow_irq irq Input 1
add_interface_port owire clear clear Output 1

