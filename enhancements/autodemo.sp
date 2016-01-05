#include <sourcemod>
#include <sdktools>
#include <cURL>

#undef REQUIRE_PLUGIN

#include <updater>

#pragma semicolon 1

// 2.2.5
//  disable hiberation during demo upload
// 2.2.3
//  additional diagnostic support
// 2.2.2
//  show index for upload failures
//  doubled transfer timeout
// 2.2.1
//  delete successfully uploaded demos
// 2.2.0
//  robustify uploading
// 2.1.2
//  errorlog improvement
// 2.1.1
//   improved log support
// 2.1.0
//   workshop map fix
// 2.0.1
//   increased time before checking for a new log file
// 2.0.0
//   now using autodemo 2.0 web interface
//   splitting and packaging of log files
//   more robust recording 
//   
// 1.0.7 
//   limit transfer speed
// 1.0.4
//   sm_demo for players to save demo names
//1.0.3
//   exclude bots 

#define VERSION "2.2.5"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "autodemo",
	author = "mukunda",
	description = "Record and upload SourceTV demos.",
	version = VERSION,
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
new Handle:autodemo_version;	// public cvar
new Handle:autodemo_minplayers;	// convar for minimum human players required for recording
new Handle:autodemo_enabled; 	// should demos be recorded
new c_minplayers;		 		// cached values
new c_enabled;				 	// 

new String:g_logfile[128];

new String:game_name[16];

new String:demo_path[128];	// path to "sm/data/demos"

new bool:demo_active;		// is demo currently recording
new demo_time;				// timestamp of demo start
new String:demo_name[128];	// name of demo, ie "auto-server-030114-203000-cs_office"
//new String:demo_date[64];	// in the format that is used by the web side (removed)
new Float:demo_active_time;	// last game time the game was confirmed to have people playing
new Float:demo_start_time;	// game time when the demo was started
new bool:demo_save = false;

new demo_scores[2];			// saved endround scores

new bool:demo_info_created;		// 

new String:ftp_url[256];			// url to demo directory
new String:ftp_auth[128];			// FTP authentication

new String:site_url[256];			// http path to site
new String:site_key[64];			// key for web api
new String:server_identifier[64];	// name of server for web api
  
#define ACTIVE_THRESHOLD 300.0 

new CURLDefaultOpt[][2] = {
	{_:CURLOPT_NOSIGNAL,		1},		// use for threaded operation
	{_:CURLOPT_NOPROGRESS,		1},		// no progress callback (unsupported)
	{_:CURLOPT_CONNECTTIMEOUT,	60},	//
	{_:CURLOPT_VERBOSE,			0}		//
}; 

new curl_timeout = 1800; // 30 minute timeout on demo upload
new String:curl_transfer_limit[32] = "300000";

new g_save_all;
new g_result_index;

new g_hibernate;
 
#define UPDATE_URL "http://www.mukunda.com/plagins/autodemo/update.txt"

//-------------------------------------------------------------------------------------------------
KvSetHandle( Handle:kv, const String:key[], Handle:value ) {
	KvSetNum( kv, key, _:value );
}

//-------------------------------------------------------------------------------------------------
Handle:KvGetHandle( Handle:kv, const String:key[] ) {
	return Handle:KvGetNum( kv, key, _:INVALID_HANDLE );
}

//-------------------------------------------------------------------------------------------------
bool:TryDeleteFile( const String:file[] ) {
	if( FileExists(file) ) {
		LogToFile( g_logfile, "Deleting \"%s\" ...", file );
		return DeleteFile(file);
	}
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldv[], const String:newv[] ) {
	if( cvar == autodemo_minplayers ) {
		c_minplayers = GetConVarInt( autodemo_minplayers );
	} else if( cvar == autodemo_enabled ) {
		c_enabled = GetConVarInt( autodemo_enabled );
		
		if( c_enabled == 0 ) {
			StopDemo();
		} else {
			TryStartDemo();
		}
	}
}
  
