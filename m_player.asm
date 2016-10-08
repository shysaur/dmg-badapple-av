                        

IF DEF(BGM_MODE) == 0
BGM_MODE        EQU 1
ENDC
SFX_MODE        EQU 1-BGM_MODE

        INCLUDE "m_config.inc"
        
IF BGM_MODE
WITH_VIBRATO    EQUS "BGM_WITH_VIBRATO"
WITH_PITCHBEND  EQUS "BGM_WITH_PITCHBEND"
WITH_SOFTENVEL  EQUS "BGM_WITH_SOFTENVEL"
WITH_DYNTRACK   EQUS "BGM_WITH_DYNTRACK" 
WITH_FRACSPEED  EQUS "BGM_WITH_FRACSPEED"
WITH_VOLUME     EQUS "BGM_WITH_VOLUME"
WITH_ENVRESTART EQUS "0"
ELSE
WITH_VIBRATO    EQUS "SFX_WITH_VIBRATO"  
WITH_PITCHBEND  EQUS "SFX_WITH_PITCHBEND"
WITH_SOFTENVEL  EQUS "SFX_WITH_SOFTENVEL"
WITH_DYNTRACK   EQUS "SFX_WITH_DYNTRACK" 
WITH_FRACSPEED  EQUS "SFX_WITH_FRACSPEED"
WITH_VOLUME     EQUS "0"
WITH_ENVRESTART EQUS "SFX_WITH_ENVRESTART"
ENDC
        
        IMPORT SoundWaveSamples
        IMPORT SoundNoisePatches
        
        IMPORT muschn
        IMPORT initch
        IMPORT mread
        IMPORT mfetch
        
        IMPORT jump
        IMPORT varset
        IMPORT notedt
        IMPORT muscc1
        GLOBAL pitchb
        GLOBAL vibrt
        GLOBAL envels
        

IF BGM_MODE
        EXPORT bgm_chn1w
        EXPORT bgm_chn2w
        EXPORT bgm_chn3w
        EXPORT bgm_chn4w
        EXPORT bgm_chn1sc
        EXPORT bgm_chn2sc
        EXPORT bgm_chn3wf
        EXPORT bgm_chn4sc
        EXPORT bgm_musici
        EXPORT bgm_music       
        
chn1w   EQUS "bgm_chn1w"
chn2w   EQUS "bgm_chn2w"
chn3w   EQUS "bgm_chn3w"
chn4w   EQUS "bgm_chn4w"
chn1sc  EQUS "bgm_chn1sc"
chn2sc  EQUS "bgm_chn2sc"
chn3wf  EQUS "bgm_chn3wf"
chn4sc  EQUS "bgm_chn4sc"
musici  EQUS "bgm_musici"
music   EQUS "bgm_music"

IF WITH_DYNTRACK
        EXPORT SoundBgmDynamicSong
musdsc  EQUS "SoundBgmDynamicSong"
ENDC

ELSE
        IMPORT bgm_chn1w
        IMPORT bgm_chn2w
        IMPORT bgm_chn3w
        IMPORT bgm_chn4w
        IMPORT bgm_chn1sc
        IMPORT bgm_chn2sc
        IMPORT bgm_chn3wf
        IMPORT bgm_chn4sc
        EXPORT sfx_musici
        EXPORT sfx_music
        
musici  EQUS "sfx_musici"
music   EQUS "sfx_music"

IF WITH_DYNTRACK
        EXPORT SoundSfxDynamicSong
musdsc  EQUS "SoundSfxDynamicSong"
ENDC

ENDC
        

IF BGM_MODE
        SECTION "musicdriver_DATA_bgm",BSS
ELSE
        SECTION "musicdriver_DATA_sfx",BSS
ENDC
        
        ;Flags:
        ; internal
        ;  bit 1   disable output (does not write to sound registers)
        ;  bit 2   disable playback (stops reading the sequence)
        ;  bit 3   silence and stop (silences the channel, then disables 
        ;          output and playback)
        ; external
        ;  bit 5   disable output
         
chn1a:  DS 2    ;Channel 1 current address (word)
chn1t:  DS 1    ;Channel 1 timer
chn1w:  DS 1    ;Channel 1 flags
chn1as: DS 2    ;Channel 1 return address
chn1ts: DS 1    ;Channel 1 finite loop counter
chn1ws: DS 1    ;Channel 1 vibrato sweep
chn1en: DS 1    ;Channel 1 envelope
chn1ut: DS 1    ;Channel 1 upcounter
chn1hf: DS 1    ;Channel 1 high frequency byte
chn1lf: DS 1    ;Channel 1 low frequency byte
chn1se: DS 1    ;Channel 1 software envelope step
chn1dt: DS 1    ;Channel 1 duty
chn1pb: DS 1    ;Channel 1 pitch bend frame delta
chn1pe: DS 1    ;Channel 1 pitch error
chn1vc: DS 1    ;Channel 1 vibrato counter
chn1l:  DS 1    ;Channel 1 length
chn1re: DS 1    ;Channel 1 real envelope
chn1sc: DS 1    ;Channel 1 restart flag / simulator counter

