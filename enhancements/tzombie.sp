#include <sourcemod>
#include <sdktools>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =  {
	name = "tzombies",
	author = "reflex gamers",
	description = "???",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com/"
};

public OnPluginStart() {
	HookEvent ( "player_spawn", PlayerSpawn );
}

public OnMapStart() {
	PrecacheModel ("models/player/zombie.mdl" );
}

public PlayerSpawn( Handle:event, const String:name[], bool:dont ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( !client ) return;
	if( GetClientTeam(client) != 2 ) return;
	SetEntityModel( client, "models/player/zombie.mdl" );
}
