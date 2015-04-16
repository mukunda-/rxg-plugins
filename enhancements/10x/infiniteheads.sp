#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Infinite Heads",
	author = "Roker",
	description = "All heads benefit user.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 132
bool extra_stats[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
public void OnPluginStart(){
	HookEvent( "player_death", Event_Player_Death);
	HookEvent( "teamplay_round_win", Event_Round_End );
}
//-----------------------------------------------------------------------------
public Action Event_Round_End( Handle event, const char[] name, bool dontBroadcast ) {
	for(int i=1;i<=MaxClients;i++){
		if( !IsValidClient(i) ) continue;
		if( !IsPlayerAlive(i))  continue;
		if(extra_stats[i]){
			removeStats(i);
		}
	}
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	int victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if(extra_stats[victim]){
		removeStats(victim);
	}
	int shooter_id = GetEventInt( event, "attacker" );
	int killer = GetClientOfUserId( shooter_id );
	
	if( !IsValidClient(killer) || !IsPlayerAlive(killer) ) {
		return Plugin_Continue;
	}
	int weapon = GetPlayerWeaponSlot( killer, TFWeaponSlot_Melee );	

	bool isDecapitation = GetEventInt( event, "customkill" ) == TF_CUSTOM_DECAPITATION;
	
	if( !isDecapitation) {
		return Plugin_Continue;
	}
	int heads = GetEntProp(killer, Prop_Send, "m_iDecapitations");
	if(heads < 8){
		heads+=1;
	}
	SetEntProp(killer, Prop_Send, "m_iDecapitations",heads);
	if(heads > 4){
		heads-=4;
		TF2Attrib_SetByDefIndex(weapon,107,1.0 + 0.06*heads);
		TF2Attrib_SetByDefIndex(weapon,26,15.0*heads);
	}
	
	extra_stats[killer] = true;
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
void removeStats(int client){
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );	
	TF2Attrib_RemoveByDefIndex(weapon,26);
	TF2Attrib_RemoveByDefIndex(weapon,107);
	extra_stats[client] = false;
}