chn2a:  DS 2    ;Channel 2 current address
chn2t:  DS 1    ;Channel 2 timer
chn2w:  DS 1    ;Channel 2 flags
chn2as: DS 2    ;Channel 2 return address
chn2ts: DS 1    ;Channel 2 finite loop counter
chn2ws: DS 1    ;Channel 2 vibrato sweep
chn2en: DS 1    ;Channel 2 envelope
chn2ut: DS 1    ;Channel 2 upcounter
chn2hf: DS 1    ;Channel 2 high frequency byte
chn2lf: DS 1    ;Channel 2 low frequency byte
chn2se: DS 1    ;Channel 2 software envelope step
chn2dt: DS 1    ;Channel 2 duty (-2)
chn2pb: DS 1    ;Channel 2 pitch bend frame delta
chn2pe: DS 1    ;Channel 2 pitch error
chn2vc: DS 1    ;Channel 2 vibrato counter
chn2l:  DS 1    ;Channel 2 length
chn2re: DS 1    ;Channel 2 real envelope
chn2sc: DS 1    ;Channel 2 restart flag / simulator counter

chn3a:  DS 2    ;Channel 3 current address
chn3t:  DS 1    ;Channel 3 timer
chn3w:  DS 1    ;Channel 3 flags 
chn3as: DS 2    ;Channel 3 return address
chn3ts: DS 1    ;Channel 3 finite loop counter
chn3ws: DS 1    ;Channel 3 vibrato sweep
chn3en: DS 1    ;Channel 3 envelope
chn3ut: DS 1    ;Channel 3 upcounter
chn3hf: DS 1    ;Channel 3 high frequency byte
chn3lf: DS 1    ;Channel 3 low frequency byte
chn3se: DS 1    ;Channel 3 software envelope step
chn3wf: DS 1    ;Channel 3 current waveform number (-2)
chn3pb: DS 1    ;Channel 3 pitch bend frame delta
chn3pe: DS 1    ;Channel 3 pitch error
chn3vc: DS 1    ;Channel 3 vibrato counter
chn3l:  DS 1    ;Channel 3 length
chn3re: DS 1    ;Channel 3 real envelope
chn3sc: DS 1    ; (SPARE)

chn4a:  DS 2    ;Channel 4 current address
chn4t:  DS 1    ;Channel 4 timer
chn4w:  DS 1    ;Channel 4 exclusion
chn4as: DS 2    ;Channel 4 return address
chn4ts: DS 1    ;Channel 4 finite loop counter
chn4ws: DS 1    ; (SPARE)
chn4en: DS 1    ;Channel 4 envelope
chn4ut: DS 1    ;Channel 4 upcounter
chn4lf: DS 1    ;Channel 4 frequency byte
chn4hf: DS 1    ; (SPARE)
chn4se: DS 1    ;Channel 4 software envelope step (-2)
chn4wf: DS 1    ; (SPARE)
chn4pb: DS 1    ; (SPARE)
chn4pe: DS 1    ; (SPARE)
chn4vc: DS 1    ; (SPARE)
chn4l:  DS 1    ;Channel 4 length
chn4re: DS 1    ;Channel 4 real envelope
chn4sc: DS 1    ;Channel 4 restart flag / simulator counter

mussl2: DS 1    ;Precision timer integer part
mussl1: DS 1    ;Precision timer decimal part
musslw: DS 1    ;Precision timer decimal counter
mustra: DS 1    ;Register for transpose (in semitones)
IF WITH_DYNTRACK
musdsc: DS 1    ;Song number to change to when a $E2 opcode is encountred
ENDC
IF WITH_VOLUME
SoundBgmAttenuation::
musvol: DS 1    ;Volume
musvo2: DS 1    ;Current volume
ENDC


IF BGM_MODE
  IF MUSIC_USE_BANKING
        SECTION "musicdriver_CODE_bgm",CODE[$4000],BANK[MUSIC_PLAYER_BANK]
  ELSE
        SECTION "musicdriver_CODE_bgm",HOME
  ENDC
ELSE
  IF MUSIC_USE_BANKING
        SECTION "musicdriver_CODE_sfx",CODE,BANK[MUSIC_PLAYER_BANK]
  ELSE
        SECTION "musicdriver_CODE_sfx",HOME
  ENDC
ENDC



        ;   Initialize music engine addresses
        ;   (HL=offset of song pointers)
