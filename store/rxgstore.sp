
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgstore>

#pragma semicolon 1

// 1.0.4
//   bugfix with credit
// 1.0.3
//   sm_store command
// 1.0.2
//   added RXGSTORE_IsConnected

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "rxgstore",
    author      = "mukunda",
    description = "rxg store api",
    version     = "1.1.0",
    url         = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_MAX 16

new String:item_map[4096]; // map of real items to item slots
new item_ids[ITEM_MAX]; //reverse map, 0=slot not used
new String:item_names[ITEM_MAX][64];
new String:item_fullnames[ITEM_MAX][64];
new Handle:item_trie;
new item_serial[ITEM_MAX];
new next_serial=1;

#define ITEMFUNC_ONUSE 0

new Handle:item_plugins[ITEM_MAX];
new Function:item_functions[ITEM_MAX][4];

new String:sql_itemid_filter[128];

//new bool:g_client_data_loading; // the load function is in progress

new g_client_items[MAXPLAYERS+1][ITEM_MAX]; // client item counts
new bool:g_client_data_loaded[MAXPLAYERS+1]; // FALSE if inventory hasn't been loaded yet

new g_client_data_account[MAXPLAYERS+1]; // cache of the client accountid, used for commits (since client may disconnect)
new g_client_items_change[MAXPLAYERS+1][ITEM_MAX];
 
new g_client_cash[MAXPLAYERS]; // unit: cents
new g_client_cash_change[MAXPLAYERS]; 

new Float:g_client_item_last_used[MAXPLAYERS];
#define ITEM_USE_COOLDOWN 0.25

enum {
	SPITEM_CREDIT = 101,
};

// conditions before an item can be used:
//  g_db_connected is TRUE
//  client_data_loaded is TRUE 
//  client_items[item]+client_items_change[item] > 0


new g_update_method;
new Float:g_last_update;

#define MIN_UPDATE_PERIOD 30.0

#define UPDATE_METHOD_ROUND 0
#define UPDATE_METHOD_TIMED 1

#define UPDATE_TIMED_INTERVAL 50.0
//-------------------------------------------------------------------------------------------------
new Handle:g_db;
new bool:g_db_connecting;
new bool:g_db_connected;
new g_db_reconnect_tries;
#define DB_RETRY_DELAY  120.0

#pragma unused GAME
new GAME;

#define GAME_CSGO	0
#define GAME_TF2	1
 

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {

	item_trie = CreateTrie();
	
	decl String:gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual(gamedir,"csgo",false) ) {
		g_update_method = UPDATE_METHOD_ROUND;
		GAME = GAME_CSGO;
	} else {
		g_update_method = UPDATE_METHOD_TIMED;
		GAME = GAME_TF2;
	}
	
	CreateNative( "RXGSTORE_RegisterItem", Native_RegisterItem );
	CreateNative( "RXGSTORE_UnregisterItem", Native_UnregisterItem );
	CreateNative( "RXGSTORE_ItemCount", Native_ItemCount );
	CreateNative( "RXGSTORE_GetCash", Native_GetCash );
	CreateNative( "RXGSTORE_AddCash", Native_AddCash );
	CreateNative( "RXGSTORE_TakeCash", Native_TakeCash );
	CreateNative( "RXGSTORE_CanUseItem", Native_CanUseItem );
	CreateNative( "RXGSTORE_UseItem", Native_UseItem );
	CreateNative( "RXGSTORE_ShowUseItemMenu", Native_ShowUseItemMenu );
	CreateNative( "RXGSTORE_IsClientLoaded", Native_IsClientLoaded );
	CreateNative( "RXGSTORE_IsConnected", Native_IsConnected );
	
	RegPluginLibrary( "rxgstore" );
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	DB_Open();
	
	RegConsoleCmd( "sm_cash", Command_cash );
	RegConsoleCmd( "useitem", Command_use_item );
	RegConsoleCmd( "items", Command_items );
	RegConsoleCmd( "sm_store", Command_store );
	RegConsoleCmd( "sm_shop", Command_store );
	RegConsoleCmd( "sm_buy", Command_store );
	
	if( g_update_method == UPDATE_METHOD_TIMED ) {
		CreateTimer( UPDATE_TIMED_INTERVAL, OnTimedUpdate, _, TIMER_REPEAT );
	} else if( g_update_method == UPDATE_METHOD_ROUND ) {
		HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	}
}

