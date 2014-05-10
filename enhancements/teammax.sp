
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

public Plugin:myinfo = {
	name = "team max",
	author = "mukunda",
	description = "max team!",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new players_ct;
new players_t;

new Handle:sm_teamlimit;

public OnPluginStart() {
	CreateConVar( "sm_teamlimit", "5", "maximum number of players on each team.", FCVAR_PLUGIN );

	RegConsoleCmd( "jointeam", Command_jointeam );
}

ScanPlayers() {
	players_ct = 0;
	players_t = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			if( IsFakeClient(i) ) continue;	// dont include bots

			new team = GetClientTeam(i);

			if( team == 2 ) {
				players_t++;
			} else if( team == 3 ) {
				players_ct++;
			}
		}
	}
}

public Action:Command_jointeam( client, args ) {
	if( IsFakeClient(client) ) {
		return Plugin_Continue; // dont fuck with bots
	}
	decl String:arg[8];
	GetCmdArg( 1, arg, sizeof(arg) );
	new team_new = StringToInt( arg );
	new team_old = GetClientTeam( client );
	if( team_old == team_new ) return Plugin_Continue;
	if( team_new < 2 ) {
		return Plugin_Continue;
	}
	ScanPlayers();
	if( team_new == 2 ) {
		if( players_t < GetConVarInt(sm_teamlimit) ) {
			return Plugin_Continue;
		}
		PrintToChat( client, "The Terrorist team is full." );
		ClientCommand( client, "play ui/weapon_cant_buy.wav" );
		return Plugin_Handled;
	} else if( team_new == 3 ) {
		if( players_ct < GetConVarInt(sm_teamlimit) ) {
			return Plugin_Continue;
		}
		PrintToChat( client, "The CT team is full." );
		ClientCommand( client, "play ui/weapon_cant_buy.wav" );
		return Plugin_Handled;
	}
	return Plugin_Continue; // errornous?
}