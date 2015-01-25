 
#include <sourcemod>
#include <sdktools>
#include <monoculus>
#include <rxgstore>
#include <tf2>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "time warp item",
	author = "Roker",
	description = "time warp item to slow down time",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
#define ITEM_NAME "time_warp"
#define ITEM_FULLNAME "time_warp"
#define ITEMID 12

new bool:time_warped = false;
new Float:c_timewarp_timescale;
new Float:c_timewarp_cooldown;

new Float:g_lastwarp;

new Handle:host_timescale;
new Handle:sm_timewarp_timescale;
new Handle:sm_timewarp_cooldown;

new Float:current_timescale;

//-----------------------------------------------------------------------------
public OnPluginStart() {

	host_timescale = FindConVar("host_timescale");
	current_timescale = 1.0;
	
	RegAdminCmd( "sm_warptime", Command_warpTime, ADMFLAG_RCON );
	sm_timewarp_timescale = CreateConVar( "sm_timewarp_timescale", "0.5", "The speed time goes when slowed with timewarp.", FCVAR_PLUGIN );
	sm_timewarp_cooldown = CreateConVar( "sm_timewarp_cooldown", "180", "The serverwide cooldown for the timewarp item.", FCVAR_PLUGIN );
	
	HookConVarChange( sm_timewarp_timescale, OnConVarChanged );
	HookConVarChange( sm_timewarp_cooldown, OnConVarChanged );
	RecacheConvars();
}

//-----------------------------------------------------------------------------
RecacheConvars() {
	c_timewarp_timescale = GetConVarFloat( sm_timewarp_timescale );
	c_timewarp_cooldown = GetConVarFloat( sm_timewarp_cooldown );
}

//-----------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
fakeCheats( client, bool:on_off ){
	SendConVarValue( client, FindConVar("sv_cheats"), on_off ? "1" : "0" );
}

//-----------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-----------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	SetConVarFloat(host_timescale, 1.0);
	g_lastwarp = -c_timewarp_cooldown;
	PrecacheSound( "ui/halloween_loot_spawn.wav", true );
	PrecacheSound( "ui/halloween_loot_found.wav", true );
}

//-----------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	return(warpTime(client));
}

//-----------------------------------------------------------------------------
public Action:Command_warpTime( client, args ) {
	warpTime(client);
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
bool:warpTime(client) {

	if( time_warped ) {
		PrintToChat(client,"\x07FFD800Time is already warped!");
		return false;
	}
	
	new Float:time = GetGameTime();
	if( time < g_lastwarp + c_timewarp_cooldown ) {
		PrintToChat( client, "\x07FFD800Time has recently been warped. Please try again in \x073EFF3E%d \x07FFD800seconds.", RoundToCeil(g_lastwarp + c_timewarp_cooldown - time) );
		return false;
	}
	
	g_lastwarp = time;
	EmitSoundToAll( "ui/halloween_loot_spawn.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	new TFTeam:client_team = TFTeam:GetClientTeam(client);
	
	decl String:name[32];
	GetClientName( client, name, sizeof name );
	
	decl String:team_color[7];
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
	} else if( client_team == TFTeam_Blue ){
		team_color = "84d8f4";
	} else {
		team_color = "874fad";
	}
	
	PrintToChatAll( "\x07%s%s \x07FFD800has warped time!", team_color, name );
	time_warped = true;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) ) {
			fakeCheats( i, true );
		}
	}
	
	CreateTimer( 0.1, Timer_warpTimeInc, _, TIMER_REPEAT );
	CreateTimer( 10.0, Timer_unWarpTime );
	return true;
}

//-----------------------------------------------------------------------------
public Action:Timer_warpTimeInc( Handle:timer ) {

	current_timescale -= 0.03;
	
	SetConVarFloat(host_timescale, current_timescale);
	if(current_timescale > c_timewarp_timescale){
		return Plugin_Continue;
	}
	
	SetConVarFloat(host_timescale, 0.5);
	return Plugin_Stop;
}

//-----------------------------------------------------------------------------
public Action:Timer_unWarpTime( Handle:timer ) {
	EmitSoundToAll( "ui/halloween_loot_found.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	PrintToChatAll( "\x07FFD800The time warp has ended!");
	CreateTimer( 0.1, Timer_unWarpTimeInc, _, TIMER_REPEAT );
}

//-----------------------------------------------------------------------------
public Action:Timer_unWarpTimeInc( Handle:timer ) {

	current_timescale += 0.03;
	SetConVarFloat( host_timescale, current_timescale );
	
	if( current_timescale < 1.0 ) {
		return Plugin_Continue;
	}
	
	SetConVarFloat(host_timescale, 1.0);
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) ) {
			fakeCheats(i,false);
		}
	}
	
	time_warped = false;
	return Plugin_Stop;
}