-- Trying to implement a Commodore LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity main_ROM is
	Port (
		clk:	in  std_logic;
		a:	in  std_logic_vector (16 downto 0);
		dout:	out std_logic_vector ( 7 downto 0)
	);
end main_ROM;
architecture rtl of main_ROM is
type
	romarray is array(0 to 131071) of std_logic_vector (7 downto 0);
constant
	rom: romarray := (
	---INCLUDE-BIN:START:clcd-u105.rom:32768: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:clcd-u105.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	,
	---INCLUDE-BIN:START:clcd-u104.rom:32768: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:clcd-u104.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	,
	---INCLUDE-BIN:START:clcd-u103.rom:32768: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:clcd-u103.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	,
	---INCLUDE-BIN:START:clcd-u102.rom:32768: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:clcd-u102.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	);
begin
	process (clk) begin
		if rising_edge(clk) then
			dout <= rom(to_integer(unsigned(a)));
		end if;
	end process;
end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity chrgen_ROM is
	Port (
		clk:	in  std_logic;
		a:	in  std_logic_vector (11 downto 0);
		dout:	out std_logic_vector ( 7 downto 0)
	);
end chrgen_ROM;
architecture rtl of chrgen_ROM is
type
	romarray is array(0 to 4095) of std_logic_vector (7 downto 0);
constant
	rom: romarray := (
	---INCLUDE-BIN:START:clcd-chargen.rom:4096: *** Do not modify this line or Makefile won't work to update binary! ***
-- DATA IS STRIPPED OUT
	---INCLUDE-BIN:STOP:clcd-chargen.rom: *** Do not modify this line or Makefile won't work to update binary! ***
	);
begin
	process (clk) begin
		if rising_edge(clk) then
			dout <= rom(to_integer(unsigned(a)));
		end if;
	end process;
end rtl;
