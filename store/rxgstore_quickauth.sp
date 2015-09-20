
#include <sourcemod>
#include <rxgstore>
#include <dbrelay>
#include <rxgcommon>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "RXG Store QuickAuth",
    author      = "WhiteThunder",
    description = "Adds !store and related commands",
    version     = "1.0.0",
    url         = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------

// rxgstore config
KeyValues kv_config;

char g_database[65];
char g_url[256];

// the ip for this server (hostip converted into ipv4 format)
char c_ip[32];

// routes for opening specific store pages
char g_route_faq[] = "/faq";
char g_route_buycash[] = "/paypal";
char g_route_cart[] = "/cart";
char g_route_item[] = "/item/%s";
char g_route_profile[] = "/user/%s";
char g_route_gift[] = "/gift/compose/%s";

//-----------------------------------------------------------------------------
int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

//#define RXG_CSGO_CLAN "#rxg"

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	LoadTranslations( "common.phrases" );
	
	RegConsoleCmd( "sm_store", Command_store );
	RegConsoleCmd( "sm_shop",  Command_store );
	RegConsoleCmd( "sm_buy",   Command_store );
	RegConsoleCmd( "sm_gift",  Command_gift );
	RegConsoleCmd( "sm_buycash",  Command_buycash );
	
	char gamedir[8];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual( gamedir, "csgo", false )) {
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	GetIPv4( c_ip, sizeof c_ip );
	PrintToServer(c_ip);
	LoadConfigFile();
}

//-----------------------------------------------------------------------------
void LoadConfigFile() {
	
	kv_config = CreateKeyValues( "rxgstore" );
	
	char filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/rxgstore.txt" );
	
	if( !FileExists( filepath ) ) {
		SetFailState( "rxgstore.txt not found" );
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
public void IgnoredSQLResult( Handle owner, Handle hndl, const char[] error, 
                              any data ) {}

//-----------------------------------------------------------------------------
public void ShowStorePage( int client, int id, int token, const char[] page ) {
	
	char game_abbr[13];
	
	if( GAME == GAME_CSGO ) {
		game_abbr = "csgo";
	} else if( GAME == GAME_TF2 ) {
		game_abbr = "tf2";
	} else {
		game_abbr = "unknown";
	}
	
	char page_param[65];
	
	if( page[0] != EOS ) {
		FormatEx( page_param, sizeof page_param, "&page=%s", page );
	}
	
	char url[512];
	FormatEx( url, sizeof url,
		"http://%s/quickauth?id=%d&token=%d&game=%s%s",
		g_url,
		id,
		token,
		game_abbr,
		(page[0] != EOS) ? page_param : "" );
	
	KeyValues kv = new KeyValues( "motd" );
	kv.SetString( "title", "RXG Store" );
	kv.SetNum( "type", MOTDPANEL_TYPE_URL );
	kv.SetString( "msg", url );
	
	ShowVGUIPanel( client, "info", kv, true );
	
	delete kv;
}

//-----------------------------------------------------------------------------
public void OnQuickAuthFetch( Handle owner, Handle hndl, const char[] error, 
                              DataPack data ) {
	if( !hndl ) {
		delete data;
		LogError( "SQL error fetching QuickAuth ID ::: %s", error );
		return;
	}
	
	int id;
	
	if( SQL_FetchRow( hndl ) ) {
		id = SQL_FetchInt( hndl, 0 );
	}
	
	char page[65];
	
	data.Reset(); 
	int client = data.ReadCell();
	int token = data.ReadCell();
	data.ReadString( page, sizeof page );
	
	delete data;
	
	client = GetClientOfUserId( client );
	if( client == 0 ) return; // disconnected
	
	ShowStorePage( client, id, token, page );
}

//-----------------------------------------------------------------------------
public Action QuickAuth( int client, const char[] page ) {
	
	DataPack pack = new DataPack();
	pack.WriteString( page );
	
	QueryClientConVar( client, "cl_disablehtmlmotd", ConVar_QueryClient, pack );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_store( int client, int args ) {
	
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client,
			"The store is currently unavailable. Please try again later." );
		
		return Plugin_Handled;
	}
	
	if( args > 0 ) {
		char sub_command[17];
		GetCmdArg( 1, sub_command, sizeof sub_command );
		
		if( StrEqual("help", sub_command, false) ||
				StrEqual("faq", sub_command, false) ) {
			
			return QuickAuth( client, g_route_faq );
			
		} else if( StrEqual("buycash", sub_command, false) ) {
			return QuickAuth( client, g_route_buycash );
			
		} else if( StrEqual("cart", sub_command, false) ) {
			return QuickAuth( client, g_route_cart );
			
		} else if( StrEqual("item", sub_command, false) ) {
			return SubCommand_Item( client, args );
			
		} else if( StrEqual("profile", sub_command, false) ) {
			return SubCommand_Profile( client, args );
			
		} else if( StrEqual("gift", sub_command, false) ) {
			return SubCommand_Gift( client, args );
			
		} else if( StrEqual("page", sub_command, false) ) {
			return SubCommand_Page( client, args );
		}
	}
	
	return QuickAuth( client, "" );
}

//-----------------------------------------------------------------------------
public Action Command_gift( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client,
			"The store is currently unavailable. Please try again later." );
		
		return Plugin_Handled;
	}
	
	return SubCommand_Gift( client, args, 1 );
}

