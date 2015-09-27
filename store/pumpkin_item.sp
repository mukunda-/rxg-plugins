#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <rxgstore>
#include <tf2_stocks>
#include <pumpkin>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "pumpkin item",
	author = "WhiteThunder",
	description = "plantable pumpkin bombs",
	version = "3.0.0",
	url = "www.reflex-gamers.com"
};

#define ITEM_NAME "pumpkin"
#define ITEM_FULLNAME "pumpkin"
#define ITEMID 6

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const char[] name ) {
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
	return SpawnPumpkin(client);
}

//-------------------------------------------------------------------------------------------------
bool SpawnPumpkin( client ) {
	return Pumpkin_SpawnPumpkinAtAim(client);
}
