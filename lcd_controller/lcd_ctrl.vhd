library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity lcd_ctrl is
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        bcd_data       : in  std_logic_vector(39 downto 0);
        bcd_data_valid : in  std_logic;
        lcd_bus        : out std_logic_vector(9 downto 0);
        lcd_enable     : out std_logic;
        lcd_busy       : in  std_logic
    );
end entity lcd_ctrl;

architecture rtl of lcd_ctrl is
    
    signal only_once : std_logic := '0';
    
begin

    process(clk)
        variable char  :  integer range 0 to 20 := 0;
    begin
        if(rising_edge(clk)) then
            if bcd_data_valid = '1' and only_once = '0' then
                only_once <= '1';
                char := 0;
            end if;

            if(lcd_busy = '0' and lcd_enable = '0') then
                lcd_enable <= '1';
                if(char <= 20) then
                    char := char + 1;
                end if;
                case char is
                    when  0 => lcd_bus <= "00" & "00000001";
                    when  1 => lcd_bus <= "00" & "10000001";
                    
                    when  2 => lcd_bus <= "10" & "01010100";
                    when  3 => lcd_bus <= "10" & "01100001";
                    when  4 => lcd_bus <= "10" & "01110100";
                    when  5 => lcd_bus <= "10" & "01101001";

                    when  6 => lcd_bus <= "00" & "00000010";
                    when  7 => lcd_bus <= "00" & "10000001";

                    when  8 => lcd_bus <= "10" & "01010100";
                    when  9 => lcd_bus <= "10" & "01101111";
                    when 10 => lcd_bus <= "10" & "01101111";

                    when 11 => lcd_bus <= "00" & "11000001";

                    when 12 => lcd_bus <= "10" & "01000011";
                    when 13 => lcd_bus <= "10" & "01110101";
                    when 14 => lcd_bus <= "10" & "01110100";
                    when 15 => lcd_bus <= "10" & "01101001";
                    when 16 => lcd_bus <= "10" & "01100101";
                    
                    when 17 => 
                        lcd_enable <= '0';
                        only_once <= '0';
                        
                    when others => lcd_enable <= '0';
                end case;
            else
                lcd_enable <= '0';
            end if;
        end if;

    end process;

end architecture rtl;

