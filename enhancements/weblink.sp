
#include <sourcemod>
#include <rxgstore>
#include <dbrelay>
#include <rxgcommon>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "RXG Web Links",
    author      = "WhiteThunder",
    description = "",
    version     = "0.1",
    url         = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------

// weblink config
KeyValues kv_config;

char g_database[65];
char g_url[256];

// the ip for this server (hostip converted into ipv4 format)
char c_ip[32];

int g_session_id[MAXPLAYERS];
int g_session_token[MAXPLAYERS];

//-----------------------------------------------------------------------------
int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

//-----------------------------------------------------------------------------
public APLRes AskPluginLoad2( Handle myself, bool late, char[] error, int err_max ) {
	CreateNative( "WEBLINK_OpenUrl", Native_OpenUrl );
	RegPluginLibrary("weblink");
}

//-----------------------------------------------------------------------------
public void OnClientDisconnect( int client ) {
	g_session_id[client] = 0;
	g_session_token[client] = 0;
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	LoadTranslations( "common.phrases" );
	
	RegConsoleCmd( "sm_web", Command_Web );
	
	char gamedir[8];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual( gamedir, "csgo", false )) {
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	GetIPv4( c_ip, sizeof c_ip );
	LoadConfigFile();
}

//-----------------------------------------------------------------------------
void LoadConfigFile() {
	
	kv_config = CreateKeyValues( "weblink" );
	
	char filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/weblink.txt" );
	
	if( !FileExists( filepath ) ) {
		SetFailState( "weblink.txt not found" );
		return;
	}
	
	if( !kv_config.ImportFromFile( filepath ) ) {
		SetFailState( "Error loading config file." );
		return;
	}
	
	kv_config.GetString( "database", g_database, sizeof g_database );
	kv_config.GetString( "url", g_url, sizeof g_url );
	
	delete kv_config;
}

//-----------------------------------------------------------------------------
public int Native_OpenUrl( Handle plugin, int numParams ) {
	
	int userid = GetNativeCell(1);
	
	int len;
	GetNativeStringLength( 2, len );
	
	char[] url = new char[len + 1];
	GetNativeString( 2, url, len + 1 );
	
	OpenUrl( userid, url );
}

//-----------------------------------------------------------------------------
public Action Command_Web( int client, int args ) {
	char url[256];
	GetCmdArg( 1, url, sizeof url );
	OpenUrl( client, url );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void OpenUrl( int client, const char[] url ) {
	
	DataPack pack = new DataPack();
	pack.WriteString( url );
	
	QueryClientConVar( client, "cl_disablehtmlmotd", ConVar_QueryClient, pack );
}

//-----------------------------------------------------------------------------
public void ConVar_QueryClient( QueryCookie cookie, int client, 
                                ConVarQueryResult result, 
                                const char[] cvarName, 
                                const char[] cvarValue,
                                DataPack data ) {

	data.Reset();
	char url[256];
	data.ReadString( url, sizeof url );
	delete data;

	if( cookie == QUERYCOOKIE_FAILED ) {
		return;
	}
	
	if( StringToInt(cvarValue) == 1 ) {
		PrintToChat( client, 
			"\x01You have web pages blocked. Please unblock web pages by entering \x04cl_disablehtmlmotd 0 \x01in console." );
		
		return;
	}

	ProcessUrlRequest( client, url );
}

//-----------------------------------------------------------------------------
public void ProcessUrlRequest( int client, const char[] url ) {
	int userid = GetClientUserId(client);
	
	if( g_session_id[client] ) {
		Session_AddUrl( userid, url );
	} else {
		Session_Create( userid, url );
	}
}

//-----------------------------------------------------------------------------
public void Session_Create( int userid, const char[] url ) {
	
	int client = GetClientOfUserId(userid);
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client, "Please try again later" );
		return;
	}
	
	int token = GetRandomInt( 10000, 100000 );
	
	// save token until client disconnect
	g_session_token[client] = token;
	
	char query[512];
	FormatEx( query, sizeof query, 
		"INSERT INTO %s.weblink_session (user_id, token, server) VALUES (%d, %d, '%s')",
		g_database,
		GetSteamAccountID(client),
		token,
		c_ip );
	
	DataPack pack = new DataPack();
	pack.WriteCell( userid );
	pack.WriteString( url );
	
	// SourceMod guarantees these callbacks will be called in order,
	// so we don't have to worry about race conditions with other users
	DBRELAY_TQuery( IgnoredSQLResult, query );
	DBRELAY_TQuery( Session_OnCreated, "SELECT LAST_INSERT_ID()", pack );
}

