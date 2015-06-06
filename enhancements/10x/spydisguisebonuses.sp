#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>

#define WEAPON_INDEX 225
public Plugin myinfo = 
{
	name = "Spy Disguise Bonuses",
	author = "Roker",
	description = "A more convincing spy.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThink, checkSpeed);
}
//-----------------------------------------------------------------------------
public checkSpeed(client)
{
	if (TF2_GetPlayerClass(client) != TFClass_Spy) { return; }
	if (!TF2_IsPlayerInCondition(client, TFCond_Disguised)) { return; }
	
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if (index != WEAPON_INDEX) { return;}
	
	TFClassType dclass = TFClassType:GetEntProp(client, Prop_Send, "m_nDisguiseClass");
	
	if(dclass == TFClass_Scout){
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 400.0);
		TF2Attrib_SetByName(client, "air dash count", 2.0);
	}else if(dclass == TFClass_Scout){
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 320.0);
	}
}