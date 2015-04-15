#include <sourcemod>
#include <sdktools>
#include <rxgcommon>

#undef REQUIRE_PLUGIN
#include <rxgstore> 

#pragma semicolon 1
#pragma newdecls required
  
//-----------------------------------------------------------------------------
public Plugin myinfo = { 

	name        = "radio",
	author      = "mukunda",
	description = "digital entertainment",
	version     = "1.1.0",
	url         = "www.mukunda.com"
};

//-----------------------------------------------------------------------------

#define RADIO_MODEL "models/props/cs_office/radio.mdl"
#define MAXSONGS 16

char  g_song_file[MAXSONGS][64];
char  g_song_title[MAXSONGS][64];
char  g_song_artist[MAXSONGS][64];
float g_song_duration[MAXSONGS];
int   g_song_count;
 
// variables for controlling the song on the map-spawned radio
bool  g_map_spawn = false;     // true if the map-spawned radio is defined
float g_map_spawn_position[3]; // position to spawn the radio
int   g_map_health;            // health to give the radio
int   g_songs_change;          // cached "change" in config
int   g_round_counter;         // round counter for rotating songs 
int   g_song_map_current;      // currently selected song


int GAME;

#define GAME_CSGO  0
#define GAME_CSS   1
#define GAME_TF2   2
 
//-----------------------------------------------------------------------------
#define ITEMID 2  // rxg-store item id

Menu g_song_menu = null; // song selection menu

//-----------------------------------------------------------------------------
int g_radio_song[2048]; // (entity data) the song index a radio will play
 
//-----------------------------------------------------------------------------
public void OnPluginStart() {

	char gamedir[16];
	GetGameFolderName( gamedir, sizeof gamedir );
	
	if( StrEqual( gamedir, "csgo", false )) {
		GAME = GAME_CSGO;
	} else if( StrEqual( gamedir, "cstrike", false )) {
		GAME = GAME_CSS;
	} else {
		SetFailState( "Game not supported." );
	}
	
	HookEvent( "round_start", OnRoundStart );
	
	RegAdminCmd( "sm_spawnradio", Command_spawnradio, ADMFLAG_RCON );
	
	if( LibraryExists( "rxgstore" ) ) {
		RXGSTORE_RegisterItem( "radio", ITEMID, "disposable radio" );
	}
}

//-----------------------------------------------------------------------------
public void OnPluginEnd() {
	if( LibraryExists( "rxgstore" ) ) {
		RXGSTORE_UnregisterItem( ITEMID );
	}
}

//-----------------------------------------------------------------------------
public void OnLibraryAdded( const char[] name ) {
	if( StrEqual( name, "rxgstore" )) {
		RXGSTORE_RegisterItem( "radio", ITEMID, "disposable radio" );
	}
} 

//-----------------------------------------------------------------------------
void LoadConfig() {
	g_map_spawn = false;
	
	KeyValues kv = CreateKeyValues( "Radio" );
	char path[256];
	BuildPath( Path_SM, path, sizeof path, "configs/radio.txt" );
	
	kv.ImportFromFile( path );
	
	int songs_permap = kv.GetNum( "permap" );
	g_songs_change   = kv.GetNum( "change" );
	
	if( songs_permap == 0        ) SetFailState( "No songs." );
	if( !kv.JumpToKey( "songs" ) ) SetFailState( "No songs." );
	if( !kv.GotoFirstSubKey()    ) SetFailState( "No songs." );
	
	ArrayList keys = CreateArray();
	do {
		int id;
		kv.GetSectionSymbol( id );
		keys.Push( id );
	} while kv.GotoNextKey();
	
	kv.GoBack();
	 
	// shuffle song list
	for( int i = keys.Length - 1; i >= 1; i-- ) {
		int j = GetRandomInt( 0, i );
		int id = keys.Get(i);
		keys.Set( i, keys.Get(j) );
		keys.Set( j, id );
	}
	g_song_count = intmin( songs_permap, keys.Length );
	
	for( int i = 0; i < g_song_count; i++ ) {
	
		kv.JumpToKeySymbol( keys.Get(i) );
		kv.GetString( "file",   g_song_file[i],   sizeof g_song_file[]   );
		kv.GetString( "title",  g_song_title[i],  sizeof g_song_title[]  );
		kv.GetString( "artist", g_song_artist[i], sizeof g_song_artist[] );
		g_song_duration[i] = kv.GetFloat( "duration" );
		kv.GoBack();
	}
	delete keys;
	
	kv.Rewind();
	
	if( kv.GetNum( "spawnonmap" )) {
	
		g_map_health = kv.GetNum( "maphealth", 1 );
		kv.JumpToKey( "mapspawns" );
		
		char map[64];
		GetCurrentMap( map, sizeof map );
		
		kv.GetVector( map, g_map_spawn_position );
 
		if( g_map_spawn_position[0] != 0.0 
		    || g_map_spawn_position[1] != 0.0 
		    || g_map_spawn_position[2] != 0.0 ) {
		    
			g_map_spawn = true;
		}
		
		kv.Rewind();
	}
	
	delete kv;
	
	BuildSongMenu();
}

/** ---------------------------------------------------------------------------
 * Build/rebuild the menu used by players to select the song they want.
 */
