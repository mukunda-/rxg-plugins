#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <rxgcommon>

int validWeapons[] =  { 574, 225 };

float storedSpeed[MAXPLAYERS+1];
float modifiedSpeed[MAXPLAYERS+1];


public Plugin myinfo = 
{
	name = "Spy Disguise Bonuses",
	author = "Roker",
	description = "A more convincing spy.",
	version = "1.2.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public void OnPluginStart()
{
	HookEvent( "player_death", Event_Player_Death, EventHookMode_Pre);
	HookEvent( "player_spawn", Event_Player_Spawn, EventHookMode_Post);
	
	HookPlayers();
}

//-----------------------------------------------------------------------------
void HookPlayers(){
	for(int i=1; i<=MaxClients; i++){
		if(!IsValidClient(i)){return;}
		SDKHook(i, SDKHook_PreThink, checkSpeed);
	}
}

//-----------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThink, checkSpeed);
}

//-----------------------------------------------------------------------------
void revertPlayer(int client){
	int weapon = GetPlayerWeaponSlot( client, TFWeaponSlot_Melee );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if(!IntArrayContains(index, validWeapons, sizeof(validWeapons))) { return;} //using a valid weapon?
	
	TF2Attrib_RemoveByDefIndex(client, 26);
	modifiedSpeed[client] = 0.0;
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
	SDKUnhook(client, SDKHook_ShouldCollide, onCollide);
}

//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {

	int attacker = GetClientOfUserId(GetEventInt( event, "attacker" ));
	int victim = GetClientOfUserId(GetEventInt( event, "userid" ));
	
	revertPlayer(victim);
	
	if( !IsValidClient(attacker) || !IsPlayerAlive(attacker) ) {return Plugin_Continue;	} //Attacker checks
	if( GetEventInt( event, "customkill" ) != TF_CUSTOM_BACKSTAB ) { return Plugin_Continue;} //is it a backstab?

	
	int weapon = GetPlayerWeaponSlot( attacker, TFWeaponSlot_Melee );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	if(!IntArrayContains(index, validWeapons, sizeof(validWeapons))) { return Plugin_Continue;} //using a valid weapon?
	
	modifiedSpeed[attacker] = storedSpeed[victim];
	
	TF2Attrib_SetByDefIndex(attacker, 26, GetEntProp(victim, Prop_Data, "m_iMaxHealth") - 125.0);
	SetEntityHealth(attacker, GetEntProp(victim, Prop_Data, "m_iMaxHealth"));
	
	SetEntProp(attacker, Prop_Data, "m_CollisionGroup", 2);
	SDKHook(attacker, SDKHook_ShouldCollide, onCollide);
	//SDKHook(attacker, SDKHook_Touch, onTouch);
	//SDKHook(attacker, SDKHook_StartTouch, onStartTouch);
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public bool onCollide(int entity, int collisiongroup, int contentsmask, bool originalResult){
	if(collisiongroup == 8){
		return false;
	}
	return originalResult;	
}
//-----------------------------------------------------------------------------
public Action Event_Player_Spawn( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId(GetEventInt( event, "userid" ));
	
	modifiedSpeed[client] = 0.0;
	storedSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
}

//-----------------------------------------------------------------------------
public TF2_OnConditionRemoved(int client, TFCond condition){
	if (condition != TFCond_Disguised) { return;}
	
	revertPlayer(client);
}

//-----------------------------------------------------------------------------
public checkSpeed(client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) { return; }
	
	if(modifiedSpeed[client] == 0){ return; }
	if (!TF2_IsPlayerInCondition(client, TFCond_Disguised)) { return; }
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", modifiedSpeed[client]);
}