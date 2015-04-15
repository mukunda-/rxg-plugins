// rxg casual cash system

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {

	name        = "cash2",
	author      = "mukunda",
	description = "cash2",
	version     = "1.0.2",
	url         = "www.reflex-gamers.com"
};

Handle rxg_mincash;
int    c_mincash;

bool   g_first_round;
bool   g_is_warmup;

//-----------------------------------------------------------------------------
public void OnPluginStart() { 
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart );
	
	rxg_mincash = CreateConVar( "rxg_mincash", "3500", 
		"Minimum amount of cash players start with (on non-pistol round)", 
		FCVAR_PLUGIN );
		
	HookConVarChange( rxg_mincash, OnConVarChanged );
	
	c_mincash = GetConVarInt( rxg_mincash );
}

//-----------------------------------------------------------------------------
public void OnConVarChanged( Handle cv, const char[] ov, const char[] nv ) {
	c_mincash = GetConVarInt( rxg_mincash );
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool nb ) {

	bool warmup = !!GameRules_GetProp( "m_bWarmupPeriod" );
	if( warmup ) {
		g_is_warmup = true;
		return;
	}
	g_is_warmup = false;
	
	int total_score = GetTeamScore(2) + GetTeamScore(3);
	if( total_score == 0 ) {
		g_first_round = true;
		return;
	}
	
	if( GetConVarInt( FindConVar( "mp_halftime" ) ) == 1 ) {
		int maxrounds = GetConVarInt( FindConVar( "mp_maxrounds" ) );
		if( total_score == maxrounds / 2 ) {
			g_first_round = true;
			return;
		}
	}
	g_first_round = false;
}

//-----------------------------------------------------------------------------
public Action PlayerSpawnDelay( Handle timer, int userid ) {
	int client = GetClientOfUserId( userid );
	if( client == 0 ) return;
	
	if( g_is_warmup ) {
		SetEntProp( client, Prop_Send, "m_iAccount",   16000 );
		SetEntProp( client, Prop_Send, "m_bHasHelmet", 1     );
		SetEntProp( client, Prop_Send, "m_ArmorValue", 100   );
	}
	
	if( g_first_round ) {
	
		// delete defuser
		SetEntProp( client, Prop_Send, "m_bHasDefuser", 0 );
		
	} else {
	
		// give minimum cash
		if( GetEntProp( client, Prop_Send, "m_iAccount" ) < c_mincash ) {
			SetEntProp( client, Prop_Send, "m_iAccount", c_mincash );
		}
		
		// give armor
		SetEntProp( client, Prop_Send, "m_bHasHelmet", 1 );
		SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
		
	}
}

//-----------------------------------------------------------------------------
public void OnPlayerSpawn( Handle event, const char[] name, bool nb ) {
	int userid = GetEventInt( event, "userid" );
	
	CreateTimer( 0.25, PlayerSpawnDelay, userid, TIMER_FLAG_NO_MAPCHANGE ); 
}
