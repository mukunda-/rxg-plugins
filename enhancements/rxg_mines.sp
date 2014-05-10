
/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define CSS // compile for counter strike source

//
// Changelog:
// 11:54 AM 9/26/2013 - 1.0.7
//   cleaned up shit
//   mine restock on respawn
//   proper cvar usage (hooked/cached)
// 2:48 PM 9/2/2013 - 1.0.6
//   CSS support
//   placement cooldown
// 8:41 AM 12/1/2012 - 1.0.5
//   custom laser texture (brighter/hi-res)
// 11:48 PM 11/30/2012 - 1.0.4
//   default mines to 3
//   team filtering option
//   finer laser texture (less aliasing)
// 1:23 PM 10/30/2012 - 1.0.3beta
//   silent defusal
//   reduced defuse time (3->2 seconds)
// 5:29 PM 10/29/2012 - 1.0.2beta
//   mine defusal
// 10:37 PM 10/28/2012 - 1.0.1beta
//   reduced explosion sound volume
//   throttled explosion sounds (1 per 0.1 seconds)
//   proper explosion sound panning
//   placement on windows
// 4:12 PM 10/27/2012 - 1.0.0beta
//   initial release

//----------------------------------------------------------------------------------------------------------------------

#if defined CSS
#define SOUND_PLACE		"weapons/g3sg1/g3sg1_slide.wav"
#else
#define SOUND_PLACE		"weapons/g3sg1/g3sg1_slideback.wav"
#endif

#define COOLDOWN 0.01 // debug 1.0

#define SOUND_ARMING	"weapons/c4/c4_beep1.wav"     // UI/beep07.wav
#define SOUND_ARMED		"items/nvg_on.wav"
#define SOUND_DEFUSE	"weapons/c4/c4_disarm.wav"

//----------------------------------------------------------------------------------------------------------------------

#define MODEL_MINE		"models/tripmine/tripmine.mdl" 
#define MODEL_BEAM		"materials/thinlaser/thinlaser.vmt" //"materials/sprites/purplelaser1.vmt"

#define LASER_WIDTH		0.6//0.12

#define LASER_COLOR_T	"254 218 92"
#define LASER_COLOR_T_START	"76 65 27"
//#define LASER_COLOR_T	"128 109 46"
//#define LASER_COLOR_T	"104 167 72"
#define LASER_COLOR_CT	"38 75 251"
#define LASER_COLOR_CT_START	"11 22 75"
#define LASER_COLOR_D	"38 251 42"
#define LASER_COLOR_D_START	"11 75 12"

//----------------------------------------------------------------------------------------------------------------------

//
// the distances for the placement traceray from the client's eyes
//
#define TRACE_START		1.0
#define TRACE_LENGTH	160.0

//----------------------------------------------------------------------------------------------------------------------


#define COMMAND			"mine"

#if defined CSS
#define ALTCOMMAND		""
#else
#define ALTCOMMAND		"buyammo2"
#endif



//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxg_mines",
	author = "REFLEX-GAMERS",
	description = "CS:GO trip mines",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Handle:sm_mines_amount;		// number of mines each player gets per round
new Handle:sm_mines_damage;		// damage of the mines
new Handle:sm_mines_dmgradius;	// radius override for explosion (0=disable)

new Handle:sm_mines_filter;	// detonation mode

new Handle:sm_mines_allow;		// who can place mines, 0 = all, 2 = T only, 3 = CT only
new Handle:sm_mines_defuse;	// who can defuse mines, 0 = all, 2 = T only, 3 = CT only

new c_mines_amount;		// cached convars
new c_mines_damage;
new c_mines_dmgradius;
new c_mines_filter;
new c_mines_allow;
new c_mines_defuse;
//----------------------------------------------------------------------------------------------------------------------

new num_mines[MAXPLAYERS+1];	// number of mines per player

new mine_counter = 0;

new bool:explosion_sound_enable=true;

//new last_playeruse_id;
//new last_playeruse_target;
new last_mine_used;

new Float:defuse_time[MAXPLAYERS+1];
new defuse_target[MAXPLAYERS+1];
new Float:defuse_position[MAXPLAYERS+1][3];
new Float:defuse_angles[MAXPLAYERS+1][3];
new bool:defuse_cancelled[MAXPLAYERS+1];
new defuse_userid[MAXPLAYERS+1];

