

        INCLUDE "video.inc"
        INCLUDE "utils.inc"
        INCLUDE "obj/frames.inc"
                

; Video defines

IF DEF(CONFIG) == 0
CONFIG EQU 0
ENDC

IF DEF(PULLDOWN) == 0
PULLDOWN EQU 1.0
ENDC
PULLDOWN_SKIPF EQU (((1.0 - DIV(1.0, PULLDOWN)) + 128) >> 8) & $FF

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
BYTES_PER_HLINE EQU 4
ENDC

PACKETS_PER_VBLK EQU 9

DEF BYTES_PER_VBLANK = ((HSIZE * VSIZE) * 16 / 4) - (144 * BYTES_PER_HLINE)
IF BYTES_PER_VBLANK < 0
DEF BYTES_PER_VBLANK = 0
ENDC
DEF HLINE_PADDING = 144 * BYTES_PER_HLINE * 4 - HSIZE * VSIZE * 16
IF HLINE_PADDING < 0
DEF HLINE_PADDING = 0
ENDC
SCY_OFFSET EQU 0 - (144 - 16 * VSIZE) / 4
        
IF ((BYTES_PER_VBLANK % 4) != 0) || ((BYTES_PER_HLINE * 144) % 4 != 0)
  FAIL "BYTES_PER_VBLANK & BYTES_PER_HLINE * 144 must be multiples of 4"
ENDC

F_COMPRESSED                EQU $18
F_NOT_COMPRESSED            EQU $3E

TIMER_COUNTER_INIT          EQU $100 - (456 / 16)


        SECTION "hram", HRAM
        
Cycle:                        DS 1
FrameFlag:                    DS 1
BankswitchPending:            DS 1      ; compressed metaframes only
PulldownCounter:              DS 1
CompressedFlagSaved:          DS 1

DEF HBlankEntry         EQUS "(HBlank+HBlankEntryOffset)"
DEF CurVideoBankLow     EQUS "(HBlank+HBlankCurVideoBankLowOffset)"
IF DEF(MBC3) == 0
DEF CurVideoBankHigh    EQUS "(HBlank+HBlankCurVideoBankHighOffset)"
ENDC
DEF CurSrcAddr          EQUS "(HBlank+HBlankCurSrcAddressOffset)"
DEF CurDestAddr         EQUS "(HBlank+HBlankCurDestAddressOffset)"
DEF HBlankSCY           EQUS "(HBlank+HBlankSCYOffset)"
DEF CompressedFlag      EQUS "(HBlank+HBlankCompressedFlagOffset)"
DEF HBlankSelfmodJump   EQUS "(HBlank+HBlankSelfmodJumpOffset)"
DEF DeltaPacketCount    EQUS "(HBlank+HBlankDeltaPacketCountOffset)"
DEF AudioProcAddr       EQUS "(HBlank+HBlankAudioProcAddrOffset)"
DEF AudioBankLow        EQUS "(HBlank+HBlankAudioBankLowOffset)"
DEF AudioBankHigh       EQUS "(HBlank+HBlankAudioBankHighOffset)"
DEF AudioProcReturn     EQUS "(HBlank+HBlankAudioProcReturnOffset)"
DEF TimerEntry          EQUS "(HBlank+HBlankTimerEntryOffset)"

        SECTION "stack", WRAM0[$CF00]
        
        DS 256
Stack:
        
        ;  Interrupt vectors
        SECTION "ih_vbl",ROM0[$40]
        
VBlankInt:
        ei
        ld a,TIMER_COUNTER_INIT
        ldh [$05],a
        jp VBlank

        
        SECTION "ih_lcdc",ROM0[$48]
        
LCDCInt:     
        ld a,1
        ldh [$05],a
        jr HBlankEntry   
        
        
        SECTION "ih_timer",ROM0[$50]
        
TimerInt:                        
        jp TimerEntry
        
        
        SECTION "ih_sio",ROM0[$58]
        
SerialIOInt:                        
        reti    
        
        
        SECTION "ih_joy",ROM0[$60]
        
