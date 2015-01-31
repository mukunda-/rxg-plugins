#include <sourcemod>
#include <sdktools>
 
//-----------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "Spawn Editor",
	author = "mukunda",
	description = "Edits spawn points.",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//-----------------------------------------------------------------------------
#include "spawneditor/common.sp"

new Handle:g_menu; 
new g_menu_client;
new g_menu_init;

new Handle:g_preview_timer = INVALID_HANDLE;

new Float:g_spawns_pos[2][MAXSPAWNS][3];
new Float:g_spawns_ang[2][MAXSPAWNS];
new g_spawns_count[2];

new mat_fatlaser;
new mat_halosprite;
new mat_glowsprite;

//-----------------------------------------------------------------------------
public OnPluginStart() {
	g_menu = CreateMenu( MenuHandler );
		
	SetMenuTitle( g_menu, "Spawn Editor" );
//	SetMenuPagination( g_menu, MENU_NO_PAGINATION );
	
	AddMenuItem( g_menu, "add",    "Add from current position" );
	AddMenuItem( g_menu, "adjust", "Adjust nearest to position" );
	AddMenuItem( g_menu, "remove", "Remove nearest to position" );
	AddMenuItem( g_menu, "next",   "Teleport to next" );
	AddMenuItem( g_menu, "count",  "Count number of spawns" );
	AddMenuItem( g_menu, "save",   "Save configuration" );
	AddMenuItem( g_menu, "load",   "Reload configuration (undo changes)" ); 
	AddMenuItem( g_menu, "clear",  "Clear all spawns" );
	AddMenuItem( g_menu, "import", "Reset to map spawns" );
	
	RegAdminCmd( "sm_spawneditor", Command_SpawnEditor, ADMFLAG_RCON );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	g_menu_init = false;
	
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");
	mat_glowsprite = PrecacheModel("materials/sprites/ledglow.vmt");
}

//-----------------------------------------------------------------------------
StartPreview() {
	if( g_preview_timer != INVALID_HANDLE ) return;
	
	PreviewTimer( INVALID_HANDLE );
	g_preview_timer = CreateTimer( 1.0, PreviewTimer, _, TIMER_REPEAT );
}

//-----------------------------------------------------------------------------
StopPreview() {
	
	if( g_preview_timer == INVALID_HANDLE ) return;
	KillTimer( g_preview_timer );
	g_preview_timer = INVALID_HANDLE;
}

//-----------------------------------------------------------------------------
public Action:PreviewTimer( Handle:timer ) {

	new color1[4] = {128,128,0,255};
	new color2[4] = {0 ,128,128,255};
	DrawSpawns( 0, color1 );
	DrawSpawns( 1, color2 );
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
DrawSpawns( team, color[4] ) {
	decl clients[2];
	clients[0] = g_menu_client;
	clients[1] = 0;
	
	for( new i = 0; i < g_spawns_count[team]; i++ ) {
		
		decl Float:pos1[3]; 
		decl Float:pos2[3]; 
		
		pos1 = g_spawns_pos[team][i];
		pos2 = g_spawns_pos[team][i];
		pos2[0] += Cosine( DegToRad(g_spawns_ang[team][i]) ) * 12.0;
		pos2[1] += Sine( DegToRad(g_spawns_ang[team][i]) ) * 12.0;
		
		TE_SetupBeamRingPoint( pos1, 1.0, 15.0, mat_fatlaser, mat_halosprite, 0, 15, 0.25, 1.5, 0.0, color, 10, 0);
		
		TE_Send( clients, 1, 0.25 );
		
		TE_SetupGlowSprite( pos1, mat_glowsprite, 1.0, 1.0, 70);
		TE_Send( clients, 1, 0.0 );
		
		TE_SetupBeamPoints( pos1, pos2, mat_fatlaser, mat_halosprite, 0, 15, 1.0, 1.0, 1.0, 64, 0.0, color, 3 );
		TE_Send( clients, 1, 0.0 );
		
		pos2 = pos1;
		pos2[2] += 12.0;
		TE_SetupBeamPoints( pos1, pos2, mat_fatlaser, mat_halosprite, 0, 15, 1.0, 1.0, 1.0, 64, 0.0, color, 3 );
		TE_Send( clients, 1, 0.0 );
		
	}
}

//-----------------------------------------------------------------------------
ImportSpawnEntities( team, const String:classname[] ) {
	g_spawns_count[team] = 0;
	decl Float:angles[3];
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, classname )) != -1 ) {
		
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", 
								g_spawns_pos[team][g_spawns_count[team]] );
								
				
		GetEntPropVector( ent, Prop_Data, "m_angRotation", angles );
		g_spawns_ang[team][g_spawns_count[team]] = angles[1];
		
		g_spawns_count[team]++;
	}
}

