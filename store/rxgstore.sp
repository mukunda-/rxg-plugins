
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgstore>
#include <dbrelay>
#include <rxgcommon>

#pragma semicolon 1
#pragma newdecls required

// 1.0.4
//   bugfix with credit
// 1.0.3
//   sm_store command
// 1.0.2
//   added RXGSTORE_IsConnected

//-----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "rxgstore",
    author      = "mukunda",
    description = "rxg store api",
    version     = "2.5.2",
    url         = "www.mukunda.com"
};

//-----------------------------------------------------------------------------
#define ITEM_MAX 16

//#define RXG_CSGO_CLAN "#rxg"
#define LOCK_DURATION_EXPIRE 30.0

// the ip for this server (hostip converted into ipv4 format)
char c_ip[32];


char g_item_map[4096];           // map of real items to item slots
int  g_item_ids[ITEM_MAX];       // reverse mapping, 0 = slot not used
char g_item_names[ITEM_MAX][64]; // names of registered items
char g_item_fullnames[ITEM_MAX][64]; // fullnames of registered items
StringMap g_item_trie;           // map of names to item slots          
int  g_item_serial[ITEM_MAX];    // item slot serial number to detect plugin
                                 // changes in callbacks
int  g_next_serial=1;

Handle   g_item_plugins[ITEM_MAX];      // plugins implementing the items
Function g_item_functions[ITEM_MAX][4]; // cached plugin function addresses

// only one function defined currently:
#define ITEMFUNC_ONUSE 0

//-----------------------------------------------------------------------------
// a snippet of sql code that contains the item id filter 
// as a IN(...) clause
//
char g_sql_itemid_filter[128];

// client item counts
int g_client_items[MAXPLAYERS+1][ITEM_MAX];

// false if inventory hasn't been loaded yet
bool g_client_data_loaded[MAXPLAYERS+1];
                                             
// cache of the client's account id. This is stored here in the event that
// a client disconnects and you need to perform a commit.
int  g_client_data_account[MAXPLAYERS+1]; 
        
// record of what items a client uses or gains, a buffer of changes
// that is used during a commit.
int g_client_items_change[MAXPLAYERS+1][ITEM_MAX];
 
// amount of rxg dollars each player has.
int g_client_cash[MAXPLAYERS+1];

// amount that they have spent or received since the last commit.
int g_client_cash_change[MAXPLAYERS+1]; 

// the last time a client used an item, used for throttling item commands.
float g_client_item_last_used[MAXPLAYERS];

// the number of seconds a client has to wait after using an item before
// he can use another one.
#define ITEM_USE_COOLDOWN 0.25

// special item IDs
enum {
	SPITEM_CREDIT = 101, // a cash item
};

//---------------------------------------------------
// conditions before an item can be used:
//  DBRELAY_IsConnected() is TRUE
//  client_data_loaded is TRUE 
//  client_items[item]+client_items_change[item] > 0
//---------------------------------------------------
 
enum UpdateMethod {
	UPDATE_METHOD_ROUND = 0, // load inventories every round
	UPDATE_METHOD_TIMED = 1  // load inventories after an interval
};

// update method (for loading inventories)
UpdateMethod g_update_method;
float        g_last_update; // game time of the last update

#define MIN_UPDATE_PERIOD 30.0
  
#define UPDATE_TIMED_INTERVAL 50.0

//-----------------------------------------------------------------------------
#pragma unused GAME
int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1 

//-----------------------------------------------------------------------------
void RegisterLibrary() {
	CreateNative( "RXGSTORE_RegisterItem",     Native_RegisterItem );
	CreateNative( "RXGSTORE_UnregisterItem",   Native_UnregisterItem );
	CreateNative( "RXGSTORE_IsItemRegistered", Native_IsItemRegistered );
	CreateNative( "RXGSTORE_ItemCount",        Native_ItemCount );
	CreateNative( "RXGSTORE_GetCash",          Native_GetCash );
	CreateNative( "RXGSTORE_AddCash",          Native_AddCash );
	CreateNative( "RXGSTORE_TakeCash",         Native_TakeCash );
	CreateNative( "RXGSTORE_CanUseItem",       Native_CanUseItem );
	CreateNative( "RXGSTORE_UseItem",          Native_UseItem );
	CreateNative( "RXGSTORE_GiveItem",         Native_GiveItem );
	CreateNative( "RXGSTORE_ShowUseItemMenu",  Native_ShowUseItemMenu );
	CreateNative( "RXGSTORE_IsClientLoaded",   Native_IsClientLoaded );
	CreateNative( "RXGSTORE_IsConnected",      Native_IsConnected );
	
	RegPluginLibrary( "rxgstore" );
}

