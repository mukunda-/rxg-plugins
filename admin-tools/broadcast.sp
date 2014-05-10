 
//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "BROADCAST",
	author = "mukunda",
	description = "broadcast",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public OnPluginStart() {
	RegServerCmd( "sm_bc", bc );
}

public Action:bc( args ) {
	decl String:msg[256];
	GetCmdArgString( msg, sizeof(msg) );
	if( strlen(msg) == 0 ) {
		PrintToServer( "sm_bc <msg> - Broadcast a server message." );
		return Plugin_Handled;
	}
	LogMessage( "Broadcast: %s", msg );
	Format( msg, sizeof(msg), "\x01\x0B\x01%s", msg );
	ReplaceString( msg, sizeof(msg), "{1}", "\x01" );
	ReplaceString( msg, sizeof(msg), "{2}", "\x02" );
	ReplaceString( msg, sizeof(msg), "{3}", "\x03" );
	ReplaceString( msg, sizeof(msg), "{4}", "\x04" );
	ReplaceString( msg, sizeof(msg), "{5}", "\x05" );
	ReplaceString( msg, sizeof(msg), "{6}", "\x06" );
	ReplaceString( msg, sizeof(msg), "{7}", "\x07" );
	ReplaceString( msg, sizeof(msg), "{8}", "\x08" );
	ReplaceString( msg, sizeof(msg), "{9}", "\x09" );
	ReplaceString( msg, sizeof(msg), "{a}", "\x0A" );
	ReplaceString( msg, sizeof(msg), "{b}", "\x0B" );
	ReplaceString( msg, sizeof(msg), "{c}", "\x0C" );
	ReplaceString( msg, sizeof(msg), "{d}", "\x0D" );
	ReplaceString( msg, sizeof(msg), "{e}", "\x0E" );
	ReplaceString( msg, sizeof(msg), "{f}", "\x0F" );
	PrintToChatAll( msg );
	return Plugin_Handled;
}
