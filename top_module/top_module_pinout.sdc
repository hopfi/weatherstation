set_location_assignment PIN_H6 -to CLK12M

set_location_assignment PIN_A8  -to LED[0]
set_location_assignment PIN_A9  -to LED[1]
set_location_assignment PIN_A11 -to LED[2]
set_location_assignment PIN_A10 -to LED[3]
set_location_assignment PIN_B10 -to LED[4]
set_location_assignment PIN_C9  -to LED[5]
set_location_assignment PIN_C10 -to LED[6]
set_location_assignment PIN_D8  -to LED[7]

set_location_assignment PIN_L12 -to BUTTONS[0]
set_location_assignment PIN_J12 -to BUTTONS[1]
set_location_assignment PIN_J13 -to BUTTONS[2]
set_location_assignment PIN_K11 -to BUTTONS[3]
set_location_assignment PIN_K12 -to BUTTONS[4]
set_location_assignment PIN_J10 -to BUTTONS[5]
set_location_assignment PIN_H10 -to BUTTONS[6]
set_location_assignment PIN_H13 -to BUTTONS[7]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[0]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[1]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[2]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[3]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[4]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[5]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[6]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to BUTTONS[7]

set_location_assignment PIN_E6 -to USR_BTN
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to USR_BTN

set_location_assignment PIN_J2 -to rs
set_location_assignment PIN_J1 -to rw
set_location_assignment PIN_H4 -to e
set_location_assignment PIN_M3 -to data[0]
set_location_assignment PIN_L3 -to data[1]
set_location_assignment PIN_M2 -to data[2]
set_location_assignment PIN_M1 -to data[3]
set_location_assignment PIN_N3 -to data[4]
set_location_assignment PIN_N2 -to data[5]
set_location_assignment PIN_K2 -to data[6]
set_location_assignment PIN_K1 -to data[7]


set_location_assignment <pin> -to sensor_scl
set_location_assignment <pin> -to sernsor_sda