-- Trying to implement a Commodore-LCD
-- (C)2017 LGB Gabor Lenart lgblgblgb@gmail.com
-- Using T65 core, also can be found (or could?) at opencores.org with BSD license
-- This work is licensed according to GNU/GPL 3.
-- WARNING: this is my first try in VHDL (or any HDL!) after blinking a LED, so ... well, you understand :)

-- My attempt to implement "5706 LCD controller" chip in VHDL according to my findings I could also write the
-- first working software emulator for Commodore-LCD back to 2014.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity lcd_controller is
	port (
		reset_n:	in std_logic;
		-- CPU can only write the four LCD controller registers:
		reg_a:	in std_logic_vector(1 downto 0);
		reg_d:	in std_logic_vector(7 downto 0);
		reg_we_n:in std_logic;
		reg_clk:	in std_logic;
		-- pixel clock
		pix_clk:	in std_logic;
		-- Access interface to the "dual port shadow RAM"
		-- REALLY, I should figure out how to use the "main" memory with time-interlaving the CPU access
		-- without this mess ...
		vid_a_bus:	out std_logic_vector(14 downto 0);
		vid_d_bus:	in  std_logic_vector( 7 downto 0);
		-- Video signal output (Commodore LCD is single bit only stuff, but since LCD display is smaller and other
		-- aspect ratio than a VGA screen, we have other information as well to signal "outside of LCD panel")
		onpanel: out std_logic;
		pixel:	out std_logic;	-- mono pixel output, only valid if 'onpanel' is '1'
		hsync:	out std_logic;
		vsync:	out std_logic
);
end lcd_controller;

architecture rtl of lcd_controller is

signal chrrom_a_bus: std_logic_vector(11 downto 0);
signal chrrom_d_bus: std_logic_vector( 7 downto 0);
alias  font_alt: std_logic is chrrom_a_bus(10);
alias  font_8: std_logic is chrrom_a_bus(11);
signal startram_low7bits_text: std_logic_vector(6 downto 0);	-- only in TXT mode it's used!
signal startram_128bytes: std_logic_vector(7 downto 0);
signal graph_mode: std_logic;
signal vid_a_buff: std_logic_vector(14 downto 0);
signal vid_a_line: std_logic_vector(14 downto 0);
signal bitpos: std_logic_vector(2 downto 0);
signal bitpos_max: std_logic_vector(2 downto 0);
signal shiftreg: std_logic_vector(7 downto 0);
signal video_byte: std_logic_vector(7 downto 0);
signal h_cnt : std_logic_vector(9 downto 0);
signal v_cnt : std_logic_vector(9 downto 0);

begin

-- Character generator ROM is private to the LCD controller on Commodore LCD.
-- The CPU cannot even access it, only the controller.
CHRGEN_ROM: entity work.chrgen_ROM
port map (
	clk => pix_clk,
	a =>	chrrom_a_bus,
	dout => chrrom_d_bus
);


-- CPU can (only) write LCD registers ...
process (reg_clk, reset_n) begin
	if reset_n = '0' then
		font_alt <= '0';
		font_8 <= '0';
		startram_low7bits_text <= (others => '0');
		startram_128bytes <= x"10";
		graph_mode <= '0';
	elsif rising_edge(reg_clk) then
		if reg_we_n = '0' then
			case reg_a is
				when "00" =>
					startram_low7bits_text <= reg_d(6 downto 0);	-- only in TXT mode it's used!
				when "01" =>
					startram_128bytes <= reg_d;
				when "10" =>
					graph_mode <= reg_d(1);
					font_alt <= reg_d(0);
				when "11" =>
					font_8 <= reg_d(2);
				when others =>
			end case;
		end if;
	end if;
end process;



-- Maintain H and V counters (actual VGA position)
process (pix_clk, reset_n) begin
	if reset_n = '0' then
		h_cnt <= (others => '0');
		v_cnt <= (others => '0');
	elsif rising_edge(pix_clk) then
		if h_cnt = 799 then
			h_cnt <= (others => '0');
			if v_cnt = 524 then
				v_cnt <= (others => '0');
			else
				v_cnt <= v_cnt + 1;
			end if;
		else
			h_cnt <= h_cnt + 1;
		end if;
	end if;
end process;


bitpos_max <= "111" when font_8 = '1' and graph_mode = '0' else "101";
vid_a_bus <= vid_a_buff;

-- Now the bulk of the work ...
process (h_cnt(0), reset_n) begin
	if reset_n = '0' then
		bitpos <= "000";
		vid_a_buff <= "000100000000000";
		vid_a_line <= "000100000000000";
		chrrom_a_bus(9 downto 0) <= (others => '0');
	elsif rising_edge(h_cnt(0)) then
		if h_cnt >= 80 and h_cnt < 80 + 480 and v_cnt >= 176 and v_cnt < 176 + 128 then
			if bitpos = "000" then
				bitpos <= "001";
				video_byte <= vid_d_bus;
				chrrom_a_bus(9 downto 3) <= video_byte(6 downto 0);
				if video_byte(7) = '0' then
					shiftreg <= chrrom_d_bus;
				else
					shiftreg <= chrrom_d_bus xor "11111111";
				end if;
				vid_a_buff <= vid_a_buff + 1;
			else
				if bitpos = bitpos_max then
					bitpos <= "000";
					-- va <= va + 1;
				else
					bitpos <= bitpos + 1;
				end if;
				shiftreg <= shiftreg(6 downto 0) & '0';
			end if;
			onpanel <= '1';
		else
			onpanel <= '0';
			bitpos <= "000";
			if h_cnt = 80 + 480 + 1 then
				if v_cnt = 176 + 128 + 1 then
					-- end of screen, set video address to default
					vid_a_line <= startram_128bytes & startram_low7bits_text;
				else
					-- end of line
					if chrrom_a_bus(2 downto 0) = "111" then
						vid_a_line <= vid_a_line + 128;
					end if;
					chrrom_a_bus(2 downto 0) <=  chrrom_a_bus(2 downto 0) + 1;
				end if;
				vid_a_buff <= vid_a_line;
			end if;
		end if;
	end if;
end process; 


hsync <= '0' when h_cnt > 640 + 16 and h_cnt < 640 + 16 + 96 else '1';
vsync <= '0' when v_cnt = 480 + 10 or  v_cnt = 480 + 11 else '1';
pixel <= shiftreg(7);


end rtl;