musici: ld d,h
        ld e,l                  ;Move song pointers address in DE
        ld hl, .ptrs            ;Get the channel init pointer array
        call initch
        call initch
        call initch            
        call initch             ;Init channels  1, 2, 3, 4
        ld hl,chn3wf
        set 7,[hl]              ;Flag channel 3 waveform to be updated
                        
        xor a                   ;   Setup globals
        ld [mussl1],a
        ld [musslw],a   
        ld [mustra],a           ;Reset transpose to none
        ld [chn1ts],a
        ld [chn2ts],a
        ld [chn3ts],a
        ld [chn4ts],a           ;Reset finite counters
        ld [chn1ws],a
        ld [chn2ws],a
        ld [chn3ws],a           ;Init vibrato descriptions (disable vibrato)
        inc a
        ld [mussl2],a           ;Set speed registers to 1.00 (59.73 Hz)
        ld [chn1t],a
        ld [chn2t],a
        ld [chn3t],a            ;Init timers to 1 (first DEC will trigger
        ld [chn4t],a            ; first note)
        ret                     ;Return
        
.ptrs:  DW chn1w, chn1dt, chn1en, chn1a
        DW chn2w, chn2dt, chn2en, chn2a
        DW chn3w, chn3en, chn3wf, chn3a
        DW chn4w, chn4en, chn4a,  chn4a


                                
        ;   Player Main
        
        
        ;   Update music frame
        
        ;   Parse the sequence data, if needed
        ;To implement fractional speed control, the sequence parsing code is 
        ;called the number of times specified in mussl1 and mussl2, interpreted
        ;as a 8.8 fixed point number. The fractional part error is in musslw.
music: IF WITH_FRACSPEED
        ld hl,mussl2
        ld a,[hl+]
        ld l,[hl]
        ld h,a                  ;Load timer value
        ld a,[musslw]
        ld c,a
        ld b,0                  ;Load fractional error
        add hl,bc               ;Sum the values
        ld a,l
        ld [musslw],a           ;Store the new fractional error
        inc h                   ;Call the music code the number of times
mustml: dec h                   ;specified in the integer part
        jr z,setchn             ;Return when counter is zero
        push hl
       ENDC
                                ;   Parse sequence data
muscon: ld a,[chn1w]            ;   Channel 1
        and $06
        jr nz,musicb            ;Disable sequence reading if flagged
        ld hl,chn1t
        dec [hl]                ;Update hannel 1 timer
        call z,music1           ;Play next note if current note finished

musicb: ld a,[chn2w]            ;   Channel 2
        and $06
        jr nz,musicc            ;Disable sequence reading if flagged
        ld hl,chn2t
        dec [hl]                ;Update channel 2 timer
        call z,music2           ;Play next note if current note finished
                                              
musicc: ld a,[chn3w]            ;   Channel 3
        and $06
        jr nz,musicd            ;Disable sequence reading if flagged
        ld hl,chn3t
        dec [hl]                ;Decrement channel 3 timer
        call z,music3           ;Play next note if current note finished
                 
musicd: ld a,[chn4w]            ;   Channel 4
        and $06
        jr nz,.pe               ;Disable sequence reading if flagged
        ld hl,chn4t
        dec [hl]                ;Decrement channel 4 timer
        call z,music4           ;Play next note if current note finished

.pe:   IF WITH_FRACSPEED
        pop hl
        jr mustml               ;Loop
       ENDC

        ;   Do background tasks (vibrato, software envelope, ...) for all
        ;   channels, and then update the hardware registers.
        
setchn:IF WITH_VOLUME
        ld a,[musvol]
        ld hl,musvo2
        cp [hl]
        jr z,set0               ;If volume did not change, skip ahead
        ld [hl],a
        ld hl,chn1sc
        set 7,[hl]
        ld hl,chn2sc
        set 7,[hl]
        ld hl,chn4sc            ;Otherwise restart all the channels to change
        set 7,[hl]              ;their envelopes to the volume-adjusted ones
       ENDC

        ;Channel 1
set0:   ld a,[chn1w]
        bit 2,a
        jr nz,.stop             ;If have to silence & stop, do it
        bit 1,a
        jr nz,set1              ;Skip if channel 1 sequence reading disabled
        
       IF SFX_MODE
        ld hl,bgm_chn1w
        set 4,[hl]              ;If playing sfx, disable the bgm
       ENDC
        ld a,[chn1hf]           
        and a
        jr z,.sil               ;If playing silence, silence it if needed
        
       IF WITH_VIBRATO
        ld hl,chn1ut
        ld a,[chn1ws]           ;Load registers for vibrato code
        call vibrt              ;Do vibrato
       ENDC
        
       IF WITH_PITCHBEND
        ld hl,chn1pb
        call pitchb             ;Do pitch bend
       ENDC
       
       IF WITH_SOFTENVEL
        ld hl,chn1en
        call envels             ;Do software envelope
        jr c,.out          
       ELSE
        ld a,[chn1ut]
        and a
        jr nz,.out              ;Don't set envelope if channel already inited
        ld a,[chn1en]
        ld [chn1re],a           ;Real envelope is equal to instrument envelope
       ENDC
        ld a,$80
        ld [chn1sc],a
        
