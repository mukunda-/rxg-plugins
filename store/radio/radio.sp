 
#include <sourcemod>
#include <sdktools> 

#undef REQUIRE_PLUGIN
#include <rxgstore> 

#pragma semicolon 1
  
//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
//-------------------------------------------------------------------------------------------------
	name = "radio",
	author = "mukunda",
	description = "digital entertainment",
	version = "1.0.0",
	url="www.mukunda.com"
};
//-------------------------------------------------------------------------------------------------

#define MAXSONGS 16
new String:song_file[MAXSONGS][64];
new String:song_title[MAXSONGS][64];
new String:song_artist[MAXSONGS][64];
new Float:song_duration[MAXSONGS];
new song_count;

new String:radio_model[] = "models/props/cs_office/radio.mdl";
 
new songs_change;
new round_counter;
new song_map_current;

new GAME;

#define GAME_CSGO  0
#define GAME_CSS   1
#define GAME_TF2   2

new Float:mapvec[3];
new bool:mapspawn;
new maphealth;

//-------------------------------------------------------------------------------------------------
//new bool:store;
#define ITEMID 2

new Handle:song_menu = INVALID_HANDLE;

//-------------------------------------------------------------------------------------------------
new radio_song[2048];
 
//-------------------------------------------------------------------------------------------------
public OnPluginStart() { 
	decl String:gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual(gamedir,"csgo",false) ) {
		GAME = GAME_CSGO;
		
	} else if( StrEqual(gamedir,"cstrike",false) ) {
		GAME = GAME_CSS;
	} else {
		SetFailState( "game not supported." );
	}
	HookEvent( "round_start", Event_RoundStart );
	
	RegAdminCmd( "sm_spawnradio", Command_spawnradio, ADMFLAG_RCON );
	
	if( LibraryExists( "rxgstore" ) ) {
		RXGSTORE_RegisterItem( "radio", ITEMID, "disposable radio" );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	if( LibraryExists( "rxgstore" ) ) {
		RXGSTORE_UnregisterItem( ITEMID );
	}
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( "radio", ITEMID, "disposable radio" );
	}
} 

//-------------------------------------------------------------------------------------------------
LoadConfig() {
	mapspawn=false;
	
	new Handle:kv = CreateKeyValues( "Radio" );
	decl String:path[256];
	BuildPath( Path_SM, path, sizeof path, "configs/radio.txt" );
	
	FileToKeyValues( kv, path );
	
	new songs_permap = KvGetNum( kv, "permap" );
	
	songs_change = KvGetNum( kv, "change" );
	
	if( songs_permap == 0 ) SetFailState( "no songs" );
	if( !KvJumpToKey( kv, "songs" ) ) SetFailState( "no songs" );
	if( !KvGotoFirstSubKey(kv) ) SetFailState( "no songs" );
	new Handle:keys = CreateArray();
	do {
		new id;
		KvGetSectionSymbol(kv,id);
		PushArrayCell( keys, id );
	} while KvGotoNextKey(kv);
	KvGoBack(kv);
	
	for( new i = GetArraySize(keys) - 1; i >= 1; i-- ) {
		new j = GetRandomInt( 0, i );
		new id = GetArrayCell( keys, i );
		SetArrayCell( keys, i, GetArrayCell( keys, j ) );
		SetArrayCell( keys, j, id );
	}
	song_count = songs_permap > GetArraySize(keys) ? GetArraySize(keys) : songs_permap;
	
	for( new i = 0; i < song_count; i++ ) {
		KvJumpToKeySymbol( kv, GetArrayCell( keys, i ) );
		KvGetString( kv, "file", song_file[i], sizeof song_file[] );
		KvGetString( kv, "title", song_title[i], sizeof song_title[] );
		KvGetString( kv, "artist", song_artist[i], sizeof song_artist[] );
		song_duration[i] = KvGetFloat( kv, "duration" );
		KvGoBack(kv);
	}
	CloseHandle(keys);
	
	KvRewind(kv);
	
	if( KvGetNum( kv, "spawnonmap" ) ) {
		maphealth = KvGetNum( kv, "maphealth", 1 );
		KvJumpToKey( kv, "mapspawns" );
		decl String:map[64];
		GetCurrentMap( map, sizeof map );
		KvGetVector( kv, map, mapvec );
		if( mapvec[0] != 0.0 || mapvec[1] != 0.0 || mapvec[2] != 0.0 ) {
			mapspawn=true;
		}
		KvRewind(kv);
	}
	
	CloseHandle(kv);
	
	BuildSongMenu();
}

