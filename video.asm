

        INCLUDE "video.inc"
        INCLUDE "utils.inc"
        

        SECTION "main_var", HRAM
        
Cycle:  DS 1


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
        DB 0            ;Cartridge type
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
        
        ld c,20
        ld b,9
        ld e,0
        ld hl,$9800
        call MakePictureRectangle3
        
        ld c,20
        ld b,9
        ld e,$C0
        ld hl,$9C00
        call MakePictureRectangle3
        
        ld a,Frame & $FF
        ld [CurSrcAddr],a
        ld a,Frame >> 8
        ld [CurSrcAddr+1],a
        
        ld a,$00
        ld [CurDestAddr],a
        ld a,$80
        ld [CurDestAddr+1],a
        
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
        ei
        
        ld a,$91
        ldh [$40],a
                
.l:     halt
        jr .l
        
        
        
VBlank: push af
        push de
        push hl
        
        ld hl,CurDestAddr
        ld a,[hl+]
        ld e,a
        ld d,[hl]
        ld l,CurSrcAddr & $FF
        ld a,[hl+]
        ld h,[hl]
        ld l,a
        
        REPT 36
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
        
        xor a
        ldh [$42],a
        ldh [HBlankSCY],a
        ld a,$18
        ldh [HBlankSelfmodJump],a
        
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
        ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        ld hl,CurDestAddr
        ld a,e
        ld [hl+],a
        ld [hl],d
        
        pop hl
        pop de
        pop af
        reti
        
.nextcycle:
        ld a,$CC
        ldh [$47],a
        ld hl,$FF40
        ld a,$18
        xor [hl]
        ld [hl],a
        
        ld a,Frame & $FF
        ld [CurSrcAddr],a
        ld a,Frame >> 8
        ld [CurSrcAddr+1],a
        
        ld l,CurDestAddr & $FF
        xor a
        ld [hl+],a
        ld a,[hl]
        cp $90
        sbc a
        and $0C
        or $80
        ld [hl],a
        
        ld a,4
        ldh [Cycle],a
        
        pop hl
        pop de
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
        
HBT_scy:
        ld a,$00
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
        
        
        
Frame:  INCBIN "1.bin"
        INCBIN "1.bin"
        
        
