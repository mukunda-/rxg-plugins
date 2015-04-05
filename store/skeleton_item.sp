 
#include <sourcemod>
#include <sdktools>
#include <skeleton>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "skeleton item",
	author = "Roker",
	description = "spawnable skeleton",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_NAME "skeleton"
#define ITEM_FULLNAME "skeleton"
#define ITEMID 14

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

//------------------------------------------------------------------m-------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	if(!SKEL_SpawnSkeleton( client, GetClientTeam(client) )){
		RXGSTORE_ShowUseItemMenu(client);
		return false;
	}else{
		return true;
	}	
}



















