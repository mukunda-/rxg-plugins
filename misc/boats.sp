


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <vphysics>
#include <piggybacking>
#include <cssdroppedammo>

#pragma unused AllowedGame
#pragma unused c_ammo_grenade_limit_flashbang
#include <cstrike_weapons>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "boats",
	author = "mukunda",
	description = "BOATS",
	version = "1.0.0",
	url = "www.mukunda.com"
};

#define GLOWMAT "materials/sprites/glow03.vmt"

new Float:client_vecs[MAXPLAYERS][3];
new rs_timer;
#define MAXENTS 2048

//new UserMsg:g_ShakeUserMsgId;

new cannonball_id;
new cannonball_owner[MAXENTS];

new cannonball_map[MAXENTS];

new hostage_carrier; 
new hostage_ent;

new bool:booty_ent[MAXENTS];
new player_has_booty[MAXPLAYERS+1];
//new booty_is_held[MAXENTS];

new bootydrop_ent;
new firstbooty;

new supercharged[2];

new ship_ents[MAXENTS]; // 0 = not a ship entity, 1 = ship1, 2 = ship2
new ship_parts[2];
new ship_damage[2];
new ship_bomb_hook[2];
new ship_alive[2];

new Handle:rxg_force_music;

new boatmap[MAXENTS]; // entity -> boat index
new boatcount;

new Float:boat_passenger_positions[5][3] = {
	{ -32.0,0.0,0.0},
	{ 48.0,15.0,0.0},
	{ 48.0,-15.0,0.0},
	{ 2.0,20.0,0.0},
	{ 2.0,-20.0,0.0}
	
};

#define MAXBOATS 8
#define BOATSEATS 5
new boat_ent[MAXBOATS];
new boat_seats[MAXBOATS][BOATSEATS];
new boat_passengers[MAXBOATS];

new player_riding_boat[MAXPLAYERS+1];
new player_boat_seat[MAXPLAYERS+1];

new Float:player_boat_time[MAXPLAYERS+1];

new bool:cannon_active[MAXENTS];
new Float:cannon_nextfire[MAXENTS];
new Float:cannon_pitch[MAXENTS];
new cannon_barrel[MAXENTS];

new player_using_cannon[MAXPLAYERS+1];

//new bool:player_hasnade[MAXPLAYERS+1];
new Float:player_nadetime[MAXPLAYERS+1];
new bool:entity_is_nadebox[MAXENTS];

new Float:player_alive_time[MAXPLAYERS+1];

new bool:endround;

new Float:c_respawn_time = 8.0;

new Float:c_cannon_cooldown = 2.00;
new c_cannonball_explosion = 100;
new Float:c_nadebox_cooldown = 1.0;
new Float:c_enter_boat_cooldown = 5.0;

new Float:c_boat_turnspeed = 2.0;
new Float:c_boat_speed = 2.0;
new Float:c_bootyboat_speed = 1.3;

new Float:c_booty_speed = 200.0;

new c_ship_detonate_ratio = 75;

new Float:c_cannon_speed = 9.0;
new Float:c_cannon_turnspeed = 3.0;
new Float:c_cannon_backblast = 300.0;
new Float:c_cannon_backblast_upward = 70.0;
new c_supercharge_multiplier = 4;
//new Float:c_cannon_massscale = 64.0;

new Handle:ammo_grenade_limit_default;
new Handle:ammo_grenade_limit_flashbang;
new Handle:ammo_grenade_limit_total;
new c_ammo_grenade_limit_default;
new c_ammo_grenade_limit_flashbang;
new c_ammo_grenade_limit_total;

new Handle:sv_alternateticks;

new String:music_list[][] = {
	"",
	"music/rxg/pirates_captain.mp3",
	"music/rxg/pirates_filler1.mp3",
	"music/rxg/pirates_filler2.mp3",
	"music/rxg/pirates_filler3.mp3",
	"music/rxg/pirates_filler4.mp3",
	"music/rxg/pirates_filler5.mp3",
	"music/rxg/pirates_main.mp3",
	"music/rxg/pirates_main2.mp3",
	"music/rxg/pirates_tense1.mp3",
	"music/rxg/pirates_tense2.mp3"
};

new Float:music_duration[] = {
	0.0,
	27.5,
	16.598,
	34.5,
	23.0,
	76.3,
	56.5,
	87.0,
	67.3,
	15.5,
	11.4
};

enum {
	MUSIC_NULL,
	MUSIC_CAPTAIN,
	MUSIC_FILLER1,
	MUSIC_FILLER2,
	MUSIC_FILLER3,
	MUSIC_FILLER4,
	MUSIC_FILLER5,
	MUSIC_MAIN1,
	MUSIC_MAIN2,
	MUSIC_TENSE1,
	MUSIC_TENSE2
};

new music_current;
new Float:music_volume;
new bool:music_fading;
new Float:music_start_time;
//new Handle:music_timer = INVALID_HANDLE;
new music_auto;
new music_next;
new Float:music_delay;

//----------------------------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldval[], const String:newval[] ) {
	if( convar == ammo_grenade_limit_default ) {
		c_ammo_grenade_limit_default = GetConVarInt( ammo_grenade_limit_default );
	} else if( convar == ammo_grenade_limit_flashbang ) {
		c_ammo_grenade_limit_flashbang = GetConVarInt( ammo_grenade_limit_flashbang );
	} else if( convar == ammo_grenade_limit_total ) {
		c_ammo_grenade_limit_total = GetConVarInt( ammo_grenade_limit_total );
	}
}

LoadConfig() {
	new Handle:kv = CreateKeyValues( "boats" );
	decl String:filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/boats.txt" );
	if( !FileExists( filepath ) ) {
		SetFailState( "boats.txt not found" );
		return;
	}
	if( !FileToKeyValues( kv, filepath ) ) {
		SetFailState( "Error loading config file." );
	}
	
	// DEFAULT VALUES LOCATED HERE!
	c_respawn_time = KvGetFloat( kv, "respawn_time", 8.0 );
	c_cannon_cooldown = KvGetFloat( kv, "cannon_cooldown", 2.0 );
	c_cannonball_explosion = KvGetNum( kv, "cannonball_explosion", 100 );
	c_nadebox_cooldown = KvGetFloat( kv, "nadebox_cooldown", 1.0 );
	c_enter_boat_cooldown = KvGetFloat( kv, "enter_boat_cooldown", 5.0 );

	c_boat_turnspeed = KvGetFloat( kv, "boat_turnspeed", 2.0 );
	c_boat_speed = KvGetFloat( kv, "boat_speed", 3.0 );
	c_bootyboat_speed = KvGetFloat( kv, "bootyboat_speed", 1.3 );

	c_cannon_speed = KvGetFloat( kv, "cannon_speed", 9.0 );
	c_cannon_turnspeed = KvGetFloat( kv, "cannon_turnspeed", 3.0 );
	c_cannon_backblast = KvGetFloat( kv, "cannon_backblast", 300.0 );
	c_cannon_backblast_upward = KvGetFloat( kv, "cannon_backblast_upward", 70.0 );
	//c_cannon_massscale = KvGetFloat( kv, "cannon_massscale", 4.0 );
	c_ship_detonate_ratio = KvGetNum( kv, "ship_detonate_ratio", 75 );
	
	c_supercharge_multiplier = KvGetNum( kv, "supercharge_multiplier", 4 );
	
	c_booty_speed = KvGetFloat( kv, "booty_speed", 200.0 );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	rxg_force_music = CreateConVar( "rxg_force_music", "0", "FFFFFFFF", FCVAR_PLUGIN );
//	g_ShakeUserMsgId = GetUserMessageId( "Shake" );

	ammo_grenade_limit_default = FindConVar( "ammo_grenade_limit_default" );
	ammo_grenade_limit_flashbang = FindConVar( "ammo_grenade_limit_flashbang" );
	ammo_grenade_limit_total = FindConVar( "ammo_grenade_limit_total" );
	HookConVarChange( ammo_grenade_limit_default, OnConVarChanged );
	HookConVarChange( ammo_grenade_limit_flashbang, OnConVarChanged );
	HookConVarChange( ammo_grenade_limit_total, OnConVarChanged );
	c_ammo_grenade_limit_default = GetConVarInt( ammo_grenade_limit_default );
	c_ammo_grenade_limit_flashbang = GetConVarInt( ammo_grenade_limit_flashbang );
	c_ammo_grenade_limit_total = GetConVarInt( ammo_grenade_limit_total );
	
	sv_alternateticks = FindConVar( "sv_alternateticks" );
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDeath );
	
	HookEvent( "hostage_rescued", Event_HostageRescued );
	HookEvent( "hostage_follows", Event_HostageFollows );
	//HookEvent( "hostage_call_for_help", Event_HostageDropped );
	
	HookEvent( "player_use", Event_PlayerUse );
	
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );
	HookPlayers();
	
	RegServerCmd( "boats_reloadcfg", reloadcfg );
	LoadConfig();
	
	RegConsoleCmd( "shiptest", shiptest );
}

