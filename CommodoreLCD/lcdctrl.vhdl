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
		reg_din:	in std_logic_vector(7 downto 0);
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
		onpanel: out std_logic;	-- display range within the LCD display
		onscreen:out std_logic;	-- display range within the VGA display (which contains the LCD)
		pixel:	out std_logic;	-- mono pixel output, only valid if 'onpanel' is '1' and 'onscreen' is '1'
		hsync:	out std_logic;
		vsync:	out std_logic
);
end lcd_controller;

architecture rtl of lcd_controller is

signal chrrom_a_bus: std_logic_vector(11 downto 0);
signal chr_a_buff: std_logic_vector(11 downto 0);
signal chrrom_d_bus: std_logic_vector( 7 downto 0);
alias  font_alt: std_logic is chr_a_buff(10);
alias  font_8: std_logic is chr_a_buff(11);
signal startram_low7bits_text: std_logic_vector(6 downto 0);	-- only in TXT mode it's used!
signal startram_128bytes: std_logic_vector(7 downto 0);
signal graph_mode: std_logic;
signal vid_a_buff: std_logic_vector(14 downto 0);
--signal vid_a_line: std_logic_vector(14 downto 0);
signal bitpos: std_logic_vector(2 downto 0);
signal bitpos_max: std_logic_vector(2 downto 0);
signal shiftreg: std_logic_vector(7 downto 0);
signal video_byte: std_logic_vector(7 downto 0);
signal h_cnt : std_logic_vector(9 downto 0);
signal v_cnt : std_logic_vector(9 downto 0);

-- Singal parameters

--constant cfg_vsync_polarity:	std_logic := '0';
--constant cfg_hsync_polarity:	std_logic := '0';
--constant cfg_h_start_disp:	unsigned(10 downto 0) := 80;
--constant cfg_h_end_disp:		unsigned(10 downto 0) := 80 + 480 - 1;
--constant cfg_h_end_visible:	unsigned(10 downto 0) := 640 - 1;
--constant cfg_h_start_sync:	unsigned(10 downto 0) := 640 + 16 + 1;
--constant cfg_h_end_sync:		unsigned(10 downto 0) := 640 + 16 + 96 - 1;
--constant cfg_h_end_scan:		unsigned(10 downto 0) := 799;
--constant cfg_v_start_disp:	unsigned(10 downto 0) := 176;
--constant cfg_v_end_disp:		unsigned(10 downto 0) := 176 + 128 - 1;
--constant cfg_v_end_visible:	unsigned(10 downto 0) := 480 - 1;
--constant cfg_v_start_sync:	unsigned(10 downto 0) := 480 + 10;
--constant cfg_v_end_sync:		unsigned(10 downto 0) := 480 + 11;
--constant cfg_v_end_scan:		unsigned(10 downto 0) := 524;




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
process (reg_clk) begin
	if rising_edge(reg_clk) then
		if reset_n = '0' then
			startram_low7bits_text <= (others => '0');
			startram_128bytes <= (others => '0');
			graph_mode <= '0';
			font_alt <= '0';
			font_8 <= '0';
		elsif reg_we_n = '0' then
			case reg_a is
				when "00" =>
					startram_low7bits_text <= reg_din(6 downto 0);	-- only in TXT mode it's used!
				when "01" =>
					startram_128bytes <= reg_din;
				when "10" =>
					graph_mode <= reg_din(1);
					font_alt <= reg_din(0);
				when "11" =>
					font_8 <= reg_din(2);
				when others => null;
			end case;
		end if;
	end if;
end process;


-- Now the bulk of the work ...
process (pix_clk) begin
	
	if rising_edge(pix_clk) then
	
	if reset_n = '0' then
		bitpos <= "000";
		--vid_a_buff <= (others => '0'); -- "000100000000000";
		--vid_a_line <= (others => '0'); -- "000100000000000";
		vid_a_buff <= (others => '0');
		chr_a_buff(9 downto 0) <= (others => '0');
		h_cnt <= (others => '0');
		v_cnt <= (others => '0');
	else
		-- maintain actual VGA positions
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
		-- Now, check out important "points" (h_cnt,v_cnt)		
		if h_cnt >= 80 and h_cnt < 80 + 480 and v_cnt >= 176 and v_cnt < 176 + 128 then
			onpanel <= '1';
			if bitpos = "000" then
				bitpos <= "001";
				video_byte <= vid_d_bus;
				chr_a_buff(9 downto 3) <= video_byte(6 downto 0);
				if video_byte(7) = '0' then
					shiftreg <= chrrom_d_bus;
				else
					shiftreg <= chrrom_d_bus xor "11111111";
				end if;
				--vid_a_buff <= vid_a_buff + 1;
				vid_a_buff(6 downto 0) <= vid_a_buff(6 downto 0) + 1;
			else
				if bitpos = bitpos_max then
					bitpos <= "000";
				else
					bitpos <= bitpos + 1;
				end if;
				shiftreg <= shiftreg(6 downto 0) & '-';
			end if;
		else
			onpanel <= '0';
			--bitpos <= "000";
			if h_cnt = 80 + 480 then
				if v_cnt = 176 + 128 - 1 then
					-- end of screen (after the last visible on-panel scanline), set video address to default
					--vid_a_line <= startram_128bytes & startram_low7bits_text;
					vid_a_buff <= startram_128bytes & startram_low7bits_text;
					-- vid_a_buff <= "000100000000000";	-- ugly hack to test: force at $800
					chr_a_buff(2 downto 0) <= "000";
				elsif v_cnt >= 176 and v_cnt < 176 + 128 - 1 then	-- end of display of an on-panel visible line
					-- end of display (visible) scanline line
					if chr_a_buff(2 downto 0) = "111" then
						--vid_a_line <= vid_a_line + 128;
						vid_a_buff(14 downto 7) <= vid_a_buff(14 downto 7) + 1;
						chr_a_buff(2 downto 0) <= "000";
					else
						chr_a_buff(2 downto 0) <= chr_a_buff(2 downto 0) + 1;
						vid_a_buff(6 downto 0) <= startram_low7bits_text;
					end if;
				end if;
				--vid_a_buff <= vid_a_line;
			end if;
		end if;
	end if;
	end if;
end process;

-- Bus address buffers presented
vid_a_bus <= vid_a_buff;
chrrom_a_bus <= chr_a_buff;

-- Setting the bit position counter max based on video mode (8 or 6 pixel, ie 7 or 5)
bitpos_max <= "111" when font_8 = '1' or graph_mode = '1' else "101";

-- Video signal related outputs
hsync <= '0' when h_cnt > 640 + 16 and h_cnt < 640 + 16 + 96 else '1';
vsync <= '0' when v_cnt = 480 + 10 or  v_cnt = 480 + 11 else '1';
pixel <= shiftreg(7);
onscreen <= '1' when h_cnt < 640 and v_cnt < 480 else '0';


end rtl;
