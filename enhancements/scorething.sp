
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "scorething",
	author = "mukunda",
	description = "display players alive as scores",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new players_alive[4];
new scores[4];

new round_is_live = false;
new round_counter;

new bool:is_map_loaded;

public OnPluginStart() {
	HookEvent( "round_end", Event_RoundEnd );
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDeath );
//	HookEvent( "bot_takeover", Event_BotTakeover );
}

public OnMapStart() {
	scores[2] = 0;
	scores[3] = 0;
	is_map_loaded = true;
}

public OnMapEnd() {
	is_map_loaded = false;
}

ShowRealScore() {
	if( !is_map_loaded ) return;
	SetTeamScore( 2, scores[2] );
	SetTeamScore( 3, scores[3] );
}

ShowPlayersAlive() {
	if( !is_map_loaded ) return;
	SetTeamScore( 2, players_alive[2] );
	SetTeamScore( 3, players_alive[3] );
}

public Action:RoundEndDelayed( Handle:timer, any:thingy ) {
	if( thingy != round_counter ) return Plugin_Handled;
	ShowRealScore();
	round_is_live = false;


	return Plugin_Handled;
}

public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	ShowPlayersAlive();


	new CSRoundEndReason:reason = CSRoundEndReason:GetEventInt( event, "reason" );
	if( reason == CSRoundEnd_GameStart ) {
		scores[2] = 0;
		scores[3] = 0;
	} else if( reason == CSRoundEnd_Draw ) {
		// do nothing!
	} else {
		
		
			
		if( reason == CSRoundEnd_TargetBombed || reason == CSRoundEnd_VIPKilled || reason == CSRoundEnd_TerroristsEscaped || reason == CSRoundEnd_TerroristWin || reason == CSRoundEnd_HostagesNotRescued || reason == CSRoundEnd_VIPNotEscaped || reason == CSRoundEnd_CTSurrender ) {
			scores[2]++;
		} else if( reason == CSRoundEnd_VIPEscaped || reason == CSRoundEnd_CTStoppedEscape || reason == CSRoundEnd_TerroristsStopped || reason == CSRoundEnd_BombDefused || reason == CSRoundEnd_CTWin || reason == CSRoundEnd_HostagesRescued || reason == CSRoundEnd_TerroristsNotEscaped || reason == CSRoundEnd_TerroristsSurrender ) {
			scores[3]++;
		}
	}
	
	CreateTimer( 1.0, RoundEndDelayed, round_counter, TIMER_FLAG_NO_MAPCHANGE );	
}

ComputeAllPlayers() {
	players_alive[2] = 0;
	players_alive[3] = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		new team = GetClientTeam(i);
		if( team >= 2 && IsPlayerAlive(i) )
			players_alive[team]++;
	}
}

public Action:RoundStartDelayed( Handle:timer, any:data ) {
	if( round_counter != data ) return Plugin_Handled;
	ComputeAllPlayers();
	round_is_live = true;
	
	ShowPlayersAlive();
	return Plugin_Handled;
}

public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_counter++;
	CreateTimer( 3.0, RoundStartDelayed, round_counter, TIMER_FLAG_NO_MAPCHANGE );
	
}

public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !round_is_live ) return;
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( client == 0 ) return;
	players_alive[GetClientTeam(client)]--;
	ShowPlayersAlive();
}
/*
public Event_BotTakeover( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !round_is_live ) return;
	new client = GetClientOfUserId( GetEventInt(event, "botid") );
	if( client == 0 ) return;
	players_alive[GetClientTeam(client)]--;
	ShowPlayersAlive();
}*/

public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !round_is_live ) return;

	ComputeAllPlayers();
	ShowPlayersAlive();
}

public OnClientDisconnect_Post(client) {
	if( round_is_live ) {
		ComputeAllPlayers();
		ShowPlayersAlive();
	}

}