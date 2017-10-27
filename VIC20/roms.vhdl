-- Trying to implement a Commodore VIC-20
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity kernal_ROM is
	Port (
		clk:	in  std_logic;
		a:		in  std_logic_vector (12 downto 0);
		dout:	out std_logic_vector ( 7 downto 0)
	);
end kernal_ROM;
architecture rtl of kernal_ROM is
type
	romarray is array(0 to 8191) of std_logic_vector (7 downto 0);
constant
	rom: romarray := (
	---INCLUDE-BIN:START:kernal.rom:8192: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:kernal.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	);
begin
	process (clk) begin
		if rising_edge(clk) then
			dout <= rom(conv_integer(a));
		end if;
	end process;
end rtl;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity basic_ROM is
	Port (
		clk:	in  std_logic;
		a:		in  std_logic_vector (12 downto 0);
		dout:	out std_logic_vector ( 7 downto 0)
	);
end basic_ROM;
architecture rtl of basic_ROM is
type
	romarray is array(0 to 8191) of std_logic_vector (7 downto 0);
constant
	rom: romarray := (
	---INCLUDE-BIN:START:basic.rom:8192: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:basic.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	);
begin
	process (clk) begin
		if rising_edge(clk) then
			dout <= rom(conv_integer(a));
		end if;
	end process;
end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity chrgen_ROM is
	Port (
		clk:	in  std_logic;
		a:		in  std_logic_vector (11 downto 0);
		dout:	out std_logic_vector ( 7 downto 0)
	);
end chrgen_ROM;
architecture rtl of chrgen_ROM is
type
	romarray is array(0 to 4095) of std_logic_vector (7 downto 0);
constant
	rom: romarray := (
	---INCLUDE-BIN:START:chrgen.rom:4096: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:chrgen.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	);
begin
	process (clk) begin
		if rising_edge(clk) then
			dout <= rom(conv_integer(a)) after 2ns;	-- after 2ns;  -- I saw that in some projects dunno why needed or not ...
		end if;
	end process;
end rtl;
