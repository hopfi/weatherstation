library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
library gen;
library wstat;


entity top_module is
    port(
        clk12m      : in  std_logic;
        usr_btn     : in  std_logic;
        buttons     : in  std_logic_VECTOR(7 downto 0);
        led         : out std_logic_VECTOR(7 downto 0) := (others => '0');
        rs          : out std_logic;
        rw          : out std_logic;
        e           : out std_logic;
        data        : out std_logic_VECTOR(7 downto 0);
        sensor_sda  : inout std_logic;
        sensor_scl  : inout std_logic
        --lcd_sda                : inout std_logic;
        --lcd_scl                : inout std_logic
    );
end entity top_module;
 
architecture struct of top_module is

    signal locked    : std_logic;
    signal sys_clk   : std_logic;
    signal sys_rst   : std_logic;
    signal sys_rst_n : std_logic;

    component sys_pll
    port (
        inclk0 : in std_logic;
        c0     : out std_logic;
        locked : out std_logic
    );
    end component;

    component dbg_signaltap_01 is
    port (
        acq_clk        : in std_logic                     := 'X';             -- clk
        acq_data_in    : in std_logic_vector(23 downto 0) := (others => 'X'); -- acq_data_in
        acq_trigger_in : in std_logic_vector(15 downto 0) := (others => 'X')  -- acq_trigger_in
    );
    end component dbg_signaltap_01;

    constant i2c_input_clk : integer range 0 to 100000000 := 10000000;
    constant i2c_bus_clk   : integer range 0 to 100000000 := 500000;
    constant bin_width     : positive range 1 to 64 := 21;
    constant bcd_width     : positive range 1 to 64 := 10;
    
    signal counter : unsigned(31 downto 0) := (others => '0');
    
    signal lcd_enable : std_logic;
    signal lcd_bus    : std_logic_VECTOR(9 DOWNTO 0);
    signal lcd_busy   : std_logic;
    
    signal sensor_ena       : std_logic;
    signal sensor_addr      : std_logic_vector(6 downto 0);
    signal sensor_rw        : std_logic;
    signal sensor_data_wr   : std_logic_vector(7 downto 0);
    signal sensor_busy      : std_logic;
    signal sensor_data_rd   : std_logic_vector(7 downto 0);
    signal sensor_ack_error : std_logic;

    signal start_meas     : std_logic;
    signal bin_data_temp  : std_logic_vector(20 downto 0);
    signal bin_data_hum   : std_logic_vector(20 downto 0);
    signal bin_data_pres  : std_logic_vector(20 downto 0);
    signal bin_data_valid : std_logic;

    signal cnv            : std_logic;
    signal bin_data       : std_logic_vector(20 downto 0);
    signal bcd_data       : std_logic_Vector(20 downto 0) := (others => '0');
    signal bcd_data_valid : std_logic;
    
    signal test : std_logic_vector(39 downto 0) := (others => '0');
    
    signal dbg_ack_data    : std_logic_vector(23 downto 0);
    signal dbg_ack_trigger : std_logic_vector(15 downto 0);

