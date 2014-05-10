
/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>


// changes:
// v1.0.1
//   messages when afkchecks go through or not
//   bug with forced afkcheck
//   only print afklist with people over THRESHOLD

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "afk list (tf2 edition)",
	author = "REFLEX-GAMERS",
	description = "afk manager",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
new afk_time[MAXPLAYERS+1];					// total time a player hasn't moved (including spectating/dead)
new afk_alive_time[MAXPLAYERS+1];			// total time a player hasn't moved while alive
new Float:old_position[MAXPLAYERS+1][2];	// 

new bool:afkcheck_active[MAXPLAYERS+1];		// if a panel is active for a client and they haven't move
new afkcheck_forced[MAXPLAYERS+1];			// client index of who caused an afkcheck

new Handle:sm_afklist_autokick;				// enable moving and kicking players
new Handle:sm_afklist_minplayers;			// minimum players required for autokick to function
new Handle:sm_afklist_maxplayers;			// number of players required for kicks to happen

new clients_playing;	// team 2,3
new clients_spectating;	// team 1
new clients_idling;		// team 0
new clients_notingame;	// <not in game>
new clients_total;

new makeroom_timer = 0;

new client_to_kick;		// next client to kick

new Handle:afkcheck_panel = INVALID_HANDLE;

// TODO, VERIFY THAT ALL OF THESE ARE CHECKED WITH SECONDS MULTIPLIER!
#define TIME_SPECTATOR_MINKICK	300	// 5 minutes	// time a player can sit in spectate before he is targetted by a 'makeroom' kick
#define TIME_ISSUE_AFKCHECK		180	// 3 minutes	// time a player can sit in game before he is issued an afkcheck
#define TIME_AFKCHECK_TIMEOUT	20	// 30 seconds	//
#define TIME_AFKLIST_SHOW		30

#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLU 3

#define ACTION_AUTO 0
#define ACTION_KICK 1
#define ACTION_MOVE 2

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	CreateAFKCheckPanel();

	sm_afklist_autokick = CreateConVar( "sm_afklist_autokick", "0", "enable autokick system", FCVAR_PLUGIN );
	sm_afklist_maxplayers = CreateConVar( "sm_afklist_maxplayers", "24", "number of players required for kicks to happen", FCVAR_PLUGIN );
	sm_afklist_minplayers = CreateConVar( "sm_afklist_minplayers", "8", "number of players required for moving to happen", FCVAR_PLUGIN );

	HookEvent( "player_spawn", Event_PlayerSpawn );

	// reset afk status if player performs these commands
	HookEvent( "player_say", Event_PlayerSay );
	HookEvent( "player_team", Event_PlayerTeam );

	RegConsoleCmd( "afklist", Command_afklist );
	RegAdminCmd( "afkcheck", Command_afkcheck, ADMFLAG_KICK );

	RegServerCmd( "afklist_test", Command_afklist_test );
	
	CreateTimer( 5.0, AfkTimer, _, TIMER_REPEAT );
}

//----------------------------------------------------------------------------------------------------------------------
CreateAFKCheckPanel() {
	afkcheck_panel = CreatePanel();
	SetPanelTitle( afkcheck_panel, "Are you there?" );
	DrawPanelItem( afkcheck_panel, "Yes" );
}

