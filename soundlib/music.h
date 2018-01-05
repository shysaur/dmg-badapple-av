
#ifndef MUSICDRV_H
#define MUSICDRV_H

#define md_bool char
#define YES     -1
#define NO      0

void musicAdvanceFrame(void);
void musicResetDriver(void);
void musicSwitchSong(char songId);

void musicTriggerSfx(char songId);
void musicStopSfx(void);

#endif /* MUSICDRV_H */
