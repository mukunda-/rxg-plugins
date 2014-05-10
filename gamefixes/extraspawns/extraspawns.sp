

#include <sourcemod>
#include <sdktools>

// 1.0.1
//  added config support

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "EXTRASPAWNS",
	author = "mukunda",
	description = "extra spawn points",
	version = "1.0.1",
	url = "www.mukunda.com"
};

// DOES NOT WORK :(
//new Handle:spawn_array = INVALID_HANDLE;
//new spawn_entity;

new mat_laserbeam;

new Handle:sm_extraspawns_limit_ct;
new Handle:sm_extraspawns_limit_t;

new t_spawn_counter;
new ct_spawn_counter;
new t_spawn_limit;
new ct_spawn_limit;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
//	spawn_array = CreateArray( 6 );
	RegAdminCmd( "sm_showspawns", Command_showspawns, ADMFLAG_RCON, "Mark spawnpoints with a temp beam" );

	sm_extraspawns_limit_t = CreateConVar( "sm_extraspawns_limit_t", "32", "Limit of player spawns to set, including original ones (max alive terrorists)" );
	sm_extraspawns_limit_ct = CreateConVar( "sm_extraspawns_limit_ct", "32", "Limit of player spawns to set, including original ones (max alive cts)" );
}

//-------------------------------------------------------------------------------------------------
MarkEnts( const String:name[], Float:height, r, g, b ) {
	
	new color[4];
	color[0] = r;
	color[1] = g;
	color[2] = b;
	color[3] = 255;
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, name )) != -1 ) {
		new Float:vec[3];
		new Float:end[3];
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );
		end[0] = vec[0];
		end[1] = vec[1];
		end[2] = vec[2] + height;
		TE_SetupBeamPoints( vec, end, mat_laserbeam, 0, 0, 0, 10.0, 2.0, 2.0, 0, 0.0, color, 0 );
		TE_SendToAll();
	}
	
}

//-------------------------------------------------------------------------------------------------
public Action:Command_showspawns( client, args ) {
	MarkEnts( "info_player_start", 64.0, 128,128, 128 );
	MarkEnts( "info_player_terrorist", 64.0, 0, 0, 128 );
	MarkEnts( "info_player_counterterrorist", 64.0, 0, 0, 128 );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
AddSpawn( const Float:vec[3], const Float:ang[3], team ) {
	new ent;
	
	if(team == 2) {
		if( t_spawn_counter == t_spawn_limit ) return;
		t_spawn_counter++;
	} else if( team == 3 ) {
		if( ct_spawn_counter == ct_spawn_limit ) return;
		ct_spawn_counter++;
	}
	
	if( team == 0 ) ent = CreateEntityByName( "info_player_start" );
	else if( team == 2 ) ent = CreateEntityByName( "info_player_terrorist" );
	else if( team == 3 ) ent = CreateEntityByName( "info_player_counterterrorist" );
	else return;

	if( ent == -1 ) return;
	
	DispatchSpawn(ent);
	TeleportEntity( ent, vec, ang, NULL_VECTOR );
	
	
}

//-------------------------------------------------------------------------------------------------
public AddSpawnT( Float:x, Float:y, Float:z, Float:yaw ) {
	decl Float:vec[3];
	vec[0] = x;
	vec[1] = y;
	vec[2] = z;
	new Float:ang[3];
	ang[1] = yaw;
	AddSpawn( vec, ang, 2 );
}

//-------------------------------------------------------------------------------------------------
public AddSpawnCT( Float:x, Float:y, Float:z, Float:yaw ) {
	decl Float:vec[3];
	vec[0] = x;
	vec[1] = y;
	vec[2] = z;
	new Float:ang[3];
	ang[1] = yaw;
	AddSpawn( vec, ang, 3 );	
}

//-------------------------------------------------------------------------------------------------
AddSpawnFromConfig(Handle:kv, team) {
	decl Float:vec[3];
	decl Float:ang[3];
	KvGetVector( kv, "position", vec );
	ang[1] = KvGetFloat( kv, "angle" );
	AddSpawn( vec, ang, team );
}

//-------------------------------------------------------------------------------------------------
LoadSpawnPoints(Handle:kv) {
	if( !KvGotoFirstSubKey(kv) ) return;

	do {
		decl String:name[32];
		KvGetSectionName( kv, name, sizeof(name) );
		if( StrEqual(name, "t", false ) ) {
			AddSpawnFromConfig(kv, 2);
		} else if( StrEqual( name, "ct", false ) ) {
			AddSpawnFromConfig(kv, 3);
		}

	} while( KvGotoNextKey(kv) );
	KvGoBack(kv);
}

//-------------------------------------------------------------------------------------------------
CountSpawns() {
	t_spawn_counter = 0;
	ct_spawn_counter = 0;
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_player_terrorist" )) != -1 ) {
		t_spawn_counter++;
	}
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_player_counterterrorist" )) != -1 ) {
		ct_spawn_counter++;
	}
	
	t_spawn_limit = GetConVarInt( sm_extraspawns_limit_t );
	ct_spawn_limit = GetConVarInt( sm_extraspawns_limit_ct );
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
//	ClearArray( spawn_array );

	mat_laserbeam = PrecacheModel( "materials/sprites/laserbeam.vmt" );

	CountSpawns();

	// load config
	decl String:filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/extraspawns.txt" );
	
	new Handle:kv = CreateKeyValues( "ExtraSpawns" );
	if( !FileExists(filepath) ) {
		CloseHandle(kv);
		SetFailState( "configs/extraspawns.txt missing" );
		return;
	}
	if( !FileToKeyValues( kv, filepath ) ) {
		CloseHandle(kv);
		SetFailState( "Couldn't Load Config" );
		return;
	}

	decl String:map[64];
	GetCurrentMap( map, sizeof( map ) );

	if( !KvJumpToKey( kv, map ) ) {
		// map not found, plugin disabled
		CloseHandle(kv);
		return;
	}
	
	LoadSpawnPoints( kv );

	CloseHandle(kv);
	
