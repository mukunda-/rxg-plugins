
#include <sourcemod>
#include <sdktools>
 
#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "spec1",
	author = "mukunda",
	description = "Move unassigned players to spectate.",
	version = "1.0.0",
	url = "www.mukunda.com"
};

#define TIME 30.0

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "cs_match_end_restart", Event_Newmatch, EventHookMode_PostNoCopy  );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SpecTimer( Handle:timer, any:data ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetClientTeam(i) != 0 ) continue;
		if( IsFakeClient(i) ) continue;
		ChangeClientTeam(i, 1);
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
StartSpecTimer() {
	CreateTimer( TIME, SpecTimer, _, TIMER_FLAG_NO_MAPCHANGE );
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	StartSpecTimer();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_Newmatch( Handle:event, const String:name[], bool:dontBroadcast ) {
	StartSpecTimer();	
}

//----------------------------------------------------------------------------------------------------------------------