.out:   ld a,[chn1w]
        and $11
        jr nz,.tail             ;Skip if channel 1 output disabled
        
        ld a,[chn1dt]
        ldh [$11],a             ;Set the duty

        ld a,[chn1sc]
        add a
        jr nc,.ske              ;Skip setting the envelope if no restart
        ld a,[chn1re]
       IF WITH_VOLUME
        call volume             ;Adjust the output volume
       ENDC
        ldh [$12],a             ;Set the envelope
        scf
        
.ske:   ld a,[chn1lf]
        ldh [$13],a             ;Reload low frequency byte
        sbc a
        or $0F                  ;Get high frequency byte with restart flag 
        ld hl,chn1hf            ;set only when carry clear (happens when
        and [hl]                ;envelope step changed or on note start)
        ldh [$14],a             ;Reload high frequency byte and restart flag
        jr .tail                ;Continue to next channel
        
.stop: IF SFX_MODE
        ld hl,bgm_chn1w
        res 4,[hl]   
       IF WITH_ENVRESTART
        ld hl,bgm_chn1sc
        set 7,[hl]              ;If we're stopping the sfx, restart the bgm
       ENDC
       ENDC
        ld a,$03
        ld [chn1w],a            ;Disable sequence reading and output
        jr .sil2                ;Shut down this channel
        
.sil:   ld a,[chn1ut]           
        and a
        jr nz,.tail             ;Don't restart note if already started
        ld a,[chn1w]
        and $11
        jr nz,.tail             ;Don't touch hardware if we are not meant to
        
.sil2:  ld a,$08                ;Set volume to zero, envelope stopped but on 
        ldh [$12],a             ;(using $00 shuts the channel down, and                      
        swap a                  ;shutting down a channel makes it click)
        ldh [$14],a             ;Restart the note 
          
.tail:  ld hl,chn1ut
        inc [hl]                ;Increment effects counter
          
          
        ;Channel 2
set1:   ld a,[chn2w]
        bit 2,a
        jr nz,.stop             ;If have to silence & stop, do it
        bit 1,a
        jr nz,set2              ;Skip if channel 2 sequence reading disabled
        
       IF SFX_MODE
        ld hl,bgm_chn2w
        set 4,[hl]              ;If playing sfx, disable the bgm
       ENDC
        ld a,[chn2hf]           
        and a
        jr z,.sil               ;If playing silence, silence it if needed

       IF WITH_VIBRATO
        ld hl,chn2ut
        ld a,[chn2ws]           ;Load registers for vibrato code
        call vibrt              ;Do vibrato
       ENDC
        
       IF WITH_PITCHBEND
        ld hl,chn2pb
        call pitchb             ;Do pitch bend
       ENDC
       
       IF WITH_SOFTENVEL
        ld hl,chn2en
        call envels             ;Do software envelope
        jr c,.out
       ELSE
        ld a,[chn2ut]
        and a
        jr nz,.out              ;Don't set envelope if channel already inited
        ld a,[chn2en]
        ld [chn2re],a           ;Real envelope is equal to instrument envelope
       ENDC
        ld a,$80
        ld [chn2sc],a
      
.out:   ld a,[chn2w]
        and $11
        jr nz,.tail             ;Skip if channel 2 output disabled
        
        ld a,[chn2dt]
        ldh [$16],a             ;Set the duty
        
        ld a,[chn2sc]
        add a
        jr nc,.ske              ;Skip setting the envelope if no restart
        ld a,[chn2re]
       IF WITH_VOLUME
        call volume             ;Adjust the output volume
       ENDC
        ldh [$17],a             ;Set the envelope
        scf
        
.ske:   ld a,[chn2lf]
        ldh [$18],a             ;Reload low frequency byte
        sbc a
        or $0F                  ;Get high frequency byte with restart flag 
        ld hl,chn2hf            ;set only when carry clear
        and [hl]                ;(happens when envelope step changed)
        ldh [$19],a             ;Reload high frequency byte and restart flag
        jr .tail                ;Continue to next channel
        
.stop: IF SFX_MODE
        ld hl,bgm_chn2w
        res 4,[hl]   
       IF WITH_ENVRESTART
        ld hl,bgm_chn2sc
        set 7,[hl]              ;If we're stopping the sfx, restart the bgm
       ENDC
       ENDC
        ld a,$03
        ld [chn2w],a            ;Disable sequence reading and output
        jr .sil2                ;Shut down this channel
        
.sil:   ld a,[chn2ut]           
        and a
        jr nz,.tail             ;Don't restart note if already started
        ld a,[chn2w]
        and $11
        jr nz,.tail             ;Don't touch hardware if we are not meant to
        
