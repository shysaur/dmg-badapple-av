RGB_AS ?=	rgbasm
RGB_LINK ?=	rgblink
RGB_AR ?=	rgblib

OUTPUT =	video.gb
OBJDIR =	obj

ASM_SRC = 	video.asm \
	utils.asm
	
DEPS =	video.inc \
	utils.inc \
	1.bin

ASM_OBJ =	$(patsubst %, $(OBJDIR)/%, $(ASM_SRC:.asm=.o))
	
all:	$(OBJDIR) $(OUTPUT)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o:	%.asm $(DEPS)
	$(RGB_AS) -o $@ $<

$(OUTPUT): 	$(ASM_OBJ)
	$(RGB_LINK) -t -o $@ -n $(@:.gb=.sym) -m $(@:.gb=.map) $(ASM_OBJ)
	rgbfix -p00 -v $@

clean:
	rm -f $(OBJDIR)/*.o
	rm -f *.lst *.map *.gb *~ *.rel *.cdb *.ihx *.lnk *.sym