//-------------------------------------------------------------------------------------------------
BuildSQLItemIDFilter() {
	FormatEx( sql_itemid_filter, sizeof sql_itemid_filter, "ITEMID IN(" );
	new count = 0;
	for( new i =0 ; i < 16; i++ ) {


		if( item_ids[i] != 0 ) {
			Format( sql_itemid_filter, sizeof sql_itemid_filter, "%s%d,", sql_itemid_filter, item_ids[i] );
			count++;
		}
		
	}
	if( count == 0 ) {
		// just use this in case "IN()" is considered an error
		StrCat( sql_itemid_filter, sizeof sql_itemid_filter, "0," ); 
	}
	sql_itemid_filter[strlen(sql_itemid_filter)-1] = 0; // remove last comma
	StrCat( sql_itemid_filter, sizeof sql_itemid_filter, ")" ); 
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	Update();
}

//-------------------------------------------------------------------------------------------------
public Action:OnTimedUpdate( Handle:timer ) {
	Update();
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
Update() {
	if ( !g_db_connected ) return;
	if( GetGameTime() - g_last_update < MIN_UPDATE_PERIOD ) {
		return;
	}
	g_last_update = GetGameTime();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( LoadClientData(i,true) ) {
			break;
		}
	}
}
  
//-------------------------------------------------------------------------------------------------
CommitItemChange( client, item, amount ) {
	
	if( amount == 0 ) return;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"UPDATE INVENTORY SET AMOUNT=AMOUNT%s%d WHERE ACCOUNT=%d AND ITEMID=%d",
		amount >= 0 ? "+":"",
		amount,
		g_client_data_account[client],
		item_ids[item] );
		
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, item );
	WritePackCell( pack, amount );
	WritePackCell( pack, g_client_data_account[client] );
	WritePackCell( pack, item_serial[item] );
	
	g_client_items_change[client][item] += amount;
	
	SQL_TQuery( g_db, OnCommitItem, query, pack ); 
}
  
//-------------------------------------------------------------------------------------------------
public OnCommitItem( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	ResetPack(data);
	new client = ReadPackCell(data);
	new item = ReadPackCell(data);
	new amount = ReadPackCell(data);
	new account = ReadPackCell(data);
	new serial = ReadPackCell( data );
	CloseHandle(data);
	
	if( !hndl ) {
		
		LogError( "[SERIOUS] SQL error during item usage commit! ::: %s", error ); 
		LogError( "ACCOUNT=%d, ITEM=%d (%s), AMOUNT=%d", account, item_ids[item], item_names[item], amount );
		
		DB_Fault();
		return;
	}
	
	if( item_serial[item] != serial ) return; // something changed with the plugin.
	client = GetClientOfUserId( client );
	if( client == 0 ) return; // disconnected
	
	g_client_items_change[client][item] -= amount;
	g_client_items[client][item] += amount;
} 

//-------------------------------------------------------------------------------------------------
bool:CommitCashChange( client, cash ) {

	if( !g_db_connected ) return false;
	if( !g_client_data_loaded[client] ) return false;
	if( cash == 0 ) return true;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO USER (ACCOUNT,CREDIT) VALUES (%d,%d) ON DUPLICATE KEY UPDATE CREDIT=CREDIT%s%d",
		g_client_data_account[client],
		cash,
		cash > 0 ? "+":"-",
		cash );
		
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, cash );
	WritePackCell( pack, g_client_data_account[client] );
	
	g_client_cash_change[client] += cash;
	
	SQL_TQuery( g_db, OnCommitCash, query, pack );
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnCommitCash( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	ResetPack(data);
	new client = GetClientOfUserId(ReadPackCell(data));
	new amount = ReadPackCell(data);
	new account = ReadPackCell(data);
	CloseHandle(data);
	if( !hndl ) {
		
		LogError( "[SERIOUS] SQL error during CREDIT commit! ::: %s", error ); 
		LogError( "ACCOUNT=%d, AMOUNT=%d", account,  amount );
		
		DB_Fault();
		return;
	}
	if( !client ) return;
	
	g_client_cash_change[client] -= amount;
	g_client_cash[client] += amount;
}

