

        INCLUDE "m_config.inc"
        INCLUDE "music.inc"
        
        
        EXPORT SoundSegmentTable
        
        EXPORT bgm_music
        EXPORT bgm_musici
IF BUILD_SFX
        EXPORT sfx_music
        EXPORT sfx_musici
ENDC

        EXPORT muschn
        EXPORT initch
        EXPORT mfetch
        EXPORT mread
        
        
        SECTION "musicdriver_util_var",WRAM0
        
        
SoundChangeBgm:
muschn:           DS 1    ;WRITE HERE TO CHANGE SONG
musson:           DS 1    ;Currently playing song (change this to restart song)
IF BUILD_SFX
SoundChangeSfx:
sfxtrg:           DS 1    ;Write here to trigger SFX
ENDC

IF MUSIC_USE_BANKING
musbnk: DS 1
sfxbnk: DS 1
tmpbnk: DS 1
ENDC

mread:  DS 3    ;Read buffer
        
        
        SECTION "musicdriver_util_CODE", ROM0
        
        
        
        ;   Bank switching and song selection driver
SoundFrame:
        ld a,[muschn]
        ld hl,musson
        cp [hl]
        jr z,.sfxc              ;If song change not requested, check sfx change
        
        ld [hl],a               ;Song change: update the current song var
        call gsptrs             ;Get this song's pointer table
       IF MUSIC_USE_BANKING
        ld [musbnk],a           ;Save the song bank
        ld [tmpbnk],a
        ld a,MUSIC_PLAYER_BANK
        ld [$2222],a            ;Switch to the sound player's bank
       ENDC
        call bgm_musici         ;Initialize the sound player
        
.sfxc: 
       IF BUILD_SFX
        ld a,[sfxtrg]
        cp $FE
        jr z,.play              ;If no SFX to trigger, continue playing
        
        call gsptrs             ;Get the song's pointer table
       IF MUSIC_USE_BANKING
        ld [sfxbnk],a           ;Save the song bank
        ld [tmpbnk],a
        ld a,MUSIC_PLAYER_BANK  
        ld [$2222],a            ;Switch to the sound player's bank
       ENDC
        call sfx_musici         ;Initialize the sound player
        ld a,$FE
        ld [sfxtrg],a           ;Reset the trigger variable
       ENDC
        
.play: 
       IF MUSIC_USE_BANKING
        ld a,MUSIC_PLAYER_BANK
        ld [$2222],a            ;Switch to the sound player's bank
       ENDC
       IF BUILD_SFX
       IF MUSIC_USE_BANKING
        ld a,[sfxbnk]
        ld [tmpbnk],a
       ENDC
        call sfx_music    
       ENDC  
       IF MUSIC_USE_BANKING    
        ld a,[musbnk]
        ld [tmpbnk],a
       ENDC
        jp bgm_music            ;Continue playing


        ;   Get song pointers
        ;Input:  A=song index;
        ;Output: HL=song pointers address, A=song pointers bank
gsptrs: cp $FF
        jr z,.dis
       IF MUSIC_USE_BANKING
        ld hl,$2222
        ld [hl],BANK(SoundSegmentTable) ;Switch to the segment table bank
        
        ld hl,SoundSegmentTable ;Start from the 1st segment
        ld bc,4
.loop:  cp [hl]                 
        jr c,.found             ;If the song is in this segment, get the pointer
        sub [hl]                ;Otherwise subtract the songs in this segment
                                ; from the song number
        add hl,bc               ;Increment pointer to the next segment
        jr .loop                
       ENDC
        
.found:
      IF MUSIC_USE_BANKING
        ld c,a                  ;Save the song's index in this segment's table
        inc hl
        ld a,[hl+]              ;Get the segment's bank
        ld b,a
        ld a,[hl+]
        ld d,[hl]
        ld e,a                  ;Get the segment's pointers base address
        ld l,c
       ELSE
        ld de,SoundSongTable
        ld l,a
       ENDC
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ;Get the offset in the pointer table
        add hl,de               ;Get the address of the song's pointers
       IF MUSIC_USE_BANKING
        ld a,b
       ENDC
        ret                     ;Return
        
