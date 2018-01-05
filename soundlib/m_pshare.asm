

        INCLUDE "m_config.inc"
        
WITH_VIBRATO    EQUS "(BGM_WITH_VIBRATO   || SFX_WITH_VIBRATO   )"
WITH_PITCHBEND  EQUS "(BGM_WITH_PITCHBEND || SFX_WITH_PITCHBEND )"
WITH_SOFTENVEL  EQUS "(BGM_WITH_SOFTENVEL || SFX_WITH_SOFTENVEL )"
WITH_DYNTRACK   EQUS "(BGM_WITH_DYNTRACK  || SFX_WITH_DYNTRACK  )"
WITH_ENVSIM     EQUS "(BGM_WITH_VOLUME    || SFX_WITH_ENVRESTART)"        


        GLOBAL mread

        GLOBAL jump
        GLOBAL varset
        GLOBAL muscc1
        GLOBAL musp2
        
        GLOBAL pitchb
        GLOBAL vibrt
        GLOBAL envels
        
       IF WITH_ENVSIM
        GLOBAL envsim
       ENDC
        
       IF WITH_SOFTENVEL
        GLOBAL SoundEnvelopeTable
       ENDC
        
        
        RSRESET
c_a     RB 2    ;current address (word)
c_t     RB 1    ;timer
c_w     RB 1    ;flags
c_as    RB 2    ;return address
c_ts    RB 1    ;finite loop counter
c_ws    RB 1    ;vibrato sweep
c_en    RB 1    ;envelope
c_ut    RB 1    ;upcounter
c_hf    RB 1    ;high frequency byte
c_lf    RB 1    ;low frequency byte
c_se    RB 1    ;software envelope step
c_dt    RB 1    ;duty
c_pb    RB 1    ;pitch bend frame delta
c_pe    RB 1    ;pitch error
c_vc    RB 1    ;vibrato counter
c_l     RB 1    ;length
c_re    RB 1    ;real envelope
c_sc    RB 1    ;restart flag / simulator counter


IF MUSIC_USE_BANKING
        SECTION "musicdriver_CODE_shared",ROMX,BANK[MUSIC_PLAYER_BANK]
ELSE
        SECTION "musicdriver_CODE_shared",ROM0
ENDC
        
        
        ;   Version ID
        DB "-0.9-"              
        
        
        IF WITH_PITCHBEND
        
        ;   Update pitch bend. HL = chnXpb address
pitchb: ld a,[hl]               ;Load the 4.4 signed fraction 
        and a
        ret z                   ;Return if p.b. = 0 (saves cycles when unused)
        add a                   ;(dfreq per frame)
        sbc a
        and $F0
        ld b,a                  ;Load in B the sign extension for the high byte
        ld a,[hl+]              ;Load the fraction again
        swap a
        ld c,a
        and $F0
        ld d,a                  ;Multiply by 16 to separate the fractional
        xor c                   ; part from the integer part
        or b
        ld c,a                  ;Sign-extend the low byte (integer part)
        ld a,b
        rla
        sbc a                   ;Generate the high byte by extending
        ld b,a                  ; the sign extension
        ld a,d
        add [hl]                ;Add the fractional part to the
        ld [hl],a               ; fractional error
        push af
        ld de,(c_lf-c_pe)
        add hl,de               ;Compute the address of the frequency value
        pop af                  ;(preserving flags)
        ld a,[hl]
        adc c
        ld [hl-],a              ;Add the bend to the low byte of the freq.
        ld a,b
        adc [hl]                ;Add the high byte
        cp $88
        jr nc,.ofl              ;High byte is > $87? overflow, cap to 7FF
        cp $80
        jr c,.undf              ;High byte is < $80? underflow, cap to 000
        ld [hl],a               ;Otherwise write the frequency as is
        ret                     ;Return
.ofl:   ld a,$87
        ld [hl+],a
        ld [hl],$FF             ;Cap frequency to 7FF
        ret