//-------------------------------------------------------------------------------------------------
LoadConfig() {
	new Handle:kv = CreateKeyValues( "AutoDemo" );
	decl String:configpath[256];
	BuildPath( Path_SM, configpath, sizeof(configpath), "configs/autodemo.txt" );
	if( !FileExists( configpath ) ) {
		SetFailState( "Missing configuration file: %s", configpath );
	}
	if( !FileToKeyValues( kv, configpath ) ) {
		SetFailState( "Error loading configuration file." );
	}
	
	KvGetString( kv, "ftp", ftp_url, sizeof ftp_url );
	if( ftp_url[0] != 0 ) {
		if( ftp_url[strlen(ftp_url)-1] != '/' ) {
			StrCat( ftp_url, sizeof ftp_url, "/" );
		}
	} else {	
		SetFailState( "Config missing FTP address." );
	}
	decl String:username[256];
	decl String:password[256];
	KvGetString( kv, "username", username, sizeof username );
	if( username[0] == 0 ) SetFailState( "Config missing FTP username." );
	KvGetString( kv, "password", password, sizeof password );
	Format( ftp_auth, sizeof ftp_auth, "%s:%s", username, password );
	
	
	KvGetString( kv, "server", server_identifier, sizeof server_identifier );
	if( server_identifier[0] == 0 ) SetFailState( "Config missing server identifier." );
	KvGetString( kv, "site", site_url, sizeof site_url );
	if( site_url[0] == 0 ) SetFailState( "config missing site url" );	
	if( site_url[strlen(site_url)-1] != '/' ) {
		StrCat( site_url, sizeof site_url, "/" );
	}
	KvGetString( kv, "key", site_key, sizeof site_key ); 
	
	KvGetString( kv, "transferlimit", curl_transfer_limit, sizeof curl_transfer_limit, "300000" ); 
	curl_timeout = KvGetNum( kv, "transfertimeout", 1200 ); 
	g_save_all = KvGetNum( kv, "saveall", 1 );
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	BuildPath( Path_SM, g_logfile, sizeof g_logfile, "logs/autodemo.log" );
	
	decl String:gamedir[32];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual( gamedir, "tf", false ) ) {
		game_name = "tf2";
	} else if( StrEqual( gamedir, "csgo", false ) ) {
		game_name = "csgo";
	} else {
		game_name = "idk";
	}
	
	LoadConfig();
	BuildPath( Path_SM, demo_path, sizeof(demo_path), "data/demos/" );
	if( !DirExists(demo_path) ) {
		CreateDirectory( demo_path, ((FPERM_O_READ|FPERM_O_EXEC)|(FPERM_G_EXEC|FPERM_G_READ)|(FPERM_U_EXEC|FPERM_U_WRITE|FPERM_U_READ)) );
	}
	CleanupDemos();
	
	autodemo_version = CreateConVar( "autodemo_version", VERSION, "AutoDemo Plugin Version", FCVAR_PLUGIN|FCVAR_NOTIFY );
	SetConVarString( autodemo_version, VERSION );
	
	autodemo_minplayers = CreateConVar( "autodemo_minplayers", "4", "Number of human players required for automatic demo recording", FCVAR_PLUGIN );
	autodemo_enabled = CreateConVar( "autodemo_enabled", "1", "Enable AutoDemo", FCVAR_PLUGIN );
	HookConVarChange( autodemo_minplayers, OnConVarChanged );
	HookConVarChange( autodemo_enabled, OnConVarChanged );
	c_minplayers = GetConVarInt( autodemo_minplayers );
	c_enabled = GetConVarInt( autodemo_enabled );
	
	HookEvent( "cs_match_end_restart", OnMatchRestart, EventHookMode_PostNoCopy );
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	HookEvent( "cs_intermission", OnIntermission, EventHookMode_PostNoCopy );
	HookEvent( "player_team", OnPlayerTeam, EventHookMode_PostNoCopy );
	
	// 5 minute timer to stop recordings where the round doesn't end
	CreateTimer(300.0, Timer_Update, _, TIMER_REPEAT); 
	if( LibraryExists("updater") ) {
		Updater_AddPlugin(UPDATE_URL);
	}
	
	RegConsoleCmd( "sm_demo", Command_demo ); 
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) { 
	if( StrEqual( name, "updater" ) ) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

//-------------------------------------------------------------------------------------------------
CleanupDemos() {
	
	new Handle:dir = OpenDirectory( demo_path );	
	decl String:entry[128];
	new FileType:ft;
	new time = GetTime();
	new total = 0;
	
	while( ReadDirEntry( dir, entry, sizeof entry, ft ) ) {
		if( ft != FileType_File ) continue;
		decl String:path[256];
		Format( path, sizeof path, "%s%s", demo_path, entry );
		
		if( (time - GetFileTime( path, FileTime_LastChange )) > (60*60*12) ) {
			total++;
			DeleteFile( path );
		}
	}
	
	if( total > 0 ) {
		LogToFile( g_logfile, "Cleaned up %d demo files.", total );
	}
	CloseHandle( dir );
}

//-------------------------------------------------------------------------------------------------
GetNumClients() {
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		if( GetClientTeam(i) < 2 ) continue;
		count++;
	}
	return count;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_Update( Handle:timer ) {
	// timer to catch situation where demo is running and nobody is playing
	
	if( !demo_active ) return Plugin_Continue;
	
	// demo_active_time is reset every round
	// exit if the game is known to be active recently
	//
	if( GetGameTime() - demo_active_time < ACTIVE_THRESHOLD ) return Plugin_Continue;
	new active_clients = GetNumClients();
	if( active_clients >= c_minplayers ) {
		demo_active_time = GetGameTime();
		return Plugin_Continue;
	}

	StopDemo(); // demo is inactive and should be terminated!
	
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
bool:TryStartDemo() {
	if( !c_enabled ) return false; 
	// if clients > minplayers, start demo (if not already started) and update active time
	new active_clients = GetNumClients();
	if( active_clients >= c_minplayers ) { 
		StartDemo();
		demo_active_time = GetGameTime();
		return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !c_enabled ) return; 
	if( !TryStartDemo() ) {
		if( GetGameTime() - demo_active_time < ACTIVE_THRESHOLD ) return; 
		StopDemo();
	}
}

//-------------------------------------------------------------------------------------------------
public OnPlayerTeam( Handle:event, const String:name[], bool:dontBroadcast ) {
	// this function is basically no load to the server since it blocks itself once the demo starts
	// and the demo starts once a few people join the server
	if( demo_active ) return;
	if( !c_enabled ) return;
	TryStartDemo();
}

//-------------------------------------------------------------------------------------------------
public OnMatchRestart( Handle:event, const String:name[], bool:db ) {
	StopDemo();
}

//-------------------------------------------------------------------------------------------------
public OnMapEnd() {
	StopDemo();
}

//-------------------------------------------------------------------------------------------------
ResetLogging() {
	ServerCommand( "log 0; log 1;" );
}
  
//-------------------------------------------------------------------------------------------------
FindLogFile( String:str[], maxlen ) { 
	// find and save which file in the logs dir is the newest
	decl String:logpath[128];
	GetConVarString( FindConVar( "sv_logsdir" ), logpath, sizeof logpath );
	
	new Handle:dir = OpenDirectory( logpath );
	decl String:file[128];
	new FileType:ft;
	new time = 0;
	while( ReadDirEntry( dir, file, sizeof file, ft ) ) {
		if( ft != FileType_File ) continue;
		decl String:path[128];
		FormatEx( path, sizeof path, "%s/%s", logpath, file );
		new filetime = GetFileTime( path, FileTime_Created );
		
		if( filetime > time ) {
			time = filetime;
			strcopy( str, maxlen, file );
		}
	}
	CloseHandle(dir);
	Format( str, maxlen, "%s/%s", logpath, str ); 
}

//-------------------------------------------------------------------------------------------------
StartDemo() {
	if( demo_active ) return;
	
	ResetLogging();
	
	decl String:time[32], String:map[32];
	demo_time = GetTime();
	GetCurrentMap( map, sizeof(map) );
	{
		ReplaceString( map, sizeof map, "\\", "/" );
		new pos = FindCharInString( map, '/', true );
		if( pos != -1 ) {
			strcopy( map, sizeof map, map[pos+1] );
		}
	}
	decl String:date[64];
	FormatTime( date, sizeof date, "%m%d%y", demo_time );
	FormatTime( time, sizeof time, "%H%M%S", demo_time );
	Format( time, sizeof time, "%s-%s", date, time );
	Format( demo_name, sizeof(demo_name), "auto-%s-%s-%s", server_identifier, time, map );
	ServerCommand( "tv_record \"%s%s\"", demo_path, demo_name );
	demo_start_time = GetGameTime();
	demo_active = true;
	demo_info_created = false;
	demo_save = false;

	PrintToChatAll( "Recording Demo... %s.dem", demo_name );
	LogToFile( g_logfile, "Started recording \"%s.dem\".", demo_name );
}
 
//-------------------------------------------------------------------------------------------------
CreateDemoInfo() {
	if( demo_info_created ) return;
	demo_info_created = true;
	
	demo_scores[0] = GetTeamScore(3);
	demo_scores[1] = GetTeamScore(2);
}

//-------------------------------------------------------------------------------------------------
StopDemo() {
	if( !demo_active ) return;
	
	decl String:logfile[256];
	FindLogFile( logfile, sizeof logfile );
	ResetLogging();
	
	ServerCommand("tv_stoprecord");
	demo_active = false;
	
	LogToFile( g_logfile, "Stopped recording \"%s.dem\".", demo_name );
	
	if( !g_save_all && !demo_save ) {
		return; // nobody requested this demo to be saved, discard.
	}
	
	// upload to webserver
	new Float:duration = GetGameTime() - demo_start_time;
	
	// demo info is usually created during the intermission, this is a failsafe
	CreateDemoInfo(); 
	
	new Handle:op = CreateKeyValues( "AutoDemoUpload" );
	
	KvSetNum( op, "file_index", 0 );
	KvSetString( op, "name", demo_name );
	KvSetString( op, "logfile", logfile );
	KvSetNum( op, "time", demo_time );
	KvSetFloat( op, "duration", duration );
	KvSetNum( op, "score0", demo_scores[0] );
	KvSetNum( op, "score1", demo_scores[1] );
	KvSetNum( op, "retries", 0 );

	g_hibernate = GetConVarInt( FindConVar( "sv_hibernate_when_empty" ))
	SetConVarInt( FindConVar( "sv_hibernate_when_empty" ), 0 )
	
	CreateTimer( 2.0, StartTransfer, op );
}

//-------------------------------------------------------------------------------------------------
public Action:StartTransfer( Handle:timer, any:data ) {
	DemoUpload(data);
	return Plugin_Handled;
} 

//-------------------------------------------------------------------------------------------------
DemoUpload( Handle:op ) {
	
	new Handle:curl = curl_easy_init();
	curl_easy_setopt_int_array( curl, CURLDefaultOpt, sizeof( CURLDefaultOpt ) );
	curl_easy_setopt_int( curl, CURLOPT_TIMEOUT, curl_timeout );
	curl_easy_setopt_int64( curl, CURLOPT_MAX_SEND_SPEED_LARGE, curl_transfer_limit );
 
	
	new index = KvGetNum( op, "file_index" ); 
	decl String:name[256];
	KvGetString( op, "name", name, sizeof name );
	
	if( index == 2 ) {
		decl String:request[512]; 
		  
		FormatEx( request, sizeof request, 
			"%sregister.php?key=%s&server=%s&game=%s&demo=%s&score=%d-%d&time=%d&duration=%.2f", 
			site_url, site_key,
			server_identifier, game_name,
			name, 
			KvGetNum( op, "score0" ), KvGetNum( op, "score1" ),
			KvGetNum( op, "time" ),
			KvGetFloat( op, "duration" ) );
		
		curl_easy_setopt_string( curl, CURLOPT_URL, request );
		
		decl String:resultfile[128];
		FormatEx( resultfile, sizeof resultfile, "%sresult%d", demo_path, g_result_index++ );
		new Handle:outfile = curl_OpenFile( resultfile, "wb" );
		curl_easy_setopt_handle( curl, CURLOPT_WRITEDATA, outfile );
		
		LogToFile( g_logfile, "Registering: %s ...", name );
		PrintToServer( "[autodemo] Registering demo: %s", name );
		KvSetHandle( op, "file", outfile );
		KvSetString( op, "resultfile", resultfile );
		curl_easy_perform_thread( curl, OnCurlComplete, op );
		
	} else {
		curl_easy_setopt_string( curl, CURLOPT_USERPWD, ftp_auth );
		curl_easy_setopt_int( curl, CURLOPT_UPLOAD, 1 );
		curl_easy_setopt_int( curl, CURLOPT_FTP_CREATE_MISSING_DIRS, CURLFTP_CREATE_DIR );
		
		decl String:source[128];
		decl String:dest[256];
		if( index == 0 ) {
			
			FormatEx( source, sizeof source, "%s%s.dem", demo_path, name );
			FormatEx( dest, sizeof dest, "%s%s.dem", ftp_url, name );
			
		} else {
			KvGetString( op, "logfile", source, sizeof source );
			FormatEx( dest, sizeof dest, "%s%s.log", ftp_url, name );
			
		}
		new Handle:infile = curl_OpenFile( source, "rb" );
		if( infile == INVALID_HANDLE ) {
			CloseHandle(curl);
			CloseHandle(op);
			LogToFile( g_logfile, "Couldn't open \"%s\" for upload!", source );
			return;
		}
		
		LogToFile( g_logfile, "Uploading: %s ...", source );
		PrintToServer( "[autodemo] Uploading file: %s", source );
		KvSetHandle( op, "file", infile );
		
		curl_easy_setopt_handle( curl, CURLOPT_READDATA, infile );
		curl_easy_setopt_string( curl, CURLOPT_URL, dest );
		curl_easy_perform_thread( curl, OnCurlComplete, op );
	}
}

//-------------------------------------------------------------------------------------------------
bool:CheckRegistration( Handle:curl, Handle:op ) {
	decl String:resultfile[128];
	KvGetString( op, "resultfile", resultfile, sizeof resultfile ); 
	
	new response;
	curl_easy_getinfo_int( curl, CURLINFO_RESPONSE_CODE, response );
	if( response != 200 ) { // 200 is HTTP_RESPONSE_OK
		TryDeleteFile( resultfile );
		return false;
	}
	
	// verify registration:
	new Handle:file = OpenFile( resultfile, "r" );
	decl String:result[256];
	result[0] = 0;
	ReadFileLine( file, result, sizeof result );
	CloseHandle(file); 
	
	TrimString( result );
	if( !StrEqual( result, "OK" ) ) {
		if( result[0] != 0 ) {
			LogToFile( g_logfile, "Result file contained \"%s\".", result );
		} else {
			LogToFile( g_logfile, "Result file was empty." );
		}
		return false;
	}
	return true;
}

//-------------------------------------------------------------------------------------------------
DeleteDemo( Handle:op ) {
	decl String:demo[256];
	KvGetString( op, "name", demo, sizeof demo );
	Format( demo, sizeof demo, "%s%s.dem", demo_path, demo );
	TryDeleteFile( demo );
}

//-------------------------------------------------------------------------------------------------
public OnCurlComplete( Handle:hndl, CURLcode:code, any:data ) {
	new Handle:op = data;
	
	new index = KvGetNum( op, "file_index" );
	CloseHandle( KvGetHandle( op, "file" ) );
	decl String:name[256];
	KvGetString( op, "name", name, sizeof name );
		
	if( code == CURLE_OK ) {
		if( index == 2 ) {
			
			if( !CheckRegistration( hndl, op ) ) {
				CloseHandle(hndl);
				
				if( !CanRetryTransfer(op) ) {
					LogToFile( g_logfile, "Couldn't register demo on site: \"%s\". Giving up.", name );
					CloseHandle(op);

					SetConVarInt( FindConVar( "sv_hibernate_when_empty" ), g_hibernate )
					return;
				} else {
					LogToFile( g_logfile, "Registration failed for \"%s\". Retrying...", name );
				}
				
				// retry
				DemoUpload( op );
				return;
			}
			CloseHandle(hndl);
			
			DeleteDemo(op);
			CloseHandle(op);
			
			SetConVarInt( FindConVar( "sv_hibernate_when_empty" ), g_hibernate )
			return; // operation complete
		}
		
		index = index + 1;
		KvSetNum( op, "file_index", index );
		
		DemoUpload( op );
		
	} else {
		CloseHandle(hndl);
		if( !CanRetryTransfer( op ) ) {
			LogToFile( g_logfile, "Upload failure for: \"%s\" (index %d). code %d. Giving up.", name, index, code );
			CloseHandle(op);

			SetConVarInt( FindConVar( "sv_hibernate_when_empty" ), g_hibernate )
			return;
		} else {
			LogToFile( g_logfile, "Upload failure for: \"%s\" (index %d). code %d. Retrying...", name, index, code );
		}
		
		DemoUpload(op);
	}
}

//-------------------------------------------------------------------------------------------------
bool:CanRetryTransfer( Handle:op ) {
	new retries = KvGetNum( op, "retries" );
	if( retries < 3 ) {
		KvSetNum( op, "retries", retries+1 );
		return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
public OnIntermission( Handle:event, const String:name[], bool:db ) {
	if( demo_active && (g_save_all || demo_save) ) {
		// tell users that their match was saved
		PrintToChatAll( "Saving Demo... %s.dem", demo_name );
	}
	CreateDemoInfo();
}

//-------------------------------------------------------------------------------------------------
public Action:Command_demo( client, args ) {
	if( !demo_active ) {
		ReplyToCommand( client, "A demo is not currently being recorded." );
		return Plugin_Handled;
	}
	
	
	ReplyToCommand( client, "Currently recording: %s.dem", demo_name );
	if( !demo_save ) {
		demo_save = true;
		if( !g_save_all ) {
			if( client == 0 ) {
				ReplyToCommand( client, "[AutoDemo] Demo marked for saving." );
			}
			
			PrintToChatAll( "\x01 \x04** Demo marked for saving. **" );
		}
	} else {
		ReplyToCommand( client, "This demo will be uploaded after the match completes." );
	}
	
	
	return Plugin_Handled;
}
