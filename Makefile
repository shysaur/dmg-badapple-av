RGB_AS ?=	rgbasm
RGB_LINK ?=	rgblink
RGB_AR ?=	rgblib
CONFIG ?=	0
FIT ?=	auto
PULLDOWN ?=	1.0
ASFLAGS +=	

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

OUTPUT =	video.gb
OUTPUT_GBS =	music.gbs
OBJDIR =	obj
FRAMESDIR ?=	frames
FRAMEEXT ?=	bmp

ASM_SRC = 	video.asm \
	utils.asm
MDATA_SRC =	musicdata2.asm
MUSIC_SRC = 	m_control.asm \
	m_player.asm \
	m_sfx.asm \
	m_pshare.asm
GBS_SRC =	m_gbsglue.asm
	
DEPS =	video.inc \
	utils.inc \
	frames2data.py \
	m_config.inc \
	musicdata.inc \
	music.inc

MDATA_OBJ =	$(patsubst %, $(OBJDIR)/%, $(MDATA_SRC:.asm=.o))
MUSIC_OBJ =	$(patsubst %, $(OBJDIR)/%, $(MUSIC_SRC:.asm=.o)) $(MDATA_OBJ)
GBS_OBJ =	$(patsubst %, $(OBJDIR)/%, $(GBS_SRC:.asm=.o)) $(MUSIC_OBJ) 
ASM_OBJ =	$(patsubst %, $(OBJDIR)/%, $(ASM_SRC:.asm=.o)) $(MUSIC_OBJ)
	
all:	$(OBJDIR) $(OUTPUT) $(OUTPUT_GBS)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o:	%.asm $(DEPS)
	$(RGB_AS) -o $@ -D CONFIG=$(CONFIG) -D PULLDOWN=$(PULLDOWN) $(ASFLAGS) $<

$(OBJDIR)/frames.bin:	$(FRAMESDIR) $(DEPS)
	./frames2data.py -o $@ -y $(HEIGHT) -i $(VBLKBYTES) -p $(FIT) -v $(FRAMESDIR)/%d.$(FRAMEEXT) -c $(PULLDOWN)

$(OBJDIR)/code.bin: 	$(ASM_OBJ) $(DEPS)
	$(RGB_LINK) -t -o $@ -n $(OUTPUT:.gb=.sym) -m $(OUTPUT:.gb=.map) $(ASM_OBJ)

$(OUTPUT):	$(OBJDIR)/frames.bin $(OBJDIR)/code.bin
	dd bs=16384 count=1 if=$(OBJDIR)/code.bin | cat - $(OBJDIR)/frames.bin > $@
	rgbfix -p00 -v $@

$(OUTPUT_GBS): 	$(GBS_OBJ)
	$(RGB_LINK) -o $(OBJDIR)/gbs.bin -n $(OBJDIR)/gbs.sym $(GBS_OBJ)
	BASE=$$((16#$$(grep _head $(OBJDIR)/gbs.sym | cut -c 4-7))); \
	dd bs=1 if=$(OBJDIR)/gbs.bin of=$@ skip=$$BASE

clean:
	rm -f $(OBJDIR)/*
	rm -f *.lst *.map *.gb *~ *.rel *.cdb *.ihx *.lnk *.sym
