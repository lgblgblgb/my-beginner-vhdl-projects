-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity main_RAM is
	Port (
		clk:			in  std_logic;
		a:				in  std_logic_vector (16 downto 0);
		din:			in  std_logic_vector ( 7 downto 0);
		dout:			out std_logic_vector ( 7 downto 0);
		we_n:			in  std_logic
		--read2_clk:	in  std_logic;
		--read2_a:		in  std_logic_vector (14 downto 0);
		--read2_dout:	out std_logic_vector ( 7 downto 0)
	);
end main_RAM;

architecture rtl of main_RAM is
type ramarray_t is array(0 to 131071) of std_logic_vector(7 downto 0);
signal mem: ramarray_t;
--signal outreg: std_logic_vector(7 downto 0);
--signal outreg2: std_logic_vector(7 downto 0);
begin

	--dout <= outreg;
	--read2_dout <= outreg2;

	process (clk) begin
		if rising_edge(clk) then
			dout <= mem(to_integer(unsigned(a)));
		end if;
	end process;

	process (clk) begin
		if rising_edge(clk) then
			if we_n = '0' then
				mem(to_integer(unsigned(a))) <= din;
			end if;
		end if;
	end process;
	
	--process (read2_clk) begin
	--	if rising_edge(read2_clk) then
	--		outreg2 <= mem(conv_integer(read2_a));
	--	end if;
	--end process;

end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity shadow_RAM is
	port (
		-- read port
		read_clk:	in  std_logic;
		read_a:		in  std_logic_vector (14 downto 0);
		read_dout:	out std_logic_vector ( 7 downto 0);
		-- write port
		write_clk:  in  std_logic;
		write_a:    in  std_logic_vector (14 downto 0);
		write_din:  in  std_logic_vector ( 7 downto 0);
		we_n:       in  std_logic
	);
end shadow_RAM;

architecture rtl of shadow_RAM is
type ramarray_t is array(0 to 32767) of std_logic_vector(7 downto 0);
signal mem: ramarray_t;
begin
	process (read_clk) begin
		if rising_edge(read_clk) then
			read_dout <= mem(to_integer(unsigned(read_a)));
		end if;
	end process;
	process (write_clk) begin
		if rising_edge(write_clk) then
			if we_n = '0' then
				mem(to_integer(unsigned(write_a))) <= write_din;
			end if;
		end if;
	end process;
end rtl;
