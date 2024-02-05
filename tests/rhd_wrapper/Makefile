# Makefile

TOPLEVEL_LANG = verilog
VERILOG_SOURCES += $(shell pwd)/../../hdl/rhd_wrapper.v
VERILOG_SOURCES += $(shell pwd)/../../hdl/spi_master_cs.v
VERILOG_SOURCES += $(shell pwd)/../../hdl/spi_master.v
TOPLEVEL = rhd_wrapper
MODULE = rhd_wrapper_tb

include $(shell cocotb-config --makefiles)/Makefile.sim