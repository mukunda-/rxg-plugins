
#include <sourcemod>

#pragma semicolon 1

//---------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "fixnextmap",
	author = "mukunda",
	description = "afwserdfasdfsafasfdsafasdfsaf",
	version = "1.0.0",
	url = "www.mukunda.com"
}

//---------------------------------------------------------------------------------------
public OnPluginStart() {
	HookUserMessage( GetUserMessageId("TextMsg"), FilterTextMsg, true);
	HookEvent( "cs_intermission", OnIntermission ); 
}

//---------------------------------------------------------------------------------------
public OnIntermission( Handle:event, const String:name[], bool:dontBroadcast ) {
	// print Next Map message delayed after match ends
	CreateTimer( 1.5, ShowNextMap, _, TIMER_FLAG_NO_MAPCHANGE );
}

//---------------------------------------------------------------------------------------
public Action:ShowNextMap( Handle:timer ) {
	
	new String:nextmap[64];
	if( !GetNextMap(nextmap, sizeof(nextmap)) ) return Plugin_Handled;
	
	PrintToChatAll( "\x01Next Map: \x09%s", nextmap);
	 
	return Plugin_Handled;
}

//---------------------------------------------------------------------------------------
public Action:FilterTextMsg(UserMsg:msg_id, Handle:msg, const players[], 
							playersNum, bool:reliable, bool:init) { 
							
	if (!reliable) return Plugin_Continue;
	
	// filter out normal Next Map message
	decl String:message[256];
	PbReadString( msg, "params", message, sizeof(message), 0 );
	if (StrContains(message, "#game_nextmap") != -1)
		return Plugin_Handled;
	return Plugin_Continue;
}
