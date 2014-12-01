//-----------------------------------------------------------------------------
// donations.sp
//
// RXG donation tracker
//-----------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <clientprefs> 
#include <rxgservices>
#include <rxgcommon>
#include <rxgsubs>

#include <donations>

//#define DEBUG

#define REQUIRE_EXTENSIONS
 
#pragma semicolon 1

//-----------------------------------------------------------------------------
// 2.3.0  <addtime>
//   upgraded code
//   switched to RXG Services
// 2.0.0  5:19 PM 3/21/2014
//   VIP menu
// 1.0.7 3:04 PM 12/23/2013
//   connect retries
// 1.0.6 8:05 AM 10/14/2013
//   extra check for bots
// 1.0.5 12:16 AM 10/14/2013
//   added failure check to prevent connection error flooding
//   dont show anonymous donations
// 1.0.3 2:37 PM 5/26/2013
//   donation expiration caching (via clientprefs cookie)
// 1.0.2 4/12/13
//   steamid matching from user_option2
// 2:31 PM 3/9/2013 - 1.0.1
//   fixed bug where donations amount was uninitialized when clients 
//   join without info
//

//-----------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "RXG Donations",
	author = "mukunda",
	description = "RXG Donations Interface",
	version = "2.3.0",
	url = "www.mukunda.com"
};

//-----------------------------------------------------------------------------
// the time when a client last used /verify
new g_last_verify[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
// donation info for each player
new bool:g_donation_cached[MAXPLAYERS+1]; 
new g_donation_expires1[MAXPLAYERS+1]; // time when $1/mo perks expire
new g_donation_expires5[MAXPLAYERS+1]; // time when $5/mo perks expire

// flag for determining first join for callback
new g_join_verification[MAXPLAYERS+1]; 

//-----------------------------------------------------------------------------
// for guaranteeing the cached callback triggers
// after admin and cookies are loaded.
new bool:g_admin_loaded[MAXPLAYERS+1]; 

//-----------------------------------------------------------------------------
// OnDonationsCached forward
new Handle:g_oncache_forward;

//-----------------------------------------------------------------------------
// Cookie for fast access to donation expiration time
//
// Format: <cachetime> <expires5> <expires1>
//   cachetime: time the cookie was created (invalidate after some time)
new Handle:g_donation_cookie;

//-----------------------------------------------------------------------------
// Which ad to display next.
new g_ad_counter = 0;

//-----------------------------------------------------------------------------
#define GAME_CSGO 1
#define GAME_TF2 2
#define GAME_CSS 3

// what game is running
new g_game = 0;

//-----------------------------------------------------------------------------
// vip menu
//
new Handle:vip_menu = INVALID_HANDLE;		  // menu
new Handle:vip_plugin_data = INVALID_HANDLE;  // array (VPD_x)
new Handle:vip_plugin_names = INVALID_HANDLE; // array { string:name }
new Handle:vip_plugin_trie = INVALID_HANDLE;  // name => index trie
new vip_plugin_next_id = 1;

enum {
	VPD_UNUSED,  // not used.
	VPD_PLUGIN,  // what plugin owns this perk
	VPD_HANDLER, // what handler to call when the menu item is pressed
	VPD_SIZE     // size of array block
};

//-----------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, 
							  String:error[], err_max ) {
	InitVIPMenu();
	
	CreateNative( "Donations_IsClientCached", Native_IsClientCached );
	CreateNative( "Donations_GetClientLevelDirect", 
					Native_GetClientLevelDirect );
	CreateNative( "Donations_GetClientLevel", Native_GetClientLevel );
	
	CreateNative( "Donations_Perks5", Native_Perks5 );
	CreateNative( "Donations_Perks1", Native_Perks1 );
	
	CreateNative( "VIP_Register", Native_Register );
	CreateNative( "VIP_Unregister", Native_Unregister );
	
	RegPluginLibrary( "donations" );
	return APLRes_Success;
}

//-----------------------------------------------------------------------------
FindGame() {
	decl String:game_name[30];
	GetGameFolderName( game_name, sizeof(game_name) );
	
	if( StrEqual( game_name, "csgo", false ) ) {
		g_game = GAME_CSGO;
	}
	else if( StrEqual( game_name, "tf", false ) ) {
		g_game = GAME_TF2;
	}
	else if( StrEqual( game_name, "cstrike", false ) ) {
		g_game = GAME_CSS;
	}
}