.undf:  ld a,$80
        ld [hl+],a
        ld [hl],$00             ;Cap frequency to 000
        ret
        
        ENDC
        
        
        IF WITH_VIBRATO
        
        ;   Vibrato code (HL = channel ut pointer
        ;                 A  = vibrato descriptor)
        ;The vibrato descriptor has this format:
        ; bits 0-2  delta pitch bend, for each frame (GB freq units / 4)
        ;      3-5  start time (frames * $8 since note attack)
        ;      6-7  frequency (59.73 Hz / 2*n+2)
vibrt:  and a
        ret z                   ;Return if v.d.=0 (saves cycles when unused)
        ld c,a                  ;Save original descriptor
        and $38                 ;Get starting time from vibrato descriptor
        cp [hl]                 ;Compare with the current upcounter
        jr z,vibrt0             ;Initialize vibrato on start
        ret nc                  ;Quit if not reached starting time yet
        
        ld de,(c_vc-c_ut)
        add hl,de               ;Get the address of the vibrato counter
        inc [hl]                ;Increment it
        
        call vibge2
        add a                   ;Get (speed + 1) * 2, in frames
        ld b,[hl]
        res 7,b                 ;Clear reverse flag for comparison with speed
        cp b
        ret nz                  ;Return if the wait frames have not elapsed
        
        bit 7,[hl]              ;Otherwise change pitch bend direction
        jr nz,vibrt1            ;On even period, sweep up

        ld [hl],$80
        call vibget             ;Otherwise sweep down; get the bend delta
        sub b                   ;Cancel previous increment
        sub b                   ;Invert pitch bend. 
        ld [de],a
        ret                     ;Return
        
vibrt1: ld [hl],0
        call vibget             ;Get the bend delta
        add b                   ;Cancel previous decrement
        add b                   ;Invert pitch bend
        ld [de],a
        ret                     ;Return
               
vibrt0: ld de,(c_vc-c_ut)
        add hl,de               ;Get address of the vibrato counter
        call vibge2             ;Get half the speed
        ld [hl],a               ;Initialize the vibrato counter
        call vibget             ;Get the bend delta
        add b                   ;Add to the existing pitch bend (set by $E5)
        ld [de],a
        ret                     ;Return
        
vibge2: ld a,c                  ;Get the speed/2 from the vibrato descriptor
        rlca
        rlca                    ;Get speed bits in first two bits
        and $03                 ;Isolate speed bits
        inc a                  
        ret                     ;Return
        
vibget: ld de,(c_pb-c_vc)
        add hl,de
        ld d,h
        ld e,l                  ;Get the address of the pitch bend register
        ld a,c
        and $07                 ;Extract the bend delta index
        ld c,a
        ld b,0
        ld hl,vibrtt
        add hl,bc               ;Get the bend delta address in the table
        ld b,[hl]               ;Get the bend value in b
        ld a,[de]               ;Load the original pitch bend in A
        ret                     ;Return
        
vibrtt: DB $00, $06, $08, $10, $18, $20, $28, $30, $38, $40

        ENDC
        
        
        IF WITH_SOFTENVEL
        
        ;   Software Envelope (A = envelope   
        ;                      B = upcounter
        ;                      C = env address (FF00+c)
        ;                      D = step)
        ;   Software Envelope (HL = chnXen address)
        ;Output carry clear on envelope change, and D = new step
envels: ld a,[hl+]
        and a
.setc:  scf                   
        ret z                   ;If envelope=0 do nothing (silence)
        cp $10                  ;If envelope >= $10, high Nibble is not zero
        jr nc,.henv             ;it's an hardware envelope, do nothing

        add a
        add (SoundEnvelopeTable - 2) & $FF
        ld e,a
        ld a,(SoundEnvelopeTable - 2) >> 8
        adc 0                   ;Compute the address of the current envelope  
        ld d,a                  ;data address from the envelope index
        ld a,[de]
        ld c,a
        inc de
        ld a,[de]
        ld b,a                  ;Get the address of the envelope data in HL         

        ld a,[bc]               ;Get the envelope step count
        ld de,(c_se - c_ut)
        add hl,de
        cp [hl]
        jr z,.setc              ;If already played all steps, do nothing
        
        ld a,[hl]
        inc a
        add a
        add c
        ld c,a
        ld a,0
        adc b                   ;Get the address of the next step's time
        ld b,a                  ;trigger
                        
        ld a,[bc]               ;Read it
        dec bc
        ld de,(c_ut - c_se)
        add hl,de
        cp [hl]                   
