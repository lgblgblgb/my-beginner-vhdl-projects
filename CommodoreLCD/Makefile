WGET		= wget
U102_ROM_URL	= http://github.lgb.hu/xemu/files/kizapr-u102.bin
U103_ROM_URL	= http://github.lgb.hu/xemu/files/sizapr-u103.bin
U104_ROM_URL	= http://github.lgb.hu/xemu/files/sept-M-13apr-u104.bin
U105_ROM_URL	= http://github.lgb.hu/xemu/files/SS-CALC-13apr-u105.bin
CHARGEN_ROM_URL	= http://github.lgb.hu/xemu/files/clcd-chargen.rom
ALL_ROM_NAMES	= clcd-chargen.rom clcd-u102.rom clcd-u103.rom clcd-u104.rom clcd-u105.rom


all:
	@echo "No default target here, sorry" >&2
	@false

clcd-u102.rom:
	$(WGET) -O $@ $(U102_ROM_URL)

clcd-u103.rom:
	$(WGET) -O $@ $(U103_ROM_URL)

clcd-u104.rom:
	$(WGET) -O $@ $(U104_ROM_URL)

clcd-u105.rom:
	$(WGET) -O $@ $(U105_ROM_URL)

clcd-chargen.rom:
	$(WGET) -O $@ $(CHARGEN_ROM_URL)

update_rom: $(ALL_ROM_NAMES)
	../_utility/update_vhdl_array.py $(ALL_ROM_NAMES) < roms.vhdl > roms.vhdl.tmp
	cat roms.vhdl > roms.vhdl.bak
	cat roms.vhdl.tmp > roms.vhdl
	rm roms.vhdl.tmp

strip_rom:
	../_utility/update_vhdl_array.py < roms.vhdl > roms.vhdl.tmp
	cat roms.vhdl > roms.vhdl.bak
	cat roms.vhdl.tmp > roms.vhdl
	rm roms.vhdl.tmp

fpga:
	sudo djtgcfg prog -d Nexys4DDR --index 0 --file CLCD.bit

.PHONY: all update_rom strip_rom fpga
