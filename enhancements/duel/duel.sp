#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
//#include <cstrike_weapons>

#undef REQUIRE_PLUGIN
//#include <restrict>
#include <updater>
#pragma semicolon 1

// CHANGES:
//  1.3.0
//    changed to sm cstrike functions
//  1.2.1 
//    exposed OnDuelEnd
//  1.2.0
//    overrides file
//    strip map folder from names
//  1.1.3
//    removed invalid weapons crash
//  1.1.2
//    fixed deadtalk
//  1.1.1
//    reset weapon restore
//  1.1.0
//    duel v1.1.0 bitches
//    add time to duel if under 30 seconds
//  1.0.2 - 3/25/13
//    using keyvalues for data
//    added 'short' as alias for 'close'
//    more map support
//    added screen flash
//    added start sound
//

#define UPDATE_URL "http://www.mukunda.com/plagins/duel/update.txt"

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "duel",
	author = "mukunda",
	description = "i demand satisfaction",
	version = "1.3.1",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------

#define CLIENT_WEAPONS_MAX 64
 
#define SND_DUEL_START	"play ui/bonus_alert_start.wav"
#define SND_DUEL_COUNT	"ui/beep07.wav"
#define SND_DUEL_DRAW	"play *duel/revolver_ocelot_draw.mp3"
//#define SND_DUEL_DIE

#define SNDF_DUEL_DRAW	"sound/duel/revolver_ocelot_draw.mp3"

#define CS_SLOT_KNIFE 2
#define CS_SLOT_UNKNOWN 5

#define IMMEDIATE_RESTORE_DELAY 0.5

new weapon_supported[] = {
	0,1,1,1,
	0,0,0,1,
	1,0,1,1,
	1,1,1,1,
	1,1,1,1,
	1,1,1,1,
	0,1,1,1,
	1,1,0,0,
	0,0,1,1,
	1,1,1,1,
	1,1,1,1,
	1,1,1,1,
	1,1,1,0,
	0,0,0
};

new bool:vote_used_this_round;
new bool:duel_active;
//new bool:vote_in_progress;
new bool:round_is_over;

new bool:bomb_planted;

new UserMsg:g_FadeUserMsgId;

new duel_userid[2];
new duel_timer = 0;
new players_t;
new players_ct;
//new Float:newround_time;
//new Float:round_length;
//new Float:spround_start_time;
new spround_round_index;
new round_counter;
new bool:duel_supported;
//new duel_vector_offset;
//new duel_vector_index;

new Float:duel_vectors[3][4][3];	// [range][pos1,ang1,pos2,ang2][vector index]

new bool:duel_challenging;
new challenge_round;
new Float:challenge_time;
new String:duel_weapon[64];
new duel_range;
new duel_loser;

new bool:restore_weapons;
new CSWeaponID:old_weapons[2][CLIENT_WEAPONS_MAX];
new old_weapons_count[2];

new new_weapons[2];

new Handle:sm_duel_restore_weapons_immediately;
new bool:restore_weapons_immediately;

new Handle:sv_alltalk			= INVALID_HANDLE;	// CVARS
new Handle:sv_deadtalk			= INVALID_HANDLE;	//

//new Handle:mp_roundtime			= INVALID_HANDLE;
//new Handle:mp_freezetime		= INVALID_HANDLE;

new Handle:kv_config			= INVALID_HANDLE;
new Handle:kv_config2			= INVALID_HANDLE; // overrides

new Handle:duelmenu				= INVALID_HANDLE;

new Handle:g_OnDuelEnd;

enum {
	RANGE_CLOSE,
	RANGE_MID,
	RANGE_LONG
};

new bool:alltalk_state;
new bool:deadtalk_state;
new bool:reset_talking;

//----------------------------------------------------------------------------------------------------------------------
public bool:IsValidClient(client) {

	if(client <= 0) return false;
	if(client > MaxClients) return false;
	return IsClientInGame(client);
}

