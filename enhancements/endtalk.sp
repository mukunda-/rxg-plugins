#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

// 1.1.0 3:38 PM 12/23/2013
//   preserve settings

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name        = "endtalk",
	author      = "mukunda",
	description = "end-round talk",
	version     = "1.1.1",
	url         = "www.mukunda.com"
};

Handle sv_alltalk       = null;
Handle sv_deadtalk      = null;
bool   alltalk_changed  = false;
bool   deadtalk_changed = false;

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	sv_alltalk  = FindConVar( "sv_alltalk" );
	sv_deadtalk = FindConVar( "sv_deadtalk" );
	
	// remove notify flag to prevent chat notifications
	SetConVarFlags( sv_alltalk,  GetConVarFlags(sv_alltalk) & ~FCVAR_NOTIFY );
	SetConVarFlags( sv_deadtalk, GetConVarFlags(sv_deadtalk) & ~FCVAR_NOTIFY );
	
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "round_end",   OnRoundEnd );
}

//-----------------------------------------------------------------------------
public void OnRoundEnd( Handle event, const char[] name, bool nb ) {
	 
	EnableFulltalk();
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool nb ) {

	DisableFulltalk();
}

//-----------------------------------------------------------------------------
void EnableFulltalk() {
	if( GetConVarBool( sv_alltalk ) == false ) {
		SetConVarBool( sv_alltalk, true );
		alltalk_changed = true;
	}
	if( GetConVarBool( sv_deadtalk ) == false ) {
		SetConVarBool( sv_deadtalk, true );	
		deadtalk_changed = true;
	}
}
//-----------------------------------------------------------------------------
void DisableFulltalk() {
	if( alltalk_changed  ) SetConVarBool( sv_alltalk,  false );
	if( deadtalk_changed ) SetConVarBool( sv_deadtalk, false );	
}


