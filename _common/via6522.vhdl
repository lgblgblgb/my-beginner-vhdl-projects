-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity via6522 is
	Port (
		-- Note! I don't use the standard scheme to have Phi2 input as "chip select" and R/Wn line
		-- but wr_n and rd_n are combined signals of Phi2+read and Phi2+write from CPU!
		-- Still, we need clock input for counters, etc
		clk:	in  std_logic;		
		a:		in  std_logic_vector (3 downto 0);
		din:	in  std_logic_vector (7 downto 0);
		dout: out std_logic_vector (7 downto 0);
		wr_n:	in  std_logic;
		rd_n: in  std_logic
	);
end via6522;

architecture rtl of via6522 is

type regarray is array(0 to 15) of std_logic_vector(7 downto 0);
signal reg: regarray;

begin
	process (rd_n) begin
		if falling_edge(rd_n) then
			dout <= reg(conv_integer(a));
		end if;
	end process;
	process (wr_n) begin
		if falling_edge(wr_n) then
			reg(conv_integer(a)) <= din;
		end if;
	end process;
end rtl;