.sil2:  ld a,$08                ;Set volume to zero, envelope stopped but on 
        ldh [$17],a             ;(using $00 shuts the channel down, and                      
        swap a                  ;shutting down a channel makes it click)
        ldh [$19],a             ;Restart the note 
      
.tail:  ld hl,chn2ut
        inc [hl]                ;Increment effects counter
      
                                
        ;Channel 3
set2:   ld a,[chn3w]
        bit 2,a
        jr nz,.stop             ;If have to silence & stop, do it
        bit 1,a
        jr nz,set3              ;Skip if channel 3 sequence reading disabled
        
       IF SFX_MODE
        ld hl,bgm_chn3w
        set 4,[hl]              ;If playing sfx, disable the bgm
       ENDC
        ld a,[chn3hf]           
        and a
        jr z,.sil               ;If playing silence, silence it if needed
        
       IF WITH_VIBRATO
        ld hl,chn3ut
        ld a,[chn3ws]           ;Load registers for vibrato code
        call vibrt              ;Do vibrato
       ENDC
        
       IF WITH_PITCHBEND
        ld hl,chn3pb
        call pitchb             ;Do pitch bend
       ENDC
       
       IF WITH_SOFTENVEL
        ld hl,chn3en
        call envels             ;Do software envelope
       ELSE
        ld a,[chn3en]
        ld [chn3re],a           ;Real envelope is equal to instrument envelope
       ENDC
        
.out:   ld a,[chn3w]
        and $11
        jr nz,.tail             ;Skip if channel 2 output disabled
        
        ld a,[chn3wf]
        bit 7,a
        jr z,.nowu              ;Don't update the waveform if not needed
        and $7F
        ld [chn3wf],a           ;Clear reload flag
        call muscc1             ;Update the waveform
.nowu:  
        ld a,[chn3re]
       IF WITH_VOLUME
        call volum3             ;Adjust the output volume
       ENDC
        ldh [$1C],a             ;Set the envelope

.ske:   ld a,[chn3lf]
        ldh [$1D],a             ;Reload low frequency byte
        ld a,[chn3hf]           ;Reload high frequency byte 
        and $07
        ldh [$1E],a             ;(no restart for chn3)
        jr .tail                ;Continue to next channel
       
.stop: IF SFX_MODE
        ld hl,bgm_chn3w
        res 4,[hl]              
        ld hl,bgm_chn3wf
        set 7,[hl]              ;If we're stopping the sfx, restart the bgm
       ENDC
        ld a,$03
        ld [chn3w],a            ;Disable sequence reading and output
        jr .sil2                ;Shut down this channel
        
.sil:   ld a,[chn3ut]           
        and a
        jr nz,.tail             ;Don't restart note if already started
        ld a,[chn3w]
        and $11
        jr nz,.tail             ;Don't touch hardware if we are not meant to
        
.sil2:  ldh [$1C],a             ;Silence channel (no restart needed)

.tail:  ld hl,chn3ut 
        inc [hl]                ;Increment effects counter
        
        
        ;Channel 4
set3:   ld a,[chn4w]
        bit 2,a
        jr nz,.stop             ;If have to silence & stop, do it
        bit 1,a
        jr nz,setout            ;Skip if channel 4 sequence reading disabled
        
       IF SFX_MODE
        ld hl,bgm_chn4w
        set 4,[hl]              ;If playing sfx, disable the bgm
       ENDC
        ld a,[chn4en]           
        and a
        jr z,.sil               ;If playing silence, silence it if needed
        
       IF WITH_SOFTENVEL
        ld hl,chn4en
        call envels             ;Do software envelope
        jr c,.out
       ELSE
        ld a,[chn4ut]
        and a
        jr nz,.out              ;Don't set envelope if channel already inited
        ld a,[chn4en]
        ld [chn4re],a           ;Real envelope is equal to instrument envelope
       ENDC
        ld a,$80
        ld [chn4sc],a
        
.out:   ld a,[chn4w]
        and $11
        jr nz,.tail             ;Skip if channel 4 output disabled
        
        ld a,[chn4sc]
        add a
        jr nc,.tail             ;Skip setting envelope/LSFR if no restart
        
        ld a,[chn4re]
       IF WITH_VOLUME
        call volume             ;Adjust the output volume
       ENDC
        ldh [$21],a             ;Set the envelope
        
        ld a,[chn4lf]
        ldh [$22],a             ;Reload the LFSR configuration
        ld a,$80
        ldh [$23],a             ;Restart the channel on step change
        jr .tail                ;Done updating all the channels: return.
        
.stop: IF SFX_MODE
        ld hl,bgm_chn4w
        res 4,[hl]             
       IF WITH_ENVRESTART
        ld hl,bgm_chn4sc
        set 7,[hl]              ;If we're stopping the sfx, restart the bgm
       ENDC
       ENDC
        ld a,$03
        ld [chn4w],a            ;Disable sequence reading and output
        jr .sil2                ;Shut down this channel
        
