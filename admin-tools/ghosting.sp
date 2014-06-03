// GHOSTING MOD

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <clientprefs>

//#define USE_DONATIONS

#if defined(USE_DONATIONS)
#include <donations>
#endif

// command list:
//   sm_ghost			: toggle ghosting mode
//   sm_gzap			: lethal electric powers
//   sm_gheal			: healing rainbow powers
//   sm_ghostie			: hostage spawning beam
//   sm_gchicken		: chicken spawning beam
//   sm_gsquawk			: ghost squawk
//   +sm_ginferno		: infernobeam (NEED SOMEONE TO FIGURE OUT HOW TO SPAWN FLAMES)
//   +sm_glaser			: laserbeam
//   sm_gexplode <power>	: lethal explosive beam with magnitude <power> (default 50)
//   sm_gsay <message>		: ghost message to all ("Boo says: ...")
//   sm_gpsay <target> <message> : ghost private message ("Boo whispers: ...") can use wildcard targets (@ct/@t)
//
//   sm_ggrab			: abduct/drop targetted entity - warning: avoid grabbing items held by players
//   sm_gspawn <name>		: spawn entity

//   sm_gbomb			: bomb
//   sm_gskull			: skull

//   sm_gban <steamid>			: ban a user from using ghost (server command)
//   sm_gunban <steamid>			: unban a user from using ghost (server command)

//   +sm_gforcefire		: make a player fire his gun

//   sm_gcash			: throw a fat stack of cash (500 BUX)

//   sm_gprop <name> <throw>	: spawn a prop
//   sm_glistprops		: list spawnable props

//   sm_gfire <size> <damagescale> : spawn a fire

// donators can use ghost in designated ghosting zones
// and can USE items as a ghost

// CHANGES - 1.1.2
//   support for donators
//   added haunted zone
//   added ghost +use
// CHANGES - 1.1.1
//   added sm_gfire
//   added sm_gprop, sm_glistprops
//   

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "ghosting",
	author = "mukunda",
	description = "the real kind of ghosting",
	version = "1.1.3",
	url = "www.reflex-gamers.com"
};

#define CASH_MONEY 500

#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5


#define LASER_LASER_POWER 20.0

#define SOUND_ZAP "ambient/energy/spark5.wav"
#define SOUND_HEAL "items/medshot4.wav"
#define SOUND_TEDDY "ambient/creatures/teddy.wav"
#define SOUND_GRAB "ambient/creatures/teddy.wav"
#define SOUND_LASER "ambient/energy/force_field_loop1.wav"
#define SOUND_FIRE "ambient/fire/fire_med_loop1.wav"

#define GHOST_TEXTURE "materials/ghosting/ghost.vmt"
#define LASER_TEXTURE "materials/sprites/laserbeam.vmt"
#define CROSSHAIR_TEXTURE "materials/sprites/hud/v_crosshair1.vmt"

#define INFERNO_LASER_COLOR "125 100 15"
#define INFERNO_LASER_WIDTH 4.0

#define LASER_LASER_COLOR "255 0 0"
#define LASER_LASER_WIDTH 0.25

new Float:g_fire_size;
new Float:g_fire_dmgscale;

new String:downloads_csgo[][] = {
	"materials/ghosting/ghost.vmt",
	"materials/ghosting/ghost.vtf"
};

new String:downloads_tf2[][] = {
	"materials/ghosting/ghost.vmt",
	"materials/ghosting/ghost.vtf"
}

new String:precache_textures[][] = {
	"materials/ghosting/ghost.vmt",
	CROSSHAIR_TEXTURE
};

/*
new String:prop_list[][] = {
	"melon",
	"cinderblock",
	"dumpster",
	"vendingmachine",
	"glassjug",
	"woodcrate",
};*/
/*
new String:prop_models[][] = {
	"models/props_junk/watermelon01.mdl",
	"models/props_junk/cinderblock01a.mdl",
	"models/props_junk/dumpster.mdl",
	"models/props/cs_office/vending_machine.mdl",
	"models/props_junk/glassjug01.mdl",
	"models/props_junk/wood_crate001a.mdl"
};*/

new Handle:mp_maxmoney;

new round_counter;

new bool:ghost_active[MAXPLAYERS+1];
new ghost_sprites[MAXPLAYERS+1];
new ghost_sprites_x[MAXPLAYERS+1];
//new Handle:ghost_timers[MAXPLAYERS+1];
new Float:ghost_hover[MAXPLAYERS+1];
new ghost_alpha[MAXPLAYERS+1];
new bool:ghost_fade[MAXPLAYERS+1];
new bool:ghost_donatormode[MAXPLAYERS+1];

new last_buttons[MAXPLAYERS+1];
new bool:show_crosshair[MAXPLAYERS+1];

new bool:grab_active[MAXPLAYERS+1];
new grabbed_entity[MAXPLAYERS+1];
new MoveType:grabbed_entity_movetype[MAXPLAYERS+1];

new total_grabs_active; // for optimization

new bool:laser_active[MAXPLAYERS+1];
new laser_type[MAXPLAYERS+1];
new laser_entity[MAXPLAYERS+1];
new laser_counter[MAXPLAYERS+1];

//new being_possessed_by[MAXPLAYERS+1];
//new ghost_possession[MAXPLAYERS+1];
new bool:ghost_forcefire[MAXPLAYERS+1];

//new client_buttons[MAXPLAYERS+1];

//-------------------------------------------------------------------------------------------------
new ghosts_active; // total number of ghosts active

//-------------------------------------------------------------------------------------------------
new Handle:sm_ghost_update; // convar, 0 = update on frame, 1 = update on timer
new c_ghost_update; // convar, 0 = update on frame, 1 = update on timer

//-------------------------------------------------------------------------------------------------
#define AFLAG2 ADMFLAG_RCON
#define AFLAG ADMFLAG_SLAY
#define AFLAGI Admin_Slay
#define SCALE "20.0"
#define HEIGHT 0.0
#define CROSSHAIR_SCALE "2.0"

//-------------------------------------------------------------------------------------------------
#define BOMB_FUSE 1.5

//-------------------------------------------------------------------------------------------------
enum {
	ZAP_HURT,
	ZAP_HEAL,
	ZAP_HOSTIE,
	ZAP_CHICKEN,
	ZAP_EXPLODE,
	ZAP_GRAB,
	ZAP_FIRE
};

//-------------------------------------------------------------------------------------------------
enum {
	LASER_LASER,
	LASER_INFERNO
};

new p_laserbeam;
//new p_smoke;

//new ghost_bans[MAXPLAYERS+1];

//new Handle:sqldb = INVALID_HANDLE; /////use cookies instead

