
#include <sourcemod>
#include <rxgstore>
#include <dbrelay>
#include <rxgcommon>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "RXG Store Notifications",
    author      = "WhiteThunder",
    description = "Notifies players about pending free items",
    version     = "1.0.0",
    url         = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------

// rxgstore config
KeyValues kv_config;

char g_database[65];

char g_initial_space[6];

//-----------------------------------------------------------------------------
#pragma unused GAME
int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	char gamedir[8];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual( gamedir, "csgo", false )) {
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	g_initial_space = (GAME == GAME_CSGO) ? "\x01 " : "";
	
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
	
	delete kv_config;
}

//-----------------------------------------------------------------------------
public int RXGSTORE_OnClientLoggedIn( int client, int account ) {
	
	DataPack data = new DataPack();
	
	data.WriteCell( GetClientUserId(client) );
	data.WriteCell( account );
	
	char query[1024];
	FormatEx( query, sizeof query,
		"SELECT 'gifts' as type, count(*) as total FROM %s.gift WHERE recipient_id=%d AND accepted=0 UNION SELECT 'rewards' as type, count(*) as total FROM %s.reward_recipient WHERE recipient_id=%d AND accepted=0",
		g_database, account, g_database, account );
	
	DBRELAY_TQuery( OnClientGiftsLoaded, query, data );
}

//-----------------------------------------------------------------------------
public void OnClientGiftsLoaded( Handle owner, Handle hndl, const char[] error, 
                            DataPack data ) {
	
	data.Reset();
	int client  = GetClientOfUserId( data.ReadCell() );
	
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
}