.sil:   ld a,[chn4ut]           ;Don't restart note if already started
        and a
        jr nz,.tail
        ld a,[chn4w]
        and $11
        jr nz,.tail
        
.sil2:  ld a,$08                ;Set volume to zero, envelope stopped but on 
        ldh [$21],a             ;(using $00 shuts the channel down, and                      
        swap a                  ;shutting down a channel makes it click)
        ldh [$23],a             ;Restart the note (swap $08 = $80)
        
.tail:  ld hl,chn4ut
        inc [hl]                ;Increment effects counter
        
setout:IF SFX_MODE || (!BGM_WITH_VOLUME && !SFX_WITH_ENVRESTART)
        xor a
        ld [chn1sc],a
        ld [chn2sc],a
        ld [chn4sc],a           ;Reset the reload flags
        ret                     ;Return
       ELSE 
        ld hl,chn1re
        call envsim
        ld hl,chn2re
        call envsim
        ld hl,chn4re            ;Simulate the envelopes (used for note
        jp envsim               ;restarting after a sound effect)
       ENDC
       
       
       IF WITH_VOLUME
       
        ;   Volume adjustment function for channels 1, 2, 4
        ;Input: A = envelope
        ;Output: A = attenuated volume
volume: ld b,a
        ld a,[musvol]
        and a
        jr z,.noth              ;Return the current envelope if no attenuation
        ld d,a
        ld a,$07
        and b
        ld c,a                  ;Get the step length from the envelope byte
        xor b
        and $F0                 ;Get the volume from the envelope byte
.loop:  rrca
        rlc c
        dec d
        jr nz,.loop             ;Compute volume / (2^a) and length * (2^a)
        and $F0
        jr z,.sil               ;If resulting volume is zero, return silence
        ld d,a
        ld a,b
        and $08
        or d
        ld b,a                  ;Preserve the increase/decrease flag 
        ld a,c
        cp $08
        jr nc,.env              ;If the step length overflowed, cap it    
        and $07
.noth:  or b                    ;Otherwise merge it with the volume
        ret                     ;Return
        
.env:   cp $07*2                ;If the result is more than half the speed of
        jr nc,.noe              ;the maximum, return constant volume
        ld a,b
        or $07                  ;Otherwise return minimum speed
.noe:   ret                     ;Return
        
.sil:   ld a,$08
        ret                     ;Return silence


        ;   Volume adjustment function for channel 3
        ;Input: A = volume
        ;Output: A = attenuated volume
        ;Channel 3's volume is actually an attenuation value, but incremented
        ;by 1 (code 0 is silence, 1 is max, 2 is 1/2, 3 is 1/4)
volum3: ld b,a
        ld a,[musvol]
        and a
        jr z,.noth              ;Return the current envelope if no attenuation
        swap a
        add a
        add a                   ;Move the attenuation to the 2 highest bytes
        ld c,a
        ld a,b
        add a                   ;Move the volume to the 2 highest bytes
        ret z                   ;Return if the current volume is already zero
        add c                   ;Attenuate the volume
        jr c,.sil               ;If result has overflowed, return silence
        rra                     ;Put the attenuation in the 5th and 4th bytes
        ret                     ;Return
        
.sil:   xor a
        ret                     ;Return silence
        
.noth:  ld a,b
        ret
        
       ENDC
        
        
        ;   Functions used for playing next note
        
        ;Play next note in Channel 1
music1: xor a                   ;Reset pitch bend now so that it can be changed
        ld [chn1pb],a           ;before the note begins
        ld hl,chn1a             
        ld a,[hl+]
        ld h,[hl]               ;Load in HL the channel 1 next note address
        ld l,a
mus1x:  call mfetch             ;Load the next code in A and B
        cp $F0                  ;F0 <= code <= FF   then jump
        jp nc,jump1
        cp $E0                  ;E0 <= code <= EF   then meta-command
        jp nc,envct1

        call musicp             ;Otherwise, global command or note
        jr c,mus1x              ;If meta-command, next note
musi1b: bit 7,b
        jr z,.nl                ;If high bit clear, load old duration
        ld a,[chn1l]
        jr musi1c               ;Otherwise read old duration
.nl:    ld a,[mread+1]
        inc hl
        ld [chn1l],a            ;Read and set new duration
musi1c: ld [chn1t],a            ;Restart the timer
        ld a,l
        ld [chn1a],a
        ld a,h
        ld [chn1a+1],a          ;Save the next note address
        ld a,e
        cp $10
        ret z                   ;Don't reset the channel when continuing
        ld [chn1hf],a
        ld a,c
        ld [chn1lf],a           ;Update frequency variable
        xor a
        ld [chn1ut],a           ;Reset upcounter
        ld [chn1se],a           ;Reset software envelope counter
        ld [chn1pe],a           ;Reset pitch error
        ret                     ;Return

        
        ;Play next note in Channel 2
