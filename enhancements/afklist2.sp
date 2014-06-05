

#include <sourcemod>
#include <sdktools>

#include <idletracker>

#pragma semicolon 1

// CHANGELOG:
//

#define IDLE_THRESHOLD 60.0

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "afk list2",
	author = "REFLEX-GAMERS",
	description = "afk tracker v2",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};


new bool:idle_at_spawn_printed;

new Handle:sm_afklist_kickspec_threshold;
new Handle:sm_afklist_kickspec_time; 

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	sm_afklist_kick_threshold = CreateConVar( "sm_afklist_kickspec_threshold", "99", "Threshold of players in server to start kicking spectators" );
	sm_afklist_kickspec_time = CreateConVar( "sm_afklist_kickspec_time", "10.0", "Kick spectators after this many minutes of idling" ); 
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	HookEvent( "round_end", Event_RoundEnd, EventHookMode_PostNoCopy );
	HookEvent( "player_death", Event_PlayerDeath );
	
	RegConsoleCmd( "sm_afklist", Command_afklist );
}

//-------------------------------------------------------------------------------------------------
CheckSpawnAFK() {
	if( idle_at_spawn_printed ) return;
	new active_players[2];
	new inactive_players[2];
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		new team = GetClientTeam(i) - 2;
		if( team < 0 ) continue; // justin case
		
		if( IsClientIdleAtSpawn(i) && GetClientIdleTime(i) >= IDLE_THRESHOLD ) inactive_players[team]++;
		else active_players[team]++;
	}
	if( ((active_players[1]+inactive_players[1]) > 0) && active_players[1] == 0 ) {
		PrintToChatAll( "\x01 \x04[IDLE] The last CT%s AFK!", inactive_players[1] == 1 ? " is" : "s are" );
		PrintCenterTextAll( "The last CT%s AFK!", inactive_players[1] == 1 ? " is" : "s are" );
		idle_at_spawn_printed = true;
	} else if( ((active_players[0]+inactive_players[0]) > 0) && active_players[0] == 0 ) {
		PrintToChatAll( "\x01 \x04[IDLE] The last terrorist%s AFK!", inactive_players[0] == 1 ? " is" : "s are" );
		PrintCenterTextAll( "The last terrorist%s AFK!", inactive_players[0] == 1 ? " is" : "s are" );
		idle_at_spawn_printed = true;
	}
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	idle_at_spawn_printed = false;
}

//-------------------------------------------------------------------------------------------------
MoveAFKClients() {
	new threshold = GetConVarInt(sm_afklist_kick_threshold);
	new Float:time = GetConVarFloat(sm_afklist_kickspec_time) * 60.0;
	
	new players = GetClientCount();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetClientTeam(i) < 2 ) {
			// spectator
			if( players >= threshold ) {
				if( GetClientIdleTime(i) >= time ) {
					KickClient( i, "Automated kick to make room" );
					continue;
				}
			}
			
			
		}
		if( !IsPlayerAlive(i) ) continue;
		
		if( GetClientIdleTime(i) >= IDLE_THRESHOLD ) {
			ChangeClientTeam( i, 1 );
			PrintToChat( i, "\x01\x0B\x01[SM] \x04You were moved to spectators for being AFK." );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	MoveAFKClients();
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new client=GetClientOfUserId(GetEventInt(event,"userid"));
	if( !client ) return;
	if( GetClientIdleTime(client) >= IDLE_THRESHOLD ) {
		ChangeClientTeam( client, 1 );
		PrintToChat( client, "\x01\x0B\x01[SM] \x04You were moved to spectators for being AFK." );
	}
	CheckSpawnAFK();
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_afklist( client, args ) {
	
	PrintToConsole( client, "AFK REPORT:" );

	new bool:hasname;
	decl String:name[64];

	new bool:no_entries=true;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientConnected(i) ) continue;
		new Float:time = GetClientIdleTime(i);
		if( time < 300.0 ) continue;
		no_entries = false;
		hasname = GetClientName( i, name, sizeof(name) );
		if( !hasname ) Format( name, 64, "<unknown name>" );

			
		if( !IsClientInGame(i) ) {
			PrintToConsole( client, "%s has been out of the game for %.2f minutes.", name, time / 60.0 );
		} else {
			new team = GetClientTeam(i);
			if( team == 1 ) {
				PrintToConsole( client, "%s has been spectating for %.2f minutes.", name, time / 60.0 );
			} else if( team == 0 ) {
				PrintToConsole( client, "%s hasn't chosen a team and has been idle for %.2f minutes.", name, time / 60.0 );
			} else {
				PrintToConsole( client, "%s has been idle for %.2f minutes.", name, time / 60.0 );
			}
	
			
		}
	}
	
	if( no_entries ) {
		PrintToConsole( client, "Nobody has been AFK for more than 5 minutes." );
	}
	return Plugin_Handled;
}
