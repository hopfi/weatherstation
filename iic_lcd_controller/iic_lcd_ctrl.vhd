library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

 
entity iic_lcd_ctrl is
	Port(
		clk       :	in std_logic; 
		reset_n   :	in std_logic;
		start		 : in std_logic;
		ena       :	out std_logic; 
		addr      :	out std_logic_vector(6 downto 0);
		rw        :	out std_logic; 
		data_wr   :	out std_logic_vector(7 downto 0);
		busy      :	in std_logic; 
		data_rd   :	in std_logic_vector(7 downto 0);
		ack_error :	in std_logic
	);
end entity;
 
 
architecture behavioural of iic_lcd_ctrl is
	
	type lcd_fsm is (init, idle, wr_display_st1, wr_display_st2, wr_display_st3, wr_display_st4, wr_display_st5, wait_state);
	signal lcd_state : lcd_fsm := init;
	signal next_state : lcd_fsm := init;
	
	signal counter : unsigned(31 downto 0) := (others => '0');

begin

	process(clk)
	begin
		if rising_edge(clk) then
			if reset_n = '0' then
				lcd_state <= init;
			else
				ena <= '0';
				
				case lcd_state is
					when init =>
						lcd_state <= idle;
						
					when idle =>
						if start = '0' then
							lcd_state <= wr_display_st1;
						end if;
						
					when wr_display_st1 =>
						addr 			<= "1000000";
						rw 			<= '0';
						data_wr 		<= x"03";
						ena			<= '1';
						if busy = '0' then
							next_state 	<= wr_display_st2;
							lcd_state 	<= wait_state;
						end if;
						
					when wr_display_st2 =>
						addr 			<= "1000000";
						rw 			<= '0';
						data_wr 		<= x"03";
						ena			<= '1';
						if busy = '0' then
							next_state 	<= wr_display_st3;
							lcd_state 	<= wait_state;
						end if;
					
					when wr_display_st3 =>
						addr 			<= "1000000";
						rw 			<= '0';
						data_wr 		<= x"03";
						ena			<= '1';
						if busy = '0' then
							next_state 	<= wr_display_st4;
							lcd_state 	<= wait_state;
						end if;
					
					when wr_display_st4 =>
						addr 			<= "1000000";
						rw 			<= '0';
						data_wr 		<= x"02";
						ena			<= '1';
						if busy = '0' then
							next_state 	<= wr_display_st5;
							lcd_state 	<= wait_state;
						end if;
					
					when wr_display_st5 =>
						addr 			<= "1000000";
						rw 			<= '0';
						data_wr 		<= x"02";
						ena			<= '1';
						if busy = '0' then
							next_state 	<= idle;
							lcd_state 	<= wait_state;
						end if;
						
					
					when wait_state =>
						counter <= counter + 1;
						if counter = 31 then
							counter <= (others => '0');
							lcd_state <= next_state;
						end if;
					
					
					when others => null;
				end case;
				
			end if;
		end if;
	end process;

	
end behavioural;