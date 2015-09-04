
#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo = {
	name = "Game Start Fix",
	author = "WhiteThunder",
	description = "Fixes game start",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
}

#define RESTART_DELAY 60

int g_last_restart = -RESTART_DELAY;

//-----------------------------------------------------------------------------
public Event_RoundStart( Handle event, const char[] name, bool db ) {
	
	int time = GetTime();
	
	if( g_last_restart + RESTART_DELAY < time &&
			GetTeamScore(2) == 0 && GetTeamScore(3) == 0 ) {
		
		g_last_restart = time;
		CS_TerminateRound( 1.0, CSRoundEnd_GameStart );
	}
}
