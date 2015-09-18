
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1;
#pragma newdecls required;

public Plugin myinfo = {
	name = "Restart Fix",
	author = "WhiteThunder",
	description = "Fixes game restart",
	version = "1.4.0",
	url = "www.reflex-gamers.com"
};

// whether a player has spawned since the match restarted
bool g_spawned_t = false;
bool g_spawned_ct = false;

// hook player_spawn only once
bool g_spawn_event_hooked = false;

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	HookEvent( "cs_match_end_restart", Event_MatchRestart, EventHookMode_PostNoCopy );
	HookEvent( "cs_win_panel_match", Event_MatchEnd, EventHookMode_PostNoCopy );
}

// Disable win conditions at match end
//-----------------------------------------------------------------------------
public void Event_MatchEnd( Handle event, const char[] name, bool db ) {
	ServerCommand( "mp_ignore_round_win_conditions 1" );
}

// Hooks up player_spawn event on match restart
//-----------------------------------------------------------------------------
public void Event_MatchRestart( Handle event, const char[] name, bool db ) {
	
	// prevent double hook (just in case)
	if( g_spawn_event_hooked ) {
		return;
	}
	
	// reset flags which event will use
	g_spawned_t = false;
	g_spawned_ct = false;
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	g_spawn_event_hooked = true;
}

// Waits for both a T and a CT to spawn before re-enabling win conditions.
//-----------------------------------------------------------------------------
public Action Event_PlayerSpawn( Handle event, const char[] name,
								bool dontBroadcast ) {
	
	int client = GetClientOfUserId( GetEventInt(event, "userid") );
	int team = GetClientTeam( client );
	
	if( team == 2 ) {
		g_spawned_t = true;
	} else if( team == 3 ) {
		g_spawned_ct = true;
	}
	
	if( g_spawned_t && g_spawned_ct ) {
		ServerCommand( "mp_ignore_round_win_conditions 0" );
		UnhookEvent( "player_spawn", Event_PlayerSpawn );
		g_spawn_event_hooked = false;
	}
	
	return Plugin_Continue;
}
