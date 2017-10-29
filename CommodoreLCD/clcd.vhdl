-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity CLCD is
	Port (
		clk100mhz: in std_logic;
		fpga_cpu_reset_n: in std_logic;
		-- fpga_switches: in std_logic_vector(15 downto 0);
		fpga_leds: out std_logic_vector(15 downto 0);
		fpga_rgbled1: out std_logic_vector(2 downto 0);
		fpga_rgbled2: out std_logic_vector(2 downto 0);
		-- VGA
		fpga_vga_hsync: out std_logic;
		fpga_vga_vsync: out std_logic;
		fpga_vga_r: out std_logic_vector(3 downto 0);
		fpga_vga_g: out std_logic_vector(3 downto 0);
		fpga_vga_b: out std_logic_vector(3 downto 0)
	);
end CLCD;

architecture rtl of CLCD is

signal clkdiv:	std_logic_vector(5 downto 0);
signal cpu_clk: std_logic;
signal pix_clk: std_logic;

signal reset_n: std_logic;
signal initial_reset_n: std_logic := '0';
signal reset_sustain_counter: unsigned(25 downto 0);

signal cpu_addrbus_to_mmu: std_logic_vector(23 downto 0);	-- T65 core knows 65816 as well, so the 24 bit bus. We use only 16 bit with 6502!
signal bus_a: std_logic_vector (17 downto 0);	-- Commodore LCD system bus (256K address space)
signal cpu_din: std_logic_vector(7 downto 0);
signal cpu_dout: std_logic_vector(7 downto 0);
signal cpu_rw: std_logic;

signal main_ram_dout: std_logic_vector(7 downto 0);
signal main_rom_dout: std_logic_vector(7 downto 0);
signal via1_register_dout: std_logic_vector(7 downto 0);
signal via2_register_dout: std_logic_vector(7 downto 0);

signal vid_a_bus: std_logic_vector(14 downto 0);
signal vid_d_bus: std_logic_vector( 7 downto 0);
signal vsync: std_logic;
signal hsync: std_logic;
signal pixel_onpanel: std_logic;
signal pixel_set: std_logic;
signal pixel: std_logic_vector(1 downto 0);

