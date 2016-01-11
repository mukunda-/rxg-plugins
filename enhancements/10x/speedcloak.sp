
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
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

float baseSpeed[MAXPLAYERS+1];
bool modified[MAXPLAYERS+1];	

int validWeapons[] =  { 30, 212, 297, 947 };

//-----------------------------------------------------------------------------
public OnPluginStart() {
	for( int client = 1; client <= MaxClients; client++ ) {
		if ( !IsValidClient(client) ) { continue; }
		SDKHook(client, SDKHook_PreThink, checkSpeed);
	}
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
public TF2_OnConditionAdded(client, TFCond:condition){
	if(condition == TFCond_Cloaked){
		if (!IsValidClient(client)) { return; }
		if (!IsPlayerAlive(client)) { return; }
		
		int weapon = GetPlayerWeaponSlot( client, 4 );
		int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
		
		if (!IntArrayContains(index, validWeapons, sizeof(validWeapons))) {return;}

		TF2Attrib_SetByName(client, "increased jump height", 1.5);
	}
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
	
	int weapon = GetPlayerWeaponSlot( client, 4 );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if (!IntArrayContains(index, validWeapons, sizeof(validWeapons))) {return;}
	
	if (!TF2_IsPlayerInCondition(client, TFCond_Cloaked)) { return; }
	
	if(baseSpeed[client] == 1.0){ //when player is frozen at start of round
		baseSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
		return;
	}
	TF2Attrib_SetByName(client, "increased jump height", 1.5);
	modified[client] = true;
}