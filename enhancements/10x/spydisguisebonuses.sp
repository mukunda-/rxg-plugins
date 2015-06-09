#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <rxgcommon>

int validWeapons[] =  { 574, 225 };
//int classHealth[] =  { 125, 125, 200, 175, 150, 175, 125, 125 };
//float classSpeed[] = {400.0, 300.0, 240.0, 280.0, 320.0, 230.0, 300.0, 300.0, 300.0};

float speed[MAXPLAYERS+1];
//bool modified[MAXPLAYERS+1];	

public Plugin myinfo = 
{
	name = "Spy Disguise Bonuses",
	author = "Roker",
	description = "A more convincing spy.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};
public void OnPluginStart()
{
	HookEvent( "player_death", Event_Player_Death, EventHookMode_Pre);
}
//-----------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThink, checkSpeed);
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {

	int client = GetClientOfUserId(GetEventInt( event, "attacker" ));
	int victim = GetClientOfUserId(GetEventInt( event, "userid" ));
	
	if( !IsValidClient(client) || !IsPlayerAlive(client) ) {return Plugin_Continue;	}
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	bool isBackstab = GetEventInt( event, "customkill" ) == TF_CUSTOM_BACKSTAB;
	
	if( !isBackstab ) { return Plugin_Continue;}
	if(!IntArrayContains(index, validWeapons, sizeof(validWeapons))) { return Plugin_Continue;}
	speed[client] = GetEntPropFloat(victim, Prop_Data, "m_flMaxspeed");
	
	TF2Attrib_SetByDefIndex(client, 26, GetEntProp(victim, Prop_Data, "m_iMaxHealth") - 125.0);
	SetEntityHealth(client, GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
	
	return Plugin_Continue;
}
public TF2_OnConditionRemoved(int client, TFCond condition){
	if(condition == TFCond_Disguised){
		if(speed[client] > 0.0){
			speed[client] = 0.0;
			TF2Attrib_RemoveByDefIndex(client, 26);
		}
	}
}
//-----------------------------------------------------------------------------
public checkSpeed(client)
{
	if (!IsValidClient(client)) { return; }
	if (!IsPlayerAlive(client)) { return; }
	
	if(speed[client] == 0){ return; }
	if (!TF2_IsPlayerInCondition(client, TFCond_Disguised)) { return; }
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", speed[client]);
}