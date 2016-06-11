

#include <sourcemod>
#include <cstrike>
#include <cstrike_weapons>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.1.0"

//--------------------------------------------------------------------------
public Plugin myinfo =
{
	name = "RXGweaponbans",
	author = "rxg",
	description = "Banning of gay weapons",
	version = PLUGIN_VERSION,
	url = "www.reflex-gamers.com"
};

Handle rxg_weapons_ban_awp;
bool c_rxg_weapons_ban_awp;

//--------------------------------------------------------------------------
RecacheConvars() {
	c_rxg_weapons_ban_awp = GetConVarBool(rxg_weapons_ban_awp);
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
	RecacheConvars();
}

//--------------------------------------------------------------------------
public OnPluginStart() {
	rxg_weapons_ban_awp = CreateConVar( "rxg_weapons_ban_awp", "1", "Whether to ban AWP");
	HookConVarChange( rxg_weapons_ban_awp, OnConVarChanged );
	RecacheConvars();
}

//--------------------------------------------------------------------------
public Action CS_OnBuyCommand( client, const char[] weapon ) {
	WeaponID id = GetWeaponID( weapon );
	if( id == WEAPON_SCAR20 ||
		id == WEAPON_G3SG1 ||
		id == WEAPON_SCAR17 ||
		(c_rxg_weapons_ban_awp && id == WEAPON_AWP)) {

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
