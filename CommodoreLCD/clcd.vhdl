-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;


entity CLCD is
	port (
		clk100mhz: in std_logic;
		fpga_cpu_reset_n: in std_logic;
		-- fpga_switches: in std_logic_vector(15 downto 0);
		fpga_leds: out std_logic_vector(15 downto 0);
		fpga_rgbled1: out std_logic_vector(2 downto 0);
		fpga_rgbled2: out std_logic_vector(2 downto 0);
		-- 7-seg display
		fpga_disp_ca: out std_logic_vector(7 downto 0);
		fpga_disp_an: out std_logic_vector(7 downto 0);
		-- VGA
		fpga_vga_hsync: out std_logic;
		fpga_vga_vsync: out std_logic;
		fpga_vga_r: out std_logic_vector(3 downto 0);
		fpga_vga_g: out std_logic_vector(3 downto 0);
		fpga_vga_b: out std_logic_vector(3 downto 0)
	);
end CLCD;

architecture rtl of CLCD is

signal clkdiv:	unsigned(31 downto 0);
signal cpu_clk: std_logic;
signal pix_clk: std_logic;

signal reset_n: std_logic;
signal initial_reset_n: std_logic := '0';
signal initial_reset: std_logic := '1';
signal reset_sustain_counter: unsigned(25 downto 0);

signal bus_a_untranslated: std_logic_vector(15 downto 0);
signal bus_a: std_logic_vector (17 downto 0);	-- Commodore LCD system bus (256K address space)
signal cpu_din: std_logic_vector(7 downto 0);
signal cpu_dout: std_logic_vector(7 downto 0);
signal cpu_wr_n: std_logic;

signal main_ram_dout: std_logic_vector(7 downto 0);
signal main_rom_dout: std_logic_vector(7 downto 0);
signal via1_register_dout: std_logic_vector(7 downto 0);
signal via2_register_dout: std_logic_vector(7 downto 0);

signal vid_a_bus: std_logic_vector(14 downto 0);
signal vid_d_bus: std_logic_vector( 7 downto 0);
signal vsync: std_logic;
signal hsync: std_logic;
signal pixel_onpanel: std_logic;
signal pixel_onscreen: std_logic;
signal pixel_set: std_logic;
signal pixel: std_logic_vector(2 downto 0);

signal via1_cs_n: std_logic;       -- active low signal for chip select on VIA1
signal via2_cs_n: std_logic;       -- active low signal for chip select on VIA2
signal acia_cs_n: std_logic;       -- active low signal for chip select on ACIA
signal exp_cs_n:  std_logic;        -- active low signal for chip select on I/O expansion area
signal lcd_cs_n:  std_logic;        -- active low signal for chip select
signal lcd_we_n:	std_logic;

signal vram_cs_n: std_logic;
signal ram_cs_n:  std_logic;
signal rom_cs_n:  std_logic;
signal ram_we_n:  std_logic;
signal rom_we_n:  std_logic;
signal vram_we_n: std_logic;

signal leds: std_logic_vector(15 downto 0);
signal rgbled1: std_logic_vector(2 downto 0) := "111";
signal rgbled2: std_logic_vector(2 downto 0) := "111";

signal seven_digit_display_hex: std_logic_vector(31 downto 0) := x"12345678";
signal seven_digit_display_dps: std_logic_vector( 7 downto 0) :=  "00000000";

signal inverted_cpu_clk: std_logic;

begin

