
#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "showscore",
	author = "mukunda",
	description = "view game score",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public OnPluginStart() {
	RegConsoleCmd( "sm_showscore", Command_showscore );
}

public Action:Command_showscore( client, args ) {
	ReplyToCommand( client, "CT: %d | T: %d", GetTeamScore(3), GetTeamScore(2) );
	return Plugin_Handled;
}