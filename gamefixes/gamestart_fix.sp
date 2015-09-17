
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1;
#pragma newdecls required;

public Plugin myinfo = {
	name = "Game Start Fix",
	author = "WhiteThunder",
	description = "Fixes game start",
	version = "1.3.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	HookEvent( "cs_match_end_restart", OnMatchRestart, EventHookMode_PostNoCopy );
	HookEvent( "cs_win_panel_match", Event_MatchEnd );
}

//-----------------------------------------------------------------------------
public void Event_MatchEnd( Handle event, const char[] name, bool db ) {
	ServerCommand( "mp_ignore_round_win_conditions 1" );
}

//-----------------------------------------------------------------------------
public void OnMatchRestart( Handle event, const char[] name, bool db ) {
	ServerCommand( "mp_ignore_round_win_conditions 0" );
}
