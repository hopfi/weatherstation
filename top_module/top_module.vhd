library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
library gen;
library wstat;


entity top_module is
    port(
        input_clk   : in  std_logic;
        user_rst    : in  std_logic;
        sensor_sda  : inout std_logic;
        sensor_scl  : inout std_logic;
        en          : out std_logic;
        rw          : out std_logic;
        rs          : out std_logic;
        lcd_data    : inout std_logic_vector(7 downto 0)
    );
end entity top_module;
 
architecture struct of top_module is

    signal locked    : std_logic;
    signal sys_clk   : std_logic;
    signal sys_rst   : std_logic;
    signal sys_rst_n : std_logic;
    signal sys_rst_n_temp : std_logic;

    component sys_pll
    port (
        inclk0 : in std_logic;
        c0     : out std_logic;
        locked : out std_logic
    );
    end component;

    constant C_SYS_CLK_FREQ : integer range 0 to 100000000 := 10000000;
    constant C_I2C_CLK_FREQ : integer range 0 to 100000000 := 400000;
    constant C_HD44780_CLK_FREQ : integer := 400000;
    constant bin_width     : positive range 1 to 64 := 21;
    constant bcd_width     : positive range 1 to 64 := 10;
    
    signal counter : unsigned(31 downto 0) := (others => '0');
    
    signal lcd_enable : std_logic;
    signal lcd_bus    : std_logic_VECTOR(9 DOWNTO 0);
    signal lcd_busy   : std_logic;
    
    signal scl_out          : std_logic;
    signal scl_in           : std_logic;
    signal scl_tri          : std_logic;
    signal sda_out          : std_logic;
    signal sda_in           : std_logic;
    signal sda_tri          : std_logic;
    signal I2CMaster_BME280ctrl_sensor_en        : std_logic;
    signal I2CMaster_BME280ctrl_sensor_busy      : std_logic;
    signal I2CMaster_BME280ctrl_sensor_ack_error : std_logic;
    signal I2CMaster_BME280ctrl_sensor_stop_mode : std_logic_vector(1 downto 0);
    signal I2CMaster_BME280ctrl_sensor_wr_data   : std_logic_vector(7 downto 0);
    signal I2CMaster_BME280ctrl_sensor_wr_en     : std_logic;
    signal I2CMaster_BME280ctrl_sensor_sending   : std_logic;
    signal I2CMaster_BME280ctrl_sensor_rd_data   : std_logic_vector(7 downto 0);
    signal I2CMaster_BME280ctrl_sensor_rd_en     : std_logic;
    signal I2CMaster_BME280ctrl_sensor_receiving : std_logic;

    signal BME280ctrl_BME280comp_start_meas   : std_logic;
    signal BME280ctrl_DataConv_bin_data_temp  : std_logic_vector(19 downto 0) := (others => '0');
    signal BME280ctrl_DataConv_bin_data_pres  : std_logic_vector(19 downto 0) := (others => '0');
    signal BME280ctrl_DataConv_bin_data_hum   : std_logic_vector(15 downto 0) := (others => '0');
    signal BME280ctrl_DataConv_bin_data_valid : std_logic := '0';

    signal BIN2BCD_LCDctrl_bcd_temp  : std_logic_vector(7 downto 0);
    signal BIN2BCD_LCDctrl_bcd_pres  : std_logic_vector(7 downto 0);
    signal BIN2BCD_LCDctrl_bcd_hum   : std_logic_vector(7 downto 0);
    signal BIN2BCD_LCDctrl_bcd_valid : std_logic;
    signal BIN2BCD_LCDctrl_bcd_busy  : std_logic;
    signal LCDCtrl_DISP_lcd_start : std_logic_vector(7 downto 0);
    signal LCDCtrl_DISP_lcd_busy  : std_logic_vector(7 downto 0);
    signal LCDCtrl_DISP_lcd_rw    : std_logic_vector(7 downto 0);
    signal LCDCtrl_DISP_lcd_rs    : std_logic_vector(7 downto 0);
    signal LCDCtrl_DISP_lcd_data  : std_logic_vector(7 downto 0);
    signal lcd_data_out  : std_logic_vector(7 downto 0);
    signal lcd_data_in   : std_logic_vector(7 downto 0);
    signal lcd_data_tri  : std_logic_vector(7 downto 0);

    signal LCDCtrl_DISPdrv_start     : std_logic;
    signal LCDCtrl_DISPdrv_busy      : std_logic;
    signal LCDCtrl_DISPdrv_disp_rw   : std_logic;
    signal LCDCtrl_DISPdrv_disp_rs   : std_logic;
    signal LCDCtrl_DISPdrv_disp_data : std_logic_vector(7 downto 0);

    signal DataConv_LCDctrl_bcd_temp_sgn : std_logic;
    signal DataConv_LCDctrl_bcd_temp     : std_logic_vector(11 downto 0);
    signal DataConv_LCDctrl_bcd_pres     : std_logic_vector(23 downto 0);
    signal DataConv_LCDctrl_bcd_hum      : std_logic_vector(7 downto 0);
    signal DataConv_LCDctrl_bcd_valid    : std_logic;
    signal DataConv_LCDctrl_bcd_busy     : std_logic;

    constant C_START_THRESHOLD : unsigned(31 downto 0) := x"000E_BC20"; --update every second
    signal timer : unsigned(31 downto 0);

