#include <sourcemod>
#include <sdktools>
#include <cURL>

#undef REQUIRE_PLUGIN

#include <updater>

#pragma semicolon 1

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

#define VERSION "2.1.2"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "autodemo",
	author = "mukunda",
	description = "record and upload demos",
	version = VERSION,
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
new Handle:autodemo_version;	// public cvar
new Handle:autodemo_minplayers;	// convar for minimum human players required for recording
new Handle:autodemo_enabled; 	// should demos be recorded
new c_minplayers;		 		// cached values
new c_enabled;				 	// 

new String:demo_path[128];	// path to "sm/data/demos"

new bool:demo_active;		// is demo currently recording
new demo_time;				// timestamp of demo start
new String:demo_name[128];	// name of demo, ie "auto-server-030114-203000-cs_office"
//new String:demo_date[64];	// in the format that is used by the web side (removed)
new Float:demo_active_time;	// last game time the game was confirmed to have people playing
new Float:demo_start_time;	// game time when the demo was started

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

new curl_timeout = 600; // 10 minute timeout on demo upload
new String:curl_transfer_limit[32] = "200000";
 
#define UPDATE_URL "http://www.mukunda.com/plagins/autodemo/update.txt"

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
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
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
	while( ReadDirEntry( dir, entry, sizeof entry, ft ) ) {
		if( ft != FileType_File ) continue;
		decl String:path[256];
		Format( path, sizeof path, "%s%s", demo_path, entry );
		DeleteFile( path );
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

	PrintToChatAll( "Recording Demo... %s.dem", demo_name );
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
	// upload to webserver
	new Float:duration = GetGameTime() - demo_start_time;
	
	// demo info is usually created during the intermission, this is a failsafe
	CreateDemoInfo(); 
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, 0 ); // file index  
	WritePackCell( pack, 0 ); // reserved slot for file handle
	WritePackString( pack, demo_name );
	WritePackString( pack, logfile );
	WritePackCell( pack, demo_time );
	WritePackFloat( pack, duration );
	WritePackCell( pack, demo_scores[0] );
	WritePackCell( pack, demo_scores[1] );

	CreateTimer( 2.0, StartTransfer, pack );
}

