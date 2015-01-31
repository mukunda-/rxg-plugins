#include <sourcemod>
#include <sdktools>
 
//-----------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "Spawn Editor Lite",
	author = "mukunda",
	description = "Edits spawn points. Without the editor.",
	version = "1.0.0",
	url = "www.mukunda.com"
};

#include "spawneditor/common.sp"

//-----------------------------------------------------------------------------
public OnMapStart() {
	decl String:configpath[128];
	
	decl String:mapname[64];
	GetCurrentMap( mapname, sizeof mapname );
	StripMapFolder( mapname, sizeof mapname );
	
	FormatEx( configpath, sizeof configpath, "cfg/spawns/%s.cfg", mapname );
	
	if( !FileExists( configpath )) {
		return;
	}
	
	new Handle:kv = CreateKeyValues( "SpawnPoints" );
	
	if( !FileToKeyValues( kv, configpath )) {
		CloseHandle( kv );
		return;
	}
	
	decl Float:spawns_vec[2][MAXSPAWNS][3];
	decl Float:spawns_ang[2][MAXSPAWNS];
	new spawns_count[2];
	
	spawns_count[0] = LoadPositions( kv,  "T", spawns_vec[0], spawns_ang[0] );
	spawns_count[1] = LoadPositions( kv, "CT", spawns_vec[1], spawns_ang[1] );
	
	CloseHandle( kv );
	
	if( spawns_count[0] == 0 || spawns_count[1] == 0 ) return;
	
	ClearSpawnEnts();
	
	AddSpawns( "info_player_terrorist", 
			   spawns_vec[0], spawns_ang[0], spawns_count[0] );
			 
	AddSpawns( "info_player_counterterrorist", 
			   spawns_vec[1], spawns_ang[1], spawns_count[1] );   
}


//-----------------------------------------------------------------------------
AddSpawns( const String:classname[], const Float:positions[MAXSPAWNS][3], 
           const Float:angles[MAXSPAWNS], count ) {
	
	new Float:ang[3];
	new Float:zero[3];
	
	for( new i = 0; i < count; i++ ) {
		new ent = CreateEntityByName( classname );
		
		ang[1] = angles[i];
		TeleportEntity( ent, positions[i], ang, zero );
		DispatchSpawn( ent );
	}
}

//-----------------------------------------------------------------------------
ClearSpawnEnts() {
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_player_terrorist" )) != -1 ) {
		AcceptEntityInput( ent, "Kill" );
	}
	
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_player_counterterrorist" )) != -1 ) {
		AcceptEntityInput( ent, "Kill" );
	}
}