music2: xor a                   ;Reset pitch bend now so that it can be changed
        ld [chn2pb],a           ;before the note begins
        ld hl,chn2a
        ld a,[hl+]
        ld h,[hl]               ;Load in HL the channel 2 next note address
        ld l,a
mus2x:  call mfetch             ;Load the next code in A and B
        cp $F0                  ;F0 <= code <= FF   then jump
        jp nc,jump2
        cp $E0                  ;E0 <= code <= EF   then meta-command
        jp nc,envct2  

        call musicp             ;Otherwise, global command or note
        jr c,mus2x              ;If meta-command, next note
musi2b: bit 7,b
        jr z,.nl                ;If high bit clear, load old duration
        ld a,[chn2l]
        jr musi2c               ;Otherwise read old duration
.nl:    ld a,[mread+1]
        inc hl
        ld [chn2l],a            ;Read and set new duration
musi2c: ld [chn2t],a            ;Restart the timer
        ld a,l
        ld [chn2a],a
        ld a,h
        ld [chn2a+1],a          ;Save the next note address
        ld a,e
        cp $10
        ret z                   ;Don't update the frequency when continuing note
        ld [chn2hf],a
        ld a,c
        ld [chn2lf],a           ;Update frequency variable
        xor a
        ld [chn2ut],a           ;Reset upcounter
        ld [chn2se],a           ;Reset software envelope counter
        ld [chn2pe],a           ;Reset pitch error
        ret                     ;Return

        
        ;Play next note in channel 3
music3: xor a                   ;Reset pitch bend now so that it can be changed
        ld [chn3pb],a           ;before the note begins
        ld hl,chn3a
        ld a,[hl+]
        ld h,[hl]               ;Load in HL the channel 3 next note address
        ld l,a
mus3x:  call mfetch             ;Load the next code in A and B
        cp $F0                  ;F0 <= code <= FF   then jump
        jp nc,jump3
        cp $E0                  ;E0 <= code <= EF   then meta-command
        jp nc,envct3

        call musicp             ;Otherwise, global command or note
        jr c,mus3x              ;If meta-command, next note
musi3b: bit 7,b
        jr z,.nl                ;If high bit clear, load old duration
        ld a,[chn3l]
        jr musi3c               ;Otherwise read old duration
.nl:    ld a,[mread+1]
        inc hl
        ld [chn3l],a            ;Read and set new duration
musi3c: ld [chn3t],a            ;Restart the timer
        ld a,l
        ld [chn3a],a
        ld a,h
        ld [chn3a+1],a          ;Save the next note address
        ld a,e
        cp $10
        ret z                   ;Don't reset the channel when continuing
        ld [chn3hf],a
        ld a,c
        ld [chn3lf],a           ;Update frequency variable
        xor a
        ld [chn3ut],a           ;Reset upcounter
        ld [chn3se],a           ;Reset software envelope counter
        ld [chn3pe],a           ;Reset pitch error
        ret                     ;Return

        
        ;Play next note in channel 4
music4: ld hl,chn4a
        ld a,[hl+]
        ld h,[hl]               ;Load in HL the channel 4 next note address
        ld l,a
mus4x:  call mfetch             ;Load the next code in A and B
        cp $F0                  
        jp nc,jump4             ;F0 <= code <= FF   then jump
        cp $E0           
        jr nz,.m4z              ;E0 = code   then envelope change
        
        ld a,[mread+1]          ;Get envelope from code stream
        inc hl
        ld [chn4en],a           ;Save new envelope
        jr mus4x                ;Set it and continue
        
.m4z:   ld a,[chn4w]    
        and a
        jr nz,.m4b              ;If channel excluded then don't parse notes

        ld a,b
        add a                   ;(this also shifts out high bit)
        cp $49*2
        jr nz,.xdirn            ;If code was not $49, not a raw noise
        
        ld a,[mread+1]          ;Get noise value from code stram
        inc hl
        ld [chn4lf],a           ;Set it
        ld a,[mread+2]
        ld [mread+1],a          ;Move the eventual duration to mread+1
        jr .m4b                 ;Continue
        
.xdirn: cp $48*2
        jr nz,.nosil            ;If code was not $48, it was not silence      
        
        xor a                   
        ld [chn4en],a           
        ld [chn4lf],a           ;Set silence
        jr .m4b                 ;Continue
            
.nosil: add a,SoundNoisePatches & $FF      
        ld e,a
        ld d,SoundNoisePatches >> 8
        jr nc,.noc              ;Get in DE the address of the drum in the 
        inc d                   ;drum patch table