//-----------------------------------------------------------------------------
LoadSubs() {
	if( g_game == GAME_CSGO ) {
		AddSubFormat( "{RED}", "\x07" );
		AddSubFormat( "{GREEN}", "\x04" );
		AddSubFormat( "{COLORS}", "\x01 " );
		AddSubFormat( "{DEF}", "\x01" );
	} else {
		AddSubFormat( "{RED}", "\x07CE2020" );
		AddSubFormat( "{GREEN}", "\x04" );
		AddSubFormat( "{COLORS}", "" );
		AddSubFormat( "{DEF}", "\x01" );
	}
}

//-----------------------------------------------------------------------------
RegisterCommands() {

	// re-cache donation information.
	RegConsoleCmd( "sm_verify", Command_verify );
	
	// print donation status.
	RegConsoleCmd( "sm_info", Command_info );
	
	// open VIP menu.
	RegConsoleCmd( "sm_vip", Command_vip );
	
	// force verify all players
	RegAdminCmd( "sm_donations_refresh", Command_refresh, ADMFLAG_BAN );
	
	// force verify a player
	RegAdminCmd( "sm_donations_fverify", Command_fverify, ADMFLAG_RCON );
	
	// check if a person is an RXG member
	RegAdminCmd( "sm_checkmember", Command_checkmember, ADMFLAG_KICK );
}

//-----------------------------------------------------------------------------
public OnPluginStart() {
	FindGame();
	LoadSubs();
	
	LoadTranslations("common.phrases");
	
	g_donation_cookie = RegClientCookie( 
			"donations_expiration2", 
			"Cached donation info.", 
			CookieAccess_Protected );
			
	g_oncache_forward = CreateGlobalForward( 
			"Donations_OnClientCached", 
			ET_Ignore, Param_Cell, Param_Cell );
	 
	RefreshAllClients(); 
	RegisterCommands();
	 
	#if defined DEBUG // debug: fast timer
		CreateTimer( 5.0,      PrintDonationInfo, _, TIMER_REPEAT );
	#else
		CreateTimer( 3.0*60.0, PrintDonationInfo, _, TIMER_REPEAT );
	#endif
  
	BuildVIPMenu();
}
 
//-----------------------------------------------------------------------------
CallCacheForward( client ) {
	Call_StartForward( g_oncache_forward );
	Call_PushCell( client );
	Call_PushCell( g_join_verification[client] );
	g_join_verification[client] = false;
	Call_Finish();
}

//-----------------------------------------------------------------------------
RefreshClient( client ) { 
	if( IsFakeClient(client) ) return;
	g_donation_cached[client] = false;
	
	// check override, "o" flag gives perks
	if( CheckCommandAccess( client, "donations_override", 
							ADMFLAG_CUSTOM1, true) ) {
							
		g_donation_cached[client] = true; 
		g_donation_expires5[client] = GetTime() + 1728000;
		g_donation_expires1[client] = GetTime() + 1728000;
		
		CallCacheForward( client );
		return;
	}
	
	decl String:data[32];
	GetClientCookie( client, g_donation_cookie, data, sizeof(data) );
	if( data[0] == 0 ) {
		// No Cookie, refresh from server
		LookupDonationInfo( client );
		return;
	}
	
	decl String:cookie_data[3][64];
	ExplodeString( 
			data, " ", cookie_data, 
			sizeof cookie_data, sizeof cookie_data[] );
	
	new cachetime = StringToInt( cookie_data[0] );
	new time = GetTime();
	new expires5 = StringToInt( cookie_data[1] );
	new expires1 = StringToInt( cookie_data[2] );
	
	// revalidate info if it has been cached for more than 24 hours
	// or if time has passed either expiration times.
	if( time > cachetime + 86400 || time > expires5 || time > expires1 ) {
		// refresh data.
		LookupDonationInfo( client ); 
	} else {
		
		g_donation_cached  [client] = true; 
		g_donation_expires5[client] = expires5;
		g_donation_expires1[client] = expires1;
		
		CallCacheForward( client );
	} 
}

//-----------------------------------------------------------------------------
RefreshAllClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		// todo. multi query
		RefreshClient(i);
	}
}

//-----------------------------------------------------------------------------
public OnClientConnected( client ) {
	g_admin_loaded[client] = false;
	g_join_verification[client] = true;
}

