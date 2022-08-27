

INCLUDE "m_config.inc"


EXPORT SoundReset
EXPORT SoundFrame


EXPORT SoundChangeBgm

IF BGM_WITH_VOLUME
EXPORT SoundBgmAttenuation
ENDC

IF BGM_WITH_DYNTRACK
EXPORT SoundBgmDynamicSong
ENDC


IF BUILD_SFX

EXPORT SoundChangeSfx

IF SFX_WITH_DYNTRACK
EXPORT SoundSfxDynamicSong
ENDC

ENDC
