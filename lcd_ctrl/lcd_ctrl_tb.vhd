----------------------------------------------------------------------------------
-- Name: Daniel Hopfinger
-- Date: 31.07.2021
-- Module: lcd_ctrl_tb.vhd
-- Description:
-- Testbench to lcd_ctrl_tb module.
--
-- History:
-- Version  | Date       | Information
-- ----------------------------------------
--  0.0.1   | 31.07.2021 | Initial version.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

library wstat;

entity lcd_ctrl_tb is
end lcd_ctrl_tb;

architecture sim of lcd_ctrl_tb is

    --! Timing constants that adjust speed of hd44780 control signal speed
    constant C_CLK_PERIOD : time := 10 ns;
    signal clk            : std_logic := '1';
    signal rst            : std_logic := '1';

    --! Lower and upper index of measurement data placeholder in ram
    constant C_TEMP_LOW  : integer := 7;
    constant C_TEMP_HIGH : integer := 11;
    constant C_PRES_LOW  : integer := 21;
    constant C_PRES_HIGH : integer := 26;
    constant C_HUM_LOW   : integer := 36;
    constant C_HUM_HIGH  : integer := 37;

    --! DUT signals
    signal bcd_temp_sign : std_logic := '0';
    signal bcd_temp      : std_logic_vector(11 downto 0);
    signal bcd_pres      : std_logic_vector(23 downto 0);
    signal bcd_hum       : std_logic_vector(7 downto 0);
    signal bcd_valid     : std_logic;
    signal bcd_busy      : std_logic;
    signal lcd_start     : std_logic;
    signal lcd_busy      : std_logic;
    signal lcd_rw        : std_logic;
    signal lcd_rs        : std_logic;
    signal lcd_data      : std_logic_vector(7 downto 0);

    --! Stimulus input and output data
    file ram_content     : text; --! File IO for ram
    file bcd_input_file  : text; --! File IO for bcd input values
    file lcd_output_file : text; --! File IO for lcd output values

    signal j            : integer;                      --! Counter to decide when to replace measurement placeholder in ram with stimulus input for measurement data
    signal act_dut_data : std_logic_vector(9 downto 0); --! Actual DUT output, combines [RW | RS | DATA]
    signal exp_dut_data : std_logic_vector(9 downto 0); --! Expected DUT output, combines [RW | RS | DATA]
    signal init_done    : std_logic := '0';             --! Signal indicating end of initialisation state

