
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "scrim1",
	author = "mukunda",
	description = "scrim features",
	version = "1.1.0",
	url = "www.mukunda.com"
};



new Handle:scrim_official;
new bool:in_lobby = false;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	scrim_official = CreateConVar( "scrim_offical", "0", "official (strict) scrimmode switch", FCVAR_PLUGIN|FCVAR_NOTIFY );
	RegConsoleCmd( "set_scrim_official", Command_scrim );
	RegConsoleCmd( "say", Command_say );
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
}

public OnMapStart() {
	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );
	in_lobby = strncmp( "rxglobby", map, 8, false ) == 0;
}

public Action:Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	if( in_lobby ) return;
	
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	
	bool in_warmup = !!GameRules_GetProp( "m_bWarmupPeriod" );
	
	if( in_warmup ) {
		SetEntProp( client, Prop_Send, "m_iAccount", 16000 );
	}
}

public Action:Command_say( client, args ) {
	decl String:text[64];
	GetCmdArgString( text, sizeof text );
	StripQuotes(text);
	if( StrEqual(text,"pause",false) || StrEqual(text,"paws",false) ) {
		ServerCommand( "mp_pause_match" );
	} else if( StrEqual(text,"unpause",false) || StrEqual(text,"unpaws",false) ) {
		ServerCommand( "mp_unpause_match" );
	}
	return Plugin_Continue;
}

public Action:Command_scrim( client, args ) {
	if(args<1) {
		ReplyToCommand( client, "scrim_official 0/1 - sets official [stricter] scrim mode" );
		return Plugin_Handled;
	}
	decl String:arg[32];
	GetCmdArg( 1, arg, sizeof arg );
	new val = StringToInt(arg);
	if( val < 0 ) val = 0;
	if( val > 1 ) val = 1;
	SetConVarInt( scrim_official, val );
	ReplyToCommand( client, "Official mode: %s", val ? "Enabled":"Disabled" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnConfigsExecuted() {
	decl String:map[64];
	GetCurrentMap( map, sizeof map );
	if( StrContains( map, "rxglobby", false ) >= 0 ) return;
	if( GetConVarBool( scrim_official ) ) {
		ServerCommand( "exec realscrim.cfg" );
	}
}

//----------------------------------------------------------------------------------------------------------------------
