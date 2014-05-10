
#include <sourcemod>
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Dynamic Hostage Count",
	author = "REFLEX GAMERS",
	description = "Extra hostages during high player capacity",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

new Handle:sm_dh_threshold;

new Handle:hostages;
new c_hostages;

new Handle:hpositions;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	sm_dh_threshold = CreateConVar( "sm_dh_threshold", "25", "Number of players to add an extra hostage" );
	hostages = FindConVar( "mp_hostages_max" );
	hpositions = FindConVar( "mp_hostages_spawn_force_positions" );
	c_hostages = GetConVarInt( hostages );
	HookEvent( "round_end", Event_RoundEnd, EventHookMode_PostNoCopy );
	c_hostages = 0;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	new players = GetTeamClientCount(2) + GetTeamClientCount(3);
	if( players >= GetConVarInt( sm_dh_threshold ) ) {
		if( c_hostages == 2 ) return;
		SetConVarInt( hostages, 3 );
		SetConVarString( hpositions, "0,2,3,4,5,7,8" );
		c_hostages = 2;
	} else {
		if( c_hostages == 1 ) return;
		SetConVarInt( hostages, 1 );
		SetConVarString( hpositions, "1,2,3,4,5,8" );
		c_hostages = 1;
	}
}
