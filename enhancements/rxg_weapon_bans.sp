

#include <sourcemod>
#include <cstrike>
#include <cstrike_weapons>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

//--------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "RXGweaponbans",
	author = "rxg",
	description = "Banning of gay weapons",
	version = PLUGIN_VERSION,
	url = "www.reflex-gamers.com"
};

//--------------------------------------------------------------------------
public OnPluginStart() {
	
}

//--------------------------------------------------------------------------
public Action:CS_OnBuyCommand( client, const String:weapon[] ) {
	new WeaponID:id = GetWeaponID( weapon );
	if( id == WEAPON_SCAR20 ||
		id == WEAPON_G3SG1 ||
		id == WEAPON_AWP || id == WEAPON_SCAR17 ) {

		// todo: make sound
		PrintToChat( client, "\x01 \x02[SM] The %s is banned.", weapon );
		return Plugin_Handled;
	}
	
	if( id == WEAPON_NEGEV ) {

		// todo: make sound
		PrintToChat( client, "\x01 \x02[SM] The NEGEV is currently banned!" );
		return Plugin_Handled;
		
	}
//	if( id == WEAPON_M249 ) {
//
//		// todo: make sound
//		PrintToChat( client, "\x01 \x02[SM] The M249 is currently banned!" );
//		return Plugin_Handled;
//		
//	}
	
	return Plugin_Continue;
}