begin

    clk <= not clk after C_CLK_PERIOD / 2;
    rst <= '0' after 10 * C_CLK_PERIOD;

    --! Process to provide stimulus for DUT
    master_proc : process
        variable var_line : line;
        variable var_char : character;
        variable var_temp : std_logic_vector(11 downto 0);
        variable var_pres : std_logic_vector(23 downto 0);
        variable var_hum  : std_logic_vector(7 downto 0);
    begin

        if rst = '1' then
            bcd_valid <= '0';
            wait until rst = '0';
        end if;
        wait for 50 * C_CLK_PERIOD;
        wait until rising_edge(clk);

        wait until init_done = '1';

        file_open(bcd_input_file, "X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/bcd_input.txt",  read_mode);
        readline(bcd_input_file, var_line); -- read in header line

        --! Iterate through bcd_input.txt file
        while not endfile(bcd_input_file) loop
            readline(bcd_input_file, var_line);
            read(var_line, var_temp);       -- read in temp data
            read(var_line, var_char);       -- read in comma
            read(var_line, var_char);       -- read in space
            read(var_line, var_pres);       -- read in pressure data
            read(var_line, var_char);       -- read in comma
            read(var_line, var_char);       -- read in space
            read(var_line, var_hum);        -- read in humidity data
            bcd_temp  <= var_temp;
            bcd_pres  <= var_pres;
            bcd_hum   <= var_hum;
            bcd_valid <= '1';
            wait for 1 * C_CLK_PERIOD;
            bcd_valid <= '0';

            wait for 10 * C_CLK_PERIOD;
            wait until falling_edge(bcd_busy);
            wait for 10 * C_CLK_PERIOD;
        end loop;

        wait for 100 * C_CLK_PERIOD;

        std.env.stop(0);

    end process master_proc;

    --! DUT
    lcd_ctrl : entity wstat.lcd_ctrl(rtl)
    generic map (
        G_DISP_RAM_FILE => "X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/disp_ram_content.mif"
    )
    port map (
        i_clk           => clk,
        i_rst           => rst,
        i_bcd_temp_sign => bcd_temp_sign,
        i_bcd_temp      => bcd_temp,
        i_bcd_pres      => bcd_pres,
        i_bcd_hum       => bcd_hum,
        i_bcd_valid     => bcd_valid,
        o_bcd_busy      => bcd_busy,
        o_lcd_start     => lcd_start,
        i_lcd_busy      => lcd_busy,
        o_lcd_rw        => lcd_rw,
        o_lcd_rs        => lcd_rs,
        o_lcd_data      => lcd_data
    );

    act_dut_data <= lcd_rs & lcd_rw & lcd_data;
    --! Process to evaluate output of DUT
    slave_proc : process
        variable var_line_ram : line;
        variable var_line_lcd : line;
        variable var_char     : character;
        variable var_ram_data : std_logic_vector(9 downto 0);
        variable var_lcd_data : std_logic_vector(7 downto 0);
    begin
        if rst = '1' then
            wait until rst = '0';
        end if;
        wait for 1 * C_CLK_PERIOD;
        wait until rising_edge(clk);

        --! Check initialisation state
        wait for 10 * C_CLK_PERIOD;

        for i in 0 to 2 loop
            lcd_busy <= '1';
            wait for 10 * C_CLK_PERIOD;
            lcd_busy <= '0';
            wait for 1 * C_CLK_PERIOD;

            if i = 0 then
                exp_dut_data <= "0000111100";
            elsif i = 1 then
                exp_dut_data <= "0000000110";
            elsif i = 2 then
                exp_dut_data <= "0000001100";
            end if;

            --! Check if data output is correct
            assert act_dut_data = exp_dut_data
            report "Data output does not match expected content of ram or measurement data" & lf &
                    "Expected: " & integer'image(to_integer(unsigned(exp_dut_data))) & lf &
                    "Actual: " & integer'image(to_integer(unsigned(act_dut_data)))
            severity failure;

        end loop;
        wait for 100 * C_CLK_PERIOD;
        init_done <= '1';
        wait for 1 * C_CLK_PERIOD;


        --! Read and discard header lines
        file_open(lcd_output_file, "X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/lcd_output.txt",  read_mode);
        readline(lcd_output_file, var_line_lcd); -- read in header line

        --! Check normal operation
        while not endfile(lcd_output_file) loop

            --! Read and discard header lines
            --file_open(ram_content, "./disp_ram_content.mif",  read_mode);
            file_open(ram_content, "X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/disp_ram_content.txt",  read_mode);
            readline(lcd_output_file, var_line_lcd);
            j <= 0;

            while not endfile(ram_content) loop
                wait until rising_edge(lcd_start);
                lcd_busy <= '1';

                --! Read unused parts of line and get actual data
                readline(ram_content, var_line_ram);
                read(var_line_ram, var_ram_data);       -- read in the actual data

                --! Ignore data from ram and use lcd_output.txt data to check for correctness.
                if (j >= C_TEMP_LOW and j <= C_TEMP_HIGH) or (j >= C_PRES_LOW and j <= C_PRES_HIGH) or (j >= C_HUM_LOW and j <= C_HUM_HIGH) then
                    read(var_line_lcd, var_lcd_data);   -- read in the actual data
                    read(var_line_lcd, var_char);       -- read in the comma
                    read(var_line_lcd, var_char);       -- read in the space
                    exp_dut_data <= "10" & var_lcd_data;
                else
                    exp_dut_data <= var_ram_data(9 downto 0);
                end if;

                wait for 1 * C_CLK_PERIOD;

                --! Check if data output is correct
                assert act_dut_data = exp_dut_data
                report "Data output does not match expected content of ram or measurement data" & lf &
                       "Expected: " & integer'image(to_integer(unsigned(act_dut_data))) & lf &
                       "Actual: " & integer'image(to_integer(unsigned(exp_dut_data)))
                severity failure;

                wait for 10 * C_CLK_PERIOD;
                lcd_busy <= '0';
                wait for 1 * C_CLK_PERIOD;

                j <= j + 1;

            end loop;
            file_close(ram_content);
        end loop;

        wait for 1000 * C_CLK_PERIOD;

    end process slave_proc;

end sim;
