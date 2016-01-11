#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Consume Fire",
	author = "Roker",
	description = "",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

int validWeapons[] =  { 595 };

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
	
 	if(TF2_IsPlayerInCondition(victim, TFCond_OnFire)){
 		TF2_RemoveCondition(victim, TFCond_OnFire);	
 	}
 	return Plugin_Continue;
}