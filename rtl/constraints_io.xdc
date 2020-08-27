# ref: https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-35-Master.xdc

set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_in }]
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { rstx_in }]
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_txd }]