//----------------------------------------------------------------------------------------------------------------------
LoadConfigFile() {

	if( kv_config != INVALID_HANDLE ) {
		CloseHandle( kv_config );
	}
	if( kv_config2 != INVALID_HANDLE ) {
		CloseHandle( kv_config2 );
	}
	
	kv_config = CreateKeyValues( "Duel" );
	kv_config2 = CreateKeyValues( "Duel" );
	
	decl String:filepath[256];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/duel.txt" );
	if( !FileExists( filepath ) ) {
		SetFailState( "duel.txt not found" );
		return;
	}
	if( !FileToKeyValues( kv_config, filepath ) ) {
		SetFailState( "Error loading config file." );
	}
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/duel-overrides.txt" );
	if( !FileExists( filepath ) ) { 
		CloseHandle( kv_config2 );
		kv_config2 = INVALID_HANDLE;
		return;
	}
	if( !FileToKeyValues( kv_config, filepath ) ) {
		CloseHandle( kv_config2 );
		kv_config2 = INVALID_HANDLE;
		return;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_reloadconfig( args ) {
	LoadConfigFile();
	LoadDuelVectors();
	PrintToServer( "Reloaded duel configuration." );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	LoadConfigFile();

	g_FadeUserMsgId = GetUserMessageId("Fade");
	
	sv_alltalk		= FindConVar( "sv_alltalk" );
	sv_deadtalk		= FindConVar( "sv_deadtalk" );

	SetConVarFlags( sv_alltalk, GetConVarFlags(sv_alltalk) & ~FCVAR_NOTIFY );
	SetConVarFlags( sv_deadtalk, GetConVarFlags(sv_deadtalk) & ~FCVAR_NOTIFY );
	
	duelmenu = CreateMenu( DuelMenuHandler );
	SetMenuTitle( duelmenu, "You have been challenged to a duel." );
	AddMenuItem( duelmenu, "accept", "Accept." );
	AddMenuItem( duelmenu, "deny", "Deny." );
	SetMenuExitButton(duelmenu, false);
	
	sm_duel_restore_weapons_immediately = CreateConVar( "sm_duel_restore_weapons_immediately", "0", "Restore weapons immediately or on next round start.", FCVAR_PLUGIN );
	restore_weapons_immediately = GetConVarBool(sm_duel_restore_weapons_immediately);
	
	RegConsoleCmd( "duel", Command_duel, "duel <weapon> <long/mid/close>, type 'buy' for weapon list" );
	RegAdminCmd( "forceduel", Command_forceduel, ADMFLAG_SLAY, "forceduel <weapon> <long/mid/close>, admin force" );
	RegServerCmd( "duel_reloadconfig", Command_reloadconfig );
	RegConsoleCmd( "buy", Command_buy );
	RegConsoleCmd( "rebuy", Command_buy );
	RegConsoleCmd( "autobuy", Command_buy );

	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );
	HookEvent( "player_death", Event_PlayerDeath );
	HookEvent( "cs_intermission", Event_Intermission );
	HookEvent( "bomb_planted", Event_BombPlanted );
	 
	if( LibraryExists("updater") )
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	g_OnDuelEnd = CreateGlobalForward("OnClientDied", ET_Ignore, Param_Cell, Param_Cell );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	// nobody likes old bacon
	if( StrEqual( name, "updater" ) ) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

//-------------------------------------------------------------------------------------------------
bool:ParsePositionString( const String:source[], Float:output[6] ) {

	//PrintToServer( "Duel Debug: Parse Position String..." );
	decl String:arg[32];
	new positer = 0;
	for( new i = 0; i < 6; i++ ) {
		if( positer == -1 ) {
			return false;
		}
		positer += BreakString( source[positer], arg, sizeof(arg) );
		//PrintToServer( "Duel Debug: %d = %s -- %d", i, arg,positer );
		if( arg[0] == 0 ) return false;
		output[i] = StringToFloat( arg );
	}
	return true;
}

bool:ParsePositioningSection( Handle:kv, index, const String:name[] ) {


	//PrintToServer( "Duel Debug: Parsing position string...... %s", name );
	
	if( !KvJumpToKey( kv, name ) ) return false;
	//PrintToServer( "Duel Debug:   jumped to key" );
	
	decl String:pos_string[256];
	decl Float:pos[6];
	KvGetString( kv, "pos1", pos_string, sizeof(pos_string) );
	if( !ParsePositionString( pos_string, pos ) ) {
		LogError( "error parsing position (1) in config, index=%s", name );
		return false;
	}
	//PrintToServer( "Duel Debug:   parsed position string %f %f %f %f %f %f", pos[0], pos[1], pos[2], pos[3], pos[4], pos[5] );
	for( new i = 0; i < 3; i++ ) duel_vectors[index][0][i] = pos[i];
	for( new i = 0; i < 3; i++ ) duel_vectors[index][1][i] = pos[3+i];
	
	KvGetString( kv, "pos2", pos_string, sizeof(pos_string) );
	if( !ParsePositionString( pos_string, pos ) ) {
		LogError( "error parsing position (2) in config, index=%s", name );
		return false;
	}
	//PrintToServer( "Duel Debug:   parsed position string %f %f %f %f %f %f", pos[0], pos[1], pos[2], pos[3], pos[4], pos[5] );
	for( new i = 0; i < 3; i++ ) duel_vectors[index][2][i] = pos[i];
	for( new i = 0; i < 3; i++ ) duel_vectors[index][3][i] = pos[3+i];
	
	KvGoBack( kv );
	return true;
}

//-------------------------------------------------------------------------------------------------
LoadDuelVectors() {
	decl String:mapname[64];
	GetCurrentMap( mapname, sizeof(mapname) );
	{
		ReplaceString( mapname, sizeof mapname, "\\", "/" );
		new pos = FindCharInString( mapname, '/', true );
		if( pos != -1 ) {
			strcopy( mapname, sizeof mapname, mapname[pos+1] );
		}
	}
	duel_supported = false;
	
	if( kv_config2 != INVALID_HANDLE ) {
		KvRewind( kv_config2 );
		while( KvJumpToKey( kv_config2, mapname ) ) {
			
			if( !ParsePositioningSection( kv_config2, 0, "close" ) ) break;
			if( !ParsePositioningSection( kv_config2, 1, "mid" ) ) break;
			if( !ParsePositioningSection( kv_config2, 2, "long" ) ) break;
			
			duel_supported = true;
			return;
		}
	}
	
	KvRewind( kv_config );
	if( KvJumpToKey( kv_config, mapname ) ) {
		if( !ParsePositioningSection( kv_config, 0, "close" ) ) return;
		if( !ParsePositioningSection( kv_config, 1, "mid" ) ) return;
		if( !ParsePositioningSection( kv_config, 2, "long" ) ) return;
		
		duel_supported = true;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	duel_supported = false;
	PrecacheSound(SND_DUEL_COUNT);
	PrecacheSound(SND_DUEL_DRAW);
	AddFileToDownloadsTable(SNDF_DUEL_DRAW);
	
	LoadDuelVectors();
	
	restore_weapons = false;
	Event_RoundStart( INVALID_HANDLE, "", false );
}

//----------------------------------------------------------------------------------------------------------------------
StopSpecialRound() {
	if( duel_active ) {
		duel_active = false;
		RestorePlayerWeapons();
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Timer_StopSpecialRound( Handle:timer, any:none ) {
	StopSpecialRound();
}

/*
//----------------------------------------------------------------------------------------------------------------------
CancelActiveVote() {
	if( vote_in_progress ) {
		CancelVote();
		vote_in_progress = false;
	}
}*/

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {

	// remember: called from mapstart too
	round_counter++;
	bomb_planted = false;
	vote_used_this_round = false;

	if( !restore_weapons_immediately ) {
		StopSpecialRound();
	}
	DisableFulltalk();

//	newround_time = GetGameTime();
//	round_length = GetConVarFloat( mp_roundtime )*60 + GetConVarFloat( mp_freezetime );
	round_is_over = false;

	//CancelActiveVote();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	 
	round_is_over = true;
	
	if( duel_active ) {
		
		new winner=0,loser=0;
		
		for( new i = 0; i < 2; i++ ) {
			new client = GetClientOfUserId( duel_userid[i] );
			if( !client ) continue;
			
			if( IsPlayerAlive(client) ) {
				if( winner != 0 ) {
					// both alive - they let the time expire, no winner.
					winner = 0;
				} else {
					winner = client;
				}
			} else { 
				loser = client;
			}
 
		//	SetEntityFlags( clients[i], GetEntityFlags(clients[i]) & ~FL_FROZEN ); might fuck up intermission freeze?
			SetEntityMoveType( client, MOVETYPE_WALK );
			
			if( restore_weapons_immediately ) {
				CreateTimer( IMMEDIATE_RESTORE_DELAY, Timer_StopSpecialRound );
			}
		}
		if( winner ) {
			Call_StartForward( g_OnDuelEnd );
			Call_PushCell( winner );
			Call_PushCell( loser ); 
			Call_Finish();
		}
	} 
}

public Event_Intermission( Handle:event, const String:name[], bool:dontBroadcast ) {
	restore_weapons = false;
}

public Event_BombPlanted( Handle:event, const String:name[], bool:dontBroadcast ) {
	bomb_planted = true;
}
/*
//----------------------------------------------------------------------------------------------------------------------
Float:TimeElapsed() {
	return GetGameTime() - newround_time;
}*/


//----------------------------------------------------------------------------------------------------------------------
EnableFulltalk() {
	if( reset_talking ) return;
	reset_talking = true;
	alltalk_state = GetConVarBool( sv_alltalk );
	deadtalk_state = GetConVarBool( sv_deadtalk );
	SetConVarBool( sv_alltalk, true );
	SetConVarBool( sv_deadtalk, true );	
}
//----------------------------------------------------------------------------------------------------------------------
DisableFulltalk() {
	if( !reset_talking ) return;
	SetConVarBool( sv_alltalk, alltalk_state );
	SetConVarBool( sv_deadtalk, deadtalk_state );	
}

//----------------------------------------------------------------------------------------------------------------------
ScanPlayers( bool:includebots=false) {
	
	players_t = 0;
	players_ct = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsValidClient(i) ) continue;
		if( IsFakeClient(i) && !includebots ) continue;
		
		new team = GetClientTeam(i);
		if( team < 2 ) continue;
		
		if( !IsPlayerAlive(i) ) continue;
		if( team == 2 ) players_t++;
		else players_ct++;
	}
}


//----------------------------------------------------------------------------------------------------------------------
bool:DuelersAreRetardedAndCantDoOneFuckingThingRightInTheirLives() {

	if( duel_range == RANGE_CLOSE ) { // bypass for melee range (knife or taser)
		return false;
	}

	for( new i = 0; i < 2; i++ ) {
		new client = GetClientOfUserId(duel_userid[i]);

		if( !IsPlayerAlive(client) ) return false; // the duel is over



		new prim = GetPlayerWeaponSlot( client, CS_SLOT_PRIMARY );
		if( prim != -1 ) {
		//	if( GetEntProp( prim, Prop_Send, "m_iClip1" ) != 0 ) {

			return false; // player still has a gun and bullets
		//	}
		}
		new pistol = GetPlayerWeaponSlot( client, CS_SLOT_SECONDARY );
		if( pistol != -1 ) {
			
		//	if( GetEntProp( pistol, Prop_Send, "m_iClip1" ) != 0 ) {

			return false; // player still has a gun and bullets
		//	}
		}
	}
	return true;
}


//----------------------------------------------------------------------------------------------------------------------
public Action:SpecialRoundUpdater( Handle:timer, any:round ) {
	if( !duel_active ) return Plugin_Stop;
	if( round_counter != round ) return Plugin_Stop; // the round changed somehow!
	new clients[2];
	clients[0] = GetClientOfUserId( duel_userid[0] );
	clients[1] = GetClientOfUserId( duel_userid[1] );
	if( clients[0] == 0 ||clients[1] == 0 ) return Plugin_Stop;
//	if( !IsClientConnected(duel_players[0]) || !IsClientConnected(duel_players[1]) ) return Plugin_Stop;

	if( !IsClientInGame(clients[0]) || !IsClientInGame(clients[1]) ) return Plugin_Stop;

	if( DuelersAreRetardedAndCantDoOneFuckingThingRightInTheirLives() ) {

		PrintCenterTextAll( "?????" );

		for( new i = 0; i < 2; i++ ) {
			SetEntityFlags( clients[i], GetEntityFlags(clients[i]) & ~FL_FROZEN );
			SetEntityMoveType( clients[i], MOVETYPE_WALK );
		}
		return Plugin_Stop;
	}

	return Plugin_Continue;
}


//----------------------------------------------------------------------------------------------------------------------
bool:FindDuelPlayers() {
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) ) {
			new team = GetClientTeam(i);
			if( team >= 2 ) {
				if( IsPlayerAlive(i) ) {
					if( count == 2 ) {
						//failed...
						return false;
					}
					duel_userid[count] = GetClientUserId(i);
					count++;
				
				}
			}
			
		}
	}
	return count == 2;
}

