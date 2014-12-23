
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgstore>
#include <cstrike>
#include <dbrelay>

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
    version     = "2.0.0",
    url         = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_MAX 16

#define RXG_CSGO_CLAN "#rxg"
#define LOCK_DURATION_EXPIRE 30.0

new String:c_ip[32];

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
//  DBRELAY_IsConnected() is TRUE
//  client_data_loaded is TRUE 
//  client_items[item]+client_items_change[item] > 0


new g_update_method;
new Float:g_last_update;

#define MIN_UPDATE_PERIOD 30.0

#define UPDATE_METHOD_ROUND 0
#define UPDATE_METHOD_TIMED 1

#define UPDATE_TIMED_INTERVAL 50.0
//-------------------------------------------------------------------------------------------------
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
	
	RegConsoleCmd( "sm_cash", Command_cash );
	RegConsoleCmd( "useitem", Command_use_item );
	RegConsoleCmd( "items", Command_items );
	RegConsoleCmd( "sm_store", Command_store );
	RegConsoleCmd( "sm_shop", Command_store );
	RegConsoleCmd( "sm_buy", Command_store );
	
	RegServerCmd( "sm_store_unload_inventory", Command_unload_user_inventory );
	RegServerCmd( "sm_store_reload_inventory", Command_reload_user_inventory );
	RegServerCmd( "sm_store_broadcast_purchase", Command_broadcast_purchase );
	RegServerCmd( "sm_store_broadcast_gift_send", Command_broadcast_gift_send );
	RegServerCmd( "sm_store_broadcast_gift_receive", Command_broadcast_gift_receive );
	RegServerCmd( "sm_store_broadcast_reward_receive", Command_broadcast_reward_receive );
	RegServerCmd( "sm_store_broadcast_review", Command_broadcast_review );
	
	if( g_update_method == UPDATE_METHOD_TIMED ) {
		CreateTimer( UPDATE_TIMED_INTERVAL, OnTimedUpdate, _, TIMER_REPEAT );
	} else if( g_update_method == UPDATE_METHOD_ROUND ) {
		HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	}
	
	new longIP = GetConVarInt(FindConVar("hostip"));
	new pieces[4];
	
	pieces[0] = (longIP & 0xFF000000) >> 24;
	pieces[1] = (longIP & 0x00FF0000) >> 16;
	pieces[2] = (longIP & 0x0000FF00) >> 8;
	pieces[3] = longIP & 0x000000FF;

	FormatEx( c_ip, sizeof c_ip, "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3] );
	
	//GetConVarString(FindConVar("ip"), c_ip, sizeof c_ip);
	BuildSQLItemIDFilter();
}