JoypadInt:                        
        reti

        
        SECTION "header",ROM0[$100]
        
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
        IF DEF(MBC3) == 0
        DB $19          ;Cartridge type
        ELSE
        DB $11
        ENDC
        DB 0            ;ROM size
        DB 0            ;RAM size
        DB $00          ;Destination code
        DB $00          ;Licensee Code
        DB $01          ;Version number
        DB $00          ;Header checksum
        DB $00,$00      ;Global checksum
        
        
        SECTION "main_code",ROM0
        
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
        ldh [$40],a         ; Disable LCDC
        
        ld de,HBlank
        ld hl,HBlankTemplate
        ld bc,HBT_end - HBlankTemplate    ; Copy the HBlank procedure in HRAM
        call Copy                         ; as it is self-modifying
        
        ld a,$FF
        ld bc,16
        ld hl,$8BF0
        call Fill           ; Create a black tile for the backdrop (index $BF)       
        
        ld a,$BF
        ld bc,(32*32)*2
        ld hl,$9800
        call Fill           ; Fill all the pattern tables with the backdrop tile
        
        ld c,HSIZE
        ld b,VSIZE
        ld e,0
        ld hl,$9800
        call MakePictureRectangle3      ; Pictures 0-1 pattern table
        
        ld c,HSIZE
        ld b,VSIZE
        ld e,$C0
        ld hl,$9C00
        call MakePictureRectangle3      ; Pictures 2-3 pattern table
        
        ld hl,Frame+4                   ; Assume the first metaframe is literal
        ld de,$8000
        ld bc,(HSIZE * VSIZE) * 16 + HLINE_PADDING
        call Copy                       ; Upload pictures 0-1 with the LCDC off
        
        ld a,F_NOT_COMPRESSED
        ldh [CompressedFlag],a          ; The 2nd metaframe must also be literal
        ldh [CompressedFlagSaved],a
        
        ld bc,4                         ; Skip the second metaframe header
        add hl,bc                       ; (it must be 0,0,0,0)
        ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a            ; Initialize the src address
        
        xor a
        ldh [CurDestAddr],a
        ld a,$8C
        ldh [CurDestAddr+1],a           ; Initialize the dest address
        
        ld a,1
        ldh [CurVideoBankLow],a
        ld [$2222],a
        IF DEF(MBC3) == 0
        xor a
        ldh [CurVideoBankHigh],a        ; Initialize the bank counters & sync
        ld [$3333],a                    ; them with the MBC
        ENDC
        
        ld a,4                          ; Initialize the frame down-counter
        ldh [Cycle],a                   ; (counts for next metaframe)
        
        ; Reset the APU
        xor a
        ldh [$26], a
        ld a, $FF
        ldh [$26], a
        ; Turn all DACs on
        ldh [$12], a
        ldh [$17], a
        ldh [$1A], a
        ldh [$21], a
        ; Put all channels on both left and right
        ldh [$25], a
        
        ld a,1
        ldh [$05],a
        ld a,TIMER_COUNTER_INIT
        ldh [$06],a
        ld a,%0000_0101
        ldh [$07],a
        
        ld a,$FF
        ldh [$47],a             ; All black palette
      
        ld a,$91
        ldh [$40],a             ; LCDC on!
        
.wfvbl: ldh a,[$44]
        cp $95                  ; Wait one full frame because the first frame
        jr nz,.wfvbl            ; may skip one HBlank interrupt
        
        ld a,$CC
        ldh [$47],a             ; Initialize palette
        ld a,$08
        ldh [$41],a             ; Select HBlank as LCDC interrupt source
        ld a,%0000_0111
        ldh [$FF],a             ; Enable LCDC interrupts and VBL interrupts
        ld a,SCY_OFFSET
        ldh [$42],a             ; Scroll up a bit for creating the bars
        xor a                   ; Clear the interrupt flag (no spurious
        ldh [$0F],a             ; interrupts please)
        
        ld hl,CurSrcAddr
        ld a,[hl+]
        ld d,[hl]
        ld e,a
        ld hl,CurDestAddr
        ld a,[hl+]
        ld h,[hl]
        ld l,a
        ld bc,$4000
        
        ei                      ; Interrupts on!

.l2:    halt
        jr .l2
        
        ld a,e
        or d
        jr nz,.l2
        di
.stop:  halt
        jr .stop
        
        
        
NextBank:
        ldh a,[CurVideoBankLow]
        inc a
        ldh [CurVideoBankLow],a
        ld [$2222],a
        IF DEF(MBC3) == 0
        ret nz
        ldh a,[CurVideoBankHigh]
        inc a
        ldh [CurVideoBankHigh],a
        ld [$3333],a
        ENDC
        ret
        
        
        