//-----------------------------------------------------------------------------
ImportSpawns( client ) {
	
	ImportSpawnEntities( 0, "info_player_terrorist" );
	ImportSpawnEntities( 1, "info_player_counterterrorist" );
	
	if( client ) {
		PrintToChat( client, "Spawns imported! CT:%d, T:%d", 
							  g_spawns_count[1], g_spawns_count[0] );
	}
}

//-----------------------------------------------------------------------------
public MenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	
	if( action == MenuAction_Cancel ) {
		StopPreview();
		
	} else if( action == MenuAction_Select ) {
		new client = param1;
		decl String:info[32];
		new bool:found = GetMenuItem( menu, param2, info, sizeof(info) );
		if( !found ) return;
		
		if( g_menu_client != client ) return;
		
		new team = GetClientTeam(client)-2;
		if( team < 0 ) return;
		
		if( StrEqual( info, "add" )) {
			AddSpawn( client, team );
			ShowMenu( client );
			
		} else if( StrEqual( info, "adjust" )) {
			AdjustSpawn( client, team );
			ShowMenu( client );
			
		} else if( StrEqual( info, "remove" )) {
			RemoveSpawn( client, team );
			ShowMenu( client );
			
		} else if( StrEqual( info, "next" )) {
			TeleportToNext( client, team );
			ShowMenu( client );
			
		} else if( StrEqual( info, "save" )) {
			SaveConfig( client );
			ShowMenu( client );
			
		} else if( StrEqual( info, "load" )) {
			LoadConfig( client );
			ShowMenu( client );
			
		} else if( StrEqual( info, "count" )) {
			CountSpawns( client );
			ShowMenu( client );
			
		} else if( StrEqual( info, "clear" )) {
			ClearSpawns( client );
			ShowMenu( client );
			
		} else if( StrEqual( info, "import" )) {
			ImportSpawns( client );
			ShowMenu( client );
			
		}
		
	}  
}

//-----------------------------------------------------------------------------
FindNearest( client, team ) {
	decl Float:pos[3];
	GetClientAbsOrigin( client, pos );
	
	new Float:distance = 99999999.9;
	new nearest = -1;
	
	for( new i = 0; i < g_spawns_count[team]; i++ ) {
		new Float:d = GetVectorDistance( pos, g_spawns_pos[team][i] );
		if( d < distance ) {
			distance = d;
			nearest = i;
		}
	}
	
	if( nearest == -1 ) {
		PrintToChat( client, "No spawn found." );
	}
	return nearest;
}

//-----------------------------------------------------------------------------
ShowMenu( client ) {
	if( !g_menu_init ) {
		g_menu_init = true;
		if( !LoadConfig( client ) ) {
			ImportSpawns( client );
		}
	}
	
	g_menu_client = client;
	StartPreview();
	DisplayMenu( g_menu, client, MENU_TIME_FOREVER );
}

//-----------------------------------------------------------------------------
AddSpawn( client, team ) {
	// add a spawn at current position
	
	decl Float:pos[3];
	decl Float:ang[3];
	GetClientAbsOrigin( client, pos );
	GetClientEyeAngles( client, ang );
	
	pos[2] += 16.0;
	
	if( g_spawns_count[team] == MAXSPAWNS ) {
		PrintToChat( client, "Cannot add more spawns." );
		return;
	}
	
	new c = g_spawns_count[team]++;
	g_spawns_pos[team][c] = pos;
	g_spawns_ang[team][c] = ang[1];
	
	PrintToChat( client, "Spawn added." );
}

//-----------------------------------------------------------------------------
AdjustSpawn( client, team ) {
	// get nearest spawn and teleport to position
	
	decl Float:pos[3];
	decl Float:ang[3];
	GetClientAbsOrigin( client, pos );
	GetClientEyeAngles( client, ang );
	
	pos[2] += 16.0;
	
	new nearest = FindNearest( client, team );
	if( nearest == -1 )  return;
	
	g_spawns_pos[team][nearest] = pos;
	g_spawns_ang[team][nearest] = ang[1];
	
	PrintToChat( client, "Spawn adjusted." );
}

