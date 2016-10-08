
INCLUDE "m_config.inc"


;SoundEnvelopeTable points to a linear array of up to 15 pointers to each
;software envelope description. SoundEnvelopeTable and the software envelope 
;descriptions must be located in the MUSIC_PLAYER_BANK.
;  Each envelope description has the following format:
;
;  DB (envelope step count)
;  for each envelope step:
;     DB (hardware envelope to use in this step)
;     DB (trigger time for this step, in frames since the note started)
;
;To prevent glitches, the trigger time for the first step should always be
;zero frames.
;  The length of one software envelope frame is not affected by the length of
;the sequence frame (which can be modified using the SET_SPEED commands),
;but it always corresponds to 1.0 sequence frames (~1/60 sec).

GLOBAL SoundEnvelopeTable


;SoundWaveSamples points to a linear array of 16-byte waveforms to use for
;channel 3.

GLOBAL SoundWaveSamples


;SoundNoisePatches points to a linear array of 16-bit noise patches used by
;channel 4. Each noise patch has the following format:
;
;  byte 0: noise frequency
;  byte 1: envelope
;
;In SoundNoisePatches you can add up to 6*12=72 patches, which are played
;corresponding to each of the 72 notes available.

GLOBAL SoundNoisePatches


IF MUSIC_USE_BANKING

