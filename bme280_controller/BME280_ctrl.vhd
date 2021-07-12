----------------------------------------------------------------------------------
-- Name: Daniel Hopfinger
-- Date: 12.07.2021
-- Module: BME280_ctrl.vhd
-- Description:
-- Controller module for the Bosch BME280 environment sensor.
-- Initiates I2C transactions to configure the sensor, start measurements and read the results.
-- Idea is to have an array of i2c commands that get processed by the controller.
-- The array contains i.e. configuration data or data readout commands for the sensor.
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
 
entity bme280_ctrl is
    port (
        i_clk               : in  std_logic;
        i_reset             : in  std_logic;
        i_start_measurement : in  std_logic;
        o_bin_data_temp     : out std_logic_vector(20 downto 0);
        o_bin_data_hum      : out std_logic_vector(20 downto 0);
        o_bin_data_pres     : out std_logic_vector(20 downto 0);
        o_bin_data_valid    : out std_logic;
        o_en                : out std_logic;
        i_busy              : in  std_logic;
        i_ack_error         : in  std_logic;
        o_stop_mode         : out std_logic_vector(1 downto 0);
        o_wr_data           : out std_logic_vector(7 downto 0);
        o_wr_en             : out std_logic;
        i_sending           : in  std_logic;
        i_rd_data           : in  std_logic_vector(7 downto 0);
        o_rd_en             : out std_logic;
        i_receiving         : in  std_logic
    );
end entity bme280_ctrl;

architecture rtl of bme280_ctrl is

    signal cnt    : unsigned(15 downto 0);
    signal cnt_en : std_logic;
    signal i2c_start : std_logic;
    signal start_reg : std_logic;

    signal i : integer range 0 to 7;

    type bme_fsm is (init, idle, write_slv_addr, wait_write_done, write_data, read_data, decide);
    signal bme_state : bme_fsm;
        

    --type data_arr is array (natural range 0 to 3) of std_logic_vector(7 downto 0);
    type data_arr is array (natural range 0 to 8) of std_logic_vector(18 downto 0);
    signal ta_arr : data_arr := (
    -- [num_of_write | rw bit | reg_addr | wr_data/num_of_read]
        "01" & '0' & x"F3" & x"00", -- Start read register: status
        "01" & '1' & x"F3" & x"00", -- Read register: status
        "10" & '0' & x"F2" & x"01", -- Write register: ctrl_hum (config)
        "10" & '0' & x"F4" & x"24", -- Write register: ctrl_meas (config)
        "10" & '0' & x"F4" & x"25", -- Write register: ctrl_meas (start measurement)
        "01" & '0' & x"F3" & x"00", -- Start read register: status
        "01" & '1' & x"F3" & x"00", -- Read register: status
        "01" & '0' & x"F7" & x"00", -- Start read register: hum_lsb, hum_msb, temp_xlsb, temp_lsb, temp_msb, press_xlsb, press_lsb, press_msb
        "01" & '1' & x"F7" & x"07" -- Read register: hum_lsb, hum_msb, temp_xlsb, temp_lsb, temp_msb, press_xlsb, press_lsb, press_msb
    );

    type rd_arr is array (natural range 0 to 8) of std_logic_vector(7 downto 0);
    signal read_arr : rd_arr := (others => (others => '0'));
    

    signal ta_idx : integer range 0 to 255;
    signal wr_idx : integer range 0 to 255;
    signal rd_idx : integer range 0 to 255;

    constant slv_addr : std_logic_vector(6 downto 0) := "1110110"; --x"76";

    signal en       : std_logic;
    signal wr_data  : std_logic_vector(7 downto 0);
    signal wr_en    : std_logic;
    signal rd_data  : std_logic_vector(7 downto 0);
    signal rd_en    : std_logic;

    signal sending_r1   : std_logic;
    signal receiving_r1 : std_logic;

    signal num_of_wr_data : std_logic_vector(1 downto 0);
    signal num_of_rd_data : std_logic_vector(7 downto 0);
    signal rw_bit         : std_logic;

    signal test_sig : integer range 0 to 7;

begin
    o_en        <= en;
    o_stop_mode <= "00";
    o_wr_data   <= wr_data;
    o_wr_en     <= wr_en;
    o_rd_en     <= rd_en;

    num_of_wr_data <= ta_arr(ta_idx)(18 downto 17);
    num_of_rd_data <= ta_arr(ta_idx)(7 downto 0);
    rw_bit         <= ta_arr(ta_idx)(16);
    
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_reset = '1' then
                bme_state <= init;
            else
                rd_en <= '0';
                sending_r1 <= i_sending;
                receiving_r1 <= i_receiving;

                --if i_start_measurement = '1' then
                if i2c_start = '1' then
                    start_reg <= '1';
                end if;

                case bme_state is
                    when init =>
                        en <= '0';
                        start_reg <= '0';
                        wr_en <= '0';
                        rd_en <= '0';

                        ta_idx <= 0;
                        wr_idx <= 0;
                        rd_idx <= 0;
                        bme_state <= idle;

                    when idle =>
                        if start_reg = '1' then
                            en <= '1';

                            if i_busy = '1' then
                                start_reg <= '0';

                                wr_idx <= 0;
                                rd_idx <= 0;
                                bme_state <= write_slv_addr;
                            end if;
                        end if;

                    when write_slv_addr =>
                        wr_data   <= slv_addr & rw_bit;
                        wr_en     <= '1';
                        bme_state <= wait_write_done;


                    when wait_write_done =>
                        if i_sending = '1' and sending_r1 = '0' then 
                            wr_en <= '0';
                        end if;

                        if i_sending = '0' and sending_r1 = '1' then
                            wr_idx <= wr_idx + 1;

                            if rw_bit = '1' then
                                bme_state <= read_data;
                            else 
                                if wr_idx = to_integer(unsigned(num_of_wr_data)) then
                                    en <= '0';
                                    ta_idx <= ta_idx + 1;
                                    bme_state <= idle;
                                else
                                    bme_state <= write_data;
                                end if;
                            end if;
                        end if;
                    
                    when write_data =>
                        wr_data   <= ta_arr(ta_idx)(15 - ((wr_idx-1)*8) downto 8 - ((wr_idx-1)*8));
                        wr_en     <= '1';
                        bme_state <= wait_write_done;

                    when read_data =>
                        if i_receiving = '0' and receiving_r1 = '1' then
                            if rd_idx = to_integer(unsigned(num_of_rd_data)) then
                                read_arr(rd_idx) <= i_rd_data;
                                en <= '0';
                                bme_state <= decide;
                            else
                                rd_idx <= rd_idx + 1;
                                rd_en <= '1';
                                read_arr(rd_idx) <= i_rd_data;
                            end if;
                        end if;

                    when decide =>
                        if ta_idx = 8 then
                            ta_idx <= 0;
                        else
                            ta_idx <= ta_idx + 1;
                        end if;
                        bme_state <= idle;


                    when others =>
                        null;
                end case;


            end if;
        end if;
    end process;
    
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_reset = '1' then
                cnt <= (others => '0');
                cnt_en <= '1';
                i2c_start <= '0';
            else
                i2c_start <= '0';
                
                --if i_busy = '0' then
                --    cnt_en <= '1';
                --end if;

                if cnt_en = '1' then
                    cnt <= cnt + 1;
                    if cnt = x"2fff" then
                        i2c_start <= '1';
                        --cnt_en <= '0';
                        cnt <= (others => '0');
                    end if;
                end if;

            end if;
        end if;
    end process;
     
end architecture rtl;

