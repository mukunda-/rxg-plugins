#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Spawn Duplicator",
    author      = "mukunda",
    description = "Duplicates spawn points on maps that don't have enough",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
//new Handle:g_convars[2];

new g_amount[2] = {16,16}; // hardcoded for now... TODO: add config

new String:g_entnames[][] = {

	"info_player_terrorist",
	"info_player_counterterrorist"
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
//	g_convars[0] = CreateConVar( "sm_spawnduper_count_t", "10", "Terrorist spawnpoint minimum to create", FCVAR_PLUGIN );
	//g_convars[1] = CreateConVar( "sm_spawnduper_count_ct", "10", "Counter-terrorist spawnpoint minimum to create", FCVAR_PLUGIN );
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	for( new team = 0; team < 2; team++ ) {
		new count = 0;
		new desired = g_amount[team];//GetConVarInt( g_convars[team] );
		new ent = -1;
		new last_ent = -1;
		while( (ent = FindEntityByClassname( ent, g_entnames[team] )) != -1 ) {
			last_ent = ent;
			count++;
		}
		
		if( count == 0 ) {
			PrintToServer( "Spawn Duplicator :: Map contains no \"%s\"!", g_entnames[team] );
		
			continue; // catch error: there are no spawn points
		}
		if( count >= desired ) continue; // catch: there are enough spawns
		
		ent = -1;
		count = desired-count;
		
		PrintToServer( "Spawn Duplicator :: Adding %d additional \"%s\"", count, g_entnames[team] );
		
		while( count ) {
			ent = FindEntityByClassname( ent, g_entnames[team] );
			if( ent == -1 || ent == last_ent )  {
				ent = -1;
				continue; // this should not happen but just in case..
			}
			
			new new_spawn = CreateEntityByName( g_entnames[team] );
			DispatchSpawn(new_spawn);
			decl Float:position[3];
			decl Float:angles[3];
			
			GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", position );
			GetEntPropVector( ent, Prop_Data, "m_angAbsRotation", angles );
			PrintToServer( "\x01 \x04%s - {%.0f,%.0f,%.0f}", g_entnames[team], position[0], position[1], position[2] );
			TeleportEntity( new_spawn, position, angles, NULL_VECTOR );
			
			count--;
		}
		
	}
	
}
