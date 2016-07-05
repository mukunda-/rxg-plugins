#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <rxgtfcommon>
#include <tf2_stocks>
#include <dbrelay>

#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo = 
{
	name = "Mayhem Tracker",
	author = "Roker",
	description = "",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

int p_time[MAXPLAYERS];

public void OnPluginStart(){		
	for(int i=0;i<MaxClients;i++){
		p_time[i] = GetTime();
	}
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	HookEvent("player_death", Event_Death, EventHookMode_Pre);
}

//-----------------------------------------------------------------------------
public Action Event_Spawn(Handle event, char[] args, bool noBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	p_time[client] = GetTime();
}

//-----------------------------------------------------------------------------
public Action Event_Death(Handle event, char[] args, bool noBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsValidClient(client)) return;
	
	int classid = GetClassID(view_as<int>(TF2_GetPlayerClass(client)));
	if(classid == 0) return;
	
	int loadout[4];
	GetLoadout(client, loadout);
	
	int usedTime = GetTime() - p_time[client];
	
	if(usedTime < 10) return;
	
	char query[1024];
	
	FormatEx( query, sizeof query, "INSERT INTO sourcebans_weaponlist.weapon_usage VALUES ( %i, %i, %i, %i, %i, CURDATE(), %i ) ON DUPLICATE KEY UPDATE time_used = time_used + %i", 
	classid, loadout[0], loadout[1], loadout[2], loadout[3], usedTime,
	usedTime);
	
	DBRELAY_TQuery( IgnoredSQLResult, query );
}

//-----------------------------------------------------------------------------
public void IgnoredSQLResult( Handle owner, Handle hndl, const char [] error, any data ) {
    if( !hndl ) {
        LogError( "SQL Error --- %s", error );
        return;
    }
}