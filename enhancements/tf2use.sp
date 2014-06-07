#include <sourcemod>
#include <sdktools>
#include <tf2use>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =  {
	name = "tf2use",
	author = "mukunda",
	description = "interface for using objects",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
};

//-------------------------------------------------------------------------------------------------
#define HAND 6.0	// size of trace hull
#define REACH 90.0	// length of trace hull

new Float:mins[3] = {-HAND,-HAND,-HAND};
new Float:maxs[3] = {HAND,HAND,HAND};

new registered_ents[2048]; // ent refs that point to the same entity, EXCEPT for clients which are user IDs
new Function:ent_callbacks[2048];
new Handle:ent_plugins[2048];

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	
	CreateNative( "TF2Use_Hook", Native_Hook );
	CreateNative( "TF2Use_Unhook", Native_Unhook );
	
	RegPluginLibrary( "tf2use" );
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "voicemenu", Command_voicemenu );
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter( entity, data ) {
	if( entity == data ) return false; // skip user
	
	if( registered_ents[entity] ) {
		if( entity <= MAXPLAYERS ) {
			if( GetClientOfUserId(registered_ents[entity]) ) {
				// use on player
				return true;
			} else {
				// this client disconnected; unhook it
				registered_ents[entity] = 0;
			}
		} else {
			if( EntRefToEntIndex( registered_ents[entity] ) == entity ) {
				// use on object
				return true;
			} else {
				// this entity has expired; unhook it
				registered_ents[entity] = 0;
			}
		}
	}
	return false; // unregistered entity
}

//-------------------------------------------------------------------------------------------------
GetArgInt( arg ) {
	decl String:text[32];
	GetCmdArg( arg, text, sizeof text );
	return StringToInt( text );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_voicemenu( client, args ) {
	// setup trace ray
	if( !IsPlayerAlive(client) ) return Plugin_Continue;
	if( args < 2 ) return Plugin_Continue;
	if( GetArgInt(1) != 0 || GetArgInt(2) != 0 ) return Plugin_Continue;
	
	// compute trace parameters
	decl Float:start[3];
	decl Float:end[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, end );
	GetAngleVectors( end, end, NULL_VECTOR, NULL_VECTOR );
	for( new i = 0; i < 3; i++ )
		end[i] = start[i] + end[i] * REACH;
	
	// run trace
	TR_TraceHullFilter( start, end, mins, maxs, CONTENTS_SOLID, TraceFilter, client );
	if( TR_DidHit() ) {
		new ent = TR_GetEntityIndex();
		if( ent > 0 ) {
			// trigger "use"
			Call_StartFunction( ent_plugins[ent], ent_callbacks[ent] );
			Call_PushCell( client );
			Call_PushCell( ent );
			new bool:res;
			Call_Finish( res );
			
			if( res ) {
				registered_ents[ent] = 0;
			}
			
			// and block "MEDIC!"
			return Plugin_Handled;
		}
	}
	
	// otherwise behave normally
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
bool:RegisterEntity( ent, Handle:plugin, Function:callback ) {
	if( ent <= MaxClients ) {
		if( !IsClientInGame(ent) ) return false;
		registered_ents[ent] = GetClientUserId( ent );
	} else if( ent > MaxClients && ent < 2048 ) {
		registered_ents[ent] = EntIndexToEntRef( ent );
	} else {
		return false;
	}
	ent_callbacks[ent] = callback;
	ent_plugins[ent] = plugin;
	return true;
}

//-------------------------------------------------------------------------------------------------
UnregisterEntity( ent ) {
	registered_ents[ent] = 0;
}

//-------------------------------------------------------------------------------------------------
public Native_Hook( Handle:plugin, numParams ) {
	RegisterEntity( GetNativeCell(1), plugin, GetNativeCell(2) );
}

//-------------------------------------------------------------------------------------------------
public Native_Unhook( Handle:plugin, numParams ) {
	UnregisterEntity( GetNativeCell(1) );
}
