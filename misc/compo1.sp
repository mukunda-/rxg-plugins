
#include <sourcemod>
#include <rxgcompo>
#include <sdkhooks>
#include <smac_hax>
#include <duel>
#include <idletracker>

// 1.0.4
// fixed suicide extra credit

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name        = "revocomp scoring",
	author      = "mukunda",
	description = "revocomp scoring",
	version     = "1.1.0",
	url         = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new kill_streaks[MAXPLAYERS+1];

new Float:client_last_kill[MAXPLAYERS+1];

new bool:round_end;
new bool:warmup;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", OnPlayerDeath );
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "round_end", OnRoundEnd );
	
	HookEvent( "bomb_planted", OnBombPlant );
	HookEvent( "bomb_defused", OnBombDefused );
	
	CreateTimer( 60.0, OnMinute, _, TIMER_REPEAT );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	new Float:warmuptime = float(GetConVarInt( FindConVar( "mp_warmuptime" ) ));
	if( warmuptime != 0.0 ) {
		warmup = true;
		CreateTimer( warmuptime, WarmupEnded, _, TIMER_FLAG_NO_MAPCHANGE );
	} else {
		warmup = false;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:WarmupEnded( Handle:timer ) {
	warmup=false;
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		kill_streaks[i] = 0;
	}
	round_end = false;
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_end = true;
}

//----------------------------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	kill_streaks[client] = 0;
}

public OnClientPutInServer( client ) {
	client_last_kill[client] = -2000.0;
}

//----------------------------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( round_end || warmup ) return;
	new attacker = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new assist = GetClientOfUserId( GetEventInt( event, "assister" ) );
	
	if( victim == attacker ) {
		if( IsFakeClient(victim) ) return;
		if( (GetGameTime() - client_last_kill[victim]) < 600.0 ) {
			COMPO_AddPoints( victim, 15, "{points} for suicide!" );
			return;
		}
	}
	
	if( attacker == 0 ) return;
	client_last_kill[attacker] = GetGameTime();
	
	if( IsFakeClient(victim) ) return;
	
	new players = COMPO_GetRoundPlayers();
 
	new weap = 0;
	decl String:weapon[64];
	GetEventString( event, "weapon", weapon, sizeof weapon );
	if( (StrContains( weapon, "knife" ) != -1 || StrContains( weapon, "bayonet" ) != -1)   ) {
		weap = 1;
	} else if( StrEqual( weapon, "taser"   ) ) {
		weap = 2;
	} else if( StrEqual( weapon, "hegrenade"  ) ) {
		weap = 3;
	}
	
	//PrintToChatAll( "DEBUG KILL %s", weapon );
	
	if( weap == 0 || players < 12 ) { // always run this one if less than 12 players
		COMPO_AddPoints( attacker, 150, "{points} for killing a player." );
	} else if( weap == 1 ) {
		COMPO_AddPoints( attacker, 350, "{points} for knifing a player." );
	} else if( weap == 2 ) {
		COMPO_AddPoints( attacker, 250, "{points} for tasing a player." );
	} else if( weap == 3 ) {
		COMPO_AddPoints( attacker, 350, "{points} for nading a player." );
	}
	
	kill_streaks[attacker]++;
	if( kill_streaks[attacker] == 4 ) {
		COMPO_AddPoints( attacker, 50, "{points} for 4-kill streak." );
	} else if( kill_streaks[attacker] == 5 ) {
		new points = players >= 12 ? 75 : 50;
		COMPO_AddPoints( attacker, points, "{points} for 5-kill streak." );
	} else if( kill_streaks[attacker] == 6 ) {
		new points = players >= 12 ? 100 : 70;
		COMPO_AddPoints( attacker, points, "{points} for 6-kill streak." );
	} else if( kill_streaks[attacker] == 7 ) {
		new points = players >= 12 ? 150 : 80;
		COMPO_AddPoints( attacker, points, "{points} for 7-kill streak." );
	} else if( kill_streaks[attacker] == 8 ) {
		new points = players >= 12 ? 200 : 90;
		COMPO_AddPoints( attacker, points, "{points} for 8-kill streak." );
	} else if( kill_streaks[attacker] >= 9 ) {
		new points = players >= 12 ? 300 : 100;
		COMPO_AddPoints( attacker, points, "{points} for 9+ kill streak." );
	}
	
	if( assist != 0 ) {
		COMPO_AddPoints( assist, 50, "{points} for assisting a kill."  );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnBombPlant( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( round_end || warmup ) return;
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	COMPO_AddPoints( client, 200, "{points} for planting the bomb."  );
}

//----------------------------------------------------------------------------------------------------------------------
public OnBombDefused( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( round_end || warmup ) return;
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	COMPO_AddPoints( client, 200, "{points} for defusing the bomb."  );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnMinute( Handle:timer ) {
	new players =COMPO_GetRoundPlayers();
	
	new bonus;
	if( players >= 0 && players <= 3 ) {
		bonus = 150;
	} else if( players >= 4 && players <= 6 ) {
		bonus = 135;
	} else if( players >= 7 && players <= 12 ) {
		bonus = 100;
	} else {
		bonus = 85;
	}
	  
	new Float:time = GetGameTime();
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		if( GetClientTeam(i) >= 2 ) { 
			if( (time - client_last_kill[i]) < 600.0 && (GetClientIdleTime(i) < 30.0 || !IsPlayerAlive(i))  ) {
				COMPO_AddPoints( i, bonus, "{points} for playing.", ADDPOINTS_ALWAYS );
			}
		} else {
			COMPO_AddPoints( i, 10, "{points} for spectating.", ADDPOINTS_ALWAYS );
		}
	}
}
 
//----------------------------------------------------------------------------------------------------------------------
public OnHaxBan( client, victim ) {
	COMPO_AddPoints( client, 700, "{points} for banning a cheater." );
}

public OnDuelEnd( winner, loser ) {
	if( COMPO_GetRoundPlayers() >= 12 ) {
		COMPO_AddPoints( winner, 400, "{points} for winning a duel." );
	}
}
