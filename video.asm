

        INCLUDE "video.inc"
        INCLUDE "utils.inc"
        
        
IF DEF(CONFIG) == 0
CONFIG EQU 0
ENDC

HSIZE EQU 20
IF CONFIG == 0
VSIZE EQU 9
BYTES_PER_HLINE EQU 4
ENDC
IF CONFIG == 1
VSIZE EQU 8
BYTES_PER_HLINE EQU 4
ENDC
IF CONFIG == 2
VSIZE EQU 7
BYTES_PER_HLINE EQU 3
ENDC

BYTES_PER_VBLANK EQU ((HSIZE * VSIZE) * 16 / 4) - (144 * BYTES_PER_HLINE)
SCY_OFFSET EQU 0 - (144 - 16 * VSIZE) / 4
        
IF ((BYTES_PER_VBLANK % 4) != 0) || ((BYTES_PER_HLINE * 144) % 4 != 0)
  FAIL "BYTES_PER_VBLANK & BYTES_PER_HLINE * 144 must be multiples of 4"
ENDC


        SECTION "main_var", HRAM
        
Cycle:      DS 1
CurBank:    DS 2


        SECTION "stack", BSS[$CF00]
        
        DS 256
Stack:
        
        ;  Interrupt vectors
        SECTION "ih_vbl",HOME[$40]
        
VBlankInt:
        jp VBlank

        
        SECTION "ih_lcdc",HOME[$48]
        
LCDCInt:     
        jp HBlank   
        
        
        SECTION "ih_timer",HOME[$50]
        
TimerInt:                        
        reti
        
        
        SECTION "ih_sio",HOME[$58]
        
SerialIOInt:                        
        reti    
        
        
        SECTION "ih_joy",HOME[$60]
        
JoypadInt:                        
        reti

        
        SECTION "header",HOME[$100]
        
Header:                 
        nop             
        jp Initialize 
        
        DB $CE,$ED,$66,$66,$CC,$0D,$00,$0B 
        DB $03,$73,$00,$83,$00,$0C,$00,$0D 
        DB $00,$08,$11,$1F,$88,$89,$00,$0E 
        DB $DC,$CC,$6E,$E6,$DD,$DD,$D9,$99 
        DB $BB,$BB,$67,$63,$6E,$0E,$EC,$CC 
        DB $DD,$DC,$99,$9F,$BB,$B9,$33,$3E 
        
        ;   123456789012345
        DB "1BPPVIDEO",0,0,0,0,0,0
        DB $00          ;CGB flag
        DB 0,0          ;New Licensee Code
        DB 0            ;SGB flag
        DB $19          ;Cartridge type
        DB 0            ;ROM size
        DB 0            ;RAM size
        DB $00          ;Destination code
        DB $00          ;Licensee Code
        DB $01          ;Version number
        DB $00          ;Header checksum
        DB $00,$00      ;Global checksum
        
        
        SECTION "main_code",HOME
        
Initialize:  
        di
        ld sp,$FFFE
        
        ld hl,$C000        ;   Clear RAM and WRAM
        xor a              ;Clear from C000 with 00
.rambl: ld [hl+],a         ;Clear four bytes (this way is faster)
        ld [hl+],a
        ld [hl+],a
        ld [hl+],a
        bit 5,h            
        jr z,.rambl         ;If next byte address is not E000 then continue
        
        ld sp,Stack
        
        ld c,$7F
        ld hl,$FF80
.hirbl: ld [hl+],a
        dec c              ;Clear one byte
        jr nz,.hirbl       ;If 7E bytes hasn't been copied, then continue
        
.wvblk: ld a,[$FF44]       ;Read LCDC vertical position
        cp $90
        jr nz,.wvblk       ;Loop until it is just inside VBlank
        
        xor a
        ldh [$40],a
        
        ld de,HBlank
        ld hl,HBlankTemplate
        ld bc,HBT_end - HBlankTemplate
        call Copy
        
        ld a,$FF
        ld bc,16
        ld hl,$8BF0
        call Fill
        
        ld a,$BF
        ld bc,(32*32)*2
        ld hl,$9800
        call Fill
        
        ld c,HSIZE
        ld b,VSIZE
        ld e,0
        ld hl,$9800
        call MakePictureRectangle3
        
        ld c,HSIZE
        ld b,VSIZE
        ld e,$C0
        ld hl,$9C00
        call MakePictureRectangle3
        
        ld hl,Frame
        ld de,$8000
        ld bc,(HSIZE * VSIZE) * 16
        call Copy
        
        ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        
        xor a
        ldh [CurDestAddr],a
        ld a,$8C
        ldh [CurDestAddr+1],a
        
        ld a,1
        ldh [CurBank],a
        ld [$2222],a
        xor a
        ldh [CurBank+1],a
        ld [$3333],a
        
        ld a,4
        ldh [Cycle],a
        
        ld a,$CC
        ldh [$47],a
        ld a,$08
        ldh [$41],a
        ld a,$03
        ldh [$FF],a
        xor a
        ldh [$0F],a
        ld a,SCY_OFFSET
        ldh [$42],a
        ei
        
        ld a,$91
        ldh [$40],a
                
