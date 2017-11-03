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

entity lcd_mmu is
	port (
		clk:			in  std_logic;
		data_in:		in  std_logic_vector (7 downto 0);	-- used to write MMU registers by the CPU
		we_n:			in  std_logic;		-- from CPU, low = write
		bus_in:		in  std_logic_vector (15 downto 0);	-- CPU address bus as input
		bus_out:		out std_logic_vector (17 downto 0);	-- 256K address space of Commodore-LCD
		via1_cs_n:	out std_logic;	-- active low signal for chip select on VIA1
		via2_cs_n:	out std_logic;	-- active low signal for chip select on VIA2
		acia_cs_n:	out std_logic;	-- active low signal for chip select on ACIA
		exp_cs_n:	out std_logic;	-- active low signal for chip select on I/O expansion area
		lcd_cs_n:	out std_logic	-- active low signal for chip select + write on LCD ctrl registers (they're write only!)
	);
end lcd_mmu;

architecture rtl of lcd_mmu is

-- MMU registers ...
signal offset1:    std_logic_vector (7 downto 0) := x"FF";	-- can be written by CPU @ $FD00-$FD7F
signal offset2:    std_logic_vector (7 downto 0) := x"FF";	-- can be written by CPU @ $FD80-$FDFF
signal offset3:    std_logic_vector (7 downto 0) := x"FF";	-- can be written by CPU @ $FE00-$FE7F
signal offset4:    std_logic_vector (7 downto 0) := x"FF";	-- can be written by CPU @ $FE80-$FEFF
signal offset5:    std_logic_vector (7 downto 0) := x"FF";	-- can be written by CPU @ $FF00-$FF7F
signal mode:       std_logic_vector (1 downto 0) := "11";	-- 
signal mode_saved: std_logic_vector (1 downto 0) := "11";	-- mode is saved if ANY write by CPU $FC00-$FC7F, restored if $FB80-$FBFF

-- Actually, MMU modes cannot be "seen" from outside, so it's totally OK to have any enumeration of the modes ...
constant KERN_MODE:std_logic_vector (1 downto 0) := "00";
constant APPL_MODE:std_logic_vector (1 downto 0) := "01";
constant RAM_MODE: std_logic_vector (1 downto 0) := "10";
constant TEST_MODE:std_logic_vector (1 downto 0) := "11";

begin

bus_out( 9 downto  0) <= bus_in(9 downto 0);	-- lower 10 bits are not altered by the MMU
bus_out(17 downto 10) <=
  -- $0000-$0FFF (always fixed)
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 12) = "0000"                     else
  -- $1000-$3FFF
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "00"  and mode = KERN_MODE else
  ("00" & bus_in(15 downto 10)) + offset1 when bus_in(15 downto 14) = "00"  and mode = APPL_MODE else
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "00"  and mode =  RAM_MODE else
   offset1                                when bus_in(15 downto 14) = "00"                       else
  -- $4000-$7FFF
  ("00" & bus_in(15 downto 10)) + offset5 when bus_in(15 downto 14) = "01"  and mode = KERN_MODE else
  ("00" & bus_in(15 downto 10)) + offset2 when bus_in(15 downto 14) = "01"  and mode = APPL_MODE else
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "01"  and mode =  RAM_MODE else
   offset2                                when bus_in(15 downto 14) = "01"                       else
   -- $8000-$BFFF
   "11" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "10"  and mode = KERN_MODE else
  ("00" & bus_in(15 downto 10)) + offset3 when bus_in(15 downto 14) = "10"  and mode = APPL_MODE else
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "10"  and mode =  RAM_MODE else
   offset3                                when bus_in(15 downto 14) = "10"                       else
   -- $F800-$FFFF (always fixed), NOTE: it will be further decoded later (also, mapping to top-kernal does not matter for I/O)
   -- in fact, we NEED to map addr to kernal in case of I/O not to catch I/O access as RAM access later (see: ram_cs_n)
   "11" & bus_in(15 downto 10)            when bus_in(15 downto 11) = "11111"                    else
  -- $C000-$F7FF
   "11" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "11"  and mode = KERN_MODE else
  ("00" & bus_in(15 downto 10)) + offset4 when bus_in(15 downto 14) = "11"  and mode = APPL_MODE else
   "00" & bus_in(15 downto 10)            when bus_in(15 downto 14) = "11"  and mode =  RAM_MODE else
   offset4                                when bus_in(15 downto 13) = "110"                      else
   offset5                                when bus_in(15 downto 13) = "111"                      else
   -- should not be
   "11" & bus_in(15 downto 10);


via1_cs_n <= '0' when bus_in(15 downto 7) = (x"F8" & '0') else '1';	-- $F800-$F87F
via2_cs_n <= '0' when bus_in(15 downto 7) = (x"F8" & '1') else '1';	-- $F880-$F8FF
exp_cs_n  <= '0' when bus_in(15 downto 7) = (x"F9" & '0') else '1';	-- $F900-$F97F
acia_cs_n <= '0' when bus_in(15 downto 7) = (x"F9" & '1') else '1';	-- $F980-$F9FF
lcd_cs_n  <= '0' when bus_in(15 downto 7) = (x"FF" & '1') else '1';	-- $FF80-$FFFF


process (clk) begin
	if rising_edge(clk) then
		if we_n = '0' then
			case bus_in(15 downto 7) is
				when x"FA" & '0' => mode <= KERN_MODE;
				when x"FA" & '1' => mode <= APPL_MODE;
				when x"FB" & '0' => mode <=  RAM_MODE;
				when x"FB" & '1' => mode <= mode_saved;
				when x"FC" & '0' => mode_saved <= mode;
				when x"FC" & '1' => mode <= TEST_MODE;
				when x"FD" & '0' => offset1 <= data_in;
				when x"FD" & '1' => offset2 <= data_in;
				when x"FE" & '0' => offset3 <= data_in;
				when x"FE" & '1' => offset4 <= data_in;
				when x"FF" & '0' => offset5 <= data_in;
				when others => null;
			end case;
		end if;
	end if;
end process;

end rtl;