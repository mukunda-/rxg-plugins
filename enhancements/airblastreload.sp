
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Airblast Auto Reload",
	author = "WhiteThunder",
	description = "Refunds ammo after successful airblast with stock flamethrower",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 21
#define AMMO_COST 5 //Based on weapon attribute
#define AMMO_MAX 200

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "object_deflected", Event_AirBlast );
}

//-----------------------------------------------------------------------------
public Action:Event_AirBlast( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Primary );
	
	new index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if( index != WEAPON_INDEX ) {
		return Plugin_Continue;
	}
	
	new iOffset = GetEntProp( weapon, Prop_Send, "m_iPrimaryAmmoType", 1 ) * 4;
	new iAmmoTable = FindSendPropInfo( "CTFPlayer", "m_iAmmo" );
	new currentAmmo = GetEntData( client, iAmmoTable + iOffset, 4 );
	
	new newAmmo = currentAmmo > AMMO_MAX ? AMMO_MAX : currentAmmo;
	SetEntData( client, iAmmoTable + iOffset, newAmmo + AMMO_COST, 4, true );
	
	return Plugin_Continue;
}
