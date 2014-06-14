
#include <sourcemod>
#include <sdktools>

#include <sdkhooks>
 
#pragma semicolon 1

// 1.1.0 3:38 PM 6/14/2014
//   sm_postertest added
//   config file is optional
//

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "posters",
	author = "mukunda",
	description = "add posters/decals to the map",
	version = "1.1.0",
	url = "www.mukunda.com"
};

public OnPluginStart() {
	RegAdminCmd( "sm_trace_point", sm_trace_point, ADMFLAG_SLAY );
	RegAdminCmd( "sm_postertest", sm_postertest, ADMFLAG_RCON );
	//RegConsoleCmd( "test", test );


}
/*
public Action:test( client, args ) {
	new ent = CreateEntityByName( "infodecal" );

	
	new Float:vec[3] = {1608.031250, -76.161575, -85.80024};
 
	decl String:decal[32];
	Format( decal, sizeof(decal), "rxgoffice/poster_haunted_zone" );
	
	DispatchKeyValue( ent, "texture", decal );
	DispatchKeyValue( ent, "LowPriority", "0" );
	
	//DispatchSpawn(ent);
		
	TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR );
	ActivateEntity( ent );

	return Plugin_Handled;
}
*/
public LoadConfig() {
	
	decl String:file[256];
	BuildPath( Path_SM, file, sizeof(file), "configs/posters.txt" );
	if( !FileExists(file) ) {
		return; // no posters config
	}
	
	new Handle:kv = CreateKeyValues( "Posters" );
	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );
	
	if( !FileToKeyValues( kv, file ) ) {
		CloseHandle(kv);
		SetFailState( "Couldn't Load Config!" );
	} 

	if( !KvJumpToKey( kv, map ) ) return;

	if( !KvGotoFirstSubKey( kv ) ) return;
	
	do {
		decl String:texture[128];
		new Float:position[3];
		new Float:project[3];
		new Float:zero[3];	
		new Float:pdist;
		KvGetString( kv, "texture", texture, sizeof(texture), "" );
		KvGetVector( kv, "position", position );
		KvGetVector( kv, "project", project, zero );
		pdist = KvGetFloat( kv, "projected_distance", 64.0 );
		new bool:projected = project[0] != 0.0 || project[1] != 0.0 || project[2] != 0.0;
		
		PrecacheDecal( texture );

		decl String:download[128];
		Format( download, sizeof(download), "materials/%s.vmt", texture );
		AddFileToDownloadsTable( download );
		Format( download, sizeof(download), "materials/%s.vtf", texture );
		AddFileToDownloadsTable( download );

		new ent;
		if( projected ) {
			ent = CreateEntityByName( "info_projecteddecal" );
		} else {
			ent = CreateEntityByName( "infodecal" ); 	
		}
		
		DispatchKeyValue( ent, "texture", texture );
		DispatchKeyValue( ent, "LowPriority", "0" );
		
		if( projected ) {
			TeleportEntity( ent, position, project, NULL_VECTOR );

			decl String:aaa[16];
			Format(aaa,sizeof(aaa),"%.2f", pdist );
			PrintToChatAll( "DEBUG: PROJECTED %f %f %f %f (%s)", project[0], project[1], project[2], pdist,aaa );
			DispatchKeyValue( ent, "Distance", aaa );
			
		} else {
			TeleportEntity( ent, position, NULL_VECTOR, NULL_VECTOR );
		}
		ActivateEntity( ent );

	} while( KvGotoNextKey(kv) );

	CloseHandle(kv);
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() { 
	LoadConfig();
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

bool:TraceEyes( client, Float:result[3] ) {
	decl Float:start[3];
	decl Float:angles[3];

	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );

	TR_TraceRayFilter( start, angles, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		TR_GetEndPosition( result );
		
		return true;
	}
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:sm_trace_point( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	decl Float:point[3];
	if( TraceEyes( client, point ) ) {
		PrintToConsole( client, "Trace Result: %f %f %f", point[0], point[1], point[2] );
	} else {
		PrintToConsole( client, "Trace did not hit." );
	}
	return Plugin_Handled;
}

PaintDecal( Float:position[3], const String:texture[] ) {
	PrecacheDecal( texture );
 
	new ent = CreateEntityByName( "infodecal" );  
	
	DispatchKeyValue( ent, "texture", texture );
	DispatchKeyValue( ent, "LowPriority", "1" ); 
	TeleportEntity( ent, position, NULL_VECTOR, NULL_VECTOR ); 
	ActivateEntity( ent );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:sm_postertest( client, args ) {
	if( args < 1 ) {
		PrintToConsole( client, "sm_postertest <texture> - Paint a decal at your crosshair" );
		return Plugin_Handled;
	}
	decl String:texture[128];
	GetCmdArg( 1, texture, sizeof texture );
	
	decl Float:point[3];
	if( !TraceEyes( client, point ) ) {
		PrintToConsole( client, "Trace did not hit." );	
		return Plugin_Handled;
	}
	PrintToConsole( client, "Position: { %f %f %f }", point[0], point[1], point[2] );
	PaintDecal( point, texture );
	
	return Plugin_Handled;
}
