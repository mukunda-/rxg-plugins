
// TODO: anonymous donations being hidden

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <dbrelay>

#include <donations>
#include <rxgcommon>

//#define DEBUG

#define REQUIRE_EXTENSIONS

#include <timefuncs>

#pragma semicolon 1

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
//   fixed bug where donations amount was uninitialized when clients join without info
//

public Plugin:myinfo =
{
	name = "RXG Donations",
	author = "mukunda",
	description = "RXG Donations Interface",
	version = "2.3.0",
	url = "www.mukunda.com"
};

#define MAX_VERIFIES_PER_SESSION 5

new String:logFile[256];

new bool:g_initialized;

new Handle:sm_donations_goal;

#define MAX_EMAIL_SIZE 128

new verifies_this_session[MAXPLAYERS+1];
  
new bool:client_donation_cached[MAXPLAYERS+1]; 
new client_donator_level[MAXPLAYERS+1];
new client_donator_expiration[MAXPLAYERS+1];
new first_verification[MAXPLAYERS+1];

new bool:admin_loaded[MAXPLAYERS+1];
new bool:cookies_loaded[MAXPLAYERS+1];

new Handle:oncache_forward;

new Handle:client_donation_cookie;

new ad_counter = 0;

new last_month_start_time;
new month_start_time;
new month_end_time;

#define GAME_CSGO 1
#define GAME_TF2 2
#define GAME_CSS 3

new Game = 0;

//----------------------------------------------------------------------------------------------------------------------
// vip menu

new Handle:vip_menu = INVALID_HANDLE;		// menu
new Handle:vip_plugin_data = INVALID_HANDLE; // array { ??, plugin, handler }
new Handle:vip_plugin_names = INVALID_HANDLE; // array { string:name }
new Handle:vip_plugin_trie = INVALID_HANDLE; // name => index trie
new vip_plugin_next_id = 1;

enum {
	VPD_UNUSED= 0,
	VPD_PLUGIN = 1,
	VPD_HANDLER = 2
};

//----------------------------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	InitVIPMenu();
	
	CreateNative( "Donations_IsClientCached", Native_Donations_IsClientCached );
	CreateNative( "Donations_GetClientLevelDirect", Native_Donations_GetClientLevelDirect );
	CreateNative( "Donations_GetClientLevel", Native_Donations_GetClientLevel );
	
	CreateNative( "VIP_Register", Native_Register );
	CreateNative( "VIP_Unregister", Native_Unregister );
	RegPluginLibrary( "donations" );
	return APLRes_Success;
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");
	
	client_donation_cookie = RegClientCookie( "donations_expiration", "donation expiration time", CookieAccess_Protected );
	oncache_forward = CreateGlobalForward( "Donations_OnClientCached", ET_Ignore, Param_Cell, Param_Cell );
	 
	decl String:gameName[30];
	GetGameFolderName(gameName, sizeof(gameName));
	
	if( StrEqual(gameName,"csgo",false) ) {
		Game = GAME_CSGO;
	}
	else if( StrEqual(gameName, "tf", false) ) {
		Game = GAME_TF2;
	}
	else if( StrEqual( gameName, "cstrike", false) ) {
		Game = GAME_CSS;
	}
	
	if( DBRELAY_IsConnected() ) {
		RefreshAllClients();
	}
	
	sm_donations_goal = CreateConVar( "sm_donations_goal", "200", "Monthly donation goal", FCVAR_PLUGIN );

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/donations.log");
 
	RegConsoleCmd( "sm_verify", Command_verify );								// verify yourself
	RegConsoleCmd( "sm_info", Command_info );									// print donation/user info
	RegConsoleCmd( "sm_vip", Command_vip );								// print donation/user info
	
	RegAdminCmd( "sm_donations_refresh", Command_refresh, ADMFLAG_BAN );		// refresh donation cache
	RegAdminCmd( "sm_donations_fverify", Command_fverify, ADMFLAG_RCON );		// admin verify another client
	RegAdminCmd( "sm_checkmember", Command_checkmember, ADMFLAG_KICK );
 
