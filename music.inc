

INCLUDE "m_config.inc"


GLOBAL SoundReset
GLOBAL SoundFrame

GLOBAL SoundChangeBgm
GLOBAL SoundChangeSfx

IF BGM_WITH_VOLUME
GLOBAL SoundBgmAttenuation
ENDC

IF BGM_WITH_DYNTRACK
GLOBAL SoundBgmDynamicSong
ENDC
IF SFX_WITH_DYNTRACK
GLOBAL SoundSfxDynamicSong
ENDC
