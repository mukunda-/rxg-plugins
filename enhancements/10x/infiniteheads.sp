#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>
#include <tf2attributes>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Infinite Heads",
	author = "Roker",
	description = "All heads benefit user.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 132
new bool:extra_stats[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", Event_Player_Death);
	HookEvent( "teamplay_round_win", Event_Round_End );
}
//-----------------------------------------------------------------------------
public Action:Event_Round_End( Handle:event, const String:name[], bool:dontBroadcast ) {
	for(new i=1;i<=MaxClients;i++){
		if(GetEntProp(i, Prop_Send, "m_iDecapitations") > 0){
			removeStats(i);
		}
	}
}
//-----------------------------------------------------------------------------
public Action:Event_Player_Death( Handle:event, const String:name[], bool:dontBroadcast ) {
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if(extra_stats[victim]){
		removeStats(victim);
	}
	new shooter_id = GetEventInt( event, "attacker" );
	new killer = GetClientOfUserId( shooter_id );
	
	if( !IsValidClient(killer) || !IsPlayerAlive(killer) ) {
		return Plugin_Continue;
	}
	new weapon = GetPlayerWeaponSlot( killer, TFWeaponSlot_Melee );	

	new bool:isDecapitation = GetEventInt( event, "customkill" ) == TF_CUSTOM_DECAPITATION;
	
	if( !isDecapitation) {
		return Plugin_Continue;
	}
	new heads = GetEntProp(killer, Prop_Send, "m_iDecapitations");
	if(heads > 4){
		heads -= 4;
		TF2Attrib_SetByDefIndex(weapon,107,1.0 + 0.06*heads);
		TF2Attrib_SetByDefIndex(weapon,26,15.0*heads);
		extra_stats[killer] = true;
	}	
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
removeStats(client){
	new weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );	
	TF2Attrib_RemoveByDefIndex(weapon,26);
	TF2Attrib_RemoveByDefIndex(weapon,107);
	extra_stats[client] = false;
}