PlayDrawSound() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) ) {
			ClientCommand( i, SND_DUEL_DRAW );
		}
	}
}

PlayStartSound() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) ) {
			ClientCommand( i, SND_DUEL_START );
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
StartDuel() {
	

	for( new i = 0; i < 2; i++ ) {
		new client = GetClientOfUserId( duel_userid[i] );
		if( !client ) return;
		SetEntityFlags( client, GetEntityFlags(client) & ~FL_FROZEN );
		
		//SetEntityMoveType( client, MOVETYPE_NONE );
	} 
	PrintCenterTextAll( "Draw!" );
	PlayDrawSound();
	//EmitSoundToAll( SND_DUEL_DRAW );
}


//----------------------------------------------------------------------------------------------------------------------
public Action:DuelTimer( Handle:timer ) {
	duel_timer++;

	if( duel_timer >= 7 ) {
		StartDuel();
		return Plugin_Stop;
	} else if( duel_timer >= 2 ) {
		PrintCenterTextAll( "%d...", 7 - duel_timer );
		EmitSoundToAll( SND_DUEL_COUNT );

	}
	return Plugin_Continue;
}


//----------------------------------------------------------------------------------------------------------------------
SetDuelRound() {
	if( !FindDuelPlayers() ) {
		// cancel duel round
		return;
	}
	
	PlayStartSound();
	ScreenFlash();
	
	duel_loser = 0;
	
	duel_active = true;
	restore_weapons = true;
	
	if( GetRemainingRoundTime() < 30.0 ) {
		SetRemainingRoundTime(30.0);
	}

//	spround_start_time = GetGameTime();
	spround_round_index = round_counter;
	CreateTimer( 1.0, SpecialRoundUpdater, spround_round_index, TIMER_REPEAT );

	//if( fulltalk ) 
	EnableFulltalk();

	//HookPlayers();
	//HookPlayerSpawn();

	//SetSpecialRoundState( RTYPE_DUEL, true );
	
	new Float:vel[3];

	new clients[2];
	clients[0] = GetClientOfUserId( duel_userid[0] );
	clients[1] = GetClientOfUserId( duel_userid[1] );
	
	TeleportEntity( clients[0], duel_vectors[duel_range][0], duel_vectors[duel_range][1], vel );
	TeleportEntity( clients[1], duel_vectors[duel_range][2], duel_vectors[duel_range][3], vel );
	
	RemoveAllWeapons();
	
	decl String:weapon_name[64];
	//CS_WeaponIDToAlias( duel_weapon, weapon_name, sizeof weapon_name );
	Format( weapon_name, sizeof(weapon_name), "weapon_%s", duel_weapon );
	SetPlayerWeapons( weapon_name );
	
	for( new i = 0; i < 2; i++ ) {
		SetEntityFlags( clients[i], GetEntityFlags(clients[i]) | FL_FROZEN );
		SetEntityMoveType( clients[i], MOVETYPE_NONE );
		SetEntityHealth( clients[i], 100 );
	}
 	
	PrintCenterTextAll( "Prepare to Draw! Your opponent is behind you!" );
	PrintToChatAll( "\x01 \x04Prepare to Draw! Your opponent is behind you! You cannot crouch or move!" );
	
	duel_timer = 0;
	CreateTimer( 1.0, DuelTimer,_, TIMER_REPEAT );
}


/*
//----------------------------------------------------------------------------------------------------------------------
public Handle_VoteMenu( Handle:menu, MenuAction:action, param1, param2 ) {
	
	if( action == MenuAction_End ) {
		vote_in_progress = false;
		CloseHandle(menu);
	}
}*/

/*
//----------------------------------------------------------------------------------------------------------------------
public Handle_VoteResults( Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2] ) {
	vote_used_this_round = true;
	vote_in_progress = false;
	
	new total_votes = 0;
	
	// get YES votes
	for( new i = 0; i < num_items; i++ ) {
		if( item_info[i][VOTEINFO_ITEM_INDEX] == 0 ) {	// or is it 1 based?
			total_votes = item_info[i][VOTEINFO_ITEM_VOTES];
			break;
		}
	}
	
	// vote success!
//	new String:strtype[64];
//	GetMenuItem(menu, 0, strtype, sizeof(strtype));

	
	total_votes++;
	num_clients++;
	
	if( total_votes == num_clients ) {
		SetDuelRound();
	
		return;
	}
	
	PrintCenterTextAll( "The duel was declined." );
	PrintToChatAll( "\x01 \x0CThe duel was declined." );
	
}*/

//---------------------------------------------------------------------------------------------------------------------
public DuelMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( !duel_challenging ) return 0;
	
	if( action == MenuAction_Select ) {
	
		if( GetGameTime() - challenge_time < 1.5 ) {  // prevent misclick
			DisplayMenu( duelmenu, param1, MENU_TIME_FOREVER );
		}
		
		duel_challenging = false;
		
		if( round_is_over || challenge_round != round_counter ) {
			return 0;
		}
		
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
			
		if( StrEqual(info, "deny") ) {
			PrintCenterTextAll( "The duel was declined." );
			PrintToChatAll( "\x01 \x0CThe duel was declined." );
			vote_used_this_round = true;
		} else if( StrEqual(info,"accept") ) {
			SetDuelRound();
		}
		
	} else if( action == MenuAction_Cancel ) {
		if( !duel_challenging ) return 0;
		duel_challenging = false;
		
		if( param2 == MenuCancel_Exit || param2 == MenuCancel_NoDisplay || param2 == MenuCancel_Interrupted ) return 0;
		
		vote_used_this_round = true;
		PrintCenterTextAll( "The duel was declined." );
		PrintToChatAll( "\x01 \x0CThe duel was declined." );
	} 
	return 0;
}

