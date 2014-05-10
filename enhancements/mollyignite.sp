// name alert

#include <sourcemod>
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "mollyignite",
	author = "REFLEX-GAMERS",
	description = "ignites players who touch fire",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define BURN_TIME 1.0

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_hurt", Event_PlayerHurt );
}

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerHurt( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( !IsValidClient(client) ) return;
	
	decl String:weap[16];
	GetEventString( event, "weapon", weap, sizeof( weap ) );
	
	if( StrEqual( weap, "inferno" ) ) {
		new dmg = GetEventInt( event, "dmg_health" );
		if( dmg > 0 && GetEventInt( event, "health" ) > dmg ) {
			// ignite player
			IgniteEntity( client, BURN_TIME );
		}
		
	}
}
