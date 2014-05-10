
#include <sourcemod>
#include <sdktools>

// 1.0.2 11:00 PM 11/24/2013
//  - increased duration
// 1.0.1 7:57 PM 10/10/2013
//  - fixed bug that depends on loading order

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "haxban",
	author = "mukunda",
	description = "ban hackers",
	version = "1.0.2",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Handle:smac_eyetest_ban = INVALID_HANDLE;
new Handle:smac_aimbot_ban = INVALID_HANDLE;

//----------------------------------------------------------------------------------------------------------------------
new bool:enabled;
new Float:disable_time;

//----------------------------------------------------------------------------------------------------------------------
new Float:last_cmd_use_time;

#define HOOKTIME 180.0
#define COOLDOWN 60.0

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	HookSMAC();

}

//----------------------------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if (StrEqual(name, "smac"))
		HookSMAC();
}

//----------------------------------------------------------------------------------------------------------------------
HookSMAC() {
	if( !LibraryExists("smac") ) return;
	smac_eyetest_ban = FindConVar( "smac_eyetest_ban" );
	smac_aimbot_ban = FindConVar( "smac_aimbot_ban" );
	RegConsoleCmd( "hax", Command_hax );
}


//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	last_cmd_use_time = -90.0;
	disable_time = 0.0;
	enabled = false;
	if( smac_eyetest_ban != INVALID_HANDLE ) SetConVarInt( smac_eyetest_ban, 0 );
	if( smac_aimbot_ban != INVALID_HANDLE ) SetConVarInt( smac_aimbot_ban, 0 );
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_hax( client, args ) {
	if( GetGameTime() - last_cmd_use_time < COOLDOWN ) {
		ReplyToCommand( client, "Please wait before banning more hackers." );
		return Plugin_Handled;
	}
	last_cmd_use_time = GetGameTime();
	PrintToChatAll( "\x01 >> \x02Banning hackers..." );
	EnableBanning( HOOKTIME );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
DisableBanning() {
	if( !enabled ) return;
	enabled = false;
	if( smac_eyetest_ban != INVALID_HANDLE ) SetConVarInt( smac_eyetest_ban, 0 );
	if( smac_aimbot_ban != INVALID_HANDLE ) SetConVarInt( smac_aimbot_ban, 0 );
}

//----------------------------------------------------------------------------------------------------------------------
EnableBanning( Float:duration ) {
	if( enabled ) return;
	enabled = true;
	disable_time = GetGameTime() + duration;
	CreateTimer( duration, TimerDisable, _, TIMER_FLAG_NO_MAPCHANGE );
	if( smac_eyetest_ban == INVALID_HANDLE ) smac_eyetest_ban = FindConVar( "smac_eyetest_ban" );
	if( smac_aimbot_ban == INVALID_HANDLE ) smac_aimbot_ban = FindConVar( "smac_aimbot_ban" );
	if( smac_eyetest_ban != INVALID_HANDLE ) SetConVarInt( smac_eyetest_ban, 1 );
	if( smac_aimbot_ban != INVALID_HANDLE ) SetConVarInt( smac_aimbot_ban, 1 );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:TimerDisable( Handle:timer ) {
	if( (GetGameTime() - disable_time) < (-1.0) ) {
		return Plugin_Handled;
	}
	DisableBanning();
	return Plugin_Handled;
}
