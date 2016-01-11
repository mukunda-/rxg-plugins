#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgtfcommon>
#include <rxgcommon>
#include <tf2attributes>

public Plugin myinfo = 
{
	name = "Taunt Health",
	author = "Roker",
	description = "Taunting with specified weapon returns players health.",
	version = "1.1.0",
	url = "www.reflex-gamers.com."
};

int instantHealWeapons[] =  { 42 };
int extraHealthWeapons[] =  { 159 };

Handle timers[MAXPLAYERS];

//-----------------------------------------------------------------------------
public TF2_OnConditionAdded(int client, TFCond condition){
	if (condition != TFCond_Taunting) { return;}
	if (IntArrayContains(GetActiveIndex(client), instantHealWeapons, sizeof(instantHealWeapons))) { 
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		SetEntityHealth(client, maxHealth);w
	}else if (IntArrayContains(GetActiveIndex(client), extraHealthWeapons, sizeof(extraHealthWeapons))) {
		int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Secondary );	
		TF2Attrib_SetByDefIndex(weapon, 26, 200.0);
		
		if(timers[client] != null){
			KillTimer(timers[client], true);
			timers[client] = null;
		}
		
		Handle data;
		timers[client] = CreateDataTimer(30.0, Timer_RemoveHealth, data);
		
		WritePackCell(data, client);
	}
}

//-----------------------------------------------------------------------------
public Action Timer_RemoveHealth(Handle timer, Handle data){
	ResetPack(data);
	int client = ReadPackCell(data);
	
	if(!IsPlayerAlive(client)) return;
	
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Secondary );	
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if (!IntArrayContains(index, extraHealthWeapons, sizeof(extraHealthWeapons))) return;

	TF2Attrib_RemoveByDefIndex(weapon, 26);
	timers[client] = null;	
}