void BuildSongMenu() {
	if( g_song_menu != null ) delete g_song_menu;
	
	g_song_menu = CreateMenu( SongMenuHandler );
	g_song_menu.SetTitle( "Select a song" );
	
	char info[16], display[64];
	for( int i = 0; i < g_song_count; i++ ) {
		FormatEx( info,    sizeof info,    "%d", i );
		FormatEx( display, sizeof display, "%s - %s", 
		          g_song_title[i], g_song_artist[i] );
		          
		g_song_menu.AddItem( info, display );
	}
	
}

//-----------------------------------------------------------------------------
public void OnMapStart() {
	LoadConfig();
	PrecacheModel( RADIO_MODEL );
	g_song_map_current = 0;
	
	char download[128];
	for( int i = 0; i < g_song_count; i++ ) {
		
		FormatEx( download, sizeof download, "sound/rxg/radio/%s", 
				  g_song_file[i] );
				  
		AddFileToDownloadsTable( download );
		
		Format( g_song_file[i], sizeof g_song_file[], "%srxg/radio/%s", 
				GAME==GAME_CSGO?"*":"", g_song_file[i] );
				
		PrecacheSound( g_song_file[i] );
	}
	
	OnRoundStart( null, "", false );
}

//-----------------------------------------------------------------------------
public Action OnRoundStart( Handle event, const char[] name, bool nb ) {

	if( g_map_spawn ) {
	
		g_round_counter++;
		if( g_round_counter >= g_songs_change ) {
			g_round_counter = 0;
			g_song_map_current++;
			if( g_song_map_current >= g_song_count ) { 
				g_song_map_current = 0;
			}
		}
		SpawnRadio( g_map_spawn_position, g_map_health, g_song_map_current );
	}
}

//-----------------------------------------------------------------------------
public Action OnLoopTimer( Handle timer, int entref ) {
	
	if( !IsValidEntity( entref )) return Plugin_Stop;
	int ent = EntRefToEntIndex(entref);
	
	EmitSoundToAll( g_song_file[g_radio_song[ent]], ent );
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public void OnRadioUse( const char[] output, int caller, int activator, 
                        float delay ) {
                        
	EmitSoundToAll( g_song_file[g_radio_song[caller]], caller );
	CreateTimer( g_song_duration[g_radio_song[caller]], OnLoopTimer, 
	             EntIndexToEntRef(caller), TIMER_REPEAT );
}

//-----------------------------------------------------------------------------
public void OnRadioBreak( const char[] output, int caller, int activator, 
                          float delay ) {
                          
	// stop twice to account for loop point area 
	// (it may have two sounds active briefly)
	StopSound( caller, SNDCHAN_AUTO, g_song_file[g_radio_song[caller]] );
	StopSound( caller, SNDCHAN_AUTO, g_song_file[g_radio_song[caller]] );
}
  
/** ---------------------------------------------------------------------------
 * Spawn a radio.
 *
 * @param position Position in space to spawn the radio.
 * @param HP       Health to assign to the radio.
 * @param song     Index in song list to play, the song list is created
 *                 when the map loads.
 */
void SpawnRadio( float position[3], int HP, int song ) { 

	char health[8];
	FormatEx( health, sizeof health, "%d", HP );
	
	int ent = CreateEntityByName( "prop_physics_multiplayer" );
	
	DispatchKeyValue( ent, "model",      RADIO_MODEL );
	DispatchKeyValue( ent, "targetname", "office_radio_2k15" );
	DispatchKeyValue( ent, "health",     health );
	DispatchKeyValue( ent, "spawnflags", "256" ); // +usable
	
	DispatchSpawn( ent );
	
	// we set this twice for some reason.
	SetEntProp( ent, Prop_Data, "m_iHealth", HP );
	
	g_radio_song[ent] = song;
	
	HookSingleEntityOutput( ent, "OnPlayerUse", OnRadioUse,   true );
	HookSingleEntityOutput( ent, "OnBreak",     OnRadioBreak, true );

	TeleportEntity( ent, position, NULL_VECTOR, NULL_VECTOR );
}

/** ---------------------------------------------------------------------------
 * Spawn a radio in front of a player.
 *
 * @param client Client to spawn in front of.
 * @param song   Song to play.
 * @param hp     HP of radio.
 */
void SpawnRadioAtPlayer( int client, int song, int hp ) {
	float pos[3];
	GetClientEyePosition( client, pos );
	float vec[3];
	GetClientEyeAngles( client, vec );
	GetAngleVectors( vec, vec, NULL_VECTOR, NULL_VECTOR );
	vec[2] = 0.0;
	NormalizeVector(vec,vec);
	vec[0] *= 20.0;
	vec[1] *= 20.0;
	AddVectors( pos, vec, pos );
	SpawnRadio( pos, hp, song );
}

//-----------------------------------------------------------------------------
public Action Command_spawnradio( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnRadioAtPlayer( client, GetRandomInt( 0, g_song_count-1 ), 1 );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public bool RXGSTORE_OnUse( int client ) {
	if( !IsPlayerAlive(client) ) return false;
	DisplayMenu( g_song_menu, client, 30 );
	return false;
}

//-----------------------------------------------------------------------------
public int SongMenuHandler( Menu menu, MenuAction action, 
                             int client, int param2 ) {
                             
	if( action == MenuAction_Select)  {
		char info[8];
		GetMenuItem( menu, param2, info, sizeof info );
		
		// make sure the item is still available.
		if( RXGSTORE_CanUseItem( client, ITEMID ) ) {
			
			RXGSTORE_UseItem( client, ITEMID );
			SpawnRadioAtPlayer( client, StringToInt( info ), 500 );
		}
	}
}