//----------------------------------------------------------------------------------------------------------------------
bool:BasicVoteChecks( sourceclient ) {
//	if( Restrict_IsWarmupRound() ) {
//		PrintToChat( sourceclient, "This action can't be done during this round." );
//		return false;
//	}
	
	if( round_is_over ) {
		PrintToChat( sourceclient, "The round is over." );
		return false;
	}
	if( !IsPlayerAlive(sourceclient) ) {
		PrintToChat( sourceclient, "You are dead." );
		return false;
	}
	if( IsVoteInProgress() ) {
		PrintToChat( sourceclient, "A vote is in progress." );
		return false;
	}
	if( bomb_planted ) {
		PrintToChat( sourceclient, "Cannot duel when the bomb is planted." );
		return false;
	}
	if( duel_active ) {
		PrintToChat( sourceclient, "A duel is already active!" );
		return false;
	}
	if( vote_used_this_round ) {
		PrintToChat( sourceclient, "A challenge was already used this round." );
		return false;
	}
	/*
	if( TimeElapsed() >= round_length - 5.0 ) {
	 
		PrintToChat( sourceclient, "Cannot start duel with under 5 seconds left." );
		return false;
	}*/
	
	return true;
}

Float:GetRemainingRoundTime() {
	new Float:roundtime = float(GameRules_GetProp( "m_iRoundTime" ));
	new Float:elapsed = GetGameTime() - GameRules_GetPropFloat( "m_fRoundStartTime" );
	return roundtime - elapsed;
}

