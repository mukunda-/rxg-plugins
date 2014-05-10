
#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "botquota fixor",
	author = "rxg",
	description = "asdfsadfasdfs",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Handle:bot_quota;
new desired_bot_quota;

new violent;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	bot_quota = FindConVar( "bot_quota" );
	RegConsoleCmd( "sm_botquota", Command_botquota );
	RegConsoleCmd( "sm_botquota_violent", Command_violent );
	HookEvent( "round_start", OnRoundStart );
}

public Action:Command_violent( client, args ) {
	if( violent )  {
		ReplyToCommand( client, "Already running in VIOLENT mode." );
		return Plugin_Handled;
	}
	violent = true;
	CreateTimer( 30.0, OnTimer, _, TIMER_REPEAT );
	ReplyToCommand( client, "Violent mode activated" );
	return Plugin_Handled;
}

BotFix() {
	new bots;
	new players;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetClientTeam(i) <= 1 ) continue;
		if( IsFakeClient(i) ) {
			bots++;
		} else {
			players++;
		}
	}
	if( bots > desired_bot_quota ) {
		ServerCommand( "bot_kick" );
		ServerCommand( "bot_quota %d", desired_bot_quota );
	} 
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnTimer( Handle:timer ) {
	BotFix();
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnConfigsExecuted() {
	desired_bot_quota = GetConVarInt( bot_quota );
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	SetConVarInt( bot_quota, desired_bot_quota );
}

public Action:Command_botquota( client, args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	desired_bot_quota = StringToInt(arg);
	SetConVarInt( bot_quota, desired_bot_quota );
	return Plugin_Handled;
}
