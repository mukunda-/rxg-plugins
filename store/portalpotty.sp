
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
new Handle:g_menu;
 
new entmap[2048];



enum {	
	M_POTTY,
	M_SIZE
};

new menu_data[MAXPLAYERS][M_SIZE];

// definitions of each array entry
enum {
	I_ENT,		// entref of base
	I_DOOR,		// entref of door
	I_OWNER,	// userid of owner
	I_TIME,		// timer for events
	I_STATE,	// S_
	I_OWNER_INSIDE, // if the owner is inside
	I_MENU_ACTIVE,
	I_SIZE
};

enum {
	S_START,
	S_IDLE
};

// models that are used
#define MODEL_BASE "models/props_urban/outhouse002.mdl"
#define MODEL_DOOR "models/props_urban/outhouse_door001.mdl"

#define OPEN_SOUND "ambient/machines/steam_release_1.wav"

//-----------------------------------------------------------------------------
public OnPluginStart() {
	g_instances = CreateArray( I_SIZE );
	RegConsoleCmd( "pp_test", test );
	
	g_menu = CreateMenu( PottyMenuHandler );
	SetMenuTitle( g_menu, "PortalPotty™ Controller" );
	AddMenuItem( g_menu, "hatch", "Close Hatch" );
	AddMenuItem( g_menu, "dive", "Dive" ); 
	AddMenuItem( g_menu, "horn", "Horn" ); 
	AddMenuItem( g_menu, "sonar", "Sonar" ); 
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( MODEL_BASE );
	PrecacheModel( MODEL_DOOR );
	PrecacheSound( OPEN_SOUND );
}

/** ---------------------------------------------------------------------------
 * Game Frame callback:
 *  - updates active instances
 */
public OnGameFrame() {
	decl data[I_SIZE];
	for( new i = 0; i < GetArraySize( g_instances ); i++ ) {
		
		GetArrayArray( g_instances, i, data );
		if( !IsValidEntity( data[I_ENT] ) ) {
			RemoveFromArray( g_instances, i );
			i--;
			continue;
		}
		
		Update( data );
		SetArrayArray( g_instances, i, data );
	}
}


/** ---------------------------------------------------------------------------
 * Construct a Portal Potty(TM).
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
	DispatchKeyValue( door, "returndelay", "-1" );
	DispatchKeyValue( door, "opendir", "1" );
	DispatchKeyValue( door, "spawnflags", "32768" );
	DispatchKeyValue( door, "forceclosed", "1" );
	DispatchKeyValue( door, "distance", "90" );
	DispatchKeyValue( door, "health", "0" );
	DispatchKeyValue( door, "soundmoveoverride", OPEN_SOUND );
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
	
	
	decl data[I_SIZE];
	data[I_ENT] = EntIndexToEntRef( ent );
	data[I_DOOR] = EntIndexToEntRef( door );
	data[I_OWNER] = GetClientUserId( owner );
	data[I_TIME] = _:GetGameTime();
	data[I_STATE] = S_START;
	data[I_OWNER_INSIDE] = 0;
	new index = PushArrayArray( g_instances, data );
	entmap[I_ENT] = index;
	entmap[I_DOOR] = index;
	
	return true;
}

ShowControlMenu( client, potty ) {
	if( 
	menu_data[client][M_POTTY] = potty;
}

HideControlMenu( client ) {
	
}

/** ---------------------------------------------------------------------------
 * Update a portal potty.
 *
 * @param data Entry from instance array.
 */
bool:Update( data[] ) {
	new Float:time = GetGameTime() - Float:data[I_TIME];
	new owner = GetClientOfUserId( data[I_OWNER] );

	
	switch( data[I_STATE] ) {
		case S_START: {
			if( time > 1.0 ) {
				AcceptEntityInput( data[I_DOOR], "Open" );
				data[I_STATE] = S_IDLE;
			}
		}
		case S_IDLE: {
			if( owner == 0 ) break;
			if( !data[I_OWNER_INSIDE] ) {
				
				if( IsInside( data[I_ENT], owner ) ) {
				
					data[I_OWNER_INSIDE] = 1;
					DisplayMenu( g_menu, owner, MENU_TIME_FOREVER );
				}
			} else {
				if( !IsInside( data[I_ENT], owner ) ) {
					data[I_OWNER_INSIDE] = 0;
				}
			}
		}
	}
	
	if( data[I_OWNER_INSIDE] && owner != 0 ) {
		if( GetClientButtons(owner) & IN_USE ) {
			// show menu
		}
	}
}

/** ---------------------------------------------------------------------------
 * Check if a player is inside a potty.
 *
 * @param potty Potty entity.
 * @param client Client index to test.
 */
bool:IsInside( potty, client ) {
	if( client == 0 ) return false;
	
	decl Float:point[3];
	GetEntPropVector( potty, Prop_Data, "m_vecAbsOrigin", point );
	decl Float:pos[3];
	GetClientAbsOrigin( client, pos );
	new Float:cw = 5.0;
	new Float:pw = 15.0;

	if( 
		(pos[0] ) >= (point[0] - pw) && 
		(pos[0] ) < (point[0] + pw) &&
		(pos[1] ) >= (point[1] - pw) && 
		(pos[1] ) < (point[1] + pw) &&
		(pos[2]) >= (point[2] - 5.0) && 
		(pos[2]) < (point[2] + 64.0) ) {
		
		return true;
	}
	return false;
}

/** ---------------------------------------------------------------------------
 * Menu handler for potty controls.
 */
public PottyMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MENU_ACTION_SELECT ) {
		
	} else if( action == MENU_ACTION_END ) {
		
	}
}

/** ---------------------------------------------------------------------------
 * Callback when a door is touched. We toggle it open in here because it 
 * doesn't work otherwise (when not attached to a static prop).
 */
public Action:DoorHook(entity, activator, caller, UseType:type, Float:value) {
	
	AcceptEntityInput( entity, "Toggle" );
	return Plugin_Handled;
}

/** ---------------------------------------------------------------------------
 * [COMMAND] Test command.
 */
public Action:test( client, args ) {
	//DisplayMenu( g_menu, client, 60 );
 
	
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
