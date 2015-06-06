
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <rxgcommon>
#include <tf2attributes>


#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Speed Cloak",
	author = "Roker",
	description = "Move fast while cloaked.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

float baseSpeed[MAXPLAYERS+1];
bool modified[MAXPLAYERS+1];	

int validWeapons[] =  { 30, 212, 297, 947 };
//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_spawn", Event_Player_Spawn);
	HookEvent( "player_death", Event_Player_Death);
}
//-----------------------------------------------------------------------------
public Action Event_Player_Spawn( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	baseSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if(modified[client]){
		TF2Attrib_RemoveByName(client, "increased jump height");
	}
}
//-----------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThink, checkSpeed);
}
//-----------------------------------------------------------------------------
public TF2_OnConditionRemoved(client, TFCond:condition){
	if(condition == TFCond_Cloaked){
		if(modified[client]){
			TF2Attrib_RemoveByName(client, "increased jump height");
		}
	}
}
//-----------------------------------------------------------------------------
public checkSpeed(client)
{
	if (!IsValidClient(client)) { return; }
	if (!IsPlayerAlive(client)) { return; }
	if (TF2_GetPlayerClass(client) != TFClass_Spy) { return;}
	
	int weapon = GetPlayerWeaponSlot( client, 4 );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if (!IsValidWeapon(index)) { return; }
	
	if (!TF2_IsPlayerInCondition(client, TFCond_Cloaked)) { return; }
	
	if(baseSpeed[client] == 1.0){ //when player is frozen at start of round
		baseSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
		return;
	}
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", baseSpeed[client]*1.3);
	TF2Attrib_SetByName(client, "increased jump height", 1.5);
	modified[client] = true;
}
//-----------------------------------------------------------------------------
bool IsValidWeapon(int index){
	for (int i = 0; i < sizeof(validWeapons);i++){
		if(index == validWeapons[i]){
			return true;
		}
	}
	return false;
}