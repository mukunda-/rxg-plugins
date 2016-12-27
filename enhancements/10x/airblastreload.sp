
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Airblast Ammo Refund",
	author = "WhiteThunder",
	description = "Refunds ammo after successful airblast with stock flamethrower",
	version = "1.0.2",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 21
#define AMMO_COST 5 //Based on weapon attribute
#define REFUND_MULTIPLIER 2 //Multiplier for how much ammo to refund
#define AMMO_MAX 200
#define HEALTH_RETURN 5

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "object_deflected", Event_AirBlast );
}

//-----------------------------------------------------------------------------
public Action Event_AirBlast( Handle event, const char name[], bool dontBroadcast ) {
	
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Primary );
	
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if( index != WEAPON_INDEX ) {
		return Plugin_Continue;
	}
	
	int iOffset = GetEntProp( weapon, Prop_Send, "m_iPrimaryAmmoType", 1 ) * 4;
	int iAmmoTable = FindSendPropInfo( "CTFPlayer", "m_iAmmo" );
	int currentAmmo = GetEntData( client, iAmmoTable + iOffset, 4 );
	
	int newAmmo = currentAmmo > AMMO_MAX ? AMMO_MAX : currentAmmo;
	SetEntData( client, iAmmoTable + iOffset, newAmmo + AMMO_COST * REFUND_MULTIPLIER, 4, true );
	
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	int health = GetEntProp(client, Prop_Data, "m_iHealth");
	health += HEALTH_RETURN;
	if(health > maxHealth){
		health = maxHealth;
	}
	SetEntProp(client, Prop_Data, "m_iHealth", health);
	return Plugin_Continue;
}