public Action:shiptest(client,args) {


	 
	
	return Plugin_Handled;
}

public Action:reloadcfg( args ) {
	LoadConfig();
}

HookPlayer(client) {
	SDKHook( client, SDKHook_TouchPost, OnClientTouched );
	SDKHook( client, SDKHook_OnTakeDamage, OnClientTakeDamage );
	SDKHook( client, SDKHook_WeaponCanUse, OnClientWeaponCanUse );
}

HookPlayers() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if(!IsClientInGame(i) ) continue;
		HookPlayer(i);
	}
}
public OnClientPutInServer(client) {
	HookPlayer(client);
}

//----------------------------------------------------------------------------------------------------------------------
public Action:RoundStartDelayed( Handle:timer ) {
	
	/*
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
				
		StopSound(i, SNDCHAN_STATIC, "common\\silence_1sec_lp.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b01.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b02.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b03.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b01.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b02.wav" );
		StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b03.wav" );
	
	}*/
	
	StopGameSound(  "common\\silence_1sec_lp.wav", SNDCHAN_STATIC,0.0  );
	StopGameSound( "*music\\003\\startround_b01.wav", SNDCHAN_STATIC,0.0 );
	StopGameSound( "*music\\003\\startround_b02.wav", SNDCHAN_STATIC,0.0 );
	StopGameSound( "*music\\003\\startround_b03.wav", SNDCHAN_STATIC,0.0 );
	StopGameSound( "*music\\001\\startround_b01.wav", SNDCHAN_STATIC,0.0 );
	StopGameSound( "*music\\001\\startround_b02.wav", SNDCHAN_STATIC,0.0 );
	StopGameSound( "*music\\001\\startround_b03.wav", SNDCHAN_STATIC,0.0 );
	
	rs_timer++;
	if( rs_timer < (3.0 / 0.3) ) {
		return Plugin_Continue;
	} 
	
	if( GetRandomInt( 0, 100 ) > 70 && (GetConVarInt(rxg_force_music) == 0) ) {
		Music_Start( MUSIC_MAIN2 );
	} else {
		Music_Start( MUSIC_MAIN1 );
	}
	music_auto = 1;
	return Plugin_Stop;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	Music_Clean();
	firstbooty=true;
	hostage_carrier = 0;
	music_auto = 0;
	cannonball_id = 1;
	SetupCannons();
	SetupNadeboxes();
	ScanShipParts();
	SetupBoats();
	rs_timer = 0;
	CreateTimer( 0.3, RoundStartDelayed,_,TIMER_REPEAT );
	
	SetConVarInt( sv_alternateticks, 0 );
	LoadRopes();
	
	SpawnHosties();
	
	StripPlayerWeapons();
	LoadDeagles();
	SetupBooty();
	
	supercharged[0] =0;
	supercharged[1] = 0;
	endround=false;
	
	hostage_ent = FindEntityByClassname( -1, "hostage_entity" );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	endround=true;
	music_auto = 0;
	SetConVarInt( sv_alternateticks, 1 );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if( !client ) return;
	player_nadetime[client] = 0.0;
	player_boat_time[client] = 0.0;
	player_alive_time[client] = GetGameTime();
	//if( GetClientTeam(client) == 3 ) SetEntProp( client, Prop_Send, "m_bHasDefuser", 1 ); // changed mind
	DismountCannon(client);
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if( !client ) return;
	
	if( client == hostage_carrier ) Event_HostageDropped();
	 
	player_alive_time[client] = GetGameTime();
	DismountCannon(client);
	ExitBoat(client);
	if( DropBooty(client) ) {
		
		if( !endround ) {
			PrintToChatAll(  "\x01\x0B\x09The booty has been dropped!" );
			PrintCenterTextAll( "The booty has been dropped!" );
			EmitSoundToAll( "*rxg/bootydrop.mp3" );
		}
	}
	
	decl String:weapon[64];
	GetEventString( event, "weapon", weapon ,sizeof weapon);
	
	if( StrEqual( weapon, "env_explosion" ) ) {
		EmitAmbientSound( "*rxg/wilhelm.mp3", client_vecs[client], _, SNDLEVEL_SCREAMING+20 );
	}
}

public OnClientDisconnect( client ) {

	if( client == hostage_carrier ) Event_HostageDropped();
	
	DismountCannon(client);
	ExitBoat(client);
	if( DropBooty( client ) ) {
		if( !endround ) {
			PrintToChatAll(  "\x01\x0B\x09The booty has been dropped!" );
			PrintCenterTextAll(  "The booty has been dropped!" );
			EmitSoundToAll( "*rxg/bootydrop.mp3",SOUND_FROM_WORLD );
		}
	}
}

new const String:downloads[][] = {
	"models/rxg/booty.dx90.vtx",
	"models/rxg/booty.mdl",
	"models/rxg/booty.phy",
	"models/rxg/booty.vvd",
	"models/rxg/cannonball.dx90.vtx",
	"models/rxg/cannonball.mdl",
	"models/rxg/cannonball.phy",
	"models/rxg/cannonball.vvd",
//	"models/rxg/nadebox.mdl",
//	"models/rxg/nadebox.phy",
//	"models/rxg/nadebox.vvd",
//	"models/rxg/pirateflag.dx90.vtx",
//	"models/rxg/pirateflag.mdl",
//	"models/rxg/pirateflag.vvd",
	
	"materials/rxg/booty.vmt",
	"materials/rxg/booty.vtf",
	"materials/rxg/cannonball.vmt",
	"materials/rxg/cannonball.vtf",
//"materials/rxg/englishflag.vmt",
//	"materials/rxg/englishflag.vtf",
//	"materials/rxg/nades.vmt",
//	"materials/rxg/nades.vtf",
//	"materials/rxg/pirateflag.vmt",
//	"materials/rxg/pirateflag.vtf",
	
	"sound/rxg/wilhelm.mp3" ,
	"sound/rxg/cannonball2.mp3",
	"sound/rxg/bootycaptured.mp3", 
	"sound/rxg/bootydrop.mp3",
	"sound/rxg/bootypickedup.mp3",
	"sound/rxg/captaindropped.mp3",
	"sound/rxg/captainescaping.mp3",
	"sound/rxg/captainrescued.mp3"
};

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	music_delay = 0.0;
	//PrecacheSound( "music/rxg_boats_potc.mp3" );
	//AddFileToDownloadsTable( "sound/music/rxg_boats_potc.mp3" );
	
	for( new i = 1; i < sizeof music_list; i++ ) {
		decl String:download[128];
		Format(download,sizeof download, "sound/%s", music_list[i] );
		AddFileToDownloadsTable( download );
		PrecacheSound( music_list[i] );
	}
	
	CreateTimer( 1.0, UpdateTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	
	PrecacheModel( "models/props/de_inferno/cannon_gun.mdl" );
	PrecacheModel( "models/rxg/cannonball.mdl" );
	PrecacheModel( "models/rxg/booty.mdl" );
	PrecacheSound( "*rxg/cannonball2.mp3" );
	PrecacheSound( "*rxg/wilhelm.mp3" );
	
	PrecacheSound( "*rxg/bootycaptured.mp3"); 
	PrecacheSound( "*rxg/bootydrop.mp3");
	PrecacheSound( "*rxg/bootypickedup.mp3");
	PrecacheSound( "*rxg/captaindropped.mp3");
	PrecacheSound( "*rxg/captainescaping.mp3");
	PrecacheSound( "*rxg/captainrescued.mp3");
	
	PrecacheModel( GLOWMAT );
	  
	  
	
	for( new i = 0; i < sizeof(downloads); i++ ) {
		AddFileToDownloadsTable( downloads[i] );
	}
	
	PrecacheSound( "weapons/hegrenade/explode3.wav" );
	
	SaveRopes();
	
	// endround
	
	CreateTimer( 3.0, TimerEndRound,_,TIMER_FLAG_NO_MAPCHANGE );
}