//-----------------------------------------------------------------------------
public OnClientCookiesCached( client ) {
	if( IsFakeClient(client) ) return;
	if( !g_admin_loaded[client] ) return;  // wait for admin to be loaded
	
	RefreshClient(client);
}

//-----------------------------------------------------------------------------
public OnClientPostAdminCheck(client) {
	g_admin_loaded[client] = true;
	if( IsFakeClient(client) ) return;
	if( !AreClientCookiesCached(client) ) {
		return; // wait for cookies to be loaded
	}
	
	RefreshClient(client);
}

//-----------------------------------------------------------------------------
public OnDonationResponse( bool:error, Handle:response ) {
	if( error ) {
		decl String:reason[128];
		ReadPackString( response, reason, sizeof reason );
		PrintToServer( "OnDonationResponse error: %s", reason );
		return;
	}
	
	while( IsPackReadable( response, 1 ) ) {
		decl String:line[128];
		ReadPackString( response, line, sizeof line );
		
		decl String:values[3][32];
		ExplodeString( line, " ", values, 
					   sizeof values, sizeof values[] );
					   
		new id       = StringToInt( values[0] );
		new expires5 = StringToInt( values[1] );
		new expires1 = StringToInt( values[0] );
		
		new client = GetClientOfUserId( id );
		if( client == 0 ) continue;
		
		g_donation_cached[client]   = true;
		g_donation_expires5[client] = expires5;
		g_donation_expires1[client] = expires1;
		
		FormatEx( line, sizeof line, "%d %d %d", 
				  GetTime(), expires5, expires1 );
		SetClientCookie( client, g_donation_cookie, line );
		
		CallCacheForward( client );
	}
} 

//-----------------------------------------------------------------------------
LookupDonationInfo( client ) {
	RGS_Request( OnDonationResponse, 0, "PERKS %d %d", 
			GetClientUserId( client ), GetSteamAccountID( client ) );
}

//-----------------------------------------------------------------------------
public Action:Command_verify( client, args ) {
	if( client == 0 ) {
		ReplyToCommand( client, "This is a client only command." );
		return Plugin_Handled;
	}
	
	if( GetTime() < g_last_verify[client] + 10 ) {
		ReplyToCommand( client, 
				"Please wait before using this command again." );
		return Plugin_Handled;
	}
	g_last_verify[client] = GetTime();
	
	ReplyToCommand( client, "Refreshing donation data..." );
	LookupDonationInfo( client );

	return Plugin_Handled; 
}

//-----------------------------------------------------------------------------
public Action:Command_refresh( client, args ) {
	RefreshAllClients();
	ReplyToCommand( client, "Refreshing donation cache..." );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action:Command_fverify( client, args ) {
	if( args < 1 ) {
		ReplyToCommand( client, "sm_donations_fverify <user>" );
		return Plugin_Handled;
	}

	decl String:targetstring[64];
	GetCmdArg( 1, targetstring,sizeof(targetstring) );

	new target = FindTarget( client, targetstring, true, false );
	if( target == -1 ) return Plugin_Handled;

	LookupDonationInfo( target );
	ReplyToCommand( client, "Refreshed donation info for %N.", target );

	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
ReplyInfo( client, const String:label[], expires ) {
	new time = GetTime();
	decl String:status[64];
	
	if( time < expires ) {
		status = "{GREEN}Active";
	} else {
		if( expires == 0 ) {
			status = "{RED}Inactive";
		} else {
			time -= g_donation_expires5[client];
			FormatDuration( time, status, sizeof status );
			Format( status, sizeof status, "{RED}Expired %s ago", status );
		}
	}
	
	Format( status, sizeof status, "{COLORS}%s: %s", label, status );
	
	FormatSubs( status, sizeof status, 
		GetCmdReplySource() == SM_REPLY_TO_CHAT ); 
	// (strip colors if replying to console.)
	
	ReplyToCommand( client, status );
}
 
//-------------------------------------------------------------------------------------------------
public Action:Command_info( client, args ) {
	
	decl String:auth[64];
	GetClientAuthString( client, auth, sizeof(auth) );
	auth[6] = '1';
	
	ReplyToCommand( client, "Your Steam ID: %s", auth ); 
	
	if( !g_donation_cached[client] ) {
		ReplyToCommand( client, "Your donation data is not loaded." );
		return Plugin_Handled;
	}
	 
	ReplyInfo( client, "$5/mo perks", g_donation_expires5[client] );
	ReplyInfo( client, "$1/mo perks", g_donation_expires1[client] );
	
	new time = GetTime();
	if( time >= g_donation_expires1[client] 
		|| time >= g_donation_expires5[client] ) {
		
		ReplyToCommand( client, 
			"Type /verify to refresh your donation status, and contanct and admin if there is a problem!" );
	}
	
	return Plugin_Handled;
}
 
//-----------------------------------------------------------------------------
public Native_IsClientCached( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return _:g_donation_cached[client];
}
 
//-----------------------------------------------------------------------------
GetClientLevel(client) {
	if( !g_donation_cached[client] ) return 0;
	
	new level = GetTime() < g_donation_expires5[client] ? 1 : 0;
	if( level == 0 ) {
		
		new AdminId:aids = GetUserAdmin( client );
		if( aids != INVALID_ADMIN_ID ) {
			if( GetAdminFlag(aids, Admin_Ban) ) return 1;
		}
		 
	}
	
	return level;
}

//-----------------------------------------------------------------------------
public Native_GetClientLevel( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return _:GetClientLevel( client ); 
}

//-----------------------------------------------------------------------------
public Native_GetClientLevelDirect( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !g_donation_cached[client] ) return 0;
	return GetTime() < g_donation_expires5[client] ? 1 : 0;

}

//-----------------------------------------------------------------------------
public Native_Perks5( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !g_donation_cached[client] ) return 0;
	return GetTime() < g_donation_expires5[client];
}

