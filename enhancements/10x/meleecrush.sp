#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <tf2_stocks>

#pragma semicolon 1

public Plugin myinfo = 
{
	name = "Melee Crush",
	author = "Roker",
	description = "Crush People",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define CRUSH_TIME 2.5
#define CRUSH_SIZE 0.01

int validWeapons[] =  { 1123 };

float g_torsoSize[MAXPLAYERS+1];


//-----------------------------------------------------------------------------
public void OnPluginStart()
{
	for (int client = 1; client <= MaxClients;client++){
		if (!IsValidClient(client)) { continue; }
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}
//-----------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3]){
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	if (!IntArrayContains(index, validWeapons, sizeof(validWeapons))) { return Plugin_Continue; }
	if(!IsValidClient(victim)){ return Plugin_Continue; }
	if(g_torsoSize[victim] == 1.0 || g_torsoSize[victim] < CRUSH_SIZE){
		SDKHook(victim, SDKHook_PreThink, PreThink);
	}
	g_torsoSize[victim] = CRUSH_SIZE;
	TF2_StunPlayer(victim, CRUSH_TIME, 0.5 ,TF_STUNFLAGS_LOSERSTATE, attacker);
	
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public PreThink(client)
{
	g_torsoSize[client] += GetTickInterval() / CRUSH_TIME * (1-CRUSH_SIZE);
	if(g_torsoSize[client] >= 1.0){
		g_torsoSize[client] = 1.0;
		SDKUnhook(client, SDKHook_PreThink, PreThink);
	}
	SetEntPropFloat(client, Prop_Send, "m_flTorsoScale", g_torsoSize[client]);
	SetEntPropFloat(client, Prop_Send, "m_flHeadScale", g_torsoSize[client]);
}