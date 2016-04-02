#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <rxgtfcommon>
#include <tf2_stocks>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "FireSpeed",
	author = "Roker",
	description = "Move fast when near ppl on fiar",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 38

int 	lit[MAXPLAYERS];
float 	baseSpeed[MAXPLAYERS];
bool 	equipped[MAXPLAYERS];
bool 	enemyLit[MAXPLAYERS];

public void OnPluginStart(){
	HookEvent("player_ignited", Event_Ignited, EventHookMode_Post);
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
}

//-----------------------------------------------------------------------------
public Action Event_Spawn(Handle event, char[] args, bool noBroadcast){ 
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	lit[client] = false;
	equipped[client] = false;
	baseSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
	
	if(index != WEAPON_INDEX){
		SDKUnhook(client, SDKHook_PreThink, setSpeed);
		SDKUnhook(client, SDKHook_WeaponSwitchPost, Event_Weapon_Switch);
		return;
	}
	SDKHook(client, SDKHook_PreThink, setSpeed);
	SDKHook(client, SDKHook_WeaponSwitchPost, Event_Weapon_Switch);
}

//-----------------------------------------------------------------------------
public Action Event_Ignited(Handle event, char[] args, bool noBroadcast){
	int client = GetEventInt(event, "pyro_entindex");
	int victim = GetEventInt(event, "victim_entindex");
	lit[victim] = client;
	enemyLit[client] = true;
	
	Handle data;
	CreateDataTimer(0.5, Timer_Check_Lit, data, TIMER_REPEAT);
	WritePackCell(data, victim); 
}

//-----------------------------------------------------------------------------
public Action Timer_Check_Lit(Handle timer, Handle data){
	ResetPack(data);
	int client = ReadPackCell(data);
	if(IsValidClient(client))
		if(TF2_IsPlayerInCondition(client, TFCond_OnFire)) return Plugin_Continue;
	
	int toCheck = lit[client];
	lit[client] = 0;
	checkEnemyLit(toCheck);
	return Plugin_Stop;
}

//-----------------------------------------------------------------------------
public Action Event_Weapon_Switch(int client, int weapon){
	int index = GetWeaponIndex(weapon);
	if(index == WEAPON_INDEX){
		equipped[client] = true;
		if(baseSpeed[client] <= 1.0){
			baseSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
		}
	}else{
		equipped[client] = false;
	}
}

//-----------------------------------------------------------------------------
public Action setSpeed(int client){
	if(enemyLit[client] && equipped[client]){
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", baseSpeed[client] * 1.5);
	}
}

//-----------------------------------------------------------------------------
void checkEnemyLit(int client){
	for(int i=0;i<MaxClients;i++){
		if(lit[i] == client){
			return;
		}
	}
	enemyLit[client] = false;
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", baseSpeed[client]);	
}