SetRemainingRoundTime( Float:time ) {
	GameRules_SetPropFloat( "m_fRoundStartTime", GetGameTime() - float(GameRules_GetProp( "m_iRoundTime"))  + time );
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryDuel( sourceclient ) {
//	if( !GetConVarBool(kniferound_duel) ) {
//		PrintToChat( sourceclient, "Duels are disabled." );
//		return false;
//	}
 
	
	if( !duel_supported ) {
		PrintToChat( sourceclient, "Duel isn't supported for this map." );
		return false;
	}

	if( !BasicVoteChecks(sourceclient) ) return false;
	
	//SetDuelRound(); DEBUG BYPASS VOTE
	//return true;
 
	ScanPlayers();
	if( players_t == 1 && players_ct == 1 ) {
		// initiate duel vote
		
		for( new i = 1; i <= MaxClients; i++ ) {
			if( !IsClientInGame(i) ) continue;
			if( i == sourceclient ) continue;
			if( !IsPlayerAlive(i) ) continue;
			PrintToChatAll( "\x01 \x0C%N has challenged his opponent to a duel!", sourceclient );
			DisplayMenu( duelmenu, i, MENU_TIME_FOREVER );
			duel_challenging = true;
			challenge_round = round_counter;
			challenge_time = GetGameTime();
			
			break;
		}
		
		
		
		return true;
	} else {
		
		PrintToChat(sourceclient, "Duel is for 1v1 only!" );
		return false;
	}
	
	
}
 


RemoveAllWeapons()
{
	new maxc = MaxClients;
	for (new i = maxc; i <= GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			decl String:name[64];
			GetEdictClassname(i, name, sizeof(name));
			if( (strncmp(name, "weapon_", 7, false) == 0) ) {

				new CSWeaponID:id = CS_AliasToWeaponID(name[7]);
				if( id != CSWeapon_NONE ) {
					new owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
					if( owner == -1 ) {
						AcceptEntityInput(i, "Kill");
					}

				}


			}
		}
	}

	
}
//----------------------------------------------------------------------------------------------------------------------
SetPlayerWeapons( const String:item[] ) {
	/*
	for( new i = 1; i <= MaxClients; i++ ) {
		SetPlayerWeapon( i, item );
	}*/
	for( new i = 0; i < 2; i++ ) {		
		SetPlayerWeapon( i, item );
	}
}

