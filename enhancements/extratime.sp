#include <sourcemod> 
#include <sdktools>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "extratime",
	author = "mukunda",
	description = "extra time for CTs when terrorists throw shit",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Float:last_fire_time;
new Float:last_smoke_time;

new Handle:sm_extratime_molotov;
new Float:c_extratime_molotov;
new Handle:sm_extratime_smoke;
new Float:c_extratime_smoke;
new Handle:sm_extratime_wait;
new Float:c_extratime_wait;

new Float:round_start_time;

new bool:round_active;

#define TERRORIST 2

CacheConVars() {
	c_extratime_molotov = GetConVarFloat( sm_extratime_molotov );
	c_extratime_smoke = GetConVarFloat( sm_extratime_smoke );
	c_extratime_wait = GetConVarFloat( sm_extratime_wait );
}

//----------------------------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldval[], const String:newval[] ) {
	CacheConVars();
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "molotov_detonate", OnMolotovDetonate );
	HookEvent( "smokegrenade_detonate", OnSmokeDetonate );
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "round_end", OnRoundEnd );
	
	sm_extratime_molotov = CreateConVar( "sm_extratime_molotov", "2.0", "Seconds added to clock when a firebomb is used by T.", FCVAR_PLUGIN );
	sm_extratime_smoke = CreateConVar( "sm_extratime_smoke", "4.0", "Seconds added to clock when smoke is used by T.", FCVAR_PLUGIN );
	sm_extratime_wait = CreateConVar( "sm_extratime_wait", "20.0", "Seconds during start of round to ignore clock adjustments.", FCVAR_PLUGIN );
	HookConVarChange( sm_extratime_molotov, OnConVarChanged );
	HookConVarChange( sm_extratime_smoke, OnConVarChanged );
	HookConVarChange( sm_extratime_wait, OnConVarChanged );
	CacheConVars();
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() { 
	last_fire_time = 0.0;
	last_smoke_time = 0.0;
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_active = true;
	round_start_time = GetGameTime();
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_active = false;
}

//----------------------------------------------------------------------------------------------------------------------
AddRoundTime( Float:seconds ) {
	new Float:start = GameRules_GetPropFloat( "m_fRoundStartTime" );
	start += seconds;
	new Float:gt = GetGameTime();
	if( start > (gt - 0.1) ) start = gt - 0.1;
	GameRules_SetPropFloat( "m_fRoundStartTime", start );
}

//----------------------------------------------------------------------------------------------------------------------
GrenadeUsed( Handle:event, &Float:last_time, Float:time_to_add ) {
	if( !round_active ) return;
	if( GetGameTime() - round_start_time < c_extratime_wait ) return;
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	new team = GetClientTeam(client);
	if( team != TERRORIST ) return;
	new Float:time_since_last = GetGameTime() - last_time;
	last_time = GetGameTime();
	
	new Float:timeadded = time_since_last;
	if( timeadded > time_to_add ) timeadded = time_to_add;

	if( timeadded <= 0.0 ) return; // just in case
	AddRoundTime( timeadded );
}

//----------------------------------------------------------------------------------------------------------------------
public OnMolotovDetonate( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	GrenadeUsed( event, last_fire_time, c_extratime_molotov );
}

public OnSmokeDetonate( Handle:event, const String:name[], bool:dontBroadcast ) {
	GrenadeUsed( event, last_smoke_time, c_extratime_smoke );
}

//----------------------------------------------------------------------------------------------------------------------
