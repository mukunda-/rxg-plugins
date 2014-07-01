
// rxg compo manager
//

#include <sourcemod>
//#include <cURL>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name        = "rxgcompo",
	author      = "mukunda",
	description = "RXG Competition API",
	version     = "1.0.7",
	url         = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
// contest menu:
// !contest, !compo
//
// 1. <name> points
// 2. <name> points
// 3. <name> points
// 4. <name> points
// 5. <name> points
// 6. <name> points
// 7. <name> points
// 8. <name> points
// 9. <name> points
// ?. <name> points

//----------------------------------------------------------------------------------------------------------------------
new bool:g_db_connected = false;
new Handle:g_db;
new g_connection_retries = 0;
#define MAX_DATABASE_RETRIES 10

new String:g_logFile[256];
 
new bool:g_client_loaded[MAXPLAYERS+1];
//new g_client_userid[MAXPLAYERS+1];
new g_client_account[MAXPLAYERS+1];
new g_client_points[MAXPLAYERS+1];
new g_client_dailypoints[MAXPLAYERS+1];
new g_client_day[MAXPLAYERS+1];
 
new g_current_day = -9000000;
new g_point_cap = 0;

new g_top_points;

new g_round_players;

new g_last_commit;

new g_leaderboard_lastpolltime;

new bool:g_client_wants_leaderboard[MAXPLAYERS+1];
new bool:g_refreshing_leaderboard;

#define LB_ENTRIES 10

new g_num_lb;
new g_leaderboard_account[LB_ENTRIES];
new String:g_leaderboard_names[LB_ENTRIES][64];
new g_leaderboard_points[LB_ENTRIES];

new g_contest_start;
new g_contest_end;

new Handle:g_menu;

#define MIN_PLAYERS_TO_GAIN_POINTS 3

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {

	CreateNative( "COMPO_AddPoints", Native_AddPoints );
	CreateNative( "COMPO_GetTopPoints", Native_GetTopPoints );
	CreateNative( "COMPO_GetPoints", Native_GetPoints );
	CreateNative( "COMPO_GetRoundPlayers", Native_GetRoundPlayers );
	RegPluginLibrary( "rxgcompo" );
}

//-------------------------------------------------------------------------------------------------
LoadConfig() {
	new Handle:kv = CreateKeyValues( "Compo" );
	decl String:configpath[256];
	BuildPath( Path_SM, configpath, sizeof(configpath), "configs/compo.txt" );
	if( !FileExists( configpath ) ) {
		SetFailState( "Missing configuration file: %s", configpath );
	}
	if( !FileToKeyValues( kv, configpath ) ) {
		SetFailState( "Error loading configuration file." );
	}
	
	g_contest_start = KvGetNum( kv, "startdate" );
	g_contest_end = KvGetNum( kv, "enddate" );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( !SQL_CheckConfig("compo") ) {
		SetFailState( "Missing \"compo\" database conf." );
		return;
	}
	LoadConfig();
	UpdateDay();
	
	g_last_commit = GetTime();
	g_leaderboard_lastpolltime = -900;
	
	BuildPath(Path_SM, g_logFile, sizeof(g_logFile), "logs/compo.log");
	
	SQL_TConnect( OnDatabaseConnected, "compo" );
	
	HookEvent( "round_start", OnRoundStart );
	
	CreateTimer( 30.0, CommitDataTimer, _, TIMER_REPEAT );
	
	RegConsoleCmd( "sm_contest", Command_contest );
	RegConsoleCmd( "sm_compo", Command_contest );
	
	RegAdminCmd( "rxgcompo_forcecommit", Command_forcecommit, ADMFLAG_RCON, "force commit to database (for clean server shutdown)" );
	
	g_menu = CreateMenu( ContestMenuHandler, MenuAction_Select|MenuAction_DisplayItem );
	SetMenuPagination( g_menu, MENU_NO_PAGINATION );
	SetMenuExitButton( g_menu, true );
	SetMenuTitle( g_menu, "REVOCOMP" );
	AddMenuItem( g_menu, "1", "Your points" );
	AddMenuItem( g_menu, "2", "Daily points" );
	AddMenuItem( g_menu, "3", "[Top 10]" );
}