;A sound segment is a non-cross-bank data area which contains music sequences.
;The SoundSegmentTable contains pointers to each sound segment, and can be
;located in any bank (it mustn't cross any bank boundary too). It has the
;following format:
;
;  for each sound segment:
;    DB (number of songs in the segment), (bank where the segment is located)
;    DW (address of the segment in that bank)
;  DB 0 ;terminator
;
;Each sound segment starts with a pointer table. The pointer table is divided
;in groups of four pointers (one group is one song). The four pointers are
;addresses to the sequence data for channels 1, 2, 3, 4 (in order) of the
;song. NULL (zero) pointers mean no sequence data is provided for that channel
;(which will stay silent).
;  Sequence data pointed by this table has a two-byte header used for
;initializing the channel:
;
;  Channel 1,2: byte 0: initial waveform
;               byte 1: initial envelope
;  Channel 3:   byte 0: initial envelope
;               byte 1: initial waveform (yes it's reversed)
;  Channel 4:   byte 0: initial envelope
;               byte 1: unused (but must be present)
;
;This header is present if and only if the sequence data is pointed by
;the song's pointer group!

GLOBAL SoundSegmentTable

ELSE

;When banking is disabled (MUSIC_USE_BANKING == 0), SoundSegmentTable is
;not used because no bank switch is needed; instead, directly declare the song
;pointer table as SoundSongTable.
GLOBAL SoundSongTable

ENDC


;All note commands are followed by 1 byte of length (in frames), unless they
;are ORed with OLDLEN (in this case, they inherit the previous note's length).
;REST, CUSTOM_NOTE and CONTINUE work in the same way.
;  Channel 4 uses all note commands to select noise patches. Noise patches are
;read from the SoundNoisePatches table and they consist of one byte of raw
;noise frequencies and one byte of envelope.
;  CUSTOM_NOTE is followed by 2 bytes of raw frequency (before the length byte,
;if it should be present); except on channel 4 (Noise) where it is followed by
;one byte of raw frequency.
;  CONTINUE resumes the playback of the previous note, by adding its length to
;the previous note's length. You can change any of the channel's parameters
;before a CONTINUE, except for envelope and vibrato.

OLDLEN          EQU $80   

C_3             EQU  0+0*12    ;$00
DO_3            EQU  0+0*12    ;$00
C_SHARP_3       EQU  1+0*12    ;$01
DO_SHARP_3      EQU  1+0*12    ;$01
D_FLAT_3        EQU  1+0*12    ;$01
RE_FLAT_3       EQU  1+0*12    ;$01
D_3             EQU  2+0*12    ;$02
RE_3            EQU  2+0*12    ;$02
D_SHARP_3       EQU  3+0*12    ;$03
RE_SHARP_3      EQU  3+0*12    ;$03
E_FLAT_3        EQU  3+0*12    ;$03
MI_FLAT_3       EQU  3+0*12    ;$03
E_3             EQU  4+0*12    ;$04
MI_3            EQU  4+0*12    ;$04
F_3             EQU  5+0*12    ;$05
FA_3            EQU  5+0*12    ;$05
F_SHARP_3       EQU  6+0*12    ;$06
FA_SHARP_3      EQU  6+0*12    ;$06
G_FLAT_3        EQU  6+0*12    ;$06
SOL_FLAT_3      EQU  6+0*12    ;$06
G_3             EQU  7+0*12    ;$07
SOL_3           EQU  7+0*12    ;$07
G_SHARP_3       EQU  8+0*12    ;$08
SOL_SHARP_3     EQU  8+0*12    ;$08
A_FLAT_3        EQU  8+0*12    ;$08
LA_FLAT_3       EQU  8+0*12    ;$08
A_3             EQU  9+0*12    ;$09
LA_3            EQU  9+0*12    ;$09
A_SHARP_3       EQU 10+0*12    ;$0A
LA_SHARP_3      EQU 10+0*12    ;$0A
B_FLAT_3        EQU 10+0*12    ;$0A
SI_FLAT_3       EQU 10+0*12    ;$0A
B_3             EQU 11+0*12    ;$0B
SI_3            EQU 11+0*12    ;$0B

C_4             EQU  0+1*12    ;$0C
DO_4            EQU  0+1*12    ;$0C
C_SHARP_4       EQU  1+1*12    ;$0D
DO_SHARP_4      EQU  1+1*12    ;$0D
D_FLAT_4        EQU  1+1*12    ;$0D
RE_FLAT_4       EQU  1+1*12    ;$0D
D_4             EQU  2+1*12    ;$0E
RE_4            EQU  2+1*12    ;$0E
D_SHARP_4       EQU  3+1*12    ;$0F
RE_SHARP_4      EQU  3+1*12    ;$0F
E_FLAT_4        EQU  3+1*12    ;$0F
MI_FLAT_4       EQU  3+1*12    ;$0F
E_4             EQU  4+1*12    ;$10
MI_4            EQU  4+1*12    ;$10
F_4             EQU  5+1*12    ;$11
FA_4            EQU  5+1*12    ;$11
F_SHARP_4       EQU  6+1*12    ;$12
FA_SHARP_4      EQU  6+1*12    ;$12
G_FLAT_4        EQU  6+1*12    ;$12
SOL_FLAT_4      EQU  6+1*12    ;$12
G_4             EQU  7+1*12    ;$13
SOL_4           EQU  7+1*12    ;$13
G_SHARP_4       EQU  8+1*12    ;$14
SOL_SHARP_4     EQU  8+1*12    ;$14
A_FLAT_4        EQU  8+1*12    ;$14
LA_FLAT_4       EQU  8+1*12    ;$14
A_4             EQU  9+1*12    ;$15
LA_4            EQU  9+1*12    ;$15
A_SHARP_4       EQU 10+1*12    ;$16
LA_SHARP_4      EQU 10+1*12    ;$16
B_FLAT_4        EQU 10+1*12    ;$16
SI_FLAT_4       EQU 10+1*12    ;$16
B_4             EQU 11+1*12    ;$17
SI_4            EQU 11+1*12    ;$17

C_5             EQU  0+2*12    ;$18
DO_5            EQU  0+2*12    ;$18
C_SHARP_5       EQU  1+2*12    ;$19
DO_SHARP_5      EQU  1+2*12    ;$19
D_FLAT_5        EQU  1+2*12    ;$19
RE_FLAT_5       EQU  1+2*12    ;$19
D_5             EQU  2+2*12    ;$1A
RE_5            EQU  2+2*12    ;$1A
D_SHARP_5       EQU  3+2*12    ;$1B
RE_SHARP_5      EQU  3+2*12    ;$1B
E_FLAT_5        EQU  3+2*12    ;$1B
MI_FLAT_5       EQU  3+2*12    ;$1B
E_5             EQU  4+2*12    ;$1C
MI_5            EQU  4+2*12    ;$1C
F_5             EQU  5+2*12    ;$1D
FA_5            EQU  5+2*12    ;$1D
F_SHARP_5       EQU  6+2*12    ;$1E
FA_SHARP_5      EQU  6+2*12    ;$1E
G_FLAT_5        EQU  6+2*12    ;$1E
SOL_FLAT_5      EQU  6+2*12    ;$1E
G_5             EQU  7+2*12    ;$1F
SOL_5           EQU  7+2*12    ;$1F
G_SHARP_5       EQU  8+2*12    ;$20
SOL_SHARP_5     EQU  8+2*12    ;$20
A_FLAT_5        EQU  8+2*12    ;$20
LA_FLAT_5       EQU  8+2*12    ;$20
A_5             EQU  9+2*12    ;$21
LA_5            EQU  9+2*12    ;$21
A_SHARP_5       EQU 10+2*12    ;$22
LA_SHARP_5      EQU 10+2*12    ;$22
B_FLAT_5        EQU 10+2*12    ;$22
SI_FLAT_5       EQU 10+2*12    ;$22
B_5             EQU 11+2*12    ;$23
SI_5            EQU 11+2*12    ;$23

C_6             EQU  0+3*12    ;$24
DO_6            EQU  0+3*12    ;$24
C_SHARP_6       EQU  1+3*12    ;$25
DO_SHARP_6      EQU  1+3*12    ;$25
D_FLAT_6        EQU  1+3*12    ;$25
RE_FLAT_6       EQU  1+3*12    ;$25
D_6             EQU  2+3*12    ;$26
RE_6            EQU  2+3*12    ;$26
D_SHARP_6       EQU  3+3*12    ;$27
RE_SHARP_6      EQU  3+3*12    ;$27
E_FLAT_6        EQU  3+3*12    ;$27
MI_FLAT_6       EQU  3+3*12    ;$27
E_6             EQU  4+3*12    ;$28
MI_6            EQU  4+3*12    ;$28
F_6             EQU  5+3*12    ;$29
FA_6            EQU  5+3*12    ;$29
F_SHARP_6       EQU  6+3*12    ;$2A
FA_SHARP_6      EQU  6+3*12    ;$2A
G_FLAT_6        EQU  6+3*12    ;$2A
SOL_FLAT_6      EQU  6+3*12    ;$2A
G_6             EQU  7+3*12    ;$2B
SOL_6           EQU  7+3*12    ;$2B
G_SHARP_6       EQU  8+3*12    ;$2C
SOL_SHARP_6     EQU  8+3*12    ;$2C
A_FLAT_6        EQU  8+3*12    ;$2C
LA_FLAT_6       EQU  8+3*12    ;$2C
A_6             EQU  9+3*12    ;$2D
LA_6            EQU  9+3*12    ;$2D
A_SHARP_6       EQU 10+3*12    ;$2E
LA_SHARP_6      EQU 10+3*12    ;$2E
B_FLAT_6        EQU 10+3*12    ;$2E
SI_FLAT_6       EQU 10+3*12    ;$2E
B_6             EQU 11+3*12    ;$2F
SI_6            EQU 11+3*12    ;$2F

C_7             EQU  0+4*12    ;$30
DO_7            EQU  0+4*12    ;$30
C_SHARP_7       EQU  1+4*12    ;$31
DO_SHARP_7      EQU  1+4*12    ;$31
D_FLAT_7        EQU  1+4*12    ;$31
RE_FLAT_7       EQU  1+4*12    ;$31
D_7             EQU  2+4*12    ;$32
RE_7            EQU  2+4*12    ;$32
D_SHARP_7       EQU  3+4*12    ;$33
RE_SHARP_7      EQU  3+4*12    ;$33
E_FLAT_7        EQU  3+4*12    ;$33
MI_FLAT_7       EQU  3+4*12    ;$33
E_7             EQU  4+4*12    ;$34
MI_7            EQU  4+4*12    ;$34
F_7             EQU  5+4*12    ;$35
FA_7            EQU  5+4*12    ;$35
F_SHARP_7       EQU  6+4*12    ;$36
FA_SHARP_7      EQU  6+4*12    ;$36
G_FLAT_7        EQU  6+4*12    ;$36
SOL_FLAT_7      EQU  6+4*12    ;$36
G_7             EQU  7+4*12    ;$37
SOL_7           EQU  7+4*12    ;$37
G_SHARP_7       EQU  8+4*12    ;$38
SOL_SHARP_7     EQU  8+4*12    ;$38
A_FLAT_7        EQU  8+4*12    ;$38
LA_FLAT_7       EQU  8+4*12    ;$38
A_7             EQU  9+4*12    ;$39
LA_7            EQU  9+4*12    ;$39
A_SHARP_7       EQU 10+4*12    ;$3A
LA_SHARP_7      EQU 10+4*12    ;$3A
B_FLAT_7        EQU 10+4*12    ;$3A
SI_FLAT_7       EQU 10+4*12    ;$3A
B_7             EQU 11+4*12    ;$3B
SI_7            EQU 11+4*12    ;$3B

C_8             EQU  0+5*12    ;$3C
DO_8            EQU  0+5*12    ;$3C
C_SHARP_8       EQU  1+5*12    ;$3D
DO_SHARP_8      EQU  1+5*12    ;$3D
D_FLAT_8        EQU  1+5*12    ;$3D
RE_FLAT_8       EQU  1+5*12    ;$3D
D_8             EQU  2+5*12    ;$3E
RE_8            EQU  2+5*12    ;$3E
D_SHARP_8       EQU  3+5*12    ;$3F
RE_SHARP_8      EQU  3+5*12    ;$3F
E_FLAT_8        EQU  3+5*12    ;$3F
MI_FLAT_8       EQU  3+5*12    ;$3F
E_8             EQU  4+5*12    ;$40
MI_8            EQU  4+5*12    ;$40
F_8             EQU  5+5*12    ;$41
FA_8            EQU  5+5*12    ;$41
F_SHARP_8       EQU  6+5*12    ;$42
FA_SHARP_8      EQU  6+5*12    ;$42
G_FLAT_8        EQU  6+5*12    ;$42
SOL_FLAT_8      EQU  6+5*12    ;$42
G_8             EQU  7+5*12    ;$43
SOL_8           EQU  7+5*12    ;$43
G_SHARP_8       EQU  8+5*12    ;$44
SOL_SHARP_8     EQU  8+5*12    ;$44
A_FLAT_8        EQU  8+5*12    ;$44
LA_FLAT_8       EQU  8+5*12    ;$44
A_8             EQU  9+5*12    ;$45
LA_8            EQU  9+5*12    ;$45
A_SHARP_8       EQU 10+5*12    ;$46
LA_SHARP_8      EQU 10+5*12    ;$46
B_FLAT_8        EQU 10+5*12    ;$46
SI_FLAT_8       EQU 10+5*12    ;$46
B_8             EQU 11+5*12    ;$47
SI_8            EQU 11+5*12    ;$47

REST            EQU  0+6*12    ;$48
CUSTOM_NOTE     EQU  1+6*12    ;$49
CONTINUE        EQU  5+6*12    ;$4D


;SET_SPEED commands are used to change the length of one frame. The speed
;value is a fixed-point 8.8 number. The frame length is equal to the speed
;value multiplied by ~1/60 sec. You change the integer and the fractional part
;of the speed value separately.
SET_SPEED_FRAC  EQU  2+6*12    ;$4A
SET_SPEED_INT   EQU  4+6*12    ;$4C

;SET_TRANSPOSE transposes each note up or down the specified number of
;semitones (signed 8-bit parameter following SET_TRANSPOSE).
SET_TRANSPOSE   EQU  3+6*12    ;$4B   

;SET_ENVELOPE sets the channel's envelope to the 8-bit parameter which
;follows the command. Envelope $00 is reserved to silence. Envelopes
;numerically lesser than $10 choose one of 15 software envelopes specified in
;the table at SoundEnvelopeTable. All other values are hardware envelopes
;(bits 0-2: step length; bit 3: attenuate (0) / amplify (1); bits 4-7: envelope
;initial value).
SET_ENVELOPE    EQU $E0
;  SET_VIBRATO sets the channel's vibrato mode to the 8-bit parameter which
;follows the command (bits 0-2 = S; bits 3-5 = start time in frames, divided
;by 8; bits 6-7 = T). The vibrato produced is a triangular wave with period 
;2*T frames and amplitude S*T frequency units. SET_VIBRATO must not be used on
;channel 4.
SET_VIBRATO     EQU $E3
;  SET_WAVEFORM sets the channel's waveform. On channels 1 and 2, bits 6-7
;select between 12.5%, 25%, 50% and 75% duty cycles (in order 0 to 3); on 
;channel 3 it selects a waveform from SoundWaveSamples. This command must not
;be used on channel 4.
SET_WAVEFORM    EQU $E4
;  SET_PITCHBEND sets the channel's pitch bend to the specified frequency
;value, as a fixed-point 4.4 number. The output frequency is swept up by this
;amount each frame.
SET_PITCHBEND   EQU $E5

;When used on channel 1, all SET_SONG commands result in a song change.
;Which song is changed in is determined by the value of SoundBgmDynamicSong
;(or SoundSfxDynamicSong) if the command is SET_SONG_DYN; or by the following
;8-bit parameter if the command is SET_SONG_PARAM.
SET_SONG_PARAM  EQU $E1
SET_SONG_DYN    EQU $E2

;SEQ_CALL starts playing a sub-sequence addressed by the 16-bit absolute 
;address which follows the command's byte. SEQ_RETURN terminates the sub-
;sequence, and resumes playing of the main sequence. Multiple nested sub-
;sequences are not allowed. The channel's state is not altered when entering or 
;returning from the sub-sequence.
SEQ_CALL        EQU $FE
SEQ_RETURN      EQU $F0

;The SEQ_REPEAT commands repeat the specified number of times (once for
;SEQ_REPEAT_1, twice for SEQ_REPEAT_2...) the sequence chunk ending at the
;SEQ_REPEAT command and starting at the address specified by the following
;16-bit absolute address. Multiple nested repeats are not allowed.
SEQ_REPEAT_1    EQU $F1
SEQ_REPEAT_2    EQU $F2
SEQ_REPEAT_3    EQU $F3
SEQ_REPEAT_4    EQU $F4
SEQ_REPEAT_5    EQU $F5
SEQ_REPEAT_6    EQU $F6
SEQ_REPEAT_7    EQU $F7
SEQ_REPEAT_8    EQU $F8
SEQ_REPEAT_9    EQU $F9
SEQ_REPEAT_10   EQU $FA
SEQ_REPEAT_11   EQU $FB
SEQ_REPEAT_12   EQU $FC
SEQ_REPEAT_13   EQU $FD

;SEQ_JUMP transfers control to the sequence starting at the address specified
;by the 16-bit absolute address which follows the command's byte.
SEQ_JUMP        EQU $FF

      
      
      

