#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <gungame>
#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Decoy Level",
    author      = "mukunda",
    description = "feel the burn",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

new Handle:gg_decoylevel_cooldown;
new Float:c_decoylevel_cooldown;

//-------------------------------------------------------------------------------------------------
enum {
	AMMO_INDEX_HE=13,
	AMMO_INDEX_FLASH,
	AMMO_INDEX_SMOKE,
	AMMO_INDEX_FIRE,
	AMMO_INDEX_DECOY
};

CacheConVars() {
	c_decoylevel_cooldown = GetConVarFloat( gg_decoylevel_cooldown );
}

public OnConVarChanged( Handle:cvar, const String:ov[], const String:nv[] ) {
	CacheConVars();
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	gg_decoylevel_cooldown = CreateConVar( "gg_decoylevel_cooldown", "0.0", "time before giving players another decoy (-1 = disable)", FCVAR_PLUGIN );
	HookConVarChange( gg_decoylevel_cooldown, OnConVarChanged );
	CacheConVars();
	
	HookEvent( "decoy_started", OnDecoyStarted ); 
	//HookEvent( "player_hurt", OnPlayerHurt ); 
	
	HookPlayers();
}

//-------------------------------------------------------------------------------------------------
HookPlayer( client ) {
	SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
}

//-------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	HookPlayer( client );
}

//-------------------------------------------------------------------------------------------------
HookPlayers() {
	for (new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) HookPlayer(i);
	}
}

//-------------------------------------------------------------------------------------------------
public Action:GiveAnotherDecoy( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( client < 1 ) return Plugin_Handled;
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	
	new level = GG_GetClientLevel( client );
	new String:weapon[64];
	GG_GetLevelWeaponName( level, weapon, sizeof weapon );
	
	if( !StrEqual( weapon, "decoy" ) ) return Plugin_Handled; // player isn't on decoy level
	if( GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_DECOY ) > 0 ) return Plugin_Handled; // player has a decoy already
	GivePlayerItem( client, "weapon_decoy" );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnDecoyStarted( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event ,"userid" ) );
	new ent = GetEventInt( event, "entityid" );
	AcceptEntityInput( ent, "kill" );
	if( client == 0 ) return;
	
	new level = GG_GetClientLevel( client );
	new String:weapon[64];
	 
	GG_GetLevelWeaponName( level, weapon, sizeof weapon );
	
	if( StrEqual( weapon, "decoy" ) ) {
		if( c_decoylevel_cooldown < 0.0 ) return;
		if( c_decoylevel_cooldown == 0.0 ) {
			GiveAnotherDecoy( INVALID_HANDLE, GetClientUserId( client ) );
		} else {
			CreateTimer( c_decoylevel_cooldown, GiveAnotherDecoy, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3]) {

	if( inflictor > 0 ) {
	
		decl String:test[64];
		GetEntityClassname( inflictor, test,sizeof test );
		if( StrEqual( test, "decoy_projectile" ) ) {
			damage = 500.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
