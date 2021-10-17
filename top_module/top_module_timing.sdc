#create input clock which is 12MHz 
create_clock -name input_clk -period 12MHz [get_ports {input_clk}]

#derive PLL clocks 
derive_pll_clocks

#derive clock uncertainty 
derive_clock_uncertainty

#set false path 
#set_false_path -from [get_ports {USR_BTN}] 
#set_false_path -from * -to [get_ports {LED*}]