#define DEFUSE_ANGLE_THRESHOLD 5.0  // 5 degrees
#define DEFUSE_POSITION_THRESHOLD 1.0 // 1 unit

#define DEFUSE_TIME 2.0
#define DEFUSE_TIME_INT 2

new Float:last_mine_use[MAXPLAYERS+1];
 
//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	sm_mines_amount = CreateConVar( "sm_mines_amount", "3", "Number of mines each player gets per round", FCVAR_PLUGIN );
	sm_mines_damage = CreateConVar( "sm_mines_damage", "100", "Damage (magnitude) of the tripmines", FCVAR_PLUGIN );
	sm_mines_dmgradius = CreateConVar( "sm_mines_dmgradius", "0", "Damage radius override (use this to clip high damage magnitudes)", FCVAR_PLUGIN );

	sm_mines_allow = CreateConVar( "sm_mines_allow", "0", "Who can place mines: 0 = all, 2 = T only, 3 = CT only", FCVAR_PLUGIN );
	sm_mines_defuse = CreateConVar( "sm_mines_defuse", "0", "Who can defuse mines: 0 = all, 2 = T only, 3 = CT only", FCVAR_PLUGIN );

	sm_mines_filter = CreateConVar( "sm_mines_filter", "0", "0 = detonate when laser touches anyone, 1 = enemies and owner only, 2 = enemies only", FCVAR_PLUGIN );

	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_use", Event_PlayerUse );
	HookEvent( "player_spawn", Event_PlayerSpawn );
	
	HookConVarChange( sm_mines_amount,		OnConVarChanged );
	HookConVarChange( sm_mines_damage,		OnConVarChanged );
	HookConVarChange( sm_mines_dmgradius,	OnConVarChanged );
	HookConVarChange( sm_mines_allow,		OnConVarChanged );
	HookConVarChange( sm_mines_defuse,		OnConVarChanged );
	HookConVarChange( sm_mines_filter,		OnConVarChanged );
	
	c_mines_amount = GetConVarInt( sm_mines_amount );
	c_mines_damage = GetConVarInt( sm_mines_damage );
	c_mines_dmgradius = GetConVarInt( sm_mines_dmgradius );
	c_mines_allow = GetConVarInt( sm_mines_allow );
	c_mines_defuse = GetConVarInt( sm_mines_defuse );
	c_mines_filter = GetConVarInt( sm_mines_filter );
	
	RegConsoleCmd( COMMAND, Command_Mine );

	if( strlen( ALTCOMMAND ) != 0 ) {
		RegConsoleCmd( ALTCOMMAND, Command_Mine );
	}

}

//----------------------------------------------------------------------------------------------------------------------
//
// precache models and sounds during map load
//
public OnMapStart() {

	// PRECACHE SOUNDS
	PrecacheSound( SOUND_PLACE, true );
	PrecacheSound( SOUND_ARMING, true );
	PrecacheSound( SOUND_ARMED, true );
	PrecacheSound( SOUND_DEFUSE, true );

	// PRECACHE MODELS
	PrecacheModel( MODEL_MINE );
	PrecacheModel( MODEL_BEAM );

	AddFileToDownloadsTable( "models/tripmine/tripmine.dx90.vtx" );
	AddFileToDownloadsTable( "models/tripmine/tripmine.mdl" );
	AddFileToDownloadsTable( "models/tripmine/tripmine.phy" );
	AddFileToDownloadsTable( "models/tripmine/tripmine.vvd" );

	AddFileToDownloadsTable( "materials/models/tripmine/minetexture.vmt" );
	AddFileToDownloadsTable( "materials/models/tripmine/minetexture.vtf" );
	
	AddFileToDownloadsTable( "materials/thinlaser/thinlaser.vmt" );
	AddFileToDownloadsTable( "materials/thinlaser/thinlaser.vtf" );

	PrecacheSound( "weapons/hegrenade/explode3.wav" );
	PrecacheSound( "weapons/hegrenade/explode4.wav" );
	PrecacheSound( "weapons/hegrenade/explode5.wav" );
}

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//----------------------------------------------------------------------------------------------------------------------


