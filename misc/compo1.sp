
#include <sourcemod>
#include <rxgcompo>
#include <sdkhooks>
#include <smac_hax>
#include <duel>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name        = "revocomp scoring",
	author      = "mukunda",
	description = "revocomp scoring",
	version     = "1.0.3",
	url         = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new kill_streaks[MAXPLAYERS+1];

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

//----------------------------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( round_end || warmup ) return;
	new attacker = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new assist = GetClientOfUserId( GetEventInt( event, "assister" ) );
	if( IsFakeClient(victim) ) return;
	if( victim == attacker ) {
		COMPO_AddPoints( attacker, 15, "{points} for suicide!" );
	}
	if( attacker == 0 ) return;
	
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
		COMPO_AddPoints( attacker, 100, "{points} for 4-kill streak." );
	} else if( kill_streaks[attacker] == 5 ) {
		new points = players >= 12 ? 120 : 100;
		COMPO_AddPoints( attacker, points, "{points} for 5-kill streak." );
	} else if( kill_streaks[attacker] == 6 ) {
		new points = players >= 12 ? 140 : 100;
		COMPO_AddPoints( attacker, points, "{points} for 6-kill streak." );
	} else if( kill_streaks[attacker] == 7 ) {
		new points = players >= 12 ? 200 : 100;
		COMPO_AddPoints( attacker, points, "{points} for 7-kill streak." );
	} else if( kill_streaks[attacker] == 8 ) {
		new points = players >= 12 ? 250 : 100;
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
	new bonus = (COMPO_GetRoundPlayers() - 6) * 30 / 8;
	if( bonus < 0 ) bonus = 0;
	if( bonus > 30 ) bonus = 30;
	bonus = 30-bonus;
	new playing_points = 20 + bonus;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetClientTeam(i) >= 2 ) {
			 
			
			COMPO_AddPoints( i, playing_points, "{points} for playing."  );
		} else {
			COMPO_AddPoints( i, 5, "{points} for spectating."  );
		}
	}
}
/*
//----------------------------------------------------------------------------------------------------------------------
public OnEntityCreated(entity, const String:classname[]) {
	if( StrEqual( classname, "chicken" ) ) {
		PrintToChatAll(" DEBUG, hooked chicken" );
		SDKHook( entity, SDKHook_OnTakeDamage, OnHurtChicken );
	}
} 

//----------------------------------------------------------------------------------------------------------------------
public Action:OnHurtChicken(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	PrintToChatAll(" DEBUG, onhurt chicken %d", attacker );
	if( damage <= 0.0 ) return Plugin_Continue;
	if( attacker < 1 || attacker > MaxClients ) return Plugin_Continue;
	COMPO_AddPoints( attacker, 20, "{points} for killing a chicken." );
	return Plugin_Continue;
}
*/
//----------------------------------------------------------------------------------------------------------------------
public OnHaxBan( client, victim ) {
	COMPO_AddPoints( client, 700, "{points} for banning a cheater." );
}

public OnDuelEnd( winner, loser ) {
	if( COMPO_GetRoundPlayers() >= 12 ) {
		COMPO_AddPoints( winner, 400, "{points} for winning a duel." );
	}
}
