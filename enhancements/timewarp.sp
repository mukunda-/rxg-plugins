
#include <sourcemod>
#include <sdktools>
#include <rxgstore>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Time Warmp",
	author = "WhiteThunder",
	description = "Slows down time",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
new Handle:cvar_timescale;

//-----------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	// CreateNative( "MONO_SpawnMonoculus", Native_SpawnMonoculus );
	// RegPluginLibrary("monoculus");
}

//-----------------------------------------------------------------------------
RecacheConvars() {
	
}

//-----------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public OnPluginStart() {
	RegAdminCmd( "sm_settimescale", Command_SetTimescale, ADMFLAG_RCON );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	
	cvar_timescale = FindConVar("host_timescale");
	SetConVarFlags( cvar_timescale, GetConVarFlags(cvar_timescale)&~FCVAR_CHEAT ); 
	
}

//-----------------------------------------------------------------------------
public Action:Command_SetTimescale( client, args ) {
	
	if( client == 0 && args == 0 ) return Plugin_Handled;
	
	new Float:scale = 1.0;
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if( args == 0 ) {
		target_list[0] = client;
		target_count = 1;
	}
	
	if( args > 0 ) {
		new String:targets_arg[32];
		GetCmdArg( 1, targets_arg, sizeof targets_arg );
		
		target_count = ProcessTargetString(
			targets_arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED & COMMAND_FILTER_ALIVE,
			target_name,
			sizeof target_name,
			tn_is_ml
		);
		
		if( target_count < 1 ) {
			ReplyToCommand( client, "[SM] No matching client found" );
			return Plugin_Handled;
		}
	}
	
	if( args > 1 ) {
		new String:scale_arg[32];
		GetCmdArg( 2, scale_arg, sizeof scale_arg );
		scale = FloatAbs( StringToFloat(scale_arg) );
	}
	
	for( new i = 0; i < target_count; i++ ) {
		SetTimescale( target_list[i], scale );
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
bool:SetTimescale( client, Float:scale ) {
	
	if( !IsPlayerAlive(client) ) {
		return false;
	}
	
	decl String:scale_arg[32];
	FloatToString( scale, scale_arg, sizeof scale_arg );
	
	SendConVarValue( client, cvar_timescale, scale_arg );
	
	return true;
}






