#if defined DEBUG
	CreateTimer( 5.0, PrintDonationInfo, _, TIMER_REPEAT );
#else
	CreateTimer( 3.0*60.0, PrintDonationInfo, _, TIMER_REPEAT );
#endif
 
	new timestamp = GetTime();

	decl String:str[32];
	FormatTime( str, sizeof(str), "%m", timestamp );
	new month = StringToInt(str); 
	FormatTime( str, sizeof(str), "%Y", timestamp );
	new year = StringToInt(str);

	month_start_time = MakeTime( 0, 0, 0, month, 1, year );
	month--;
	if( month < 1 ) {
		month += 12;
		year--;
	}
	last_month_start_time = MakeTime( 0, 0, 0, month, 1, year );
	month += 2;
	if( month > 12 ) {
		month -= 12;
		year++;
	}
	month_end_time = MakeTime( 0, 0, 0, month, 1, year );
	
	BuildVIPMenu();
}



//-------------------------------------------------------------------------------------------------
CallCacheForward( client ) {
	Call_StartForward( oncache_forward );
	Call_PushCell( client );
	Call_PushCell( first_verification[client] );
	first_verification[client] = false;
	Call_Finish();
}

//-------------------------------------------------------------------------------------------------
RefreshClient( client ) { 
	if(IsFakeClient(client) ) return;
	client_donation_cached[client] = false;
	client_donator_level[client] = 0;
	
	// check override
	if( CheckCommandAccess( client, "donations_override", ADMFLAG_CUSTOM1, true) ) {
		client_donation_cached[client] = true;
		client_donator_level[client] = 1;
		client_donator_expiration[client] = 666;
		
		CallCacheForward( client );
		return;
	}

	decl String:data[32];
	GetClientCookie( client, client_donation_cookie, data, sizeof(data) );
	if( StrEqual(data,"") ) {
		// No Cookie, refresh from server
		LookupDonationInfo( client );
		return;
	}
	new expiration = StringToInt( data );
	if( GetTime() >= expiration ) {
		LookupDonationInfo( client ); // has cookie but it expired
	} else {
		// client has donations
		client_donation_cached[client] = true;
		client_donator_level[client] = 1;
		client_donator_expiration[client] = expiration;
		
		CallCacheForward( client );
	} 
}

//-------------------------------------------------------------------------------------------------
RefreshAllClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		RefreshClient(i);
	}
}

//-------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	if( IsFakeClient(client) ) return;
	verifies_this_session[client] = 0;
	admin_loaded[client] = false;
	cookies_loaded[client] = false;
	first_verification[client] = true;
	
}

//-------------------------------------------------------------------------------------------------
public OnClientCookiesCached( client ) {
	cookies_loaded[client] = true;
	if( IsFakeClient(client) ) return;
	if( !admin_loaded[client] ) return;  // wait for admin to be loaded
	
	RefreshClient(client);
}

//-------------------------------------------------------------------------------------------------
public OnClientPostAdminCheck(client) {
	admin_loaded[client] = true;
	if( IsFakeClient(client) ) return;
	if( !cookies_loaded[client] ) return; // wait for cookies to be loaded

	RefreshClient(client);
}

//-------------------------------------------------------------------------------------------------
public OnDBRelayConnected() {
	
	if( g_initialized ) {
		return;
	}
	
	RefreshAllClients();
	
	g_initialized = true;
}

//-------------------------------------------------------------------------------------------------
public LookupDonationInfoResult3( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	new client = GetClientOfUserId( data );
	if( !client ) return;

	if( !hndl ) {
		LogToFile( logFile, "(LookupDonationInfoResult3) Database Error: %s.", error );
		
		client_donation_cached[client] = true;
		return;
	}

	client_donation_cached[client] = true;
	
	client_donator_level[client] = 0;

	new rows = SQL_GetRowCount(hndl);
	if( rows == 0 ) { 
		
	} else {
		SQL_FetchRow(hndl);	// todo here!
	
		new time = SQL_FetchInt( hndl, 0 );
		if( GetTime() < time ) { // client has perks!
			client_donator_level[client] = 1;
			client_donator_expiration[client] = time;
			
			// save expiration in cookie
			decl String:cookie[32];
			Format( cookie, sizeof(cookie), "%d", time );
			SetClientCookie( client, client_donation_cookie, cookie );
		}
		CallCacheForward(client); 
	}
}

