// rxg casual cash system
#include <sourcemod>
#include <sdktools>
  
//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
//-------------------------------------------------------------------------------------------------
	name = "cash2",
	author = "mukunda",
	description = "cash2",
	version = "1.0.1",
	url="REFLEX GAMERS DOT COM"
};

new Handle:rxg_mincash;
new c_mincash;

new bool:g_first_round;
new bool:g_is_warmup;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() { 
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart );
	
	rxg_mincash = CreateConVar( "rxg_mincash", "3500", "Minimum amount of cash players start with (on non-pistol round)", FCVAR_PLUGIN );
	HookConVarChange( rxg_mincash, OnConVarChanged );
	c_mincash = GetConVarInt( rxg_mincash );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == rxg_mincash ) {
		c_mincash = GetConVarInt( rxg_mincash );
	}
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:nobroadcast ) {

	new warmup = GameRules_GetProp( "m_bWarmupPeriod" );
	if( warmup ) {
		g_is_warmup = true;
		return;
	}
	g_is_warmup = false;
	
	new total_score = GetTeamScore(2) + GetTeamScore(3);
	if( total_score == 0 ) {
		g_first_round = true;
		return;
	}
	
	if( GetConVarInt( FindConVar( "mp_halftime" ) ) == 1 ) {
		if( total_score == GetConVarInt( FindConVar( "mp_maxrounds" ) ) / 2 ) {
			g_first_round = true;
			return;
		}
	}
	g_first_round = false;
	
}

//-------------------------------------------------------------------------------------------------
public Action:PlayerSpawnDelay( Handle:timer, any:data ) {
	new client = GetClientOfUserId( data );
	if( client == 0 ) return;
	
	if( g_is_warmup ) {
		SetEntProp( client, Prop_Send, "m_iAccount", 16000 );
		SetEntProp( client, Prop_Send, "m_bHasHelmet", 1 );
		SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
	}
	
	if( g_first_round ) {
		// delete defuser
		SetEntProp( client, Prop_Send, "m_bHasDefuser", 0 );
	} else {
		if( GetEntProp( client, Prop_Send, "m_iAccount" ) < c_mincash ) {
			SetEntProp( client, Prop_Send, "m_iAccount", c_mincash );
		}
		SetEntProp( client, Prop_Send, "m_bHasHelmet", 1 );
		SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:nobroadcast ) {
	CreateTimer( 0.25, PlayerSpawnDelay, GetEventInt( event, "userid" ), TIMER_FLAG_NO_MAPCHANGE ); 
}

