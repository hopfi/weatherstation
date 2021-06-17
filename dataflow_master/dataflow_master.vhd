library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity dataflow_master is
	port (
		clk						: IN  STD_LOGIC;
		reset_n					: IN  STD_LOGIC              	
	);
end entity dataflow_master;
 
architecture rtl of dataflow_master is
	
	
	
begin
	
	process(clk)
	begin
		if rising_edge(clk) then
			if reset_n = '1' then
			
			else
			
			end if;
		end if;
	end process;
	
	
end architecture rtl;