.dis:   ld hl,.nosnd
       IF MUSIC_USE_BANKING
        ld a,MUSIC_PLAYER_BANK
       ENDC
        ret
        
.nosnd: DW 0,0,0,0
        
        
        ;   Reset sound
SoundReset:
        ld a,$FE
        ld [musson],a           ;Ensure that old song register != muschn
        inc a
        ld [muschn],a           ;Init song number register
       IF BUILD_SFX
        ld [sfxtrg],a           ;Silence SFX
       ENDC
        ld a,$77
        ldh [$24],a             ;Set maximum volume
        ld a,$FF
        ldh [$25],a             ;Disable stereo
        ldh [$26],a             ;Enable sound generator hardware
        ret                     ;Return
        
        
        ;   Initialize single channel 
        ;(HL=array of 4 pointers, DE=addr. of sequence pointer)
initch:
       IF MUSIC_USE_BANKING
        ld a,[tmpbnk]
        ld [$2222],a            ;Switch to song data bank
       ENDC
        ld a,[de]
        inc de
        ld c,a
        ld a,[de]
        inc de
        ld b,a                  ;Load in BC the channel sequence address
        push de                 ;Save DE (will be used for temp. pointers)
        or c
        
       IF MUSIC_USE_BANKING
        ld a,MUSIC_PLAYER_BANK
        ld [$2222],a            ;Switch to engine code bank
       ENDC
        ld a,[hl+]
        ld e,a
        ld a,[hl+]
        ld d,a                  ;Load address of flag pointer for this channel
        jr nz,.ok               ;If sequence pointer not null, standard init
        
        ld bc,6
        add hl,bc               ;Advance to next 4 pointers
        ld a,[de]
        and %11                 
        cp %11
        jr z,.noth              ;Don't disable channel if already disabled
        ld a,[de]
        or %100                 ;Command to disable channel         
        jr .done                ;Write the new flags and done
        
.ok:    ld a,[de]
        and $10                 ;If sequence valid, enable channel
        ld [de],a               ;(keeping output override flag)
        
       IF MUSIC_USE_BANKING
        ld a,[tmpbnk]
        ld [$2222],a            ;Switch to song data bank
       ENDC
        
        ld a,[bc]               ;Load first value from header
        inc bc
        ld d,a
        ld a,[bc]               ;Load second value from header
        inc bc
        push af
        push de                 ;Save both for later writing
        
       IF MUSIC_USE_BANKING
        ld a,MUSIC_PLAYER_BANK
        ld [$2222],a            ;Switch to engine code bank
       ENDC
        
        ld a,[hl+]
        ld e,a
        ld a,[hl+]
        ld d,a                  ;Get address of first var to be inited
        pop af
        ld [de],a               ;Initialize the var
        
        ld a,[hl+]
        ld e,a
        ld a,[hl+]
        ld d,a                  ;Get address of second var to be inited
        pop af
        ld [de],a               ;Initialize the var
        
        ld a,[hl+]
        ld e,a
        ld a,[hl+]
        ld d,a                  ;Get address of current sequence pointer
        ld a,c
        ld [de],a
        inc de
        ld a,b                  ;Initialize the pointer (address of 1st byte
.done:  ld [de],a               ;after the header)
        
.noth:  pop de
        ret                     ;Return
       
        
        ;   Fetch 4 bytes of sequence data, pointed by HL in the BGM sequence
        ;data bank.
mfetch:
       IF MUSIC_USE_BANKING
        ld a,[tmpbnk]
        ld [$2222],a            ;Switch to song data bank
       ENDC
        
        ld a,[hl+]
        ld b,a
        ld [mread],a
        ld a,[hl+]
        ld [mread+1],a
        ld a,[hl]
        ld [mread+2],a          ;Move 3 bytes to the read buffer
        
       IF MUSIC_USE_BANKING
        ld a,BANK(bgm_music)
        ld [$2222],a            ;Switch back to the code bank
       ENDC
        dec hl                  ;Return the second byte's address in HL
        ld a,b                  ;Return the first byte in A and B
        ret                     ;Return









