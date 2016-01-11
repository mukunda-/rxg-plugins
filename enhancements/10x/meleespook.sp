#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <sdkhooks>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Melee Spook",
	author = "Roker",
	description = "Makes melee spook people",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

int validWeapons[] =  { 939 };

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	for( int client = 1; client <= MaxClients; client++ ) {
		if ( !IsValidClient(client) ) { continue; }
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

//-----------------------------------------------------------------------------
public Action OnTakeDamage( int victim, int &attacker, int &inflictor,
							float &damage, int &damagetype, int &weapon,
							float damageForce[3], float damagePosition[3] ) {
	
	// do client checks before weapon
	// both attacker and victim need to be clients
	if( !IsValidClient(attacker) || !IsValidClient(victim) ) {
		return Plugin_Continue;
	}
	
	if( !IsValidEntity(weapon) ) {
		return Plugin_Continue;
	}
	
	char weapon_classname[64];
	GetEntityClassname( weapon, weapon_classname, sizeof weapon_classname );
	
	// must be a client weapon, not an eyeball boss or something
	if( strncmp( weapon_classname, "tf_weapon", 9 ) != 0 ) {
		return Plugin_Continue;
	}
	
	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	
	if( !IntArrayContains( index, validWeapons, sizeof validWeapons ) ) {
		return Plugin_Continue;
	}
	
	TF2_StunPlayer(victim, 1.0, 0.5, TF_STUNFLAGS_GHOSTSCARE);
	return Plugin_Continue;
}
