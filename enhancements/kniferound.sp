
// this plugin is broken
// some core components have been moved to the DUEL plugin

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <cstrike_weapons>
#include <restrict>
#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "kniferound",
	author = "mukunda",
	description = "the kniferound",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define TIME_TO_STARTVOTE 10.0 // seconds after the round starts where a vote can be issued

// todo: SOUNDS
#define SND_DUEL_COUNT	"ui/beep07.wav"
#define SND_DUEL_DRAW	"play *duel/revolver_ocelot_draw.mp3"
//#define SND_DUEL_DIE

#define SNDF_DUEL_DRAW	"sound/duel/revolver_ocelot_draw.mp3"

#define CLIENT_WEAPONS_MAX 64

//----------------------------------------------------------------------------------------------------------------------
new Handle:sm_kniferound_cooldown;	// cooldown for special rounds
new Handle:sm_kniferound_cooldown_failed;	// cooldown for special rounds if a vote is declined
new Handle:sm_kniferound_playeroverride; // if both teams are under this amount of players, allow the vote
new Handle:sm_kniferound_knife;	// allow knife round
new Handle:sm_kniferound_taser;	// allow taser round
new Handle:sm_kniferound_nades;	// allow nade round
new Handle:sm_kniferound_duel;	// allow duel		(2 players only)

//----------------------------------------------------------------------------------------------------------------------
new vote_cooldown;
new bool:vote_used_this_round;

new bool:special_round_active;
//new bool:special_round_used;
new special_round_type;
//new bool:special_round_disable_knife;

new bool:vote_using_cd;
new bool:vote_in_progress;
new bool:round_is_over;

enum {	
	RTYPE_INVALID,
	RTYPE_KNIFE,
	RTYPE_TASER,
	RTYPE_NADES,
	RTYPE_DUEL
	
};

new duel_players[2];

new duel_timer = 0;

new players_t;
new players_ct;

new Float:newround_time;
new Float:round_length;

new Float:spround_start_time;
new spround_round_index;

new round_counter;

new Handle:sv_alltalk			= INVALID_HANDLE;	// CVARS
new Handle:sv_deadtalk			= INVALID_HANDLE;	//

new Handle:mp_roundtime			= INVALID_HANDLE;
new Handle:mp_freezetime		= INVALID_HANDLE;

new bool:hooked_players[MAXPLAYERS+1];
new bool:playerspawn_hooked;

//----------------------------------------------------------------------------------------------------------------------
new Float:duelvecs[][] = {

	// cs_office
	{672.830688, 837.234985, -159.968750},
	{22.000000, 90.000000, 0.000000},		// T
	{672.830688, 415.991180, -159.968750},
	{22.000000, -90.000000, 0.000000}		// CT
};

