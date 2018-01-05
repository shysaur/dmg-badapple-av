

INCLUDE "m_config.inc"


GLOBAL SoundReset
GLOBAL SoundFrame


GLOBAL SoundChangeBgm

IF BGM_WITH_VOLUME
GLOBAL SoundBgmAttenuation
ENDC

IF BGM_WITH_DYNTRACK
GLOBAL SoundBgmDynamicSong
ENDC


IF BUILD_SFX

GLOBAL SoundChangeSfx

IF SFX_WITH_DYNTRACK
GLOBAL SoundSfxDynamicSong
ENDC

ENDC
