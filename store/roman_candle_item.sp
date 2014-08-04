 
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <storeweapons>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Roman Candle Weapon",
	author = "WhiteThunder",
	description = "Equips a Roman Candle",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_NAME "roman_candle"
#define ITEM_FULLNAME "roman_candle"
#define ITEMID 10

#define WEAPON_INDEX 666
#define WEAPON_NAME "Roman Candle"
#define WEAPON_TEXT_COLOR "ED5E00"
#define CLASS_RESTRICTION TFClass_Heavy

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
