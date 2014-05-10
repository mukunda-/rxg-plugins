#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "DCSTATUS",
	author = "DCSTATUS",
	description = "FUCKING DCSTATUS",
	version = "DCSTATUS.DCSTATUS.DCSTATUS",
	url = "WWW.DCSTATUS.NET"
};

#define STATUS_SLOTS 20 

//new String:current_names[MAXPLAYERS+1][32];
//new String:current_auths[MAXPLAYERS+1][32]; 

// THIS IS A RING BUFFER
new String:ss_names[STATUS_SLOTS][32];
new String:ss_auths[STATUS_SLOTS][32]; 
new String:ss_timestamp[STATUS_SLOTS][32];

new queue_position = 0;
new queue_length = 0;

public OnPluginStart() {
	HookEvent( "player_disconnect", Event_playerdc );
	RegConsoleCmd( "sm_dcstatus", Command_dcstatus, "view status of people who disconnected" );
 
}

public Event_playerdc( Handle:event, const String:name[], bool:dontBroadcast ) {
	decl String:cname[64];
	decl String:auth[64];
	GetEventString( event, "name", cname, sizeof(cname) );
	GetEventString( event, "networkid", auth, sizeof(auth) );
	AddEntry( cname, auth );
}

AddEntry( const String:name[], const String:auth[] ) {
	strcopy( ss_names[queue_position], sizeof(ss_names[]), name );
	strcopy( ss_auths[queue_position], sizeof(ss_auths[]), auth );
	FormatTime( ss_timestamp[queue_position], sizeof(ss_timestamp[]), "%X" );
	queue_position++;
	if( queue_position >= STATUS_SLOTS ) queue_position = 0;
	queue_length++;
	if( queue_length>STATUS_SLOTS ) queue_length = STATUS_SLOTS;
}
 

public Action:Command_dcstatus( client, args ) {
	PrintToConsole( client, "DCStatus v1.0006%d, %d clients:", sizeof(ss_names[]), queue_length );

	for( new i = 0; i < queue_length; i++ ) {
		new index = queue_position - 1 - i;
		if( index < 0 ) index += STATUS_SLOTS;
		PrintToConsole( client, "  %s - %s - %s", ss_timestamp[index], ss_auths[index], ss_names[index] );
	}
	return Plugin_Handled;
}
 