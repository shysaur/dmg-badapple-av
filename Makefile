RGB_AS?=rgbasm
RGB_LINK?=rgblink
RGB_AR?=rgblib
CONFIG?=0
FIT?=auto
PULLDOWN?=1.0
ASFLAGS+=

HEIGHT=144
VBLKBYTES=144
ifeq ($(CONFIG),1)
  HEIGHT=128
  VBLKBYTES=64
endif
ifeq ($(CONFIG),2)
  HEIGHT=112
  VBLKBYTES=128
endif

OUTPUT=video.gb
OBJDIR=obj
FRAMESDIR?=frames
FRAMEEXT?=bmp

include src/Makefile.in

ASM_OBJ=$(patsubst %, $(OBJDIR)/%, $(ASM_SRC:.asm=.o)) $(MUSIC_OBJ)
	
all: $(OBJDIR) $(OUTPUT) $(OUTPUT_GBS)

$(OBJDIR):
	mkdir -p $(OBJDIR)
	mkdir -p $(OBJDIR)/src

$(OBJDIR)/%.o: %.asm $(DEPS)
	$(RGB_AS) $(INC) -o $@ -D CONFIG=$(CONFIG) -D PULLDOWN=$(PULLDOWN) $(ASFLAGS) $<

$(OBJDIR)/frames.bin: $(FRAMESDIR) $(DEPS)
	./frames2data.py -o $@ -y $(HEIGHT) -i $(VBLKBYTES) -p $(FIT) -v $(FRAMESDIR)/%d.$(FRAMEEXT) -c $(PULLDOWN)

$(OBJDIR)/code.bin: $(ASM_OBJ) $(DEPS)
	$(RGB_LINK) -t -o $@ -n $(OUTPUT:.gb=.sym) -m $(OUTPUT:.gb=.map) $(ASM_OBJ)

$(OUTPUT): $(OBJDIR)/frames.bin $(OBJDIR)/code.bin
	dd bs=16384 count=1 if=$(OBJDIR)/code.bin | cat - $(OBJDIR)/frames.bin > $@
	rgbfix -p00 -v $@

clean:
	rm -r -f $(OBJDIR)
	rm -f *.lst *.map *.gb *~ *.rel *.cdb *.ihx *.lnk *.sym *.gbs
