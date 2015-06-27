#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Large Rockets",
	author = "Roker",
	description = "Make large rockets.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

int validWeapons[] =  { 18, 205, 513, 658, 800, 809, 889, 898, 907, 916, 965, 974 };

public void OnEntityCreated(int entity, const char[] classname){
	if (!StrEqual(classname, "tf_projectile_rocket")) { return;}
	SDKHook(entity, SDKHook_Spawn, RocketSpawn);
}
public void RocketSpawn(int entity){
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	int index = TF2_GetWeaponIndex(weapon);
	if (!IntArrayContains(index, validWeapons, sizeof(validWeapons))) { return;}
	SetEntPropFloat(entity, Prop_Data, "m_flModelScale", 1.5);
}