signal ram_oe_n:  std_logic;        -- active low signal for chip select on RAM (128K sized area at phys addr zero)
signal ram_we_n:  std_logic;        -- active low signal for write enable on RAM (128K sized area at phys addr zero)
signal rom_oe_n:  std_logic;        -- active low signal for chip select on ROM (128K sized area, above the RAM)
signal via1_cs_n: std_logic;       -- active low signal for chip select on VIA1
signal via2_cs_n: std_logic;       -- active low signal for chip select on VIA2
signal acia_cs_n: std_logic;       -- active low signal for chip select on ACIA
signal exp_cs_n:  std_logic;        -- active low signal for chip select on I/O expansion area
signal lcd_we_n:  std_logic;        -- active low signal for chip select + write on LCD ctrl registers (they're write only!)
signal vram_we_n: std_logic;        -- active low signal to signal video RAM (lower 32K of memory map) access by the CPU

signal leds: std_logic_vector(15 downto 0);
signal rgbled1: std_logic_vector(2 downto 0) := "111";
signal rgbled2: std_logic_vector(2 downto 0) := "111";


begin


CPU: entity work.T65
port map (
	Mode => "01",	-- 65C02 mode! (in the future it would be interesting to see if C-LCD would work a 65C816 as well ...)
	Res_n	=> reset_n,
	Enable => '1',
	Clk => cpu_clk,
	Rdy => '1',
	Abort_n => '1',
	IRQ_n => '1',
	NMI_n => '1',
	SO_n => '1',
	R_W_n => cpu_rw,
	A => cpu_addrbus_to_mmu,
	DI => cpu_din,
	DO => cpu_dout
);
LCD_CTRL: entity work.lcd_controller
port map (
	reg_a => bus_a(1 downto 0),
	reg_d => cpu_dout,
	reg_we_n => lcd_we_n,
	reg_clk => cpu_clk,
	pix_clk => pix_clk,
	vid_a_bus => vid_a_bus,
	vid_d_bus => vid_d_bus,
	vsync => vsync,
	hsync => hsync,
	onpanel => pixel_onpanel,
	pixel => pixel_set,
	reset_n => reset_n
);
MMU: entity work.lcd_mmu
port map (
	clk => cpu_clk,
	data_in => cpu_dout,
	rw_n => cpu_rw,
	bus_in => cpu_addrbus_to_mmu(15 downto 0),
	bus_translated => bus_a,
	ram_oe_n	=> ram_oe_n,
	ram_we_n => ram_we_n,
	rom_oe_n => rom_oe_n,
	via1_cs_n => via1_cs_n,
	via2_cs_n => via2_cs_n,
	acia_cs_n => acia_cs_n,
	exp_cs_n => exp_cs_n,
	lcd_we_n => lcd_we_n,
	vram_we_n => vram_we_n
);
VIA1: entity work.via6522
port map (
	clk => cpu_clk,
	cs_n => via1_cs_n,
	rw_n => cpu_rw,
	a => bus_a(3 downto 0),
	din => cpu_dout,
	dout => via1_register_dout,
	res_n => reset_n
);
VIA2: entity work.via6522
port map (
	clk => cpu_clk,
	cs_n => via2_cs_n,
	rw_n => cpu_rw,
	a => bus_a(3 downto 0),
	din => cpu_dout,
	dout => via2_register_dout,
	res_n => reset_n
);
MAIN_RAM: entity work.main_RAM
port map (
 	clk => cpu_clk,
	a => bus_a(16 downto 0),
	we_n => ram_we_n,
	din => cpu_dout,
	dout => main_ram_dout
);

-- This entity is only used to have a dual-port "shadow" memory which is only written by the CPU,
-- and read by the "LCD controller" to produce image then. Shared bus access is hard, as we don't
-- have fixed access pattern, since the real output is now a VGA screen not a real LCD panel ...
SHADOW_RAM: entity work.shadow_RAM
port map (
	write_clk => cpu_clk,
	write_addr => bus_a(14 downto 0),
	write_data => cpu_dout,
	write_enable_n => vram_we_n,
	read_clk => pix_clk,
	read_addr => vid_a_bus,
	read_data => vid_d_bus
);

MAIN_ROM: entity work.main_ROM
port map (
	clk => cpu_clk,
	a => bus_a(16 downto 0),
	dout => main_rom_dout
);


process (ram_oe_n, rom_oe_n, via1_cs_n, via2_cs_n) begin
	if ram_oe_n = '0' then
		cpu_din <= main_ram_dout;
	elsif rom_oe_n = '0' then
		cpu_din <= main_rom_dout;
	elsif via1_cs_n = '0' then
		cpu_din <= via1_register_dout;
	elsif via2_cs_n = '0' then
		cpu_din <= via2_register_dout;
	else
		cpu_din <= x"FF";
	end if;
end process;



process (clk100mhz) begin
	if rising_edge(clk100mhz) then
		clkdiv <= clkdiv + 1;
		--if fpga_cpu_reset_n = '0' or initial_reset_n = '0' then
		--	reset_sustain_counter <= (others => '1');
		--	initial_reset_n <= '1';
		--	reset_n <= '0';
		--	rgbled1 <= "001";
		--else
		--	initial_reset_n <= '1';
		--	if reset_sustain_counter /= 0 then
		--		reset_n <= '0';
		--		reset_sustain_counter <= reset_sustain_counter - 1;
		--		rgbled1 <= "100";
		--	else
		--		reset_n <= '1';
		--		rgbled1 <= "010";
		--		reset_sustain_counter <= (others => '0');
		--	end if;
		--end if;
	end if;
end process;

reset_n <= fpga_cpu_reset_n;



cpu_clk <= clkdiv(5);
pix_clk <= clkdiv(1);

fpga_vga_hsync <= hsync;
fpga_vga_vsync <= vsync;

pixel <= pixel_onpanel & pixel_set; -- I have no idea why, but ISE does not allow to use this directly in a case?! WHY????

process (pixel) begin
	--if rising_edge(pix_clk) then
	case pixel is
		when "10"   =>
			fpga_vga_r <= "1111";
			fpga_vga_g <= "1111";
			fpga_vga_b <= "1111";
		when "11"   =>
			fpga_vga_r <= "0000";
			fpga_vga_g <= "0000";
			fpga_vga_b <= "1111";
		when others =>
			fpga_vga_r <= "0000";
			fpga_vga_g <= "0000";
			fpga_vga_b <= "0000";
	end case;
	--end if;
end process;


fpga_leds <= leds;
leds <= cpu_addrbus_to_mmu(15 downto 0);
fpga_rgbled1 <= rgbled1;
fpga_rgbled2 <= rgbled2;
rgbled2(0) <= not initial_reset_n;
rgbled2(1) <= not fpga_cpu_reset_n;
rgbled2(2) <= not reset_n;

end rtl;
