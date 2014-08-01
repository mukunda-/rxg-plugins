#include <sourcemod>
#include <sdktools>
#include <cstrike>

// 1.0.1
//  beeper marks on radar.

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxgice",
	author = "mukunda",
	description = "rxg iceworld shit",
	version = "1.0.1",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new bool:g_respawned_this_round[MAXPLAYERS+1];
new Float:g_round_start_time;

new Float:c_bonuslife_time = 1.5;
new Float:c_beep_time = 6.0;
new Float:c_beep_repeat_time = 3.0;
new String:c_beep_sound[128] = "buttons/blip2.wav";

new Float:g_last_sound_time[MAXPLAYERS+1];
new bool:g_game_active;
new bool:g_round_end;

LoadConfig() {
	decl String:path[128];
	BuildPath( Path_SM, path, sizeof path, "configs/rxgice.cfg" );
	if( !FileExists( path ) ) return;
	new Handle:kv = CreateKeyValues( "rxgice" );
	if( !FileToKeyValues( kv, path ) ) {
		CloseHandle(kv);
		return;
	}
	
	c_bonuslife_time = KvGetFloat( kv, "bonus_life_time", c_bonuslife_time );
	c_beep_time = KvGetFloat( kv, "beep_time", c_beep_time );
	c_beep_repeat_time = KvGetFloat( kv, "beep_repeat_time", c_beep_repeat_time );
	
	// not sure if its safe to pass target to defvalue directly
	decl String:str[128];
	strcopy( str, sizeof str, c_beep_sound );
	KvGetString( kv, "beep_sound", c_beep_sound, sizeof c_beep_sound, str );
	
	CloseHandle(kv);
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	LoadConfig(); 
	
	AddNormalSoundHook( OnSound );
	
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	HookEvent( "round_end", OnRoundEnd, EventHookMode_PostNoCopy );
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "player_death", OnPlayerDeath );
	
	HookEvent( "weapon_fire", OnWeaponFire );
	
	CreateTimer( 1.0, OnSecond, _, TIMER_REPEAT );
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	OnRoundStart( INVALID_HANDLE, "", false );
	g_game_active = true;
	if( c_beep_sound[0] != 0 ) PrecacheSound( c_beep_sound );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapEnd() {
	g_game_active = false;
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		g_respawned_this_round[i] = false;
	}
	g_round_start_time = GetGameTime();
	g_round_end = false;
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	g_round_end = true;
}

//----------------------------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	g_last_sound_time[client] = GetGameTime() + 5.0;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:RespawnPlayerDelayed( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return Plugin_Handled;
	if( g_round_end ) return Plugin_Handled;
	CS_RespawnPlayer( client );
	PrintToChat( client, "\x01 \x04Try again!" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new attacker = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	if( client == 0 || attacker == 0 ) return;
	if( client == attacker ) return;
	if( g_respawned_this_round[client] ) return;
	if( (GetGameTime() - g_round_start_time) < c_bonuslife_time ) {
		g_respawned_this_round[client] = true;
		CreateTimer( 0.25, RespawnPlayerDelayed, GetClientUserId( client ) );
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnWeaponFire( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	g_last_sound_time[client] = GetGameTime();
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnSound( clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], 
						&entity, &channel, &Float:volume, &level, &pitch, &flags ) {
	
	//PrintToServer( "SOUND %d - %s %d", entity, sample, flags );
	if( entity >= 1 && entity <= MaxClients ) {
		if( strncmp( sample, "player/foot", 11 ) == 0 ) {
			 g_last_sound_time[entity] = GetGameTime();
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnSecond( Handle:timer ) {
	if( !g_game_active ) return Plugin_Continue;
	if( g_round_end ) return Plugin_Continue;
	
	if( c_beep_sound[0] != 0 && c_beep_time > 0.0 ) {
		new alive[2];
		for( new i = 1; i <= MaxClients; i++ ) {
			if( IsClientInGame(i) && IsPlayerAlive(i) ) {
				alive[ GetClientTeam(i)-2 ]++;
			}
		}
		
		if( alive[0] <= 2 && alive[1] <= 2 ) {
			new Float:time = GetGameTime();
			for( new i = 1; i <= MaxClients; i++ ) {
				if( IsClientInGame(i) && IsPlayerAlive(i) ) {
					if( (time-g_last_sound_time[i]) >= c_beep_time ) {
						EmitSoundToAll( c_beep_sound, i, _, SNDLEVEL_GUNFIRE );
						SetEntProp( i, Prop_Send, "m_bSpotted", 1 );
						
						if( c_beep_repeat_time > 0.0 ) {
							g_last_sound_time[i] = time - (c_beep_time - c_beep_repeat_time) ;
						}
						
					}
					
				}
			}
		}
	}
	
	return Plugin_Continue;
}