//----------------------------------------------------------------------------------------------------------------------
public bool:IsValidClient(client) {

	if(client <= 0) return false;
	if(client > MaxClients) return false;
	return IsClientInGame(client);
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	sv_alltalk		= FindConVar( "sv_alltalk" );
	sv_deadtalk		= FindConVar( "sv_deadtalk" );

		
	mp_roundtime		= FindConVar( "mp_roundtime" );
	mp_freezetime		= FindConVar( "mp_freezetime" );

	sm_kniferound_cooldown  = CreateConVar( "sm_kniferound_cooldown", "20", "Cooldown between allowed knife rounds.", FCVAR_PLUGIN );
	sm_kniferound_cooldown_failed = CreateConVar( "sm_kniferound_cooldown_failed", "10", "Cooldown if a vote was declined.", FCVAR_PLUGIN );
	sm_kniferound_playeroverride = CreateConVar( "sm_kniferound_playeroverride", "2", "If both teams are under this amount of players, allow the vote always.", FCVAR_PLUGIN );
	sm_kniferound_knife = CreateConVar( "sm_kniferound_knife", "1", "Enable !knife vote.", FCVAR_PLUGIN );
	sm_kniferound_taser = CreateConVar( "sm_kniferound_taser", "1", "Enable !taser vote.", FCVAR_PLUGIN );
	sm_kniferound_nades = CreateConVar( "sm_kniferound_nades", "1", "Enable !nades vote.", FCVAR_PLUGIN );
	sm_kniferound_duel = CreateConVar( "sm_kniferound_duel", "1", "Enable !duel vote.", FCVAR_PLUGIN );

	RegAdminCmd( "sm_kniferound_resetcd", Command_resetcd, ADMFLAG_SLAY );
	RegAdminCmd( "sm_kniferound_force", Command_force, ADMFLAG_SLAY );

	RegConsoleCmd( "say", Command_Say );
	RegAdminCmd( "sm_forceduel", Command_test, ADMFLAG_SLAY );

	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );

	vote_cooldown = GetConVarInt( sm_kniferound_cooldown_failed );	
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	vote_cooldown = GetConVarInt( sm_kniferound_cooldown_failed );
	special_round_active = false;
	vote_in_progress = false;
	round_counter = 0;

	for( new i = 0; i <= MAXPLAYERS; i++ ) {
		hooked_players[i] = false;
	}

	UnhookPlayerSpawn();

	PrecacheSound(SND_DUEL_COUNT);
	PrecacheSound(SND_DUEL_DRAW);

	AddFileToDownloadsTable(SNDF_DUEL_DRAW);
	// todo: precache sounds
	// todo: sound downloads
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer(client) {
	if( special_round_active ) {
		HookPlayer(client);
	}
}