//-------------------------------------------------------------------------------------------------
public Action:Command_unload_user_inventory( args ) {
	
	if( args > 0 ) {
		
		decl String:account_string[16];
		GetCmdArg( 1, account_string, sizeof account_string );
		new account = StringToInt(account_string);
		
		for( new i = 1; i <= MaxClients; i++ ) {
			if( g_client_data_account[i] == account ) {
				g_client_data_loaded[i] = false;
				//PrintToChat( i, "\x01 \x04[STORE]\x01 Your inventory has been unloaded." );
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_reload_user_inventory( args ) {
	
	if( args > 0 ) {
		
		decl String:account_string[16];
		GetCmdArg( 1, account_string, sizeof account_string );
		new account = StringToInt(account_string);
		
		for( new i = 1; i <= MaxClients; i++ ) {
			if( g_client_data_account[i] == account ) {
				LoadClientData(i);
				PrintToChat( i, "\x01 \x04[STORE]\x01 Your inventory has been updated." );
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
BroadcastStoreActivity( args, const String:msg[] ) {
	
	if( args > 0 ) {
	
		decl String:account_string[16];
		GetCmdArg( 1, account_string, sizeof account_string );
		new account = StringToInt(account_string);
		
		for( new i = 1; i <= MaxClients; i++ ) {
		
			if( g_client_data_account[i] == account ) {
			
				decl String:player_name[33];
				GetClientName( i, player_name, sizeof player_name );
				
				decl String:team_color[7];
				decl String:item_color[7];
				new client_team = GetClientTeam(i);
				
				if( client_team == 2 ){
					team_color = GAME == GAME_TF2 ? "\x07ff3d3d" : "\x09";
				} else if( client_team == 3 ){
					team_color = GAME == GAME_TF2 ? "\x0784d8f4" : "\x0B";
				} else {
					team_color = GAME == GAME_TF2 ? "\x07808080" : "\x08";
				}
				
				item_color = GAME == GAME_TF2 ? "\x07874fad" : "\x03";
				
				new arg = 2;
				
				while( args >= arg ) {
					
					decl String:item[64];
					GetCmdArg( arg, item, sizeof item );
					
					PrintToChatAll( msg, team_color, player_name, item_color, item );
					
					arg++;
				}
				
				return;
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_broadcast_purchase( args ) {
	
	BroadcastStoreActivity( args, "\x01 %s%s \x01just bought %s%s \x01from the \x04!store" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_broadcast_gift_send( args ) {
	
	BroadcastStoreActivity( args, "\x01 %s%s \x01just sent a \x04!store \x01gift containing %s%s" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_broadcast_gift_receive( args ) {
	
	BroadcastStoreActivity( args, "\x01 %s%s \x01just received a \x04!store \x01gift containing %s%s" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_broadcast_reward_receive( args ) {
	
	BroadcastStoreActivity( args, "\x01 %s%s \x01just received a \x04!store \x01reward containing %s%s" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_broadcast_review( args ) {
	
	BroadcastStoreActivity( args, "\x01 %s%s \x01just wrote a \x04!store \x01review about %s%s" );
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
BuildSQLItemIDFilter() {
	FormatEx( sql_itemid_filter, sizeof sql_itemid_filter, "item_id IN(" );
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
	if ( !DBRELAY_IsConnected() ) return;
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
		"UPDATE sourcebans_store.user_item SET quantity=quantity%s%d WHERE user_id=%d AND item_id=%d",
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
	
	DBRELAY_TQuery( OnCommitItem, query, pack ); 
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
		LogError( "user_id=%d, item_id=%d (%s), quantity=%d", account, item_ids[item], item_names[item], amount );
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

	if( !DBRELAY_IsConnected() ) return false;
	if( !g_client_data_loaded[client] ) return false;
	if( cash == 0 ) return true;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store.user (user_id,credit) VALUES (%d,%d) ON DUPLICATE KEY UPDATE credit=credit%s%d",
		g_client_data_account[client],
		cash,
		cash > 0 ? "+":"-",
		cash );
		
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, cash );
	WritePackCell( pack, g_client_data_account[client] );
	
	g_client_cash_change[client] += cash;
	
	DBRELAY_TQuery( OnCommitCash, query, pack );
	
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
		LogError( "user_id=%d, quantity=%d", account,  amount );
		return;
	}
	
	if( !client ) return;
	
	g_client_cash_change[client] -= amount;
	g_client_cash[client] += amount;
}

//-------------------------------------------------------------------------------------------------
bool:TryTakeCash( client, cash, Handle:plugin, TakeCashCB:cb, any:data ) {
	if( !DBRELAY_IsConnected() ||
		!IsClientInGame(client) || 
		!IsClientAuthorized(client) ||
		!g_client_data_loaded[client] || 
		cash <= 0 ) return false;
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"UPDATE sourcebans_store.user SET credit=credit-%d WHERE user_id=%d AND credit>=%d",
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
	
	DBRELAY_TQuery( OnTakeCash, query, pack );
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
		LogError( "user_id=%d, quantity=%d", account, amount );
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
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, account );
	WritePackCell( pack, client );
	WritePackCell( pack, chain );
	
	new time = GetTime();
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store.user (user_id,server,ingame) VALUES(%d,'%s',%d) ON DUPLICATE KEY UPDATE server=VALUES(server),ingame=VALUES(ingame)",
		account,c_ip,time,c_ip,time );
	DBRELAY_TQuery( OnClientLoggedIn, query, pack );
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnClientLoggedIn( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	new account = ReadPackCell(data);
	
	if( client == 0 ) {
		CloseHandle(data);
		return;
	}
	if( !hndl ) {
		CloseHandle(data);
		LogError( "Error logging in user %L : %s", client, error );
		return;
	}
	
	decl String:query[1024];
	FormatEx( query, sizeof query, "SELECT locked FROM sourcebans_store.user where user_id=%d", account );
	DBRELAY_TQuery( OnClientLockChecked, query, data );
}

//-------------------------------------------------------------------------------------------------
public OnClientLockChecked( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	new account = ReadPackCell(data);
	
	if( client == 0 ) {
		CloseHandle(data);
		return;
	}
	if( !hndl ) {
		CloseHandle(data);
		LogError( "Error checking player inventory lock for %L : %s", client, error );
		return;
	}
	
	SQL_FetchRow( hndl );
	new locked = SQL_FetchInt( hndl, 0 );
	
	if( locked + LOCK_DURATION_EXPIRE >= GetTime() ) {
		g_client_data_loaded[client] = false;
		//PrintToChat( client, "Your inventory did not load due to a temporary lock." );
		CloseHandle(data);
		return;
	}
	
	decl String:query[1024];
	FormatEx( query, sizeof query,
		"SELECT 'gifts' as type, count(*) as total FROM sourcebans_store.gift WHERE recipient_id=%d AND accepted=0 UNION SELECT 'rewards' as type, count(*) as total FROM sourcebans_store.reward_recipient WHERE recipient_id=%d AND accepted=0",
		account, account );
	
	DBRELAY_TQuery( OnClientGiftsLoaded, query, data );
}

//-------------------------------------------------------------------------------------------------
public OnClientGiftsLoaded( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	new account = ReadPackCell(data);
	
	if( client == 0 ) {
		CloseHandle(data);
		return;
	}
	if( !hndl ) {
		CloseHandle(data);
		LogError( "Error checking pending gifts/rewards for %L : %s", client, error );
		return;
	}
	
	// pending gifts
	if( SQL_MoreRows( hndl ) ) {
	
		SQL_FetchRow( hndl );
		new num_gifts = SQL_FetchInt( hndl, 1 );
		
		if( num_gifts > 0 ) {
			PrintToChat( client, "\x01 \x04[STORE]\x01 You have pending gifts. Access the \x04!store \x01to accept them." );
		}
	}
	
	// pending rewards
	if( SQL_MoreRows( hndl ) ) {
		
		SQL_FetchRow( hndl );
		new num_rewards = SQL_FetchInt( hndl, 1 );
		
		if( num_rewards > 0 ) {
			PrintToChat( client, "\x01 \x04[STORE]\x01 You have pending rewards. Access the \x04!store \x01to accept them." );
		}
	}
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"SELECT item_id,quantity FROM sourcebans_store.user_item WHERE user_id=%d AND %s UNION SELECT %d AS item_id,credit AS quantity FROM sourcebans_store.user WHERE user_id=%d",
		account,
		sql_itemid_filter,
		SPITEM_CREDIT,
		account );
	
	DBRELAY_TQuery( OnClientInventoryLoaded, query, data );
}

//-------------------------------------------------------------------------------------------------
public OnClientInventoryLoaded( Handle:owner, Handle:hndl, const String:error[], any:data ) {

	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	//skip account field
	SetPackPosition( data, 16 );
	new client2 = ReadPackCell(data);
	new bool:chain = !!ReadPackCell(data);
	CloseHandle(data);
	
	if( client != 0 ) {
		 
		if( !hndl ) {
			LogError( "Error loading inventory for %L : %s", client, error );
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

	if( DBRELAY_IsConnected() ) {
		new account = GetSteamAccountID( client );
		if( account == 0 ) return;
	
		decl String:query[1024];
		FormatEx( query, sizeof query, 
			"UPDATE sourcebans_store.user SET server='' WHERE user_id=%d",account );
			
		DBRELAY_TQuery( IgnoredSQLResult, query );
	}
}

//-------------------------------------------------------------------------------------------------
public IgnoredSQLResult( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	if( !hndl ) {
		LogError( "SQL Error --- %s", error );
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
public OnDBRelayConnected() {
	
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_data_loaded[i] = false;
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_items( client, args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
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
		if( DBRELAY_IsConnected() && g_client_data_loaded[client] && (g_client_items[client][item]+g_client_items_change[client][item])>0 ) {
			
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
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
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
				
				BuildSQLItemIDFilter();
				
				return true;
			}
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
		!DBRELAY_IsConnected() ||
		!g_client_data_loaded[client] )
		return 0;
	
	return g_client_items[client][slot]+g_client_items_change[client][slot];
}

//-------------------------------------------------------------------------------------------------
public Native_GetCash( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) return 0;
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
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) return false;
	return (g_client_items[client][slot]+g_client_items_change[client][slot]) > 0;
}

//-------------------------------------------------------------------------------------------------
public Native_UseItem( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new slot = item_map[itemid]-1;
	if( slot == -1 ) return false;
	if( !IsClientInGame(client) ) return false;
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) return false;
	
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
	
	return DBRELAY_IsConnected() && g_client_data_loaded[client];
}

//-------------------------------------------------------------------------------------------------
public Native_IsConnected( Handle:plugin, numParams ) {
	return DBRELAY_IsConnected();
}

//-------------------------------------------------------------------------------------------------
public Action:Command_cash( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !DBRELAY_IsConnected() || !g_client_data_loaded[client] ) {
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
	
	decl String:source[13];
	
	if( GAME == GAME_CSGO ) {
		source = "csgo";
	} else if( GAME == GAME_TF2 ) {
		source = "tf2";
	} else {
		source = "unknown";
	}
	
	decl String:url[1024];
	FormatEx( url, sizeof url,
		//"http://store.reflex-gamers.com/quickauth%s.php?id=%d&token=%d",
		"http://rxgstore2.dev/quickauth?id=%d&token=%d&source=%s",
		//"http://store2.reflex-gamers.com/quickauth?id=%d&token=%d&source=%s",
		id,
		token,
		source );
	
	new Handle:Kv = CreateKeyValues( "motd" );
	KvSetString( Kv, "title", "RXG Store" );
	KvSetNum( Kv, "type", MOTDPANEL_TYPE_URL );
	KvSetString( Kv, "msg", url );
	ShowVGUIPanel( client, "info", Kv, true );
	CloseHandle( Kv );
}

//-------------------------------------------------------------------------------------------------
public OnQuickAuthSave( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	DBRELAY_TQuery( OnQuickAuthFetch, "SELECT LAST_INSERT_ID()", data );
	
	if( !hndl ) {
		CloseHandle(data);
		LogError( "SQL error saving QuickAuth token ::: %s", error );
		return;
	}
}

//-------------------------------------------------------------------------------------------------
public OnQuickAuthFetch( Handle:owner, Handle:hndl, const String:error[], any:data ) {
	
	if( !hndl ) {
		LogError( "SQL error fetching QuickAuth ID ::: %s", error );
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
	
	if( !DBRELAY_IsConnected() ) {
		PrintToChat( client, "The database could not be reached. Please try again later." );
		return Plugin_Handled;
	}
	
	QueryClientConVar(client, "cl_disablehtmlmotd", ConVar_QueryClient);
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public ConVar_QueryClient( QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[] ) {

	if( cookie == QUERYCOOKIE_FAILED ) {
		return;
	}
	
	if( StringToInt(cvarValue) == 1 ) {
		PrintToChat( client, "\x01You have web pages blocked. Please visit \x04store.reflex-gamers.com \x01or unblock web pages by entering \x04cl_disablehtmlmotd 0 \x01in console." );
		return;
	}

	new token = GetRandomInt( 10000, 100000 );
	
	decl String:clan_tag[32];
	CS_GetClientClanTag( client, clan_tag, sizeof clan_tag );
	new bool:is_member = StrEqual( clan_tag, RXG_CSGO_CLAN );
	
	decl String:query[1024];
	FormatEx( query, sizeof query, 
		"INSERT INTO sourcebans_store.quick_auth (user_id, token, server, is_member) VALUES (%d, %d, '%s', %d)",
		GetSteamAccountID(client),
		token,
		c_ip,
		is_member );
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, GetClientUserId(client) );
	WritePackCell( pack, token );
	
	if( DBRELAY_IsConnected() ) {
		DBRELAY_TQuery( OnQuickAuthSave, query, pack );
	} else {
		PrintToChat( client, "\x01Visit our store at \x04store.reflex-gamers.com");
	}
	
	//ReplyToCommand( client, "Visit our store at store.reflex-gamers.com" );
}