LED_DISP: entity work.led_display
port map (
	clk => clkdiv(11),
	digits => seven_digit_display_hex,
	dps => seven_digit_display_dps,
	seg7_an => fpga_disp_an,
	seg7_ca => fpga_disp_ca
);
CPU_R65C02TC: entity work.r65c02_tc
port map (
	clk_clk_i => inverted_cpu_clk,	-- trying this hmm :-O
	d_i => cpu_din,
	d_o => cpu_dout,
	a_o => bus_a_untranslated,
	irq_n_i => '1',
	nmi_n_i => '1',
	rdy_i => '1',
	rst_rst_n_i => reset_n,
	so_n_i => '1',
	wr_n_o => cpu_wr_n
);
LCD_CTRL: entity work.lcd_controller
port map (
	reg_a => bus_a_untranslated(1 downto 0),
	reg_din => cpu_dout,
	reg_we_n => lcd_we_n,
	reg_clk => cpu_clk,
	pix_clk => pix_clk,
	vid_a_bus => vid_a_bus,
	vid_d_bus => vid_d_bus,
	vsync => vsync,
	hsync => hsync,
	onpanel => pixel_onpanel,
	onscreen => pixel_onscreen,
	pixel => pixel_set,
	reset_n => reset_n
);
MMU: entity work.lcd_mmu
port map (
	clk => cpu_clk,
	data_in => unsigned(cpu_dout),
	we_n => cpu_wr_n,
	bus_in => unsigned(bus_a_untranslated(15 downto 0)),
	bus_translated => bus_a,
	via1_cs_n => via1_cs_n,
	via2_cs_n => via2_cs_n,
	acia_cs_n => acia_cs_n,
	exp_cs_n => exp_cs_n,
	lcd_cs_n => lcd_cs_n
);
VIA1: entity work.via6522
port map (
	clk => cpu_clk,
	cs_n => via1_cs_n,
	wr_n => cpu_wr_n,
	a => bus_a_untranslated(3 downto 0),
	din => cpu_dout,
	dout => via1_register_dout,
	res_n => reset_n
);
VIA2: entity work.via6522
port map (
	clk => cpu_clk,
	cs_n => via2_cs_n,
	wr_n => cpu_wr_n,
	a => bus_a_untranslated(3 downto 0),
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
	-- read-only memory port for the LCD controller
	--read2_clk => pix_clk,
	--read2_a => vid_a_bus,
	--read2_dout => vid_d_bus
);
SHADOW_RAM: entity work.shadow_RAM
port map (
	write_clk => cpu_clk,
	write_a => bus_a(14 downto 0),
	write_din => cpu_dout,
	we_n => vram_we_n,
	read_clk => pix_clk,
	read_a => vid_a_bus,
	read_dout => vid_d_bus
);
MAIN_ROM: entity work.main_ROM
port map (
	clk => cpu_clk,
	a => bus_a(16 downto 0),
	dout => main_rom_dout
);



-- multiplexing the CPU data input with the selected device's output
-- R/W register capable devices must be mentioned FIRST (since I/O CS signals overlaps with ROM CS signal)
cpu_din <=
	via1_register_dout	when via1_cs_n = '0' else
	via2_register_dout	when via2_cs_n = '0' else
	x"FF"						when  exp_cs_n = '0' else	-- nothing here currently (neither on the real C-LCD)
	x"00"						when acia_cs_n = '0' else	-- not implemented yet at all
	main_rom_dout			when  rom_cs_n = '0' else
	main_ram_dout			when  ram_cs_n = '0' else
	-- should not happen
	x"FF";

vram_cs_n <= bus_a(17) or bus_a(16) or bus_a(15);		-- '0' when bus_a(17 downto 15) = "000" else '1';
vram_we_n <= vram_cs_n or cpu_wr_n;							-- '0' when vram_cs_n = '0' and cpu_wr_n = '0' else '1';
ram_cs_n <= bus_a(17);
ram_we_n <= ram_cs_n or cpu_wr_n;							-- '0' when ram_cs_n = '0' and cpu_wr_n = '0' else '1';
rom_cs_n <= '0' when bus_a(17) = '1' else '1';			-- not bus_a(17)
lcd_we_n <= lcd_cs_n or cpu_wr_n;	-- write only ("through" kernal) LCD display controller access. The other is MMU, but that is covered in mmu.vhdl already

process (clk100mhz) begin
	if rising_edge(clk100mhz) then
		clkdiv <= clkdiv + 1;
	end if;
