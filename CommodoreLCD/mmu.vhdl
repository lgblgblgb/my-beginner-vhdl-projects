-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

-- My attempt to implement "5705 LCD MMU" chip in VHDL according to my findings I could also write the
-- first working software emulator for Commodore-LCD back to 2014.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
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
	Port (
		clk: in std_logic;
		data_in: in std_logic_vector (7 downto 0);	-- used to write MMU registers by the CPU
		rw_n: std_logic;		-- from CPU, low = write, high = read access
		bus_in: in std_logic_vector (15 downto 0);	-- CPU address bus as input
		bus_translated: out std_logic_vector (17 downto 0);	-- 256K address space of Commodore-LCD
		ram_oe_n: out std_logic;	-- active low signal for chip select on RAM (128K sized area at phys addr zero)
		ram_we_n: out std_logic;	-- active low signal for write enable on RAM (128K sized area at phys addr zero)
		rom_oe_n: out std_logic;	-- active low signal for chip select on ROM (128K sized area, above the RAM)
		via1_cs_n: out std_logic;	-- active low signal for chip select on VIA1
		via2_cs_n: out std_logic;	-- active low signal for chip select on VIA2
		acia_cs_n: out std_logic;	-- active low signal for chip select on ACIA
		exp_cs_n: out std_logic;	-- active low signal for chip select on I/O expansion area
		lcd_we_n: out std_logic;	-- active low signal for chip select + write on LCD ctrl registers (they're write only!)
		vram_we_n: out std_logic	-- active low signal to signal video RAM (lower 32K of memory map) access by the CPU
	);
end lcd_mmu;

architecture rtl of lcd_mmu is

-- MMU registers ...
signal offset1:    std_logic_vector (7 downto 0);	-- can be written by CPU @ $FD00-$FD7F
signal offset2:    std_logic_vector (7 downto 0);	-- can be written by CPU @ $FD80-$FDFF
signal offset3:    std_logic_vector (7 downto 0);	-- can be written by CPU @ $FE00-$FE7F
signal offset4:    std_logic_vector (7 downto 0);	-- can be written by CPU @ $FE80-$FEFF
signal offset5:    std_logic_vector (7 downto 0);	-- can be written by CPU @ $FF00-$FF7F
signal mode:       std_logic_vector (1 downto 0);	-- 
signal mode_saved: std_logic_vector (1 downto 0);	-- mode is saved if ANY write by CPU $FC00-$FC7F, restored if $FB80-$FBFF

--alias  bus_add:    std_logic_vector (7 downto 0) is bus_in(17 downto 10);
signal bus_add:	 std_logic_vector (7 downto 0);
alias  bus_rem:    std_logic_vector (9 downto 0) is bus_in( 9 downto  0);

constant TEN_ZEROS:std_logic_vector (9 downto 0) := "0000000000";
constant KERN_MODE:std_logic_vector (1 downto 0) := "00";
constant APPL_MODE:std_logic_vector (1 downto 0) := "01";
constant RAM_MODE: std_logic_vector (1 downto 0) := "10";
constant TEST_MODE:std_logic_vector (1 downto 0) := "11";

signal mem_cs_n: std_logic;
signal bus_out: std_logic_vector (17 downto 0);


begin

bus_add <= "00" & bus_in(15 downto 10);

process (clk, bus_in, rw_n) begin
	if rising_edge(clk) then
		case bus_in(15 downto 14) is
			when "00" =>	-- *** FIRST 16K of 65xx address space ***
				if bus_in(13 downto 12) = "00" then
					bus_out <= "00" & bus_in;	-- first 4K is pass-through
				else
					case mode is
						when KERN_MODE => bus_out <= "00" & bus_in;
						when APPL_MODE => bus_out <= (bus_add + offset1) & bus_rem;
						when RAM_MODE  => bus_out <= "00" & bus_in;
						when TEST_MODE => bus_out <= TEN_ZEROS & offset1;
						when others =>
					end case;
				end if;
				mem_cs_n <= '0';
			when "01" =>	-- *** SECOND 16K of 65xx address space ***
				case mode is
					when KERN_MODE => bus_out <= (bus_add + offset5) & bus_rem;
					when APPL_MODE => bus_out <= (bus_add + offset2) & bus_rem;
					when RAM_MODE  => bus_out <= "00" & bus_in;
					when TEST_MODE => bus_out <= TEN_ZEROS & offset2;
					when others =>
				end case;
				mem_cs_n <= '0';
			when "10" =>	-- *** THIRD 16K of 65xx address space ***
				case mode is
					when KERN_MODE => bus_out <= "11" & bus_in(15 downto 0);
					when APPL_MODE => bus_out <= (bus_add + offset3) & bus_rem;
					when RAM_MODE  => bus_out <= "00" & bus_in;
					when TEST_MODE => bus_out <= TEN_ZEROS & offset3;
					when others =>
				end case;
				mem_cs_n <= '0';
			when "11" =>	-- *** FOURTH 16K of 65xx address space ***
				if (bus_in(13 downto 9) /= "11100") or (rw_n = '1' and (bus_in(15 downto 8) > x"F9")) then
					case mode is
						when KERN_MODE => bus_out <= "11" & bus_in(15 downto 0);
						when APPL_MODE => bus_out <= (bus_add + offset4) & bus_rem;
						when RAM_MODE  => bus_out <= "00" & bus_in;
						when TEST_MODE => bus_out <= TEN_ZEROS & offset4;	-- btw this is wrong, however TEST mode is unusable for anything other than HW testing
						when others =>
					end case;
					mem_cs_n <= '0';
				else
					bus_out <= "00" & bus_in;
					mem_cs_n <= '1';	-- NOT a memory access!
				end if;
			when others =>
		end case;
		bus_translated <= bus_out;
		-- Produce various memory access related signals
		if mem_cs_n = '0' and rw_n = '1' and bus_out(17) = '0' then
			ram_oe_n <= '0';
		else
			ram_oe_n <= '1';
		end if;
		if mem_cs_n = '0' and rw_n = '0' and bus_out(17) = '0' then
			ram_we_n <= '0';
		else
			ram_we_n <= '1';
		end if;
		if mem_cs_n = '0' and rw_n = '1' and bus_out(17) = '1' then
			rom_oe_n <= '0';
		else
			rom_oe_n <= '1';
		end if;
		if mem_cs_n = '0' and rw_n = '0' and bus_out(17 downto 15) = "000" then
			vram_we_n <= '0';
		else
			vram_we_n <= '1';
		end if;
		-- Produce I/O select signals for devices (note: LCD ctrl is write only in this list, but it's decoded that way
		-- already, with mem_cs_n signal!)
		if mem_cs_n = '1' and bus_out(10 downto 7) = "0000" then
			via1_cs_n <= '0';
		else
			via1_cs_n <= '1';
		end if;
		if mem_cs_n = '1' and bus_out(10 downto 7) = "0001" then
			via2_cs_n <= '0';
		else
			via2_cs_n <= '1';
		end if;
		if mem_cs_n = '1' and bus_out(10 downto 7) = "0010" then
			exp_cs_n <= '0';
		else
			exp_cs_n <= '1';
		end if;
		if mem_cs_n = '1' and bus_out(10 downto 7) = "0011" then
			acia_cs_n <= '0';
		else
			acia_cs_n <= '1';
		end if;
		if mem_cs_n = '1' and bus_out(10 downto 7) = "1111" then
			lcd_we_n <= '0';
		else
			lcd_we_n <= '1';
		end if;
		-- The MMU controller itself, handle their registers
		-- NOTE: mem_cs_n signal is already decoded in the way, that only write access is possible here, no problem!
		if mem_cs_n = '1' then
			case bus_out(10 downto 7) is
				when "0100" => mode <= KERN_MODE;
				when "0101" => mode <= APPL_MODE;
				when "0110" => mode <= RAM_MODE;
				when "0111" => mode <= mode_saved;
				when "1000" => mode_saved <= mode;
				when "1001" => mode <= TEST_MODE;
				when "1010" => offset1 <= data_in;
				when "1011" => offset2 <= data_in;
				when "1100" => offset3 <= data_in;
				when "1101" => offset4 <= data_in;
				when "1110" => offset5 <= data_in;
				when others =>
			end case;
		end if;
	end if;
end process;



end rtl;