public LookupDonationInfoResult2( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	ResetPack(data);
	new userid = ReadPackCell(data);
	new forumid = ReadPackCell(data);
	CloseHandle(data);
	new client = GetClientOfUserId(userid) ;
	if( !client) return; // client DCd
	

	if( !hndl ) {
		LogToFile( logFile, "(LookupDonationInfoResult2) Database Error: %s.", error );
		client_donation_cached[client] = true;
		return;
	}

	decl String:auth[64];
	GetClientAuthString( client, auth, sizeof(auth) );
	auth[6] = '_';
	
	decl String:query[2048];
	Format( query, sizeof(query),
		
		"SELECT MAX(IF(time >= @a, @a := time + amt_time, @a := @a + amt_time )) AS donation_expiry_date \
			FROM ( \
				SELECT \
					payment_date AS time, (mc_gross*exchange_rate)*535680.0 AS amt_time \
					FROM sourcebans_forums.dopro_donations \
					WHERE (user_id='%d' OR option_name2 LIKE '%s') \
\
					AND (payment_status = 'Completed' OR payment_status = 'Refunded') \
					ORDER BY payment_date ASC \
				) AS q1",
			
		forumid,auth);
	
	DBRELAY_TQuery( LookupDonationInfoResult3, query, userid );
}

public LookupDonationInfoResult( Handle:owner, Handle:hndl, const String:error[], any:userid ) {
	new client = GetClientOfUserId( userid );
	if( !client ) return; // client disconnected
	if( !hndl ) {
		client_donation_cached[client] = true;
		return;
	}
	
	new rows = SQL_GetRowCount(hndl);
	if( rows <= 1 ) {
		
		new forum_id;
		if( rows == 1 ) {
			SQL_FetchRow(hndl);
			forum_id = SQL_FetchInt( hndl, 0 );
		} else {
			forum_id = -999;
		}
		new Handle:data = CreateDataPack();
		WritePackCell( data, userid );
		WritePackCell( data, forum_id );  

		DBRELAY_TQuery( LookupDonationInfoResult2, "SET @a := 0", data );
	} else if( rows > 1 ) {
		
		
		decl String:auth[64];
		GetClientAuthString( client, auth, sizeof(auth) );
		LogToFile( logFile, "SteamID Duplicate Found: client=%N, auth=%s, forumIDs:", client, auth );
		for( new i = 0; i < rows; i++ ) {
			SQL_FetchRow(hndl);
			new forum_id = SQL_FetchInt( hndl, 0 );
			LogToFile( logFile, "  %d", forum_id );
		}
		PrintToChat( client, "Notice: Your SteamID was matched with multiple forum accounts. Please tell an admin to correct this." );
	}
}

//-------------------------------------------------------------------------------------------------
LookupDonationInfo( client ) {
	if( !DBRELAY_IsConnected() ) return;
	client_donation_cached[client] = false;
	client_donator_level[client] = 0; 

	decl String:auth[64];
	decl String:query[256];
	GetClientAuthString( client, auth, sizeof(auth) );
	auth[6] = '_';
	Format( query, sizeof(query), "SELECT userid FROM sourcebans_forums.userfield WHERE field7 LIKE '%s'", auth );
	DBRELAY_TQuery( LookupDonationInfoResult, query, GetClientUserId(client) );
}
 

//-------------------------------------------------------------------------------------------------
public Action:Command_verify( client, args ) {
	if( client == 0 ) {
		ReplyToCommand( client, "This is a client only command." );
		return Plugin_Handled;
	}
	
	if( !DBRELAY_IsConnected() ) {
		ReplyToCommand( client, "Couldn't connect to donation database!" );
		return Plugin_Handled;
	}
	if( verifies_this_session[client] >= MAX_VERIFIES_PER_SESSION ) {
		ReplyToCommand( client, "You cannot use verify again during this session." );
		return Plugin_Handled;
	}
	verifies_this_session[client]++;
	ReplyToCommand( client, "Donation data refreshed." );
	LookupDonationInfo(client);

	return Plugin_Handled;
	 
}

