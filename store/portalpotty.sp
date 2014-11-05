
//-----------------------------------------------------------------------------
#include <sourcemod>
#include <traceeyes>
#include <sdkhooks>

//-----------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "portalpotty",
	author = "mukunda",
	description = "Portal Potty (TM)",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
}

//-----------------------------------------------------------------------------

// portal potty instances
new Handle:g_instances;
 

// definitions of each array entry
enum {
	I_ENT,		// entref of base
	I_DOOR,		// entref of door
	I_OWNER,	// userid of owner
	I_SIZE
};

// models that are used
#define MODEL_BASE "models/props_urban/outhouse002.mdl"
#define MODEL_DOOR "models/props_urban/outhouse_door001.mdl"

//-----------------------------------------------------------------------------
public OnPluginStart() {
	g_instances = CreateArray( I_SIZE );
	RegConsoleCmd( "pp_test", test );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( MODEL_BASE );
	PrecacheModel( MODEL_DOOR );
}

/** ---------------------------------------------------------------------------
 * Game Frame callback:
 *  - updates active instances
 */
public OnGameFrame() {
	for( new i = 0; i < GetArraySize( g_instances ); i++ ) {
		
	}
}

/** ---------------------------------------------------------------------------
 * [COMMAND] Test command.
 */
public Action:test( client, args ) {
	decl Float:pos[3];
	if( !TraceEyes( client, pos ) ) {
		PrintToChat( client, "invalid pos." );
		return Plugin_Handled;
	}
	
	decl Float:angles[3];
	GetClientEyeAngles( client, angles );
	
	Create( client, pos, angles[1] + 180.0 );
	return Plugin_Handled;
}

/** ---------------------------------------------------------------------------
 * Create a Portal Potty(TM).
 *
 * @param owner     Owner of the new device.
 * @param pos       Floor position to spawn.
 * @param direction Angle the thing should be facing
 * @returns true on success
 */
bool:Create( owner, Float:pos[3], Float:direction ) {
	direction = RoundToNearest(direction/90.0) * 90.0;
	// create portapotty object
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
	
	// create the door
	new door = CreateEntityByName( "prop_door_rotating" );
	DispatchKeyValue( door, "physdamagescale", "0.0" );
	DispatchKeyValue( door, "model", MODEL_DOOR );
	DispatchKeyValue( door, "spawnpos", "0" );
	DispatchKeyValue( door, "speed", "200" );
	DispatchKeyValue( door, "returndelay", "1" );
	DispatchKeyValue( door, "opendir", "1" );
	DispatchKeyValue( door, "spawnflags", "0" );
	DispatchKeyValue( door, "forceclosed", "1" );
	DispatchKeyValue( door, "distance", "90" );
	DispatchKeyValue( door, "health", "5" );
	DispatchSpawn( door );
	
	decl Float:doorpos[3];
	new Float:dy = -17.0;
	new Float:dx = 27.0;
	doorpos[2] = 3.5;
	doorpos[1] = (  Sine(DegToRad(direction))*dx) + (Cosine(DegToRad(direction))*dy);
	doorpos[0] = (Cosine(DegToRad(direction))*dx) - (  Sine(DegToRad(direction))*dy);
	for( new i = 0; i < 3; i++ ) {
		doorpos[i] += pos[i];
	} 	
	TeleportEntity( door, doorpos, angles, zeros );
	
	
	SetVariantString( "!activator" );
	AcceptEntityInput( door, "SetParent", ent );
	SDKHook( door, SDKHook_UsePost, DoorHook );
	
	
	new data[I_SIZE];
	data[I_ENT] = EntIndexToEntRef( ent );
	data[I_DOOR] = EntIndexToEntRef( door );
	data[I_OWNER] = GetClientUserId( owner );
	PushArrayArray( g_instances, data );
	
	return true;
}

/** ---------------------------------------------------------------------------
 * Callback when a door is touched. We toggle it open in here because it 
 * doesn't work otherwise (when not attached to a static prop).
 */
public Action:DoorHook(entity, activator, caller, UseType:type, Float:value) {

	AcceptEntityInput( entity, "Toggle" );
	return Plugin_Handled;
}

