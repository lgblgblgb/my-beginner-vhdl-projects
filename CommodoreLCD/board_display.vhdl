-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

-- My attempt to implement "5705 LCD MMU" chip in VHDL according to my findings I could also write the
-- first working software emulator for Commodore-LCD back to 2014.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

-- NOTE: Commodore LCD's MMU does not have RESET input, the programmer should initialize it
-- This is not a problem, as the high memory area, where 65xx reset vector and some initial code
-- is always "fixed" regardless of the MMU mode, so it will work.

-- IDEA: later, I would like to see if a 65C816 works instead of a 65C02 or sw compatible (like 65C102).
-- with that, I would modify MMU to only use it, if CPU uses bank-0, otherwise CPU would be able to
-- access the whole 16Mbyte by its own and unaltered, thus it's possible to use much more RAM at least
-- in native mode, but being compatible with stock C-LCD still in 65816 emulation mode (which is the default).



entity led_display is
	port (
		clk: in std_logic;
		digits: in std_logic_vector(31 downto 0);
		dps: in std_logic_vector(7 downto 0);
		seg7_an: out std_logic_vector(7 downto 0);
		seg7_ca: out std_logic_vector(7 downto 0)
	);
end led_display;


architecture rtl of led_display is
	signal digit_mask: std_logic_vector(7 downto 0) := "11111110";
	signal data_shift: std_logic_vector(31 downto 0) := (others => '1');
	signal data_shift_dp: std_logic_vector(7 downto 0) := (others => '0');
begin
	process (clk) begin
		if rising_edge(clk) then
			digit_mask <= digit_mask(6 downto 0) & digit_mask(7);	-- rotate
			--if digit_mask = "01111111" then
			if digit_mask(7) = '0' then
				data_shift <= digits;
				data_shift_dp <= dps;
			else
				data_shift <= data_shift(3 downto 0) & data_shift(31 downto 4); 	-- rotate
				data_shift_dp <= data_shift_dp(0) & data_shift_dp(7 downto 1); -- rotate
			end if;
			seg7_an <= digit_mask;
			seg7_ca(7) <= not data_shift_dp(0);
			case data_shift(3 downto 0) is
				when x"0" => seg7_ca(6 downto 0) <= "1000000";
				when x"1" => seg7_ca(6 downto 0) <= "1111001";
				when x"2" => seg7_ca(6 downto 0) <= "0100100";
				when x"3" => seg7_ca(6 downto 0) <= "0110000";
				when x"4" => seg7_ca(6 downto 0) <= "0011001";
				when x"5" => seg7_ca(6 downto 0) <= "0010010";
				when x"6" => seg7_ca(6 downto 0) <= "0000010";
				when x"7" => seg7_ca(6 downto 0) <= "1111000";
				when x"8" => seg7_ca(6 downto 0) <= "0000000";
				when x"9" => seg7_ca(6 downto 0) <= "0010000";
				when x"A" => seg7_ca(6 downto 0) <= "0001000";
				when x"B" => seg7_ca(6 downto 0) <= "0000011";
				when x"C" => seg7_ca(6 downto 0) <= "1000110";
				when x"D" => seg7_ca(6 downto 0) <= "0100001";
				when x"E" => seg7_ca(6 downto 0) <= "0000110";
				when x"F" => seg7_ca(6 downto 0) <= "0001110";
				when others => seg7_ca(6 downto 0) <= "0100001";
			end case;
		end if;
	end process;
end rtl;