.noc:   ld a,[de]               ;Get frequency value from the table
        ld [chn4lf],a           ;Set the frequency            
        inc de
        ld a,[de]               ;Get envelope value from the table
        ld [chn4en],a           ;Set the envelope
        
.m4b:   bit 7,b
        jr nz,.oldl             ;If high bit set, retains old duration
        
        ld a,[mread+1]
        inc hl
        ld [chn4t],a            ;Save the note duration in the timer register
        ld [chn4l],a
        jr .end
        
.oldl:  ld a,[chn4l]
        ld [chn4t],a            ;Set default timer value as old note's one
        
.end:   ld a,l
        ld [chn4a],a
        ld a,h
        ld [chn4a+1],a          ;Save the next note address
        xor a
        ld [chn4ut],a
        ld [chn4se],a           ;Reset software envelope counter
        ret                     ;Return
       

       
        ;   Jump subroutines ($F0-$FF)
        
        ;Channel 1
jump1:  ld bc,chn1as            
        ld de,chn1ts            ;Load parameters for this channel
        call jump               ;Do the jump
        jp nz,mus1x             ;Play next note at new address 
        ld hl,chn1w
        set 2,[hl]              ;If address was zero, flag the channel to be
        ret                     ;silenced and stopped, and abort.

        ;Channel 2
jump2:  ld bc,chn2as            
        ld de,chn2ts            ;Load parameters for this channel
        call jump               ;Do the jump
        jp nz,mus2x             ;Play next note at new address
        ld hl,chn2w
        set 2,[hl]              ;If address was zero, flag the channel to be
        ret                     ;silenced and stopped, and abort.

        ;Channel 3
jump3:  ld bc,chn3as          
        ld de,chn3ts            ;Load parameters for this channel
        call jump               ;Do the jump
        jp nz,mus3x             ;Play next note at new address
        ld hl,chn3w
        set 2,[hl]              ;If address was zero, flag the channel to be
        ret                     ;silenced and stopped, and abort.

        ;Channel 4
jump4:  ld bc,chn4as          
        ld de,chn4ts            ;Load parameters for this channel
        call jump               ;Do the jump
        jp nz,mus4x             ;Play next note at new address
        ld hl,chn4w
        set 2,[hl]              ;If address was zero, flag the channel to be
        ret                     ;silenced and stopped, and abort.

        


        ;   Envelope/Vibrato/Waveform change subroutines
        ;Channel 1
envct1: ld de,envc1t
       IF WITH_DYNTRACK
        cp $E2                  ;If next command is $E2 then change song
        jp z,dynsnb             ;commanded by program (only on channel 1!)
        cp $E1                  ;If next command is $E1 then change song as
        jp z,dynsng             ;specified by song (only on chn 1)
       ENDC
        call varset             ;Interpret generic command
        jp mus1x                ;Play next note
        
       IF WITH_DYNTRACK
dynsnb: ld hl,musdsc            ;Change song to the musdsc value
dynsng: call varset             ;Change the song
        ld a,4
        ld [chn1w],a
        ld [chn2w],a
        ld [chn3w],a
        ld [chn4w],a            ;Freeze the other channels (don't continue 
        ret                     ;playing this song) and done
       ENDC

        ;Channel 2
envct2: ld de,envc2t
        call varset             ;Interpret generic command
        jp mus2x                ;Play next note 
        
        ;Channel 3
envct3: cp $E4
        jr z,envc32             ;If it is a waveform change then do it
        ld de,envc3t
        call varset             ;Otherwise do a generic command
        jp mus3x                ;Play next note
        
envc32: ld a,[mread+1]          ;Load the waveform byte
        inc hl
        or $80
        ld [chn3wf],a           ;Store in channel 3 waveform register
        jp mus3x                ;Play next note
        
        
envc1t: DW chn1en, muschn, muschn, chn1ws, chn1dt, chn1pb        
envc2t: DW chn2en, muschn, muschn, chn2ws, chn2dt, chn2pb
envc3t: DW chn3en, muschn, muschn, chn3ws, chn3wf, chn3pb


        ;   Parse a note number. A = B = note/command
        ;Output: carry set on meta-note, CE = frequency, B = note/command
        ;Also does the global control codes.
musicp: add a                   ;Shift out high bit
        cp (5+6*12) * 2         ;If we have to continue the current note
        jr z,.cont              ; without restarting, return a fake note
        cp $4A * 2
        jp nc,.gcom             ;If >= $4A, do a global command
        
        ld a,[mustra]
        ld c,a                  ;Get transpose in C
        jp musp2                ;Read the note

.gcom:  ld a,b
        sub $4A
        ld de,.pt               ;Load the address of the var table
        jp varset               ;Set the appropriate variable
        
.pt:    DW mussl1, mustra, mussl2

.cont:  ld e,$10                ;Fake flag "continue" note is $01xx
        xor a
        ret                     ;Return with carry clear
        
        