public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( cvar == sm_mines_amount ) {
		c_mines_amount = GetConVarInt( sm_mines_amount );
	} else if( cvar == sm_mines_damage ) {
		c_mines_damage = GetConVarInt( sm_mines_damage );
	} else if( cvar == sm_mines_dmgradius ) {
		c_mines_dmgradius = GetConVarInt( sm_mines_dmgradius );
	} else if( cvar == sm_mines_allow ) {
		c_mines_allow = GetConVarInt( sm_mines_allow );
	} else if( cvar == sm_mines_defuse ) {
		c_mines_defuse = GetConVarInt( sm_mines_defuse );
	} else if( cvar == sm_mines_filter ) {
		c_mines_filter = GetConVarInt( sm_mines_filter );
	}
	
}


//----------------------------------------------------------------------------------------------------------------------
//
// restore mines on round start
//
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
//	GiveAllPlayersMines();
	mine_counter = 0;
	explosion_sound_enable=true;
}

//----------------------------------------------------------------------------------------------------------------------
//
// give player his mines on connect
//
public OnClientConnected( client ) {
	GivePlayerMines( client );
	last_mine_use[client] = 0.0;
}


//----------------------------------------------------------------------------------------------------------------------
public OnClientDisconnect( client ) {
	DeletePlacedMines( client );
	
}

