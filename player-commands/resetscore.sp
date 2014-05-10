
//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <cstrike>

//#undef REQUIRE_PLUGIN
//#include <updater>

//#define DEBUG

#pragma semicolon 1

// 3:06 PM 12/23/2013 - 1.0.2
//   using new sourcemod functions
//   removed updater support
// 1.0.1 - 9/29/13
//   using gamedata now
//   added updater support
//   

//#define UPDATE_URL "http://www.mukunda.com/plugins/resetscore/update.txt"

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "resetscore",
	author = "mukunda",
	description = "!resetscore - Resets your score",
	version = "1.0.2",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
//new String:score_data_start[64];
//new assists_offset;
//new score_offset;
//new mvp_offset;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
//	new Handle:conf = LoadGameConfigFile("resetscore");
//	if (conf == INVALID_HANDLE)
//		SetFailState("gamedata/resetscore.txt missing");
		
//	GameConfGetKeyValue( conf, "ScoreDataStart", score_data_start, sizeof score_data_start );
//	assists_offset = GameConfGetOffset( conf, "Assists" );
//	score_offset = GameConfGetOffset( conf, "Score" );
//	mvp_offset = GameConfGetOffset( conf, "MVPs" );
//	
//	CloseHandle(conf);
 
	RegConsoleCmd( "sm_resetscore", Command_resetscore );
	
	
    
//	#if !defined( DEBUG )
//	
//		if (LibraryExists("updater"))
//		{
//			Updater_AddPlugin(UPDATE_URL);
//		}
//		
//	#else
//	
//		RegConsoleCmd( "rs_test", test );
//	
//	#endif
}

//#if !defined( DEBUG )
//
//-------------------------------------------------------------------------------------------------
//public OnLibraryAdded( const String:name[] ) {
//	// nobody likes old bacon
//	if( StrEqual( name, "updater" ) ) {
//		Updater_AddPlugin(UPDATE_URL);
//	}
//}
//
//#endif

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_resetscore( client, args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !IsClientInGame(client) ) return Plugin_Handled;
//	Scores_SetPlayer( client, 0, 0, 0, 0, 0 );
	
	SetEntProp( client, Prop_Data, "m_iFrags", 0 );
	CS_SetClientAssists( client, 0 );
	SetEntProp( client, Prop_Data, "m_iDeaths", 0 );
	CS_SetMVPCount( client, 0 );
	CS_SetClientContributionScore( client, 0 );

	PrintToChat( client, "\x01 \x0BYour score has been reset. Good Luck!" );
	return Plugin_Handled;
}

#if defined DEBUG

//----------------------------------------------------------------------------------------------------------------------
new addresses_1[1024];
new addresses_2[1024];

new address_write_1 = 0;
new address_write_2 = 0;

new current_list = 0;
new first_list = 1;

CheatSearch( client, argint, bool:reset=false ) {
	if( reset ) {
		current_list = 0;
		address_write_1 = 0;
		address_write_2 = 0;
		current_list = 0;
		first_list = 1;
		PrintToConsole( client, "reset search" );
		return;
	}

	if( first_list ) { // search entire memory
		PrintToConsole( client, " *** performing memory search" );
		for( new i = 4; i < 10000; i+= 4 ) {
			if( GetEntData( client, i ) == argint ) {			
	
				addresses_1[address_write_1] = i;
				address_write_1++;
				PrintToConsole( client, "found %d", i );
			}
		}
		first_list = 0;
		PrintToConsole( client, " *** total %d matches", address_write_1 );
	} else { // search list
		if( current_list == 0 ) {
			for( new i = 0; i < address_write_1; i++ ) {
				if( GetEntData( client, addresses_1[i] ) == argint ) {
					addresses_2[address_write_2] = addresses_1[i];
					address_write_2++;
					PrintToConsole( client, "found %d", addresses_1[i] );
					
				}
			}
			PrintToConsole( client, " *** total %d matches", address_write_2 );
			address_write_1 = 0;
			current_list = 1;
		} else if( current_list == 1 ) {
			for( new i = 0; i < address_write_2; i++ ) {
				if( GetEntData( client, addresses_2[i] ) == argint ) {
					addresses_1[address_write_1] = addresses_2[i];
					address_write_1++;
					PrintToConsole( client, "found %d", addresses_2[i] );
					
				}
			}
			PrintToConsole( client, " *** total %d matches", address_write_1 );
			address_write_2 = 0;
			current_list = 0;
		}
	}
}


//-------------------------------------------------------------------------------------------------
public Action:test( client, args ) {
//-------------------------------------------------------------------------------------------------


	/* cheat search*/
	if( args == 0 ) {
		CheatSearch( client,0,true);
 
		return Plugin_Handled;
	} else {
		decl String:arg[32];
		GetCmdArg( 1, arg, sizeof(arg) );
		CheatSearch( client, StringToInt(arg) );
	}

	
	return Plugin_Handled;
}

#endif

// 7872 = end of weapon purchases <old>

//-------------------------------------------------------------------------------------------------
//Scores_SetPlayer( client, kills, assists, deaths, score, mvps ) {
//-------------------------------------------------------------------------------------------------
	
//	new offset = FindDataMapOffs( client, "m_iFrags" ) + assists_offset;
//	SetEntProp( client, Prop_Data, "m_iFrags", kills );
//	SetEntData( client, offset, assists );
//	SetEntProp( client, Prop_Data, "m_iDeaths", deaths );
//	
//	new start = FindSendPropInfo("CCSPlayer", score_data_start);
//	
//	SetEntData( client, start + mvp_offset, mvps );
//	SetEntData( client, start + score_offset, score );

//}

