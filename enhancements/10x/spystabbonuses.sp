#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <tf2_stocks>

public Plugin myinfo = 
{
	name = "Backstab Bonuses",
	author = "Roker",
	description = "Spy gets bonuses on ",
	version = "1.0",
	url = "www.reflex-gamers.com"
};

int validWeapons[] =  { 461 };

public void OnPluginStart()
{
	HookEvent( "player_death", Event_Player_Death, EventHookMode_Post);
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {

	int client = GetClientOfUserId(GetEventInt( event, "attacker" ));
	
	if( !IsValidClient(client) || !IsPlayerAlive(client) ) {
		return Plugin_Continue;
	}
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	bool isBackstab = GetEventInt( event, "customkill" ) == TF_CUSTOM_BACKSTAB;
	
	if( !isBackstab || IsValidWeapon(index)) { return;}) {
		return Plugin_Continue;
	}
	
	TF2_AddCondition(client, TFCond_Cloaked);
	
	return Plugin_Continue;
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