//----------------------------------------------------------------------------------------------------------------------
MakeRoom() {
	if( GetConVarBool( sm_afklist_autokick ) == false ) return; // autokick disabled
	 

	//if( player_kicked_this_round ) return;
	ScanClients();
	 
	 
	if( clients_total < GetConVarInt( sm_afklist_minplayers ) ) return; // autokick disabled (minimum players)
	 
	
	// if server is full:
	if( clients_total >= GetConVarInt( sm_afklist_maxplayers ) ) {
		 
		
		// kick a spectator
		if( client_to_kick != 0 ) { 
 
			AFKCheck( client_to_kick, ACTION_KICK );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// update # of spectators and out-of-game players, also search for best client to kick
//
ScanClients() {
	clients_notingame = 0;
	clients_idling = 0;
	clients_spectating = 0;
	clients_playing = 0;

	new besttime = 0;

	client_to_kick = 0;
	for( new i = 1; i <= MaxClients; i++ ) {	
		if( IsClientConnected(i) ) {
			if( IsFakeClient(i) ) continue;

			if( IsClientInGame(i) ) {
				new team = GetClientTeam(i);
				if( team >= 2 ) {	
					clients_playing++;
				} else if( team == 1 ) {
					if( afk_time[i] > besttime ) {
						besttime = afk_time[i];
						client_to_kick = i;
					}
					clients_spectating++;
				} else if( team == 0 ) {
					if( afk_time[i] > besttime ) {
						besttime = afk_time[i];
						client_to_kick = i;
					}
					clients_idling++;
				}
			} else {
				clients_notingame++;

				if( afk_time[i] > besttime ) {
					besttime = afk_time[i];
					client_to_kick = i;
				}
			}

		}
	}

	if( besttime*5 < TIME_SPECTATOR_MINKICK ) {
		client_to_kick = 0;
	}

	clients_total = clients_notingame + clients_idling + clients_spectating + clients_playing;
}

//----------------------------------------------------------------------------------------------------------------------
WasClientAFK( MenuAction:action, param2 ) {
	
	if( action == MenuAction_Cancel ) {
		if( param2 == MenuCancel_Timeout ) {
			
			return true;
		}
	}
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public AFKCheck_Handler_Kick(Handle:menu, MenuAction:action, param1, param2) {
	new client = param1;
	if( !afkcheck_active[client] ) return; // player came back with menu open
	afkcheck_active[client] = false;

	new tellclient = afkcheck_forced[client];
	if( tellclient > 0 ) tellclient = GetClientOfUserId( tellclient );

	new bool:hasname;
	decl String:name[64];
	hasname = GetClientName( client, name, sizeof(name) );
	if( !hasname ) Format( name, 64, "<unknown name>" );

	if( WasClientAFK( action, param2 ) ) {
		KickClient( client, "Automated kick to make room" );
		if( tellclient > 0 ) {
			PrintToChat(client, "[SM] %s didn't respond to your check and was kicked.", name );
		}
	} else {
		ResetClientAFK( client );
		if( tellclient > 0 ) {
			PrintToChat(client, "[SM] %s responded to your afk check.", name );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public AFKCheck_Handler_Move(Handle:menu, MenuAction:action, param1, param2) {
	
	new client = param1;
	if( !afkcheck_active[client] ) return; // player came back with menu open
	afkcheck_active[client] = false;

	new tellclient = afkcheck_forced[client];
	if( tellclient > 0 ) tellclient = GetClientOfUserId( tellclient );
	
	new bool:hasname;
	decl String:name[64];
	hasname = GetClientName( client, name, sizeof(name) );
	if( !hasname ) Format( name, 64, "<unknown name>" );
	
	if( WasClientAFK( action, param2 ) ) {
		ChangeClientTeam( client, TEAM_SPEC );
		if( tellclient > 0 ) {
			PrintToChat(client, "[SM] %s didn't respond to your check and was moved.", name );
		}
	} else {
		ResetClientAFK( client );
		if( tellclient > 0 ) {
			PrintToChat(client, "[SM] %s responded to your afk check.", name );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
AFKCheck( client, action=0) {
	if( !(client > 0 && IsClientConnected(client) && IsClientInGame(client)) ) return false;
	
	if( afkcheck_active[client] ) return false; // menu is already open
	afkcheck_active[client] = true;

	if( action == ACTION_AUTO ) {
		new team = GetClientTeam(client);
		if( team >= 2 ) {
			action = ACTION_MOVE;
		} else {
			action = ACTION_KICK;
		}
	}

	if( action == ACTION_KICK ) {
		if( !SendPanelToClient( afkcheck_panel, client, AFKCheck_Handler_Kick, TIME_AFKCHECK_TIMEOUT ) ) {
			KickClient( client, "Automated kick to make room" );
			afkcheck_active[client] = false;
			
		}
	} else if( action == ACTION_MOVE ) {
		if( !SendPanelToClient( afkcheck_panel, client, AFKCheck_Handler_Move, TIME_AFKCHECK_TIMEOUT ) ) {
			ChangeClientTeam( client, TEAM_SPEC );
			afkcheck_active[client] = false;
		}
	} else {
		return false;
	}
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_afkcheck( client, args ) {	

	if( args < 1 ) {
		PrintToConsole( client, "afkcheck <player> - Sends a user an AFK check menu and moves or kicks them if they don't respond." );
		return Plugin_Handled;
	}

	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	decl String:arg[64];
	GetCmdArg( 1, arg, 64 );
	
	target_count = ProcessTargetString(
			arg,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml);

	if( target_count > 1 ) {
		PrintToConsole( client, "Ambiguous name!" );
	} else if( target_count == 1 ) {
		if( !AFKCheck( target_list[0], ACTION_AUTO ) ) {
			PrintToConsole( client, "Couldn't issue afkcheck (could already be active!)" );
		} else {
			afkcheck_forced[target_list[0]] = GetClientUserId(client);
			PrintToConsole( client, "Issued afkcheck!" );
		}

	} else {
		PrintToConsole( client, "Couldn't find player matching \"%s\"", arg );
	}
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_afklist( client, args ) {
	
	PrintToConsole( client, "AFK REPORT (c=%d):", client );

	new bool:hasname;
	decl String:name[64];
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientConnected(i) ) {

			if( afk_time[i]*5 > TIME_AFKLIST_SHOW ) {

				hasname = GetClientName( i, name, sizeof(name) );
				if( !hasname ) Format( name, 64, "<unknown name>" );

				if( !IsClientInGame(i) ) {
					PrintToConsole( client, "%s has been out of the game for %d seconds.", name, afk_time[i]*5 );
				} else {
					new team = GetClientTeam(i);
					if( team == TEAM_RED ) {
						PrintToConsole( client, "%s (RED) hasn't moved for %d seconds, or %d seconds while alive", name, afk_time[i]*5, afk_alive_time[i]*5 );
					} else if( team == TEAM_BLU ) {
						PrintToConsole( client, "%s (BLU) hasn't moved for %d seconds, or %d seconds while alive", name, afk_time[i]*5, afk_alive_time[i]*5 );
					} else if( team == TEAM_SPEC ) {
						PrintToConsole( client, "%s has been spectating for %d seconds", name, afk_time[i]*5 );
					} else if( team == 0 ) {
						PrintToConsole( client, "%s hasn't chosen a team and has been idle for %d seconds", name, afk_time[i]*5 );
					}
				}
			}
		}
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:AfkTimer(Handle:timer) {


	new maxc = GetMaxClients();
	for( new i = 1; i <= maxc; i++ ) {
		afk_time[i]++;
		if( IsClientConnected(i) && IsClientInGame(i) ) {
			if( IsPlayerAlive(i) ) {
				afk_alive_time[i]++;
				new Float:vec[3];
				GetClientAbsOrigin( i, vec );
				
				new Float:a, Float:b, Float:dist;
				a = vec[0] - old_position[i][0];
				b = vec[1] - old_position[i][1];
				dist = (a*a) + (b*b);
				if( dist > (25.0) ) {  // if player moves 5.0 units or more then reset his timer
					old_position[i][0] = vec[0];
					old_position[i][1] = vec[1];
					ResetClientAFK(i);	
				}
			}
			
			if( GetClientTeam(i) >= 2 ) {
				if( afk_time[i]*5 >= TIME_ISSUE_AFKCHECK ) {
					if( AFKCheck(i, ACTION_MOVE) ) {
						afkcheck_forced[i] = 0;
					}

				}
			}
			
			
		}
	}


	makeroom_timer++;
	if( makeroom_timer*5 >= 30 ) {
		makeroom_timer = 0;
		MakeRoom();
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
ResetClientAFK(client) {
	afk_time[client] = 0;
	afk_alive_time[client] = 0;
	afkcheck_active[client] = false;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerTeam( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	new team = GetEventInt( event, "team" );

	if( team >= 2 ) {
		if( client <= 0 ) return;
		if( IsClientConnected(client) && IsClientInGame(client) ) {
			ResetClientAFK(client);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( IsClientConnected(client) && IsClientInGame(client) ) {
		new Float:vec[3];

		GetClientAbsOrigin( client, vec );

		old_position[client][0] = vec[0];
		old_position[client][1] = vec[1];
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSay( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( client <= 0 ) return;
	if( IsClientConnected(client) && IsClientInGame(client) ) {
		ResetClientAFK(client);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	afk_time[client] = 0;
	afk_alive_time[client] = 0;
}

public Action:Command_afklist_test( args ) {
	/*
	PrintToServer( "running test function!" );
	AfkTimer(INVALID_HANDLE);
	return Plugin_Handled;
	*/
}