VBlank: ;push af
        ;push bc
        ;push de
        ;push hl
        
        ld a,l
        ldh [CurDestAddr],a
        ld a,h
        ldh [CurDestAddr+1],a
        ld hl,CurSrcAddr
        ld a,e
        ld [hl+],a
        ld [hl],d
        
        ldh a,[CurVideoBankLow]
        ld [$2222],a
        IF DEF(MBC3) == 0
        ldh a,[CurVideoBankHigh]
        ld [$3333],a
        ENDC
        
        ld a,1                      ; Tell the main thread that a frame
        ldh [FrameFlag],a           ; has passed
        
        ldh a,[PulldownCounter]
        add PULLDOWN_SKIPF
        ldh [PulldownCounter],a
        jp c,.freeze_frame
        
        ldh a,[CompressedFlagSaved]
        ldh [CompressedFlag],a
        cp F_COMPRESSED             ; If this frame is compressed, go to the
        jp z,.vbl_compression       ; decompression code
        
        ld hl,CurDestAddr
        ld a,[hl+]
        ld e,a
        ld d,[hl]                   ; Load destination address
        
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
.nobsA1:ld l,[hl]                   ; Load source address or bankswitch
        ld h,a                      ; if not enough bytes in this bank
        
.bseA:  
        REPT BYTES_PER_VBLANK / 4
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
        inc de                      ; Copy the uncompressed block via
        ENDR                        ; unrolled loop
        
        ld a,SCY_OFFSET
        ldh [$42],a                 
        dec a                       
        ldh [HBlankSCY],a           ; Reset the scroll and the
        ld a,$18                    ; counters used by the HBlank thread,
        ldh [HBlankSelfmodJump],a   ; for the stretch raster effect
        
        ldh a,[Cycle]
        dec a
        ldh [Cycle],a
        jr nz,.no_nextcycle
        
        ldh a,[BankswitchPending]
        and a
        jr z,.nextcycle
        
        call NextBank
        ld hl,$4000
        jr .nextcycle
        
.no_nextcycle:
        ld a,h
        cp ($8000 - 144*BYTES_PER_HLINE) >> 8
        ld a,l
        jr c,.nobsB
        jr nz,.bsB
        cp ($8000 - 144*BYTES_PER_HLINE) & $FF
        jr c,.nobsB
        jr z,.nobsB
.bsB:   call NextBank
        ld hl,$4000
.nobsB: ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        
        ldh a,[Cycle]
        rra
        jr c,.nochgpal
        ld a,$F0
        ldh [$47],a

.nochgpal:        
        ld hl,CurDestAddr
        ld a,e
        ld [hl+],a
        ld [hl],d
        jp .vblank_exit
        
        
        ; Reset the addresses for the next 4 frame upload cycle
        ; HL = source address for next metaframe
.nextcycle:
        ld a,[hl+]                ; Read stop flag
        and a
        jr nz,.end_video          ; Stop flag != 0 => end the video
        ld a,[hl+]                ; Read compression flag
        ldh [CompressedFlag],a
        ldh [CompressedFlagSaved],a
        ld a,[hl+]
        ldh [BankswitchPending],a
        inc hl
        
        ldh a,[CompressedFlag]
        cp $18
        jr nz,.nc_nofirstcompressedpacket
        
        ld a,[hl+]
        ldh [DeltaPacketCount],a
        ld a,[hl+]
        ldh [BankswitchPending],a
        inc hl
        inc hl
        
.nc_nofirstcompressedpacket:
        ld a,l
        ldh [CurSrcAddr],a
        ld a,h
        ldh [CurSrcAddr+1],a
        
        ld hl,CurDestAddr
        xor a
        ld [hl+],a
        ld a,[hl]
        cp $8C
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
        
        jp .vblank_exit
        
.end_video:
        xor a
        ldh [CurSrcAddr], a         ; Set the src address to zero so that we'll
        ldh [CurSrcAddr+1], a       ; remember that we stopped
        
        ldh [DeltaPacketCount], a   ; When compression is enabled and the delta
        ld a,F_COMPRESSED           ; packet count is zero, the HBlank thread
        ldh [CompressedFlag], a     ; is idle
        ldh [CompressedFlagSaved], a
        
        ld bc,Silence               ; Set sound playback address to a zeroed area
        
        jp .vblank_exit
        
        
.vbl_compression:
        ld hl,CurSrcAddr
        ld a,[hl+]
        ld e,a
        ld d,[hl]                   ; Read the last source address in DE
        
        or d                        ; Destination address == 0
        jp z,.video_ended           ; => video has already ended!
        
        ldh a,[BankswitchPending]
        and a
        jr z,.c_nextpacket
        
        call NextBank
        ld de,$4000