public Action:TimerEndRound(Handle:timer) {
	CS_TerminateRound(0.5,	CSRoundEnd_Draw);
	return Plugin_Handled;
}
 

//-------------------------------------------------------------------------------------------------
#define AMMO_INDEX_HE 11
#define AMMO_INDEX_FLASH 12
#define AMMO_INDEX_SMOKE 13
#define AMMO_INDEX_MOLOTOV 14
#define AMMO_INDEX_DECOY 15
#define AMMO_INDEX_TASER 16

//-------------------------------------------------------------------------------------------------
bool:PlayerCanFitNade( client ) {
	new ammo_he			= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE      );
	new ammo_flash		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FLASH   );
	new ammo_smoke		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_SMOKE   );
	new ammo_molotov	= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_MOLOTOV );
	new ammo_decoy		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_DECOY   );
	
	new total = ammo_he + ammo_flash + ammo_smoke + ammo_molotov + ammo_decoy;
	
	if( total >= c_ammo_grenade_limit_total ) return false;
	
	if( ammo_he >= c_ammo_grenade_limit_default ) return false;

	return true;
}

//-------------------------------------------------------------------------------------------------
GivePlayerNade( client ) {
	GivePlayerItem( client, "weapon_hegrenade" );
}


//-------------------------------------------------------------------------------------------------
SetupNadeboxes() {

	for( new i = 0; i < MAXENTS; i++ ) {
		entity_is_nadebox[i] = false;
	}
	  
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "prop_physics_override" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( strncmp( name, "nadebox", 6 ) != 0 ) continue;
		
		//SetEntProp( ent, Prop_Send, "m_CollisionGroup",  );
		
		//SDKHook( ent, SDKHook_TouchPost, OnNadeboxTouched );
		entity_is_nadebox[ent] = true;
	}
}


//-------------------------------------------------------------------------------------------------
public OnClientTouched(entity, other) {
	
	
	
	if( entity_is_nadebox[other] ) {
		
		if( GetGameTime() - player_nadetime[entity] < c_nadebox_cooldown ) return; // cooldown
		
		if( !PlayerCanFitNade( entity ) ) return; // player is full
		player_nadetime[entity] = GetGameTime();
		GivePlayerNade(entity);
	} else if( boatmap[other] != -1 ) {
		
		
		TryEnterBoat( entity, boatmap[other] );
	} else if( other == bootydrop_ent ) {
		if( player_has_booty[entity] ) {
			//new booty = player_has_booty[entity];
			DropBooty(entity,false);
			
			//AcceptEntityInput( booty, "Kill" );
			OnBootyRescued();
		}
	} else if( cannonball_map[other] ) {
		CannonballTouch( other, 0 );
		
	}
}

 
/*
// respawn vectors
new Float:respawn_top = 950.0;
new Float:respawn_bottom = -200.0;
new Float:respawn_area[2][4] = {
	{-1135.0,-100.0,1060.0,-781.0},
	{-1535.0,1999.0,648.0,1312.0}
};*/


public bool:RespawnFilter(entity, contentsMask) {
	return true;
}

TryRespawnPlayer(client) {
/*
	new team = GetClientTeam(client);
	if( team < 2 ) return;
	for( new try = 0; try < 10; try++ ) {
		new Float:trace_start[3];
		new Float:trace_end[3];
		trace_start[2] = respawn_top;
		trace_end[2] = respawn_bottom;
		
		for( new i = 0 ; i < 2 ; i++ ) {
			trace_start[i] = GetRandomFloat( respawn_area[team-2][i], respawn_area[team-2][i+2] );
			trace_end[i] = trace_start[i];
			
		}
		
		TR_TraceRayFilter( trace_start, trace_end, CONTENTS_SOLID, RayType_EndPoint, RespawnFilter );
		
		new ent = TR_GetEntityIndex();
		decl String:class[64];
		GetEntityClassname( ent, class, sizeof class );
		if( StrEqual( class, "func_breakable" ) || StrEqual(class,"func_physbox") ) {
			//found good spot
			player_alive_time[client] = GetGameTime();
			CS_RespawnPlayer(client);
			decl Float:pos[3];
			TR_GetEndPosition( pos );
			pos[2] += 32.0;
			TeleportEntity( client, pos, NULL_VECTOR, NULL_VECTOR );
			break;
		}
	}*/
	
	player_alive_time[client] = GetGameTime();
	CS_RespawnPlayer(client);
}

