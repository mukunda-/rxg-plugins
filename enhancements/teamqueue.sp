
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <updater>
#include <donations>


#pragma semicolon 1

#define UPDATE_URL "http://www.mukunda.com/plagins/teamqueue/update.txt"

// 11:40 PM 10/15/2013
// autoselect fix
// 1.0.3 10:15 AM 10/15/2013
//  updater
// 1.0.2 11:38 AM 10/8/2013
//  fixed limitteams bug

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "teamqueue",
	author = "mukunda",
	description = "Waiting queue to join teams",
	version = "1.0.4",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------

new Handle:tq_maxplayers; // max players allowed on a team 
new Handle:tq_grace_time; // time to join a team and be respawned
new Handle:tq_vips; // allow vips to cut the line
new Handle:mp_limitteams;

new c_maxplayers; 
new Float:c_grace_time;
new c_limitteams;
new bool:c_vips;

new Float:round_start_time;

// array of user IDs wanting to join a team
new Handle:queue[2]; // ct, t

new is_client_queued[MAXPLAYERS+1];

new bool:use_donations;

new String:team_names[][] = { "\x02<error lol>", "\x01Spectators", "\x09Terrorist", "\x0BCounter-Terrorist" };

new bool:player_spawned_this_round[MAXPLAYERS+1];

new Float:next_teamchange_time[MAXPLAYERS+1];

new playercount[2];

CountPlayers() {
	playercount[0] = GetTeamClientCount(2);
	playercount[1] = GetTeamClientCount(3);
}

#define ERROR_SOUND "ui/weapon_cant_buy.wav"

//----------------------------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	if( convar == tq_maxplayers ) {
		c_maxplayers = StringToInt( newValue );
	} else if( convar == tq_grace_time ) {
		c_grace_time = StringToFloat( newValue );
	} else if( convar == mp_limitteams ) {
		c_limitteams = StringToInt( newValue );
	} else if( convar == tq_vips ) {
		c_vips = !!StringToInt( newValue );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	tq_maxplayers = CreateConVar( "tq_maxplayers", "15", "Maximum players normally allowed on a team.", FCVAR_PLUGIN );
	HookConVarChange( tq_maxplayers, OnConVarChanged );
	c_maxplayers = GetConVarInt( tq_maxplayers );
	
	tq_grace_time = CreateConVar( "tq_grace_time", "20.0", "Time after round start where players can respawn when changing a team.", FCVAR_PLUGIN );
	HookConVarChange( tq_grace_time, OnConVarChanged );
	c_grace_time = GetConVarFloat( tq_grace_time );
	
	mp_limitteams = FindConVar( "mp_limitteams" );
	HookConVarChange( mp_limitteams, OnConVarChanged );
	c_limitteams = GetConVarInt( mp_limitteams );
	
	tq_vips = CreateConVar( "tq_vips", "0", "Allow VIPs to cut the line.", FCVAR_PLUGIN );
	HookConVarChange( tq_vips, OnConVarChanged );
	c_vips = GetConVarBool( tq_vips );
	
	for( new i = 0; i < 2; i++ )
		queue[i] = CreateArray();
		
	RegConsoleCmd( "jointeam", Command_jointeam );
	
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	
	if( LibraryExists("donations") ) {
		use_donations = true;
	}

	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}


public Action:Event_PlayerTeam( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	SetEventBroadcast(event, true);
	return Plugin_Continue;
}
 
//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	round_start_time = 0.0;
	PrecacheSound( ERROR_SOUND );
}