//----------------------------------------------------------------------------------------------------------------------
RestorePlayerWeapons() {
	if( !restore_weapons ) return;
	for( new i = 0; i < 2; i++ ) {
		LoadPlayerWeapons( i );
	}
}

CSWeaponID:WeaponIDfromEntity( ent ) {
	if( ent == -1 ) return CSWeapon_NONE;
	decl String:classname[64];
	GetEntityClassname( ent, classname, sizeof(classname) );
	ReplaceString( classname, sizeof(classname), "weapon_", "" );
	return CS_AliasToWeaponID( classname );
}	
/*
//----------------------------------------------------------------------------------------------------------------------
PlayerHasTaser( client ) {
	new ent = -1;
	for( new i = 0; i < CLIENT_WEAPONS_MAX; i++ ) {
		ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent != -1 ) {
			new WeaponID:id = WeaponIDfromEntity(ent);
			if( id == WEAPON_TASER ) {
				return ent;
			}
		}
	}
	return 0;
}*/

//----------------------------------------------------------------------------------------------------------------------
#define WEAPON_AMMO_BACKPACK 1452

SavePlayerWeapon( index, ent ) {
	new client = GetClientOfUserId(duel_userid[index]);
	if( !client ) return;
	
	/*
	decl String:name[64];
	GetEntityClassname( ent, name, sizeof(name) );
	new r = ReplaceString( name, sizeof(name), "weapon_", "" );
	if( r == 0 ) return;
	*/
	new CSWeaponID:weap = WeaponIDfromEntity(ent);
	if( weap == CSWeapon_NONE ) return;
	//todo:more checks required?
	//PrintToServer( "Saving player weapon (%d), %d", client, _:weap );
	old_weapons[index][old_weapons_count[index]] = WeaponIDfromEntity(ent);// GetWeaponID(name);//ent;
	old_weapons_count[index]++;
	CS_DropWeapon(client, ent, true, true);
	AcceptEntityInput(ent, "Kill");
}