end process;

--process (clk100mhz) begin
--	if falling_edge(clk100mhz) then
--		if fpga_cpu_reset_n = '0' or initial_reset_n = '0' then
--			reset_sustain_counter <= (others => '1');
--			initial_reset_n <= '1';
--			reset_n <= '0';
--			rgbled1 <= "001";
--		else
--			initial_reset_n <= '1';
--			if reset_sustain_counter /= 0 then
--				reset_n <= '0';
--				reset_sustain_counter <= reset_sustain_counter - 1;
--				rgbled1 <= "100";
--			else
--				reset_n <= '1';
--				rgbled1 <= "010";
--				reset_sustain_counter <= (others => '0');
--			end if;
--		end if;
--	end if;
--end process;

process (clkdiv(14)) begin
	if rising_edge(clkdiv(14)) then
		if initial_reset = '1' then
			reset_n <= '0';
			initial_reset <= '0';
		else
			reset_n <= fpga_cpu_reset_n;
		end if;
	end if;
end process;

-- CLK div table
--0 - 50 MHz
--1 - 25 MHz
--2 - 12.5 MHz
--3 - 6.25 MHz
--4 - 3.125 MHz
--5 - 1.5625 MHz
--6 - ~781.25 KHz
--7 - ~390.625 KHz
--8 - ~195.3125 KHz
--9 - ~97 KHz
--10 - ~48 KHz
--11 - ~24 KHz
--12 - ~12 KHz
--13 - ~6 KHz
--14 - ~3 KHz
--15 - ~1.5 KHz
--16 - ~762 Hz
--17 - ~381 Hz
--18 - ~190 Hz
--19 - ~95 Hz
--20 - ~47 Hz
--21 - ~23 Hz
--22 - ~12 Hz
--23 - ~6 Hz
--24 - ~3 Hz
--25 - ~1.5Hz
--26 - ~0.74Hz
--27 - ~0.37Hz

inverted_cpu_clk <= not cpu_clk;

cpu_clk <= clkdiv(6); -- was 5 for ~1.5MHz, 27 ~0.37Hz :) is for extreme debugging ...
pix_clk <= clkdiv(1);

fpga_vga_hsync <= hsync;
fpga_vga_vsync <= vsync;

pixel <= pixel_onscreen & pixel_onpanel & pixel_set; -- I have no idea why, but ISE does not allow to use this directly in a case?! WHY????

process (pixel) begin
	case pixel is
		when "110"   =>		-- pixel within VGA screen and within 'LCD' but not set
			fpga_vga_r <= "1111";
			fpga_vga_g <= "1111";
			fpga_vga_b <= "1111";
		when "111"   =>		-- pixel within VGA screen and within 'LCD' and set
			fpga_vga_r <= "0000";
			fpga_vga_g <= "0000";
			fpga_vga_b <= "1111";
		when "100" | "101" =>	-- on VGA screen but not on 'LCD' (very large "border" we can say)
			fpga_vga_r <= "0011";
			fpga_vga_g <= "0000";
			fpga_vga_b <= "0000";
		when others =>
			fpga_vga_r <= "0000";
			fpga_vga_g <= "0000";
			fpga_vga_b <= "0000";
  end case;
end process;

process (cpu_clk, bus_a_untranslated) begin
	if rising_edge(cpu_clk) then
		fpga_leds <= leds;
		fpga_rgbled1 <= rgbled1;
		fpga_rgbled2 <= rgbled2;
		seven_digit_display_hex <= bus_a(15 downto 0) & bus_a_untranslated(15 downto 0);
		seven_digit_display_dps(7 downto 6) <= bus_a(17 downto 16);
	end if;
	if falling_edge(cpu_clk) then
		leds <= bus_a(15 downto 0);
		rgbled2(0) <= initial_reset;   -- not initial_reset_n
		rgbled2(1) <= not fpga_cpu_reset_n;
		rgbled2(2) <= not reset_n;
	end if;
end process;

end rtl;
