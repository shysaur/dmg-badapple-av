

        EXPORT _head

        INCLUDE "music.inc"
        INCLUDE "m_config.inc"
        
        
IF MUSIC_USE_BANKING
GBS_BASE = $4000 - $200
ELSE
GBS_BASE = $0800 - $200
ENDC
        
        
        SECTION "stack", WRAM0[$CF00]
        
        
        DS 256
_stack: 
        
        
        SECTION "gbs_header", ROM0[$0000]
        
        
        DS GBS_BASE
        
_head:  DB "GBS",1
        DB GBS_NUMSONGS, GBS_FIRSTSONG           ;Number of songs, first song
        DW _load, _init, SoundFrame, _stack
        DB 0,0

_title: DB GBS_TITLE
.e:     DS $20 - (.e - _title)
      
_auth:  DB GBS_AUTHOR
.e:     DS $20 - (.e - _auth)
        
_copyr: DB GBS_COPYRIGHT
.e:     DS $20 - (.e - _copyr)
        
_load:


        SECTION "musicdriver_gbs_support_CODE", ROM0
        
_init:  push af            
        call SoundReset
        pop af
        ld [SoundChangeBgm],a
        jp SoundFrame    