begin

    sys_pll_inst : sys_pll 
    port map (
        inclk0 => clk12m,
        c0     => sys_clk,
        locked => locked
    );
    sys_rst <= locked;
    sys_rst_n <= not locked;
    
    ----instantiate the lcd controller
    --lcd_driver_inst : entity gen.lcd_driver(controller)
    --port map(
    --    clk        => sys_clk,
    --    reset_n    => '1',
    --    lcd_enable => lcd_enable,
    --    lcd_bus    => lcd_bus,
    --    busy       => lcd_busy,
    --    rw         => rw,
    --    rs         => rs,
    --    e          => e,
    --    lcd_data   => data
    --);
    --
    --lcd_ctrl_inst : entity wstat.lcd_ctrl(rtl)
    --port map(
    --    clk            => sys_clk,
    --    reset_n        => '1',
    --    bcd_data       => test,
    --    bcd_data_valid => bcd_data_valid,
    --    lcd_bus        => lcd_bus,
    --    lcd_enable     => lcd_enable,
    --    lcd_busy       => lcd_busy
    --);
    --test(20 downto 0) <= bcd_data;
    
    i2c_sensor_inst : entity gen.i2c_master(logic)
    generic map (
        input_clk => i2c_input_clk,         --input clock speed from user logic in Hz
        bus_clk   => i2c_bus_clk            --speed the i2c bus (scl) will run at in Hz
    )
    port map (
        clk       => sys_clk,               --system clock
        reset_n   => sys_rst_n,             --active low reset
        ena       => sensor_ena,            --latch in command
        addr      => sensor_addr,           --address of target slave
        rw        => sensor_rw,             --'0' is write, '1' is read
        data_wr   => sensor_data_wr,        --data to write to slave
        busy      => sensor_busy,           --indicates transaction in progress
        data_rd   => sensor_data_rd,        --data read from slave
        ack_error => sensor_ack_error,      --flag if improper acknowledge from slave
        sda       => sensor_sda,            --serial data output of i2c bus
        scl       => sensor_scl
    );
    
    signaltap_inst : dbg_signaltap_01
    port map (
        acq_clk        => sys_clk,
        acq_data_in    => dbg_ack_data,
        acq_trigger_in => dbg_ack_trigger
    );
    dbg_ack_data <= x"00" & '0' & sensor_rw & sensor_addr & sensor_data_rd;
    dbg_ack_trigger <= x"000" & "00" & sensor_ena & sensor_busy;

    BME280_ctrl_inst : entity wstat.BME280_ctrl(rtl)
    port map (
        clk               => sys_clk,
        reset_n           => sys_rst,
        start_measurement => start_meas,      --: IN  std_logic;
        bin_data_temp     => bin_data_temp,   --: OUT std_logic_VECTOR(20 downto 0);
        bin_data_hum      => bin_data_hum,    --: OUT std_logic_VECTOR(20 downto 0);
        bin_data_pres     => bin_data_pres,   --: OUT std_logic_VECTOR(20 downto 0);
        bin_data_valid    => bin_data_valid,  --: OUT std_logic;    
        ena               => sensor_ena,      --: IN  std_logic;                   
        addr              => sensor_addr,     --: IN  std_logic_VECTOR(6 DOWNTO 0);
        rw                => sensor_rw,       --: IN  std_logic;                   
        data_wr           => sensor_data_wr,  --: IN  std_logic_VECTOR(7 DOWNTO 0);
        busy              => sensor_busy,     --: OUT std_logic;                   
        data_rd           => sensor_data_rd,  --: OUT std_logic_VECTOR(7 DOWNTO 0);
        ack_error         => sensor_acK_error --: IN  std_logic;    
    );
    --
    --bin2BDC_inst : entity gen.binary_to_BCD(rtl)
    --generic map (
    --    g_INPUT_WIDTH    => bin_width, 
    --    g_DECIMAL_DIGITS => bcd_width
    --)
    --port map (
    --    i_Clock  => sys_clk, 
    --    i_Start  => cnv, 
    --    i_Binary => bin_data, 
    --    o_BCD    => open,
    --    o_DV     => bcd_data_valid
    --);
    --
    --dataflow_master_inst : entity wstat.dataflow_master(rtl)
    --port map (
    --    clk      => sys_clk,
    --    reset_n  => '1'
    --);
    --
    --led(1) <= '0' when buttons(1) = '1' else '1';
    --led(2) <= '0' when buttons(2) = '1' else '1';
    --led(3) <= '0' when buttons(3) = '1' else '1';
    --led(4) <= '0' when buttons(4) = '1' else '1';
    --led(5) <= '0' when buttons(5) = '1' else '1';
    --led(6) <= '0' when buttons(6) = '1' else '1';
    --led(7) <= '0' when buttons(7) = '1' else '1';
    
end struct;