//-------------------------------------------------------------------------------------------------
bool:TryTakeCash( client, cash, Handle:plugin, TakeCashCB:cb, any:data ) {
	if( !g_db_connected ||
		!IsClientInGame(client) || 
		!IsClientAuthorized(client) ||
		!g_client_data_loaded[client] || 
		cash <= 0 ) return false;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"UPDATE USER SET CREDIT=CREDIT-%d WHERE ACCOUNT=%d AND CREDIT>=%d",
		cash,
		g_client_data_account[client],
		cash );
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, cash );
	WritePackCell( pack, g_client_data_account[client] );
	WritePackCell( pack, _:plugin );
	WritePackCell( pack, _:cb );
	WritePackCell( pack, data );
	
	SQL_TQuery( g_db, OnTakeCash, query, pack );
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnTakeCash( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	ResetPack(data);
	new userid = ReadPackCell(data);
	new amount = ReadPackCell(data);
	new account = ReadPackCell(data);
	new Handle:plugin = Handle:ReadPackCell(data);
	new TakeCashCB:cb = TakeCashCB:ReadPackCell(data);
	new any:cbdata = ReadPackCell(data);
	
	CloseHandle(data);
	
	Call_StartFunction( plugin, Function:cb );
	Call_PushCell( userid );
	Call_PushCell( amount );
	Call_PushCell( cbdata );
	
	if( !hndl ) {
		Call_PushCell( true );
		Call_Finish();
		
		LogError( "SQL error during CREDIT taking! ::: %s", error ); 
		LogError( "ACCOUNT=%d, AMOUNT=%d", account, amount );
		
		DB_Fault();
		return;
	}
	
	new client = GetClientOfUserId(userid);
	new failed = (SQL_GetAffectedRows(hndl) == 0);
	if( client != 0 && !failed ) {
		g_client_cash[client] -= amount;
	}
	
	Call_PushCell( failed );
	Call_Finish();
}