//-------------------------------------------------------------------------------------------------
BuildSongMenu() {
	if( song_menu != INVALID_HANDLE ) CloseHandle( song_menu );
	
	song_menu = CreateMenu( SongMenuHandler );
	SetMenuTitle( song_menu, "Select a song" );
	
	for( new i = 0; i < song_count; i++ ) {
		decl String:info[16], String:display[64];
		FormatEx( info, sizeof info, "%d", i );
		FormatEx( display, sizeof display, "%s - %s", song_title[i], song_artist[i] );
		AddMenuItem( song_menu, info, display );
	}
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	LoadConfig();
	PrecacheModel( radio_model );
	song_map_current = 0;
	
	for( new i = 0; i < song_count; i++ ) {
		decl String:download[128];
		FormatEx( download, sizeof download, "sound/rxg/radio/%s", song_file[i] );
		AddFileToDownloadsTable( download );
		
		Format( song_file[i], sizeof song_file[], "%srxg/radio/%s", GAME==GAME_CSGO?"*":"", song_file[i] );
		PrecacheSound( song_file[i] );
	}
	Event_RoundStart( INVALID_HANDLE, "", false );
}

//-------------------------------------------------------------------------------------------------
public Action:Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {

	if( mapspawn ) {
	
		round_counter++;
		if( round_counter >= songs_change ) {
			round_counter = 0;
			song_map_current++;
			if( song_map_current >= song_count ) 
				song_map_current = 0;
			
		}
		SpawnRadio( mapvec, maphealth, song_map_current );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:OnLoopTimer( Handle:timer, any:entref ) {
	
	if( !IsValidEntity(entref) ) return Plugin_Stop;
	new ent = EntRefToEntIndex(entref);
	
	EmitSoundToAll( song_file[radio_song[ent]], ent );
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public OnRadioUse(const String:output[], caller, activator, Float:delay) { 
	EmitSoundToAll( song_file[radio_song[caller]], caller );
	CreateTimer( song_duration[radio_song[caller]], OnLoopTimer, EntIndexToEntRef(caller), TIMER_REPEAT );
}

//-------------------------------------------------------------------------------------------------
public OnRadioBreak(const String:output[], caller, activator, Float:delay) { 
	// stop twice to account for loop point area
	StopSound( caller, SNDCHAN_AUTO, song_file[radio_song[caller]] );
	StopSound( caller, SNDCHAN_AUTO, song_file[radio_song[caller]] );
}
  
//-------------------------------------------------------------------------------------------------
SpawnRadio( Float:position[3], HP, song ) { 

	decl String:health[16];
	FormatEx( health, sizeof health, "%d", HP );
	
	new ent = CreateEntityByName( "prop_physics_multiplayer" );
	DispatchKeyValue( ent, "model", radio_model );
	DispatchKeyValue( ent, "targetname", "office_radio_2k14" );
	DispatchKeyValue( ent, "health", health );
	DispatchKeyValue( ent, "spawnflags", "256" ); // +usable
	DispatchSpawn( ent );
	
	SetEntProp( ent, Prop_Data, "m_iHealth", HP );
	
	radio_song[ent] = song;
	
	HookSingleEntityOutput( ent, "OnPlayerUse", OnRadioUse, true );
	HookSingleEntityOutput( ent, "OnBreak", OnRadioBreak, true );

	TeleportEntity( ent, position, NULL_VECTOR, NULL_VECTOR);
}

//-------------------------------------------------------------------------------------------------
SpawnRadioAtPlayer( client, song, hp ) {
	decl Float:pos[3];
	GetClientEyePosition( client, pos );
	decl Float:vec[3];
	GetClientEyeAngles( client, vec );
	GetAngleVectors( vec, vec, NULL_VECTOR, NULL_VECTOR );
	vec[2] = 0.0;
	NormalizeVector(vec,vec);
	vec[0] *= 20.0;
	vec[1] *= 20.0;
	AddVectors( pos, vec, pos );
	SpawnRadio( pos, hp, song );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_spawnradio( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnRadioAtPlayer( client, GetRandomInt( 0, song_count-1 ), 1 );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public bool:RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	DisplayMenu( song_menu, client, 30 );
	return false;
}

//-------------------------------------------------------------------------------------------------
public SongMenuHandler(Handle:menu, MenuAction:action, client, param2) {
	if( action == MenuAction_Select)  {
		new String:info[32];
		GetMenuItem( menu, param2, info, sizeof(info) );
		
		if( RXGSTORE_CanUseItem( client, ITEMID ) ) {
			RXGSTORE_UseItem( client, ITEMID );
			SpawnRadioAtPlayer( client, StringToInt( info ), 500 );
		}
	}
}