new Handle:ban_cookie;

new Float:donator_zone[2][3];

new Handle:allowcmd_forward;
new Handle:onuse_forward;

new GAME;

enum {
	GAME_CSS,
	GAME_CSGO,
	GAME_TF2,
	GAME_OTHER
};

//----------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

/*
InitSQL() {
	decl String:error[256];
	sqldb = SQLite_UseDatabase( "sourcemod-local", error, sizeof(error) );
	if( sqldb == INVALID_HANDLE ) {
		SetFailState( "SQL ERROR: %s", error );
	}
}

BuildSQLTable() {
	
	SQL_LockDatabase( sqldb );
	SQL_FastQuery( sqldb, "VACUUM" );  

	// create a new table
	SQL_FastQuery( sqldb, "DROP TABLE ghost_bans" );
	SQL_FastQuery( sqldb, "CREATE TABLE ghost_bans (steamid TEXT PRIMARY KEY);" );

	SQL_UnlockDatabase( perks_sqldb );
}*/

//-------------------------------------------------------------------------------------------------
GetGameIndex() {
	decl String:buffer[64];
	GetGameFolderName( buffer, sizeof buffer );
	
	if( StrEqual( buffer, "csgo", false ) ) {
		GAME = GAME_CSGO;
	} else if( StrEqual( buffer, "css", false ) ) {
		GAME = GAME_CSS;
		
	} else if( StrEqual( buffer, "tf2", false ) || StrEqual( buffer, "tf", false ) ) {
		GAME = GAME_TF2;
		
	} else {
		GAME = GAME_OTHER;
	}
	
	// game related initialization...
	if( GAME == GAME_CSS || GAME == GAME_TF2 ) {
		
	} else if( GAME == GAME_CSGO ) {
		
	} else {
		///????
	}
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == sm_ghost_update ) {
		c_ghost_update = GetConVarInt( sm_ghost_update );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");

	GetGameIndex();

	allowcmd_forward = CreateGlobalForward( "Ghosting_OnAllowCmd", ET_Event, Param_Cell );
	onuse_forward = CreateGlobalForward( "Ghosting_OnUse", ET_Event, Param_Cell, Param_Cell );

	sm_ghost_update = CreateConVar( "sm_ghost_update", "1", "ghosting update rate, 0=onframe,1=ontimer" );
	HookConVarChange( sm_ghost_update, OnConVarChanged );
	c_ghost_update = GetConVarInt( sm_ghost_update );

	//InitSQL();
	//BuildSQLTable();
	ban_cookie = RegClientCookie( "ghosting_bans", "Ghosting Bans", CookieAccess_Private );

	mp_maxmoney = FindConVar( "mp_maxmoney" );

	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	RegAdminCmd( "sm_ghost", Command_ghost, AFLAG );
	RegAdminCmd( "sm_gzap", Command_zap, AFLAG );
	RegAdminCmd( "sm_gheal", Command_heal, AFLAG );
	RegAdminCmd( "sm_ghostie", Command_hostie, AFLAG );
	RegAdminCmd( "sm_gchicken", Command_chicken, AFLAG );
	RegAdminCmd( "sm_gsquawk", Command_squawk, AFLAG );
	RegAdminCmd( "sm_gexplode", Command_explode, AFLAG );
	
	RegAdminCmd( "sm_gsay", Command_gsay, AFLAG );
	RegAdminCmd( "sm_gpsay", Command_gpsay, AFLAG );

	RegAdminCmd( "sm_ggrab", Command_ggrab, AFLAG );
	RegAdminCmd( "sm_gspawn", Command_gspawn, AFLAG2 );

	RegAdminCmd( "+sm_ginferno", Command_ginferno_start, AFLAG );
	RegAdminCmd( "+sm_glaser", Command_glaser_start, AFLAG );
	RegAdminCmd( "-sm_ginferno", Command_ginferno_stop, AFLAG );
	RegAdminCmd( "-sm_glaser", Command_glaser_stop, AFLAG );

	RegAdminCmd( "sm_gbomb", Command_gbomb, AFLAG );
	RegAdminCmd( "sm_gskull", Command_gskull, AFLAG );

	RegServerCmd( "sm_gban", Command_gban );
	RegServerCmd( "sm_gunban", Command_gunban );

	//RegAdminCmd( "sm_gpossess", Command_gpossess, AFLAG );
	RegAdminCmd( "+sm_gforcefire", Command_pgshoot, AFLAG );
	RegAdminCmd( "-sm_gforcefire", Command_mgshoot, AFLAG );

	RegAdminCmd( "sm_gcash", Command_gcash, AFLAG );

	RegAdminCmd( "sm_gprop", Command_gprop, AFLAG );
	RegAdminCmd( "sm_gproplist", Command_gproplist, AFLAG );
	
	RegAdminCmd( "sm_gfire", Command_gfire, AFLAG );

	HookEvent( "player_use", Event_PlayerUse );

	if( GAME == GAME_TF2 ) {
		AddCommandListener( Command_taunt, "+taunt" );
	}

	HookExistingClients();

	CreateTimer( 0.1, GhostUpdateTimer, _, TIMER_REPEAT );
}

HookClient( client ) {
	SDKHook( client, SDKHook_WeaponCanUse, OnWeaponCanUse );
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {

	HookClient(client);

}

HookExistingClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			HookClient(i);
		}
	}
}

