#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2items>
#include <tf2_stocks>

int savedBoss = -1;

public Plugin myinfo = {
	name = "Freak Fortress 2  Sandman",
	author = "Roker",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{
	return APLRes_Success;
}
//-----------------------------------------------------------------------------
public OnPluginStart2()
{
	LoadTranslations("freak_fortress_2.phrases");
}
//-----------------------------------------------------------------------------
public Action FF2_OnAbility2(client, const char[] plugin_name, const char[] ability_name, action)
{
	if (!strcmp(ability_name, ability_name)){
		savedBoss=GetClientOfUserId(FF2_GetBossUserId(client));
		Rage_Sandman(ability_name,savedBoss);
	}
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
Rage_Sandman(const char[] ability_name, boss){
	CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 1, 5.0), Timer_returnWeapon);
	
	TF2_RemoveWeaponSlot(boss, 2);
	
	Handle hWeapon=TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);	

	TF2Items_SetClassname(hWeapon, "tf_weapon_bat_wood");
	TF2Items_SetItemIndex(hWeapon, 44);

	TF2Items_SetNumAttributes(hWeapon, 4);
	TF2Items_SetAttribute(hWeapon, 0, 38, 1.0);
	TF2Items_SetAttribute(hWeapon, 1, 278, 0.01);
	TF2Items_SetAttribute(hWeapon, 2, 279, 1.0);
	TF2Items_SetAttribute(hWeapon, 3, 250, 1.0);

	int weapon = TF2Items_GiveNamedItem(boss, hWeapon);
	CloseHandle(hWeapon);
	
	EquipPlayerWeapon(boss, weapon);
	
	weapon = GetPlayerWeaponSlot(boss, TFWeaponSlot_Melee);
	
	int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	SetEntData(boss, iAmmoTable+iOffset, 99, 4, true);
	
}

//-----------------------------------------------------------------------------
public Action Timer_returnWeapon(Handle timer){
	TF2_RemoveWeaponSlot(savedBoss, 2);
	Handle hWeapon=TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);	

	TF2Items_SetClassname(hWeapon, "tf_weapon_bat");
	TF2Items_SetItemIndex(hWeapon, 450);

	TF2Items_SetNumAttributes(hWeapon, 1);
	TF2Items_SetAttribute(hWeapon, 0, 250, 1.0);
	
	int weapon = TF2Items_GiveNamedItem(savedBoss, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(savedBoss, weapon);
	
	return Plugin_Continue;
}