//-------------------------------------------------------------------------------------------------
bool:LoadClientData( client, bool:chain=false ) {
	// conditions for this function: client is in-game and authorized
	
	if( !IsClientInGame(client) || IsFakeClient(client) || !IsClientAuthorized(client) ) return false;
	 
	new account = GetSteamAccountID( client );
	g_client_data_account[client] = account;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"SELECT ITEMID,AMOUNT FROM INVENTORY WHERE ACCOUNT=%d AND %s UNION SELECT %d AS ITEMID,CREDIT AS AMOUNT FROM USER WHERE ACCOUNT=%d",
		account,
		sql_itemid_filter,
		SPITEM_CREDIT,
		account );
		
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, client );
	WritePackCell( pack, chain );
		
	SQL_TQuery( g_db, OnClientInventoryLoaded, query, pack );
	
	new time = GetTime();
	FormatEx( query, sizeof query, 
		"INSERT INTO USER (ACCOUNT,INGAME) VALUES(%d,%d) ON DUPLICATE KEY UPDATE INGAME=%d",
		account,time,time );
	SQL_TQuery( g_db, IgnoredSQLResult, query, pack );
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnClientInventoryLoaded( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	new client2 = ReadPackCell(data);
	new bool:chain = !!ReadPackCell(data);
	CloseHandle(data);
	
	if( client != 0 ) {
		 
		if( !hndl ) {
			LogError( "Error loading inventory for %L : %s", client, error );
			DB_Fault();
			return;
		}
		
		g_client_data_account[client] = GetSteamAccountID( client );
		
		for( new i = 0; i < 16; i++ ) {
			g_client_items[client][i] = 0;
			g_client_items_change[client][i] = 0;
		}
		
		while( SQL_FetchRow( hndl ) ) {
			new item = SQL_FetchInt( hndl, 0 ); // 0=ITEMID
			
			// special items:
			if( item == SPITEM_CREDIT ) {
				g_client_cash[client] = SQL_FetchInt( hndl, 1 );
				continue;
			}
			
			// normal:
			new slot = item_map[item] -1;
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

//-------------------------------------------------------------------------------------------------
LogOutPlayer( client ) {

	if( g_db_connected ) {
		new account = GetSteamAccountID( client );
		if( account == 0 ) return;
	
		decl String:query[1024];
		FormatEx( query, sizeof query, 
			"UPDATE USER SET INGAME=0 WHERE ACCOUNT=%d",account );
			
		SQL_TQuery( g_db, IgnoredSQLResult, query );
	}
}

//-------------------------------------------------------------------------------------------------
public IgnoredSQLResult( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogError( "SQL Error --- %s", error );
		DB_Fault();
		return;
	}
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	g_last_update = -MIN_UPDATE_PERIOD;
}

//-------------------------------------------------------------------------------------------------
public OnClientConnected(client) {
	g_client_data_loaded[client] = false; 
	 
}

//-------------------------------------------------------------------------------------------------
public OnClientDisconnect( client ) {
	LogOutPlayer( client );
}
   
//-------------------------------------------------------------------------------------------------
public DB_OnConnect(Handle:owner, Handle:hndl, const String:error[], any:data) {
	
	if( hndl == INVALID_HANDLE ) {
		LogError( "sql connection error: %s", error );
		if( g_db_reconnect_tries == 0 ) {
			SetFailState( "Unable to connect to database" );
			
		} else {
			g_db_reconnect_tries--;
			CreateTimer( DB_RETRY_DELAY, DB_ReconnectTimer );
			return;
		}
	}
	g_db_connecting = false;
	g_db_connected = true;
	g_db = hndl;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_data_loaded[i] = false;
	}
	
	BuildSQLItemIDFilter();
	 
	PrintToServer( "[RXGSTORE] database connection established." );
} 

//-------------------------------------------------------------------------------------------------
public Action:DB_ReconnectTimer( Handle:timer ) {
	DB_Open( false );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
bool:DB_Open( bool:first=true ) {
	
	// returns true if connected
	if( g_db_connecting ) return false;
	if( g_db_connected ) return true;
	SQL_TConnect( DB_OnConnect, "rxgstore" );
	g_db_connecting = true;
	if( first ) g_db_reconnect_tries = 5;
	return false;
}

//-------------------------------------------------------------------------------------------------
public DB_Fault() {
	if( !g_db_connected ) return;
	CloseHandle( g_db );
	g_db = INVALID_HANDLE;
	g_db_connected = false;
	DB_Open();
}

//-------------------------------------------------------------------------------------------------
public Action:Command_items( client, args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !g_db_connected || !g_client_data_loaded[client] ) {
		PrintToChat( client, "Your inventory is still loading." );
		return Plugin_Handled;
	}
	
	PrintToChat( client, "You have:" );
	for( new i = 0; i < ITEM_MAX; i++ ) {
		if( item_ids[i] == 0 ) continue;
		new count = g_client_items[client][i] + g_client_items_change[client][i];
		
		if( count > 1 ) {
			PrintToChat( client, "%s (%d)", item_names[i], count );
		} else if( count == 1 ) {
			PrintToChat( client, "%s", item_names[i] );
		}
	}
	new cash = g_client_cash[client] + g_client_cash_change[client];
	if( cash < 0 ) cash = 0;
	
	PrintToChat( client, "CASH: $%d.%02d", cash/100,cash%100 ); 
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public UseItemMenu( Handle:menu, MenuAction:action, client, param2) {
	
	if( action == MenuAction_End)  {
		CloseHandle(menu);
	} else if( action == MenuAction_Select ) {
		new String:info[32];
		
		GetMenuItem( menu, param2, info, sizeof(info) );
		new item = StringToInt(info);
		if( g_db_connected && g_client_data_loaded[client] && (g_client_items[client][item]+g_client_items_change[client][item])>0 ) {
			
			Call_StartFunction( item_plugins[item], item_functions[item][ITEMFUNC_ONUSE] );
			Call_PushCell( client );
			new bool:result;
			Call_Finish( result );
			
			if( result ) {
				UseItem( client, item );
			}
			
		} else {
			PrintToChat( client, "An error happened." );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public ShowUseItemMenu( client ) {
	new Handle:menu = CreateMenu( UseItemMenu );
	new items = 0;
	for( new i = 0; i < ITEM_MAX; i++ ) {
		new count = (g_client_items[client][i] + g_client_items_change[client][i]);
		if( count > 0 ) {
			decl String:info[16];
			decl String:text[64];
			FormatEx( info, sizeof info, "%d", i );
			if( count == 1 ) {
				FormatEx( text, sizeof text, "%s", item_names[i] );
			} else {
				FormatEx( text, sizeof text, "%s (%d)", item_names[i], count );
			}
			AddMenuItem(  menu, info, text );
			items++;
		}
	}
	if( items == 0 ) {
		PrintToChat( client, "You don't have any items!" );
		CloseHandle(menu);
	} else {
		DisplayMenu( menu, client, 60 );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_use_item( client, args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !g_db_connected || !g_client_data_loaded[client] ) {
		PrintToChat( client, "Your inventory is still loading." );
		return Plugin_Handled;
	}
	
	if( FloatAbs(GetGameTime() - g_client_item_last_used[client]) < ITEM_USE_COOLDOWN ) {
		return Plugin_Handled;
	}
	g_client_item_last_used[client] = GetGameTime();
	
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	for( new i = 0; arg[i]; i++ ) arg[i] = CharToLower(arg[i]);
	TrimString(arg);
	if( arg[0] == 0 ) {
		ShowUseItemMenu(client);
		return Plugin_Handled;
	}
	
	new item; 
	if( GetTrieValue( item_trie, arg, item ) ) {
		
		if( g_client_items[client][item] + g_client_items_change[client][item] <= 0 ) {
			PrintToChat( client, "You don't have any of that item." );
			return Plugin_Handled;
		}
		
		Call_StartFunction( item_plugins[item], item_functions[item][ITEMFUNC_ONUSE] );
		Call_PushCell( client );
		new bool:result;
		Call_Finish( result );
		
		if( result ) {
			UseItem( client, item );
		}
		
	} else {
		PrintToChat( client, "Unknown item: \"%s\"", arg );
	}
	 
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
UseItem( client, item ) {
	CommitItemChange( client, item, -1 );
}


//-------------------------------------------------------------------------------------------------
CachePluginFunctions( Handle:plugin, slot ) {
	item_plugins[slot] = plugin;
	item_functions[slot][ITEMFUNC_ONUSE] = GetFunctionByName( plugin, "RXGSTORE_OnUse" );
}

//-------------------------------------------------------------------------------------------------
public Native_RegisterItem( Handle:plugin, numParams ) {
	
	new itemid = GetNativeCell(2);
	
	// search for existing
	new exists=-1;
	for( new i = 0; i < ITEM_MAX; i++ ) {
		if( item_ids[i] == itemid ) {
			exists = i;
			break;
		}
	}
	if( exists == -1 ) {
		// try to add
		for( new slot = 0; slot < ITEM_MAX; slot++ ) {
			if( item_ids[slot] == 0 ) {
				item_ids[slot] = itemid;
				item_map[itemid] = slot+1;
				decl String:name[64];
				GetNativeString( 1, name, sizeof name );
				GetNativeString( 3, item_fullnames[slot], sizeof item_fullnames[] );
				strcopy( item_names[slot], sizeof item_names[], name );
				for( new j = 0; name[j]; j++ ) name[j] = CharToLower(name[j]);
				SetTrieValue( item_trie, name, slot );
				CachePluginFunctions( plugin, slot );
				item_serial[slot] = next_serial++;
				
				for( new client = 1; client <= MaxClients; client++ ) {
					g_client_items[client][slot] = 0;
					g_client_items_change[client][slot] = 0;
				}
				
				return true;
			}
		}
		if( g_db_connected ) {
			BuildSQLItemIDFilter();
		}
		return false;
	} else {
		CachePluginFunctions( plugin, exists );
		return true;
	}
}

//-------------------------------------------------------------------------------------------------
public Native_UnregisterItem( Handle:plugin, numParams ) {
	new itemid = GetNativeCell(1);
	if( !item_map[itemid] ) return false;
		
	new slot = item_map[itemid]-1;
	item_map[itemid] = 0;
	item_ids[slot] = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_items[i][slot] = 0;
		g_client_items_change[i][slot] = 0;
	}
	SetTrieValue( item_trie, item_names[slot], -1 );
	return true;
}

//-------------------------------------------------------------------------------------------------
public Native_ItemCount( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new slot = item_map[itemid]-1;
	if( slot == -1 ||
		!g_db_connected ||
		!g_client_data_loaded[client] )
		return 0;
	
	return g_client_items[client][slot]+g_client_items_change[client][slot];
}

//-------------------------------------------------------------------------------------------------
public Native_GetCash( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !g_db_connected || !g_client_data_loaded[client] ) return 0;
	return g_client_cash[client]+g_client_cash_change[client];
}

//-------------------------------------------------------------------------------------------------
public Native_AddCash( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !IsClientInGame(client) ) return false;
	return CommitCashChange( client, GetNativeCell(2) );
}
//-------------------------------------------------------------------------------------------------
public Native_TakeCash( Handle:plugin, numParams ) {
	return TryTakeCash( GetNativeCell(1), GetNativeCell(2), plugin, GetNativeCell(3), GetNativeCell(4) );
}

//-------------------------------------------------------------------------------------------------
public Native_CanUseItem( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new slot = item_map[itemid]-1;
	if( slot == -1 ) return false;
	if( !g_db_connected || !g_client_data_loaded[client] ) return false;
	return (g_client_items[client][slot]+g_client_items_change[client][slot]) > 0;
}

//-------------------------------------------------------------------------------------------------
public Native_UseItem( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new slot = item_map[itemid]-1;
	if( slot == -1 ) return false;
	if( !IsClientInGame(client) ) return false;
	if( !g_db_connected || !g_client_data_loaded[client] ) return false;
	
	if( (g_client_items[client][slot]+g_client_items_change[client][slot]) <= 0 ) return false;
	
	CommitItemChange( client, slot, -1 );
	return true;
}

//-------------------------------------------------------------------------------------------------
public Native_ShowUseItemMenu( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	ShowUseItemMenu(client);
}

//-------------------------------------------------------------------------------------------------
public Native_IsClientLoaded( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !IsClientInGame(client) ) return false;
	
	return g_db_connected && g_client_data_loaded[client];
}

//-------------------------------------------------------------------------------------------------
public Native_IsConnected( Handle:plugin, numParams ) {
	return g_db_connected;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_cash( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !g_db_connected || !g_client_data_loaded[client] ) {
		PrintToChat( client, "Your items are still being loaded." );
		return Plugin_Handled;
	}
	
	new cash = g_client_cash[client] + g_client_cash_change[client];
	if( cash < 0 ) cash = 0;
	
	if( GAME == GAME_CSGO ) {
		PrintToChat( client, "\x01You have \x05$%d.%02d\x01.", cash/100, cash%100 );
	} else {
		PrintToChat( client, "\x01You have \x04$%d.%02d\x01.", cash/100, cash%100 );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public ShowStorePage( client, id, token ) {
	
	decl String:url[1024];
	FormatEx( url, sizeof url,
		"http://store.reflex-gamers.com/quickauth%s.php?id=%d&token=%d",
		GAME == GAME_CSGO ? "_csgo" : "",
		id,
		token );
	
	if( GAME == GAME_CSGO ) {
		ShowMOTDPanel(client, "RXG Store", url, MOTDPANEL_TYPE_URL);
	} else {
		new Handle:Kv = CreateKeyValues( "motd" );
		KvSetString( Kv, "title", "RXG Store" );
		KvSetNum( Kv, "type", MOTDPANEL_TYPE_URL );
		KvSetString( Kv, "msg", url );
		ShowVGUIPanel( client, "info", Kv, true );
		CloseHandle( Kv );
	}
}

//-------------------------------------------------------------------------------------------------
public OnQuickAuthSave( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	SQL_TQuery( g_db, OnQuickAuthFetch, "SELECT LAST_INSERT_ID()", data );
	
	if( !hndl ) {
		LogError( "SQL error saving QuickAuth token ::: %s", error );
		DB_Fault();
		return;
	}
}

//-------------------------------------------------------------------------------------------------
public OnQuickAuthFetch( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	if( !hndl ) {
		LogError( "SQL error fetching QuickAuth ID ::: %s", error );
		DB_Fault();
		return;
	}
	
	new id;
	
	if( SQL_FetchRow( hndl ) ) {
		id = SQL_FetchInt( hndl, 0 );
	}
	
	ResetPack(data);
	new client = ReadPackCell(data);
	new token = ReadPackCell(data);
	CloseHandle(data);
	
	client = GetClientOfUserId( client );
	if( client == 0 ) return; // disconnected
	
	ShowStorePage( client, id, token );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_store( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	new token = GetRandomInt( 10000, 100000 );
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO QUICKAUTH (ACCOUNT, TOKEN) VALUES (%d, %d)",
		GetSteamAccountID(client),
		token );
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, token );
	
	SQL_TQuery( g_db, OnQuickAuthSave, query, pack );
	
	//ReplyToCommand( client, "Visit our store at store.reflex-gamers.com" );
	
	return Plugin_Handled;
}