//-----------------------------------------------------------------------------
public void Session_OnCreated( Handle owner, Handle hndl, const char[] error, 
                              DataPack data ) {
	
	if( !hndl ) {
		delete data;
		LogError( "SQL error fetching WebLink Session ID ::: %s", error );
		return;
	}
	
	int session_id;
	
	if( SQL_FetchRow( hndl ) ) {
		session_id = SQL_FetchInt( hndl, 0 );
	}
	
	data.Reset(); 
	int userid = data.ReadCell();
	char url[256];
	data.ReadString( url, sizeof url );
	delete data;
	
	int client = GetClientOfUserId( userid );
	if( client == 0 ) return; // disconnected
	
	// save session until client disconnect
	g_session_id[client] = session_id;
	
	Session_AddUrl( userid, url );
}

//-----------------------------------------------------------------------------
void Session_AddUrl( int userid, const char[] url ) {
	
	int client = GetClientOfUserId(userid);
		
	// could be disconnected if called directly
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client, "Please try again later" );
		return;
	}
	
	Handle db;
	DBRELAY_GetDatabase( db );
	
	char url_escaped[256];
	SQL_EscapeString( db, url, url_escaped, sizeof url_escaped );
	
	char query[512];
	FormatEx( query, sizeof query, 
		"INSERT INTO %s.weblink_url (weblink_session_id, url) VALUES (%d, '%s')",
		g_database,
		g_session_id[client],
		url_escaped );
	
	DataPack pack = new DataPack();
	pack.WriteCell( userid );
	pack.WriteString( url );
	
	DBRELAY_TQuery( Session_OnUrlAdded, query, pack );
}

//-----------------------------------------------------------------------------
public void Session_OnUrlAdded( Handle owner, Handle hndl, const char[] error, 
                              DataPack data ) {
	
	if( !hndl ) {
		delete data;
		LogError( "SQL error fetching WebLink Session URL ID ::: %s", error );
		return;
	}
	
	char url[256];
	
	data.Reset(); 
	int userid = data.ReadCell();
	data.ReadString( url, sizeof url );
	delete data;
	
	int client = GetClientOfUserId(userid);
	if( client == 0 ) return; //disconnected
	
	ShowUrl( client );
}

//-----------------------------------------------------------------------------
public void ShowUrl( int client ) {
	
	char game_abbr[13];
	
	if( GAME == GAME_CSGO ) {
		game_abbr = "csgo";
	} else if( GAME == GAME_TF2 ) {
		game_abbr = "tf2";
	} else {
		game_abbr = "unknown";
	}
	
	char url[512];
	FormatEx( url, sizeof url,
		"%s?id=%d&token=%d&game=%s",
		g_url,
		g_session_id[client],
		g_session_token[client],
		game_abbr );
	
	KeyValues kv = new KeyValues( "motd" );
	kv.SetString( "title", "" );
	kv.SetNum( "type", MOTDPANEL_TYPE_URL );
	kv.SetString( "msg", url );
	ShowVGUIPanel( client, "info", kv, true );
	delete kv;
	
	//ShowMOTDPanel( client, "", url, MOTDPANEL_TYPE_URL );
}

//-----------------------------------------------------------------------------
public void IgnoredSQLResult( Handle owner, Handle hndl, const char[] error, 
                              any data ) {}