WeaponID:WeaponIDfromEntity( ent ) {
	if( ent == -1 ) return WEAPON_NONE;
	decl String:classname[64];
	GetEntityClassname( ent, classname, sizeof(classname) );
	ReplaceString( classname, sizeof(classname), "weapon_", "" );
	return GetWeaponID( classname );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Hook_OnTakeDamage(victim,&attacker,&inflictor,&Float:damage,&damagetype,&weapon,Float:damageForce[3],Float:damagePosition[3]) {
	if( special_round_active ) {
		if( special_round_type == RTYPE_NADES || special_round_type == RTYPE_TASER ) {
			
			if(!(attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients)) {
				return Plugin_Continue;
			}
			
			if( weapon > 0 && IsValidEntity(weapon) ) {
			
				new WeaponID:id = WeaponIDfromEntity(weapon);

				if( id == WEAPON_KNIFE ) {
					// print message to attacker
					PrintHintText( attacker, "Knife damage is disabled!" );
					damage = 0.0;
					return Plugin_Changed;
				}
			}

			if( special_round_type == RTYPE_NADES ) {
				damageForce[0] *= 5.0;
				damageForce[1] *= 5.0;
				damageForce[2] *= 5.0;
				return Plugin_Changed;
			
			}
		}
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
HookPlayer( client ) {
	if( !IsValidClient(client) ) return;
	if( !hooked_players[client] ) {
		SDKHook( client, SDKHook_OnTakeDamage, Hook_OnTakeDamage );
		hooked_players[client] = true;
	}
}

//----------------------------------------------------------------------------------------------------------------------
UnhookPlayer( client ) {
	if( !IsValidClient(client) ) {
		hooked_players[client] = false;
		return;
	}
	if( hooked_players[client] ) {
		hooked_players[client] = false;
		SDKUnhook( client, SDKHook_OnTakeDamage, Hook_OnTakeDamage );
	}
}

//----------------------------------------------------------------------------------------------------------------------
HookPlayers() {
	for( new i = 1; i <= MaxClients; i++ ) {
		HookPlayer(i);
	}
}

//----------------------------------------------------------------------------------------------------------------------
UnhookPlayers() {
	for( new i = 1; i <= MaxClients; i++ ) {
		UnhookPlayer(i);
	}
}

//----------------------------------------------------------------------------------------------------------------------
HookPlayerSpawn() {
	if( !playerspawn_hooked ) {
		HookEvent( "player_spawn", Event_PlayerSpawn );
		HookEvent( "player_death", Event_PlayerDeath );
		playerspawn_hooked = true;
	}
}

//----------------------------------------------------------------------------------------------------------------------
UnhookPlayerSpawn() {
	if( playerspawn_hooked ) {
		UnhookEvent( "player_spawn", Event_PlayerSpawn );
		UnhookEvent( "player_death", Event_PlayerDeath );
		playerspawn_hooked = false;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_resetcd( client, args ) {
	vote_cooldown = 0;
	PrintToConsole( client, "Vote Cooldown Reset!" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_force( client, args ) {
	if( special_round_active ) {
		PrintToConsole( client, "A special round is already active!" );
		return Plugin_Handled;
	}
	if( args < 1 ) {
		PrintToConsole( client, "usage: force <mode>, <mode> can be 'taser', 'knife', or 'nades'" );
		return Plugin_Handled;
	}
	decl String:arg[32];
	GetCmdArg( 1, arg, sizeof(arg) );
	new type = TranslateRoundType(arg);
	if( type == RTYPE_INVALID || type == RTYPE_DUEL ) {
		PrintToConsole( client, "Invalid <mode>, <mode> can be 'taser', 'knife', or 'nades'" );
		return Plugin_Handled;
	}

	if( type == RTYPE_KNIFE ) {
		SetKnifeRound();
	} else if( type == RTYPE_TASER ) {
		SetTaserRound();
	} else if( type == RTYPE_NADES ) {
		SetNadesRound();
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
StopSpecialRound() {
	if( special_round_active ) {
		special_round_active = false;
		UnhookPlayers();
		UnhookPlayerSpawn();
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
CancelActiveVote() {
	if( vote_in_progress ) {
		CancelVote();
		vote_in_progress = false;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_counter++;

	vote_cooldown--;
	if( vote_cooldown <= 0 ) vote_cooldown = 0;
	vote_used_this_round = false;

	StopSpecialRound();
	newround_time = GetGameTime();
	round_length = GetConVarFloat( mp_roundtime )*60 + GetConVarFloat( mp_freezetime );
	round_is_over = false;

	CancelActiveVote();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	StopSpecialRound();
	round_is_over = true;

	CancelActiveVote();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {

	if( special_round_active ) {
		new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
		if( special_round_type == RTYPE_DUEL ) {
			ForcePlayerSuicide(client);
			PrintToChat( client, "[SM] You joined during a duel." );
		} else if( special_round_type == RTYPE_KNIFE || special_round_type == RTYPE_TASER || special_round_type == RTYPE_NADES ) {
			SetPlayerWeapon( client, "weapon_knife" );
		}
	} //else {
	//	PrintToServer( "KNIFEROUND-DEBUG: player spawn hooked outside of special round!" );
	//}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	/////
}

//----------------------------------------------------------------------------------------------------------------------
Float:TimeElapsed() {
	return GetGameTime() - newround_time;
}

//----------------------------------------------------------------------------------------------------------------------
Float:SpecialTimeElapsed() {
	return GetGameTime() - spround_start_time;
}

//----------------------------------------------------------------------------------------------------------------------
EnableFulltalk() {
	SetConVarBool( sv_alltalk, true );
	SetConVarBool( sv_deadtalk, true );	
}

//----------------------------------------------------------------------------------------------------------------------
ScanPlayers() {
	
	players_t = 0;
	players_ct = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) && !IsFakeClient(i) ) {
			new team = GetClientTeam(i);
			if( team >= 2 ) {
				if( IsPlayerAlive(i) ) {
					if( team == 2 ) players_t++;
					else players_ct++;
				}
			}
			
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
bool:DuelersAreRetardedAndCantDoOneFuckingThingRightInTheirLives() {
	
	for( new i = 0; i < 2; i++ ) {
		new client = duel_players[i];
		
		new pistol = GetPlayerWeaponSlot( client, _:SlotPistol );
		if( pistol != -1 ) {

			if( GetEntProp( pistol, Prop_Send, "m_iClip1" ) != 0 ) {

				return false; // player still has a gun and bullets
			}
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:GivePlayerGrenade( client ) {
	if( !IsValidClient(client) ) return false;
	if( !IsPlayerAlive(client) ) return false;
	
	if( GetPlayerWeaponSlot( client, _:SlotGrenade ) == -1 ) {
		GivePlayerItem( client, "weapon_hegrenade" );
		return true;
	}
	return false;
}

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
}

//----------------------------------------------------------------------------------------------------------------------
bool:GivePlayerTaser( client ) {
	if( !IsValidClient(client) ) return false;
	if( !IsPlayerAlive(client) ) return false;
	if( PlayerHasTaser(client) != 0 ) return false;
	GivePlayerItem( client, "weapon_taser" );
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
RestockPlayerBombs() {
	for( new i = 1; i <= MaxClients; i++ ) {
		GivePlayerGrenade(i);
	}
}

//----------------------------------------------------------------------------------------------------------------------
RestockPlayerTasers() {
	for( new i = 1; i <= MaxClients; i++ ) {
		GivePlayerTaser(i);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SpecialRoundUpdater( Handle:timer, any:round ) {
	if( !special_round_active ) {
		return Plugin_Stop;
	}
	if( round_counter != round ) {
		return Plugin_Stop; // the round changed somehow!
	}
	if( round_is_over ) {
		return Plugin_Stop;
	}
	
	
	
	if( special_round_type == RTYPE_DUEL ) {
		if( !IsClientConnected(duel_players[0]) || !IsClientConnected(duel_players[1]) ) {
			return Plugin_Stop;
		}

		if( !IsClientInGame(duel_players[0]) || !IsClientInGame(duel_players[1]) ) {
			return Plugin_Stop;
		}
		if( DuelersAreRetardedAndCantDoOneFuckingThingRightInTheirLives() ) {

			PrintCenterTextAll( "Seriously?" );
			for( new i = 0; i < 2; i++ ) {
				SetEntityFlags( duel_players[i], GetEntityFlags(duel_players[i]) & ~FL_FROZEN );
				SetEntityMoveType( duel_players[i], MOVETYPE_WALK );
			}
			return Plugin_Stop;
		}
	} else if( special_round_type == RTYPE_NADES ) {
		RestockPlayerBombs();
	} else if( special_round_type == RTYPE_TASER ) {
		RestockPlayerTasers();
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
SetSpecialRoundState( type, fulltalk ) {
	special_round_active = true;
	special_round_type = type;
	spround_start_time = GetGameTime();
	spround_round_index = round_counter;
	CreateTimer( 1.0, SpecialRoundUpdater, spround_round_index, TIMER_REPEAT );

	if( fulltalk ) 
		EnableFulltalk();

	HookPlayers();
	HookPlayerSpawn();
}

//----------------------------------------------------------------------------------------------------------------------
SetKnifeRound() {
	SetSpecialRoundState( RTYPE_KNIFE, false );
	RemoveAllWeapons();
	SetPlayerWeapons( "weapon_knife" );

	PrintCenterTextAll( "Knife Round!" );
	PrintToChatAll( "[SM] Knife Round!" );
}

//----------------------------------------------------------------------------------------------------------------------
SetTaserRound() {
	SetSpecialRoundState( RTYPE_TASER, false );
	RemoveAllWeapons();
	SetPlayerWeapons("weapon_knife");

	PrintCenterTextAll( "Taser Round!" );
	PrintToChatAll( "[SM] Taser Round! The knife does ZERO damage." );
}

//----------------------------------------------------------------------------------------------------------------------
SetNadesRound() {
	SetSpecialRoundState( RTYPE_NADES, false );
	RemoveAllWeapons();
	SetPlayerWeapons("weapon_knife");
	
	EnableFulltalk();

	PrintCenterTextAll( "Nade Round!" );
	PrintToChatAll( "[SM] Nade Round! The knife does ZERO damage." );
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
					duel_players[count] = i;
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

//----------------------------------------------------------------------------------------------------------------------
StartDuel() {
	for( new i = 0; i < 2; i++ ) {
		SetEntityFlags( duel_players[i], GetEntityFlags(duel_players[i]) & ~FL_FROZEN );
		SetEntityHealth( duel_players[i], 100 );
		//SetEntityMoveType( duel_players[i], MOVETYPE_NONE );
	} 
	PrintCenterTextAll( "Draw!" );
	PlayDrawSound();
	//EmitSoundToAll( SND_DUEL_DRAW );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:DuelTimer( Handle:timer ) {
	duel_timer++;

	if( duel_timer >= 5 ) {
		StartDuel();
		return Plugin_Stop;
	} else if( duel_timer >= 2 ) {
		PrintCenterTextAll( "%d...", 5 - duel_timer );
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
	
	SetSpecialRoundState( RTYPE_DUEL, true );
	
	new Float:vel[3];

	TeleportEntity( duel_players[0], duelvecs[0], duelvecs[1], vel );
	TeleportEntity( duel_players[1], duelvecs[2], duelvecs[3], vel );

	RemoveAllWeapons();
	SetPlayerWeapons( "weapon_deagle" );
	
	for( new i = 0; i < 2; i++ ) {
		SetEntityFlags( duel_players[i], GetEntityFlags(duel_players[i]) | FL_FROZEN );
		SetEntityMoveType( duel_players[i], MOVETYPE_NONE );
	}
 
	PrintCenterTextAll( "Prepare to Draw! Your opponent is behind you!" );

	duel_timer = 0;
	CreateTimer( 1.0, DuelTimer,_, TIMER_REPEAT );
}

//----------------------------------------------------------------------------------------------------------------------
TranslateRoundType( const String:type[] ) {
	if( StrEqual(type, "knife") ) {
		return RTYPE_KNIFE;
	} else if( StrEqual(type, "taser") ) {
		return RTYPE_TASER;
	} else if( StrEqual(type, "nades") ) {
		return RTYPE_NADES;
	} else if( StrEqual( type, "duel") ) {
		return RTYPE_DUEL;
	}
	return RTYPE_INVALID;
}

//----------------------------------------------------------------------------------------------------------------------
public Handle_VoteMenu( Handle:menu, MenuAction:action, param1, param2 ) {
	
	if( action == MenuAction_End ) {
		vote_in_progress = false;
		CloseHandle(menu);
	}
}

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
	new String:strtype[64];
	GetMenuItem(menu, 0, strtype, sizeof(strtype));
	new type = TranslateRoundType( strtype );
	
	total_votes++;
	num_clients++;
	
	if( type == RTYPE_TASER || type == RTYPE_KNIFE || type == RTYPE_NADES ) {
		if( (total_votes*100 / num_clients) >= 51 ) {
			if( type == RTYPE_KNIFE ) {
				SetKnifeRound();
			} else if( type == RTYPE_TASER ) {
				SetTaserRound();
			} else if( type == RTYPE_NADES ) {
				SetNadesRound();
			}
		
			if( vote_using_cd )
				vote_cooldown = GetConVarInt( sm_kniferound_cooldown );
			return;
		}
		
	} else if( type == RTYPE_DUEL ) {
		if( total_votes == num_clients ) {
			SetDuelRound();
		
			if( vote_using_cd )
				vote_cooldown = GetConVarInt( sm_kniferound_cooldown );
			return;
		}
	}
	
	if( vote_using_cd )
		vote_cooldown = GetConVarInt( sm_kniferound_cooldown_failed );
	PrintCenterTextAll( "[SM] The vote failed!" );
	
}

//----------------------------------------------------------------------------------------------------------------------
bool:BasicVoteChecks( sourceclient ) {
	if( Restrict_IsWarmupRound() ) {
		PrintToChat( sourceclient, "[SM] This action can't be done during this round." );
		return false;
	}
	
	if( round_is_over ) {
		PrintToChat( sourceclient, "[SM] The round is over." );
		return false;
	}
	if( IsVoteInProgress() ) {
		PrintToChat( sourceclient, "[SM] A vote is in progress." );
		return false;
	}
	if( special_round_active ) {
		PrintToChat( sourceclient, "[SM] Cannot start vote until next round." );
		return false;
	}
	if( vote_used_this_round ) {
		PrintToChat( sourceclient, "[SM] A vote was already used this round." );
		return false;
	}
	if( !IsPlayerAlive(sourceclient) ) {
		PrintToChat( sourceclient, "[SM] You are dead." );
		return false;
	}
	if( TimeElapsed() >= round_length - 20.0 ) {
		//PrintToChatAll( "DEBUG %f , %f", TimeElapsed(), round_length );
		PrintToChat( sourceclient, "[SM] Cannot start vote with under 20 seconds left." );
		return false;
	}
	
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
CreateKnifeVote( sourceclient, players_to_ignore_cd, const String:title[], const String:value[], const String:chatmsg[] ) {
	ScanPlayers();
	new bool:usecd = true;
	if( players_ct == 0 || players_t == 0 ) {
		PrintToChat( sourceclient, "[SM] Cannot start vote." );
		return false;
	}
	if( players_ct <= players_to_ignore_cd && players_t <= players_to_ignore_cd ) {
		usecd = false;
	}
	if( usecd ) {
		if( vote_cooldown != 0 ) {
			PrintToChat( sourceclient, "[SM] Vote cannot be issued for another %d rounds.", vote_cooldown );
			return false;
		}
		if( TimeElapsed() > TIME_TO_STARTVOTE ) {
			PrintToChat( sourceclient, "[SM] Vote can only be issued at the beginning of a round." );
			return false;
		}
	}
	
	new Handle:menu = CreateMenu( Handle_VoteMenu );
	SetVoteResultCallback( menu, Handle_VoteResults );
	SetMenuTitle( menu, title );
	AddMenuItem( menu, value, "Yes" );
	AddMenuItem( menu, "no", "No" );
	vote_using_cd = usecd;
	SendAliveVoteMenu(sourceclient,menu);
	
	PrintToChatAll( chatmsg );
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryKnifeRound( sourceclient ) {
	if( !GetConVarBool(sm_kniferound_knife) ) {
		PrintToChat( sourceclient, "[SM] Knife rounds are disabled." );
		return false;
	}
	if( !BasicVoteChecks(sourceclient) ) return false;
	if( !CreateKnifeVote( sourceclient, GetConVarInt(sm_kniferound_playeroverride), "Knife Round?", "knife", "[SM] Knife Round Vote!" ) ) return false;
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryTaserRound( sourceclient ) {
	if( !GetConVarBool(sm_kniferound_taser) ) {
		PrintToChat( sourceclient, "[SM] Taser rounds are disabled." );
		return false;
	}
	if( !BasicVoteChecks(sourceclient) ) return false;
	if( !CreateKnifeVote( sourceclient, GetConVarInt(sm_kniferound_playeroverride), "Taser Round?", "taser", "[SM] Taser Round Vote!" ) ) return false;
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryNadeRound( sourceclient ) {
	if( !GetConVarBool(sm_kniferound_nades) ) {
		PrintToChat( sourceclient, "[SM] Nade rounds are disabled." );
		return false;
	}
	if( !BasicVoteChecks(sourceclient) ) return false;
	if( !CreateKnifeVote( sourceclient, GetConVarInt(sm_kniferound_playeroverride), "Nade Round?", "nades", "[SM] Naderound Vote!" ) ) return false;
	
	return true;  
}

//----------------------------------------------------------------------------------------------------------------------
bool:TryDuel( sourceclient ) {
	if( !GetConVarBool(sm_kniferound_duel) ) {
		PrintToChat( sourceclient, "[SM] Duels are disabled." );
		return false;
	}

	if( !BasicVoteChecks(sourceclient) ) return false;
	
	//PrintToChatAll( "Debug3" );
	ScanPlayers();
	if( players_t == 1 && players_ct == 1 ) {
		// initiate duel vote
		
		new Handle:menu = CreateMenu( Handle_VoteMenu );
		SetVoteResultCallback( menu, Handle_VoteResults );
		SetMenuTitle( menu, "Accept the Duel?" );
		AddMenuItem( menu, "duel", "Yes" );
		AddMenuItem( menu, "no", "No" );
		SendAliveVoteMenu(sourceclient,menu);

		PrintToChat( sourceclient, "[SM] You challeneged the other player to a duel!" );
		
		return true;
	} else {
		
		PrintToChat(sourceclient, "[SM] Duel is for 1v1 only!" );
		return false;
	}
	
	
}

//----------------------------------------------------------------------------------------------------------------------
SendAliveVoteMenu( sourceclient, Handle:menu ) {
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i < MaxClients; i++ ) {
		
		if( IsValidClient(i) && i != sourceclient ) {
			if( IsPlayerAlive(i) ) {
				clients[count] = i;
				count++;
			}
		}
	}

	if( VoteMenu( menu, clients, count, 10 ) ) {

		vote_in_progress = true;
	}
}



//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Say( client, args ) {
	
	decl String:buffer[64];
	GetCmdArgString( buffer, sizeof(buffer) );
	StripQuotes(buffer);
	TrimString(buffer);
	//PrintToChatAll( "Debug1: %s - %d", buffer, strlen(buffer) );

	if( StrEqual( buffer, "!knife" ) ) {
		// try knife round
		if( !TryKnifeRound( client ) ) {
			return Plugin_Handled;
		}
	} else if( StrEqual( buffer, "!taser" ) ) {
		// try taser round
		if( !TryTaserRound( client ) ) {
			return Plugin_Handled;
		}
	} else if( StrEqual( buffer, "!nades" ) ) {
		// try nade round
		if( !TryNadeRound( client ) ) {
			return Plugin_Handled;
		}
	} else if( StrEqual( buffer, "!duel" ) ) {
		// try duel
		//PrintToChatAll( "Debug2" );
		if( !TryDuel( client ) ) {

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------


RemoveAllWeapons()
{
	new maxc = MaxClients;
	for (new i = maxc; i <= GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			decl String:name[WEAPONARRAYSIZE];
			GetEdictClassname(i, name, sizeof(name));
			if((strncmp(name, "weapon_", 7, false) == 0 || strncmp(name, "item_", 5, false) == 0) ) {

				new WeaponID:id = Restrict_GetWeaponIDExtended(name);
				if( id != WEAPON_NONE ) {
					new owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
					if( owner == -1 ) {
						AcceptEntityInput(i, "Kill");
					}


					//	if( id != WEAPON_KNIFE ) {
					//		RemovePlayerItem( owner, i );
						//} else {
						//	EquipPlayerWeapon( owner, i );
						//}
					//}
				}


			}
		}
	}

	
}

//----------------------------------------------------------------------------------------------------------------------
SetPlayerWeapons( const String:item[] ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		SetPlayerWeapon( i, item );
	}
}

//----------------------------------------------------------------------------------------------------------------------
#define WEAPON_AMMO_BACKPACK 1452

SetPlayerWeapon( client, const String:item[] ) {

	if( !IsClientConnected(client) ) return;
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;

	// strip player weapons
	new ent;
	ent = GetPlayerWeaponSlot( client, int:SlotPrimmary );
	if( ent != -1 ) RemovePlayerItem( client, ent );
	ent = GetPlayerWeaponSlot( client, int:SlotPistol );
	if( ent != -1 ) RemovePlayerItem( client, ent );

	//ent = GetPlayerWeaponSlot( client, int:SlotKnife );
	//if( ent != -1 ) RemovePlayerItem( client, ent );

	//ent = GetPlayerWeaponSlot( client, int:SlotKnife );
	//if( ent != -1 ) RemovePlayerItem( client, ent );


	for( new i = 0; i < 3; i++ ) {
		ent = GetPlayerWeaponSlot( client, int:SlotGrenade );
		if( ent != -1 ) 
			RemovePlayerItem( client, ent );
		else
			break;
	}

	ent = PlayerHasTaser( client );
	if( ent != 0 ) {
		RemovePlayerItem( client, ent );
	}


	EquipPlayerWeapon( client, GetPlayerWeaponSlot( client, int:SlotKnife ) );

	if( StrEqual( item, "weapon_knife" ) ) {
		
		return; // dont give player a knife
	}

	ent = GivePlayerItem( client, item );
	
	//if( ent != -1 ) {
		
		//CreateTimer( 0.5, testtimer, client );
		//SetEntProp( ent, Prop_Send, "m_iClip1", 50 );
		//SetEntProp( ent, Prop_Send, "m_iClip2", 50 );
		//SetEntData( ent, WEAPON_AMMO_BACKPACK, 50 );
		//new Handle:data;
		//CreateDataTimer( 0.5, EquipPlayerDelayed, data );
		//EquipPlayerWeapon( client, ent );
		//WritePackCell( data, GetClientUserId(client) );
		//WritePackCell( data, ent );
	//}
	//ent = GetPlayerWeaponSlot( client, int:SlotKnife );
	//if( ent != -1 ) {
	//	EquipPlayerWeapon( client, ent );
	//}
	
}
/*
public Action:EquipPlayerDelayed( Handle:timer, any:data ) {
	// todo never, this is actually some unsafe shit going on in here

	if( !special_round_active ) return Plugin_Handled;
	
	ResetPack(data);
	new client = GetClientOfUserId(ReadPackCell(data));
	if( client <= 0 ) return Plugin_Handled;
	new ent = ReadPackCell(data);
	
	EquipPlayerWeapon( client, ent );

	return Plugin_Handled;
}
*/

//----------------------------------------------------------------------------------------------------------------------
public Action:testtimer(Handle:timer, any:data) {
	for( new i = 0; i < 32; i++ )
			SetEntProp( data, Prop_Send, "m_iAmmo", 50, 4, i);
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_test( client, args ) {
	//SetEntityMoveType(client, MOVETYPE_NONE);
	//new Float:vec[3];
	//SetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]", 0.0 );
	///SetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]", 0.0 );
	//SetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]", 0.0 );
	SetDuelRound();

	//SetEntityFlags( client, GetEntityFlags(client) | FL_FROZEN );
	//ForcePlayerKnife(client);
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	if( !special_round_active ) return Plugin_Continue;

	// disable crouching for duel
	if( special_round_type == RTYPE_DUEL ) {
		buttons &= ~IN_DUCK;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
//
// block weapon acquiring 
//
public Action:Restrict_OnCanBuyWeapon(client, team, WeaponID:id, &CanBuyResult:result) {
	if( special_round_active ) return Plugin_Handled;
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Restrict_OnCanPickupWeapon(client, team, WeaponID:id, &bool:result) {
	if( special_round_active ) {
		if( id == WEAPON_DEAGLE && special_round_type == RTYPE_DUEL ) return Plugin_Continue;
		if( id == WEAPON_TASER && special_round_type == RTYPE_TASER ) return Plugin_Continue;
		if( id == WEAPON_HEGRENADE && special_round_type == RTYPE_NADES ) return Plugin_Continue;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
