/**
 * @file
 * @brief Functions to handle speaking monsters
**/

#ifndef MONSPEAK_H
#define MONSPEAK_H

string mons_speech_name(const monster* mons, bool use_base_name);
void maybe_mons_speaks(monster* mons);
bool mons_speaks(monster* mons);
bool mons_speaks_msg(monster* mons, const string &msg,
                     const msg_channel_type def_chan = MSGCH_TALK,
                     const bool silence = false);

#endif
