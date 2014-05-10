

// bacon program definition

//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "augs",
	author = "mukunda",
	description = "augs.",
	version = "1.0.0",
	url = "augs"
};


//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegServerCmd( "augs", augs );
	RegServerCmd( "negevs", negevs );
}

//-------------------------------------------------------------------------------------------------
public Action:augs( args ) {
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
		GivePlayerItem( i, "weapon_aug" );
		PrintToChat( i, "\x01 \x02You are strangely compelled to use an AUG." );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:negevs( args ) {
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
		GivePlayerItem( i, "weapon_negev" );
		PrintToChat( i, "\x01 \x02You are strangely compelled to use a NEGEV." );
	}
	return Plugin_Handled;
}