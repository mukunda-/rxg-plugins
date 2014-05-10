

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

public Plugin:myinfo = 
{
	name = "sm_endround",
	author = "mukunda",
	description = "end the round",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public OnPluginStart() {
	RegAdminCmd( "sm_endround", Command_endround, ADMFLAG_SLAY );
	RegAdminCmd( "sm_restartmatch", Command_restartmatch, ADMFLAG_SLAY );
}

public Action:Command_endround( client, args ) {
	CS_TerminateRound( 5.0, CSRoundEnd_Draw );
	return Plugin_Handled;
}

public Action:Command_restartmatch( client, args ) {
	CS_TerminateRound( 5.0, CSRoundEnd_GameStart );
	return Plugin_Handled;
}