.setc2: scf                     ;If the step trigger's time has not come yet,
        ret nz                  ;return doing nothing
                                
        ld a,[bc]               ;Read the hardware envelope to play
        ld de,(c_re - c_ut)
        add hl,de
        ld [hl],a               ;Put into the appropriate register
        ld de,(c_se - c_re)
        add hl,de
        inc [hl]                ;Update step
        ccf
        ret                     ;Return from Subroutine
        
.henv:  ld b,a
        xor a
        cp [hl]                 ;Harware envelope triggers on note attack
        jr nz,.setc2            ;only (upcounter = 0)
        ld de,(c_re - c_ut)
        add hl,de
        ld [hl],b               ;If upcounter = 0, set the envelope
        ret                     ;Return with carry clear (clear from above)
        
        ENDC
        
        
        IF WITH_ENVSIM
        
        ;   Envelope simulator (HL = chnXre address)
envsim: ld a,[hl+]
        and $07                 ;If real envelope is silence then return
        jr z,.tail2             ;resetting the restart flag
        ld a,[hl]
        cp $80
        jr z,.init              ;If new envelope, initialize the counter
.c:     and $7F                 ;Reset the restart flag
        dec a
        ld [hl-],a              ;Decrement the counter
        ret nz                  ;Return if not yet zero
        
        ld a,[hl]               ;Otherwise simulate volume change:
        bit 3,a
        jr z,.dec               ;Decrement the volume if bit 3 clear
        
        add $10                 ;Increment the volume
        cp $F0
        jr c,.tail              ;Write the value if not to the maximum value
        
.stop:  and $F0
        or $08                  ;Otherwise write the maximum volume with
        ld [hl],a               ;no envelope set
        ret                     ;Return
        
.dec:   sub $10                 ;Decrement the volume
        cp $10
        jr c,.stop              ;If at the maximum value, stop the envelope
        
.tail:  ld [hl+],a              ;Otherwise write the new envelope
        and $07
.tail2: ld [hl],a               ;Reload the counter
        ret                     ;Return
        
        ;Initialize the counter
.init:  dec hl
        ld a,[hl+]                      
        and $07                 ;Get the step length
        jr .c                   ;Go count the first frame
        
        ENDC
        
        
        ;   Set channel 3 sample. Sample index in A.
                                ;   A        D        E
muscc1: swap a                  ;43218765 -------- --------      
        ld d,a                  ;43218765 43218765 --------
        and $F0                 ;4321---- 43218765 --------
        ld e,a                  ;4321---- 43218765 4321----
        xor d                   ;----8765 43218765 4321----
        ld d,a                  ;----8765 ----8765 4321----  DE = A * $10
        ld hl,SoundWaveSamples
        add hl,de               ;Compute sample address
        xor a
        ldh [$1A],a             ;Turn the channel off
        ld c,$30
muscc2: ld a,[hl+]
        ld [$FF00+c],a
        inc c                   ;Store sample
        bit 6,c
        jr z,muscc2             ;Copy the sample in the waveram ($FF30-$FF3F)
        ld a,$80
        ldh [$1A],a             ;Turn the channel back on   
        ldh [$1C],a             ;Silence the channel
        ldh [$1E],a             ;Restart sound playback
        ret                     ;Return

        
        
        ;   Generic jump handler (BC = chnXas address
        ;                         DE = chnXts address
        ;                         HL = note pointer)
jump:   cp $F0
        jr z,jumprt             ;If jump opcode is $F0 then do a "Return"
        cp $FE
        jr z,jumpca             ;If jump opcode is $FE then do a "Call"
        cp $FF       
        jr nz,jumpc             ;If jump opcode is not $FF then counted jump
