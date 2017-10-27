-- Trying to implement a Commodore VIC-20
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity VIC20 is
	Port (
		clk100mhz: in std_logic;
		fpga_cpu_reset_n: in std_logic;
		-- fpga_switches: in std_logic_vector(15 downto 0);
		fpga_leds: out std_logic_vector(15 downto 0);
		fpga_rgbled1: out std_logic_vector(2 downto 0);
		fpga_rgbled2: out std_logic_vector(2 downto 0)
	);
end VIC20;

architecture rtl of VIC20 is

constant DEV_MAIN_RAM:	integer := 0;
constant DEV_VIC:			integer := 1;
constant DEV_VIA1:		integer := 2;
constant DEV_VIA2:		integer := 3;
constant DEV_COLOUR_RAM:integer := 4;
constant	DEV_MAX_BITS:	integer := 4;

signal clkdiv:	std_logic_vector(4 downto 0);
signal cpu_clk: std_logic;
signal mem_clk: std_logic;
signal reset_n: std_logic;
signal initial_reset_n: std_logic := '0';
signal reset_sustain_counter: unsigned(25 downto 0);
signal cpu_a: std_logic_vector(23 downto 0);	-- T65 core knows 65816 as well, so the 24 bit bus. We use only 16 bit with 6502!
signal cpu_din: std_logic_vector(7 downto 0);
signal cpu_dout: std_logic_vector(7 downto 0);
signal main_ram_dout: std_logic_vector(7 downto 0);
signal colour_ram_dout: std_logic_vector(3 downto 0);
signal kernal_rom_dout: std_logic_vector(7 downto 0);
signal basic_rom_dout: std_logic_vector(7 downto 0);
signal chrgen_rom_dout: std_logic_vector(7 downto 0);
signal vic_register_dout: std_logic_vector(7 downto 0);
signal via1_register_dout: std_logic_vector(7 downto 0);
signal via2_register_dout: std_logic_vector(7 downto 0);
signal cpu_rw: std_logic;
signal vic_din: std_logic_vector(11 downto 0);
signal vic_a: std_logic_vector(13 downto 0);
signal select_mux: std_logic_vector (DEV_MAX_BITS downto 0);
signal leds: std_logic_vector(15 downto 0);
signal rgbled1: std_logic_vector(2 downto 0) := "111";
signal rgbled2: std_logic_vector(2 downto 0) := "111";


begin


CPU: entity work.T65
port map (
	Mode => "00",
	Res_n	=> reset_n,
	Enable => '1',
	Clk => cpu_clk,
	Rdy => '1',
	Abort_n => '1',
	IRQ_n => '1',
	NMI_n => '1',
	SO_n => '1',
	R_W_n => cpu_rw,
	A => cpu_a,
	DI => cpu_din,
	DO => cpu_dout
);

MAIN_RAM: entity work.main_RAM
port map (
 	clk => mem_clk,
	a => cpu_a(14 downto 0),
	we_n => cpu_rw or select_mux(DEV_MAIN_RAM) or cpu_clk,
	din => cpu_dout,
	dout => main_ram_dout
);
CHRGEN_ROM: entity work.chrgen_ROM
port map (
	clk => mem_clk,
	a => cpu_a(11 downto 0),
	dout => chrgen_rom_dout
);
VIC: entity work.vic6561
port map (
	clk => not cpu_clk,
	reg_din => cpu_dout,
	reg_a => cpu_a(3 downto 0),
	reg_dout => vic_register_dout,
	reg_wr_n => cpu_rw or select_mux(DEV_VIC) or cpu_clk,
	reg_rd_n => (not cpu_rw) or select_mux(DEV_VIC) or cpu_clk,
	vid_din => vic_din,
	vid_a => vic_a
);
VIA1: entity work.via6522
port map (
	clk => cpu_clk,
	wr_n => cpu_rw or select_mux(DEV_VIA1) or cpu_clk,
	rd_n => (not cpu_rw) or select_mux(DEV_VIA1) or cpu_clk,
	a => cpu_a(3 downto 0),
	din => cpu_dout,
	dout => via1_register_dout
);
VIA2: entity work.via6522
port map (
	clk => cpu_clk,
	wr_n => cpu_rw or select_mux(DEV_VIA2) or cpu_clk,
	rd_n => (not cpu_rw) or select_mux(DEV_VIA2) or cpu_clk,
	a => cpu_a(3 downto 0),
	din => cpu_dout,
	dout => via2_register_dout
);
COLOUR_RAM: entity work.colour_RAM
port map (
	clk => mem_clk,
	a => cpu_a(9 downto 0),
	we_n => cpu_rw or select_mux(DEV_COLOUR_RAM) or cpu_clk,
	din => cpu_dout(3 downto 0),
	dout => colour_ram_dout
);
BASIC_ROM: entity work.basic_ROM
port map (
	clk => mem_clk,
	a => cpu_a(12 downto 0),
	dout => basic_rom_dout
);
KERNAL_ROM: entity work.kernal_ROM
port map (
	clk => mem_clk,
	a => cpu_a(12 downto 0),
	dout => kernal_rom_dout
);


