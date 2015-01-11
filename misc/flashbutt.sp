

#include <sourcemod>
#include <sdktools>
#include <flashmod>

#pragma semicolon 1

public Plugin:myinfo = {
	name = "flashbutt",
	author = "mukunda",
	description = "Flashbang blocker for practice.",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public Action:Flashmod_OnPlayerFlashed( flasher, flashee, &Float:alpha, &Float:duration ) {

	PrintToChat( flashee, "\x01 \x04Flashed for %.2f seconds.", duration );
	duration = duration * 0.1;
	alpha = alpha * 0.1;
	return Plugin_Changed;
	
}
