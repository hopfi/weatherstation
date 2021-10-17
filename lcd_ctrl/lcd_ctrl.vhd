----------------------------------------------------------------------------------
-- Name: Daniel Hopfinger
-- Date: 30.07.2021
-- Module: lcd_ctrl.vhd
-- Description:
-- Controller module that generates the data to be written to the display
--
-- History:
-- Version  | Date       | Information
-- ----------------------------------------
--  0.0.1   | 30.07.2021 | Initial version.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_ctrl is
    generic (
        G_DISP_RAM_FILE : string := ""
    );
    port (
        i_clk            : in  std_logic;                       --! Clk input
        i_rst            : in  std_logic;                       --! Reset input

        --! Data input interface
        i_bcd_temp_sign  : in  std_logic;                       --! Sign of BCD temperature
        i_bcd_temp       : in  std_logic_vector(11 downto 0);   --! Temperature input coded in BCD
        i_bcd_pres       : in  std_logic_vector(23 downto 0);   --! Pressure input coded in BCD
        i_bcd_hum        : in  std_logic_vector(7 downto 0);    --! Humidity input coded in BCD
        i_bcd_valid      : in  std_logic;                       --! Valid signal, start operation
        o_bcd_busy       : out std_logic;                       --! Busy signal indicating going operation

        --! Display driver interface
        o_lcd_start      : out std_logic;                       --! Start signals start output of data
        i_lcd_busy       : in  std_logic;                       --! Busy signal halts operation of data output
        o_lcd_rw         : out std_logic;                       --! LCD RW signal bit
        o_lcd_rs         : out std_logic;                       --! LCD RS signal bit
        o_lcd_data       : out std_logic_vector(7 downto 0)     --! LCD Data vector
    );
end entity lcd_ctrl;

architecture rtl of lcd_ctrl is

    --! State machine handling data output from ram to display driver
    type disp_fsm is (init, idle, write_ram, write_lcd_data, wait_lcd_busy);
    signal disp_state : disp_fsm;

    --! Memory structure storing lcd command data and control signals
    --! [rs | rw | data]
    type disp_comm_arr is array (natural range <>) of std_logic_vector(9 downto 0);

    --! Display initialisation
    constant C_DISP_INIT_LENGTH : integer := 3;
    constant disp_init : disp_comm_arr(0 to C_DISP_INIT_LENGTH - 1) := (
        "0000111100", --! Function set x3C
        "0000000110", --! Entry mode   x06
        "0000001110"  --! Display on   x0E
    );

    --! RAM containing data for output to display. Shows: 
    --! Line 0: "Temp xxx°C"
    --! Line 0: "Pres xxxxxxPa"
    --! Line 0: "Hum xxx%"
    constant C_DISP_COMMAND_LENGTH : integer := 39;
    constant C_DISP_RAM_LENGTH : integer := 64;
    signal disp_ram : disp_comm_arr(0 to C_DISP_RAM_LENGTH - 1);
    attribute ram_init_file : string;
    attribute ram_init_file of disp_ram : signal is G_DISP_RAM_FILE;--"X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/disp_ram_content.mif";


    --! Index array indicating where placeholders for measurement data in ram are
    constant C_MEAS_DIGITS_LENGTH : integer := 12;
    type idx_arr is array (0 to C_MEAS_DIGITS_LENGTH - 1) of std_logic_vector(7 downto 0);
    constant meas_idx_arr : idx_arr := (
        x"07", x"08", x"09", x"0B",                 --! Temperature
        x"15", x"16", x"17", x"18", x"19", x"1A",   --! Pressure
        x"24", x"25"                                --! Humidity
    );

    signal init_idx : integer range 0 to C_DISP_INIT_LENGTH;            --! Initialisation index iterating through disp_init array
    signal meas_data_idx : integer range 0 to C_MEAS_DIGITS_LENGTH;     --! Index iterating through meas_idx_arr
    signal meas_data : std_logic_vector(7 downto 0);                    --! Converted BCD to LCD code data. Gets stored in RAM at position indicated by meas_idx_arr.
    signal temp_sgn : std_logic_vector(7 downto 0);                     --! Sign of BCD temperature coded in LCD charset code

    --! Internal signals of output ports
    signal bcd_busy    : std_logic;
    signal lcd_busy_r1 : std_logic;
    signal lcd_rs      : std_logic;
    signal lcd_rw      : std_logic;
    signal lcd_data    : std_logic_vector(7 downto 0);
    signal lcd_start   : std_logic;

    --! RAM control and data signals
    signal ram_we      : std_logic;
    signal ram_wr_addr : integer range 0 to C_DISP_RAM_LENGTH - 1;
    signal ram_wr_data : std_logic_vector(9 downto 0);
    signal ram_rd_addr : integer range 0 to C_DISP_RAM_LENGTH - 1;
    signal ram_rd_data : std_logic_vector(9 downto 0);

