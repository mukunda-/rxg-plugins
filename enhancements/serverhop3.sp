

#include <sourcemod>
#include <socket>

#undef REQUIRE_PLUGIN
#include <updater>

// 1.0.5 11:25 AM 5/27/2014
//  - ignore bots
// 1.0.4 9:04 PM 10/28/2013
//  - fixed server crash bug when no other servers active
// 1.0.3 5:25 PM 10/28/2013
//  - dont advertise empty servers (may add a variable later)
//

#define MAX_SERVERS 10
#define REFRESH_TIME 10.0
#define MENU_TIMEOUT 20

public Plugin:myinfo = {
	name = "Server Hop [rxgcsgo edition]",
	author = "[GRAVE] rig0r",
	description = "Provides live server info with join option",
	version = "1.0.4",
	url = "http://www.gravedigger-company.nl"
};

new String:my_ip[128];

new String:server_address[MAX_SERVERS][64];
new server_port[MAX_SERVERS];
new String:server_name[MAX_SERVERS][64];
new String:si_map[MAX_SERVERS][64];
new si_players[MAX_SERVERS];
new si_maxplayers[MAX_SERVERS];
new bool:si_refreshing[MAX_SERVERS];
new Handle:socket[MAX_SERVERS];
new server_count;

new is_scrim_server[MAX_SERVERS];
new show_map[MAX_SERVERS];

new lobby_only;

//new bool:socket_error[MAX_SERVERS];

new ad_iterator;
new ad_divider;

new server_update_iterator;

new Handle:sm_serverhop_adtime;
new c_serverhop_adtime;

#define UPDATE_URL "http://www.mukunda.com/plugins/serverhop3/update.txt"

//-------------------------------------------------------------------------------------------------
public CvarChanged ( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	if( convar == sm_serverhop_adtime ) {
		c_serverhop_adtime = GetConVarInt( sm_serverhop_adtime );
	}
} 