//-------------------------------------------------------------------------------------------------
public Action:Command_refresh( client, args ) {
	RefreshAllClients();
	ReplyToCommand( client, "Refreshing donation cache." );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_fverify( client, args ) {
	if( args < 1 ) {
		ReplyToCommand( client, "sm_donations_fverify <user>" );
		return Plugin_Handled;
	}

	decl String:targetstring[64];
	GetCmdArg(1,targetstring,sizeof(targetstring));

	new target = FindTarget( client, targetstring,true,false);
	if( target == -1 ) return Plugin_Handled;

	LookupDonationInfo(target);
	ReplyToCommand( client, "Refreshed donation info for %N!", target );

	return Plugin_Handled;
}
 
//-------------------------------------------------------------------------------------------------
public Action:Command_info( client, args ) {

	decl String:auth[64];
	GetClientAuthString( client, auth, sizeof(auth) );
	auth[6] = '1';
	
	ReplyToCommand( client, "Your Steam ID: %s", auth );
	PrintToConsole( client, "Your Steam ID: %s", auth );
	
	if( !client_donation_cached[client] ) {
		ReplyToCommand( client, "Your donation data is still being loaded." );
		return Plugin_Handled;
	}
	 
	if( GetClientLevel(client) > 0 ) {
		ReplyToCommand( client, "Your Donator Perks are active!");
		
	} else {
		ReplyToCommand( client, "Your Donator Perks are disabled (expired or non existant!)." );
		ReplyToCommand( client, "Type /verify if you have just donated, and contact an admin if they still don't work!" );
		 
	}
	
	return Plugin_Handled;
}
 
//-------------------------------------------------------------------------------------------------

public Native_Donations_IsClientCached( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return _:client_donation_cached[client];
}
 

GetClientLevel(client) {
	if( !client_donation_cached[client] ) return 0;
	
	new level = client_donator_level[client];
	if( level == 0 ) {
		
		new AdminId:aids = GetUserAdmin( client );
		if( aids != INVALID_ADMIN_ID ) {
			if( GetAdminFlag(aids, Admin_Ban) ) return 1;
		}
		
		//if( DonationWhitelist_CheckClient(client) ) return 1;
	}
	
	return client_donator_level[client];
}

public Native_Donations_GetClientLevel( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return _:GetClientLevel(client);

}

public Native_Donations_GetClientLevelDirect( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !client_donation_cached[client] ) return 0;
	return client_donator_level[client];

}
 
public PrintDonationInfo_QueryTotal( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogToFile(logFile, "(PrintDonationInfo_QueryTotal) Database error: %s.", error);

		return;
	}

	if( SQL_GetRowCount(hndl) == 0 ) return;
	SQL_FetchRow(hndl);

	new Float:total = SQL_FetchFloat( hndl, 0 );

	
	new percent;
	new Float:goal = GetConVarFloat( sm_donations_goal );
	percent = RoundToZero((total/goal)*100);
	new actual_percent = percent;
	if( percent > 100 ) percent = 100;
	

	

	if( Game == GAME_CSGO ) {
 

		if( percent == 100 ) {
			PrintToChatAll( "\x01\x0B\x01RXG Monthly Goal/Fees: \x02$%.0f\x01, Received \x04$%.0f \x05(Thank You!)", goal, total );
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
 
			progress[write++] = 0xf;
			while(per52) {
				progress[write++] = 0xE2;
				progress[write++] = 0x96;
				progress[write++] = 0x88;//aa; 
				per52 -= 1;
			}
			progress[write++] = 0;
			PrintToChatAll( "\x01RXG Monthly Goal/Fees: \x07$%.0f\x01, Received \x04$%.0f \x01%s\x01", goal, total, progress );
		}
 
	} else if( Game == GAME_TF2 || Game == GAME_CSS ) {
		//if( percent == 100 ) return; // goal reached!
	
		decl String:progress[128] = "";
		if( percent != 100 ) {
			progress ="\x072cc048";
		} else if(percent==100) { 
			progress ="\x070072bc";
		}
		new per5 = percent /10;
		new per52 = 10-per5;
		new write=7;
		while(per5) {
 
			progress[write++] = 0xE2;
			progress[write++] = 0x96;
			progress[write++] = 0x88;
			per5 -= 1;

		}
		progress[write] = 0;
		StrCat( progress, sizeof(progress), "\x07145720" );//"\x0800000000" );
		write += 7; 
		while(per52) {
			progress[write++] = 0xE2;
			progress[write++] = 0x96;
			progress[write++] = 0x88;
			per52 -= 1;
		}
		progress[write++] = 0;
		

		PrintToChatAll( "\x0784d8f4RXG Monthly Goal/Fees: \x04$%.0f\x0784d8f4, Received \x04$%.0f\x01\xE2\x96\x90%s\x01\xE2\x96\x8C\x0784d8f4(%d%%)", goal, total, progress, actual_percent );
 
	}
}

