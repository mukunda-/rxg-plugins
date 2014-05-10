#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

// 1.1.0 3:38 PM 12/23/2013
//   preserve settings

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "endtalk",
	author = "mukunda",
	description = "end-round talk",
	version = "1.1.0",
	url = "www.mukunda.com"
};

new Handle:sv_alltalk			= INVALID_HANDLE;	// CVARS
new Handle:sv_deadtalk			= INVALID_HANDLE;	//
new bool:alltalk_changed;
new bool:deadtalk_changed;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	sv_alltalk		= FindConVar( "sv_alltalk" );
	sv_deadtalk		= FindConVar( "sv_deadtalk" );

	SetConVarFlags( sv_alltalk, GetConVarFlags(sv_alltalk) & ~FCVAR_NOTIFY );
	SetConVarFlags( sv_deadtalk, GetConVarFlags(sv_deadtalk) & ~FCVAR_NOTIFY );
	
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {


	DisableFulltalk();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	 
	EnableFulltalk();
}

//----------------------------------------------------------------------------------------------------------------------
EnableFulltalk() {
	if( GetConVarBool( sv_alltalk ) == false ) {
		SetConVarBool( sv_alltalk, true );
		alltalk_changed = true;
	}
	if( GetConVarBool( sv_deadtalk ) == false ) {
		SetConVarBool( sv_deadtalk, true );	
		deadtalk_changed = true;
	}
}
//----------------------------------------------------------------------------------------------------------------------
DisableFulltalk() {
	if( alltalk_changed ) SetConVarBool( sv_alltalk, false );
	if( deadtalk_changed ) SetConVarBool( sv_deadtalk, false );	
}