jumpa:  ld hl,mread+1
        ld a,[hl+]              ;Otherwise simple jump.
        ld h,[hl]              
        ld l,a                  ;Load address to jump to
        or h                    ;Return Z if address was zero
        ret                     ;Play next note at new address 
        
        ;Do a counted jump
jumpc:  ld b,a
        ld a,[de]
        and a                   ;If it is zero, then we have a new jump
        jr z,jumpe              ;Initialize jump counter and jump
        dec a                   ;Decrement finite jump counter          
        jr z,jumpd              ;If it reached zero jump ended, proceed
        ld [de],a               ;Otherwise continuing jump; update the counter
        jr jumpa                ;Jump to the specified address
jumpd:  ld [de],a               ;Save jump counter (zero)
        inc hl
        inc hl                  ;Skip the jump instruction
        inc a                   ;Clear zero flag
        ret                     ;Next note
jumpe:  ld a,b
        and $0F                 ;Save the new jump counter 
        ld [de],a               ;(low nybble of opcode)
        jr jumpa                ;Jump to the specified address
        
        ;Do a sequence call 
jumpca: ld a,l
        ld [bc],a
        inc bc                  
        ld a,h
        ld [bc],a               ;Move current address to return address
        jr jumpa                ;Jump to the specified address

        ;Do a sequence return
jumprt: ld h,b
        ld l,c
        ld a,[hl+]
        ld h,[hl]
        ld l,a                  ;Set HL to the return address 
        inc hl
        inc hl                  ;Skip call address
        or h                    ;Clear Z flag
        ret                     ;Play next note
         
         
        ;   Generic command handler
varset: and $0F
        add a                   ;Get the index in the destination table
        add e
        ld e,a
        ld a,0
        adc d
        ld d,a                  ;Get the address of the destination address
        ld a,[de]
        ld b,a
        inc de
        ld a,[de]
        ld d,a
        ld e,b                  ;Get the destination address 
        ld a,[mread+1]          ;Load the byte to be written (cmd param)
        inc hl
        ld [de],a               ;Write it
        scf                     ;Signal not a note (for musicp)
        ret                     ;Return
        
        
        ;   Parse a note/silence. B = note/command, C = transpose
        ;Output: carry set on meta-note, EC = frequency, B = note/command
musp2:  ld a,b
        and $7F
        cp $48
        jr z,.sil               ;If note = $48, silence
        jr nc,.raw              ;If $49, raw frequency
         
        ;Note      
        add c                   ;Transpose the note
        add a
        add notedt & $FF
        ld e,a
        ld a,0
        adc notedt >> 8
        ld d,a                  ;Get the address of the frequency in DE
        ld a,[de]
        ld c,a
        inc de
        ld a,[de]
        ld e,a                  ;Load the frequency in EC
        xor a
        ret                     ;Return with carry clear

        ;Silence
.sil:   xor a
        ld c,a
        ld e,a                  ;Frequency is zero
        ret                     ;Return with carry clear
        
        ;Raw frequency
.raw:   ld a,[mread+1]
        ld e,a
        ld a,[mread+2]
        and $07
        or $80
        ld c,a                  ;Load it
        inc hl  
        inc hl                  ;Increment read pointer
        ret                     ;Return with carry clear
         
        ;Table of note frequencies
notedt: DW $802C,$809D,$8107,$816B,$81CA,$8223,$8277,$82C7,$8312
        DW $8358,$839B,$83DA,$8416,$844E,$8483,$84B5,$84E5,$8511
        DW $853C,$8563,$8589,$85AC,$85CE,$85ED,$860B,$8627,$8642
        DW $865B,$8672,$8689,$869E,$86B2,$86C4,$86D6,$86E7,$86F7
        DW $8706,$8714,$8721,$872D,$8739,$8744,$874F,$8759,$8762
        DW $876B,$8773,$877B,$8783,$878A,$8790,$8797,$879D,$87A2
        DW $87A7,$87AC,$87B1,$87B6,$87BA,$87BE,$87C1,$87C5,$87C8
        DW $87CB,$87CE,$87D1,$87D4,$87D6,$87D9,$87DB,$87DD,$87DF

