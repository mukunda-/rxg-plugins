
//-------------------------------------------------------------------------------------------------
#include <sourcemod>

#include <traceeyes>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "portalpotty",
	author = "mukunda",
	description = "Portal Potty (TM)",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
}

new Handle:instances;
#define INSTANCE_SIZE 32

enum {
	I_ENT,
	I_
};

#define MODEL_BASE "models/props_urban/outhouse002.mdl"
#define MODEL_DOOR "models/props_urban/outhouse_door001.mdl"

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	instances = CreateArray( INSTANCE_SIZE );
	RegConsoleCmd( "pp_test", test );
}

//-------------------------------------------------------------------------------------------------
public Action:test( client, args ) {
	decl Float:pos[3];
	if( !TraceEyes( client, pos ) ) {
		PrintToChat( client, "invalid pos." );
		return Plugin_Handled;
	}
	
	decl Float:angles[3];
	GetClientEyeAngles( client, angles );
	
	Create( pos, angles[1] );
	return Plugin_Handled;
}

bool:Create( Float:pos[3], Float:direction ) {
	new ent = CreateEntityByName( "prop_physics_override" );
	if( !ent ) return false;
	DispatchKeyValue( ent, "physdamagescale", "0.0" );
	DispatchKeyValue( ent, "model", MODEL_BASE );
	SetEntityMoveType( ent, MOVETYPE_VPHYSICS );
	
	DispatchSpawn( ent );
	new Float:zeros[3];
	new Float:angles[3];
	angles[1] = direction;
	
	TeleportEntity( ent, pos, angles, zeros );
	AcceptEntityInput( ent, "DisableMotion" );
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnGameFrame() {
	for( new i = 0; i < GetArraySize( instances ); ) {
		
	}
}
