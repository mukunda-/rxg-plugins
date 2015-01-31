#include <sourcemod>

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxgutils",
	author = "REFLEX",
	description = "Commonly used event utilities.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

new Handle:f_player_death = INVALID_HANDLE;
new Handle:f_player_spawn = INVALID_HANDLE;
new Handle:f_round_start  = INVALID_HANDLE;

new g_players_alive = 0;

enum {
	CSGO,
	TF2
};

new g_game = CSGO;

//-----------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, 
                              String:error[], err_max) {
	
	decl String:gamedir[PLATFORM_MAX_PATH];
	GetGameFolderName(gamedir, sizeof(gamedir));
	
	if( StrEqual( gamedir, "csgo" )) {
		g_game = CSGO;
	} else if( StrEqual( gamedir, "tf2" )) {
		g_game = TF2;
	}
	
	RegPluginLibrary( "rxgutils" );
	CreateNative( "RU_PlayersAlive", Native_PlayersAlive );
	return APLRes_Success;
}

//-----------------------------------------------------------------------------
public OnPluginStart() {
	f_player_death = CreateGlobalForward( "RU_PlayerDeath", 
			ET_Ignore, Param_Cell, Param_Cell );
	f_player_spawn = CreateGlobalForward( "RU_PlayerSpawn", 
			ET_Ignore, Param_Cell );
	f_round_start = CreateGlobalForward( "RU_RoundStart", ET_Ignore );
		 
	HookEvent( "player_death", OnPlayerDeath );
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "round_start", OnRoundStart );
}

//-----------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ));
	if( client == 0 ) return;
	new attacker = GetEventInt( event, "attacker" );
	if( attacker != 0 ) attacker = GetClientOfUserId( attacker );
	
	Call_StartForward( f_player_death );
	Call_PushCell( client );
	Call_PushCell( attacker );
	Call_Finish();
	
	g_players_alive--;
}

//-----------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ));
	if( client == 0 ) return;
	if( GetClientTeam(client) == 0 ) return; // not in game yet.
	
	Call_StartForward( f_player_spawn );
	Call_PushCell( client );
	Call_Finish();
	
	g_players_alive++;
}

//-----------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {

	g_players_alive = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		g_players_alive++;
	}
	
	Call_StartForward( f_round_start );
	Call_Finish();
}

//-----------------------------------------------------------------------------
public Native_PlayersAlive( Handle:plugin, args ) {
	return g_players_alive;
}