//-----------------------------------------------------------------------------
public Native_Perks1( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !g_donation_cached[client] ) return 0;
	return GetTime() < g_donation_expires1[client];
}

//-----------------------------------------------------------------------------
public OnQueryTotal( bool:error, Handle:response ) {
	if( error ) return;
	
	new percent;
	new Float:total = KvGetFloat( response, "total" );
	new Float:goal  = KvGetFloat( response, "goal" );
	
	percent = RoundToZero( (total/goal)*100.0 );
	new actual_percent = percent;
	if( percent > 100 ) percent = 100;
 
	if( g_game == GAME_CSGO ) {
		if( percent == 100 ) {
			PrintToChatAll( "\x01RXG Monthly Goal/Fees: \x02$%.0f\x01, Received \x04$%.0f \x05(Thank You!)", 
			goal, total );
		} else {
			decl String:progress[128] = "";
			
			progress[0] = 0x06;	
			
			new per5 = percent /10;
			if( per5 == 0 && percent != 0 ) per5 = 1;
			new per52 = 10-per5;
			new write=1;
			while(per5) {
				progress[write++] = 0xE2;
				progress[write++] = 0x96;
				progress[write++] = 0x88; 
				per5 -= 1;
 
			}
 
			progress[write++] = 0xF;
			while(per52) {
				progress[write++] = 0xE2;
				progress[write++] = 0x96;
				progress[write++] = 0x88;
				per52 -= 1;
			}
			progress[write++] = 0;
			PrintToChatAll( "\x01RXG Monthly Goal/Fees: \x07$%.0f\x01, Received \x04$%.0f \x01%s\x01", 
				goal, total, progress );
		}
 
	} else { 
	
		decl String:progress[128] = "";
		if( percent != 100 ) {
			progress = "\x072cc048";
		} else { 
			progress = "\x070072bc";
		}
		new per5 = percent /10;
		new per52 = 10-per5;
		new write=7;
		while( per5 ) { 
			progress[write++] = 0xE2;
			progress[write++] = 0x96;
			progress[write++] = 0x88;
			per5 -= 1;

		}
		progress[write] = 0;
		StrCat( progress, sizeof(progress), "\x07145720" ); 
		write += 7; 
		while(per52) {
			progress[write++] = 0xE2;
			progress[write++] = 0x96;
			progress[write++] = 0x88;
			per52 -= 1;
		}
		progress[write++] = 0;
		
		PrintToChatAll( "\x0784d8f4RXG Monthly Goal/Fees: \x04$%.0f\x0784d8f4, Received \x04$%.0f\x01\xE2\x96\x90%s\x01\xE2\x96\x8C\x0784d8f4(%d%%)", 
		goal, total, progress, actual_percent );
	}
}

//-----------------------------------------------------------------------------
enum {
	QUERYPERSON_TOP,
	QUERYPERSON_LASTTOP,
	QUERYPERSON_RAND
};