--with cpu_a(15 downto 12)
--	select cpu_din <=
--		main_ram_dout   when "0000",	-- 0x0___
--		main_ram_dout   when "0001",	-- 0x1___
--		main_ram_dout   when "0010",	-- 0x2___
--		main_ram_dout   when "0011",	-- 0x3___
--		main_ram_dout   when "0100",	-- 0x4___
--		main_ram_dout   when "0101",	-- 0x5___
--		main_ram_dout   when "0110",	-- 0x6___
--		main_ram_dout   when "0111",	-- 0x7___
--		chrgen_rom_dout when "1000",	-- 0x8___
--		--"11111111"      when "1001",	-- 0x9___	I/O area, this is a TODO currently!
--		--"11111111"		 when "1010",	-- 0xA___
--		--"11111111"		 when "1011",	-- 0xB___
--		basic_rom_dout	 when "1100",	-- 0xC___
--		basic_rom_dout	 when "1101",	-- 0xD___
--		kernal_rom_dout when "1110",	-- 0xE___
--		kernal_rom_dout when "1111",	-- 0xF___
--		"11111111"		 when others;


process (cpu_a, main_ram_dout, chrgen_rom_dout, vic_register_dout, via1_register_dout, via2_register_dout,
colour_ram_dout, basic_rom_dout, kernal_rom_dout) begin
	if cpu_a(15) = '0' then
		-- 32K RAM at "once" ... well-expanded VIC-20. TODO: also implement different VIC-20 configurations!
		cpu_din <= main_ram_dout;
		select_mux <= (DEV_MAIN_RAM => '0', others => '1');
	elsif cpu_a(14 downto 12) = "000" then
		-- Character generator ROM
		cpu_din <= chrgen_rom_dout;
		select_mux <= (others => '1');
	elsif cpu_a(14 downto 8) = "0010000" then
		-- VIC-I registers.
		-- it seems, a full 256 bytes long "page" is used to select, but only lower 4 bits select the register
		-- 9000-90FF
		cpu_din <= vic_register_dout;
		select_mux <= (DEV_VIC => '0', others => '1');
	elsif cpu_a(14 downto 10) = "00100" and cpu_a(4) = '1' then
		-- VIA-1 registers
		-- 9000-93FF range where bit 4 = '1' (FIXME: it seems there is collusion with VIC, let's exclude 9000-90FF)
		-- also I am not sure what happens if bit 4 and 5 is set too, a low quality schematics of VIC20 suggests that
		-- then both of the VIAs are selected at the _same_ time? On reading it should cause bus conflict! :-O
		cpu_din <= via1_register_dout;
		select_mux <= (DEV_VIA1 => '0', others => '1');
	elsif cpu_a(14 downto 10) = "00100" and cpu_a(5) = '1' then
		-- VIA-2 registers
		-- 9000-93FF range where bit 5 = '1'
		-- see my comments above, at VIA-1 though
		cpu_din <= via2_register_dout;
		select_mux <= (DEV_VIA2 => '0', others => '1');
	elsif cpu_a(14 downto 10) = "00101" then
		-- Colour RAM.
		cpu_din <= "1111" & colour_ram_dout;
		select_mux <= (DEV_COLOUR_RAM => '0', others => '1');
	elsif cpu_a(14 downto 13) = "10" then
		cpu_din <= basic_rom_dout;
		select_mux <= (others => '1');
	elsif cpu_a(14 downto 13) = "11" then
		cpu_din <= kernal_rom_dout;
		select_mux <= (others => '1');
	else
		cpu_din <= (others => '1');
		select_mux <= (others => '1');
	end if;
end process;

-- VIC-I access to the memory stuff
--process (vid_a) begin
--	vid_din
--end process;


process (clk100mhz) begin
	if rising_edge(clk100mhz) then
		clkdiv <= clkdiv + 1;
		if fpga_cpu_reset_n = '0' or initial_reset_n = '0' then
			reset_sustain_counter <= (others => '1');
			initial_reset_n <= '1';
			reset_n <= '0';
			rgbled1 <= "001";
		else
			initial_reset_n <= '1';
			if reset_sustain_counter /= 0 then
				reset_n <= '0';
				reset_sustain_counter <= reset_sustain_counter - 1;
				rgbled1 <= "100";
			else
				reset_n <= '1';
				rgbled1 <= "010";
				reset_sustain_counter <= (others => '0');
			end if;
		end if;
	end if;
end process;

mem_clk <= clkdiv(3);
cpu_clk <= clkdiv(4);


fpga_leds <= leds;
leds <= cpu_a(15 downto 0);
fpga_rgbled1 <= rgbled1;
fpga_rgbled2 <= rgbled2;
rgbled2(0) <= not initial_reset_n;
rgbled2(1) <= not fpga_cpu_reset_n;
rgbled2(2) <= not reset_n;

end rtl;
