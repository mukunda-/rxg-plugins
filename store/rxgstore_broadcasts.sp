
#include <sourcemod>
#include <rxgstore>
#include <rxgcommon>

#undef REQUIRE_PLUGIN
#include <sourceirc>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "RXG Store Broadcasts",
    author      = "WhiteThunder",
    description = "Broadcasts Store Events",
    version     = "1.0.1",
    url         = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

char g_initial_space[6];
char g_item_color[11];
char g_irc_prefix[] = "\x030,3[STORE] ";

//-----------------------------------------------------------------------------
bool use_irc;

public void OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		use_irc = true;
}
public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "sourceirc"))
		use_irc = true;
}
public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "sourceirc"))
		use_irc = false;
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	RegServerCmd( "sm_store_broadcast_purchase",       Command_broadcast_purchase       );
	RegServerCmd( "sm_store_broadcast_gift_send",      Command_broadcast_gift_send      );
	RegServerCmd( "sm_store_broadcast_gift_receive",   Command_broadcast_gift_receive   );
	RegServerCmd( "sm_store_broadcast_reward_receive", Command_broadcast_reward_receive );
	RegServerCmd( "sm_store_broadcast_giveaway_claim", Command_broadcast_giveaway_claim );
	RegServerCmd( "sm_store_broadcast_review",         Command_broadcast_review         );
	
	char gamedir[8];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual( gamedir, "csgo", false )) {
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	g_initial_space = (GAME == GAME_CSGO) ? "\x01 " : "";
	g_item_color = (GAME == GAME_TF2) ? "\x07874fad" : "\x03";
}

/** ---------------------------------------------------------------------------
 * Find a client with a matching account id.
 *
 * @param account Account ID to search for.
 *
 * @returns Client index or 0 if the account isn't found.
 */
int FindClientFromAccount( int account ) {
	
	for( int i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		int acc = GetSteamAccountID(i);
		if( acc == account ) {
			return i;
		}
	}
	return 0;
}

//-----------------------------------------------------------------------------
void GetPlayerTeamColor( int client, char[] color, int color_size ) {
	
	int  client_team = GetClientTeam( client );
	char team_color[11];
	
	if( client_team == 2 ){
		team_color = (GAME == GAME_TF2) ? "\x07ff3d3d" : "\x09";
	} else if( client_team == 3 ){
		team_color = (GAME == GAME_TF2) ? "\x0784d8f4" : "\x0B";
	} else {
		team_color = (GAME == GAME_TF2) ? "\x07808080" : "\x08";
	}
	
	FormatEx( color, color_size, team_color );
}

//-----------------------------------------------------------------------------
void GetPlayerNameColored( int client, char[] msg, int msg_size,
                           bool start_of_msg = false ) {
	
	char player_name[33];
	GetClientName( client, player_name, sizeof player_name );
	
	char team_color[11];
	GetPlayerTeamColor( client, team_color, sizeof team_color );
	
	if( start_of_msg ) {
		FormatEx( msg, msg_size, "%s%s%s", g_initial_space, team_color, player_name );
	} else {
		FormatEx( msg, msg_size, "%s%s", team_color, player_name );
	}
}

//-----------------------------------------------------------------------------
void BroadcastStoreActivity( int args, const char[] msg, const char[] irc_msg,
							 int startAtArg = 2 ) {
	
	if( args == 0 ) return;
	
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return;
	
	char player_name_colored[65];
	GetPlayerNameColored( client, player_name_colored,
						  sizeof player_name_colored, true );
	
	if( use_irc ) {
		char player_name[33];
		GetClientName( client, player_name, sizeof player_name );
		IRC_MsgFlaggedChannels( "relay", irc_msg, g_irc_prefix, player_name );
	}
	
	PrintToChatAll( msg, player_name_colored );
	BroadcastStoreItems( args, startAtArg );
}

//-----------------------------------------------------------------------------
void BroadcastStoreItems( int args, int startAtArg = 2 ) {
	
	if( args == 0 ) return;
	
	int arg = startAtArg;
	
	// print each item
	while( args >= arg ) {
		char item[64];
		GetCmdArg( arg, item, sizeof item );
		PrintToChatAll( "%s%s%s", g_initial_space, g_item_color, item );
		arg++;
	}
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_purchase( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s \x01just made a \x04!store \x01purchase:",
		"%s%s made a purchase" );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_gift_send( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s \x01just sent a \x04!store \x01gift:",
		"%s%s sent a gift" );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_gift_receive( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s \x01just accepted a \x04!store \x01gift:",
		"%s%s accepted a gift" );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_reward_receive( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s \x01just accepted a \x04!store \x01reward:",
		"%s%s accepted a reward" );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_giveaway_claim( int args ) {
	
	if( args == 0 ) return Plugin_Handled;
	
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return Plugin_Handled;
	
	char giveaway_name[65];
	GetCmdArg( 2, giveaway_name, sizeof giveaway_name );
	
	char player_name_colored[65];
	GetPlayerNameColored( client, player_name_colored,
						  sizeof player_name_colored, true );
	
	PrintToChatAll( "%s \x01just claimed the \x04!store \x01%s:",
                    player_name_colored, giveaway_name );
    
	if( use_irc ) {
		char player_name[33];
		GetClientName( client, player_name, sizeof player_name );
		IRC_MsgFlaggedChannels( "relay", "%s%s claimed the %s",
								g_irc_prefix, player_name, giveaway_name );
	}
	
	BroadcastStoreItems( args, 3 );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_review( int args ) {
	
	if( args == 0 ) return Plugin_Handled;
 
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return Plugin_Handled;
	
	char player_name_colored[65];
	GetPlayerNameColored( client, player_name_colored,
						  sizeof player_name_colored, true );
	
	char team_color[11];
	GetPlayerTeamColor( client, team_color, sizeof team_color );
	
	char item_name[70];
	GetCmdArg( 2, item_name, sizeof item_name );
	
	PrintToChatAll(
		"%s \x01just wrote a \x04!store \x01review about the %s%s",
		player_name_colored, g_item_color, item_name );
	
	if( use_irc ) {
		char player_name[33];
		GetClientName( client, player_name, sizeof player_name );
		IRC_MsgFlaggedChannels( "relay",
			"%s%s wrote a review about the %s",
			g_irc_prefix, player_name, item_name );
	}
	
	return Plugin_Handled;
}