//-------------------------------------------------------------------------------------------------
public Action:StartTransfer( Handle:timer, any:data ) {
	DemoUpload(data);
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
SkipPackStrings( Handle:pack, count ) {
	decl String:buffer[256];
	for( new i = 0; i < count; i++ ) {
		ReadPackString(pack,buffer,sizeof buffer);
	}
}

//-------------------------------------------------------------------------------------------------
public OnCurlComplete( Handle:hndl, CURLcode:code, any:data ) {
	
	ResetPack(data);
	new index = ReadPackCell( data )+1;
	new Handle:file = Handle:ReadPackCell( data );
	CloseHandle(file);
	decl String:name[256];
	ReadPackString( data, name, sizeof name );
		
	if( code == CURLE_OK ) {
		
		if( index == 3 ) {
			CloseHandle(data);
			new response;
			curl_easy_getinfo_int(hndl,CURLINFO_RESPONSE_CODE,response);
			CloseHandle(hndl);
			if( response != 200 ) { // 200 is HTTP_RESPONSE_OK
				LogError( "Couldn't register demo on site: \"%s\"", name );
				return;
			}
			// verify registration:
			decl String:resultfile[128];
			FormatEx( resultfile, sizeof resultfile, "%sresult", demo_path );
			file = OpenFile( resultfile, "r" );
			decl String:result[64];
			ReadFileLine( file, result, sizeof result );
			TrimString( result );
			if( !StrEqual( result, "OK" ) ) {
				LogError( "Couldn't register demo on site: \"%s\"", name );
			}
			CloseHandle( file );
			
			return; // operation complete
		}
		CloseHandle(hndl);
		
		ResetPack(data);
		WritePackCell(data,index);
		
		DemoUpload(data);
		
	} else {
		CloseHandle(hndl);
		LogError( "Upload failure for: \"%s\". code %d", name, code );
		
		CloseHandle(data);
	}
}

//-------------------------------------------------------------------------------------------------
DemoUpload( Handle:pack ) {
	
	new Handle:curl = curl_easy_init();
	curl_easy_setopt_int_array( curl, CURLDefaultOpt, sizeof( CURLDefaultOpt ) );
	curl_easy_setopt_int( curl, CURLOPT_TIMEOUT, curl_timeout );
	curl_easy_setopt_int64( curl, CURLOPT_MAX_SEND_SPEED_LARGE, curl_transfer_limit );
	if( !curl ) {
		LogError( "Couldn't initialize cURL for uploading: \"%s\"", demo_name );
		return;
	}
	
	ResetPack(pack);
	new index = ReadPackCell( pack ); 
	ReadPackCell( pack ); 
	decl String:name[256];
	ReadPackString( pack, name, sizeof name );
		
	if( index == 2 ) {
		decl String:request[512];
		SkipPackStrings(pack,1); // skip logfile string
		new time = ReadPackCell( pack );
		new Float:duration = ReadPackFloat( pack );
		new scores[2];
		scores[0] = ReadPackCell(pack);
		scores[1] = ReadPackCell(pack);
		FormatEx( request, sizeof request, 
			"%sregister.php?key=%s&server=%s&demo=%s&score=%d-%d&time=%d&duration=%.2f", 
			site_url, site_key,
			server_identifier,
			name, 
			demo_scores[0], demo_scores[1],
			time,
			duration );
		//PrintToServer( "DEBUG: register=%s", request );
		curl_easy_setopt_string( curl, CURLOPT_URL, request );
		FormatEx( request, sizeof request, "%sresult", demo_path );
		decl String:resultfile[128];
		FormatEx( resultfile, sizeof resultfile, "%sresult", demo_path );
		new Handle:outfile = curl_OpenFile( resultfile, "wb" );
		curl_easy_setopt_handle( curl, CURLOPT_WRITEDATA, outfile );
		
		PrintToServer( "[autodemo] Registering demo: %s", name );
		ResetPack(pack);
		ReadPackCell(pack);
		WritePackCell( pack, _:outfile );
		curl_easy_perform_thread( curl, OnCurlComplete, pack );
		
	} else {
		curl_easy_setopt_string( curl, CURLOPT_USERPWD, ftp_auth );
		curl_easy_setopt_int( curl, CURLOPT_UPLOAD, 1 );
		curl_easy_setopt_int( curl, CURLOPT_FTP_CREATE_MISSING_DIRS, CURLFTP_CREATE_DIR );
		
		decl String:source[128];
		decl String:dest[128];
		if( index == 0 ) {
			
			FormatEx( source, sizeof source, "%s%s.dem", demo_path, name );
			FormatEx( dest, sizeof dest, "%s%s.dem", ftp_url, name );
			
		} else {
			ReadPackString( pack, source, sizeof source );
			FormatEx( dest, sizeof dest, "%s%s.log", ftp_url, name );
			
		}
		new Handle:infile = curl_OpenFile( source, "rb" );
		if( infile == INVALID_HANDLE ) {
			CloseHandle(curl);
			LogError( "Couldn't open \"%s\" for upload.", source );
			return;
		}
		
		PrintToServer( "[autodemo] Uploading file: %s", source );
		ResetPack(pack);
		ReadPackCell(pack);
		WritePackCell( pack, _:infile );
		curl_easy_setopt_handle( curl, CURLOPT_READDATA, infile );
		curl_easy_setopt_string( curl, CURLOPT_URL, dest );
		curl_easy_perform_thread( curl, OnCurlComplete, pack );
	}
}

//-------------------------------------------------------------------------------------------------
public OnIntermission( Handle:event, const String:name[], bool:db ) {
	if( demo_active ) {
		// tell users that their match was saved
		PrintToChatAll( "Saving Demo... %s.dem", demo_name );
		CreateDemoInfo();
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_demo( client, args ) {
	if( !demo_active ) {
		ReplyToCommand( client, "A demo is not being recorded currently." );
		return Plugin_Handled;
	}
	
	ReplyToCommand( client, "Currently recording: %s.dem", demo_name );
	return Plugin_Handled;
}
