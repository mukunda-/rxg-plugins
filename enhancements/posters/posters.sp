
#include <sourcemod>
#include <sdktools>

#include <sdkhooks>
 
#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "posters",
	author = "mukunda",
	description = "add posters/decals to the map",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public OnPluginStart() {
	RegAdminCmd( "sm_trace_point", sm_trace_point, ADMFLAG_SLAY );
	//RegConsoleCmd( "test", test );


}

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

public LoadConfig() {
	
	new Handle:kv = CreateKeyValues( "Posters" );
	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );
	decl String:file[256];
	BuildPath( Path_SM, file, sizeof(file), "configs/posters.txt" );
	if( FileExists(file) ) {
		if( !FileToKeyValues( kv, file ) ) {
			CloseHandle(kv);
			SetFailState( "Couldn't Load Config" );
		}
	} else {
		SetFailState( "Config Not Found: %s", file );
		return;
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

public OnMapStart() {
	// debug

	LoadConfig();
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:sm_trace_point( client, args ) {
	decl Float:start[3];
	decl Float:angles[3];

	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );

	TR_TraceRayFilter( start, angles, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		decl Float:point[3];
		TR_GetEndPosition( point );
		ReplyToCommand( client, "Trace Result: %f %f %f", point[0], point[1], point[2] );
	} else {
		ReplyToCommand( client, "Trace did not hit." );
	}
	return Plugin_Handled;
}
