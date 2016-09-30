

        INCLUDE "video.inc"
        

        SECTION "stack", BSS[$CF00]
        
        DS 256
Stack:

        
        ;  Interrupt vectors
        SECTION "ih_vbl",HOME[$40]
        
VBlankInt:
        reti

        
        SECTION "ih_lcdc",HOME[$48]
        
LCDCInt:     
        reti    
        
        
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
        
.l:     jr .l

        
        
        