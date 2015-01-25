 
#include <sourcemod>
#include <sdktools>
#include <monoculus>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "time warp item",
	author = "Roker",
	description = "time warp item to slow down time",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_NAME "time_warp"
#define ITEM_FULLNAME "time_warp"
#define ITEMID

new bool:time_warped = false;
new Float:c_timewarp_timescale;
new Handle:host_timescale;
new Handle:sm_timewarp_timescale;

new Float:current_timescale;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	//RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	host_timescale = FindConVar("host_timescale");
	current_timescale = 1.0;
	
	RegAdminCmd( "sm_warptime", Command_warpTime, ADMFLAG_RCON );
	sm_timewarp_timescale = CreateConVar("sm_timewarp_timescale", "0.5", "The speed time goes when slowed", FCVAR_PLUGIN);
	
	HookConVarChange( sm_timewarp_timescale, OnConVarChanged );
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_timewarp_timescale = GetConVarFloat( sm_timewarp_timescale );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
fakeCheats(client, bool:on_off){
	SendConVarValue(client, FindConVar("sv_cheats"), on_off ? "1" : "0");
}
//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		//RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	//RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if(!time_warped){
		warpTime();
	}else{
		PrintToChat(client,"Time is already warped!");
	}
}
//-------------------------------------------------------------------------------------------------
public Action:Command_warpTime( client, args ) {
	warpTime();
	return Plugin_Handled;
}
//-------------------------------------------------------------------------------------------------
public warpTime(){
	time_warped = true;
	for (new i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			fakeCheats(i,true);
		}
	}
	CreateTimer(0.1, Timer_warpTimeInc, _,TIMER_REPEAT);
	CreateTimer(10.0, Timer_unWarpTime);
}
//-------------------------------------------------------------------------------------------------
public Action:Timer_warpTimeInc(Handle:Timer){
	current_timescale -= 0.03;
	SetConVarFloat(host_timescale, current_timescale);
	if(current_timescale > c_timewarp_timescale){
		return Plugin_Continue;
	}
	return Plugin_Stop;
}
//-------------------------------------------------------------------------------------------------
public Action:Timer_unWarpTime(Handle:Timer){
	CreateTimer(0.1, Timer_unWarpTimeInc, _,TIMER_REPEAT);
}
//-------------------------------------------------------------------------------------------------
public Action:Timer_unWarpTimeInc(Handle:timer){
	current_timescale += 0.03;
	SetConVarFloat(host_timescale, current_timescale);
	if(current_timescale < 1){
		return Plugin_Continue;
	}
	for (new i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			fakeCheats(i,false);
		}
	}
	time_warped = false;
	return Plugin_Stop;
}