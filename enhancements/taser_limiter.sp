
#include <sourcemod>
#include <rxgcommon>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name        = "Taser Limiter",
	author      = "WhiteThunder",
	description = "Limits tasers you can buy per round",
	version     = "1.0.0",
	url         = "www.reflex-gamers.com"
};

// ----------------------------------------------------------------------------

// convar handles
Handle sm_taser_limit;

// cached convar values
int c_taser_limit;

// number of taser bought this round
int g_tasers_bought[MAXPLAYERS+1];

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	HookEvent( "round_start",      OnRoundStart );
	
	sm_taser_limit = CreateConVar( "sm_taser_limit", "0", "Taser buy limit per player per round. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	
	HookConVarChange( sm_taser_limit,               OnCVarChanged );
	CacheCVars();
}

//-----------------------------------------------------------------------------
void CacheCVars() {
	c_taser_limit                  = GetConVarInt( sm_taser_limit );
}

//-----------------------------------------------------------------------------
public void OnCVarChanged( Handle convar, const char[] oldValue, 
						   const char[] newValue ) {
	CacheCVars();
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool db ) {
	for( int i = 1; i <= MaxClients; i++ ) {
		g_tasers_bought[i] = 0;
	}
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer( int client ) {
	g_tasers_bought[client] = 0;
}

//-----------------------------------------------------------------------------
public Action CS_OnBuyCommand( int client, const char[] weapon ) {
	if( !IsValidClient( client )) return Plugin_Continue;
	
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	// get the weapon ID
	char real_name[64];
	CS_GetTranslatedWeaponAlias( weapon, real_name, sizeof real_name );

	CSWeaponID id = CS_AliasToWeaponID( real_name );
	
	// catch invalid weapon name.
	if( id == CSWeapon_NONE ) return Plugin_Continue;
	
	// limit tasers per round
	if( c_taser_limit > 0 && id == CSWeapon_TASER ) {
		if( g_tasers_bought[client] >= c_taser_limit ) {
			return Plugin_Handled;
		}
		g_tasers_bought[client]++;
	}
	
	return Plugin_Continue;
}
