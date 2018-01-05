

        INCLUDE "m_config.inc"
        INCLUDE "music.inc"
        
      
IF MUSIC_C_FUNCTS  
      
        
        SECTION "musicdriver_interface", ROM0
        
        
_musicSwitchSong::
        ld hl,sp+2
        ld a,[hl]
        ld [SoundChangeBgm],a
        ret
        
        
IF BUILD_SFX

_musicTriggerSfx::
        ld hl,sp+2
        ld a,[hl]
        ld [SoundChangeSfx],a
        ret
        
        
_musicStopSfx::
        ld a,$FF
        ld [SoundChangeSfx],a
        ret
        
ENDC        
        
        
_musicResetDriver::
        jp SoundReset

        
_musicAdvanceFrame::
        push bc
        call SoundFrame
        pop bc
        ret

  
ENDC

