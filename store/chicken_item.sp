 
#include <sourcemod>
#include <sdktools>
#include <rxgstore>
#include <chickenthrowing>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "chicken item",
	author = "WhiteThunder",
	description = "throwable chickens",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};


#define GRAVITY 800.0
#define GRAVITY_MULT 0.5
#define SPEED 750.0
#define SCALE 1.0

#define ITEM_NAME "chicken"
#define ITEM_FULLNAME "chicken"
#define ITEMID 7

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
	CHKN_ThrowChicken(client, SCALE, SPEED, GRAVITY * GRAVITY_MULT);
	return true;
}