//-----------------------------------------------------------------------------
public APLRes AskPluginLoad2( Handle myself, bool late, char[] error, 
                              int err_max ) {

	g_item_trie = new StringMap();
	
	char gamedir[8];
	GetGameFolderName( gamedir, sizeof gamedir );
	
	if( StrEqual( gamedir, "csgo", false )) {
		g_update_method = UPDATE_METHOD_ROUND;
		GAME = GAME_CSGO;
	} else {
		g_update_method = UPDATE_METHOD_TIMED;
		GAME = GAME_TF2;
	}
	
	RegisterLibrary();
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	RegConsoleCmd( "sm_cash",  Command_cash );
	RegConsoleCmd( "useitem",  Command_use_item );
	RegConsoleCmd( "items",    Command_items );
	RegConsoleCmd( "sm_store", Command_store );
	RegConsoleCmd( "sm_shop",  Command_store );
	RegConsoleCmd( "sm_buy",   Command_store );
	
	RegServerCmd( "sm_store_unload_inventory",         Command_unload_user_inventory    );
	RegServerCmd( "sm_store_reload_inventory",         Command_reload_user_inventory    );
	RegServerCmd( "sm_store_broadcast_purchase",       Command_broadcast_purchase       );
	RegServerCmd( "sm_store_broadcast_gift_send",      Command_broadcast_gift_send      );
	RegServerCmd( "sm_store_broadcast_gift_receive",   Command_broadcast_gift_receive   );
	RegServerCmd( "sm_store_broadcast_reward_receive", Command_broadcast_reward_receive );
	RegServerCmd( "sm_store_broadcast_review",         Command_broadcast_review         );
	
	if( g_update_method == UPDATE_METHOD_TIMED ) {
		CreateTimer( UPDATE_TIMED_INTERVAL, OnTimedUpdate, _, TIMER_REPEAT );
	} else if( g_update_method == UPDATE_METHOD_ROUND ) {
		HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	}
	
	// parse ip
	int longIP = GetConVarInt( FindConVar( "hostip" ));
	int pieces[4];
	
	pieces[0] = (longIP & 0xFF000000) >> 24;
	pieces[1] = (longIP & 0x00FF0000) >> 16;
	pieces[2] = (longIP & 0x0000FF00) >> 8;
	pieces[3] = (longIP & 0x000000FF);

	// format as ipv4
	FormatEx( c_ip, sizeof c_ip, "%d.%d.%d.%d",
              pieces[0], pieces[1], pieces[2], pieces[3] );
	
	BuildSQLItemIDFilter();
}

/** ---------------------------------------------------------------------------
 * Find a client with a matching account id.
 *
 * @param account Account ID to search for.
 *
 * @returns Client index or 0 if the account isn't found.
 */
int FindClientFromAccount( int account ) {
	// TODO are disconnected clients handled safely??
	
	for( int i = 1; i <= MaxClients; i++ ) {
		if( g_client_data_account[i] == account ) {
			return i;
		}
	}
	return 0;
}