LoadConfig() {
	decl String:file[256];
	BuildPath( Path_SM, file, sizeof(file), "configs/%s", "ghosting.txt" );

	new Handle:kv = CreateKeyValues( "Ghosting" );

	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );

	if( !FileExists(file) ) {
		CloseHandle(kv);
		return;
	}

	if( !FileToKeyValues( kv, file ) ) {
		CloseHandle(kv);
		return;
	}

	if( !KvJumpToKey( kv, map ) ) {
		// no options for map
		CloseHandle(kv);
		return;
	}

	if( KvJumpToKey( kv, "DonatorZone" ) ) {
		KvGetVector( kv, "a", donator_zone[0] );
		KvGetVector( kv, "b", donator_zone[1] );
		KvGoBack( kv );
	}
	
	CloseHandle(kv);
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {

	for( new i = 0; i < sizeof(donator_zone); i++ ) {
		for( new j = 0; j < 3; j++ ) {
			donator_zone[i][j] = 0.0;
		}
	}

	LoadConfig();

	
	if( GAME == GAME_CSGO ) {
		for( new i = 0; i < sizeof( downloads_csgo ); i++ )
			AddFileToDownloadsTable( downloads_csgo[i] );
	} else if( GAME == GAME_TF2 ) {
		for( new i = 0; i < sizeof( downloads_tf2 ); i++ )
			AddFileToDownloadsTable( downloads_tf2[i] );
	}
	
	for( new i = 0; i < sizeof( precache_textures ); i++ ) {
		PrecacheModel( precache_textures[i] );
	}
	p_laserbeam = PrecacheModel( LASER_TEXTURE );
	//p_smoke = PrecacheModel( "materials/sprite/gunsmoke.vmt" );
	PrecacheModel( "models/gibs/hgibs.mdl" );

	if( GAME == GAME_CSGO ) {
		PrecacheModel( "models/props/cs_assault/money.mdl" );
	}

	/*
	for( new i = 0; i < sizeof( prop_models ); i++ ) {
		PrecacheModel( prop_models[i] );
	}*/
	
	PrecacheSound( SOUND_ZAP );
	PrecacheSound( SOUND_HEAL );
	PrecacheSound( SOUND_TEDDY );
	PrecacheSound( SOUND_LASER );
	PrecacheSound( SOUND_FIRE );

	PrecacheSound( "weapons/hegrenade/explode3.wav" );

	for( new i = 0; i < 64; i++ ) {
		ghost_active[i] = false;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		ghost_active[i] = false;
		ghost_sprites[i] = 0;
		ghost_sprites_x[i] = 0;
		grab_active[i] = false;
		laser_active[i] = false;
		laser_entity[i] = 0;
		//ghost_possession[i] = 0;
		//being_possessed_by[i] = 0;
		ghost_forcefire[i] = false;
	}
	total_grabs_active = 0;
	round_counter++;
}

bool:CheckDonatorZone( client ) {
	decl Float:pos[3];
	GetClientEyePosition( client, pos );
	for( new i = 0; i < 3; i++ ) {
		if( pos[i] < donator_zone[0][i] || pos[i] > donator_zone[1][i] ) return false;
	}
	return true;
}

