

        EXPORT _head

        INCLUDE "music.inc"
        
IF MUSIC_USE_BANKING
GBS_BASE = $4000 - $1A0
ELSE
GBS_BASE = $0800 - $1A0
ENDC
        
        
        SECTION "stack", BSS[$CF00]
        
        
        DS 255
_stack: DS 1
        
        
        SECTION "gbs_header", HOME[$0000]
        
        
        DS GBS_BASE
        
_head:  DB "GBS",1
        DB 255,1                      ;Number of songs, first song
        DW _init, _init, SoundFrame, _stack+1
        DB 0,0

_title: DB "Music Player Test"
.e:     DS $20 - (.e - _title)
      
_auth:  DB "Music Player Test"
.e:     DS $20 - (.e - _auth)
        
_copyr: DB "2015"
.e:     DS $20 - (.e - _copyr)
        

        SECTION "musicdriver_gbs_support_CODE", HOME
        
_init:  push af            
        call SoundReset
        pop af
        ld [SoundChangeBgm],a
        jp SoundFrame    