//----------------------------------------------------------------------------------------------------------------------
public OnLibraryAdded(const String:name[]) {
	if( StrEqual( name, "donations" ) ) use_donations = true;
	
	if( StrEqual( name, "updater" ) ) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnLibraryRemoved(const String:name[]) {
	if( StrEqual( name, "donations" ) ) use_donations = false;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_jointeam( client, args ) {
	if( GetGameTime() < next_teamchange_time[client] ) {
		//EmitSoundToClient( client, ERROR_SOUND );
		//PrintToChat( client, "You can't change teams for %d more seconds.", RoundToCeil( next_teamchange_time[client] - GetGameTime() ) );
		return Plugin_Handled;
		
	}
	next_teamchange_time[client] = GetGameTime() + 0.25;
	//ChangeClientTeam(client,0);
//	ChangeClientTeam(client,1);
	
//	return Plugin_Handled;
	
	decl String:arg[32];
	GetCmdArg( 1, arg, sizeof arg );
	
  
	new team;
	if( arg[0] == '1' || CharToLower( arg[0] ) == 's' ) {
		team = 1;
	} else if( arg[0] == '2' || CharToLower( arg[0] ) == 'c' ) {
		team = 2;
	} else if( arg[0] == '3' || CharToLower( arg[0] ) == 't' ) {
		team = 3;
	} else if( arg[0] == '0' || CharToLower( arg[0] ) == 'a' ) {
		team = 0;
	} else {
		return Plugin_Handled; // invalid jointeam command
	}
	
	
	CountPlayers();
	if( team == 0 ) {
		if( playercount[1] < playercount[0] ) {
			team = 3;
		} else{
			team = 2;
		}
	}
	
	// todo: auto select
	
	if( team == 1 ) {
		if( is_client_queued[client] ) {
		//	PrintToChat( client, "\x01 \x04You have left the team queue." );
			RemoveFromQueue(client);
		}
		return Plugin_Continue;
	} else if( team >= 2 ) {
		CheckQueue(team-2);
		if( is_client_queued[client] == team ) {
			// reply : already in queue
			PrintToChat( client, "\x01 \x04You are already queued to join %s\x04.", team_names[team] );
			
			if( GetClientTeam(client) == 1 ) ChangeClientTeam( client, 0 );
			ChangeClientTeam( client, 1 );
			return Plugin_Handled;
		}
		
		if( GetClientTeam( client ) == team ) return Plugin_Continue;
		 
		
		RemoveFromQueue(client);
		
		
		if( use_donations && c_vips ) {
			if( Donations_GetClientLevel( client ) ) { 
				if( CanJoinTeam( team, false ) ) {
				
					/*
					
		*/
		
					ClientJoinTeam( client, team );
					 
					return Plugin_Handled;
				} else {
					EmitSoundToClient( client, ERROR_SOUND );
					return Plugin_Handled;
				}
			}
		}
		
		if( CanJoinTeam( team ) && GetArraySize( queue[team-2] ) ==0 ) {
			ClientJoinTeam( client, team );
			
			
		} else {
			if( !CanJoinTeam( team, false ) ) { // check for imbalance and use default handler
				EmitSoundToClient( client, ERROR_SOUND );
				return Plugin_Handled;
			}
			if( GetClientTeam(client) > 1 ) {
				ForcePlayerSuicide(client);
			}
			if( GetClientTeam(client) == 1 ) ChangeClientTeam( client, 0 );
			ChangeClientTeam( client, 1 );
			AddToQueue( client, team );
		}
	}
	
	return Plugin_Handled;
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	is_client_queued[client] = 0;
	player_spawned_this_round[client] = false;
	next_teamchange_time[client] = 0.0;
	
}

//----------------------------------------------------------------------------------------------------------------------
CheckQueue( team ) {
	
	new added = 0;
	///for( new team = 0; team < 2; team++ ) {
	
	while( GetArraySize( queue[team] ) ) {
		if( playercount[team] >= c_maxplayers ) break;
		if( (playercount[team] - playercount[1-team]) >= c_limitteams ) break;
		
		new userid = GetArrayCell( queue[team], 0 );
		RemoveFromArray( queue[team], 0 );
		
		new client = GetClientOfUserId( userid );
		if( client == 0 ) continue;
		
		if( !is_client_queued[client] ) continue; // should print error if this passes
		
		added++;
		playercount[team]++;
		ClientJoinTeam( client, team+2 );
	}
		
	//}
	return added;
}

//----------------------------------------------------------------------------------------------------------------------
ClientJoinTeam( client, team ) {
	ChangeClientTeam( client, team );
	is_client_queued[client] = 0;
	
	PrintToChatAll( "\x01%N has joined %s\x01.", client, team_names[team] );
	
	if( !player_spawned_this_round[client] && (GetGameTime() - round_start_time) < c_grace_time ) {
		RespawnDelayed(client);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	round_start_time = GetGameTime();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) break;
		if( GetClientTeam(i) < 2 ) {
			player_spawned_this_round[i] = false;
		} else {
			player_spawned_this_round[i] = true;
		}
	}
	
	CountPlayers();
	
	while( CheckQueue( 0 ) || CheckQueue( 1 ) ) {
		
	}
	
	for( new team = 0; team < 2; team++ ) {
		
		new size = GetArraySize( queue[team] );
		new pos = 1;
		for( new i = 0; i < size; i++ ) {
			new client = GetClientOfUserId( GetArrayCell( queue[team], i ) );
			if( client == 0 ) continue;
			if( !is_client_queued[client] ) continue;
			PrintToChat( client, "\x01 \x04You are queued (%d) to join %s\x04.", pos, team_names[team+2] );
			pos++;
		}
		
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( client == 0 ) return;
	
	player_spawned_this_round[client] = true;
}

//----------------------------------------------------------------------------------------------------------------------
RemoveFromQueue( client ) {
	if( !is_client_queued[client] ) return;
	PrintToChat( client, "\x01 \x04You have left the %s\x04 queue.", team_names[is_client_queued[client]] );
	
	new team = is_client_queued[client] - 2;
	is_client_queued[client] = 0;
	
	new userid = GetClientUserId( client );
	
	new size = GetArraySize( queue[team] );
	for( new i = 0; i < size; i++ ) {
		if( GetArrayCell( queue[team], i ) == userid ) {
			RemoveFromArray( queue[team], i );
			break;
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
AddToQueue( client, team  ) {
	if( is_client_queued[client] ) return;
	
	is_client_queued[client] = team;
	
	PushArrayCell( queue[team-2], GetClientUserId( client ) );
	PrintToChat( client, "\x01 \x04You have been queued to join %s\x04.", team_names[team] );
}

//----------------------------------------------------------------------------------------------------------------------
bool:CanJoinTeam( team, bool:limit=true ) {
	
	team -= 2;
	
	if( limit) if( playercount[team] >= c_maxplayers ) return false;
	if( (playercount[team] - playercount[1-team]) >= c_limitteams ) return false;
	
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:RespawnDelayedTimer( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return Plugin_Handled;
	if( player_spawned_this_round[client] ) return Plugin_Handled;
	player_spawned_this_round[client] = true;
	if( IsPlayerAlive(client) ) return Plugin_Handled;
	CS_RespawnPlayer( client );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
RespawnDelayed( client ) {
	CreateTimer(0.5, RespawnDelayedTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );
}
