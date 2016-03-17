#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Max Health on Kill",
	author = "Roker",
	description = "Increase max health on kill.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 214
int kills[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
public void OnPluginStart(){
	HookEvent( "player_death", Event_Player_Death);
	HookEvent( "teamplay_round_start", Event_Round_Start );
}

//-----------------------------------------------------------------------------
public Action Event_Round_Start( Handle event, const char[] name, bool dontBroadcast ) {
	for(int i=1;i<=MaxClients;i++){
		if( !IsValidClient(i) ) continue;
		if( !IsPlayerAlive(i))  continue;
		if(kills[i]){
			removeStats(i);
		}
	}
}

//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	int victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if(kills[victim] != 0){
		removeStats(victim);
	}
	int shooter_id = GetEventInt( event, "attacker" );
	int killer = GetClientOfUserId( shooter_id );
	
	if( !IsValidClient(killer) || !IsPlayerAlive(killer) ) return Plugin_Continue;
	int weapon = GetPlayerWeaponSlot( killer, TFWeaponSlot_Melee );
	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	if(index != WEAPON_INDEX) return Plugin_Continue;
	if(weapon 
	if(kills[killer] < 4){
		kills[killer]++;
		Address adr = TF2Attrib_GetByDefIndex(weapon, 26);
		float health = 0.0;
		if(adr != Address_Null){
			health = TF2Attrib_GetValue(adr);
		}
		TF2Attrib_SetByDefIndex(weapon, 26, health + 25.0);
	}
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
void removeStats(int client){
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );
	if(!IsValidEntity(weapon)){return;}
	
	TF2Attrib_RemoveByDefIndex(weapon, 26);
	kills[client] = 0;
}