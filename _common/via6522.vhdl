-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity via6522 is
	Port (
		clk:	in  std_logic;		
		a:		in  std_logic_vector (3 downto 0);
		din:	in  std_logic_vector (7 downto 0);
		dout: out std_logic_vector (7 downto 0);
		rw_n:	in  std_logic;
		cs_n: in  std_logic;
		res_n:in  std_logic
	);
end via6522;

architecture rtl of via6522 is

type regarray is array(0 to 15) of std_logic_vector(7 downto 0);
signal reg: regarray;

begin
	process (clk, cs_n, rw_n) begin
		if rising_edge(clk) and cs_n = '0' and rw_n = '1' then
			--dout <= reg(conv_integer(a));
			dout <= x"FF";
		end if;
	end process;
	process (clk, cs_n, rw_n) begin
		if rising_edge(clk) and cs_n = '0' and rw_n = '0' then
			reg(conv_integer(a)) <= din;
		end if;
	end process;
end rtl;