//-----------------------------------------------------------------------------
RemoveSpawn( client, team ) {
	
	new nearest = FindNearest( client, team );
	if( nearest == -1 ) return;
	
	// shift array upwards
	for( new i = nearest; i < g_spawns_count[team]-1; i++ ) {
		g_spawns_pos[team][i] = g_spawns_pos[team][i+1];
		g_spawns_ang[team][i] = g_spawns_ang[team][i+1]; 
	}
	g_spawns_count[team]--;
	
	PrintToChat( client, "Spawn removed." );
}

//-----------------------------------------------------------------------------
TeleportToNext( client, team ) {
	// teleport to next entry in the array
	
	new nearest = FindNearest( client, team );
	if( nearest == -1 ) return;
	
	new next = nearest + 1;
	if( next == g_spawns_count[team] ) next = 0;
	
	new Float:ang[3];
	GetClientEyeAngles( client, ang );
	new Float:vel[3];
	ang[1] = g_spawns_ang[team][next];
	TeleportEntity( client, g_spawns_pos[team][next], ang, vel );
	
}

//-----------------------------------------------------------------------------
SaveConfig( client ) {
	decl String:configpath[128];
	decl String:mapname[64];
	GetCurrentMap( mapname, sizeof mapname );
	StripMapFolder( mapname, sizeof mapname );
	FormatEx( configpath, sizeof configpath, "cfg/spawns/%s.cfg", mapname );
	
	if( !FileExists( "cfg/spawns" ) ) CreateDirectory( "cfg/spawns", 511 );
	
	new Handle:kv = CreateKeyValues( "SpawnPoints" );
	
	KvJumpToKey( kv, "T", true );
	WriteKVSpawns( kv, 0 );
	KvGoBack( kv );
	
	KvJumpToKey( kv, "CT", true );
	WriteKVSpawns( kv, 1 );
	KvGoBack( kv );
	
	KeyValuesToFile( kv, configpath );
	
	CloseHandle(kv);
	
	PrintToChat( client, "Config saved." );
}

//-----------------------------------------------------------------------------
WriteKVSpawns( Handle:kv, team ) {
	for( new i = 0; i < g_spawns_count[team]; i++ ) {
		decl String:section[8];
		FormatEx( section, sizeof section, "%d", i+1 );
		KvJumpToKey( kv, section, true );
		
		KvSetVector( kv, "pos", g_spawns_pos[team][i] );
		KvSetFloat(  kv, "ang", g_spawns_ang[team][i] );
		
		KvGoBack( kv );
	}
}

//-----------------------------------------------------------------------------
bool:LoadConfig( client ) {
	decl String:configpath[128];
	decl String:mapname[64];
	GetCurrentMap( mapname, sizeof mapname );
	StripMapFolder( mapname, sizeof mapname );
	FormatEx( configpath, sizeof configpath, "cfg/spawns/%s.cfg", mapname );
	
	if( !FileExists( configpath )) {
		if( client ) PrintToChat( client, "Config doesn't exist." );
		return false;
	}
	
	new Handle:kv = CreateKeyValues( "SpawnPoints" );
	
	if( !FileToKeyValues( kv, configpath )) {
		if( client ) PrintToChat( client, "Error loading config." );
		CloseHandle( kv );
		return false;
	}
	
	g_spawns_count[0] = 
		LoadPositions( kv,  "T", g_spawns_pos[0], g_spawns_ang[0] );
	
	g_spawns_count[1] = 
		LoadPositions( kv, "CT", g_spawns_pos[1], g_spawns_ang[1] );
	
	CloseHandle(kv);
	
	if( client ) PrintToChat( client, "Spawns loaded. CT:%d, T:%d", 
				 g_spawns_count[1], g_spawns_count[0] );
	return true;
} 

//-----------------------------------------------------------------------------
ClearSpawns( client ) {
	g_spawns_count[0] = 0;
	g_spawns_count[1] = 0;
	if( client ) PrintToChat( client, "All spawns cleared." );
}

//-----------------------------------------------------------------------------
CountSpawns( client ) {
	PrintToChat( client, "Spawn count: CT:%d, T:%d", 
				 g_spawns_count[1], g_spawns_count[0] );
}

//-----------------------------------------------------------------------------
public Action:Command_SpawnEditor( client, args ) {
	if( GetClientTeam( client ) < 2 ) {
		PrintToChat( client, "You need to be on a team." );
		return Plugin_Handled;
	}
	
	ShowMenu( client );
	return Plugin_Handled;
}
