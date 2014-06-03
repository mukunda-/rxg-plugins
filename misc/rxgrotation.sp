
#include <sourcemod>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "RXG Rotation",
	author = "mukunda",
	description = "Weighted map rotation plugin",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
};

//-------------------------------------------------------------------------------------------------
new Handle:maplist = INVALID_HANDLE;
new serial =-1;
new UserMsg:g_TextMsg;

new g_map_index = -1;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	{
		new Handle:a = FindConVar("nextlevel");
		SetConVarFlags( a, GetConVarFlags(a)& ~FCVAR_NOTIFY );

	}
				
	
	maplist = CreateArray(32);
	HookEvent( "cs_intermission", Event_Intermission, EventHookMode_PostNoCopy  );
	
	g_TextMsg = GetUserMessageId("TextMsg");
	HookUserMessage(g_TextMsg, pReplaceNextMapMsg, true);
}


public Action:pReplaceNextMapMsg(UserMsg:msg_id, Handle:pb, const players[], playersNum, bool:reliable, bool:init)
{
	if (!reliable)
	{
		return Plugin_Continue;
	}
	decl String:message[256];
	PbReadString(pb, "params",  message, 256, 0);
	if (StrContains(message, "#game_nextmap") != -1) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
CountPlayers() {
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		if( GetClientTeam(i) < 2 ) continue;
		count++;
	}
	return count;
}

//-------------------------------------------------------------------------------------------------
TrimMapname( String:str[], maxlen ) {
	new pos = FindCharInString( str, '/', true );
	if( pos != -1 ) {
		Format( str, maxlen, "%s", str[pos+1] );
	}
	pos = FindCharInString( str, '\\', true );
	if( pos != -1 ) {
		Format( str, maxlen, "%s", str[pos+1] );
	}
}

//-------------------------------------------------------------------------------------------------
public Event_Intermission( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new players = CountPlayers();
	
	if (ReadMapList(maplist, 
			serial, 
			"mapcyclefile", 
			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT)
		== INVALID_HANDLE)
	{
		if (serial == -1)
		{ 
			SetFailState("Mapcycle Not Found");
		}
	}
	
	new mapCount = GetArraySize(maplist);
	decl String:mapName[32];

	decl String:current[64];
	GetCurrentMap(current, 64);
	TrimMapname( current, sizeof current );
	 
	if( g_map_index == -1 ) { // try to find in list
		for (new i = 0; i < mapCount; i++)
		{
			GetArrayString(maplist, i, mapName, sizeof(mapName));
			TrimMapname( mapName, sizeof mapName );
			if (strcmp(current, mapName, false) == 0)
			{
				g_map_index = i;
				break;
			}
		}
	}
	
	new Handle:kv = CreateKeyValues( "RXGRotation" );
	decl String:filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/rxgrotation.txt" );
	if( !FileExists( filepath ) ) {
		SetFailState( "rxgrotation.txt not found" );
		return;
	}
	if( !FileToKeyValues( kv, filepath ) ) {
		SetFailState( "Error loading config file." );
	}
	if( !KvJumpToKey( kv, "Maps" ) ) {
		SetFailState( "Config missing \"Maps\" section." );
	}
	
	new retries = 1000;
	
	do {
		g_map_index++;
		if( g_map_index >= mapCount ) g_map_index = 0;
		
		decl String:mapname[64];
		decl String:short_mapname[64];
		
		GetArrayString( maplist, g_map_index, mapname, sizeof mapname );
		strcopy( short_mapname, sizeof short_mapname, mapname );
		TrimMapname(short_mapname, sizeof short_mapname);
		new bool:validmap=false;
		decl String:friendly_mapname[64];
		
		if( !KvJumpToKey( kv, short_mapname ) ) {
			validmap=true;
			strcopy( friendly_mapname, sizeof friendly_mapname, mapname );
			TrimMapname( friendly_mapname, sizeof friendly_mapname );
			LogError( "Next map not listed in Maps config but is in map cycle." );
		} else {
			new req_players = KvGetNum( kv, "players" );
			if( players >= req_players ) {
				validmap = true;
				KvGetString( kv, "name", friendly_mapname, sizeof friendly_mapname );
			}
			KvGoBack( kv );
		}
		
		if( validmap ) {
			CloseHandle(kv);
			
			new oldflags;
			{
				new Handle:a = FindConVar("sm_nextmap");
				
				if( a != INVALID_HANDLE ) {
					oldflags = GetConVarFlags(a);
					SetConVarFlags(a,oldflags&~FCVAR_NOTIFY);
				}
			}
	
			SetNextMap( mapname );
			ServerCommand( "nextlevel %s", mapname );
			
			{
				new Handle:a = FindConVar("sm_nextmap");
			
				if( a != INVALID_HANDLE ) 
					SetConVarFlags( a, oldflags );
			}
			
			PrintToChatAll( "\x01 \x09Next map : %s", friendly_mapname );
			return;
		}
		
	} while( retries-- );
	
	
	
	LogError( "FATAL: RXGRotation couldn't find a suitable next map." );
	SetFailState( "No suitable next map, make sure there is a PLAYERS:0 entry" );
}
 
//-------------------------------------------------------------------------------------------------
