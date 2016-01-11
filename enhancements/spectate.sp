#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <tf2_stocks>

public Plugin myinfo = 
{
	name = "Spectate",
	author = "Roker",
	description = "Follow a player",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

int watcherid[MAXPLAYERS+1];
int following[MAXPLAYERS+1];
int followingid[MAXPLAYERS+1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_spectate", cmd_spectate, "Spectate a player.", ADMFLAG_KICK );
	HookEvent( "player_spawn", Event_Player_Spawn);
}
//-----------------------------------------------------------------------------
public Action cmd_spectate(int client, args) {
	char name[128];
	char pName[64];
	
	if(args == 0){
		if(GetClientUserId(following[client]) != followingid[client]){
			PrintToChat(client, "The player you were spectating has left the game.");
		}else if(IsValidClient(following[client])){
			GetClientName(following[client], pName, sizeof(pName));
			PrintToChat(client, "No longer spectating %s.", pName);
		}
		following[client] = 0;
	}
	
	GetCmdArg(1, name, sizeof(name));
	int target = FindTarget(client, name, false, false);
	
	watcherid[client] = GetClientUserId(client);
	followingid[client] = GetClientUserId(target);
	following[client] = target;
	
	spectate(client, target);
	
	GetClientName(target, pName, sizeof(pName));
	
	PrintToChat(client, "Spectating %s.", pName);
	
	return Plugin_Handled;
}
//-----------------------------------------------------------------------------
public Action Event_Player_Spawn( Handle event, const char[] name, bool dontBroadcast ) {
	int spawned = GetClientOfUserId(GetEventInt(event, "userid"));
	for (int i = 1; i <= MaxClients;i++){
		if (!IsValidClient(i)) continue;
		if (following[i] != spawned) continue;
		if (GetClientUserId(i) != watcherid[i]){
			following[i] = 0;
			continue;
		}
		if (GetClientUserId(following[i]) != followingid[i]){
			PrintToChat(i, "The player you were spectating has left the game.");
			following[i] = 0;
			continue;
		}
		if(TFTeam:GetClientTeam(i) != TFTeam_Spectator){
			following[i] = 0;
			continue;
		}
		spectate(i, spawned);
	}
}
void spectate(int client, int target){
	char pName[64];
	GetClientName(target, pName, sizeof(pName));
	
	FakeClientCommandEx(client, "spec_player \"%s\"", pName);	
}