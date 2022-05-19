ASM = rgbasm
LINK = rgblink
FIX = rgbfix

SOURCES = $(wildcard *.asm)
INCDIRS  = 
WARNINGS = all extra
ASFLAGS  = -p $(PADVALUE) $(addprefix -i,$(INCDIRS)) $(addprefix -W,$(WARNINGS))
LDFLAGS  = -p $(PADVALUE)
FIXFLAGS = -p $(PADVALUE) -v -k "$(LICENSEE)" -l $(OLDLIC) -m $(MBC) -n $(VERSION) -r $(SRAMSIZE) -t $(TITLE)

include project.mk

all: $(ROMNAME)

$(ROMNAME): $(patsubst %.asm,%.o,$(SOURCES))
	$(LINK) $(LDFLAGS) -o $@.$(ROMEXT) -m $@.map -n $@.sym $^
	$(FIX) $(FIXFLAGS) $@.$(ROMEXT)

%.o: %.asm
	$(ASM) $(ASFLAGS) -o $*.o $<
