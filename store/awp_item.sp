
#include <sourcemod>
#include <sdktools>
#include <rxgstore>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "awp item",
	author = "WhiteThunder",
	description = "disposable awp",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define ITEM_NAME "awp"
#define ITEM_FULLNAME "awp"
#define ITEMID 13

//-----------------------------------------------------------------------------
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
}

//-----------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-----------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-----------------------------------------------------------------------------
public RXGSTORE_OnUse(client) {
	if( !IsPlayerAlive(client) ) return false;
	
	if ( GetTeamScore(2) == 0 && GetTeamScore(3) == 0 ) {
		PrintToChat( client, "\x01 \x02You may not unpack an AWP yet." );
		return false;
	}
	
	PrintToChat( client, "Here is your AWP." );
	GivePlayerItem( client, "weapon_awp" );
	new team = GetClientTeam(client);
	decl String:msg[256];
	FormatEx( msg, sizeof msg, "\01 \x03%N has unpackaged an AWP!", client );
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && GetClientTeam(i) == team ) {
			PrintToChat( i, msg );
		}
	}
	return true;
}