//----------------------------------------------------------------------------------------------------------------------
public DeletePlacedMines(client) {
	new ent = -1;
	decl String:name[32];
	while( (ent = FindEntityByClassname( ent, "prop_physics_override" )) != -1 ) {
		GetEntPropString( ent, Prop_Data, "m_iName", name, 32 );
		if( strncmp( name, "rxgtripmine", 11, true ) == 0 ) {
			if( GetEntPropEnt( ent, Prop_Data, "m_hLastAttacker" ) == client ) { // slight hack here, cant use owner entity because it wont allow the owner to destroy his own mines.
				AcceptEntityInput( ent, "Kill" );

				
			}
		}
	}

	while( (ent = FindEntityByClassname( ent, "env_beam" )) != -1 ) {
		GetEntPropString( ent, Prop_Data, "m_iName", name, 32 );
		if( strncmp( name, "rxgtripmine", 11, true ) == 0 ) {
			if( GetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity" ) == client ) {
				AcceptEntityInput( ent, "Kill" );

				
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
//
// give all players their mines
//

/*
public GiveAllPlayersMines() {
	new mines = GetConVarInt( sm_pp_tripmines );
	for( new i = 0; i < MAXPLAYERS+1; i++ ) {
		num_mines[i] = mines;
	}
}*/

public Event_PlayerSpawn( Handle:event, const String:name[], bool:db ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	
	GivePlayerMines( client );
	
}

//----------------------------------------------------------------------------------------------------------------------
//
// give one player his mines
//
GivePlayerMines( client ) {
	num_mines[client] = c_mines_amount;
}

//----------------------------------------------------------------------------------------------------------------------
//
// clamp all mines to the tripmine setting, used after the cvar is changed
//
/*
ClampMines() {
	new mines = GetConVarInt( sm_pp_tripmines );
	for( new i = 0; i < MAXPLAYERS+1; i++ ) {
		if( num_mines[i] > mines ) {
			num_mines[i] = mines;
		}
	}
}*/

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Mine( client, args ) {
	
	if( GetGameTime() < last_mine_use[client] + COOLDOWN ) {
		return Plugin_Handled;
	}
	last_mine_use[client] = GetGameTime();
	if( IsClientConnected(client) ) {
		if( IsPlayerAlive(client) ) {
			
			if( c_mines_allow > 0 && GetClientTeam(client) != c_mines_allow ) {
				PrintCenterText( client, "Your team cannot place mines." );
				return Plugin_Handled;
			}
			
			if( num_mines[client] > 0 ) {
				// plant mine
				PlaceMine(client);
			} else {

				if( c_mines_amount != 0 ) {
					PrintCenterText( client, "You have no more mines." );
				} else {
					PrintCenterText( client, "Mines are disabled." );
				}
			}
		}
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public PlaceMine( client ) {
	

	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];
	GetClientEyePosition( client, trace_start );
	GetClientEyeAngles( client, trace_angle );
	GetAngleVectors( trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR );
	NormalizeVector( trace_end, trace_end ); // end = normal

	// offset start by near point
	for( new i = 0; i < 3; i++ )
		trace_start[i] += trace_end[i] * TRACE_START;
	
	for( new i = 0; i < 3; i++ )
		trace_end[i] = trace_start[i] + trace_end[i] * TRACE_LENGTH;
	
	TR_TraceRayFilter( trace_start, trace_end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0 );
	
	if( TR_DidHit( INVALID_HANDLE ) ) {
		num_mines[client]--;

		if( num_mines[client] != 0 ) {
			PrintCenterText( client, "You have %d mines left!", num_mines[client] );
		} else  {
			PrintCenterText( client, "That was your last mine!" );
		}

		TR_GetEndPosition( trace_end, INVALID_HANDLE );
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal);
		 
		SetupMine( client, trace_end, trace_normal );

	} else {
		PrintCenterText( client, "Invalid mine position." );
	}
}

//----------------------------------------------------------------------------------------------------------------------
//
// filter out mine placement on anything but the map
//
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public MineLaser_OnTouch( const String:output[], caller, activator, Float:delay ) {

	AcceptEntityInput(caller, "TurnOff");
	AcceptEntityInput(caller, "TurnOn");

	if( activator == 0 ) return;

	new bool:detonate = false;
	if( !IsValidClient(activator) ) {
		// world!
		detonate = true;
		return;
	}

	decl String:targetname[64];
	if( !detonate ) {
		if( !IsPlayerAlive(activator) ) return;


		GetEntPropString( caller, Prop_Data, "m_iName", targetname, sizeof(targetname) );
		new team = targetname[12] - 32;
		new owner = targetname[11]-32;
		
		if( c_mines_filter == 1 || c_mines_filter == 2 ) {
			// detonate if enemy or owner
			
			if( !IsValidClient(owner) ) {
				// something went wrong, bypass test
				detonate = true;
			} else {
				//new team = GetClientTeam( owner );
				if( GetClientTeam( activator ) != team || (owner == activator && c_mines_filter == 1) ) {
					detonate = true;
				}
			}
		} else if( c_mines_filter == 0 ) {
			// detonate always
			detonate = true;
		}
	}

	if( detonate ) {

		decl String:buffers[2][32];

		ExplodeString( targetname, "_", buffers, 2, 32 );

		new ent_mine = StringToInt( buffers[1] );

		AcceptEntityInput( ent_mine, "break" );
		
	}

	return;
}

//----------------------------------------------------------------------------------------------------------------------
public SetupMine( client, Float:position[3], Float:normal[3] ) {
  
	decl String:mine_name[64];
	decl String:beam_name[64];
	decl String:str[128];

	Format( mine_name, 64, "rxgtripmine%c%c%d", 32+client, 32+GetClientTeam(client), mine_counter );
	
	
	new Float:angles[3];
	GetVectorAngles( normal, angles );
	
	
	new ent = CreateEntityByName( "prop_physics_override" );

	Format( beam_name, 64, "rxgtripmine%c%c%d_%d", 32+client, 32+GetClientTeam(client), mine_counter, ent );

	DispatchKeyValue( ent, "model", MODEL_MINE );
	DispatchKeyValue( ent, "physdamagescale", "0.0");	// enable this to destroy via physics?
	DispatchKeyValue( ent, "health", "1" ); // use the set entity health function instead ?
	DispatchKeyValue( ent, "targetname", mine_name);
	DispatchKeyValue( ent, "spawnflags", "256"); // set "usable" flag
	DispatchSpawn( ent );

	SetEntityMoveType(ent, MOVETYPE_NONE);
	SetEntProp(ent, Prop_Data, "m_takedamage", 2);
	SetEntPropEnt(ent, Prop_Data, "m_hLastAttacker", client); // use this to identify the owner (see below)
	//SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity",client); //Set the owner of the mine (cant, it stops the owner from destroying it)
	SetEntityRenderColor( ent, 255, 255, 255, 255 );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2); // set non-collidable


	// when the mine is broken, delete the laser beam
	Format( str, sizeof(str), "%s,Kill,,0,-1", beam_name );
	DispatchKeyValue( ent, "OnBreak", str );

	// hook to explosion function
	HookSingleEntityOutput( ent, "OnBreak", MineBreak, true );

	HookSingleEntityOutput( ent, "OnPlayerUse", MineUsed, false );

	// offset placement slightly so it is on the wall's surface
	for( new i =0 ; i < 3; i++ ) {
		position[i] += normal[i] * 0.5;
	}
	TeleportEntity(ent, position, angles, NULL_VECTOR );//angles, NULL_VECTOR );

	// trace ray for laser (allow passage through windows)
	TR_TraceRayFilter(position, angles, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All, 0);

	new Float:beamend[3];
	TR_GetEndPosition( beamend, INVALID_HANDLE );

	// create beam
	new ent_laser = CreateLaser( beamend, position, beam_name, GetClientTeam(client) );
	
	// when touched, activate/break the mine

	if( c_mines_filter == 1 || c_mines_filter == 2 ) {
		HookSingleEntityOutput( ent_laser, "OnTouchedByEntity", MineLaser_OnTouch );
	} else {
		
		// detonate against anything
		Format( str, sizeof(str), "%s,Break,,0,-1", mine_name );
		DispatchKeyValue( ent_laser, "OnTouchedByEntity", str );
	}

	SetEntPropEnt(ent_laser, Prop_Data, "m_hOwnerEntity",client); //Set the owner of the mine's beam
	
	// timer for activating
	new Handle:data;
	CreateDataTimer( 1.0, ActivateTimer, data, TIMER_REPEAT );  
	ResetPack(data);
	WritePackCell(data, 0);
	WritePackCell(data, ent);
	WritePackCell(data, ent_laser);

	PlayMineSound( ent, SOUND_PLACE );
	
	mine_counter++;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:ActivateTimer( Handle:timer, Handle:data ) {
	ResetPack(data);

	new counter = ReadPackCell(data);
	new ent = ReadPackCell(data);
	new ent_laser = ReadPackCell(data);

	if( !IsValidEntity(ent) ) { // mine was broken (gunshot/grenade) before it was armed
		return Plugin_Stop;
	}

	if( counter < 2 ) {
		PlayMineSound( ent, SOUND_ARMING );
		counter++;
		ResetPack(data);
		WritePackCell(data, counter);
	} else {
		PlayMineSound( ent, SOUND_ARMED );

		// enable touch trigger and increase brightness
		DispatchKeyValue(ent_laser, "TouchType", "4");

#if defined CSS
		new owner = GetEntPropEnt(ent, Prop_Data, "m_hLastAttacker" );
		if( owner != 0 && IsClientInGame(owner) ) {
			new team = GetClientTeam(owner);
			decl String:color[16];
			if( team == 2 ) color = LASER_COLOR_T;
			else if( team == 3 ) color = LASER_COLOR_CT;
			else color = LASER_COLOR_D;

			DispatchKeyValue( ent_laser, "rendercolor", color );
		} else {
			decl String:color[16];
			color = LASER_COLOR_D;
			DispatchKeyValue( ent_laser, "rendercolor", color );
		}
#else
		DispatchKeyValue(ent_laser, "renderamt", "220");
#endif

		return Plugin_Stop;
	}
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
PlayMineSound( entity, const String:sound[] ) {
	EmitSoundToAll( sound, entity );
}

//----------------------------------------------------------------------------------------------------------------------
public MineBreak (const String:output[], caller, activator, Float:delay) { 

	decl String:targetname[64];
	GetEntPropString( caller, Prop_Data, "m_iName", targetname, sizeof(targetname) );

	new team = targetname[12] - 32;
	new client = targetname[11] - 32;

	new attacker = GetEntPropEnt( caller, Prop_Data, "m_hLastAttacker" );
	if( attacker == client ) {
		if( GetClientTeam(client) != team ) {
			// client switched sides (ie zombified), use world damage
			attacker = 0;
		}
	}

	new Float:pos[3];
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", pos);

	// create explosion
	CreateExplosionDelayed( pos, attacker );

}

//----------------------------------------------------------------------------------------------------------------------
public Action:DefuseTimer( Handle:timer, any:client ) {
	new userid = defuse_userid[client];
	new old_client = GetClientOfUserId( userid );

	if( !IsValidClient(old_client) || old_client != client ) {
		
		return Plugin_Stop; // something went wrong
	}

	if( defuse_cancelled[client] ) {
		StopClientProgressBar(client);
		defuse_userid[client] = 0;
		return Plugin_Stop;
	}

	if( !IsValidEntity(defuse_target[client]) ) {
		// mine was killed
		StopClientProgressBar(client);
		defuse_userid[client] = 0;
		return Plugin_Stop;
	}

	new bool:player_moved=false;
	// VERIFY ANGLES
	new Float:angles[3];
	
	
	GetClientEyeAngles( client, angles );
	for( new i = 0; i < 3; i++ ) {
		if( FloatAbs(angles[i] - defuse_angles[client][i]) > DEFUSE_ANGLE_THRESHOLD ) {
			player_moved=true;
			break;
		}
	}

	if( !player_moved ) {
		new Float:pos[3];
		GetClientAbsOrigin( client, pos );

		for( new i = 0; i < 3; i++ ) {
			pos[i] -= defuse_position[client][i];
			pos[i] *= pos[i];
		}
		
		new Float:dist = pos[0] + pos[1] + pos[2];

		if( dist >= (DEFUSE_POSITION_THRESHOLD*DEFUSE_POSITION_THRESHOLD) ) {
			player_moved = true;
		}
	}

	if( player_moved ) {
		PrintHintText( client, "Defusal Interrupted." );
		StopClientProgressBar(client);
		defuse_userid[client] = 0;
		return Plugin_Stop;
	}


	defuse_time[client] += 0.25;
	if( defuse_time[client] < DEFUSE_TIME ) {
		//new String:message[16] = "Defusing.";
		
		//for( new i = 0; i < defuse_time[client]; i++ )
		//	StrCat( message, 16, "." );

		//PrintHintText( client, message );
	} else {

		EmitSoundToClient( client, SOUND_PLACE );//
//		PlayMineSound( defuse_target[client], SOUND_PLACE );

		num_mines[client]++;

		// defuse mine and give to player
		UnhookSingleEntityOutput( defuse_target[client], "OnBreak", MineBreak );
		AcceptEntityInput( defuse_target[client], "Break" );

		
		
		PrintHintText( client, "Mine Defused. You have %d mine%s now", num_mines[client], num_mines[client] != 1 ? "s" : "" );

		StopClientProgressBar(client);
		defuse_userid[client] = 0;
		return Plugin_Stop;
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
StartClientProgressBar( client, duration ) {
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", duration );
}

//----------------------------------------------------------------------------------------------------------------------
StopClientProgressBar( client ) {
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0 );
}

//----------------------------------------------------------------------------------------------------------------------
StartDefusal( client, target ) {
	if( defuse_userid[client] != 0 ) return; // defusal already in progress

	defuse_time[client] = 0.0;
	defuse_target[client] = target;
	GetClientAbsOrigin( client, defuse_position[client] );
	GetClientEyeAngles( client, defuse_angles[client] );
	defuse_cancelled[client] = false;
	defuse_userid[client] = GetClientUserId(client);
	CreateTimer( 0.25, DefuseTimer, client, TIMER_REPEAT );

	StartClientProgressBar( client, DEFUSE_TIME_INT );
	EmitSoundToClient( client, SOUND_DEFUSE );//
//	PlayMineSound( defuse_target[client], SOUND_DEFUSE );
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {

	if( !IsValidClient(client) ) return Plugin_Continue;

	if( (buttons & IN_USE) == 0 ) {
	
		if( defuse_userid[client] && !defuse_cancelled[client] ) { // is defuse in progress?
			defuse_cancelled[client] = true;
			//PrintHintText( client, "Defusal Cancelled." );
		}
	}
	
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public MineUsed(const String:output[], caller, activator, Float:delay)
{ 
	// register last mine touched
	last_mine_used = caller;

//	PrintToChatAll( "debug1, %s, %d, %d, %d", output, caller, last_playeruse_id, last_playeruse_target );
	 
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new id = GetEventInt( event, "userid" );
	new target = GetEventInt( event, "entity" );

	if( last_mine_used == target ) { // verify this use event matches with the mine-use event

		new client = GetClientOfUserId( id );
		if( client == 0 ) return; // client has disconnected

		if( c_mines_defuse > 0 && GetClientTeam(client) != c_mines_defuse ) {
			PrintCenterText( client, "Your team cannot defuse mines." );
			return;
		}
		StartDefusal( client, target );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public CreateLaser(Float:start[3], Float:end[3], String:name[], team)
{
	new ent = CreateEntityByName("env_beam");
	if (ent != -1)
	{

		decl String:color[16];


		TeleportEntity(ent, start, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(ent, MODEL_BEAM); // This is where you would put the texture, ie "sprites/laser.vmt" or whatever.
		SetEntPropVector(ent, Prop_Data, "m_vecEndPos", end);
		DispatchKeyValue(ent, "targetname", name );

#if defined CSS
		if( team == 2 ) color = LASER_COLOR_T_START;
		else if( team == 3 ) color = LASER_COLOR_CT_START;
		else color = LASER_COLOR_D_START;

		DispatchKeyValue(ent, "rendercolor", color );
		DispatchKeyValue(ent, "renderamt", "255" );
#else
		if( team == 2 ) color = LASER_COLOR_T;
		else if( team == 3 ) color = LASER_COLOR_CT;
		else color = LASER_COLOR_D;

		DispatchKeyValue(ent, "rendercolor", color );
		DispatchKeyValue(ent, "renderamt", "80" );
#endif

		DispatchKeyValue(ent, "decalname", "Bigshot"); 
		DispatchKeyValue(ent, "life", "0"); 
		DispatchKeyValue(ent, "TouchType", "0");
		DispatchSpawn(ent);
		SetEntPropFloat(ent, Prop_Data, "m_fWidth", LASER_WIDTH); 
		SetEntPropFloat(ent, Prop_Data, "m_fEndWidth", LASER_WIDTH); 
		ActivateEntity(ent);
		AcceptEntityInput(ent, "TurnOn");
	}

	return ent;
}
 
//----------------------------------------------------------------------------------------------------------------------
public CreateExplosionDelayed( Float:vec[3], owner ) {

	new Handle:data;
	CreateDataTimer( 0.1, CreateExplosionDelayedTimer, data );
	
	WritePackCell(data,owner);
	WritePackFloat(data,vec[0]);
	WritePackFloat(data,vec[1]);
	WritePackFloat(data,vec[2]);

}

//----------------------------------------------------------------------------------------------------------------------
public Action:CreateExplosionDelayedTimer( Handle:timer, Handle:data ) {

	ResetPack(data);
	new owner = ReadPackCell(data);

	new Float:vec[3];
	vec[0] = ReadPackFloat(data);
	vec[1] = ReadPackFloat(data);
	vec[2] = ReadPackFloat(data);

	CreateExplosion( vec, owner );
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:EnableExplosionSound( Handle:timer ) {
	explosion_sound_enable = true;
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public CreateExplosion( Float:vec[3], owner ) {
	new ent = CreateEntityByName("env_explosion");	
	DispatchKeyValue(ent, "classname", "env_explosion");
	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity",owner); //Set the owner of the explosion

	new mag = c_mines_damage; 
	new rad = c_mines_dmgradius;
	SetEntProp(ent, Prop_Data, "m_iMagnitude",mag); 
	if( rad != 0 ) {
		SetEntProp(ent, Prop_Data, "m_iRadiusOverride",rad); 
	}

	DispatchSpawn(ent);
	ActivateEntity(ent);

	decl String:exp_sample[64];

	#if defined CSS
	Format( exp_sample, 64, "^weapons/hegrenade/explode%d.wav", GetRandomInt( 3, 5 ) );
	#else
	Format( exp_sample, 64, ")weapons/hegrenade/explode%d.wav", GetRandomInt( 3, 5 ) );
	#endif

	if( explosion_sound_enable ) {
		explosion_sound_enable = false;
		EmitAmbientSound( exp_sample, vec, _, SNDLEVEL_GUNFIRE  );
		CreateTimer( 0.1, EnableExplosionSound );
	} 

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}