//-----------------------------------------------------------------------------
public OnQueryPerson( bool:error, Handle:response, any:data ) {
	if( error ) return;
	
	decl String:name[64];
	decl String:amount[64];
	KvGetString( response, "name", name, sizeof name );
	KvGetString( response, "amount", amount, sizeof amount );
	
	if( data == QUERYPERSON_TOP ) {
		if( g_game == GAME_CSGO ) {
			PrintToChatAll( 
				"\x01Top donator this month: \x04%s \x01(\x04$%s\x01)", 
				name, amount );
		} else {
			PrintToChatAll( 
				"\x0784d8f4Top donator this month: \x07f7d85a%s \x0784d8f4(\x04$%s\x0784d8f4)", 
				name, amount );
		}
	} else if( data == QUERYPERSON_LASTTOP ) {
		if( g_game == GAME_CSGO ) {
			PrintToChatAll( 
				"\x01Top donator of last month: \x04%s \x01(\x04$%s\x01)", 
				name, amount );
		} else {
			PrintToChatAll( 
				"\x0784d8f4Top donator of last month: \x07f7d85a%s \x0784d8f4(\x04$%s\x0784d8f4)", 
				name, amount );
		}
	} else if( data == QUERYPERSON_RAND ) {
		if( g_game == GAME_CSGO ) {
			PrintToChatAll( 
				"\x01 \x04%s\x01 donated \x04$%s\x01 this month.", 
				name, amount );
		} else {
			PrintToChatAll( 
				"\x07f7d85a%s\x0784d8f4 donated \x04$%s\x0784d8f4 this month.", 
				name, amount );
		}
	}
}

