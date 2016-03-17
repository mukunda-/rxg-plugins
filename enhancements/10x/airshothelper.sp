#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Airshot Helper",
	author = "Roker",
	description = "POP POP",
	version = "1.0.4",
	url = "www.reflex-gamers.com"
};

int g_Attacker[MAXPLAYERS];
public void OnPluginStart(){
	for(int client=1;client<=MaxClients;client++){
		if(!IsValidClient(client)) continue;
		SDKHook(client, SDKHook_OnTakeDamage, Event_Damage);
	}
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer(int client){
	if(!IsValidClient(client)) return;
	SDKHook(client, SDKHook_OnTakeDamage, Event_Damage);
}

//-----------------------------------------------------------------------------
public Action Event_Damage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom){
	if(!IsValidClient(attacker)) return Plugin_Continue;
	if(!IsValidEntity(weapon)) return Plugin_Continue;
	char weaponClass[64];
	GetEntityClassname(weapon, weaponClass, 64);
	if(StrEqual(weaponClass, "eyeball_boss"))  return Plugin_Continue;
	if(victim == attacker)  return Plugin_Continue;
	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	if(index != 127)  return Plugin_Continue;
	
	g_Attacker[victim] = attacker; 
	
	Handle data;
	CreateDataTimer(0.1, Timer_HookPlayer, data);
	
	WritePackCell(data, weapon);
	WritePackCell(data, victim);
	if(TF2_IsPlayerInCondition(victim, TFCond_BlastJumping)){
		damagetype += DMG_CRIT;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public Action Timer_HookPlayer(Handle timer, Handle data){
	ResetPack(data);
	int weapon = ReadPackCell(data);
	int victim = ReadPackCell(data);
	
	if(TF2_IsPlayerInCondition(victim, TFCond_BlastJumping)){
		SetEntProp(weapon, Prop_Data, "m_iClip1", 4);
	}
	
	SDKHook(victim, SDKHook_PreThink, Airborne);
}

//-----------------------------------------------------------------------------
public void Airborne(int client){
	if(TF2_IsPlayerInCondition(client, TFCond_BlastJumping)){
		FocusMode(g_Attacker[client], true);
	}else{
		FocusMode(g_Attacker[client], false);
		SDKUnhook(client, SDKHook_PreThink, Airborne);
	}
}

//-----------------------------------------------------------------------------
void FocusMode(int client, bool enabled){
	if(!IsValidClient(client)) return;
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	if(enabled){
		TF2_AddCondition(client, TFCond_UberBlastResist);
		TF2Attrib_SetByDefIndex(weapon, 6, 0.2);
	}else{
		TF2_RemoveCondition(client, TFCond_UberBlastResist);
		TF2Attrib_RemoveByDefIndex(weapon, 6);
	}
}