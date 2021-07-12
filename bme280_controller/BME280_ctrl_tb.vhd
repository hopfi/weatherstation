----------------------------------------------------------------------------------
-- Name: Daniel Hopfinger
-- Date: 12.07.2021
-- Module: bme280_ctrl_tb
-- Description: 
-- Testbench for bme280_ctrl module.
--
-- History:
-- Version  | Date       | Information
-- ----------------------------------------
--  0.0.1   | 12.07.2021 | Initial version.
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wstat;

entity BME280_ctrl_tb is
end BME280_ctrl_tb;

architecture sim of BME280_ctrl_tb is

    constant C_CLK_PERIOD : time := 10 ns;
    constant C_I2C_PERIOD : time := 2500 ns;
    constant C_CONV_TIME_FREQ : integer := 1e9;
    
    signal clk : std_logic := '1';
    signal rst : std_logic := '1';

    signal start_measurement    : std_logic;
    signal bin_data_temp        : std_logic_vector(20 downto 0);
    signal bin_data_hum         : std_logic_vector(20 downto 0);
    signal bin_data_pres        : std_logic_vector(20 downto 0);
    signal bin_data_valid       : std_logic;
    signal en                   : std_logic;
    signal busy                 : std_logic := '0';
    signal ack_error            : std_logic;
    signal stop_mode            : std_logic_vector(1 downto 0);
    signal wr_data              : std_logic_vector(7 downto 0);
    signal wr_en                : std_logic;
    signal sending              : std_logic;
    signal rd_data              : std_logic_vector(7 downto 0);
    signal rd_en                : std_logic;
    signal receiving            : std_logic;

begin

    clk <= not clk after C_CLK_PERIOD / 2;
    rst <= '0' after 10 * C_CLK_PERIOD;

    master_proc : process
    begin

        if rst = '1' then
            wait until rst = '0';
        end if;
        wait for 50 * C_CLK_PERIOD;
        wait until rising_edge(clk);

    end process master_proc;

    bme_280 : entity wstat.BME280_ctrl(rtl)
    port map (
        i_clk               => clk,
        i_reset             => rst,
        i_start_measurement => start_measurement,
        o_bin_data_temp     => bin_data_temp,
        o_bin_data_hum      => bin_data_hum,
        o_bin_data_pres     => bin_data_pres,
        o_bin_data_valid    => bin_data_valid,
        o_en                => en,
        i_busy              => busy,
        i_ack_error         => ack_error,
        o_stop_mode         => stop_mode,
        o_wr_data           => wr_data,
        o_wr_en             => wr_en,
        i_sending           => sending,
        i_rd_data           => rd_data,
        o_rd_en             => rd_en,
        i_receiving         => receiving
    );

end sim;