//-----------------------------------------------------------------------------
public Action:PrintDonationInfo( Handle:timer ) {
	if( g_ad_counter == 0 ) {
		// print donation totals
		RGS_Request( OnQueryTotal, 0, "DONATIONS TOTAL" );
		
	} else if( g_ad_counter == 1 ) {
		// current top donator
		RGS_Request( OnQueryPerson, QUERYPERSON_TOP, "DONATIONS TOP" );
		
	} else if( g_ad_counter == 2 ) {
		// last top donator
		RGS_Request( OnQueryPerson, QUERYPERSON_TOP, "DONATIONS LASTTOP" );
		
	} else if( g_ad_counter == 3 ) {
		// random donator
		RGS_Request( OnQueryPerson, QUERYPERSON_TOP, "DONATIONS RAND" );
		
	}
	g_ad_counter++;
	if( g_ad_counter == 4 ) g_ad_counter = 0;
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public OnQueryMembership( bool:error, Handle:response, any:client ) {
	if( client != 0 ) {
		client = GetClientOfUserId( client );
		if( !client ) return;
	}
	
	if( error ) {
		PrintToConsole( client, 
			"Error looking up member. Please try again later." );
		return;
	}
	
	decl String:ismember[64];
	decl String:rank[64];
	
	KvGetString( response, "ismember", ismember, sizeof ismember );
	KvGetString( response, "rank", rank, sizeof rank );
	
	PrintToConsole( client, "ismember: %s", ismember );
	PrintToConsole( client, "rank: %s", rank );
}

//-----------------------------------------------------------------------------
LookupRXGMembership( client, target ) {
	PrintToConsole( client, "Looking up %N...", target );
	RGS_Request( OnQueryMembership, client ? GetClientUserId(client):0, 
		"MEMBER %d", GetSteamAccountID( target ) );
}

//-----------------------------------------------------------------------------
public Action:Command_checkmember( client, args ) {
	if( args < 1 ) {
		ReplyToCommand( client, 
			"sm_checkmember <user> - checks if a client is a registered rxg member" );
		return Plugin_Handled;
	}
	
	decl String:targetstring[64];
	GetCmdArg( 1, targetstring, sizeof(targetstring) );
	
	new target = FindTarget( client, targetstring, true, false );
	if( target == -1 ) return Plugin_Handled;

	LookupRXGMembership( client, target );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
InitVIPMenu() {
	vip_plugin_data = CreateArray( VPD_SIZE );
	vip_plugin_names = CreateArray( 16 );
	vip_plugin_trie = CreateTrie();
}

//-----------------------------------------------------------------------------
RebuildVIPPluginTrie() {
	new count = GetArraySize( vip_plugin_data );
	ClearTrie( vip_plugin_trie );
	for( new i = 0; i < count; i++ ) {
		decl String:name[64];
		GetArrayString( vip_plugin_names, i, name, sizeof name );
		SetTrieValue( vip_plugin_trie, name, i );
	}
}

//-----------------------------------------------------------------------------
RemoveVIPPlugin( index ) {
	decl String:name[64];
	GetArrayString( vip_plugin_names, index, name, sizeof name );
	RemoveFromArray( vip_plugin_names, index );
	RemoveFromArray( vip_plugin_data, index );
	RemoveFromTrie( vip_plugin_trie, name ); 
}

//-----------------------------------------------------------------------------
public Native_Register( Handle:plugin, numParams ) {
	decl String:name[64];
	GetNativeString( 1, name, sizeof name );
	new VIPHandler:handler = GetNativeCell(2);
	
	new count = GetArraySize( vip_plugin_data );
	
	// remove existing
	for( new i = 0; i < count; i++ ) {
		decl String:name2[64];
		GetArrayString( vip_plugin_names, i, name2, sizeof name2 );
		
		if( !StrEqual( name2, name ) ) continue;
		RemoveVIPPlugin( i );
		break;
	}
	
	decl data[3];
	data[0] = vip_plugin_next_id;
	data[1] = _:plugin;
	data[2] = _:handler;
	PushArrayArray( vip_plugin_data, data );
	PushArrayString( vip_plugin_names, name );
	vip_plugin_next_id++;
	
	RebuildVIPPluginTrie();
	
	BuildVIPMenu();
}

//-----------------------------------------------------------------------------
public Native_Unregister( Handle:plugin, numParams ) {
	new count = GetArraySize( vip_plugin_data );
	for( new i = 0; i < count; i++ ) {
		if( Handle:GetArrayCell( vip_plugin_data, i, VPD_PLUGIN ) == plugin ) {
			RemoveVIPPlugin( i );
			count--;
			i--;
		}
	}
	RebuildVIPPluginTrie();
}

//-----------------------------------------------------------------------------
public VIPMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_Select ) {
		new client = param1;
		if( !g_donation_cached[client] ) {
			
			return;
		}
		new VIPAction:vipaction = VIP_ACTION_USE;
		if( !Donations_Perks5( client )) {
			
			vipaction = VIP_ACTION_HELP;
		}
		
		decl String:info[32];
		if( !GetMenuItem( menu, param2, info, sizeof(info)) ) return;
		if( info[0] == '0' ) return;
		
		new index;
		if( GetTrieValue( vip_plugin_trie, info, index ) ) {
			
			Call_StartFunction( 
				Handle:GetArrayCell( vip_plugin_data, index, VPD_PLUGIN ),
				Function:GetArrayCell( vip_plugin_data, index, VPD_HANDLER ) );
			Call_PushCell( client );
			Call_PushCell( vipaction );
			Call_Finish();
		} 
		
		if( vipaction == VIP_ACTION_HELP ) {
			PrintToChat( client, "\x01 \x04Become a VIP today by supporting our servers. Donate at www.reflex-gamers.com." );
		}
	}
}

//-----------------------------------------------------------------------------
BuildVIPMenu() {
	if( vip_menu != INVALID_HANDLE ) CloseHandle( vip_menu );
	vip_menu = CreateMenu( VIPMenuHandler );
	
	SetMenuTitle( vip_menu, "VIP Menu" );
	new count = GetArraySize( vip_plugin_data );
	if( count < 9 ) {
		SetMenuPagination( vip_menu, MENU_NO_PAGINATION );
		SetMenuExitButton( vip_menu, true );
	}
	for( new i = 0; i < count; i++ ) {
		decl String:name[64];
		GetArrayString( vip_plugin_names, i, name, sizeof name );
		AddMenuItem( vip_menu, name, name );
	}
	if( count == 0 ) {
		AddMenuItem( vip_menu, "0", "No Plugins Enabled!", ITEMDRAW_DISABLED );
	}
}

//-----------------------------------------------------------------------------
public Action:Command_vip( client, args ) {
	if( !g_donation_cached[client] ) {
		PrintToChat( client, 
			"Your data is not loaded. Type /verify to refresh it." );
		return Plugin_Handled;
	}
	
	DisplayMenu( vip_menu, client, MENU_TIME_FOREVER );
	return Plugin_Handled;
}
