 
#include <sourcemod>
#include <sdktools>
#include <monoculus>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "spectral monoculus item",
	author = "WhiteThunder",
	description = "spawnable spectral monoculus",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_NAME "spectral_monoculus"
#define ITEM_FULLNAME "spectral_monoculus"
#define ITEMID 9

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	return MONO_SpawnMonoculus( client, GetClientTeam(client) );
}



