//----------------------------------------------------------------------------------------------------------------------
public Action:RetryDatabaseConnection( Handle:timer ) {
	SQL_TConnect( OnDatabaseConnected, "compo" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnDatabaseConnected( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	g_db = hndl;
	if( g_db == INVALID_HANDLE ) {
		LogToFile( g_logFile, "database connection failure: %s", error );
		g_connection_retries++;
		if( g_connection_retries == MAX_DATABASE_RETRIES ) {
			LogToFile( g_logFile, "giving up after %d retries.", MAX_DATABASE_RETRIES );
			SetFailState( "could not establish database connection." );
		}
		CreateTimer( 180.0, RetryDatabaseConnection );
		return;
	}
	g_connection_retries = 0;
	g_db_connected = true;
	
	g_top_points = 0;
	// refresh all clients
	for( new i = 1; i <= MaxClients; i++ ) {
//		g_client_loading[client] = false;
		g_client_loaded[i] = false;
		g_client_wants_leaderboard[i] = false;
	}
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientConnected(i) &&IsClientAuthorized(i) && !IsFakeClient(i) ) {
			
			g_client_account[i] = GetSteamAccountID( i );
			LoadClientData( i );
		} else {
			g_client_account[i] = 0;
		}
	}
	RefreshTopPoints();
}

//----------------------------------------------------------------------------------------------------------------------
public ConnectionError( const String:source[], const String:error[] ) {
	LogToFile( g_logFile, "database error: %s -> %s", error, source );
	if( g_db_connected ) {
		LogToFile( g_logFile, "retrying connection in 180 seconds." );
		g_db_connected = false;
		CloseHandle( g_db );
		g_db = INVALID_HANDLE;
		CreateTimer( 180.0, RetryDatabaseConnection );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	g_client_loaded[client] = false;
	if( IsFakeClient(client) ) return;
	//g_client_loading[client] = false; 
	//g_client_newpoints[client] = 0;
}

//----------------------------------------------------------------------------------------------------------------------
public OnSQLRefreshTopPoints( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		ConnectionError( "OnSQLRefreshTopPoints", error );
		return;
	}
	if( SQL_GetRowCount(hndl) == 0 ) {
		g_top_points = 1;
	} else {
		SQL_FetchRow(hndl);
		g_top_points = SQL_FetchInt( hndl, 0 );
	}
}

//----------------------------------------------------------------------------------------------------------------------
RefreshTopPoints() {
 
	SQL_TQuery( g_db, OnSQLRefreshTopPoints, "SELECT points FROM players ORDER BY points DESC LIMIT 1" );
}

