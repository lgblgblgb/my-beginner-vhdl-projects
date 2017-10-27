-- Trying to implement a Commodore VIC-20
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity colour_RAM is
	Port (
		clk:	in  std_logic;
		a:		in  std_logic_vector (9 downto 0);
		din:	in  std_logic_vector (3 downto 0);
		dout: out std_logic_vector (3 downto 0);
		we_n:	in  std_logic
	);
end colour_RAM;

architecture rtl of colour_RAM is
type ramarray is array(0 to 1023) of std_logic_vector(3 downto 0);
signal mem: ramarray;
begin

	process (clk) begin
		if rising_edge(clk) then
			dout <= mem(conv_integer(a));
		end if;
	end process;

	process (clk) begin
		if rising_edge(clk) then
			if we_n = '0' then
				mem(conv_integer(a)) <= din;
			end if;
		end if;
	end process;

end rtl;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity main_RAM is
	Port (
		clk:	in  std_logic;
		a:		in  std_logic_vector (14 downto 0);
		din:	in  std_logic_vector ( 7 downto 0);
		dout: out std_logic_vector ( 7 downto 0);
		we_n:	in  std_logic
	);
end main_RAM;

architecture rtl of main_RAM is
type ramarray is array(0 to 32767) of std_logic_vector(7 downto 0);
signal mem: ramarray;
begin

	process (clk) begin
		if rising_edge(clk) then
			dout <= mem(conv_integer(a));
		end if;
	end process;

	process (clk) begin
		if rising_edge(clk) then
			if we_n='0' then
				mem(conv_integer(a)) <= din;
			end if;
		end if;
	end process;

end rtl;