//-----------------------------------------------------------------------------
public Action Command_unload_user_inventory( int args ) {
	
	if( args == 0 ) return Plugin_Handled;
	
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return Plugin_Handled;
	
	g_client_data_loaded[client] = false;
	//PrintToChat( i, "\x01 \x04[STORE]\x01 Your inventory has been unloaded." );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_reload_user_inventory( int args ) {
	
	if( args == 0 ) return Plugin_Handled;
	
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return Plugin_Handled;
	
	char initial_space[6];
	initial_space = GAME == GAME_CSGO ? "\x01 " : "";
	
	LoadClientData( client );
	PrintToChat( client, "%s\x04[STORE]\x01 Your inventory has been updated.", 
		         initial_space );
		
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
void BroadcastStoreActivity( int args, const char[] msg, 
                             bool single = false ) {
	
	if( args == 0 ) return;
 
	int client = FindClientFromAccount( GetCmdArgInt( 1 ));
	if( !client ) return;
	
	char player_name[33];
	GetClientName( client, player_name, sizeof player_name );
	
	char team_color[11];
	char item_color[11];
	char initial_space[6];
	int  client_team = GetClientTeam( client );
	
	if( client_team == 2 ){
		team_color = GAME == GAME_TF2 ? "\x07ff3d3d" : "\x09";
	} else if( client_team == 3 ){
		team_color = GAME == GAME_TF2 ? "\x0784d8f4" : "\x0B";
	} else {
		team_color = GAME == GAME_TF2 ? "\x07808080" : "\x08";
	}
	
	item_color    = GAME == GAME_TF2  ? "\x07874fad" : "\x03";
	initial_space = GAME == GAME_CSGO ? "\x01 " : "";
	
	int arg = 2;
	
	if( single ) {
		char item[64];
		GetCmdArg( arg, item, sizeof item );
		PrintToChatAll( msg, initial_space, team_color, 
		                player_name, item_color, item );
	} else {
		// show starting message then items on separate lines
		PrintToChatAll( msg, initial_space, team_color, player_name );
		
		while( args >= arg ) {
			char item[64];
			GetCmdArg( arg, item, sizeof item );
			
			PrintToChatAll( "%s%s%s", initial_space, item_color, item );
			
			arg++;
		}
	}
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_purchase( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s%s%s \x01just made a \x04!store \x01purchase:" );
		
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_gift_send( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s%s%s \x01just sent a \x04!store \x01gift:" );
		
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_gift_receive( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s%s%s \x01just accepted a \x04!store \x01gift:" );
		
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_reward_receive( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s%s%s \x01just accepted a \x04!store \x01reward:" );
		
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_broadcast_review( int args ) {
	
	BroadcastStoreActivity( args, 
		"%s%s%s \x01just wrote a \x04!store \x01review about the %s%s", true );
		
	return Plugin_Handled;
}


//-----------------------------------------------------------------------------
void BuildSQLItemIDFilter() {
	FormatEx( g_sql_itemid_filter, sizeof g_sql_itemid_filter, "item_id IN(" );
	int count = 0;
	for( int i = 0; i < 16; i++ ) {

		if( g_item_ids[i] != 0 ) {
			Format( g_sql_itemid_filter, sizeof g_sql_itemid_filter, 
			        "%s%d,", g_sql_itemid_filter, g_item_ids[i] );
			count++;
		}
	}
	
	if( count == 0 ) {
		// just use this in case "IN()" is considered an error
		StrCat( g_sql_itemid_filter, sizeof g_sql_itemid_filter, "0," ); 
	}
	
	// remove trailing comma and add closing parenthesis
	g_sql_itemid_filter[strlen(g_sql_itemid_filter)-1] = 0;
	StrCat( g_sql_itemid_filter, sizeof g_sql_itemid_filter, ")" );
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool nb ) {
	Update();
}

//-----------------------------------------------------------------------------
public Action OnTimedUpdate( Handle timer ) {
	Update();
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
void Update() {
	if( !DBRELAY_IsConnected() ) return;
	if( GetGameTime() - g_last_update < MIN_UPDATE_PERIOD ) {
		return;
	}
	
	g_last_update = GetGameTime();
	
	for( int i = 1; i <= MaxClients; i++ ) {
		if( LoadClientData( i, true )) {
			break;
		}
	}
}

//-----------------------------------------------------------------------------
void LogItemUse( int client, int slot ) {
	char player_name[33];
	GetClientName( client, player_name, sizeof player_name );
	LogMessage( "%s used a %s", player_name, g_item_names[slot] );
}

//-----------------------------------------------------------------------------
void CommitItemChange( int client, int item, int amount ) {

	if( amount == 0 ) return;
	
	char query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store2.user_item ( user_id, item_id, quantity ) VALUES ( %d, %d, %d ) ON DUPLICATE KEY UPDATE quantity = quantity %s %d",
		g_client_data_account[client],
		g_item_ids[item],
		amount,
		amount >= 0 ? "+":"",
		amount );
	
	int userid = GetClientUserId( client );
	int account = g_client_data_account[client];
	
	DataPack pack = new DataPack();
	 
	pack.WriteCell( userid  );
	pack.WriteCell( item    ); 
	pack.WriteCell( amount  );
	pack.WriteCell( account );
	pack.WriteCell( g_item_serial[item] );
	
	g_client_items_change[client][item] += amount;
	
	DBRELAY_TQuery( OnCommitItem, query, pack ); 
}

//-----------------------------------------------------------------------------
public void OnCommitItem( Handle owner, Handle hndl, const char[] error, 
                          DataPack data ) {
    
	data.Reset();

	int client  = data.ReadCell();
	int slot    = data.ReadCell();
	int amount  = data.ReadCell();
	int account = data.ReadCell();
	int serial  = data.ReadCell();
	
	delete data;
	
	if( !hndl ) {
		LogError( "[SERIOUS] SQL error during item usage commit! ::: %s", 
				  error ); 
		LogError( "user_id=%d, item_id=%d (%s), quantity=%d", 
				  account, g_item_ids[slot], g_item_names[slot], amount );
		return;
	}
	
	if( g_item_serial[slot] != serial ) {
		return; // something changed with the plugin.
	}
		
	client = GetClientOfUserId( client );
	if( client == 0 ) return; // disconnected
	
	g_client_items_change[client][slot] -= amount;
	g_client_items[client][slot] += amount;
} 

//-----------------------------------------------------------------------------
bool CommitCashChange( int client, int cash ) {

	if( !DBRELAY_IsConnected() ) return false;
	if( !g_client_data_loaded[client] ) return false;
	if( cash == 0 ) return true;
	
	char query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store2.user (user_id,credit) VALUES (%d,%d) ON DUPLICATE KEY UPDATE credit=credit%s%d",
		g_client_data_account[client],
		cash,
		cash > 0 ? "+":"-",
		cash );
		
	DataPack pack = new DataPack();
	
	pack.WriteCell( GetClientUserId(client)       );
	pack.WriteCell( cash                          );
	pack.WriteCell( g_client_data_account[client] );
	
	g_client_cash_change[client] += cash;
	
	DBRELAY_TQuery( OnCommitCash, query, pack );
	
	return true;
}

//-----------------------------------------------------------------------------
public void OnCommitCash( Handle owner, Handle hndl, const char[] error, 
                          DataPack data ) {

	data.Reset();
	int client  = GetClientOfUserId( data.ReadCell() );
	int amount  = data.ReadCell();
	int account = data.ReadCell();
	
	delete data;
	
	if( !hndl ) {
		LogError( "[SERIOUS] SQL error during CREDIT commit! ::: %s", error ); 
		LogError( "user_id=%d, quantity=%d", account,  amount );
		return;
	}
	
	if( !client ) return;
	
	g_client_cash_change[client] -= amount;
	g_client_cash[client] += amount;
}

//-----------------------------------------------------------------------------
bool TryTakeCash( int client, int cash, Handle plugin, TakeCashCB cb, 
                  any userdata ) {
                  
	if( !DBRELAY_IsConnected() ||
		!IsClientInGame(client) || 
		!IsClientAuthorized(client) ||
		!g_client_data_loaded[client] || 
		cash <= 0 ) return false;
	
	char query[1024];
	FormatEx( query, sizeof query, 
		"UPDATE sourcebans_store2.user SET credit=credit-%d WHERE user_id=%d AND credit>=%d",
		cash,
		g_client_data_account[client],
		cash );
	
	DataPack pack = new DataPack();
	
	pack.WriteCell    ( GetClientUserId(client)       );
	pack.WriteCell    ( cash                          );
	pack.WriteCell    ( g_client_data_account[client] );
	pack.WriteCell    ( plugin                        );
	pack.WriteFunction( cb                            );
	pack.WriteCell    ( userdata                      );
	
	DBRELAY_TQuery( OnTakeCash, query, pack );
	
	return true;
}

//-----------------------------------------------------------------------------
public void OnTakeCash( Handle owner, Handle hndl, const char[] error, 
                        DataPack data ) {

	data.Reset();
	
	int userid    = data.ReadCell();
	int amount    = data.ReadCell();
	int account   = data.ReadCell();
	Handle plugin = view_as<Handle>(data.ReadCell());
	TakeCashCB cb = view_as<TakeCashCB>data.ReadFunction();
	any cbdata    = data.ReadCell();
	
	delete data;
	
	Call_StartFunction( plugin, cb );
	
	Call_PushCell( userid );
	Call_PushCell( amount );
	Call_PushCell( cbdata );
	
	if( !hndl ) {
	
		Call_PushCell( true );
		Call_Finish();
		
		LogError( "SQL error during CREDIT taking! ::: %s", error ); 
		LogError( "user_id=%d, quantity=%d", account, amount );
		return;
	}
	
	int  client = GetClientOfUserId(userid);
	bool failed = (SQL_GetAffectedRows(hndl) == 0);
	if( client != 0 && !failed ) {
		g_client_cash[client] -= amount;
	}
	
	Call_PushCell( failed );
	Call_Finish();
}

/** ---------------------------------------------------------------------------
 * Load a client's inventory.
 *
 * @param client Client index.
 * @param chain  Load the next client in the client list after this one
 */
bool LoadClientData( int client, bool chain = false ) {
	// conditions for this function: client is in-game and authorized
	
	if( !IsClientInGame(client) || IsFakeClient(client) 
	    || !IsClientAuthorized(client) ) return false;
	 
	int account = GetSteamAccountID( client );
	g_client_data_account[client] = account;
	
	DataPack pack = new DataPack();
	pack.WriteCell( GetClientUserId(client) );
	pack.WriteCell( account                 );
	pack.WriteCell( client                  );
	pack.WriteCell( chain                   );
	
	int time = GetTime();
	
	char query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store2.user (user_id,server,ingame) VALUES(%d,'%s',%d) ON DUPLICATE KEY UPDATE server=VALUES(server),ingame=VALUES(ingame)",
		account, c_ip, time, c_ip, time );
		
	DBRELAY_TQuery( OnClientLoggedIn, query, pack );
	
	return true;
}

//-----------------------------------------------------------------------------
public void OnClientLoggedIn( Handle owner, Handle hndl, const char[] error, 
                              DataPack data ) {
	
	data.Reset();
	
	int client  = GetClientOfUserId( data.ReadCell() );
	int account = data.ReadCell();
	
	if( client == 0 ) {
		delete data;
		return;
	}
	
	if( !hndl ) {
		delete data;
		LogError( "Error logging in user %L : %s", client, error );
		return;
	}
	
	char query[1024];
	FormatEx( query, sizeof query, 
	          "SELECT locked FROM sourcebans_store2.user where user_id=%d", 
			  account );
			  
	DBRELAY_TQuery( OnClientLockChecked, query, data );
}

//-----------------------------------------------------------------------------
public void OnClientLockChecked( Handle owner, Handle hndl, 
                                 const char[] error, DataPack data ) {
	
	data.Reset();
	int client  = GetClientOfUserId( data.ReadCell() );
	int account = data.ReadCell();
	
	if( client == 0 ) {
		delete data;
		return;
	}
	
	if( !hndl ) {
		delete data;
		
		LogError( "Error checking player inventory lock for %L : %s", 
		          client, error );
		return;
	}
	
	SQL_FetchRow( hndl );
	int locked = SQL_FetchInt( hndl, 0 );
	
	if( locked + LOCK_DURATION_EXPIRE >= GetTime() ) {
		g_client_data_loaded[client] = false;
		//PrintToChat( client, "Your inventory did not load due to a temporary lock." );
		CloseHandle(data);
		return;
	}
	
	char query[1024];
	FormatEx( query, sizeof query,
		"SELECT 'gifts' as type, count(*) as total FROM sourcebans_store2.gift WHERE recipient_id=%d AND accepted=0 UNION SELECT 'rewards' as type, count(*) as total FROM sourcebans_store2.reward_recipient WHERE recipient_id=%d AND accepted=0",
		account, account );
	
	DBRELAY_TQuery( OnClientGiftsLoaded, query, data );
}

//-----------------------------------------------------------------------------
public void OnClientGiftsLoaded( Handle owner, Handle hndl, const char[] error, 
                            DataPack data ) {
	
	data.Reset();
	int client  = GetClientOfUserId( data.ReadCell() );
	int account = data.ReadCell();
	
	if( client == 0 ) {
		delete data;
		return;
	}
	
	if( !hndl ) {
		delete data;
		LogError( "Error checking pending gifts/rewards for %L : %s", 
		          client, error );
		return;
	}
	
	int num_gifts   = 0;
	int num_rewards = 0;
	
	// pending gifts
	if( SQL_MoreRows( hndl ) ) {
		SQL_FetchRow( hndl );
		num_gifts = SQL_FetchInt( hndl, 1 );
	}

	// pending rewards
	if( SQL_MoreRows( hndl ) ) {
		SQL_FetchRow( hndl );
		num_rewards = SQL_FetchInt( hndl, 1 );
	}
	
	char initial_space[6];
	initial_space = GAME == GAME_CSGO ? "\x01 " : "";
	
	if( num_gifts > 0 || num_rewards > 0 ) {
		PrintToChat( client, 
			"%s\x04[STORE]\x01 You have a pending gift or reward. Access the \x04!store \x01to accept it.", 
			initial_space );
	}
	
	char query[1024];
	FormatEx( query, sizeof query, 
		"SELECT item_id,quantity FROM sourcebans_store2.user_item WHERE user_id=%d AND %s UNION SELECT %d AS item_id,credit AS quantity FROM sourcebans_store2.user WHERE user_id=%d",
		account,
		g_sql_itemid_filter,
		SPITEM_CREDIT,
		account );
	
	DBRELAY_TQuery( OnClientInventoryLoaded, query, data );
}

//-----------------------------------------------------------------------------
public void OnClientInventoryLoaded( Handle owner, Handle hndl, 
                                     const char[] error, DataPack data ) {

	data.Reset();
	
	int client = GetClientOfUserId( data.ReadCell() );
	//skip account field
	data.ReadCell();
	
	int  client2 = data.ReadCell();
	bool chain = !!data.ReadCell();
	delete data;
	
	if( client != 0 ) {
		 
		if( !hndl ) {
			LogError( "Error loading inventory for %L : %s", client, error );
			return;
		}
		
		g_client_data_account[client] = GetSteamAccountID( client );
		
		for( int i = 0; i < 16; i++ ) {
			g_client_items[client][i] = 0;
			g_client_items_change[client][i] = 0;
		}
		
		while( SQL_FetchRow( hndl ) ) {
			int item = SQL_FetchInt( hndl, 0 ); // 0=ITEMID
			
			// special items:
			if( item == SPITEM_CREDIT ) {
				g_client_cash[client] = SQL_FetchInt( hndl, 1 );
				continue;
			}
			
			// normal:
			int slot = g_item_map[item] -1;
			if( slot == -1 ) continue; // unmapped item. (should have been filtered out!)
			
			g_client_items[client][slot] = SQL_FetchInt( hndl, 1 ); // 1=AMOUNT
		}
		g_client_data_loaded[client] = true;
	}
	
	if( chain ) {
		// load next connected client's data
		client2++;
		for( ; client2 <= MaxClients; client2++ ) {
			if( LoadClientData(client2,true) ) {
				break;
			}
		}
	}
}

//-----------------------------------------------------------------------------
void LogOutPlayer( int client ) {

	if( DBRELAY_IsConnected() ) {
		int account = GetSteamAccountID( client );
		if( account == 0 ) return;
	
		char query[1024];
		FormatEx( query, sizeof query, 
			"UPDATE sourcebans_store2.user SET server='' WHERE user_id=%d",
			account );
			
		DBRELAY_TQuery( IgnoredSQLResult, query );
	}
}

//-----------------------------------------------------------------------------
public void IgnoredSQLResult( Handle owner, Handle hndl, const char[] error, 
                              any data ) {
                              
	if( !hndl ) {
		LogError( "SQL Error --- %s", error );
		return;
	}
}

//-----------------------------------------------------------------------------
public void OnMapStart() {
	g_last_update = -MIN_UPDATE_PERIOD;
}

//-----------------------------------------------------------------------------
public void OnClientConnected( int client ) {
	g_client_data_loaded[client] = false; 
	 
}

//-----------------------------------------------------------------------------
public void OnClientDisconnect( int client ) {
	LogOutPlayer( client );
}

//-----------------------------------------------------------------------------
public int OnDBRelayConnected() {
	
	for( int i = 1; i <= MaxClients; i++ ) {
		g_client_data_loaded[i] = false;
	}
}

//-----------------------------------------------------------------------------
bool ClientOnlyCommand( int client ) {
	if( client == 0 ) {
		PrintToServer( "This is a client-only command." );
		return true;
	}
	return false;
}

//-----------------------------------------------------------------------------
public Action Command_items( int client, int args ) {

	if( ClientOnlyCommand( client )) return Plugin_Handled;
	
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
		PrintToChat( client, "Your inventory is still loading." );
		return Plugin_Handled;
	}
	
	PrintToChat( client, "You have:" );
	
	// print client inventory
	for( int i = 0; i < ITEM_MAX; i++ ) {
		if( g_item_ids[i] == 0 ) continue;
		
		int count = g_client_items[client][i] + g_client_items_change[client][i];
		
		if( count > 1 ) {
			PrintToChat( client, "%s (%d)", g_item_names[i], count );
		} else if( count == 1 ) {
			PrintToChat( client, "%s", g_item_names[i] );
		}
	}
	
	int cash = g_client_cash[client] + g_client_cash_change[client];
	if( cash < 0 ) cash = 0;
	
	char cash_string[16];
	FormatNumberInt( cash, cash_string, sizeof cash_string, ',' );
	
	PrintToChat( client, "CASH: $%s", cash_string );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public int UseItemMenu( Menu menu, MenuAction action, 
                         int client, int param2 ) {
	
	if( action == MenuAction_End ) {
		delete menu;
		
	} else if( action == MenuAction_Select ) {
		char info[32];
		
		GetMenuItem( menu, param2, info, sizeof info );
		int item = StringToInt(info);
		
		if( DBRELAY_IsConnected() && g_client_data_loaded[client] 
		    && (g_client_items[client][item] + g_client_items_change[client][item]) > 0 ) {
			
			Call_StartFunction( g_item_plugins[item], 
			                    g_item_functions[item][ITEMFUNC_ONUSE] );
			                    
			Call_PushCell( client );
			
			bool result;
			Call_Finish( result );
			
			if( result ) {
				UseItem( client, item );
			}
			
		} else {
		
			PrintToChat( client, "An error happened." );
		}
	}
}

//-----------------------------------------------------------------------------
public void ShowUseItemMenu( int client ) {
	Menu menu = new Menu( UseItemMenu );
	int items = 0;
	
	char info[16];
	char text[64];
			
	for( int i = 0; i < ITEM_MAX; i++ ) {
		int count = g_client_items[client][i] 
		            + g_client_items_change[client][i];
		            
		if( count > 0 ) {
			
			FormatEx( info, sizeof info, "%d", i );
			if( count == 1 ) {
				FormatEx( text, sizeof text, "%s", g_item_names[i] );
			} else {
				FormatEx( text, sizeof text, "%s (%d)", 
				          g_item_names[i], count );
			}
			
			AddMenuItem( menu, info, text );
			items++;
		}
	}
	
	if( items == 0 ) {
	
		PrintToChat( client, "You don't have any items!" );
		delete menu;
		
	} else {
	
		DisplayMenu( menu, client, 60 );
		
	}
}

//-----------------------------------------------------------------------------
public Action Command_use_item( int client, int args ) {

	if( ClientOnlyCommand( client )) return Plugin_Handled;
	
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
	
		PrintToChat( client, "Your inventory is still loading." );
		return Plugin_Handled;
	}
	
	float waittime = FloatAbs(GetGameTime() - g_client_item_last_used[client]); 
	
	if( waittime < ITEM_USE_COOLDOWN ) {
		// spam prevention
		return Plugin_Handled;
	}
	
	g_client_item_last_used[client] = GetGameTime();
	
	char arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	for( int i = 0; arg[i]; i++ ) arg[i] = CharToLower(arg[i]);
	TrimString( arg );
	
	if( arg[0] == 0 ) {
		ShowUseItemMenu( client );
		return Plugin_Handled;
	}
	
	int item; 
	if( g_item_trie.GetValue( arg, item )) {
		
		if( g_client_items[client][item] + g_client_items_change[client][item] <= 0 ) {
			PrintToChat( client, "You don't have any of that item." );
			return Plugin_Handled;
		}
		
		Call_StartFunction( g_item_plugins[item], 
		                    g_item_functions[item][ITEMFUNC_ONUSE] );
		                    
		Call_PushCell( client );
		
		bool result;
		Call_Finish( result );
		
		if( result ) {
			UseItem( client, item );
		}
		
	} else {
		PrintToChat( client, "Unknown item: \"%s\"", arg );
	}
	 
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
void UseItem( int client, int slot ) {
	LogItemUse( client, slot );
	CommitItemChange( client, slot, -1 );
}


//-----------------------------------------------------------------------------
void CachePluginFunctions( Handle plugin, int slot ) {
	g_item_plugins[slot] = plugin;
	g_item_functions[slot][ITEMFUNC_ONUSE] = 
			GetFunctionByName( plugin, "RXGSTORE_OnUse" );
}

//-----------------------------------------------------------------------------
public int Native_RegisterItem( Handle plugin, int args ) {
	
	int itemid = GetNativeCell(2);
	
	// search for existing
	int exists = -1;
	for( int i = 0; i < ITEM_MAX; i++ ) {
		if( g_item_ids[i] == itemid ) {
			exists = i;
			break;
		}
	}
	
	if( exists == -1 ) {
	
		// try to add
		for( int slot = 0; slot < ITEM_MAX; slot++ ) {
			if( g_item_ids[slot] != 0 ) continue;
			
			g_item_ids[slot] = itemid;
			g_item_map[itemid] = slot+1;
			
			char name[64];
			GetNativeString( 1, name, sizeof name );
			GetNativeString( 3, g_item_fullnames[slot], sizeof g_item_fullnames[] );
			
			strcopy( g_item_names[slot], sizeof g_item_names[], name );
			
			for( int j = 0; name[j]; j++ ) {
				name[j] = CharToLower(name[j]);
			}
			
			g_item_trie.SetValue( name, slot );
			CachePluginFunctions( plugin, slot );
			
			g_item_serial[slot] = g_next_serial++;
			
			for( int client = 1; client <= MaxClients; client++ ) {
				g_client_items[client][slot] = 0;
				g_client_items_change[client][slot] = 0;
			}
			
			BuildSQLItemIDFilter();
			
			return true;
		}
		
		// no free slots.
		return false;
	} else {
	
		CachePluginFunctions( plugin, exists );
		return true;
	}
}

//-----------------------------------------------------------------------------
public int Native_UnregisterItem( Handle plugin, int args ) {
	int itemid = GetNativeCell(1);
	if( !g_item_map[itemid] ) return false;
		
	int slot = g_item_map[itemid]-1;
	g_item_map[itemid] = 0;
	g_item_ids[slot] = 0;
	for( int i = 1; i <= MaxClients; i++ ) {
		g_client_items[i][slot] = 0;
		g_client_items_change[i][slot] = 0;
	}
	
	// TODO: why not use Remove?
	g_item_trie.SetValue( g_item_names[slot], -1 );
	return true;
}

//-----------------------------------------------------------------------------
public int Native_IsItemRegistered( Handle plugin, int args ) {
	int itemid = GetNativeCell(1);
	if( itemid < 0 || itemid > 4095 ) return false;
	
	return g_item_map[itemid] != 0;
}

//-----------------------------------------------------------------------------
public int Native_ItemCount( Handle plugin, int args ) {

	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int slot   = g_item_map[itemid] - 1;
	
	if( slot == -1 ||
		!DBRELAY_IsConnected() ||
		!g_client_data_loaded[client] )
		return 0;
	
	return g_client_items[client][slot] + g_client_items_change[client][slot];
}

//-----------------------------------------------------------------------------
public int Native_GetCash( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) return 0;
	
	return g_client_cash[client] + g_client_cash_change[client];
}

//-----------------------------------------------------------------------------
public int Native_AddCash( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	
	if( !IsClientInGame( client )) return false;
	
	return CommitCashChange( client, GetNativeCell(2) );
}
//-----------------------------------------------------------------------------
public int Native_TakeCash( Handle plugin, int args ) {
	return TryTakeCash( GetNativeCell(1), GetNativeCell(2), plugin, 
	                    GetNativeCell(3), GetNativeCell(4) );
}

//-----------------------------------------------------------------------------
public int Native_CanUseItem( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int slot = g_item_map[itemid]-1;
	
	if( slot == -1 ) return false;
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) return false;
	
	return g_client_items[client][slot] + g_client_items_change[client][slot] > 0;
}

//-----------------------------------------------------------------------------
public int Native_UseItem( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int slot = g_item_map[itemid]-1;
	
	if( slot == -1 || !IsClientInGame(client) 
	    || !DBRELAY_IsConnected() 
	    || !g_client_data_loaded[client] ) return false; 
	
	int count = g_client_items[client][slot]+g_client_items_change[client][slot];
	if( count <= 0 ) return false;
	
	UseItem( client, slot );
	
	return true;
}

//-----------------------------------------------------------------------------
public int Native_GiveItem( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int count  = GetNativeCell(3);
	int slot   = g_item_map[itemid]-1;
	
	if( slot == -1 || !IsClientInGame(client) 
	    || !DBRELAY_IsConnected() 
	    || !g_client_data_loaded[client] ) return false;
	
	CommitItemChange( client, slot, count );
	return true;
}

//-----------------------------------------------------------------------------
public int Native_ShowUseItemMenu( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	ShowUseItemMenu(client);
}

//-----------------------------------------------------------------------------
public int Native_IsClientLoaded( Handle plugin, int args ) {
	int client = GetNativeCell(1);
	if( !IsClientInGame(client) ) return false;
	
	return DBRELAY_IsConnected() && g_client_data_loaded[client];
}

//-----------------------------------------------------------------------------
public int Native_IsConnected( Handle plugin, int args ) {
	return DBRELAY_IsConnected();
}

//-----------------------------------------------------------------------------
public Action Command_cash( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
		PrintToChat( client, "Your items are still being loaded." );
		return Plugin_Handled;
	}
	
	int cash = g_client_cash[client] + g_client_cash_change[client];
	if( cash < 0 ) cash = 0;
	
	char cash_string[16];
	FormatNumberInt( cash, cash_string, sizeof cash_string, ',' );
	
	if( GAME == GAME_CSGO ) {
		PrintToChat( client, "\x01You have \x05$%s\x01.", cash_string );
	} else {
		PrintToChat( client, "\x01You have \x04$%s\x01.", cash_string );
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void ShowStorePage( int client, int id, int token ) {
	
	char source[13];
	
	if( GAME == GAME_CSGO ) {
		source = "csgo";
	} else if( GAME == GAME_TF2 ) {
		source = "tf2";
	} else {
		source = "unknown";
	}
	
	char url[512];
	FormatEx( url, sizeof url,
		"http://store.reflex-gamers.com/quickauth?id=%d&token=%d&game=%s",
		id,
		token,
		source );
	
	KeyValues kv = new KeyValues( "motd" );
	kv.SetString( "title", "RXG Store" );
	kv.SetNum( "type", MOTDPANEL_TYPE_URL );
	kv.SetString( "msg", url );
	
	ShowVGUIPanel( client, "info", kv, true );
	
	delete kv;
}

public void OnQuickAuthSave( Handle owner, Handle hndl, const char[] error, 
                             DataPack data ) {
	if( !hndl ) {
		delete data;
		LogError( "SQL error saving QuickAuth token ::: %s", error );
		return;
	}
	
	DBRELAY_TQuery( OnQuickAuthFetch, "SELECT LAST_INSERT_ID()", data );
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
	
	data.Reset(); 
	int client = ReadPackCell(data);
	int token = ReadPackCell(data);
	
	delete data;
	
	client = GetClientOfUserId( client );
	if( client == 0 ) return; // disconnected
	
	ShowStorePage( client, id, token );
}

//-----------------------------------------------------------------------------
public Action Command_store( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client, 
			"The store is currently unavailable. Please try again later." );
			
		return Plugin_Handled;
	}
	
	QueryClientConVar( client, "cl_disablehtmlmotd", ConVar_QueryClient );
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void ConVar_QueryClient( QueryCookie cookie, int client, 
                                ConVarQueryResult result, 
                                const char[] cvarName, 
                                const char[] cvarValue ) {

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
		"INSERT INTO sourcebans_store2.quick_auth (user_id, token, server, is_member) VALUES (%d, %d, '%s', %d)",
		GetSteamAccountID(client),
		token,
		c_ip,
		is_member );
	
	DataPack pack = new DataPack();
	pack.WriteCell( GetClientUserId( client )); 
	pack.WriteCell( token );
	
	if( DBRELAY_IsConnected() ) {
		DBRELAY_TQuery( OnQuickAuthSave, query, pack );
	} else {
		PrintToChat( client, "\x01Visit our store at \x04store.reflex-gamers.com");
	}
	
	//ReplyToCommand( client, "Visit our store at store.reflex-gamers.com" );
}