LoadPlayerWeapons( index ) {

	new client = GetClientOfUserId(duel_userid[index]);
	if( duel_userid[index] == duel_loser ) return;
	if( !client ) return;
	
	StripPlayerWeapons(client);
	
	
	for( new i = 0; i < old_weapons_count[index]; i++ ) {
		decl String:name[64];
		CS_WeaponIDToAlias( old_weapons[index][i], name, sizeof name );
		Format( name, sizeof name, "weapon_%s", name );
		//name = "weapon_";
		//StrCat( name, sizeof(name), weaponNames[old_weapons[index][i]] );
		//PrintToServer( "Restoring player weapons (%d), %s", client, name );
		GivePlayerItem( client, name );
	}
}

StripPlayerWeapons( client ) {
	for( new i = 0; i < CLIENT_WEAPONS_MAX; i++ ) {
		new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent <= 0 ) continue;
		if( ent == GetPlayerWeaponSlot( client, CS_SLOT_KNIFE ) ||
			ent == GetPlayerWeaponSlot( client, CS_SLOT_C4 ) ||
			ent == GetPlayerWeaponSlot( client, CS_SLOT_UNKNOWN ) ) continue;
		
		CS_DropWeapon(client, ent, true, true);
		AcceptEntityInput(ent, "Kill");
	}
}

SetPlayerWeapon( index, const String:item[] ) {

		
	new client = GetClientOfUserId(duel_userid[index]);
	if( !client ) return;

	if( !IsClientConnected(client) ) return;
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;

	old_weapons_count[index] = 0;

	for( new i = 0; i < CLIENT_WEAPONS_MAX; i++ ) {
		new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent <= 0 ) continue;
		if( ent == GetPlayerWeaponSlot( client, CS_SLOT_KNIFE ) ||
			ent == GetPlayerWeaponSlot( client, CS_SLOT_C4 ) ||
			ent == GetPlayerWeaponSlot( client, CS_SLOT_UNKNOWN ) ) continue;
		SavePlayerWeapon( index, ent );
	}
	
	new_weapons[index] = 0;
	if( StrEqual( item, "weapon_knife" ) ) {
		
		return; // dont give player a knife
	}
	

	new ent = GivePlayerItem( client, item );
	new_weapons[index] = ent;	 
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	if( !duel_active ) return Plugin_Continue;
	
	// disable crouching for duel
	if( round_is_over ) return Plugin_Continue; // enable teabagging
	buttons &= ~IN_DUCK;
	return Plugin_Changed;
}

