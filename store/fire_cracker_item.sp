 
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <storeweapons>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Fire Cracker Weapon",
	author = "WhiteThunder",
	description = "Equips a Fire Cracker",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_NAME "fire_cracker"
#define ITEM_FULLNAME "fire_cracker"
#define ITEMID 11

#define WEAPON_INDEX 6667
#define WEAPON_NAME "Fire Cracker"
#define WEAPON_TEXT_COLOR "EB0000"
#define CLASS_RESTRICTION TFClass_Pyro

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
	return STOREWEAPONS_GiveWeapon( client, WEAPON_INDEX, CLASS_RESTRICTION, WEAPON_NAME, WEAPON_TEXT_COLOR );
}
