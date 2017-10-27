-- Trying to implement a Commodore VIC-20
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity vic6561 is
	Port (
		-- Using separated "for CPU" bus and "VIC issued memory access" bus for cleaner implementation
		-- Also note: real VIC-I would use address bus for "chip select" as well. However here
		-- we use reg_wr_n and reg_rd_n inputs to have combined CPU read/write valid signals.
		-- Also, VIC-I does many clock magic (it has two-phase clock signal input, output, and also memory clock optinally)
		-- but again, we left that for the top module to implement.
		clk:	    in  std_logic;
		reg_a:	 in  std_logic_vector (3 downto 0);
		reg_din:	 in  std_logic_vector (7 downto 0);
		reg_dout: out std_logic_vector (7 downto 0);
		reg_wr_n: in  std_logic; -- this is combined clock, ie '0' if CPU really writes VIC-I reg (cpu_clk and rd/wr signal combined)
		reg_rd_n: in  std_logic; -- like the above, but for reading
		vid_a:	 out std_logic_vector (13 downto 0); -- 16K memory can be accessed (linear, this will be translated in top-level)
		vid_din:  in  std_logic_vector (11 downto 0) -- VIC has 12 bit bus towards the memory (high 4 bits is the colour RAM)		
	);
end vic6561;

architecture rtl of vic6561 is

type   regarray is array(0 to 15) of std_logic_vector(7 downto 0);
signal reg: regarray;

begin
	process (reg_rd_n) begin
		if reg_rd_n = '0' then
			reg_dout <= reg(conv_integer(reg_a));
		end if;
	end process;
	process (reg_wr_n) begin
		if reg_wr_n = '0' then
			reg(conv_integer(reg_a)) <= reg_din;
		end if;
	end process;
end rtl;