public PrintDonationInfo_QueryTop( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogToFile(logFile, "(PrintDonationInfo_QueryTop) Database error: %s.", error);

		return;
	}

	if( SQL_GetRowCount(hndl) == 0 ) return;
	SQL_FetchRow(hndl);

	decl String:name[64];
	SQL_FetchString( hndl, 0, name, sizeof(name) );
	new Float:total = SQL_FetchFloat( hndl, 1 );

	if( Game == GAME_CSGO ) {
		PrintToChatAll( "\x01 \x01Top donator this month: \x04%s \x01(\x04$%.2f\x01)", name, total );
	} else if( Game == GAME_TF2 || Game == GAME_CSS ) {
		PrintToChatAll( "\x0784d8f4Top donator this month: \x07f7d85a%s \x0784d8f4(\x04$%.2f\x0784d8f4)", name, total );
	}
}

public PrintDonationInfo_QueryTopLast( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogToFile(logFile, "(PrintDonationInfo_QueryTop) Database error: %s.", error);

		return;
	}

	if( SQL_GetRowCount(hndl) == 0 ) return;
	SQL_FetchRow(hndl);

	decl String:name[64];
	SQL_FetchString( hndl, 0, name, sizeof(name) );
	new Float:total = SQL_FetchFloat( hndl, 1 );

	if( Game == GAME_CSGO ) {
		PrintToChatAll( "\x01 \x01Top donator of last month: \x04%s \x01(\x04$%.2f\x01)", name, total );
	} else if( Game == GAME_TF2 || Game == GAME_CSS ) {
		PrintToChatAll( "\x0784d8f4Top donator of last month: \x07f7d85a%s \x0784d8f4(\x04$%.2f\x0784d8f4)", name, total );
	}
}
public PrintDonationInfo_QueryRandom( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogToFile(logFile, "(PrintDonationInfo_QueryRandom) Database error: %s.", error);

		return;
	}
	
	if( SQL_GetRowCount(hndl) == 0 ) return;
	SQL_FetchRow(hndl);
	
	decl String:name[64];
	SQL_FetchString( hndl, 0, name, sizeof(name) );
	new Float:total = SQL_FetchFloat( hndl, 1 );

	if( Game == GAME_CSGO ) {
		PrintToChatAll( "\x01 \x04%s\x01 donated \x04$%.2f\x01 this month.", name, total );
	} else if( Game == GAME_TF2 || Game==GAME_CSS ) {
		PrintToChatAll( "\x07f7d85a%s\x0784d8f4 donated \x04$%.2f\x0784d8f4 this month.", name, total );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:PrintDonationInfo( Handle:timer ) {
	decl String:query[512];
	if( !DBRELAY_IsConnected() ) return Plugin_Continue;
	if( ad_counter == 0 ) {
		// print donation totals
 
		Format( query, sizeof(query), 
			"SELECT SUM(mc_gross*exchange_rate) AS scaled FROM sourcebans_forums.dopro_donations WHERE (payment_date >= '%d') AND (payment_date < '%d') AND event_id = '0' AND (payment_status = 'Completed' OR payment_status = 'Refunded') ",
			month_start_time,
			month_end_time );

		DBRELAY_TQuery( PrintDonationInfo_QueryTotal, query );
	} else if( ad_counter == 1 ) {
		// current top donator
		Format( query, sizeof(query), 
			"SELECT custom,SUM(mc_gross*exchange_rate) AS scaled FROM sourcebans_forums.dopro_donations WHERE (payment_date >= '%d') AND (payment_date < '%d') AND event_id = '0' AND (payment_status = 'Completed' OR payment_status = 'Refunded') AND option_seleczion1='Yes' GROUP BY custom ORDER BY scaled DESC LIMIT 1",
			month_start_time,
			month_end_time );

		DBRELAY_TQuery( PrintDonationInfo_QueryTop, query );
	} else if( ad_counter == 2 ) {
		// last top donator
		Format( query, sizeof(query), 
			"SELECT custom,SUM(mc_gross*exchange_rate) AS scaled FROM sourcebans_forums.dopro_donations WHERE (payment_date >= '%d') AND (payment_date < '%d') AND event_id = '0' AND (payment_status = 'Completed' OR payment_status = 'Refunded') AND option_seleczion1='Yes' GROUP BY custom ORDER BY scaled DESC LIMIT 1",
			last_month_start_time,
			month_start_time );

		DBRELAY_TQuery( PrintDonationInfo_QueryTopLast, query );
	} else if( ad_counter == 3 ) {
		Format( query, sizeof(query), 
			"SELECT custom,SUM(mc_gross*exchange_rate) AS scaled FROM sourcebans_forums.dopro_donations WHERE (payment_date >= '%d') AND (payment_date < '%d') AND event_id = '0' AND (payment_status = 'Completed' OR payment_status = 'Refunded') AND option_seleczion1='Yes' GROUP BY custom ORDER BY RAND() LIMIT 1",
			month_start_time,
			month_end_time );
		DBRELAY_TQuery( PrintDonationInfo_QueryRandom, query );
	}
	ad_counter++;
	if( ad_counter == 4 ) ad_counter = 0;

	return Plugin_Continue;


}

//-------------------------------------------------------------------------------------------------
public LookupRXGMembership3( Handle:owner, Handle:hndl, const String:error[], any:userid ) {
	new client = 0;
	if( userid ) {
		client = GetClientOfUserId(userid);
		if( !client ) return;
	}

	if( !hndl ) {
		PrintToConsole( client, " *** database error: %s", error );
		return;
	}
	if( SQL_GetRowCount(hndl) == 0 ) {
		PrintToConsole( client, " *** something weird happened (CODE9)" );
		return;
	}
	SQL_FetchRow(hndl);
	decl String:title[64];
	SQL_FetchString( hndl, 0, title, sizeof(title) );
	PrintToConsole( client, " *** Usergroup: \"%s\"", title );
	PrintToConsole( client, " *** (if the above printed DEFAULT or something then they are not a member)" );
	PrintToConsole( client, " *** This report is complete; tell pray that you are 110%% satisfied with this system!" );
}

//-------------------------------------------------------------------------------------------------
public LookupRXGMembership2( Handle:owner, Handle:hndl, const String:error[], any:userid ) {
	new client = 0;
	if( userid ) {
		client = GetClientOfUserId(userid);
		if( !client ) return;
	}

	if( !hndl ) {
		PrintToConsole( client, " *** database error: %s", error );
		return;
	}
	if( SQL_GetRowCount(hndl) == 0 ) {
		PrintToConsole( client, " *** something weird happened (CODE7)" );
		return;
	}
	SQL_FetchRow(hndl);
	new usergroupid = SQL_FetchInt( hndl, 0 );
	PrintToConsole( client, " *** fetching usergroup..." );
	decl String:query[256];
	Format( query, sizeof(query), "SELECT title FROM sourcebans_forums.usergroup WHERE usergroupid='%d'", usergroupid );
	DBRELAY_TQuery( LookupRXGMembership3, query, userid );
}

//-------------------------------------------------------------------------------------------------
public LookupRXGMembership1( Handle:owner, Handle:hndl, const String:error[], any:userid ) {
	new client = 0;
	if( userid ) {
		client = GetClientOfUserId(userid);
		if( !client ) return;
	}

	if( !hndl ) {
		PrintToConsole( client, " *** database error: %s", error );
		return;
	}
	
	if( SQL_GetRowCount(hndl) == 0 ) {
		PrintToConsole( client, " *** no matching STEAMID found in forum accounts" );
		PrintToConsole( client, " *** user is not a member or does not have a steamid set in his profile" );
		return;
	}
	
	SQL_FetchRow(hndl);
	new forumid = SQL_FetchInt( hndl, 0 );
	PrintToConsole( client, " *** found forum ID : %d", forumid );
	decl String:query[256];
	Format( query, sizeof(query), "SELECT usergroupid FROM sourcebans_forums.user WHERE userid='%d'", forumid );
	DBRELAY_TQuery( LookupRXGMembership2, query, userid );
	
}

//-------------------------------------------------------------------------------------------------
LookupRXGMembership( client, target ) {
	PrintToConsole( client, "Looking up %N...", target );
	decl String:query[256];
	decl String:auth[64];
	
	//GetClientAuthString( target, auth, sizeof(auth) );
	GetClientAuthId( target, AuthId_SteamID64, auth, sizeof(auth) );
	
	//auth[6] = '_';
	Format( query, sizeof(query), "SELECT userid FROM sourcebans_forums.steamuser WHERE steamid='%s'", auth );
	
	DBRELAY_TQuery( LookupRXGMembership1, query, client?GetClientUserId(client):0 );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_checkmember( client, args ) {
	if( args < 1 ) {
		ReplyToCommand( client, "sm_checkmember <user> - checks if a client is a registered rxg member" );
		return Plugin_Handled;
	}

	if( !DBRELAY_IsConnected() ) {
		ReplyToCommand( client, "couldn't access database, try again later" );
		return Plugin_Handled;
	}
	
	decl String:targetstring[64];
	GetCmdArg(1,targetstring,sizeof(targetstring));
	
	new target = FindTarget( client, targetstring,true,false);
	if( target == -1 ) return Plugin_Handled;

	LookupRXGMembership( client, target );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
InitVIPMenu() {
	vip_plugin_data = CreateArray( 3 );
	vip_plugin_names = CreateArray( 16 );
	vip_plugin_trie = CreateTrie();
}

//-------------------------------------------------------------------------------------------------
RebuildVIPPluginTrie() {
	new count = GetArraySize( vip_plugin_data );
	ClearTrie( vip_plugin_trie );
	for( new i = 0; i < count; i++ ) {
		decl String:name[64];
		GetArrayString( vip_plugin_names, i, name, sizeof name );
		SetTrieValue( vip_plugin_trie, name, i );
	}
}

//-------------------------------------------------------------------------------------------------
RemoveVIPPlugin( index ) {
	decl String:name[64];
	GetArrayString( vip_plugin_names, index, name, sizeof name );
	RemoveFromArray( vip_plugin_names, index );
	RemoveFromArray( vip_plugin_data, index );
	RemoveFromTrie( vip_plugin_trie, name ); 
}

//-------------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------
public VIPMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_Select ) {
		new client = param1;
		if( !client_donation_cached[client] ) {
			
			return;
		}
		new VIPAction:vipaction = VIP_ACTION_USE;
		if( client_donator_level[client] == 0 ) {
			
			vipaction = VIP_ACTION_HELP;
		}
		
		decl String:info[32];
		if( !GetMenuItem(menu, param2, info, sizeof(info)) ) return;
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

//-------------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------
public Action:Command_vip( client, args ) {
	if( !client_donation_cached[client] ) {
		PrintToChat( client, "Your data is still being loaded." );
		return Plugin_Handled;
	}
	DisplayMenu( vip_menu, client, MENU_TIME_FOREVER );
	return Plugin_Handled;
}