.c_nextpacket:
        ld a,[de]
        inc e
        inc a
        ld l,a              ; Read the packet count in the block head
        ld a,[de]
        ldh [BankswitchPending],a
        inc e               ; Read the bankswitch flag in the block head
        inc e
        inc de              ; Skip the rest of the block head
        
        dec l
        jp z,.c_end2         ; Empty block, skip everyting
        
        ld a,PACKETS_PER_VBLK
        sub l
        swap a
        ld h,a
        and $F0
        add LOW(.c_copy)
        ld l,a
        ld a,h
        jr nc,.c_nocarry
        inc a
.c_nocarry:
        and $0F
        add HIGH(.c_copy)
        ld h,a
        push hl

        ld hl,CurDestAddr
        ld a,[hl+]
        ld h,[hl]
        ld l,a               ; Load the destination address
        
        ret                  ; jump inside the copy unrolled loop
.c_copy:
        REPT PACKETS_PER_VBLK
        ld a,[de]
        inc e
        add l
        DB $30, 1   ;jr nc,+1
        inc h
        ld l,a
        ld a,[de]
        ld [hl+],a
        inc e
        ld a,[de]
        ld [hl+],a
        inc e
        ld a,[de]
        ld [hl+],a
        inc de          
        ENDR        ; 16 bytes per iteration!
        
.c_end:
        ld a,l
        ldh [CurDestAddr],a
        ld a,h
        ldh [CurDestAddr+1],a
        
.c_end2:
        ld a,SCY_OFFSET
        ldh [$42],a
        dec a
        ldh [HBlankSCY],a
        ld a,$18
        ldh [HBlankSelfmodJump],a
        
        ldh a,[BankswitchPending]
        and a
        jr z,.c_nobankswitch2
        
        call NextBank
        ld de,$4000
        
.c_nobankswitch2:
        ldh a,[Cycle]
        dec a
        ldh [Cycle],a
        jr nz,.c_nonextcycle
        
        ld h,d
        ld l,e
        jp .nextcycle
        
.c_nonextcycle:
        rra
        jr c,.c_nochgpal
        ld a,$F0
        ldh [$47],a

.c_nochgpal: 
        ld a,[de]
        ldh [DeltaPacketCount],a
        inc e
        ld a,[de]
        ldh [BankswitchPending],a
        inc e
        inc e
        inc de
        
        ld hl,CurSrcAddr
        ld a,e
        ld [hl+],a
        ld [hl],d        
        
        jp .vblank_exit
        
        
.video_ended:
        ld a,SCY_OFFSET
        ldh [$42],a
        dec a
        ldh [HBlankSCY],a
        ld a,$18
        ldh [HBlankSelfmodJump],a
        
        jp .vblank_exit
        
        
.freeze_frame:
        xor a
        ldh [DeltaPacketCount],a
        ld a,F_COMPRESSED
        ldh [CompressedFlag],a
        ld a,SCY_OFFSET
        ldh [$42],a
        dec a
        ldh [HBlankSCY],a
        ld a,$18
        ldh [HBlankSelfmodJump],a
        
.vblank_exit:
        ld hl,CurSrcAddr
        ld a,[hl+]
        ld d,[hl]
        ld e,a
        ld hl,CurDestAddr
        ld a,[hl+]
        ld h,[hl]
        ld l,a
        ;pop hl
        ;pop de
        ;pop bc
        ;pop af
        reti
        
        
        
        SECTION "video_engine_template", ROM0

HBlankTemplate:
HBT_compressed:
        ldh a,[$44]         ; Use LY to count the packets already done
HBT_counter:                ; CompressionPacketCount - 1
        cp 255
        jr nc,HBT_endj
        
        ld a,[de]
        inc e
        add l
        ld l,a
        jr c,.carry
        REPT 2
        ld a,[de]
        ld [hl+],a
        inc e
        ENDR
        ld a,[de]
        ld [hl+],a
        inc de
        
        jr HBT_commend
    
.carry: inc h
        REPT 2
        ld a,[de]
        ld [hl+],a
        inc e
        ENDR
        ld a,[de]
        ld [hl+],a
        inc de
        
HBT_commend:
        ;ld a,l
        ;ldh [CurDestAddr],a
        ;ld a,h
        ;ldh [CurDestAddr+1],a
        
HBT_endj:                 ; HBlankSelfmodJump
        jr HBT_end_noscroll           ; This offset must be $18
        ldh [HBlankSelfmodJump],a     ; A == $18!
        ldh a,[HBlankSCY]
        dec a
        ldh [HBlankSCY],a
HBT_exit:
HBT_TimerEntry:
        push af
HBT_AudioBankLow:
        ld a,LOW(NUM_VIDEO_BANKS+1)
        ld [$2222],a
        IF DEF(MBC3) == 0
