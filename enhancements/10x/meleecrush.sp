#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <tf2_stocks>

#pragma semicolon 1

public Plugin myinfo = {
	name = "Melee Crush",
	author = "Roker",
	description = "Crush People",
	version = "1.0.2",
	url = "www.reflex-gamers.com"
};

#define CRUSH_TIME 2.5
#define CRUSH_SIZE 0.01

int validWeapons[] =  { 1123 };

float g_torsoSize[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	for( int client = 1; client <= MaxClients; client++ ) {
		if ( !IsValidClient(client) ) { continue; }
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

//-----------------------------------------------------------------------------
public OnClientPutInServer(client) {
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

//-----------------------------------------------------------------------------
public Action OnTakeDamage( int victim, int &attacker, int &inflictor,
							float &damage, &damagetype, &weapon,
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
	
	if( g_torsoSize[victim] == 1.0 || g_torsoSize[victim] < CRUSH_SIZE ) {
		SDKHook(victim, SDKHook_PreThink, PreThink);
	}
	
	g_torsoSize[victim] = CRUSH_SIZE;
	TF2_StunPlayer( victim, CRUSH_TIME, 0.5 ,TF_STUNFLAGS_LOSERSTATE, attacker );
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public PreThink(client) {
	
	g_torsoSize[client] += GetTickInterval() / CRUSH_TIME * (1-CRUSH_SIZE);
	
	if( g_torsoSize[client] >= 1.0 ) {
		g_torsoSize[client] = 1.0;
		SDKUnhook(client, SDKHook_PreThink, PreThink);
	}
	
	SetEntPropFloat( client, Prop_Send, "m_flTorsoScale", g_torsoSize[client] );
	SetEntPropFloat( client, Prop_Send, "m_flHeadScale", g_torsoSize[client] );
}