begin

    --! Internal signals of output ports
    o_lcd_rs    <= lcd_rs;
    o_lcd_rw    <= lcd_rw;
    o_lcd_data  <= lcd_data;
    o_lcd_start <= lcd_start;
    o_bcd_busy  <= bcd_busy;
    bcd_busy <= '0' when disp_state = idle else '1';

    --! Initializes display.
    --! Saves BCD measurement data to RAM. 
    --! Iterates through RAM and displays the measurement data on the display.
    ctrl_proc : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                init_idx   <= 0;
                disp_state <= init;
            else
                lcd_busy_r1 <= i_lcd_busy;
                lcd_start   <= '0';
                ram_we      <= '0';

                case disp_state is
                    when init =>
                        meas_data_idx <= C_MEAS_DIGITS_LENGTH;

                        if i_lcd_busy = '0' and lcd_busy_r1 = '1' then
                            lcd_start <= '1';
                            lcd_rs    <= disp_init(init_idx)(9);
                            lcd_rw    <= disp_init(init_idx)(8);
                            lcd_data  <= disp_init(init_idx)(7 downto 0);
                            init_idx  <= init_idx + 1;

                            if init_idx = 2 then
                                disp_state    <= idle;
                            end if;
                        end if;

                    when idle =>
                        if i_bcd_valid = '1' then
                            ram_rd_addr   <= 0;
                            meas_data_idx <= 0;

                            disp_state    <= write_ram;
                        end if;
                    
                    when write_ram =>
                        ram_we      <= '1';
                        ram_wr_addr <= to_integer(unsigned(meas_idx_arr(meas_data_idx)));
                        ram_wr_data <= "10" & meas_data;

                        if meas_data_idx = C_MEAS_DIGITS_LENGTH - 1 then
                            disp_state <= write_lcd_data;
                        else
                            meas_data_idx <= meas_data_idx + 1;
                        end if;

                    when write_lcd_data =>
                        lcd_start <= '1';
                        lcd_rs    <= ram_rd_data(9);
                        lcd_rw    <= ram_rd_data(8);
                        lcd_data  <= ram_rd_data(7 downto 0);
                        
                        if ram_rd_addr < C_DISP_COMMAND_LENGTH - 1 then
                            ram_rd_addr <= ram_rd_addr + 1;
                        else
                            ram_rd_addr <= 0;
                        end if;

                        disp_state <= wait_lcd_busy;

                    when wait_lcd_busy =>
                        if i_lcd_busy = '0' and lcd_busy_r1 = '1' then
                            if ram_rd_addr = 0 then
                                disp_state <= idle;
                            else
                                disp_state <= write_lcd_data;
                            end if;
                        end if;

                    when others =>
                        null;
                end case;

            end if;
        end if;
    end process ctrl_proc;
    
    --! Process to infer RAM with command data for display
    --! RAM containts commands for LCD display.
    ram_proc : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if ram_we = '1' then
                disp_ram(ram_wr_addr) <= ram_wr_data;
            end if;
            ram_rd_data <= disp_ram(ram_rd_addr);
        end if;
    end process ram_proc;

    --! Mux to get bcd digits of data ports for saving to ram
    temp_sgn <= "00101011" when i_bcd_temp_sign = '0' else "00101101"; --! 0:+, 1:-
    meas_data_proc : process (meas_data_idx)
    begin
        case meas_data_idx is
            when  0 => meas_data <= temp_sgn;
            when  1 => meas_data <= "0011" & i_bcd_temp(4*2 + 3 downto 4*2);
            when  2 => meas_data <= "0011" & i_bcd_temp(4*1 + 3 downto 4*1);
            when  3 => meas_data <= "0011" & i_bcd_temp(4*0 + 3 downto 4*0);

            when  4 => meas_data <= "0011" & i_bcd_pres(4*5 + 3 downto 4*5);
            when  5 => meas_data <= "0011" & i_bcd_pres(4*4 + 3 downto 4*4);
            when  6 => meas_data <= "0011" & i_bcd_pres(4*3 + 3 downto 4*3);
            when  7 => meas_data <= "0011" & i_bcd_pres(4*2 + 3 downto 4*2);
            when  8 => meas_data <= "0011" & i_bcd_pres(4*1 + 3 downto 4*1);
            when  9 => meas_data <= "0011" & i_bcd_pres(4*0 + 3 downto 4*0);

            when 10 => meas_data <= "0011" & i_bcd_hum(4*1 + 3 downto 4*1);
            when 11 => meas_data <= "0011" & i_bcd_hum(4*0 + 3 downto 4*0);

            when others =>
                meas_data <= (others => '0');

        end case;
    end process;

end architecture rtl;

