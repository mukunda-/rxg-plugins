
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "scrim1",
	author = "mukunda",
	description = "scrim features",
	version = "1.0.0",
	url = "www.mukunda.com"
};



new Handle:scrim_official;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	scrim_official = CreateConVar( "scrim_offical", "0", "official (strict) scrimmode switch", FCVAR_PLUGIN|FCVAR_NOTIFY );
	RegConsoleCmd( "set_scrim_official", Command_scrim );
	RegConsoleCmd( "say", Command_say );
	
}



public Action:Command_say( client, args ) {
	decl String:text[64];
	GetCmdArgString( text, sizeof text );
	StripQuotes(text);
	if( StrEqual(text,"pause",false) ) {
		ServerCommand( "mp_pause_match" );
	} else if( StrEqual(text,"unpause",false) ) {
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
