
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1;
#pragma newdecls required;

public Plugin myinfo = {
	name = "Restart Fix (Map)",
	author = "WhiteThunder",
	description = "Fixes game restart",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

// whether a player has spawned since the map started
bool g_spawned_t = false;
bool g_spawned_ct = false;

// hook player_spawn only once
bool g_spawn_event_hooked = false;

public void OnMapStart() {
	SetConVarBool( FindConVar("mp_ignore_round_win_conditions"), true );
	
	// prevent double hook (in case of early map change)
	if( g_spawn_event_hooked ) {
		return;
	}
	
	g_spawned_t = false;
	g_spawned_ct = false;
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	g_spawn_event_hooked = true;
}

// Waits for both a T and a CT to spawn before re-enabling win conditions.
public Action Event_PlayerSpawn( Handle event, const char[] name, bool dontBroadcast ) {
	
	int client = GetClientOfUserId( GetEventInt(event, "userid") );
	int team = GetClientTeam( client );
	
	if( team == 2 ) {
		g_spawned_t = true;
	} else if( team == 3 ) {
		g_spawned_ct = true;
	}
	
	if( g_spawned_t && g_spawned_ct ) {
		SetConVarBool( FindConVar("mp_ignore_round_win_conditions"), false );
		UnhookEvent( "player_spawn", Event_PlayerSpawn );
		g_spawn_event_hooked = false;
	}
	
	return Plugin_Continue;
}