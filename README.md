# weatherstation

In this project I build a simple weather station.
At a FPGA conference I got a Trenz MAX1000 board as a giveaway.
Since I only work with Xilinx devices, I wanted to get more familiar with Intel FPGAs and their workflow.
So I started this project, which could also be useful for home use.
The FPGA gets sensor data from a I2C environment sensor (BME280) converts the data to BCD and sens it to a LC-Display.



## Project specific modules
Following (specific) modules are contained in this repository:

- BME280 Controller

This module handles the communication (writing configuration, reading data) to the sensor over I2C.

- Data Converter

The sensor provides the environment data as "uncompensated" data which has to be converted as specified in the datasheet.
After the data is "compensated" it is converted from binary to BCD values.

- LCD Controller

BCD values of temperature, pressure and humidity get sent to the LC-Display together with additional text.

- Top Module

Mostly a structure module connecting all the other modules



## Generic modules
Some additional modules from different repositories are needed for this project:

BIN to BCD Converter (https://github.com/hopfi/bin_bcd_converter.git)

BME280 Data Compensator (https://github.com/hopfi/bme280_data_comp.git)

HD44780 Driver (https://github.com/hopfi/hd44780_driver.git)

I2C Master (https://github.com/hopfi/i2c_master.git)


## Todo

- Find different compensation formular for the pressure data

- Fix compensation formular for humidity

- Signed BCD for temperature