.l:     halt
        jr .l
        
        
        
NextBank:
        ld hl,CurBank
        ld a,[hl]
        inc a
        ld [hl+],a
        ld [$2222],a
        ret nz
        ld a,[hl]
        inc a
        ld [hl],a
        ld [$3333],a
        ret
        
        
        
VBlank: push af
        push bc
        push de
        push hl
        
        ld hl,CurDestAddr
        ld a,[hl+]
        ld e,a
        ld d,[hl]
        
        ld l,(CurSrcAddr+1) & $FF
        ld a,[hl-]
        cp ($8000 - BYTES_PER_VBLANK) >> 8
        jr c,.nobsA1
        jr nz,.bsA
        ld a,[hl+]
        cp ($8000 - BYTES_PER_VBLANK) & $FF
        jr c,.nobsA2
        jr z,.nobsA2
.bsA:   call NextBank
        ld hl,$4000
        jr .bseA
.nobsA2:ld a,[hl-]
.nobsA1:ld l,[hl]
        ld h,a
        
.bseA:  REPT BYTES_PER_VBLANK / 4
        ld a,[hl+]
        ld [de],a
        inc e
        ld a,[hl+]
        ld [de],a
        inc e
        ld a,[hl+]
        ld [de],a
        inc e
        ld a,[hl+]
        ld [de],a
        inc de
        ENDR
        
        ld a,SCY_OFFSET
        ldh [$42],a
        dec a
        ldh [HBlankSCY],a
        ld a,$18
        ldh [HBlankSelfmodJump],a
        
        ld a,h
        cp ($8000 - 144*BYTES_PER_HLINE) >> 8
        ld a,l
        jr c,.nobsB
        jr nz,.bsB
        cp ($8000 - 144*BYTES_PER_HLINE) & $FF
        jr c,.nobsB
        jr z,.nobsB
.bsB:   call NextBank
        xor a
        ld h,$40
.nobsB: ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        
        ld c,Cycle & $FF
        ld a,[c]
        dec a
        ld [c],a
        jr z,.nextcycle
        
        rra
        jr c,.nochgpal
        ld a,$F0
        ldh [$47],a

.nochgpal:        
        ld hl,CurDestAddr
        ld a,e
        ld [hl+],a
        ld [hl],d
        
        pop hl
        pop de
        pop bc
        pop af
        reti
        
.nextcycle:
        ld hl,CurDestAddr
        xor a
        ld [hl+],a
        ld a,[hl]
        cp $90
        sbc a
        and $0C
        or $80
        ld [hl],a
        
        ld a,$CC
        ldh [$47],a
        ld hl,$FF40
        ld a,$18
        xor [hl]
        ld [hl],a
        
        ld a,4
        ldh [Cycle],a
        
        pop hl
        pop de
        pop bc
        pop af
        reti
        
        

HBlankTemplate:
        push af
        push de
        push hl
        
HBT_csrc:
        ld hl,60000
HBT_cdest:
        ld de,60000
        
        IF BYTES_PER_HLINE == 4
        REPT 3
        ld a,[hl+]
        ld [de],a
        inc e
        ENDR
        ld a,[hl+]
        ld [de],a
        inc de
        ELSE
        REPT 3
        ld a,[hl+]
        ld [de],a
        inc de
        ENDR
        ENDC
        
HBT_scy:
        ld a,SCY_OFFSET-1
        ldh [$42],a
        
        ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        ld hl,CurDestAddr
        ld a,e
        ld [hl+],a
        ld [hl],d
        
HBT_endj:
        jr .end
        ld hl,HBlankSCY
        dec [hl]
        ld l,HBlankSelfmodJump & $FF
        ld [hl],$18
        jr .end2
.end:   ld a,$3E
        ldh [HBlankSelfmodJump],a
.end2:  pop hl
        pop de
        pop af
        reti
HBT_end:
        
        
RealHBlankProcSize          EQU HBT_end - HBlankTemplate
HBlankCurSrcAddressOffset   EQU HBT_csrc - HBlankTemplate + 1
HBlankCurDestAddressOffset  EQU HBT_cdest - HBlankTemplate + 1
HBlankSCYOffset             EQU HBT_scy - HBlankTemplate + 1
HBlankSelfmodJumpOffset     EQU HBT_endj - HBlankTemplate



        SECTION "hblank_copier", HRAM
    
HBlank:           DS HBlankCurSrcAddressOffset
CurSrcAddr:       DS 2
                  DS HBlankCurDestAddressOffset - HBlankCurSrcAddressOffset - 2
CurDestAddr:      DS 2
                  DS HBlankSCYOffset - HBlankCurDestAddressOffset - 2
HBlankSCY:        DS 1
                  DS HBlankSelfmodJumpOffset - HBlankSCYOffset - 1
HBlankSelfmodJump:DS 1
                  DS RealHBlankProcSize - HBlankSelfmodJumpOffset
      
      
      
        SECTION "data", ROMX[$4000]
        
        
        
Frame:  DB 0
        
        
