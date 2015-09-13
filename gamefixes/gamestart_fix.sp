
#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo = {
	name = "Game Start Fix",
	author = "WhiteThunder",
	description = "Fixes game start",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
}

// prevent infinite restart
#define RESTART_COOLDOWN 60

int g_last_restart = -RESTART_COOLDOWN;

//-----------------------------------------------------------------------------
public Event_RoundStart( Handle event, const char[] name, bool db ) {
	
	int time = GetTime();
	
	if( g_last_restart + RESTART_COOLDOWN < time &&
			GetTeamScore(2) == 0 && GetTeamScore(3) == 0 ) {
		
		g_last_restart = time;
		int players = CountPlayers();
		
		// give time to join teams so people don't get stuck on join screen
		float restart_delay = 1.0;
		
		if( players > 20 ) {
			restart_delay = 3.0;
		} else if( players > 10 ) {
			restart_delay = 2.0;
		}
		
		CreateTimer( restart_delay, Timer_RestartRound );
	}
}

//-----------------------------------------------------------------------------
public int CountPlayers() {
	int players = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) ) players++;
	}
	return players;
}

//-----------------------------------------------------------------------------
public Action Timer_RestartRound( Handle timer, any data ) {
	// CSRoundEnd_GameStart ignores the time argument
	CS_TerminateRound( 0.0, CSRoundEnd_GameStart );
}