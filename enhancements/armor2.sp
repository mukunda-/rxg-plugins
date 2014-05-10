

#include <sourcemod>
#include <sdktools>

// 1.0.2
//   halftime fix
// 1.0.1
//   remove defuser from pistol round
 
//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
//-------------------------------------------------------------------------------------------------
	name = "freearmor2",
	author = "mukunda",
	description = "freearmor2",
	version = "1.0.2",
	url="Pow!"
};
 
//-------------------------------------------------------------------------------------------------
public OnPluginStart() { 
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	CreateTimer( 0.25, poopdick );


}

public Action:poopdick( Handle:timer ) {
	// why i have to do this, is dumb
	for( new client = 1; client <= MaxClients; client++ ) {
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

//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
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
