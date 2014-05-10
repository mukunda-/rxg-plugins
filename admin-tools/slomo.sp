
#include <sourcemod>
#include <sdktools> 
 #pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "slomo",
	author = "REFLEX-GAMERS",
	description = "slomo button",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};


new Handle:sv_cheats;
new Handle:host_timescale;

new bool:slomo;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	sv_cheats = FindConVar( "sv_cheats" );
	host_timescale = FindConVar( "host_timescale" );

	SetConVarFlags( sv_cheats, GetConVarFlags(sv_cheats) & ~FCVAR_NOTIFY );
	SetConVarFlags( host_timescale, GetConVarFlags(host_timescale) & ~FCVAR_NOTIFY );

	RegAdminCmd( "sm_slomo", Command_toggle, ADMFLAG_SLAY );
	RegAdminCmd( "+sm_slomo", Command_on, ADMFLAG_SLAY );
	RegAdminCmd( "-sm_slomo", Command_off, ADMFLAG_SLAY );
	
	// block cheat commands
	RegConsoleCmd( "noclip", Command_nullify );
	RegConsoleCmd( "endround", Command_nullify );
}

public Action:Command_nullify( client,args ) {
	return Plugin_Handled;
}

Float:GetSlomoArg(args) {
	new Float:speed;
	if( args > 0 ) {

		decl String:arg[16];
		GetCmdArg( 1, arg, sizeof(arg) );
		speed = StringToFloat( arg );
	} else {
		speed = 0.5;
	}
	if( speed < 0.1 ) speed = 0.1;
	if( speed > 0.9 ) speed = 0.9;
	return speed;
}

public Action:Command_toggle( client, args ) {
	new Float:speed = GetSlomoArg(args);
	if( !slomo ) {
		slomo = true;
		SetConVarInt( sv_cheats, 1 );
		SetConVarFloat( host_timescale, speed );
	} else {
		slomo = false;
		SetConVarFloat( host_timescale, 1.0 );
		SetConVarInt( sv_cheats, 0 );
	}
	return Plugin_Handled;
}

public Action:Command_on( client, args ) {
	new Float:speed = GetSlomoArg(args);
	if( !slomo ) {
		slomo = true;
		SetConVarInt( sv_cheats, 1 );
		SetConVarFloat( host_timescale, speed );
	}
	return Plugin_Handled;
}

public Action:Command_off( client, args ) {
	if( slomo ) {
		slomo = false;
		SetConVarFloat( host_timescale, 1.0 );
		SetConVarInt( sv_cheats, 0 );
	}
	return Plugin_Handled;
}
