#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <rxgcommon>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>


public Plugin myinfo = {
	name = "Freak Fortress 2: Speedup",
	author = "Roker",
};

float speed = 400.0;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	
	return APLRes_Success;
}

public OnPluginStart2()
{
	LoadTranslations("freak_fortress_2.phrases");
}

public Action FF2_OnAbility2(client,const char[] plugin_name,const char[] ability_name,action)
{	
	float timeLength = FF2_GetAbilityArgumentFloat(client, this_plugin_name, ability_name, 1, 5.0);
	speed = FF2_GetAbilityArgumentFloat(client, this_plugin_name, ability_name, 2, 400.0);
	
	int boss = GetClientOfUserId(FF2_GetBossUserId(client));
	
	SDKHook(boss, SDKHook_PreThink, setSpeed);
	
	Handle data;
	CreateDataTimer(timeLength, Timer_unhookPlayer, data);
	WritePackCell(data, boss);

	return Plugin_Continue;
}		
//-----------------------------------------------------------------------------
public Action Timer_unhookPlayer(Handle timer, Handle data){
	ResetPack(data);
	int client = ReadPackCell(data);
	CloseHandle(data);
	SDKUnhook(client, SDKHook_PreThink, setSpeed);
}
//-----------------------------------------------------------------------------
public setSpeed(client)
{
	if (!IsValidClient(client)) { return; }
	if (!IsPlayerAlive(client)) { return; }
	
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", speed);
}