//-----------------------------------------------------------------------------
public Action Command_buycash( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client,
			"The store is currently unavailable. Please try again later." );
		
		return Plugin_Handled;
	}
	
	return QuickAuth( client, g_route_buycash );
}

//-----------------------------------------------------------------------------
Action SubCommand_Item( int client, int args ) {
	
	char page[65] = "";
	
	if( args > 1 ) {
		char item_name[65];
		GetCmdArg( 2, item_name, sizeof item_name );
		FormatEx( page, sizeof page, g_route_item, item_name );
		// TODO: handle invalid item names
	} else {
		ReplyToCommand( client, "No item specified" );
		return Plugin_Handled;
	}
	
	return QuickAuth( client, page );
}

//-----------------------------------------------------------------------------
Action SubCommand_Profile( int client, int args, int arg = 2 ) {

	char page[65] = "";
	
	if( arg <= args ) {
		
		char target_arg[33];
		GetCmdArg( arg, target_arg, sizeof target_arg );
		int target = FindTarget( client, target_arg, true, false );
		
		if( target == -1 ) {
			return Plugin_Handled;
		} else {
			char steamid[65];
			if( GetClientAuthId( target, AuthId_SteamID64, steamid, sizeof steamid ) ) {
				FormatEx( page, sizeof page, g_route_profile, steamid );
			} else {
				ReplyToCommand( client, "Invalid player" );
				return Plugin_Handled;
			}
		}
		
	} else {
		ReplyToCommand( client, "No player specified" );
		return Plugin_Handled;
	}
	
	return QuickAuth( client, page );
}

//-----------------------------------------------------------------------------
Action SubCommand_Gift( int client, int args, int arg = 2 ) {
	
	char page[65] = "";
	
	if( arg <= args ) {
		
		char target_arg[33];
		GetCmdArg( arg, target_arg, sizeof target_arg );
		int target = FindTarget( client, target_arg, true, false );
		
		if( target == -1 ) {
			ReplyToCommand( client, "Player not found" );
			return Plugin_Handled;
		} else if( target == client ) {
			ReplyToCommand( client, "You cannot send a gift to yourself" );
			return Plugin_Handled;
		} else {
			char steamid[65];
			if( GetClientAuthId( target, AuthId_SteamID64, steamid, sizeof steamid ) ) {
				FormatEx( page, sizeof page, g_route_gift, steamid );
			} else {
				ReplyToCommand( client, "Invalid player" );
				return Plugin_Handled;
			}
		}
	} else {
		ReplyToCommand( client, "No player specified" );
		return Plugin_Handled;
	}
	
	return QuickAuth( client, page );
}

//-----------------------------------------------------------------------------
Action SubCommand_Page( int client, int args ) {
	
	char page[65] = "";
	
	if( args > 1 ) {
		char page_arg[65];
		GetCmdArg( 2, page_arg, sizeof page_arg );
		FormatEx( page, sizeof page, "/%s", page_arg );
	} else {
		ReplyToCommand( client, "No page specified" );
		return Plugin_Handled;
	}
	
	return QuickAuth( client, page );
}

//-----------------------------------------------------------------------------
public void ConVar_QueryClient( QueryCookie cookie, int client, 
                                ConVarQueryResult result, 
                                const char[] cvarName, 
                                const char[] cvarValue,
                                DataPack data ) {

	data.Reset();
	char page[65];
	data.ReadString( page, sizeof page );
	delete data;

	if( cookie == QUERYCOOKIE_FAILED ) {
		return;
	}
	
	if( StringToInt(cvarValue) == 1 ) {
		PrintToChat( client, 
			"\x01You have web pages blocked. Please visit \x04store.reflex-gamers.com \x01or unblock web pages by entering \x04cl_disablehtmlmotd 0 \x01in console." );
		
		return;
	}

	int token = GetRandomInt( 10000, 100000 );
	
	//decl String:clan_tag[32];
	//CS_GetClientClanTag( client, clan_tag, sizeof clan_tag );
	//new bool:is_member = StrEqual( clan_tag, RXG_CSGO_CLAN );
	bool is_member = false;
	
	char query[512];
	FormatEx( query, sizeof query, 
		"INSERT INTO %s.quick_auth (user_id, token, server, is_member) VALUES (%d, %d, '%s', %d)",
		g_database,
		GetSteamAccountID(client),
		token,
		c_ip,
		is_member );
	
	DataPack pack = new DataPack();
	pack.WriteCell( GetClientUserId( client )); 
	pack.WriteCell( token );
	pack.WriteString( page );
	
	if( DBRELAY_IsConnected() ) {
		DBRELAY_TQuery( IgnoredSQLResult, query );
		DBRELAY_TQuery( OnQuickAuthFetch, "SELECT LAST_INSERT_ID()", pack );
	} else {
		PrintToChat( client, "\x01Visit our store at \x04store.reflex-gamers.com");
	}
	
	//ReplyToCommand( client, "Visit our store at store.reflex-gamers.com" );
}