//-------------------------------------------------------------------------------------------------
LoadConfig() {
	
	decl String:path[256];
	new Handle:kv;
	BuildPath( Path_SM, path, sizeof(path), "configs/serverhop.cfg" );
	kv =CreateKeyValues("Servers");
	if( !FileToKeyValues(kv,path) ) {
		SetFailState( "couldn't load server listing" );
		return;
	}
	
	server_count = 0;
	
	KvRewind(kv);
	KvGotoFirstSubKey(kv);
	do {
		KvGetSectionName( kv, server_name[server_count], sizeof(server_name[]) );
		KvGetString( kv, "address", server_address[server_count], sizeof(server_address[]) );
		is_scrim_server[server_count] = KvGetNum( kv, "scrim", 0 );

		// todo: DNS shit if the user doesnt give a direct IP
		if( StrEqual( server_address[server_count], my_ip ) ) {
			lobby_only = is_scrim_server[server_count];

			continue; // dont add ourselves

		}
		
		show_map[server_count] = KvGetNum( kv, "showmap", 1 );
		server_port[server_count] = KvGetNum( kv, "port", 27015 );
		server_count++;
		if( server_count == MAX_SERVERS ) break;
	} while( KvGotoNextKey(kv) );
	
	
	CloseHandle(kv);
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "sm_servers", Command_servers );
	
	new ipraw = GetConVarInt( FindConVar("hostip") );
	
	new ip[4];
	ip[0] = (ipraw>>24) & 255;
	ip[1] = (ipraw>>16) & 255;
	ip[2] = (ipraw>>8) & 255
	ip[3] = (ipraw) & 255;
	
	Format( my_ip, sizeof(my_ip), "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3] );

	
	LoadConfig();
	RefreshAllServers();
	CreateTimer( REFRESH_TIME, RefreshServerTimer, _, TIMER_REPEAT );
	
	// get ip of server
	
	sm_serverhop_adtime = CreateConVar( "sm_serverhop_adtime", "10", "Time between server advertisements (in 10 second units???).", FCVAR_PLUGIN );
	HookConVarChange( sm_serverhop_adtime, CvarChanged );
	
	c_serverhop_adtime = GetConVarInt( sm_serverhop_adtime );
	
	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	// nobody likes old bacon
	if( StrEqual( name, "updater" ) ) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

//-------------------------------------------------------------------------------------------------
public Action:RefreshServerTimer( Handle:timer ) {
	ServerRefresh();
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
Advertise() {

	
	// for lobby_only (scrim servers) show adverts only when in lobby
	if( lobby_only ) {
		decl String:map[64];
		GetCurrentMap( map, sizeof(map) );
		if( strncmp( map, "rxglobby", 8 ) != 0 ) return;
	}

	ad_iterator++;
	if( ad_iterator >= server_count ) {
		ad_iterator = 0;
	}
	new original_iterator = ad_iterator;
	
	while( si_maxplayers[ad_iterator] == 0 || si_players[ad_iterator] == 0 ) {
		ad_iterator++;
		if( ad_iterator >= server_count ) {
			ad_iterator = 0;
		}
		if( ad_iterator == original_iterator ) return; // catch zero active servers
	}
	
	
	
	new maxplayers = si_maxplayers[ad_iterator];

	if( !is_scrim_server[ad_iterator] ) {
		
		new playercolor = si_players[ad_iterator] >= maxplayers ? 7 : 1;
		PrintToChatAll( "\x01 \x0C(Servers)\x01 \x09%s\x01%s\x01%s\x01%s [%c%d\x01/%c%d\x01]\x08 - type \x01!servers \x08to join",
			server_name[ad_iterator],
			show_map[ad_iterator] ? " (":"",
			show_map[ad_iterator] ? si_map[ad_iterator]:"",
			show_map[ad_iterator] ? ")":"",
			playercolor,si_players[ad_iterator],
			playercolor,maxplayers);
	} else {
		new playercolor = si_players[ad_iterator] >= maxplayers ? 7 : 1;
		if( strncmp( si_map[ad_iterator], "rxglobby", 8 ) == 0 || si_map[ad_iterator][0] == 0 ) {
			
			PrintToChatAll( "\x01 \x0C(Servers)\x01 \x09%s\x01 [%c%d\x01/%c%d\x01]\x08 - type \x01!servers\x08 to join", 
				server_name[ad_iterator],
				playercolor,si_players[ad_iterator],
				playercolor,maxplayers );
		} else {
			PrintToChatAll( "\x01 \x0C(Servers)\x01 \x09%s\x01 \x08(in progress)", 
				server_name[ad_iterator] );
		}
	}
}

//-------------------------------------------------------------------------------------------------
RefreshAllServers() {
	for( new i = 0; i < server_count; i++ ) {
		UpdateServer(i);
	}
}

//-------------------------------------------------------------------------------------------------
UpdateServer( index ) {
	if( si_refreshing[index] ) {
		// server timed out / is down
		si_refreshing[index] = false;
		si_maxplayers[index] = 0;
		CloseHandle(socket[index]);
	}
	
	si_refreshing[index] = true;
	//socket_error[i] = false;
	socket[index] = SocketCreate( SOCKET_UDP, OnSocketError );
	SocketSetArg( socket[index], index );
	SocketConnect( socket[index], OnSocketConnected, OnSocketReceive, OnSocketDisconnected, server_address[index], server_port[index] );

}

//-------------------------------------------------------------------------------------------------
ServerRefresh() {

	ad_divider++;
	if( ad_divider >= c_serverhop_adtime ) ad_divider = 0;
	if( ad_divider == 0 ) {
		Advertise();
	}
	
	UpdateServer( server_update_iterator );
	server_update_iterator++;
	if( server_update_iterator >= server_count ) server_update_iterator = 0;
	 
}
 
//-------------------------------------------------------------------------------------------------
public OnSocketConnected( Handle:sock, any:i )
{
	decl String:requestStr[ 25 ];
	Format( requestStr, sizeof( requestStr ), "%s", "\xFF\xFF\xFF\xFF\x54Source Engine Query" );
	SocketSend( sock, requestStr, 25 );
}

//-------------------------------------------------------------------------------------------------
TrimMap( String:map[], maxlen ) {

	// skip slashes (workshop maps)
	new slash = FindCharInString( map, '\\', true );
	if( slash != -1 ) Format( map, maxlen, "%s", map[slash+1] );
	slash = FindCharInString( map, '/', true );
	if( slash != -1 ) Format( map, maxlen, "%s", map[slash+1] );
	slash = FindCharInString( map, '_' );
	if( slash != -1 ) Format( map, maxlen, "%s", map[slash+1] );
}

//-------------------------------------------------------------------------------------------------
public OnSocketReceive( Handle:sock, String:receive_data[], const data_size, any:i ) {
	decl String:text[256];
	new offset = 2; // skip header,protocol
	
	offset += strlen( receive_data[offset] )+1; // server name( not used )
	
	strcopy( text, sizeof(text), receive_data[offset] ); // map name
	offset += strlen(text)+1;
	
	TrimMap(text,sizeof(text));
	strcopy( si_map[i], sizeof(si_map[]), text ); // save map
	
	offset += strlen( receive_data[offset] )+1; // game dir
	offset += strlen( receive_data[offset] )+1; // game desc
	offset += 2; // game ID
	
	si_players[i] = receive_data[offset++]; // players
	si_maxplayers[i] = receive_data[offset++]; // max. players
	si_players[i] -= receive_data[offset++]; // bots
	if( si_players < 0 ) si_players = 0;
	
	si_refreshing[i] = false;
	CloseHandle( sock );
}

//-------------------------------------------------------------------------------------------------
public OnSocketDisconnected( Handle:sock, any:i ) {
	si_refreshing[i] = false;
	CloseHandle( sock );
}

//-------------------------------------------------------------------------------------------------
public OnSocketError( Handle:sock, const errorType, const errorNum, any:i ) {
	si_maxplayers[i] = 0;
	si_refreshing[i] = false;
	CloseHandle( sock );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_servers( client, args ) {
	
	new Handle:menu = CreateMenu( ServerMenuHandler );
	
	// build servers menu
	new total = 0;
	for( new i = 0; i < server_count; i++ ) {
 
		decl String:serverstring[128];
		
		if( si_maxplayers[i] == 0 ) continue;
		
		if( !is_scrim_server[i] ) {
			
			
			Format( serverstring, sizeof(serverstring), "%s%s%s%s (%d/%d)",
				server_name[i],
				show_map[i] ? " [":"",
				show_map[i] ? si_map[i]:"",
				show_map[i] ? "]":"",
				si_players[i],
				si_maxplayers[i] );
				
		} else {
			if( strncmp( si_map[i], "rxglobby", 8 ) == 0 || si_map[i][0] == 0 ) {
				Format( serverstring, sizeof(serverstring), "%s%s%s%s (%d/%d)",
					server_name[i],
					show_map[i] ? " [":"",
					show_map[i] ? si_map[i]:"",
					show_map[i] ? "]":"",
					si_players[i],
					si_maxplayers[i] );
			} else {
				continue; // do not list in-progress scrim server
			}
		}
		
		decl String:info[32];
		Format( info, sizeof(info), "%d", i );
		AddMenuItem( menu, info, serverstring );
		total++;
	}
	if( total == 0 ) {
		CloseHandle(menu);
		PrintToChat( client, "There are no available servers; please try again later." );
		return Plugin_Handled;
	}
	
	
	DisplayMenu( menu, client, MENU_TIMEOUT );
	
	return Plugin_Handled;
}

public ServerMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_End ) {
		CloseHandle( menu );
	} else if( action == MenuAction_Select ) {
		decl String:info[32];
		decl String:disp[128];
		GetMenuItem(menu, param2, info, sizeof(info),_,disp,sizeof(disp));
		new index = StringToInt(info);
		
		new spaces = 57-strlen(disp);
		if( spaces < 1 ) spaces = 1;
		//decl String:formatstring[64];
		//Format(formatstring,sizeof(formatstring), "%%s%%%dc", spaces );
		
		Format( disp, sizeof(disp), "%-57s", disp );//formatstring, disp, ' ' );
		
		new client = param1;
		PrintToChat( client,"\x01\x0B\x04(Server Hop)\x01 Please open your console and copy and paste the command provided to switch servers." );
		
		
		
		PrintToConsole( client, "**************************************************************" );
		PrintToConsole( client, "*                        SERVER HOP                          *" );
		PrintToConsole( client, "* You have selected:                                         *" );
		PrintToConsole( client, "*   %s*", disp                                                  );
		PrintToConsole( client, "*                                                            *" );
		PrintToConsole( client, "* Please copy (and run) the command below to switch servers. *" );
		PrintToConsole( client, "* You will probably have to run it twice because CS:GO is so *" );
		PrintToConsole( client, "* broken. (the first time will just disconnect you)          *" );
		PrintToConsole( client, "--------------------------------------------------------------" );
		PrintToConsole( client, "connect %s:%d", server_address[index], server_port[index] );
		PrintToConsole( client, "--------------------------------------------------------------" );
		PrintToConsole( client, "* and then complain to Valve how there is no automatic       *" );
		PrintToConsole( client, "* redirect feature in CS:GO!                                 *" );
		PrintToConsole( client, "**************************************************************" );
	}
}