/*
	if( StrEqual( map, "cs_office" ) ) {
		//AddStartSpawn( 1038.0, -436.0, -72.0, 5.9637, -140.3924, 0.0 );
		
		// 32 players

		AddSpawnCT( -1395.049805, -1668.520264, -335.968781, 14.345157 );
		AddSpawnT( 1842.740479, -343.920532, -159.968750, 125.014687 );


	}*/
/*
	spawn_entity = FindEntityByClassname( -1, "info_player_start" );
	AcceptEntityInput(spawn_entity,"Kill");
	spawn_entity = -1;
	PrintToServer( "%d =====", spawn_entity );
	if( spawn_entity != -1 ) {
		CreateTimer( 5.0, ShiftStartPositionTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	}*/
	

}
/*
public Action:ShiftStartPositionTimer( Handle:timer ) {
	//new client = GetClientOfUserId( userid );
	//if( client == 0 ) return Plugin_Stop;
	//if( GetClientTeam(client) != 0 ) return Plugin_Stop;
	if( spawn_entity <= 0 ) return Plugin_Stop;
	
	// teleport client
	new index = GetRandomInt( 0, GetArraySize(spawn_array)-1 );
	new Float:vec[3];
	new Float:ang[3];
	vec[0] = Float:GetArrayCell( spawn_array, index, 0 );
	vec[1] = Float:GetArrayCell( spawn_array, index, 1 );
	vec[2] = Float:GetArrayCell( spawn_array, index, 2 );
	ang[0] = Float:GetArrayCell( spawn_array, index, 3 );
	ang[1] = Float:GetArrayCell( spawn_array, index, 4 );
	ang[2] = Float:GetArrayCell( spawn_array, index, 5 );
	
	
	TeleportEntity( spawn_entity, vec, ang, NULL_VECTOR );
	
	GetEntPropVector( spawn_entity, Prop_Data, "m_vecAbsOrigin", vec );
	PrintToServer("testes %f, %f, %f", vec[0], vec[1], vec[2] );
	return Plugin_Continue;
}*/
/*
public OnClientPutInServer( client ) {
	new size = GetArraySize(spawn_array);
	if( size != 0 ) {
		CreateTimer( 5.0, ShiftStartPositionTimer, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	}
}
*/

//-------------------------------------------------------------------------------------------------
/*
public AddStartSpawn( Float:x, Float:y, Float:z, Float:yaw, Float:pitch, Float:roll ) {
	decl Float:vec[3];
	vec[0] = x;
	vec[1] = y;
	vec[2] = z;
	new Float:ang[3];
	ang[0] = yaw;
	ang[1] = pitch;
	
	PushArrayCell( spawn_array, _:x );
	new entry = GetArraySize(spawn_array) - 1;
	SetArrayCell( spawn_array, entry, _:y, 1 );
	SetArrayCell( spawn_array, entry, _:z, 2 );
	SetArrayCell( spawn_array, entry, _:yaw, 3 );
	SetArrayCell( spawn_array, entry, _:pitch, 4 );
	SetArrayCell( spawn_array, entry, _:roll, 5 );
}
*/