//----------------------------------------------------------------------------------------------------------------------
bool:ProcessDuelArg( client, arg_index, String:weapon[], maxlen, &range, &CSWeaponID:weapid ) {
	decl String:arg[64];
	GetCmdArg( arg_index, arg, sizeof(arg) );
	for( new i = 0; arg[i]; i++ ) {
		arg[i] = CharToLower(arg[i]);
	}
	if( StrEqual( arg, "help", false ) ) {
		ReplyToCommand( client, "duel <weapon> <long/mid/close>, type 'buy' in console for weapon list." );
		return false;
	}
	if( StrEqual( arg, "close", false ) || StrEqual( arg, "short", false ) ) {
		range = RANGE_CLOSE;
		return true;
	} else if( StrEqual( arg, "mid", false ) ) {
		range = RANGE_MID;
		return true;
	} else if( StrEqual( arg, "long", false ) ) {
		range = RANGE_LONG;
		return true;
	}
	
	decl String:alias2[64];
	CS_GetTranslatedWeaponAlias( arg, alias2, sizeof alias2 );
	new CSWeaponID:id = CS_AliasToWeaponID( alias2 );
	if( id == CSWeapon_NONE ) {
		ReplyToCommand( client, "duel: Unknown arg: \"%s\"", arg );
		return false;
	}
	
	if( !CS_IsValidWeaponID(id) || !weapon_supported[id] ) {
		ReplyToCommand( client, "duel: That weapon is not supported.", arg );
		return false;
	}
	//if( type == WeaponTypeArmor || type == WeaponTypeShield || type == WeaponTypeOther || type == WeaponTypeNone ) {
	//	ReplyToCommand( client, "duel: no" );
	//	return false;
	//}
	//if( AllowedGame[id] == 2 || AllowedGame[id] == -1 || id == WEAPON_SG550 || id == WEAPON_SG552 || id == WEAPON_USP || id == WEAPON_MP5NAVY || id == WEAPON_M3 || id == WEAPON_TMP || id == WEAPON_GALIL || 
	//id == WEAPON_SCAR17 || id == WEAPON_KNIFE_GG || id == WEAPON_SCOUT ) {
	//	ReplyToCommand( client, "duel: Unknown arg: \"%s\"", arg );
	//	return false;
	//}

	strcopy( weapon, maxlen, arg );
	weapid = id;
	//weapon = id;
	return true;
}

bool:ProcessDuelArgs( client, args ) {
	new String:weapon[64] = "deagle";
	new range = RANGE_MID;
	new CSWeaponID:weapid = CSWeapon_DEAGLE;
	
	if( args > 0 ) {
		if( !ProcessDuelArg( client, 1, weapon, sizeof weapon, range, weapid ) ) return false;
	}
	if( args > 1 ) {
		if( !ProcessDuelArg( client, 2, weapon, sizeof weapon, range, weapid ) ) return false;
	}
	
	if( weapid == CSWeapon_TASER || weapid == CSWeapon_KNIFE ) {
		range = RANGE_CLOSE;
	}
	
	strcopy( duel_weapon, sizeof duel_weapon, weapon );
	duel_range = range;
	
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_duel( client, args ) {

	if( duel_challenging ) {
		PrintToChat( client, "A challenge is already active." );
		return Plugin_Handled;
	}
	if( !ProcessDuelArgs( client, args ) ) return Plugin_Handled;


	if( !TryDuel( client ) ) {
		return Plugin_Handled;
	}


	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_forceduel( client, args ) {

	if( duel_challenging ) {
		PrintToChat( client, "A challenge is already active." );
		return Plugin_Handled;
	}
	if( !ProcessDuelArgs( client, args ) ) return Plugin_Handled;

	if( !duel_supported ) {
		ReplyToCommand( client, "Duel isn't supported for this map." );
		return Plugin_Handled;
	}
	
//	if( Restrict_IsWarmupRound() ) {
//		PrintToChat( client, "This action can't be done during this round." );
//		return Plugin_Handled;
//	}
	
	if( round_is_over ) {
		PrintToChat( client, "The round is over." );
		return Plugin_Handled;
	}
	if( IsVoteInProgress() ) {
		PrintToChat( client, "A vote is in progress." );
		return Plugin_Handled;
	}
	if( duel_active ) {
		PrintToChat( client, "A duel is already active!" );
		return Plugin_Handled;
	}
	

	ScanPlayers(true);
	if( players_t != 1 || players_ct != 1 ) {
		ReplyToCommand( client, "Duel is for 1v1 only!" );
		return Plugin_Handled;
	}
	
	SetDuelRound();
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Restrict_OnCanPickupWeapon( client, team, WeaponID:id, &bool:result ) {
	if( duel_active ) {
		result = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
	
//-------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( duel_active ) {
		if( duel_loser == 0 ) {
			duel_loser = GetEventInt( event, "userid" );
		}
	}
}

//-------------------------------------------------------------------------------------------------
ScreenFlash() {
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			clients[count] = i;
			count++;
		}
	}
	
	new duration2 = 200;
	new holdtime = 0;

	new flags = 0x10|1;
	//new color[4] = { 255,60,10, 192};
	new color[4] = { 255,255,255, 255};
	new Handle:message = StartMessageEx( g_FadeUserMsgId, clients, count );
	PbSetInt(message, "duration", duration2);
	PbSetInt(message, "hold_time", holdtime);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
}

//-------------------------------------------------------------------------------------------------
public Action:Command_buy( client, args ) {
	return duel_active ? Plugin_Handled : Plugin_Continue;
}