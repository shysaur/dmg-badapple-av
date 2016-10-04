RGB_AS ?=	rgbasm
RGB_LINK ?=	rgblink
RGB_AR ?=	rgblib

OUTPUT =	video.gb
OBJDIR =	obj

ASM_SRC = 	video.asm \
	utils.asm
	
DEPS =	video.inc \
	utils.inc \
	frames2data.py

ASM_OBJ =	$(patsubst %, $(OBJDIR)/%, $(ASM_SRC:.asm=.o))
	
all:	$(OBJDIR) $(OUTPUT)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o:	%.asm $(DEPS)
	$(RGB_AS) -o $@ $<

$(OBJDIR)/frames.bin:	frames $(DEPS)
	./frames2data.py -o $@ -v frames/%d.bmp

$(OBJDIR)/code.bin: 	$(ASM_OBJ) $(DEPS)
	$(RGB_LINK) -t -o $@ -n $(OUTPUT:.gb=.sym) -m $(OUTPUT:.gb=.map) $(ASM_OBJ)

$(OUTPUT):	$(OBJDIR)/frames.bin $(OBJDIR)/code.bin
	dd bs=16384 count=1 if=$(OBJDIR)/code.bin | cat - $(OBJDIR)/frames.bin > $@
	rgbfix -p00 -v $@

clean:
	rm -f $(OBJDIR)/*
	rm -f *.lst *.map *.gb *~ *.rel *.cdb *.ihx *.lnk *.sym
