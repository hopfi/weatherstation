library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity bme280_ctrl is
    port (
        i_sys_clk           : in  std_logic;
        i_sys_rst           : in  std_logic;
        
        i_start_measurement : in  std_logic;
        
        o_bin_data_temp     : out std_logic_vector(20 downto 0);
        o_bin_data_hum      : out std_logic_vector(20 downto 0);
        o_bin_data_pres     : out std_logic_vector(20 downto 0);
        o_bin_data_valid    : out std_logic;

        o_ena               : out std_logic;
        o_addr              : out std_logic_vector(6 downto 0);
        o_rw                : out std_logic;
        i_data_wr           : in  std_logic_vector(7 downto 0);
        i_busy              : in  std_logic;
        i_data_rd           : in  std_logic_vector(7 downto 0);
        i_ack_error         : in  std_logic
    );
end entity bme280_ctrl;

architecture rtl of bme280_ctrl is
    
    signal rw_cmd  : std_logic;
    signal rw_ena  : std_logic;
    signal rw_busy : std_logic;
    signal rd_addr : std_logic_vector(6 downto 0);
    signal rd_data : std_logic_vector(7 downto 0);
    
    signal dbg_start_meas : std_logic;
    signal dbg_cnt : unsigned(15 downto 0);


begin
    

    process(i_sys_clk)
    begin
        if rising_edge(i_sys_clk) then
            if i_sys_rst = '1' then
                dbg_cnt <= (others => '0');
            else
                dbg_cnt <= dbg_cnt + 1;

                dbg_start_meas <= '0';

                if dbg_cnt = x"ffff" then
                    dbg_start_meas <= '1';
                end if;

            end if;
        end if;
    end process;


    process(i_sys_clk)
    begin
        if rising_edge(i_sys_clk) then
            if i_sys_rst = '1' then

            else
                rw_ena <= '0';

                rw_busy <= i_busy;

                if dbg_start_meas = '1' then
                    rw_cmd <= '1';
                    rd_addr <= x"dead";
                    rw_ena <= '1';
                end if;


            end if;
        end if;
    end process;
    
    
end architecture rtl;

