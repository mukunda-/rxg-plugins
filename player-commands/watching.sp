
/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/


#include <sourcemod>
#include <sdktools>
#include <idletracker>
#pragma semicolon 1


// version 1.1.0
//   exclude AFKs
// version 1.0.0
//   initial release
//
//
// todo: localization
// 

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Watching",
	author = "mukunda",
	description = "Command to see how many players are sharing your view.",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Float:last_used[MAXPLAYERS];
#define COOLDOWN 1.0

enum {
	SPECMODE_FIRSTPERSON = 4,
	SPECMODE_3RDPERSON = 5,
	SPECMODE_FREE = 6
};

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "sm_watching", Command_watching, "Shows how many players are watching you." );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_watching( client, args ) {
	if( client == 0 ) return Plugin_Continue;

	// -- commandspam protection --
	if( FloatAbs(GetGameTime() - last_used[client]) < COOLDOWN ) return Plugin_Handled;
	last_used[client] = GetGameTime();
	
	new target;
	
	if( !IsPlayerAlive(client) ) {

		// -- if player is dead, use their observer target --
	
		new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
		if( (!IsClientObserver(client)) || ((specmode != SPECMODE_FIRSTPERSON) && (specmode != SPECMODE_3RDPERSON)) ) {

			// free roaming, function disabled
			return Plugin_Handled;
		}
		
		target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
	} else {
		target = client;
	}
	
	if( target == 0 ) return Plugin_Handled;
	
	new count = 0;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		
		// filter for spectators watching target
		if( !IsClientInGame(i) ) continue;
		if( client == i ) continue; // exclude caller
		if( !IsClientObserver(i) ) continue;
		if( GetClientIdleTime(i) > 300.0 ) continue; // exclude AFK spectators
		new specmode = GetEntProp( i, Prop_Send, "m_iObserverMode" );
		if( specmode != SPECMODE_FIRSTPERSON && specmode != SPECMODE_3RDPERSON ) continue;
		if( target != GetEntPropEnt( i, Prop_Send, "m_hObserverTarget" ) ) continue;
		
		count++;
	}
	
	// print result	
	decl String:countstring[32];
	if( count == 0 )
		countstring = "no";
	else 
		Format( countstring, sizeof countstring, "%d", count );

	if( target == client ) {
		PrintToChat( client, "\x01 \x04There %s %s %s watching you.", count == 1 ? "is":"are", countstring, count == 1 ? "person":"people" );
	} else {
		PrintToChat( client, "\x01 \x04There %s %s other %s watching %N.", count == 1 ? "is":"are", countstring, count == 1 ? "person":"people", target );
	}
	return Plugin_Handled;
}
