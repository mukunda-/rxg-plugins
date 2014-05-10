#if defined _DONATIONWLawefawef_INCLUDED
 #endinput
#endif
#define _DONATIONWLawefawef_INCLUDED

forward Action:Flashmod_OnPlayerFlashed( flasher, flashee, &Float:alpha, &Float:duration );

forward Flashmod_OnPlayerTeamflash( flasher, num_teammates_flashed );

forward Flashmod_FlashbangStats( flasher, enemies_flashed, team_flashed, Float:enemies_duration_sum, Float:team_duration_sum );