TryGhost( client, bool:admincmd ) {
	if( !ghost_active[client] ) {
		if( AreClientCookiesCached(client) ) {
			decl String:cookie[11];
			GetClientCookie( client, ban_cookie, cookie, sizeof(cookie) );
			new val = StringToInt( cookie );
			if( val != 0 ) {
				PrintToChat( client, "You are banned from ghosting!" );
				return;
			}
		}

		new donatormode;

		if(!admincmd) {

			new bool:isallowed;
			new AdminId:adminid = GetUserAdmin(client);
			if( adminid != INVALID_ADMIN_ID ) {
				if( GetAdminFlag(adminid,AFLAGI) ) {
					isallowed = true;
				}
			}

			if(!isallowed) {
#if defined USE_DONATIONS
				if( Donations_GetClientLevel(client) != 0 ) {
					isallowed = true;
					donatormode = 1;
				}
#endif
			}
			
			if( !isallowed ) {
				return;
			}
		}

		if( donatormode && !ghost_active[client] ) {
			ghost_donatormode[client] = true;
			if( !CheckDonatorZone( client ) ) {
				PrintToChat( client, "You may only ghost in the Haunted Zone." );
				return;
			}
			
		} else {
			ghost_donatormode[client] = false;
		}

		if( StartGhost(client) ) {
			
			PrintToChat( client, "You are now ghosting!" );
		} else {
			PrintToChat( client, "You can't ghost right now." );
		}

		LogMessage( "%N used ghost", client );
	} else {
		if( !ghost_fade[client] ) {
			ghost_fade[client] = true;
	//		StopGhost(client);
			PrintToChat( client, "You have stopped ghosting." );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ghost( client, args ) {
	TryGhost(client,true);
	 
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnSpriteKilled( const String:output[], caller, activator, Float:delay ) {
	new client = GetEntPropEnt( caller, Prop_Send, "m_hOwnerEntity" );
	ghost_sprites[client] = 0;
	ghost_active[client] = false;
}

public Action:GhostUpdateTimer( Handle:timer ) {
	if( ghosts_active == 0 ) return Plugin_Continue;
	if( c_ghost_update != 1 ) return Plugin_Continue;
	UpdateAllGhosts();
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public OnGameFrame() {
	if( ghosts_active == 0 ) return;
	if( c_ghost_update != 0 ) return;

	UpdateAllGhosts();
}

//----------------------------------------------------------------------------------------------------------------------
UpdateAllGhosts() {
	new counter = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( UpdateGhost( i ) ) counter++;
	}
	ghosts_active = counter;
}

//----------------------------------------------------------------------------------------------------------------------
bool:UpdateGhost( client ) {
	if( !IsValidClient(client) ) {
		StopGhost(client);
		//ghost_timers[client] = INVALID_HANDLE;
		return false;
	}

	if( !ghost_active[client] ) {
		//ghost_timers[client] = INVALID_HANDLE;
		return false;
	}

	if( ghost_donatormode[client] && !CheckDonatorZone(client) ) {
		PrintToChat( client, "You have left the Haunted Zone." );
		StopGhost( client );
		//ghost_timers[client] = INVALID_HANDLE;
		return false;
	}
	
	//ghost_hover[client] += 0.1;
	//if( ghost_hover[client] > (3.15*2.0) ) ghost_hover[client] -= (3.15*2.0);
	TeleportSprite( client );
	if( laser_active[client] ) {
		
	}

	if( !ghost_fade[client] ) {
		if( ghost_alpha[client] < 128 ) {
			ghost_alpha[client] += 20;
			if( ghost_alpha[client] > 128 ) ghost_alpha[client] = 128;
			SetEntityRenderColor( ghost_sprites[client], 128,128,128, ghost_alpha[client] );
			 
			//DispatchKeyValue( ghost_sprites[client], "renderamt", "255" );
		}
	} else {
		ghost_alpha[client] -= 20;
		if( ghost_alpha[client] <= 0 ) {
			ghost_alpha[client] = 128;
			StopGhost(client);
			//ghost_timers[client] = INVALID_HANDLE;
			return false;
		} 

		SetEntityRenderColor( ghost_sprites[client], 128,128,128, ghost_alpha[client] );
		 
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:IsGrabValid(client) {
	new ge = grabbed_entity[client];
	if( !IsValidEntity( ge ) ) {
		return false;
	}

	if( ge > 0 && ge <= MaxClients ) {
		if( !IsValidClient(ge) ) {
			return false;
		} else if( !IsPlayerAlive(ge) ) {
			return false;
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
TeleportGrabbed( client, const Float:vec[3] ) { 
	new ge = grabbed_entity[client];
	if( !IsGrabValid(client) ) {
		grab_active[client] = false;
		return;
	}
	TeleportEntity( ge, vec, NULL_VECTOR, NULL_VECTOR );
	
}

//----------------------------------------------------------------------------------------------------------------------
SpawnInferno( const Float:vec[3] ) {
	new ent = CreateEntityByName( "inferno" );

	// TODO

	TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR );
	SetEntProp( ent, Prop_Send, "m_fireCount", 6 );		//???
	SetEntProp( ent, Prop_Send, "m_flSimulationTime", 128 );	//???
 
	DispatchSpawn(ent);
}

//----------------------------------------------------------------------------------------------------------------------
TeleportLaser( client, const Float:vec[3] ) {
	new Float:start[3];
	new Float:angles[3];

	new Float:end[3];
	
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );
/* ***********************
	if( laser_type[client] == LASER_LASER ) {
		new Float:norm[3];
		GetAngleVectors( angles, norm, NULL_VECTOR, NULL_VECTOR );		
		for( new i = 0; i < 3; i++ ) {
			end[i] = start[i] + norm[i] * 500.0;
		}
	
	} else {

*********************** */

	TR_TraceRayFilter( start, angles, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All, client );
	
	if( !TR_DidHit() ) return;

	// create beam
	TR_GetEndPosition( end );

	
	SetEntPropVector( laser_entity[client], Prop_Data, "m_vecEndPos", end );
	TeleportEntity( laser_entity[client], vec, NULL_VECTOR, NULL_VECTOR );

	if( laser_type[client] == LASER_INFERNO ) {
		if( laser_counter[client] == 0 ) {
			// spawn inferno
			SpawnInferno( end );
		}
		laser_counter[client]++;
		if( laser_counter[client] >= 10 ) laser_counter[client] = 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
TeleportSprite( client ) {
	new Float:pos[3];
	new Float:ang[3];
	new Float:norm[3];

	GetClientEyePosition( client, pos );

	new Float:xhair[3];

	GetClientEyeAngles( client, ang );
	GetAngleVectors( ang, norm, NULL_VECTOR, NULL_VECTOR );

	new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
	if( specmode == SPECMODE_FIRSTPERSON || specmode == SPECMODE_3RDPERSON ) {
		new target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
		if( IsValidClient( target ) ) {
			GetClientEyePosition( target, pos );
			pos[2] += 16.0;

		}
	}

	for( new i = 0; i < 3; i++ )
		xhair[i] = pos[i] + norm[i] * 15.0;
	
	
	
	pos[2] += Sine(GetGameTime()+ghost_hover[client]) * 5.0;
	TeleportEntity( ghost_sprites[client], pos, NULL_VECTOR, NULL_VECTOR );
	
	{
		new Action:result;
		Call_StartForward(allowcmd_forward);
		Call_PushCell( client );
		Call_Finish(_:result);
		
		if( result == Plugin_Continue ) {
			show_crosshair[client] = true;
			TeleportEntity( ghost_sprites_x[client], xhair, NULL_VECTOR, NULL_VECTOR );
		} else {
			show_crosshair[client] = false;
		}
	}
///	pos[0] = 0.0;
//	pos[1] = 0.0;
//	pos[2] = HEIGHT;

	if( grab_active[client] ) {
		TeleportGrabbed(client,pos);
	}

	if( laser_active[client] ) {
		TeleportLaser( client,pos );
	}
}

//----------------------------------------------------------------------------------------------------------------------
CreateGhostSprite( client ) {
	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	SetEntityModel( ent, GHOST_TEXTURE );
	DispatchKeyValue( ent, "rendercolor", "128 128 128" );
	DispatchKeyValue( ent, "rendermode", "2" );
	DispatchKeyValue( ent, "renderamt", "128" );
	DispatchKeyValue( ent, "scale", SCALE );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	
	HookSingleEntityOutput( ent, "OnKilled", OnSpriteKilled );

	return ent;
}

public Action:Hook_SetTransmit_XHair( entity, client ) {
	if( client == GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" ) ) {
		if( show_crosshair[client] ) return Plugin_Continue;
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
CreateCrosshair( client ) {
	new ent = CreateEntityByName( "env_sprite_oriented" );
	
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	SetEntityModel( ent, CROSSHAIR_TEXTURE );
	DispatchKeyValue( ent, "rendercolor", "128 128 128" );
	DispatchKeyValue( ent, "rendermode", "2" );
	DispatchKeyValue( ent, "renderamt", "255" );
	DispatchKeyValue( ent, "scale", CROSSHAIR_SCALE );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	
	SetEdictFlags( ent, GetEdictFlags(ent)&(~FL_EDICT_ALWAYS) );
	SDKHook( ent, SDKHook_SetTransmit, Hook_SetTransmit_XHair );
	
	return ent;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected(client) {
	ghost_active[client] = false;
}

//----------------------------------------------------------------------------------------------------------------------
OverrideGrab( ent ) {
	// client = client taking item
	// ent = item to check
	
	// this function stops another ghost from holding an item
	// when another ghost picks it up
	for( new i = 1; i <= MaxClients; i++ ) {
		if( grab_active[i] ) {
			if( grabbed_entity[i] == ent ) {
				DropItem(i);
				return;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
GrabItem( client, ent ) {
	if( !ghost_active[client] ) return;
	if( grab_active[client] ) return;

	OverrideGrab( ent );
	
	grab_active[client] = true;
	grabbed_entity[client] = ent;
	grabbed_entity_movetype[client] = GetEntityMoveType( ent );
	SetEntityMoveType( ent, MOVETYPE_NONE );
	total_grabs_active++;
}

//----------------------------------------------------------------------------------------------------------------------
DropItem( client ) {
	if( !grab_active[client] ) return;
	new Float:bump[3] = {1.0,1.0,1.0};
	if( IsGrabValid(client) ) {
		SetEntityMoveType( grabbed_entity[client], grabbed_entity_movetype[client] );
		TeleportEntity( grabbed_entity[client], NULL_VECTOR, NULL_VECTOR, bump );	
	}
	grab_active[client] = false;
	total_grabs_active--;
}

//----------------------------------------------------------------------------------------------------------------------
bool:StartGhost( client ) {
	if( ghost_active[client] ) return false;
	if( IsPlayerAlive(client) ) return false;
	ghost_sprites[client] = CreateGhostSprite(client);
	ghost_sprites_x[client] = CreateCrosshair(client);
	ghost_active[client] = true;
	ghost_fade[client] = false;
	ghost_alpha[client] = 0;
	ghost_hover[client] = GetRandomFloat( 0.0, 6.3 );
	//if( !ghost_timers[client] ) {
	//	ghost_timers[client] = CreateTimer( 0.033, GhostTimer, client, TIMER_REPEAT );
	//}
	ghosts_active++;
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:StopGhost( client ) {
	if( !ghost_active[client] ) return false;
	DropItem(client);
	StopLaser(client);
	AcceptEntityInput( ghost_sprites[client], "kill" );
	AcceptEntityInput( ghost_sprites_x[client], "kill" );
	ghost_sprites[client] = 0;
	ghost_sprites_x[client] = 0;
	ghost_active[client] = false;
	return true;
}

SpawnFire( const Float:vec[3] ) {
	new ent = CreateEntityByName( "env_fire" );
	if( ent == -1 ) return;
	
	decl String:arg[64];
	if( g_fire_dmgscale >= 0.0 ) {
		Format( arg, sizeof(arg), "%f", g_fire_dmgscale );
		DispatchKeyValue(ent, "damagescale", arg );
	}
	
	if( g_fire_size >= 0.0 ) {
		Format( arg, sizeof(arg), "%f", g_fire_size );
		DispatchKeyValue(ent, "firesize", arg );
	}
	
	//DispatchKeyValue(ent, "firetype", "1" ); // test
	DispatchSpawn(ent);
	TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR );
	AcceptEntityInput( ent, "StartFire" );
	
	EmitSoundToAll( SOUND_FIRE, ent );
}

//----------------------------------------------------------------------------------------------------------------------
// returns entity hit
// -1 for no collision
// 0 for world collision
DoZap( client, Float:range, type, arg1=0 ) {
	new Float:start[3];
	new Float:angles[3];
	new Float:norm[3];
	new Float:end[3];
	
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );
	GetAngleVectors( angles, norm, NULL_VECTOR, NULL_VECTOR );
	for( new i = 0; i < 3; i++ )
		end[i] = start[i] + norm[i] * range;
	TR_TraceRayFilter( start, end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter, client );
	new ent = -1;
	
	if( TR_DidHit() ) {
		// create beam
		TR_GetEndPosition( end );
		
		ent = TR_GetEntityIndex();
		if( ent == -1 ) {
			ent = 0;
		}
	}
	
	new color[4];
	
	if( type == ZAP_HURT ) {
		color = {87/2,255/2,253/2,255/2};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 10.0, 10.0, 10, 20.0, color, 10 );
		TE_SendToAll();

		new Float:force[3];// = {5000.0,5000.0,5000.0};
		for( new i = 0; i < 3; i++ ) {
			force[i] = norm[i] * 1000.0;
		}
		force[2] = 500.0;

		if( ent > 0 ) {
			TeleportEntity(ent,NULL_VECTOR,NULL_VECTOR,force);
			if( IsValidClient(ent) ) {
				SetEntProp(ent, Prop_Send, "m_LastHitGroup", 3 );
				
			}
			//SetEntPropVector( ent, Prop_Send, "m_vecForce", force );
			//SetEntProp( ent, Prop_Send, "m_nForceBone", 2 );
			SDKHooks_TakeDamage( ent, 0, 0, 25.0, DMG_DROWN, _, force, start );
		}
		EmitSoundToAll( SOUND_ZAP, ghost_sprites[client] );

	} else if( type == ZAP_HEAL ) {
		color = {170/2,251/2,108/2,255/2};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 20.0, 20.0, 5, 1.0, color, 10 );
		TE_SendToAll();
		EmitSoundToAll( SOUND_HEAL, ghost_sprites[client] );
		if( IsValidClient(ent) ) {
			
			new hp = GetClientHealth(ent);
			hp += 10;
			if( hp > 100 ) hp = 100;
			SetEntityHealth(ent,hp);

		}

	} else if( type == ZAP_HOSTIE ) {
		color = {128,128,128,128};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 1.0, 1.0, 10, 10.0, color, 10 );
		TE_SendToAll();

		if( ent == 0 ) {
			// CREATE HOSTIE
			new HOSTIE = CreateEntityByName( "hostage_entity" );

			new Float:hangles[3];
			hangles[0] = 0.0;
			hangles[1] = GetRandomFloat( 0.0, 360.0 );
			hangles[2] = 0.0;
			TeleportEntity( HOSTIE, end, hangles, NULL_VECTOR );
			DispatchSpawn(HOSTIE);
			
			
		}
		EmitSoundToAll( SOUND_ZAP, ghost_sprites[client] );
	} else if( type == ZAP_CHICKEN ) {
		color = {128,128,0,128};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 1.0, 1.0, 10, 10.0, color, 10 );
		TE_SendToAll();

		if( ent == 0 ) {
			// CREATE HOSTIE
			new HOSTIE = CreateEntityByName( "chicken" );

			new Float:hangles[3];
			hangles[0] = 0.0;
			hangles[1] = GetRandomFloat( 0.0, 360.0 );
			hangles[2] = 0.0;
			TeleportEntity( HOSTIE, end, hangles, NULL_VECTOR );
			DispatchSpawn(HOSTIE);
			
			
		}
		EmitSoundToAll( SOUND_ZAP, ghost_sprites[client] );
	} else if( type == ZAP_EXPLODE ) {
		color = {128,0,0,128};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 0.5, 0.5, 10, 25.0, color, 10 );
		TE_SendToAll();

		EmitSoundToAll( SOUND_ZAP, ghost_sprites[client] );

		CreateExplosion( end, arg1 );
		
	} else if( type == ZAP_GRAB ) {
		if( ent > 0 ) {
			color = {128,128,128,128};
			TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 2.5, 2.5, 10, 5.0, color, 10 );
			TE_SendToAll();

			EmitSoundToAll( SOUND_GRAB, ghost_sprites[client] );

			GrabItem( client, ent );
		}
		
	} else if( type == ZAP_FIRE ) {
		
		color = {128,0,0,128};
		TE_SetupBeamPoints( start, end, p_laserbeam, 0, 0, 30, 0.25, 2.5, 2.5, 10, 5.0, color, 10 );
		TE_SendToAll();

		SpawnFire( end );
	}
	
	return ent;
	
}

//----------------------------------------------------------------------------------------------------------------------
CreateExplosion( Float:vec[3], damage ) {
	new ent = CreateEntityByName("env_explosion");	 
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",300); 
	
	EmitAmbientSound( ")weapons/hegrenade/explode3.wav", vec, _, SNDLEVEL_GUNFIRE  );

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}

//----------------------------------------------------------------------------------------------------------------------
CreateLaserEntity( type ) {
	if( type == LASER_LASER ) {
		new ent = CreateEntityByName( "env_beam" );
		SetEntityModel( ent, LASER_TEXTURE );
		DispatchKeyValue( ent, "rendercolor", LASER_LASER_COLOR );
		DispatchKeyValue( ent, "renderamt", "255" );
		DispatchKeyValue( ent, "life", "0" );
		DispatchKeyValue( ent, "TouchType", "0" );
		DispatchKeyValue( ent, "damage", "100" );
		DispatchKeyValue( ent, "ClipStyle", "0" );
		DispatchSpawn( ent );
		SetEntPropFloat( ent, Prop_Data, "m_fWidth", LASER_LASER_WIDTH );
		SetEntPropFloat( ent, Prop_Data, "m_fEndWidth", LASER_LASER_WIDTH );
		ActivateEntity( ent );
		AcceptEntityInput( ent, "TurnOn" );
		
		return ent;
	} else if( type == LASER_INFERNO ) {
		new ent = CreateEntityByName( "env_beam" );

		SetEntityModel( ent, LASER_TEXTURE );
		DispatchKeyValue( ent, "rendercolor", INFERNO_LASER_COLOR );
		DispatchKeyValue( ent, "renderamt", "255" );
		//DispatchKeyValue( ent, "decalname", "Bigshot" );
		DispatchKeyValue( ent, "life", "0" );
		DispatchKeyValue( ent, "TouchType", "0" );
		DispatchSpawn( ent );
		SetEntPropFloat( ent, Prop_Data, "m_fWidth", INFERNO_LASER_WIDTH );
		SetEntPropFloat( ent, Prop_Data, "m_fEndWidth", INFERNO_LASER_WIDTH );
		SetEntPropFloat( ent, Prop_Send, "m_fAmplitude", 2.0 );
		ActivateEntity( ent );
		AcceptEntityInput( ent, "TurnOn" );
		return ent;
	} else {
		return -1;
	}
}

//----------------------------------------------------------------------------------------------------------------------
StartLaser( client, type ) {
	if( !ghost_active[client] ) return;
	if( laser_active[client] ) return;
	
	laser_active[client] = true;
	laser_type[client] = type;
	laser_entity[client] = CreateLaserEntity( type );
	laser_counter[client] = 0;
	
	// emit sound
	EmitSoundToAll( SOUND_LASER, ghost_sprites[client] );
}

//----------------------------------------------------------------------------------------------------------------------
StopLaser( client ) {
	if( !laser_active[client] ) return;
	laser_active[client] = false;
	if( laser_entity[client] > 0 ) {
		AcceptEntityInput( laser_entity[client], "Kill" );
		laser_entity[client] = 0;
	}
	// stop sound
	if( ghost_sprites[client] > 0 ) {
		StopSound( ghost_sprites[client], SNDCHAN_AUTO, SOUND_LASER );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter( entity, contentsMask, any:data ) {
	if( entity != data ) {
		return true;
	}
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask, any:data ) {

	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_zap( client, args ) {
	if( ghost_active[client] ) {	
		new ent = DoZap( client, 5000.0, ZAP_HURT );
		if( ent > 0 ) {
			// hurt entity
		}
	}
//	LogMessage( "%N used gzap", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_heal( client, args ) {
	if( ghost_active[client] ) {
		new ent = DoZap( client, 5000.0, ZAP_HEAL );
		if( ent > 0 ) {
			// heal entity
		}
	}
//	LogMessage( "%N used gheal", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_hostie( client, args ) {
	if( ghost_active[client] ) {
		DoZap( client, 5000.0, ZAP_HOSTIE );
	}
//	LogMessage( "%N used ghostie", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_explode( client, args ) {
	if( ghost_active[client] ) {
		new arg1 = 50;
		if( args > 0 ) {
			decl String:text[16];
			GetCmdArg( 1, text, sizeof(text) );
			arg1 = StringToInt( text );
		}
		DoZap( client, 5000.0, ZAP_EXPLODE, arg1 );
	}
//	LogMessage( "%N used gexplode", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_chicken( client, args ) {
	if( ghost_active[client] ) {
		DoZap( client, 5000.0, ZAP_CHICKEN );
	}
//	LogMessage( "%N spawned chicken", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_squawk( client, args ) {
	if( ghost_active[client] ) {
		EmitSoundToAll( SOUND_TEDDY, ghost_sprites[client] );
	}
//	LogMessage( "%N used squawk", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gsay( client, args ) {
//	if( ghost_active[client] ) {
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_gsay <message>");
		return Plugin_Handled;	
	}
	if( ghost_active[client] ) {
		EmitSoundToAll( SOUND_TEDDY, ghost_sprites[client] );
	}
	decl String:text[256];
	GetCmdArgString( text, sizeof(text) );
	PrintToChatAll( "Boo says: %s", text );
//	}
//	LogMessage( "%N used gsay", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gpsay( client, args ) {
	

	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_gpsay <target> <message>");
		return Plugin_Handled;	
	}	
	if( ghost_active[client] ) {
		EmitSoundToAll( SOUND_TEDDY, ghost_sprites[client] );
	}
	decl String:text[192], String:arg[64], String:message[192];
	GetCmdArgString(text, sizeof(text));

	new len = BreakString(text, arg, sizeof(arg));
	BreakString(text[len], message, sizeof(message));

	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	target_count = ProcessTargetString(
		arg,
		client, 
		target_list, 
		MAXPLAYERS, 
		COMMAND_FILTER_CONNECTED,
		target_name,
		sizeof(target_name),
		tn_is_ml);

	for( new i = 0; i < target_count; i++ ) {
		if( target_list[i] != client ) {
			PrintToChat( target_list[i], "Boo whispers: %s", message );
		}
	}
	PrintToChat( client, "(Boo) -> %s: %s", arg, message );


//	LogMessage( "%N used gpsay", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ggrab( client, args ) {
	if( ghost_active[client] ) {
		if( !grab_active[client] ) {
			DoZap( client, 5000.0, ZAP_GRAB );
		} else {
			DropItem(client);
		}
	}
//	LogMessage( "%N used ggrab", client );
	return Plugin_Handled;	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gspawn( client, args ) {
	if( ghost_active[client] ) {
		decl String:name[64];
		GetCmdArg( 1, name, sizeof(name) );
		new ent = CreateEntityByName( name );
		if( ent != -1 ) {
			new Float:vec[3];
			GetClientEyePosition( client, vec );
			TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR );
			DispatchSpawn( ent );
		}
	}
//	LogMessage( "%N used gspawn", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ginferno_start( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	ReplyToCommand( client, "This command isn't completed." );
	return Plugin_Handled;
//	StartLaser( client, LASER_INFERNO );
//	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ginferno_stop( client, args ) {
//	if( !ghost_active[client] ) return Plugin_Handled;
//	StopLaser( client );
//	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_glaser_start( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	StartLaser( client, LASER_LASER );
//	LogMessage( "%N used glaser", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_glaser_stop( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	StopLaser( client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
SpawnSmallSmoke( const Float:vec[3] ) {
/*
	TE_Start( "Sprite" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteNum( "m_nModelIndex", p_smoke );
	TE_WriteFloat( "m_fScale", 10.0 );
	//TE_WriteNum( "m_nFrameRate", 1 );
	TE_SendToAll();
*/
//	TE_SetupSmoke( vec, p_smoke, 10.0, 1 );
	new Float:dir[3];
//	new color[4] = {128, 0, 0 ,255};
	TE_SetupDust( vec, dir, 10.0, 10.0 );
//	TE_SetupBloodSprite( vec, dir, color, 10, p_smoke, p_smoke );
	TE_SendToAll();
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SkullTimer( Handle:timer, any:data ) {
	ResetPack( data );
	new counter = ReadPackCell(data);
	new rc = ReadPackCell(data);
	if( rc != round_counter ) return Plugin_Stop;
	new ent = ReadPackCell(data);
	ResetPack(data);
	counter++;
	WritePackCell(data,counter);

	new Float:vec[3];
	GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );

	if( counter == 10 ) {
		AcceptEntityInput( ent, "Kill" );
	
		CreateExplosion( vec, 400 );
		return Plugin_Stop;
	} else {
		SpawnSmallSmoke( vec );
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SkullTouch(entity, other) {
	PrintToServer( "BOINK!" );
}

SpawnBomb( client, bool:explode=true ) {
	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "1.0");
	DispatchKeyValue(ent, "model", "models/gibs/hgibs.mdl");
	DispatchSpawn(ent);
	//SetEntProp( ent, Prop_Send, "m_CollisionGroup", 6); // set non-collidable
 
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);   
	new Float:ang[3];
	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );

	new Float:vec[3];
	GetClientEyePosition(client,vec);
	new Float:vel[3];
	new Float:eyeang[3];
	new Float:eyenorm[3];
	new Float:eyenorm_up[3];

	GetClientEyeAngles( client, eyeang );
	GetAngleVectors( eyeang, eyenorm, NULL_VECTOR, eyenorm_up );
	
	for( new i = 0; i < 3; i++ )
		vel[i] = eyenorm[i]*1000.0 + eyenorm_up[i] *1000.0 * 0.2;

	TeleportEntity( ent, vec, ang, vel);

	//SDKHook( ent, SDKHook_StartTouch, SkullTouch );

	if( explode ) {
		new Handle:data;
		CreateDataTimer( BOMB_FUSE / 10.0, SkullTimer, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT );
		WritePackCell( data, 0 );
		WritePackCell( data, round_counter );
		WritePackCell( data, ent );


		EmitSoundToAll( SOUND_ZAP, ghost_sprites[client] );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gbomb( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	SpawnBomb(client);
//	LogMessage( "%N used gbomb", client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gskull( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	SpawnBomb(client, false);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnWeaponCanUse( client, weapon ) {
	// called whenever a client wants to pick up a weapon
	// we use this to make the ghost drop a weapon item before the client
	// takes it to avoid strange behavior

	// don't do anything if there isnt anything floating
	if( total_grabs_active == 0 ) return Plugin_Continue;

	for( new i = 1; i <= MaxClients; i++ ) {
		if( grab_active[i] ) {
			if( grabbed_entity[i] == weapon ) {
				DropItem(i);
				break;
			}
		}
	}
	
	return Plugin_Continue;
}
/*
//----------------------------------------------------------------------------------------------------------------------
public SQL_DoNothing( Handle:owner, Handle:hndl, const String:error[], any:data ) {

}

//----------------------------------------------------------------------------------------------------------------------
public SQL_CachePlayer( Handle:owner, Handle:hndl, const String:error[], any:data ) {
}

//----------------------------------------------------------------------------------------------------------------------
CacheGhostBan( client ) {
	ghost_bans[i] = false;

	if( !IsClientInGame(client) ) return;
	decl String:sql_query[256];
	decl String:auth[64];
	GetClientAuthString( client, auth, sizeof(auth) );
	Format( sql_query, sizeof( sql_query ), "SELECT * FROM ghost_bans WHERE steamid='%s'", auth );
	SQL_TQuery( sqldb, SQL_CachePlayer, sql_query, client );
}

//----------------------------------------------------------------------------------------------------------------------
RecacheGhostBans() {
	for( new i = 1; i <= MaxClients; i++ ) {
		CacheGhostBan(i);
	}	
}
*/
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gban( args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof(arg) );
	new target = FindTarget( 0, arg, true, false );
	if( target == -1 ) return Plugin_Handled;
	SetClientCookie( target, ban_cookie, "1");
	ReplyToCommand( 0, "Banned %N from ghosting.", target );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_gunban( args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof(arg) );
	new target = FindTarget( 0, arg, true, false );
	if( target == -1 ) return Plugin_Handled;
	SetClientCookie( target, ban_cookie, "0");
	ReplyToCommand( 0, "Unbanned %N from ghosting.", target );
	return Plugin_Handled;
}
/*
public TakeMoneys(const String:output[], caller, activator, Float:delay) {
	//AcceptEntityInput( caller, "kill" );
	// test activator
	PrintToChatAll( "test, %d, %d", caller, activator );

	new max = 16000;
	if(mp_maxmoney != INVALID_HANDLE)
		max = GetConVarInt(mp_maxmoney);
	
//	new account = GetEntProp(client, Prop_Send, "m_iAccount");
//	account += CASH_MONEY;
	//if(account < max)
	//	SetEntProp(client, Prop_Send, "m_iAccount", account);
	//else
	//	SetEntProp(client, Prop_Send, "m_iAccount", max);
}*/

public Event_PlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if( client == 0 ) return;
	new ent = GetEventInt( event, "entity" );

	decl String:tname[64];
	GetEntPropString( ent, Prop_Data, "m_iName", tname, sizeof(tname) );
	if( StrEqual( tname, "CASHMONEY" ) ) {
		AcceptEntityInput( ent, "Kill" );
	
		new max = 16000;
		if(mp_maxmoney != INVALID_HANDLE)
			max = GetConVarInt(mp_maxmoney);
	
		new account = GetEntProp(client, Prop_Send, "m_iAccount");
		account += CASH_MONEY;
		if(account < max)
			SetEntProp(client, Prop_Send, "m_iAccount", account);
		else
			SetEntProp(client, Prop_Send, "m_iAccount", max);
	}
}

public Action:Command_gcash( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;

	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "1.0");
	DispatchKeyValue(ent, "model", "models/props/cs_assault/money.mdl"); // todo: cash model
	DispatchKeyValue( ent, "spawnflags", "256" );	// usable
	DispatchKeyValue( ent, "targetname", "CASHMONEY" );
	DispatchSpawn(ent);
	//SetEntProp( ent, Prop_Send, "m_CollisionGroup", 6); // set non-collidable
 
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);   
	new Float:ang[3];
	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );

	new Float:vec[3];
	GetClientEyePosition(client,vec);
	new Float:vel[3];
	new Float:eyeang[3];
	new Float:eyenorm[3];
	new Float:eyenorm_up[3];

	GetClientEyeAngles( client, eyeang );
	GetAngleVectors( eyeang, eyenorm, NULL_VECTOR, eyenorm_up );
	
	for( new i = 0; i < 3; i++ )
		vel[i] = eyenorm[i]*1000.0 + eyenorm_up[i] *1000.0 * 0.2;

	TeleportEntity( ent, vec, ang, vel);

	//HookSingleEntityOutput( ent, "OnPlayerUse", TakeMoneys, true );
	//SDKHook( ent, SDKHook_StartTouch, SkullTouch );
	return Plugin_Handled;
}

//======================================================================================================================
// POSSESSION
//

public Action:Command_pgshoot( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
	if( specmode == SPECMODE_FIRSTPERSON || specmode == SPECMODE_3RDPERSON ) {
		new target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
		if( IsValidClient( target ) ) {
			
			ghost_forcefire[target] = true;
		}
	}
	return Plugin_Handled;
}

public Action:Command_mgshoot( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;
	new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
	if( specmode == SPECMODE_FIRSTPERSON || specmode == SPECMODE_3RDPERSON ) {
		new target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
		if( IsValidClient( target ) ) {
			
			ghost_forcefire[target] = false;
		}
	}
	return Plugin_Handled;
}

bool:TryGhostButton( client ) {
	new Action:result;
	Call_StartForward(allowcmd_forward);
	Call_PushCell( client );
	Call_Finish(_:result);
	if( result == Plugin_Handled ) {
		return false;
	}

	if( !IsPlayerAlive(client) ) {
		TryGhost( client, false );
		return true;
	}
	return false;
}

public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	
	if( GAME == GAME_CSGO ) {
		if( impulse == 100 ) {
			TryGhostButton(client );
			return Plugin_Continue;
		}
	} else if( GAME == GAME_TF2 ) {
		if( ( (last_buttons[client] ^ buttons) & buttons) & IN_RELOAD ) {
			TryGhostButton(client);
		}
	}

	if( ghost_active[client] ) {
		if(ghost_fade[client] ) return Plugin_Continue;
		new Action:result;
		Call_StartForward(allowcmd_forward);
		Call_PushCell( client );
		Call_Finish(_:result);
		if( result == Plugin_Handled ) {
			return Plugin_Continue;
		}

		if( ( (last_buttons[client] ^ buttons) & buttons) & IN_USE ) {
			if( !IsPlayerAlive(client) && IsClientObserver(client) && GetEntProp( client, Prop_Send, "m_iObserverMode" ) == 6 ) {
				
				
				DoGhostUse( client );
			}
		}
		
	} else {

		if( ghost_forcefire[client] ) {
			buttons |= IN_ATTACK;

		}
		
	}
		
	last_buttons[client] = buttons;

	return Plugin_Continue;
}

public Action:Command_taunt( client, const String:command[], argc ) {
	TryGhostButton(client);
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter_Use( entity, contentsMask, any:client ) {
	
	if( entity <= MaxClients ) {
		return false;
	}
	if( grab_active[client] ) {
		if( grabbed_entity[client] == entity ) {
			return false;
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
DoGhostUse( client ) {
	decl Float:start[3];
	decl Float:angles[3];
	decl Float:end[3];
	decl Float:norm[3];
	new Float:range = 80.0;
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );
	GetAngleVectors( angles, norm, NULL_VECTOR, NULL_VECTOR );
	for( new i = 0; i < 3; i++ )
		end[i] = start[i] + norm[i] * range;
	TR_TraceRayFilter( start, end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_Use, client );

	new ent = 0;
	
	if( TR_DidHit() ) {
		
		ent = TR_GetEntityIndex();
		if( ent == -1 ) {
			ent = 0;
		}
	}

	if( ent ) {
		new Action:result;
		Call_StartForward(onuse_forward);
		Call_PushCell( client );
		Call_PushCell( ent );
		Call_Finish(_:result);
	}
	
}

/*
public Action:Command_gpossess( client, args ) {
	if( !ghost_active[client] ) return Plugin_Handled;

	if( ghost_possession[client] != 0 ) { 
		being_possessed_by[ghost_possession[client]] = 0;
		ghost_possession[client] = 0;
		return Plugin_Handled;
	}
	new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
	if( specmode == SPECMODE_FIRSTPERSON ) {
		new target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
		if( IsValidClient( target ) ) {
			
			ghost_possession[client] = target;
			being_possessed_by[target] = client;
		}
	} else {
		ReplyToCommand( client, "Must be spectating someone in first person" );
	}
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	client_buttons[client] = buttons;

	if( ghost_possession[client] ) {
		buttons = 0;
		return Plugin_Handled;
	}
	if( being_possessed_by[client] ) {
		buttons = client_buttons[being_possessed_by[client]];
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
*/

//======================================================================================================================
public Action:Command_gfire( client, args ) {

	g_fire_dmgscale = -1.0;
	g_fire_size = -1.0;
	if( ghost_active[client] ) {
	 
		decl String:text[16];
		if( args > 0 ) {
			GetCmdArg( 1, text, sizeof(text) );
			g_fire_size = StringToFloat( text );
			if( g_fire_size <= 0.0 ) g_fire_size = -1.0;
		}
		if( args > 1 ) {
			GetCmdArg( 2, text, sizeof(text) );
			g_fire_dmgscale = StringToFloat( text );
			if( g_fire_dmgscale <= 0.0 ) g_fire_dmgscale = -1.0;
		}
		DoZap( client, 5000.0, ZAP_FIRE, 0 );
	}
	
	return Plugin_Handled;
}


//-----------------------------------------------------------------------------------------------------------------------
public Action:Command_gprop( client, args ) {
	if( ghost_active[client] ) {
		ReplyToCommand( client, "This command isn't implemented yet." );
	}
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------------------------------------------------
public Action:Command_gproplist( client, args ) {
	if( ghost_active[client] ) {
		ReplyToCommand( client, "This command isn't implemented yet." );
	}
	return Plugin_Handled;
}
