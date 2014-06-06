 
#include <sourcemod>
#include <sdktools>
#include <rxgstore>

#pragma semicolon 1

#define MIN_DISTANCE 50.0
#define MAX_DISTANCE 200.0

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "pumpkin item",
	author = "WhiteThunder",
	description = "deployable pumpkin bombs",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};


#define ITEM_NAME "pumpkin"
#define ITEM_FULLNAME "pumpkin"
#define ITEMID 6

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	RegAdminCmd( "sm_spawnpumpkin", Command_spawnpumpkin, ADMFLAG_RCON );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public bool:SpawnPumpkin( client ) {
	
	decl Float:start[3], Float:angle[3], Float:end[3], Float:feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		decl Float:norm[3], Float:norm_angles[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		new Float:distance = GetVectorDistance( feet, end, true );

		if ( distance < MIN_DISTANCE * MIN_DISTANCE ) {
			PrintToChat( client, "\x07808080Cannot plant that close" );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if ( distance > MAX_DISTANCE * MAX_DISTANCE ) {
			PrintToChat( client, "\x07808080Cannot plant that far away" );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if ( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07808080Cannot plant there" );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	}
	
	new ent = CreateEntityByName( "tf_pumpkin_bomb" );
	DispatchKeyValue( ent, "targetname", "RXG_PUMPKIN" );
	DispatchSpawn( ent );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	decl String:team_color[7];
	new team = GetClientTeam(client);
	
	if( team == 2 ){
		team_color = "ff3d3d";
	} else if ( team == 3 ){
		team_color = "84d8f4";
	} else {
		return true;
	}
	
	decl String:name[32];
	GetClientName(client, name, sizeof name);
	
	PrintToChatAll("\x07%s%s \x07FFD800has spawned a pumpkin!", team_color, name);
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	return SpawnPumpkin(client);
}

//-------------------------------------------------------------------------------------------------
public Action:Command_spawnpumpkin( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnPumpkin(client);
	return Plugin_Handled;
}
