#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <tf2_stocks>
#include <tf2attributes>
#include <donations>
#include <clientprefs>

#pragma semicolon 1
//#pragma newdecls required

public Plugin myinfo = 
{
	name = "",
	author = "Roker",
	description = "",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

Handle clientPrefs;

int enabled[MAXPLAYERS];

//-----------------------------------------------------------------------------
public void OnPluginStart()
{
	clientPrefs = RegClientCookie( "VIPGreenFlamesData", "VIP Green Flames Saved Data", CookieAccess_Protected );
	VIP_Register( "Green Flames", OnVIPMenu );
	
	HookEvent("player_spawn", Spawn, EventHookMode_Post);
}

//-----------------------------------------------------------------------------
public void OnLibraryAdded( const char[] name ) {
	if( StrEqual(name, "donations") ){
		VIP_Register( "Green Flames", OnVIPMenu );
	}
}

//-----------------------------------------------------------------------------
public OnVIPMenu( int client, VIPAction action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04Green Flames for Flamethrowers." );
	} else if( action == VIP_ACTION_USE ) {
		if( !AreClientCookiesCached( client ) ) return;
		toggleFlameSettings(client);
	}
}

//-----------------------------------------------------------------------------
public Action Spawn(Handle event, const char[] name, bool dB){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	givePlayerFlames(client);
}

//-----------------------------------------------------------------------------
void givePlayerFlames(int client){
	if(!Donations_GetClientLevelDirect(client)) return;
	if(!enabled[client]) return;
	
	if(TF2_GetPlayerClass(client) != TFClass_Pyro) return;
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	
	TF2Attrib_SetByDefIndex(weapon, 1008, 1.0);
}

//-----------------------------------------------------------------------------
void removePlayerFlames(int client){
	if(TF2_GetPlayerClass(client) != TFClass_Pyro) return;
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	TF2Attrib_SetByDefIndex(weapon, 1008, 0.0);
}

//-----------------------------------------------------------------------------
public void OnClientCookiesCached(int client){
	char cookieString[8];
	GetClientCookie(client, clientPrefs, cookieString, sizeof(cookieString));
	
	enabled[client] = StringToInt(cookieString);
}

//-----------------------------------------------------------------------------
public void OnClientDisconnect(int client){
	char cookieString[8];
	IntToString(enabled[client], cookieString, sizeof(cookieString));
	
	SetClientCookie(client, clientPrefs, cookieString);
}

//-----------------------------------------------------------------------------
void toggleFlameSettings(int client){
	if(enabled[client]){
		enabled[client] = 0;
		PrintToChat(client, "Green Flames disabled.");
		if(IsPlayerAlive(client)){
			removePlayerFlames(client);
		}
	}else{
		enabled[client] = 1;
		PrintToChat(client, "Green Flames enabled.");
		if(IsPlayerAlive(client)){
			givePlayerFlames(client);
		}
	}
}