
// designated for CSS to give players max money and armor each round

#include <sourcemod>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "moneys",
	author = "mukunda",
	description = "moneys",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_spawn", Event_PlayerSpawn );
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	SetEntProp( client, Prop_Send, "m_iAccount", 16000 );
	SetEntProp( client, Prop_Send, "m_bHasHelmet", 1 );
	SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
}