//-------------------------------------------------------------------------------------------------
UpdateRespawn( client ) {
	if( endround ) return;
	
	if( GetClientTeam(client) < 2 ) return;
	if( !IsPlayerAlive(client) ) {
		new Float:seconds = c_respawn_time - (GetGameTime() - player_alive_time[client]);
		if( seconds <= 0.0 ) {
			TryRespawnPlayer(client);
			
			
		} else if( seconds < c_respawn_time - 3.0 ) {
			PrintHintText( client, "Respawn in %d seconds...", RoundToNearest(seconds) );
		} else {
		}
	} else {
		//player_alive_time[client] = GetGameTime();
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:UpdateTimer( Handle:timer ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		//UpdateNades(i);
		UpdateRespawn(i);
		
		if( player_has_booty[i] ) {
			PrintHintText( i, "You have the booty! Take it back to your ship!" );
		}
	}
	
	if( !hostage_carrier )
		FixCaptainPosition();
}




//----------------------------------------------------------------------------------------------------------------------
// #
// #CANNONS
// #
//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------
SetupCannons() {

	for( new i = 0; i <= MAXPLAYERS; i++ ) {
		player_using_cannon[i] = 0;
	}
	for( new i = 0; i < MAXENTS; i++ ) {
		cannonball_map[i] = 0;
	}
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "prop_physics_override" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( strncmp( name, "cannon", 6 ) != 0 ) continue;
		
		SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
		//SetEntPropFloat( ent, Prop_Data, "m_massScale", c_cannon_massscale );
		cannon_active[ent] = false;
		cannon_nextfire[ent] = 0.0;
		cannon_pitch[ent] = 0.0;
		// spawn barrel
		new barrel = CreateEntityByName( "prop_dynamic" );
		SetEntityModel( barrel, "models/props/de_inferno/cannon_gun.mdl" );
		SetVariantString( "!activator" );
		AcceptEntityInput( barrel, "SetParent", ent );
		new Float:vec[3];
		TeleportEntity( barrel, vec,vec,vec );
		DispatchSpawn( barrel );
		cannon_barrel[ent] = barrel;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerUse( Handle:event, const String:n[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new ent =  GetEventInt( event, "entity" );
	if( client == 0 ) return;
	
	
	
	decl String:name[64];
	GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
 
	if( !player_using_cannon[client] && strncmp( name, "cannon", 6 ) == 0 ) {
		if( cannon_active[ent] ) {
			PrintCenterText( client, "That cannon is being used." );
			return;
		}
		
		MountCannon( client, ent );
	} else if( boatmap[ent] != -1 ) {
		
		
		 
		TryEnterBoat( client, boatmap[ent],true );
	} else if( booty_ent[ent] ) {
		// it is booty!
	 
		TryPickupBooty( client, ent );
	}
}

//----------------------------------------------------------------------------------------------------------------------
DismountCannon( client ) {
	if( !player_using_cannon[client] ) return;
	new cannon = player_using_cannon[client];
	player_using_cannon[client] = 0;
	cannon_active[cannon] = false;
	
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;
	SetEntityMoveType( client, MOVETYPE_WALK );
	
	new Float:pos[3];
	GetClientAbsOrigin(client,pos);
	pos[2] -= 4.0;
	TeleportEntity(client,pos,NULL_VECTOR,NULL_VECTOR);
}

//----------------------------------------------------------------------------------------------------------------------
IsCannonUpright( ent ) {
	decl Float:angles[3];
	GetEntPropVector( ent, Prop_Send, "m_angRotation", angles );
	
	if( !( (angles[0] >= 340.0 || angles[0] <= 20.0) && (angles[2] >= 340.0 || angles[2] <= 20.0) ) ) {
		
		return false; // bad angles
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
MountCannon( client, ent ) {
	if( cannon_active[ent] ) return;
	if( player_riding_boat[client] != -1 ) return;
	if( player_using_cannon[client] ) return;
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;
	
	if( IsClientPiggybacking(client) ) return;
	
	if( !IsCannonUpright( ent ) ) {
		PrintCenterText( client, "You can't use that cannon." );
		return;
	}
	
	player_using_cannon[client] = ent;
	cannon_active[ent] = true;
	
	SetEntityMoveType( client, MOVETYPE_NONE );

}

//----------------------------------------------------------------------------------------------------------------------
UpdateCannons() {
	for( new i = 1; i <= MAXPLAYERS; i++ ) {
		if( !player_using_cannon[i] ) continue;
		if( !IsClientInGame(i) ) {
			DismountCannon(i);
			continue;
		}
		new cannon = player_using_cannon[i];
		
		if( !IsCannonUpright( cannon ) ) {
			DismountCannon(i);
			continue;
		}
		
		new buttons = GetClientButtons(i);
		
		if( buttons & IN_JUMP ) {
			DismountCannon(i);
			continue;
		}
		
	
		
		new Float:cannon_pos[3];
		new Float:cannon_angles[3];
		GetEntPropVector( cannon, Prop_Data, "m_vecAbsOrigin", cannon_pos );
		GetEntPropVector( cannon, Prop_Send, "m_angRotation", cannon_angles );
		new Float:cannon_direction[3];
		cannon_direction[1] = cannon_angles[1];
		GetAngleVectors( cannon_direction, NULL_VECTOR, cannon_direction, NULL_VECTOR );
		
		
		new Float:move[3];
		
		new bool:moving;
		if( buttons & IN_FORWARD ) {
			for( new j = 0; j < 2; j++ ) {
				move[j] =  cannon_direction[j] * c_cannon_speed;
				
			}
			moving = true;
		} else if( buttons & IN_BACK ) {
			for( new j = 0; j < 3; j++ ) {
				move[j] =  -cannon_direction[j] * c_cannon_speed;
				
			}
			moving = true;
		}
		
		if( buttons & IN_ATTACK ) {
		
			if( TryShootCannon( cannon, i ) ) {
				for( new j = 0; j < 2; j++ ) {
					move[j] += -cannon_direction[j] * c_cannon_backblast;
				}
				move[2] += c_cannon_backblast_upward;
				moving = true;
			}
			
		}
		
		decl Float:player_angles[3];
		GetClientEyeAngles( i, player_angles );
		player_angles[1] = player_angles[1] + 90.0 + 360.0;
		while( player_angles[1] >= 360.0 ) player_angles[1] -= 360.0;
		
		new Float:avel[3];
		
		if( moving ) {
			new Float:diff = player_angles[1] - cannon_angles[1];
			if( diff > 180 ) diff -= 360;
			if( diff < -180 ) diff += 360;
			
			
			if( FloatAbs(diff) > 1.0 ) {
				if( diff < 0.0 ) {
					avel[2] = -c_cannon_turnspeed;
				} else {
					avel[2] =c_cannon_turnspeed;
				}
			}
		}
		
		if( moving ) {
		 
			Phys_AddVelocity( cannon, move, avel );
		}
		
		// adjust pitch
		{	
			player_angles[0] += 360.0; // fixup angle
			while( player_angles[0] >= 360.0 ) player_angles[0] -= 360.0;
			if( player_angles[0] >= 180.0 ) player_angles[0] -= 360.0;
			
			
			new Float:diff = player_angles[0] - cannon_pitch[cannon];
			if( diff > 180 ) diff -= 360;
			if( diff < -180 ) diff += 360;
			
			if( FloatAbs(diff) > 1.5 ) {
				if( diff < 0.0 ) {
					cannon_pitch[cannon] -= 0.5;
				} else {
					cannon_pitch[cannon] += 0.5;
				}
			}
			
			// clamp max range
			if( cannon_pitch[cannon] < -85.0 ) {
				cannon_pitch[cannon] = -85.0;
			}
			if( cannon_pitch[cannon] > 10.0 ) {
				cannon_pitch[cannon] = 10.0;
			}
			 
			new Float:angles[3];
			angles[2] = cannon_pitch[cannon] ;//* 0.75; // scale down if too silly
			
			TeleportEntity( cannon_barrel[cannon], NULL_VECTOR, angles, NULL_VECTOR );
		}
		cannon_direction[0] = 0.0;
		
		cannon_direction[1] = cannon_angles[1];
		cannon_direction[2] = 0.0;
		GetAngleVectors( cannon_direction, NULL_VECTOR, cannon_direction, NULL_VECTOR );
		decl Float:playerpos[3];
		playerpos[0] = cannon_pos[0] - cannon_direction[0] * 14.0;
		playerpos[1] = cannon_pos[1] - cannon_direction[1] * 14.0;
		playerpos[2] = cannon_pos[2] + 8.0;
		new Float:zero[3];
		//GetEntPropVector( cannon, Prop_Data, "m_vecAbsOrigin", pos );
		
		
		TeleportEntity( i, playerpos, NULL_VECTOR, zero );
		
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnCannonballBreak( const String:output[], caller, activator, Float:delay ) {
	CannonballTouch( caller, 0 );
}

//----------------------------------------------------------------------------------------------------------------------
public CannonballTouch(entity, other) {
	
	decl Float:pos[3];
	GetEntPropVector( entity, Prop_Data, "m_vecAbsOrigin", pos );
	new owner = cannonball_owner[entity];//GetEntPropEnt( entity, Prop_Data, "m_hOwnerEntity" );
	
	new dmg = c_cannonball_explosion;
	if( owner > 0 ) {
		new team = GetClientTeam(owner);
		if( team >= 2 ) {
			if( supercharged[team-2] ) {
				dmg *= c_supercharge_multiplier;
			}
		}
	}
	
	CreateExplosion( pos,  dmg, owner );
	AcceptEntityInput(entity,"Kill");
	
	
}


//----------------------------------------------------------------------------------------------------------------------
CreateExplosion( Float:vec[3], damage,owner,bool:suppress=false ) {
	new ent = CreateEntityByName("env_explosion");	 
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", owner );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",damage); 
	//SetEntProp(ent, Prop_Data, "m_iRadiusOverride",300); 
	
	if( !suppress )
		EmitAmbientSound( ")weapons/hegrenade/explode3.wav", vec, _, SNDLEVEL_GUNFIRE  );
		
	if( suppress ) {
		DispatchKeyValue( ent, "spawnflags", "89" );
	}

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	
	new Float:shakelen = 150.0;
	new Float:shakediv = 3.0; // want:50
	if( suppress ) {
		// want:15
		shakelen = 120.0;
		shakediv = 6.0;
	}
	// shake screens
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		new Float:pos[3];
		GetClientEyePosition( i, pos );
		new Float:dist = GetVectorDistance( vec, pos, true );
		if( dist < shakelen*shakelen ) {
			ShakeScreen( i, (shakelen - SquareRoot(dist)) / shakediv );
		}
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:CannonballExpire( Handle:timer, any:data ) {
	ResetPack(data);
	new ent = ReadPackCell(data);
	if( !IsValidEntity(ent) ) return Plugin_Handled;
	decl String:name1[64];
	GetEntPropString( ent, Prop_Data, "m_iName", name1, sizeof name1 );
	decl String:name2[64];
	ReadPackString(data,name2,sizeof(name2));
	if( !StrEqual(name1,name2) ) return Plugin_Handled;
	AcceptEntityInput( ent, "Kill" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryShootCannon( cannon,client ) {
	if( GetGameTime() < cannon_nextfire[cannon] ) return false;
	cannon_nextfire[cannon] = GetGameTime() + c_cannon_cooldown;
	
	new bool:super = false;
	if( client != 0 ) {
		new team = GetClientTeam(client);
		if( team >= 2 ) {
			if( supercharged[team-2] ) {
				super=true;
			}
		}
	}
	
	new ent = CreateEntityByName( "prop_physics_override" );
	cannonball_map[ent] = 1;
	cannonball_owner[ent] = client;
	SetEntityModel( ent, "models/rxg/cannonball.mdl" );
	//SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", client ); // this fucks with collision
	
	DispatchKeyValue( ent,"health", "1");
	DispatchKeyValue( ent,"massscale", "0.1" );
	decl String:name[64];
	Format(name,sizeof name, "cannonball%d", cannonball_id++ );
	DispatchKeyValue(ent,"targetname",name);
	new Float:cannon_pos[3];
	new Float:cannon_angles[3];
	GetEntPropVector( cannon, Prop_Data, "m_vecAbsOrigin", cannon_pos );
	GetEntPropVector( cannon, Prop_Send, "m_angRotation", cannon_angles );
	new Float:cannon_direction[3];
	cannon_direction[1] = cannon_angles[1];
	cannon_direction[2] = cannon_pitch[cannon];
	GetAngleVectors( cannon_direction, NULL_VECTOR, cannon_direction, NULL_VECTOR );
		
	cannon_pos[0] += cannon_direction[0] * 64.0;
	cannon_pos[1] += cannon_direction[1] * 64.0;
	cannon_pos[2] += cannon_direction[2] * 64.0;
	cannon_pos[2] += 50.0;
	
	cannon_direction[2] += 0.15;
	
	cannon_direction[0] *= 5000.0;
	cannon_direction[1] *= 5000.0;
	cannon_direction[2] *= 5000.0;
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	TeleportEntity( ent, cannon_pos, cannon_angles, cannon_direction );
	
	CreateExplosion( cannon_pos, 0, 0,true );
	
	EmitSoundToAll( "*rxg/cannonball2.mp3", cannon, _, SNDLEVEL_RAIDSIREN, _,_,GetRandomInt(85,114) );
	
	if( super ) {
		AttachGlow( ent );
	}
	
	//
	SDKHook( ent, SDKHook_StartTouchPost, CannonballTouch );
	HookSingleEntityOutput( ent, "OnBreak", OnCannonballBreak, true );
	new Handle:data;
	CreateDataTimer( 10.0, CannonballExpire, data, TIMER_FLAG_NO_MAPCHANGE );
	WritePackCell(data, ent);
	WritePackString(data,name);
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
// #
// # BOATS
// #
//----------------------------------------------------------------------------------------------------------------------

SetupBoats() {
	boatcount = 0;
	for( new i = 0; i <= MAXPLAYERS; i++ ) {
		player_riding_boat[i] = -1;
		player_boat_seat[i] = 0;
	}
	
	for( new i = 0; i < MAXENTS; i++ ) {
		boatmap[i] = -1;
	}
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "func_physbox" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( strncmp( name, "boat", 4 ) != 0 ) continue;
		
		boatmap[ent] = boatcount;
		boat_ent[boatcount] = ent;
		
		
		for( new i =0;i<BOATSEATS;i++ )
			boat_seats[boatcount][i]=0;
		boat_passengers[boatcount] = 0;
		boatcount++;
		
		
		if( strncmp( name, "boat2", 5 ) != 0 ) continue;
		
		// flip the other boat around
		
		decl Float:angles[3];
		GetEntPropVector( ent, Prop_Send, "m_angRotation", angles );
		angles[1] += 180.0;
		TeleportEntity( ent, NULL_VECTOR, angles, NULL_VECTOR );
	}
}

//----------------------------------------------------------------------------------------------------------------------
bool:IsBoatUpright( ent ) {
	decl Float:angles[3];
	GetEntPropVector( ent, Prop_Send, "m_angRotation", angles );
	
	if( !( (angles[0] >= 300.0 || angles[0] <= 60.0) && (angles[2] >= 300.0 || angles[2] <= 60.0) ) ) {
		
		return false; // bad angles
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
TryEnterBoat( client, boat, bool:direct=false ) {
	if( player_riding_boat[client] != -1 ) return; // already on boat
	if( player_using_cannon[client] ) return;
	
	if( IsClientPiggybacking(client) ) return;
	
	if( !direct ) {
		if( GetGameTime() < (player_boat_time[client] + c_enter_boat_cooldown) ) {
			// unstick client (for boat touching!)
			new Float:newpos[3];
			GetClientAbsOrigin( client, newpos );
			newpos[2] += 0.5;
			TeleportEntity( client, newpos, NULL_VECTOR, NULL_VECTOR );
			return;
		}
	}
	
	
	
	if( boat_passengers[boat] >= BOATSEATS ) return; // boat is full
	
	if( !IsBoatUpright(boat_ent[boat]) ) return; // boat is capsized
	
	for( new i = 0; i < BOATSEATS;i++ ) {
		if( boat_seats[boat][i] != 0 ) continue;
		boat_seats[boat][i] = client;
		boat_passengers[boat]++;
		
		player_boat_seat[client] = i;
		player_riding_boat[client] = boat;
		
		
		SetEntityMoveType( client, MOVETYPE_NONE );
		
		AcceptEntityInput( boat_ent[boat], "Wake" );
		break;
	}
}

//----------------------------------------------------------------------------------------------------------------------
ExitBoat(client) {
	new boat = player_riding_boat[client];
	if( boat == -1 ) return;
	
	player_boat_time[client] = GetGameTime();
	player_riding_boat[client] = -1;
	boat_seats[boat][player_boat_seat[client]] = 0;
	boat_passengers[boat]--;
	
	if( !IsClientInGame(client) ) return;
	SetEntityMoveType( client, MOVETYPE_WALK );
}

//----------------------------------------------------------------------------------------------------------------------
UpdateBoats() {
	for( new i = 0 ; i < boatcount; i++ ) {
		if( boat_passengers[i] ) {
		
			new boat = i;
			decl Float:boatpos[3];
			GetEntPropVector( boat_ent[i], Prop_Data, "m_vecAbsOrigin", boatpos );
			
			new bool:capsized = !IsBoatUpright(boat_ent[i]);
			
			new bool:hasbooty = false;
			for( new j = 0; (j < BOATSEATS) && !hasbooty; j++ ) {
				new client = boat_seats[i][j];
				if( !client ) continue;
				if( player_has_booty[client] ) hasbooty = true;
				if( hostage_carrier == client ) hasbooty = true;
			}
			
			for( new j = 0; j < BOATSEATS; j++ ) {
			
				new client = boat_seats[i][j];
				if( !client ) continue;
				
				if( !IsClientInGame(client) ) {
					ExitBoat(client);
					continue;
				}
				
				if( capsized ) {
					ExitBoat(client);
					continue;
				}
				
				new buttons = GetClientButtons(client);
				
				if( buttons & IN_JUMP ) {
					ExitBoat(client);
					continue;
				}
				
				new Float:boat_pos[3];
				new Float:boat_angles[3];
				GetEntPropVector( boat_ent[boat], Prop_Data, "m_vecAbsOrigin", boat_pos );
				GetEntPropVector( boat_ent[boat], Prop_Send, "m_angRotation", boat_angles );
				new Float:boat_direction[3];
				boat_direction[1] = boat_angles[1];
				boat_direction[1] -= 90.0;
				GetAngleVectors( boat_direction, NULL_VECTOR, boat_direction, NULL_VECTOR );
				
				
				new Float:move[3];
				
				
				new bool:moving;
				if( j == 0 ) {
					if( buttons & IN_FORWARD ) {
						for( new k = 0; k < 2; k++ ) {
							move[k] =  boat_direction[k] * (hasbooty ? c_bootyboat_speed : c_boat_speed);
							 
						}
						moving = true;
					} else if( buttons & IN_BACK ) {
						for( new k = 0; k < 3; k++ ) {
							move[k] =  -boat_direction[k] * (hasbooty ? c_bootyboat_speed : c_boat_speed);
							 
						}
						moving = true;
					}
				}
				  
				new Float:avel[3];
				 
				
				if( j == 0 ) {
					if( buttons&  IN_MOVELEFT) {
						avel[2] = c_boat_turnspeed;
						moving=true;
					} else if( buttons&  IN_MOVERIGHT )  {
						avel[2] = -c_boat_turnspeed;
						moving=true;
					} 
				}
				if( moving ) {
					
					Phys_AddVelocity( boat_ent[boat], move, avel );
				}
				boat_direction[0] = 0.0;
				
				boat_direction[1] = boat_angles[1];
				boat_direction[2] = 0.0;
				
				{
					decl Float:fwd[3],Float:right[3], Float:up[3];
					GetAngleVectors( boat_direction, fwd, right, up );
					new Float:playerpos[3];
					playerpos[0] = boat_pos[0];
					playerpos[1] = boat_pos[1];
					playerpos[2] = boat_pos[2];
					for( new k = 0; k < 3; k++ ) {
						playerpos[1] += right[k] * boat_passenger_positions[j][k];
						playerpos[0] +=   fwd[k] * boat_passenger_positions[j][k];
						playerpos[2] += up[k] * boat_passenger_positions[j][k];
					}
					new Float:zero[3];
					TeleportEntity( client, playerpos, NULL_VECTOR, zero );
				}
					
				
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
ScanShipParts() {

	for( new i = 0; i < MAXENTS; i++ ){
		ship_ents[i] = 0;
	}
	ship_parts[0] = 0;
	ship_parts[1] = 0;
	ship_damage[0] = 0;
	ship_damage[1] = 0;
	ship_alive[0] = 1;
	ship_alive[1] = 1;
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "func_breakable" )) != -1 ) {
		//decl String:name[64];
		//GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		//if( strncmp( name, "cannon", 6 ) != 0 ) continue;
		
		new Float:pos[3];
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", pos );
		if( pos[1] < 500.0 ){
			ship_ents[ent] = 1; // t
			ship_parts[0]++;
		} else {
			ship_ents[ent] = 2; // ct
			ship_parts[1]++;
		}
		
	} 
	
	ship_bomb_hook[0] = 0;
	ship_bomb_hook[1] = 0;
	// find bomb hook
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_target" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( StrEqual( name, "bombhook-ctboat" ) ) {
			ship_bomb_hook[1] = ent;
		} else if( StrEqual( name, "bombhook-tboat" ) ) {
			ship_bomb_hook[0] = ent;
		}
	}
}
//----------------------------------------------------------------------------------------------------------------------
DetonateShip( ship ) {
	if( !ship_alive[ship] ) return;
	ship_alive[ship] = 0;
	if( ship_bomb_hook[ship] == 0 ) {
		PrintToChatAll( "Error: bomb hook missing!! (%d)", ship );
		return;
	}
	new ent = CreateEntityByName( "planted_c4" );
	SetEntProp( ent, Prop_Send, "m_bBombTicking", 1 );
	decl Float:pos[3];
	GetEntPropVector( ship_bomb_hook[ship], Prop_Data, "m_vecAbsOrigin", pos );
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	DispatchSpawn(ent);
	SetEntPropFloat( ent, Prop_Send, "m_flC4Blow", GetGameTime() + 1.0 );
	SetEntPropFloat( ent, Prop_Send, "m_flTimerLength", 0.0 );
	CreateTimer( 2.0, DetonateEndRound, ship, TIMER_FLAG_NO_MAPCHANGE );
	
	StopGameSound( "*music\\001\\bombtenseccount_b01.wav", SNDCHAN_STATIC,0.1 );
	StopGameSound( "*music\\001\\bombtenseccount_b01.wav", SNDCHAN_STATIC,0.4 );
	StopGameSound( "items\\nvg_on.wav", SNDCHAN_STATIC,0.2,ent );
	//StopGameSound( "ui\\arm_bomb.wav", SNDCHAN_STATIC,0.8,ent );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:DetonateEndRound( Handle:timer,any:ship ) {
	if( !endround ) {
		CS_TerminateRound( 6.0, ship == 0 ? CSRoundEnd_CTWin:CSRoundEnd_TerroristWin );
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
OnShipDamaged( ship, damage ) {
	if(endround)return;
	if( damage >= (ship_parts[ship]*c_ship_detonate_ratio/100) ) {
		// detonate ship
		DetonateShip(ship);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnGameFrame() {
	
	UpdateCannons();
	UpdateBoats();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		GetClientAbsOrigin( i, client_vecs[i] );
	}
	 
	
	Music_Update();
}

public OnEntityDestroyed(entity) {
	if(entity >= MAXENTS || entity <= 0 ) return;
	if( ship_ents[entity] ) {
		new ship = ship_ents[entity]-1;
		ship_ents[entity] = 0;
		if( !ship_alive[ship] ) return;
		ship_damage[ship]++;
		OnShipDamaged( ship, ship_damage[ship] );
	}
	if( boatmap[entity] != -1 ) {
		BoatDestroyed( entity );
	}
	if( booty_ent[entity] ) {
	 
		booty_ent[entity] = false;
	}
	if( cannonball_map[entity] ) {
		cannonball_map[entity] = 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
ShakeScreen( client, Float:amplitude ) {
	 
	new Handle:message = StartMessageOne( "Shake", client );
	PbSetInt( message, "command", 0 );
	PbSetFloat(message, "local_amplitude", amplitude);
	PbSetFloat(message, "frequency", 25.0);
	PbSetFloat(message, "duration", 1.0);
	
	EndMessage();

}
 

new Handle:ropepack = INVALID_HANDLE;

//----------------------------------------------------------------------------------------------------------------------
SaveRopes() {
	if( ropepack != INVALID_HANDLE ) CloseHandle( ropepack );
	ropepack = CreateDataPack();
	new ent = -1;
	while(( ent = FindEntityByClassname( ent, "move_rope" )) != -1 ) {
		
		new Float:pos[3];
		GetEntPropVector( ent, Prop_Data, "m_vecOrigin", pos );
		for( new i = 0; i < 3; i++ )
			WritePackFloat( ropepack, pos[i] );
		
		decl String:str[64];
		GetEntPropString( ent, Prop_Data, "m_iParent", str, sizeof str );
		
		//GetEntPropString( parent, Prop_Data, "m_iName", str, sizeof str );
		
		WritePackString( ropepack, str );
		
		
		GetEntPropString( ent, Prop_Data, "m_iNextLinkName", str, sizeof str );
		WritePackString( ropepack, str );
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
LoadRopes() {
	ResetPack(ropepack);
	while( IsPackReadable(ropepack,1) ) {
		new rope = CreateEntityByName( "move_rope" );
		DispatchKeyValue( rope, "Width", "3" );
		DispatchKeyValue( rope, "RopeMaterial", "cable/rope.vmt" );
		DispatchKeyValue( rope, "Slack", "25" );
		DispatchKeyValue( rope, "Collide", "0" );
		
		new Float:pos[3];
		for( new i = 0; i < 3; i++ )
			pos[i] = ReadPackFloat( ropepack );
		
		decl String:str[64];
		ReadPackString(ropepack,str,sizeof str); // parent
		
		SetVariantString( str );
		AcceptEntityInput(rope,"SetParent" );
		TeleportEntity( rope, pos, NULL_VECTOR,NULL_VECTOR);
		
		ReadPackString( ropepack, str, sizeof str ); // nextkey
		DispatchKeyValue( rope, "NextKey", str );
		
		
		
		DispatchSpawn( rope );
		ActivateEntity( rope );
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
SpawnHosties() {
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_target" )) != -1 ) {
		decl String:name[64];
		GetEntPropString(ent, Prop_Data,"m_iName", name, sizeof name );
		
		if( strncmp(name,"hostie",6) != 0 ) continue;
		
		new hostage = CreateEntityByName( "hostage_entity" );
		SetEntityMoveType( hostage, MOVETYPE_NONE );
		decl Float:vec[3];
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );
		new Float:ang[3];
		ang[1] = GetRandomFloat(0.0,360.0);
		TeleportEntity( hostage, vec, ang, NULL_VECTOR );
		DispatchSpawn( hostage );
	}
}

//#/define WEAPON_AMMO_BACKPACK 1452
//----------------------------------------------------------------------------------------------------------------------
// give all deagles spare ammo
//
LoadDeagles() {
	//new offset = FindSendPropInfo("CWeaponCSBase", "m_fAccuracyPenalty");
	//offset+=20;
	
	new ent = -1;
	
	while( (ent = FindEntityByClassname( ent, "weapon_deagle" )) != -1 ) {
		CS_SetDroppedWeaponAmmo( ent, 10 );
		//SetEntData(ent, offset, 10 );
	}
}

//----------------------------------------------------------------------------------------------------------------------
// remove any weapons carried over from previous rounds
//
StripPlayerWeapons( ) {
	for( new client = 1; client <= MaxClients; client++ ) {
		
		if( !IsClientInGame(client) ) continue;
		for( new i = 0; i < 64; i++ ) {
			new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
			if( ent <= 0 ) continue;
			if( ent == GetPlayerWeaponSlot( client, int:SlotKnife ) ) continue;
		
			CS_DropWeapon(client, ent, true, true);
			AcceptEntityInput(ent, "Kill");
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// nullify drown damage if player is on a boat
//
public Action:OnClientTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
 
	if( damagetype == DMG_DROWN ) {
		 
		if( (player_riding_boat[victim] != -1) || ((GetGameTime() - player_alive_time[victim]) < 5.0) ) {
			
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

BoatDestroyed( ent ) {
	new boat = boatmap[ent];
	
	
	if( boat_passengers[boat] ) {
		// unloadpassengers
		for( new i = 0; i < BOATSEATS; i++ ) {
			new seat = boat_seats[boat][i];
			if( seat == 0 ) continue;
			ExitBoat( seat );
		}
	}
	boat_passengers[boat] = 0;
	boatmap[ent] = 0;
	boat_ent[boat] = 0;
}

//----------------------------------------------------------------------------------------------------------------------
//
// BOOTY
//
//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------
SetupBooty() {
	for( new i = 0; i < MAXENTS;i++ ) {
		booty_ent[i] = false;
		//booty_is_held[i] = 0;
	}
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		player_has_booty[i] = 0;
	}
	
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "info_target" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( StrEqual( name, "booty" ) ) {
			
			decl Float:vec[3];
			new Float:ang[3] = {0.0,280.0,0.0};
			GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );
			SpawnBooty( vec,ang );
			 
		}
	}
	
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "trigger_multiple" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
		if( StrEqual( name, "bootydrop" ) ) {
			
			bootydrop_ent = ent;
			 
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
SpawnBooty( const Float:vec[3], const Float:ang[3] ) {
	new ent = CreateEntityByName( "prop_physics_override" );
	SetEntityModel( ent, "models/rxg/booty.mdl" );
	DispatchKeyValue( ent, "targetname", "bootybox" );
	DispatchKeyValue( ent, "spawnflags", "256" );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	//new Float:ang[3] = {0.0,10.0,0.0};
	AcceptEntityInput(ent, "DisableDamageForces" );
	TeleportEntity( ent, vec, ang, NULL_VECTOR );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	booty_ent[ent] = true;
	return ent;
}

SpawnCarryBooty() {
	new ent = CreateEntityByName( "prop_dynamic" );
	SetEntityModel( ent, "models/rxg/booty.mdl" );
	DispatchKeyValue( ent, "targetname", "bootycarry" );
	   
	DispatchSpawn(ent);
	ActivateEntity(ent); 
	return ent;
}

//----------------------------------------------------------------------------------------------------------------------
TryPickupBooty( client, ent ) {
	
	if( GetClientTeam(client) != 2 ) return;
	 
	if( !booty_ent[ent] ) return;
	//if( booty_is_held[ent] ) return;
	
	//booty_is_held[ent] = client;
	
	AcceptEntityInput( ent, "Kill" );
	booty_ent[ent] = false;
	ent = SpawnCarryBooty();
	player_has_booty[client] = ent;
	
	SetEntPropFloat( client, Prop_Send, "m_flMaxspeed", c_booty_speed );
	
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( "c4" );
	AcceptEntityInput( ent, "SetParentAttachment" );
	
	new Float:vec[3];
	new Float:ang[3];
	new Float:vel[3];
	
	TeleportEntity( ent, vec, ang, vel );
	AcceptEntityInput( ent, "DisableMotion" );
	
	EmitSoundToAll( "*rxg/bootypickedup.mp3" );
	PrintCenterTextAll(  "The booty has been picked up!" );
	PrintToChatAll( "\x01\x0B\x09The booty has been picked up!" );
	
	if( firstbooty ) {
		firstbooty = false;
		Music_Fade();
		Music_DelayStart( 1.0 );
		Music_Queue( MUSIC_TENSE2 );
	}
}

//----------------------------------------------------------------------------------------------------------------------
DropBooty( client, bool:respawn=true ) {
 
	new booty = player_has_booty[client];
	if( !booty ) return 0;
	player_has_booty[client] = 0;
	
	new Float:pos[3];
	new Float:ang[3];
	for( new i =0 ; i < 3; i++ ) {
		pos[i] = client_vecs[client][i];
	} 
	
	if( IsValidEntity(booty) ) {
		decl String:name[64];
		GetEntPropString( booty, Prop_Data, "m_iName", name, sizeof name );
		
		
		if( StrEqual( name, "bootycarry" ) ) {
		
			// this is the usual path, may not happen when a client DCs
			
			// take position from carry prop
			GetEntPropVector( booty, Prop_Data, "m_vecAbsOrigin", pos );
			GetEntPropVector( booty, Prop_Data, "m_angAbsRotation", ang );
			
			AcceptEntityInput(booty,"Kill");
		}
	}
	//booty_is_held[booty] = 0;
		
	
	if( respawn ) {
		 
		SpawnBooty( pos,ang  );
		
	}
	
	if( IsClientInGame(client) ) {
		
		SetEntPropFloat( client, Prop_Send, "m_flMaxspeed", 260.0 );
	}
	
	return 1;
	
	/*
	if( !IsClientInGame(client) ) return 1;
	
	AcceptEntityInput( booty, "ClearParent" );
	AcceptEntityInput( booty, "EnableMotion" );
	SetEntityMoveType( booty, MOVETYPE_VPHYSICS );
	new Float:vel[3] = {0.0,0.0,1.0};
	TeleportEntity(booty,NULL_VECTOR,NULL_VECTOR,vel);
	return 1;*/
}

//-------------------------------------------------------------------------------------------------
public Event_HostageRescued( Handle:event, const String:name[], bool:dontBroadcast ) {
	OnHostieRescued();
	StopGameSound(  "radio\\rescued.wav", SNDCHAN_STATIC,0.2  );
	hostage_carrier = 0;
}

public Event_HostageFollows( Handle:event, const String:name[], bool:dontBroadcast ) {
	EmitSoundToAll( "*rxg/captainescaping.mp3" );
	PrintCenterTextAll(  "The captain is escaping!" );
	PrintToChatAll(  "\x01\x0B\x09The captain is escaping!" );
	hostage_carrier = GetClientOfUserId(GetEventInt( event, "userid" ));
	
	//CreateTimer( 0.25, SlowCarrier, _, TIMER_FLAG_NO_MAPCHANGE );
	//GetClientAbsOrigin(  hostage_carrier , hostage_vec );
}
/*
public Action:SlowCarrier( Handle:timer ) {

	
	if(hostage_carrier != 0)
		SetEntPropFloat( hostage_carrier, Prop_Send, "m_flMaxspeed", 100.0 );
	return Plugin_Handled;
}*/

Event_HostageDropped() {
	//if(hostage_carrier != 0)
	//	SetEntPropFloat( hostage_carrier, Prop_Send, "m_flMaxspeed", 260.0 );
	hostage_carrier = 0;
	
	EmitSoundToAll( "*rxg/captaindropped.mp3" );
	PrintCenterTextAll( "The captain has been dropped!" );
	PrintToChatAll(   "\x01\x0B\x09The captain has been dropped!" );
	//if( !endround )
	//	CreateTimer( 0.5, TeleportCaptain );
}

public FixCaptainPosition() {
	
	new Float:waterlevel = -170.0;
	//waterlevel -= 23.0;
	new Float:pos[3];
	GetEntPropVector( hostage_ent, Prop_Data, "m_vecAbsOrigin", pos );
	if( pos[2] < waterlevel ) {
		pos[2] = waterlevel;
		TeleportEntity( hostage_ent, pos, NULL_VECTOR, NULL_VECTOR );
	}
}

//-------------------------------------------------------------------------------------------------
OnHostieRescued() {
	Music_Fade();
	Music_DelayStart( 3.0 );
	Music_Queue( MUSIC_CAPTAIN );
	EmitSoundToAll( "*rxg/captainrescued.mp3" );
	PrintCenterTextAll( "The Captain has been rescued! The British have gained Supercharged Cannons!" );
	PrintToChatAll( "\x01\x0B\x09The Captain has been rescued! The British have gained Supercharged Cannons!" );
	supercharged[1] = 1;
}

//-------------------------------------------------------------------------------------------------
OnBootyRescued() {
	Music_Fade();
	Music_DelayStart( 3.0 );
	Music_Queue( MUSIC_TENSE1 );
	EmitSoundToAll( "*rxg/bootycaptured.mp3" );
	PrintCenterTextAll( "The Booty has been captured! The Pirates have gained Supercharged Cannons!" );
	PrintToChatAll( "\x01\x0B\x09The Booty has been captured! The Pirates have gained Supercharged Cannons!" );
	supercharged[0] = 1;
}


//-------------------------------------------------------------------------------------------------
AttachGlow( parent ) {
	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", ent );
	SetEntityModel( ent, GLOWMAT );
	SetEntityRenderColor( ent, 255,255,255 );
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );//RENDER_GLOW );
	DispatchKeyValue( ent, "GlowProxySize", "45.0" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "20.0" ); 
	DispatchKeyValue( ent, "scale", "45.0" );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent",parent );
	new Float:pos[3];

	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
}

//-------------------------------------------------------------------------------------------------
bool:MusicHasExpired() {
	return ((GetGameTime() - music_start_time) >= music_duration[music_current]) || music_volume == 0.0;
}

//-------------------------------------------------------------------------------------------------
Music_Update() {
	if( MusicHasExpired() ) {
		if( music_auto ) {
			if( GetGameTime() >= music_delay ) {
				if( !music_next && GetGameTime() < music_start_time + music_duration[music_current] + 3.0 ) return; // hack to add delay between fillers
				Music_AutoPlay();
				return;
			}
		}
	}
	if( music_fading ) {
		music_volume -= 0.018;
		Music_SetVolume( music_volume );
		if( music_volume == 0 ) {
			music_fading = false;
			
		}
		
	}
}
/*
//-------------------------------------------------------------------------------------------------
public Action:Music_Timer( Handle:timer ) {
	if( music_auto ) {
		Music_AutoPlay();
	}
	music_timer = INVALID_HANDLE;
	return Plugin_Handled;
}*/

//-------------------------------------------------------------------------------------------------
Music_Fade() {
	music_fading = true;
}

Music_DelayStart( Float:time ) {
	music_delay = GetGameTime() + time;
}

//-------------------------------------------------------------------------------------------------
Music_Queue( index ) {
	music_next = index;
}

//-------------------------------------------------------------------------------------------------
Music_SetVolume( Float:vol ) {
	if( vol < 0.0 ) vol = 0.0;
	if( vol > 1.0 ) vol = 1.0;
	music_volume = vol;
	EmitSoundToAll( music_list[music_current], _, SNDCHAN_STATIC, _, SND_CHANGEVOL, vol );
}

//-------------------------------------------------------------------------------------------------
Music_AutoPlay() {
	if( music_next ) {
		Music_Start(music_next);
		music_next = 0;
	} else {
		Music_Start( GetRandomInt( MUSIC_FILLER1, MUSIC_FILLER5 ) );
	}
}


//-------------------------------------------------------------------------------------------------
Music_Start( index ) {
	//if( music_timer != INVALID_HANDLE ) {
	//	KillTimer(music_timer);
	//	music_timer = INVALID_HANDLE;
	//}
	music_fading = false;
	music_current = index;
	music_start_time = GetGameTime();
	music_volume = 1.0;
	EmitSoundToAll( music_list[index],_,SNDCHAN_STATIC );
	
	
}

//-------------------------------------------------------------------------------------------------
Music_Clean() {
/*
	if( music_timer != INVALID_HANDLE ) {
		KillTimer(music_timer);
		music_timer = INVALID_HANDLE;
	}*/
	
	music_current = 0;
	music_start_time = 0.0;
	music_fading = false;
}

StopGameSound( const String:sample[], channel, Float:delay=0.01, ent=0 ){
	new Handle:data = CreateDataPack();
	WritePackString(data, sample);
	WritePackCell(data,channel);
	WritePackCell(data,ent);
	if(delay > 0.0 ) {
		CreateTimer( delay, Timer_StopGameSound, data, TIMER_FLAG_NO_MAPCHANGE );
	} else {
		Timer_StopGameSound( INVALID_HANDLE, data );
	}
}

public Action:Timer_StopGameSound( Handle:timer, any:data ) {
	ResetPack(data);
	decl String:sample[256];
	ReadPackString( data, sample, sizeof sample );
	new channel = ReadPackCell(data);
	new ent = ReadPackCell(data);
	CloseHandle(data);
	
	if( ent == 0 ) {
		for( new i = 1; i <= MaxClients; i++ ) {
			if( !IsClientInGame(i) ) continue;
			if( IsFakeClient(i) ) continue;
			
			StopSound(i, channel, sample );
			
		}
	} else {
		StopSound(ent, channel, sample );
	}

	return Plugin_Handled;
}


public Action:Piggybacking_OnUse( client ) {
	if( player_riding_boat[client] != -1 ) return Plugin_Handled;
	if( player_using_cannon[client] ) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:OnClientWeaponCanUse( client, weapon ) {
	decl String:name[64];
	GetEntityClassname( weapon, name, sizeof name );
	if( StrEqual(name,"weapon_molotov") ) {
		new ammo_molotov	= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_MOLOTOV );
		if(ammo_molotov != 0) {
			// prevent picking up multiple mollys
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}