//----------------------------------------------------------------------------------------------------------------------
public OnSQLClientLogout( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		ConnectionError( "OnSQLClientLogout", error );
		return;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientDisconnect(client) {
	if( IsFakeClient(client) ) return;
	if( g_db_connected ) {
		new account = g_client_account[client];
		if( account == 0 ) return;
		CommitPlayer( client, 0, false );
		
		g_client_account[client] = 0;
	
		/*
		decl String:query[1024];
		FormatEx( query, sizeof query, 
			"UPDATE players SET ingame=0 WHERE ACCOUNT=%d",account );
		
		SQL_TQuery( g_db, OnSQLClientLogout, query );*/
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientAuthorized( client  ) {
	if( IsFakeClient(client) ) return;
	g_client_account[client] = GetSteamAccountID( client );
	if( g_db_connected ) {
		LoadClientData(client);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnSQLClientData( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	new client = GetClientOfUserId(data);
	if( client == 0 ) return; // client disconnected
	if( !hndl ) {
		ConnectionError( "OnSQLClientData", error );
		return;
	}
	
	UpdateDay();
	
	if( SQL_GetRowCount(hndl) > 0 ) {
		SQL_FetchRow( hndl );
		g_client_points[client] = SQL_FetchInt( hndl, 0 );
		g_client_dailypoints[client] = SQL_FetchInt( hndl, 1 );
		g_client_day[client] = SQL_FetchInt( hndl, 2 );
		
		if( g_client_day[client] != g_current_day ) {
			g_client_day[client] = g_current_day;
			g_client_dailypoints[client] = 0;
		}
	} else {
		g_client_points[client] = 0;
		g_client_dailypoints[client] = 0;
		g_client_day[client] = g_current_day;
	}
	g_client_loaded[client] = true;
}

//----------------------------------------------------------------------------------------------------------------------
public OnSQLClientLogin( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		ConnectionError( "OnSQLClientLogin", error );
		return;
	}
}

//----------------------------------------------------------------------------------------------------------------------
LoadClientData( client ) {
	
	decl String:query[512];
	FormatEx( query, sizeof query,
		"UPDATE players SET ingame=%d WHERE account=%d", GetTime(), g_client_account[client] );
	SQL_TQuery( g_db, OnSQLClientLogin ,query);
	FormatEx( query, sizeof query, 
		"SELECT points,daypoints,day FROM players WHERE account=%d",
		g_client_account[client] );
	SQL_TQuery( g_db, OnSQLClientData, query, GetClientUserId(client) );
}

PrintRoundInfo( client ) {
	
	if( g_client_loaded[client] && g_db_connected ) {
		if( g_point_cap && g_client_dailypoints[client] >= g_point_cap ) {
			PrintToChat( client, "\x01 \x0B[REVOCOMP]\x01 You are at the daily point cap. (%d/%d)", g_client_dailypoints[client], g_point_cap );
			return;
		}
		if( g_round_players < MIN_PLAYERS_TO_GAIN_POINTS ) {
			PrintToChat( client, "\x01 \x0B[REVOCOMP]\x01 Under %d players: Point gains are disabled.", MIN_PLAYERS_TO_GAIN_POINTS );
			return;
		}
		if( g_point_cap ) {
			PrintToChat( client, "\x01 \x0B[REVOCOMP]\x01 You have gained \x04%d\x01 of \x04%d\x01 points today.", g_client_dailypoints[client], g_point_cap );
		} else {
			PrintToChat( client, "\x01 \x0B[REVOCOMP]\x01 You have gained \x04%d\x01 of \x04Unlimited\x01 points today.", g_client_dailypoints[client] );
		}
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) { 

	
	g_round_players = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) )continue;
		if( IsFakeClient(i) ) continue;
		if( GetClientTeam(i) >= 2 ) {
			g_round_players++;
		}
		 
	}
	new time = GetTime();
	new bool:started = ( time >= g_contest_start && time < g_contest_end );
	if( started ) {
		for( new i = 1; i <= MaxClients; i++ ) {
			if( IsClientInGame(i) && !IsFakeClient(i) ) {
				PrintRoundInfo(i);
			}
		}
	
		// commit data if it has been more than 60 seconds
		if( GetTime() >= g_last_commit + 60 ) {
			CommitPlayerData(); 
		}
	}
}
//----------------------------------------------------------------------------------------------------------------------
public Action:CommitDataTimer( Handle:timer ) {
	// commit data if it has been 5 minutes
	if( GetTime() >= g_last_commit + 300 ) {
		CommitPlayerData();
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_forcecommit( client, args ) {
	CommitPlayerData();
}

//----------------------------------------------------------------------------------------------------------------------
public OnSQLCommitData( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		ConnectionError( "OnSQLCommitData", error );
		return;
	}
}

//----------------------------------------------------------------------------------------------------------------------
CommitPlayer( client, time, bool:updatename ) {
	decl String:query[1024];
	decl String:name[64];
	GetClientName( client, name, sizeof name );
	
	if( updatename ) {
		decl String:safename[128];
		SQL_EscapeString( g_db, name, safename, sizeof safename );
		FormatEx( query, sizeof query, 
			"INSERT INTO players (account,points,daypoints,day,ingame,name) VALUES (%d,%d,%d,%d,%d,'%s') ON DUPLICATE KEY UPDATE points=%d,daypoints=%d,day=%d,ingame=%d,name='%s'",
			g_client_account[client], g_client_points[client], g_client_dailypoints[client], g_client_day[client], time, safename,
			g_client_points[client], g_client_dailypoints[client], g_client_day[client], time, safename );
	} else {
		FormatEx( query, sizeof query, 
			"INSERT INTO players (account,points,daypoints,day,ingame) VALUES (%d,%d,%d,%d,%d) ON DUPLICATE KEY UPDATE points=%d,daypoints=%d,day=%d,ingame=%d",
			g_client_account[client], g_client_points[client], g_client_dailypoints[client], g_client_day[client], time, 
			g_client_points[client], g_client_dailypoints[client], g_client_day[client], time );
	}
	SQL_TQuery( g_db, OnSQLCommitData, query );
}

//----------------------------------------------------------------------------------------------------------------------
CommitPlayerData( ) {
	if( !g_db_connected ) return;
	
	new time = GetTime();
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && g_client_loaded[i] ) {
			if( IsFakeClient(i) ) continue;
			CommitPlayer(i, time,true);
			
			
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public AddPoints( client, points, const String:message[] ) {
	//LogToFile( g_logFile, "ADDPOINTS1" );
	if( !g_db_connected ) return 0;
	//LogToFile( g_logFile, "ADDPOINTS2" );
	if( !g_client_loaded[client] ) return 0;
	//LogToFile( g_logFile, "ADDPOINTS3" )	;
	//if( g_top_points == 0 ) return 0;
	//LogToFile( g_logFile, "ADDPOINTS4" );
	new time = GetTime();
	if( time < g_contest_start || time >= g_contest_end ) return 0;
	
	if( g_point_cap && (g_client_dailypoints[client] >= g_point_cap) ) {
		return 0;// point cap
	}
	
	if( g_round_players < MIN_PLAYERS_TO_GAIN_POINTS ) return 0;
	
	new bool:capped = false;
	g_client_dailypoints[client] += points;
	if( g_point_cap && (g_client_dailypoints[client] >= g_point_cap) ) {
		points -= (g_client_dailypoints[client] - g_point_cap);
		g_client_dailypoints[client] = g_point_cap;
		capped = true;
		 
	}
	
	new Float:mul = 1.0;
	if( (g_top_points-g_client_points[client]) > 50000 ) {
		mul = 1.0 + Pow(1.0-float(g_client_points[client])/float(g_top_points),3.0)*2.0;
		if( mul < 1.0 ) mul = 1.0;
	}
	
	
	points = RoundToFloor(float(points) * mul); 
	
	if( message[0] != 0 ) {
		decl String:pointstring[64];
		FormatEx( pointstring, sizeof pointstring, "\x05+%d point%s\x01", points, points == 1 ? "":"s" );
		decl String:message2[256];
		strcopy( message2, sizeof message2, message );
		ReplaceString( message2, sizeof message2, "{points}", pointstring );
		PrintToChat( client, "\x01 %s", message2 ); 
	}
	
	if( points > 0 ) {
		g_client_points[client] += points;
		LogToFile( g_logFile, "ADDING points %N +%d", client, points );
		if( g_client_points[client] > g_top_points ) g_top_points = g_client_points[client];
	}
	
	if( capped ) {
		PrintToChat( client, "\x01 \x0B[REVOCOMP]\x0E You have reached the daily point cap!" );
	}
	return points;
}


//----------------------------------------------------------------------------------------------------------------------
public OnGetLeaders( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	g_refreshing_leaderboard = false;
	if( !hndl ) { 
		ConnectionError( "OnGetLeaders", error );
		return;
	}
	
	g_num_lb = SQL_GetRowCount(hndl);
	if( g_num_lb > LB_ENTRIES ) g_num_lb = LB_ENTRIES;
	for( new i = 0; i < g_num_lb; i++ ) {
		SQL_FetchRow(hndl);
		g_leaderboard_account[i] = SQL_FetchInt( hndl, 0 );
		g_leaderboard_points[i] = SQL_FetchInt( hndl, 1 );
		SQL_FetchString( hndl, 2, g_leaderboard_names[i], sizeof(g_leaderboard_names[]) );
		
		LogToFile( g_logFile, "LB ENTRY %d, %d, %s", g_leaderboard_account[i], g_leaderboard_points[i], g_leaderboard_names[i] );
	}
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( g_client_wants_leaderboard[i] ) {
			DisplayLeaderboard(i);
		}
	}
	g_leaderboard_lastpolltime = GetTime(); 
}


ShowTimeLeft(client) {
	if( GetTime() < g_contest_start ) {
		PrintToChat( client, "\x01 REVOCOMP has not started yet." );
		return;
	}
	new endtime = g_contest_end - GetTime();
	if( endtime > 0 ) {
		if( endtime < 60 ) {
			PrintToChat( client, "\x01 \x01The contest ends in \x02%d second\x01!!!", endtime, endtime == 1 ? "":"s" );
		} else if( endtime < 60*60 ) {
			endtime = endtime / 60;
			PrintToChat( client, "\x01 \x01The contest ends in \x02%d minute%s\x01!!!", endtime, endtime == 1 ? "":"s" );
		} else if( endtime < 60*60*24 ) {
			endtime = endtime / (60*60);
			PrintToChat( client, "\x01 \x01The contest ends in \x09%d hour%s\x01!", endtime, endtime == 1 ? "":"s" );
		} else {
			endtime = endtime / (60*60*24);
			PrintToChat( client, "\x01 \x01The contest ends in \x05%d day%s\x01.", endtime, endtime == 1 ? "":"s" );
		}
	} else if( endtime > -(60*60*24*3) ) {
		PrintToChat( client, "\x01 \x02The contest has ended!" );
	}
}

public PanelHandler1(Handle:menu, MenuAction:action, param1, param2) {
	
}

//----------------------------------------------------------------------------------------------------------------------
DisplayLeaderboard( client ) {
	g_client_wants_leaderboard[client] = false;
	if( !IsClientInGame(client) ) return;
	
	if( g_num_lb == 0 ) return;
	
	new Handle:menu = CreatePanel();//CreateMenu( ContestMenuHandler );
	SetPanelTitle( menu, "REVOCOMP LEADERBOARD" );

	
	//SetMenuExitButton( menu, false );
	//new bool:foundself;
	for( new i = 0; i < g_num_lb; i++ ) {
		decl String:text[128];
		decl String:name[128];
		new points;
		new account = g_leaderboard_account[i];
		strcopy( name, sizeof name, g_leaderboard_names[i] );
		points = g_leaderboard_points[i];
		
		if( account == g_client_account[client] ) {
			points = g_client_points[client];
		//	foundself = true;
		}
		
		FormatEx( text, sizeof text, "[%d] %s - %d points", i+1, name, points);
		
		DrawPanelText( menu, text );
	}
	DrawPanelItem( menu, "Exit" );
	/*
	if( !foundself ) {
		decl String:text[128];
		FormatEx( text, sizeof text, "You have %d points.", g_client_points[client] );
		AddMenuItem( menu, "", text );
	}*/
	
	SendPanelToClient( menu, client, PanelHandler1, 20 );
	CloseHandle(menu);
	
}

//----------------------------------------------------------------------------------------------------------------------
GetLeaderboard(client) {
	if( g_client_wants_leaderboard[client] && g_refreshing_leaderboard ) return;
	if( g_refreshing_leaderboard ) {
		g_client_wants_leaderboard[client] = true;
		return;
	}
	if( GetTime() > g_leaderboard_lastpolltime + 30 ) {
		g_refreshing_leaderboard = true;
		SQL_TQuery( g_db, OnGetLeaders, "SELECT account,points,name FROM players ORDER BY points DESC LIMIT 10" );
		g_client_wants_leaderboard[client] = true;
	} else {
		DisplayLeaderboard(client);
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
public ContestMenuHandler( Handle:menu, MenuAction:action, client, param2) {
	if( action == MenuAction_DisplayItem ) {
		if( param2 == 0 ) {
			decl String:text[64];
			FormatEx( text,sizeof text, "Your points: %d", g_client_points[client] );
			RedrawMenuItem( text );
		} else if( param2 == 1 ) {
			decl String:text[64];
			if( g_point_cap > 0 ) {
				FormatEx( text,sizeof text, "Daily points: %d/%d (%d%%)", g_client_dailypoints[client], g_point_cap, (g_client_dailypoints[client]*100 / g_point_cap) );
			} else {
				FormatEx( text,sizeof text, "Daily points: %d/Unlimited", g_client_dailypoints[client] );
			}
			RedrawMenuItem( text );
		}
	} else if( action == MenuAction_Select ) {
		if( param2 == 2 ) {
			GetLeaderboard(client);
		}
	}
}
//----------------------------------------------------------------------------------------------------------------------
ShowContestMenu(client) {
	ShowTimeLeft(client); 
	if( GetTime() >= g_contest_start ) {
	
		DisplayMenu( g_menu, client, 20 );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_contest( client, args ) {
	//PrintToChat( client, "\x01 \x02 *** TEST MODE *** THERE IS NO CONTEST, THIS PLUGIN IS BEING DEVELOPED. ***" ); DEBUG VERSION
	if( !g_client_loaded[client] || !g_db_connected ) {
		PrintToChat( client, "The database is currently unavailable." );
		return Plugin_Handled;
	}
	ShowContestMenu( client );
	
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Native_AddPoints( Handle:plugin, numParams ) {
	decl String:message[64];
	GetNativeString( 3, message, sizeof message );
	return AddPoints( GetNativeCell(1), GetNativeCell(2), message );
}

//----------------------------------------------------------------------------------------------------------------------
public Native_GetTopPoints( Handle:plugin, numParams ) {
	return g_top_points;
}

//----------------------------------------------------------------------------------------------------------------------
public Native_GetPoints( Handle:plugin, numParams ) {
	new c = GetNativeCell(1);
	if( !g_client_loaded[c] ) return -1;
	return g_client_points[c];
}

//----------------------------------------------------------------------------------------------------------------------
public Native_GetRoundPlayers( Handle:plugin, numParams ) {
	return g_round_players;
}

//----------------------------------------------------------------------------------------------------------------------
UpdateDay() {
	new time = GetTime();
	
	time -= g_contest_start;
	
	// the first day is only 18 hours long (12:00PM -> 6:00 AM CDT)
	
	
	new day_offset = (g_contest_start % 86400); // seconds into the first day that the contest starts
	day_offset -= 11*60*60; // 6:00 AM CDT (11:00 UTC)
	if( day_offset < 0 ) day_offset += 86400;
	
	new day = (time+day_offset) / 86400;
	
	if( g_current_day != day ) {
		g_current_day = day;
		if( time >= 0 && time < (g_contest_end - g_contest_start) ) {
			//new day_index = day - (g_contest_start/86400);
			g_point_cap = GetPointCap( day );
		} else {
			g_point_cap = 0;
		}
		
		for( new i = 1; i <= MaxClients; i++ ) {
			if( g_client_loaded[i] ) {
				if( g_client_day[i] != day ) {
					g_client_day[i] = day;
					g_client_dailypoints[i] = 0;
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
GetPointCap( day ) {
	// REVOCOMP point caps
	
	
	if( day < 7 ) {
		return 7500;
	} else if( day < 14 ) {
		return 16000;
	} else if( day < 21 ) {
		return 25000;
	} else {
		return 0;
	}
}

