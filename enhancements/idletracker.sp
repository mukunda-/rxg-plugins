#include <sourcemod>
#include <sdktools>

#pragma semicolon 1


//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "idletracker",
	author = "mukunda",
	description = "idle tracker; reports to plugins exactly how long someone has not touched their controls",
	version = "1.0.0",
	url = "www.mukunda.com"
};

public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	CreateNative( "ResetClientIdleTime", Native_ResetIdleTime );
	CreateNative( "GetClientIdleTime", Native_GetIdleTime );
	CreateNative( "IsClientIdleAtSpawn", Native_IdleAtSpawn );
}

//----------------------------------------------------------------------------------------------------------------------
new Float:last_touch_time[MAXPLAYERS+1];

new last_buttons[MAXPLAYERS+1];
new Float:last_pitch[MAXPLAYERS+1];

new bool:idle_at_spawn[MAXPLAYERS+1];
new Float:spawntime[MAXPLAYERS+1];

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations( "common.phrases" );

	HookEvent( "player_spawn", Event_PlayerSpawn );
	AddCommandListener( ResetTimeFromCommand, "say" );
	AddCommandListener( ResetTimeFromCommand, "say_team" ); // todo: verify name of command
	AddCommandListener( ResetTimeFromCommand, "jointeam" );
	
	RegConsoleCmd( "sm_idle", Command_idle );
	
	new Float:time = GetGameTime();
	for( new i = 1; i <=MaxClients; i++ ) {
		last_touch_time[i] = time;
		spawntime[i] = time;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	new bool:idle = true;
	if( (GetGameTime() - spawntime[client] > 3.0) ) {
		if( buttons != last_buttons[client] ) {
			idle = false;
		}
		if( IsPlayerAlive(client) ) {
			if( angles[0] != last_pitch[client] ) {
				idle = false;
			}
		}
	}

	last_buttons[client] = buttons;
	last_pitch[client] = angles[0];	
	
	if( !idle ) {
		ResetIdleTime(client);
	}
	return Plugin_Continue;
}

public OnClientConnected(client) { 
	ResetIdleTime(client);
	spawntime[client] = GetGameTime();
}

//----------------------------------------------------------------------------------------------------------------------
ResetIdleTime(client) {
	last_touch_time[client] = GetGameTime();
	idle_at_spawn[client] = false;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId(userid);
	if( !client ) return;
	idle_at_spawn[client] = true;
	spawntime[client] = GetGameTime();
}

//----------------------------------------------------------------------------------------------------------------------
public Action:ResetTimeFromCommand(client, const String:command[], argc) {
	ResetIdleTime(client);
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------

Float:GetIdleTime(client) {
	return GetGameTime() - last_touch_time[client];	
}

public Native_GetIdleTime( Handle:plugin, numParams ) {
	return _:GetIdleTime(GetNativeCell(1));
}

public Native_IdleAtSpawn( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return idle_at_spawn[client];
}

public Native_ResetIdleTime( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	ResetIdleTime(client);
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_idle( client, args ) {
	if( args == 0 ) {
		ReplyToCommand( client, "[SM] Usage: sm_idle <player> - Returns player idle time." );
		return Plugin_Handled;
	}
	decl String:arg[64];
	GetCmdArg( 1, arg,sizeof(arg) );
	new target = FindTarget( client, arg, false );
	if( target == -1 ) return Plugin_Handled;
	PrintToServer( "%d", idle_at_spawn[target] );
	ReplyToCommand( client, "[SM] %N has been idle %sfor %.2f seconds.", target, idle_at_spawn[target]?"at spawn ":"", GetIdleTime(target) );
	
	return Plugin_Handled;
}
