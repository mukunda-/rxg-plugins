#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "Melee Spin",
	author = "Roker",
	description = "Make melee turn people",
	version = "1.0.3",
	url = "www.reflex-gamers.com"
};

int validWeapons[] =  { 221, 999 };

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	for( int client = 1; client <= MaxClients; client++ ) {
		if (!IsValidClient(client)) { continue; }
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer( int client ) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

//-----------------------------------------------------------------------------
public Action OnTakeDamage( int victim, int &attacker, int &inflictor,
							float &damage, int &damagetype, int &weapon,
							float damageForce[3], float damagePosition[3],
							int damagecustom) {
	
	if( !IsValidClient(attacker) || !IsValidClient(victim) || !IsValidEntity(weapon) ) {return Plugin_Continue;}
	
	char weapon_classname[64];
	GetEntityClassname( weapon, weapon_classname, sizeof weapon_classname );
	if( strncmp( weapon_classname, "tf_weapon", 9 ) != 0 ) {return Plugin_Continue;} // must be a client weapon, not an eyeball boss or something
	
	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	if (!IntArrayContains(index, validWeapons, sizeof(validWeapons))) {
		return Plugin_Continue;
	}
	
 	float look[3];
 	GetClientAbsAngles(victim, look);
 	look[1] += 180.0;
	
 	TeleportEntity(victim, NULL_VECTOR, look, NULL_VECTOR);
	
 	return Plugin_Continue;
}