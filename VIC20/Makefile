WGET		= wget
KERNAL_ROM_URL	= http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/vic20/kernal.901486-07.bin
BASIC_ROM_URL	= http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/vic20/basic.901486-01.bin
CHRGEN_ROM_URL	= http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/vic20/characters.901460-03.bin
ALL_ROM_NAMES	= kernal.rom basic.rom chrgen.rom

all:
	@echo "No default target here, sorry" >&2
	@false

kernal.rom:
	$(WGET) -O $@ $(KERNAL_ROM_URL)

basic.rom:
	$(WGET) -O $@ $(BASIC_ROM_URL)

chrgen.rom:
	$(WGET) -O $@ $(CHRGEN_ROM_URL)

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
	sudo djtgcfg prog -d Nexys4DDR --index 0 --file VIC20.bit

.PHONY: all update_rom strip_rom fpga
