-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity shadow_RAM is
	Port (
		write_clk:	in  std_logic;
		write_addr:	in  std_logic_vector (14 downto 0);
		write_data:	in  std_logic_vector ( 7 downto 0);
		write_enable_n:	in  std_logic;
		read_clk:	in  std_logic;
		read_addr:	in  std_logic_vector (14 downto 0);
		read_data:	out std_logic_vector ( 7 downto 0)
	);
end shadow_RAM;

architecture rtl of shadow_RAM is
type ramarray is array(0 to 32767) of std_logic_vector(7 downto 0);
signal mem: ramarray;
begin

	process (read_clk) begin
		if rising_edge(read_clk) then
			read_data <= mem(conv_integer(read_addr));
		end if;
	end process;

	process (write_clk) begin
		if rising_edge(write_clk) then
			if write_enable_n = '0' then
				mem(conv_integer(write_addr)) <= write_data;
			end if;
		end if;
	end process;

end rtl;
