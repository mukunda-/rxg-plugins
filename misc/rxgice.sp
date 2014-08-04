#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <cssdroppedammo>

// 1.0.1
//  beeper marks on radar.

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxgice",
	author = "mukunda",
	description = "rxg iceworld shit",
	version = "1.0.2",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new bool:g_respawned_this_round[MAXPLAYERS+1];
new Float:g_round_start_time;

new Float:c_bonuslife_time = 1.5;
new Float:c_beep_time = 6.0;
new Float:c_beep_repeat_time = 3.0;
new String:c_beep_sound[128] = "buttons/blip2.wav";

new Handle:rxgice_cash_per_kill;
new c_cash_per_kill;
new Handle:mp_maxmoney;
new c_maxmoney;

new Float:g_last_sound_time[MAXPLAYERS+1];
new bool:g_game_active;
new bool:g_round_end;

//----------------------------------------------------------------------------------------------------------------------
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
CacheConVars() {
	c_cash_per_kill = GetConVarInt( rxgice_cash_per_kill );
	c_maxmoney = GetConVarInt( mp_maxmoney );
}

//----------------------------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	CacheConVars();
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	rxgice_cash_per_kill = CreateConVar( "rxgice_cash_per_kill", "150", "Cash per kill, ignores weapon modifiers.", FCVAR_PLUGIN );
	HookConVarChange( rxgice_cash_per_kill, OnConVarChanged );
	mp_maxmoney = FindConVar( "mp_maxmoney" );
	HookConVarChange( mp_maxmoney, OnConVarChanged );
	CacheConVars();

	LoadConfig(); 
	
	AddNormalSoundHook( OnSound );
	
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	HookEvent( "round_end", OnRoundEnd, EventHookMode_PostNoCopy );
	HookEvent( "player_spawn", OnPlayerSpawn );
	HookEvent( "player_death", OnPlayerDeath );
	
	HookEvent( "weapon_fire", OnWeaponFire );
	
	CreateTimer( 1.0, OnSecond, _, TIMER_REPEAT );
	
	//RegConsoleCmd( "icetest", test );
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
	
	ProcessWeapons();
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
	
	if( c_cash_per_kill != 0 ) {
		new cash = GetEntProp( client, Prop_Send, "m_iAccount" );
		cash += c_cash_per_kill;
		if( cash > c_maxmoney ) cash = c_maxmoney;
		SetEntProp( client, Prop_Send, "m_iAccount", cash );
		PrintToChat( attacker, "\x01 \x06+$%d\x01: Award for neutralizing an enemy.", c_cash_per_kill );
	}
	
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


//--------------------------------------------------------------------------
public Action:CS_OnBuyCommand( client, const String:weapon[] ) {
	new CSWeaponID:id = CS_AliasToWeaponID( weapon );
	if( id == CSWeapon_SMOKEGRENADE ||
		id == CSWeapon_MOLOTOV ||
		id == CSWeapon_INCGRENADE || id == CSWeapon_FLASHBANG ) {

		// todo: make sound?
		PrintToChat( client, "\x01You are not allowed to purchase \"%s\".", weapon );
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

ProcessWeapons() {
	// todo.
	/*
	new ent = -1;
	for( ent = MaxClients+1; ent <= 2047; ent++ ) {
		if( IsValidEntity(ent) ){
			decl String:classname[64];
			GetEntityClassname( ent, classname, sizeof classname );
			if( strncmp( classname, "weapon_", 7 ) == 0 ) {
				new owner = GetEntPropEnt( ent, Prop_Send,"m_hOwner" );
				if( owner < 1 ) {
					PrintToServer(" Setting ammo for %s (%d)", classname, CS_GetDroppedWeaponAmmo(ent) );
					//PrintToServer(" VALUE2 (%d)", GetEntProp(ent, Prop_Data,"m_iPrimaryAmmoCount") );
					new start = FindSendPropInfo("CWeaponCSBase", "m_fAccuracyPenalty");
					for( new offset = 0; offset < 128; offset += 4 ) {
						//if( GetEntData( ent, start+offset ) == 200 ) {
							PrintToServer("Found ammo match, offset %d %d", offset, GetEntData(ent,start+offset) );
						//}
					}
					
					//CS_SetDroppedWeaponAmmo( ent, 0 );
				}
			}
		}
	}
	
	for( new i = 0; i < 32; i++ ) {
		PrintToServer( "Ammo %d = %d", i, GetEntProp( 2, Prop_Send, "m_iAmmo", _, i ) );
	}*/
}
/*
public Action:test(client,args ) {
	new ent = -1;
	for( ent = MaxClients+1; ent <= 2047; ent++ ) {
		if( IsValidEntity(ent) ){
			decl String:classname[64];
			GetEntityClassname( ent, classname, sizeof classname );
			if( strncmp( classname, "weapon_", 7 ) == 0 ) {
				new owner = GetEntPropEnt( ent, Prop_Send,"m_hOwner" );
				if( owner < 1 ) {
					SetEntityMoveType(ent,MOVETYPE_VPHYSICS);
					PrintToServer(" Setting ammo for %s (%d) %d +%d -%d", classname, 
						CS_GetDroppedWeaponAmmo(ent),
						GetEntProp( ent, Prop_Send, "m_bInitialized"),
						GetEntProp( ent, Prop_Send, "m_iClip1")	,
						GetEntPropFloat( ent, Prop_Data, "m_pConstraint" )
						);
					//PrintToServer(" VALUE2 (%d)", GetEntProp(ent, Prop_Data,"m_iPrimaryAmmoCount") );
					//new start =4;// FindSendPropInfo("CWeaponCSBase", "m_fAccuracyPenalty");
					//for( new offset = 0; offset < 2700; offset += 1 ) {
					//	if( GetEntData( ent, start+offset,1 ) == 200 ) {
					//		PrintToServer("Found ammo match, offset %d %d", offset, GetEntData(ent,start+offset) );
					//	}
					//}
					
					CS_SetDroppedWeaponAmmo( ent, 0 );
				}
			}
		}
	}
	
	for( new i = 0; i < 32; i++ ) {
		PrintToServer( "Ammo %d = %d", i, GetEntProp( 2, Prop_Send, "m_iAmmo", _, i ) );
	}
}*/
