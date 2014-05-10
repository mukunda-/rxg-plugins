
//----------------------------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "respawn",
	author = "mukunda",
	description = "respawn player",
	version = "1.0.0",
	url = "www.mukunda.com"
};
  
public OnPluginStart() { 
	LoadTranslations( "common.phrases" );
	RegAdminCmd( "sm_respawn", Command_respawn, ADMFLAG_SLAY, "Respawns a player." );
	
} 

//-------------------------------------------------------------------------------------------------
public Action:Command_respawn( client, args ) {


	if( client == 0 ) return Plugin_Handled;
	if( args < 1 ) {
		ReplyToCommand( client, "[SM] Usage: sm_respawn <player>" );
		return Plugin_Handled;
	}
	decl String:name[64];
	GetCmdArg( 1, name, sizeof(name) );
	new target = FindTarget( client, name );
	if( target == -1 ) return Plugin_Handled;
	if( !IsClientInGame(target) ) {
		ReplyToCommand( client, "[SM] sm_respawn: Invalid target." );
		return Plugin_Handled;
	}
	if( GetClientTeam(target) < 2 || IsPlayerAlive(target) ) {
		ReplyToCommand( client, "[SM] sm_respawn: Invalid target." );
		return Plugin_Handled;
	}
	CS_RespawnPlayer(target);

	if( !IsPlayerAlive(target) ) {
		ReplyToCommand( client, "[SM] Respawned %N.", target );
	}
	PrintToChat( target, "[SM] An admin respawned you." );
	
	return Plugin_Handled;
}