HBT_AudioBankHigh:
        ld a,HIGH(NUM_VIDEO_BANKS+1)
        ld [$3333],a
        ENDC
HBT_AudioProcAddr:
        jp AudioFrame
        
        IF DEF(MBC3) == 0
        REPT 3                    ; Add some padding to make sure that the
        nop                       ; jump at HBT_endj has $18 as argument so that
        ENDR                      ; it becomes a ld a,$18 if it's not taken
        ELSE
        REPT 8                    ; Add some padding to make sure that the
        nop                       ; jump at HBT_endj has $18 as argument so that
        ENDR                      ; it becomes a ld a,$18 if it's not taken
        ENDC
        
HBT_end_noscroll:
        ld a,$3E
        ldh [HBlankSelfmodJump],a
        jr HBT_exit
        
HBT_AudioProcReturn:
HBT_VideoBankLow:
        ld a,$00
        ld [$2222],a
        IF DEF(MBC3) == 0
HBT_VideoBankHigh:
        ld a,$00
        ld [$3333],a
        ENDC
        pop af
        reti
        
HBT_Entry:
        
;HBT_csrc:                 ; CurSrcAddr - 1
        ;ld de,60000
;HBT_cdest:                ; CurDestAddr - 1
;        ld hl,60000
        
HBT_scy:                  ; HBlankSCY - 1
        ld a,SCY_OFFSET-1
        ldh [$42],a
        
HBT_cjmp:                 ; CompressedFlag
        jr HBT_compressed

HBT_notcompr: 
        IF BYTES_PER_HLINE == 4
        REPT 3
        ld a,[de]
        ld [hl+],a
        inc e
        ENDR
        ELSE
        REPT 2
        ld a,[de]
        ld [hl+],a
        inc de
        ENDR
        ENDC
        ld a,[de]
        ld [hl+],a
        inc de
        
        jr HBT_commend
HBT_csrc:                 ; CurSrcAddr - 1
        ld de,60000
HBT_cdest:                ; CurDestAddr - 1
        ld hl,60000
HBT_end:
        
        
RealHBlankProcSize                  EQU HBT_end - HBlankTemplate
HBlankEntryOffset                   EQU HBT_Entry - HBlankTemplate
HBlankCurVideoBankLowOffset         EQU HBT_VideoBankLow - HBlankTemplate + 1
IF DEF(MBC3) == 0
HBlankCurVideoBankHighOffset        EQU HBT_VideoBankHigh - HBlankTemplate + 1
ENDC
HBlankCurSrcAddressOffset           EQU HBT_csrc - HBlankTemplate + 1
HBlankCurDestAddressOffset          EQU HBT_cdest - HBlankTemplate + 1
HBlankSCYOffset                     EQU HBT_scy - HBlankTemplate + 1
HBlankCompressedFlagOffset          EQU HBT_cjmp - HBlankTemplate
HBlankSelfmodJumpOffset             EQU HBT_endj - HBlankTemplate
HBlankDeltaPacketCountOffset        EQU HBT_counter - HBlankTemplate + 1
HBlankAudioProcAddrOffset           EQU HBT_AudioProcAddr - HBlankTemplate + 1
HBlankAudioBankLowOffset            EQU HBT_AudioBankLow - HBlankTemplate + 1
IF DEF(MBC3) == 0
HBlankAudioBankHighOffset           EQU HBT_AudioBankHigh - HBlankTemplate + 1
ENDC
HBlankAudioProcReturnOffset         EQU HBT_AudioProcReturn - HBlankTemplate
HBlankTimerEntryOffset              EQU HBT_TimerEntry - HBlankTemplate


        SECTION "video_engine", HRAM[$FFFE-RealHBlankProcSize]
    
HBlank:                 DS RealHBlankProcSize
        

        SECTION "audio_frame_handlers", ROM0[$0000]
       
AudioFrame:
        ld a,[bc]
        ldh [$24],a
        inc bc
        bit 7,b
        jr z,AudioProcReturn
        ld b,$40
        ldh a,[AudioBankLow]
        inc a
        ldh [AudioBankLow],a
        IF DEF(MBC3) == 0
        jr nz,AudioProcReturn
        ldh a,[AudioBankHigh]
        inc a
        ldh [AudioBankHigh],a
        ENDC
        jr AudioProcReturn
        
        
        SECTION "silence", ROM0
        
Silence: DS 200

      
        SECTION "data", ROM0[$4000]
        
Frame:  DB 0
        
        
