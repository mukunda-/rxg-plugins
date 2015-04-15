#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

// 1.0.2
//   halftime fix
// 1.0.1
//   remove defuser from pistol round
 
//-----------------------------------------------------------------------------
public Plugin myinfo = {

	name        = "freearmor2",
	author      = "mukunda",
	description = "freearmor2",
	version     = "1.1.0",
	url         = "www.mukunda.com"
};
 
//-----------------------------------------------------------------------------
public void OnPluginStart() { 
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool db ) {
	CreateTimer( 0.25, PoopDick );
}

//-----------------------------------------------------------------------------
public Action PoopDick( Handle timer ) {

	// why i have to do this, is dumb
	for( int client = 1; client <= MaxClients; client++ ) {
		if( !IsClientInGame( client ) ) continue;
		if( GetEntProp( client, Prop_Send, "m_iAccount" ) >= 1000 ) {
				
		} else {
			// delete defuser
			SetEntProp( client, Prop_Send, "m_bHasHelmet", 0 );
			SetEntProp( client, Prop_Send, "m_ArmorValue", 0 );
			SetEntProp( client, Prop_Send, "m_bHasDefuser", 0 );
		}
	}
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void OnPlayerSpawn( Handle event, const char[] name, bool db ) {
	int client = GetClientOfUserId( GetEventInt( event, "userid" ));
	if( client == 0 ) return;
	if( GetEntProp( client, Prop_Send, "m_iAccount" ) >= 1000 ) {
		// refresh armor
		SetEntProp( client, Prop_Send, "m_bHasHelmet", 1 );
		SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
	} else {
		// delete defuser
		SetEntProp( client, Prop_Send, "m_bHasDefuser", 0 );
	}
}
