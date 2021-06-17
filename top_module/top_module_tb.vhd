library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_unsigned.all;

library std;
use std.textio.all;

library wstat;


entity top_module_tb is
end entity top_module_tb;

architecture sim of top_module_tb is

    constant C_CLOCK_PERIOD : time := 83 ns;
    signal in_clk : std_logic := '1';
    signal sys_rst : std_logic := '1';

    signal e       : std_logic;
    signal rw      : std_logic;
    signal rs      : std_logic;
    signal led     : std_logic_vector(7 downto 0) := (others => '0');
    signal usr_btn : std_logic;
    signal data    : std_logic_vector (7 downto 0);
    signal clk12m  : std_logic;
    signal buttons : std_logic_vector(7 downto 0);

begin

    in_clk <= not in_clk after C_CLOCK_PERIOD / 2;
    sys_rst <= transport '0' after 1000 ns;


    dut : entity wstat.top_module(struct)
    port map 
    ( 
        e       => e,
        rw      => rw,
        rs      => rs,
        LED     => LED,
        USR_BTN => USR_BTN,
        data    => data,
        CLK12M  => in_clk,
        BUTTONS => BUTTONS
    );



    -- "Constant Pattern"
    -- Start Time = 0 ns, End Time = 1 ms, Period = 0 ns
    process
    begin
        buttons <= "00000000";
        wait for 1 us;
        
        -- dumped values till 1 us
        wait;
    end process;


end sim;