begin

    sys_pll_inst : sys_pll 
    port map (
        inclk0 => input_clk,
        c0     => sys_clk,
        locked => locked
    );
    sys_rst <= locked;
    sys_rst_n_temp <= not locked;
    sys_rst_n <= sys_rst_n_temp or not user_rst;

    process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if sys_rst_n = '1' then
                timer <= (others => '0');
                BME280ctrl_BME280comp_start_meas <= '0';
            else
                BME280ctrl_BME280comp_start_meas <= '0';

                if timer = C_START_THRESHOLD then
                    BME280ctrl_BME280comp_start_meas <= '1';
                    timer <= (others => '0');
                else
                    timer <= timer + 1;
                end if;
            end if;
        end if;
    end process;


    i2c_sensor_inst : entity gen.i2c_master(rtl)
    generic map (
        G_SYSTEM_CLOCK => C_SYS_CLK_FREQ, --input clock speed from user logic in Hz
        G_BAUD_RATE    => C_I2C_CLK_FREQ  --speed the i2c bus (scl) will run at in Hz
    )
    port map (
        i_sys_clk   => sys_clk,
        i_sys_rst   => sys_rst_n,
        o_scl       => scl_out,
        i_scl       => scl_in,
        t_scl       => scl_tri,
        o_sda       => sda_out,
        i_sda       => sda_in,
        t_sda       => sda_tri,
        i_en        => I2CMaster_BME280ctrl_sensor_en,
        o_busy      => I2CMaster_BME280ctrl_sensor_busy,
        o_ack_error => I2CMaster_BME280ctrl_sensor_ack_error,
        i_stop_mode => I2CMaster_BME280ctrl_sensor_stop_mode,
        i_wr_data   => I2CMaster_BME280ctrl_sensor_wr_data,
        i_wr_en     => I2CMaster_BME280ctrl_sensor_wr_en,
        o_sending   => I2CMaster_BME280ctrl_sensor_sending,
        o_rd_data   => I2CMaster_BME280ctrl_sensor_rd_data,
        i_rd_en     => I2CMaster_BME280ctrl_sensor_rd_en,
        o_receiving => I2CMaster_BME280ctrl_sensor_receiving
    );
    sensor_sda <= sda_out when sda_tri = '0' else 'Z';
    sda_in <= sensor_sda;
    sensor_scl <= scl_out when scl_tri = '0' else 'Z';
    scl_in <= sensor_scl;

    BME280_ctrl_inst : entity wstat.BME280_ctrl(rtl)
    port map (
        i_clk               => sys_clk,
        i_reset             => sys_rst_n,
        i_start_measurement => BME280ctrl_BME280comp_start_meas,
        o_bin_data_temp     => BME280ctrl_DataConv_bin_data_temp,
        o_bin_data_pres     => open, --BME280ctrl_DataConv_bin_data_pres,
        o_bin_data_hum      => BME280ctrl_DataConv_bin_data_hum,
        o_bin_data_valid    => BME280ctrl_DataConv_bin_data_valid,
        o_en                => I2CMaster_BME280ctrl_sensor_en,
        i_busy              => I2CMaster_BME280ctrl_sensor_busy,
        i_ack_error         => I2CMaster_BME280ctrl_sensor_ack_error,
        o_stop_mode         => I2CMaster_BME280ctrl_sensor_stop_mode,
        o_wr_data           => I2CMaster_BME280ctrl_sensor_wr_data,
        o_wr_en             => I2CMaster_BME280ctrl_sensor_wr_en,
        i_sending           => I2CMaster_BME280ctrl_sensor_sending,
        i_rd_data           => I2CMaster_BME280ctrl_sensor_rd_data,
        o_rd_en             => I2CMaster_BME280ctrl_sensor_rd_en,
        i_receiving         => I2CMaster_BME280ctrl_sensor_receiving
    );

    data_conv : entity wstat.data_converter(struct)
    port map (
        i_clk            => sys_clk,
        i_rst            => sys_rst_n,
        i_bin_data_temp  => BME280ctrl_DataConv_bin_data_temp,
        i_bin_data_pres  => BME280ctrl_DataConv_bin_data_pres,
        i_bin_data_hum   => BME280ctrl_DataConv_bin_data_hum,
        i_bin_data_valid => BME280ctrl_DataConv_bin_data_valid,
        o_bcd_temp_sgn   => DataConv_LCDctrl_bcd_temp_sgn,
        o_bcd_temp       => DataConv_LCDctrl_bcd_temp,
        o_bcd_pres       => open, --DataConv_LCDctrl_bcd_pres,
        o_bcd_hum        => DataConv_LCDctrl_bcd_hum,
        o_bcd_valid      => DataConv_LCDctrl_bcd_valid,
        i_bcd_busy       => DataConv_LCDctrl_bcd_busy
    );

    lcd_ctrl_inst : entity wstat.lcd_ctrl(rtl)
    generic map (
        G_DISP_RAM_FILE => "X:/Daniel/dev_docs/fpga/vhdl/weatherstation/lcd_ctrl/disp_ram_content.mif"
    )
    port map(
        i_clk           => sys_clk,
        i_rst           => sys_rst_n,
        i_bcd_temp_sign => DataConv_LCDctrl_bcd_temp_sgn,
        i_bcd_temp      => DataConv_LCDctrl_bcd_temp,
        i_bcd_pres      => DataConv_LCDctrl_bcd_pres,
        i_bcd_hum       => DataConv_LCDctrl_bcd_hum,
        i_bcd_valid     => DataConv_LCDctrl_bcd_valid,
        o_bcd_busy      => DataConv_LCDctrl_bcd_busy,
        o_lcd_start     => LCDCtrl_DISPdrv_start,
        i_lcd_busy      => LCDCtrl_DISPdrv_busy,
        o_lcd_rw        => LCDCtrl_DISPdrv_disp_rw,
        o_lcd_rs        => LCDCtrl_DISPdrv_disp_rs,
        o_lcd_data      => LCDCtrl_DISPdrv_disp_data
    );

    display_driver : entity gen.hd44780_driver(rtl)
    generic map(
        G_SYSTEM_CLOCK => C_SYS_CLK_FREQ,
        G_BAUD_RATE    => C_HD44780_CLK_FREQ
    )
    port map(
        i_sys_clk   => sys_clk,
        i_sys_rst   => sys_rst_n,
        i_start     => LCDCtrl_DISPdrv_start,
        o_busy      => LCDCtrl_DISPdrv_busy,
        i_disp_rw   => LCDCtrl_DISPdrv_disp_rw,
        i_disp_rs   => LCDCtrl_DISPdrv_disp_rs,
        i_disp_data => LCDCtrl_DISPdrv_disp_data,
        o_en        => en,
        o_rw        => rw,
        o_rs        => rs,
        o_data      => lcd_data_out,
        i_data      => lcd_data_in,
        t_data      => lcd_data_tri
    );
    lcd_data <= lcd_data_out when lcd_data_tri = x"00" else x"ZZ";
    lcd_data_in <= lcd_data;

end struct;